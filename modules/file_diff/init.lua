-- Copyright 2015-2017 Mitchell mitchell.att.foicica.com. See LICENSE.

--
-- DON'T USE YET (working on this module)
--


local M = {}

--[[ This comment is for LuaDoc.
---
-- File diff'ing for Textadept.
-- @field MARK_ADDITION (number)
--   The marker for line additions.
-- @field MARK_DELETION (number)
--   The marker for line deletions.
-- @field MARK_MODIFICATION (number)
--   The marker for line modifications.
-- @field INDIC_ADDITION (number)
--   The indicator number for text added within lines.
-- @field INDIC_ADDITION (number)
--   The indicator number for text deleted within lines.
module('_M.file_diff')]]

M.MARK_ADDITION = _SCINTILLA.next_marker_number()
M.MARK_DELETION = _SCINTILLA.next_marker_number()
M.MARK_MODIFICATION = _SCINTILLA.next_marker_number()
M.INDIC_ADDITION = _SCINTILLA.next_indic_number()
M.INDIC_DELETION = _SCINTILLA.next_indic_number()
local MARK_ADDITION = M.MARK_ADDITION
local MARK_DELETION = M.MARK_DELETION
local MARK_MODIFICATION = M.MARK_MODIFICATION
local INDIC_ADDITION = M.INDIC_ADDITION
local INDIC_DELETION = M.INDIC_DELETION

-- Localizations.
local _L = _L
if _L['_Compare Files']:find('^No Localization') then
  -- Dialogs.
  _L['Select the first file to compare'] = 'Select the first file to compare'
  _L['Select the file to compare to'] = 'Select the file to compare to'
  -- Status.
  _L['No more differences'] = 'No more differences'
  -- Menu.
  _L['_Compare Files'] = '_Compare Files'
  _L['_Compare Files...'] = '_Compare Files...'
  _L['Compare This File _With...'] = 'Compare This File _With...'
  _L['_Next Change'] = '_Next Change'
  _L['_Previous Change'] = '_Previous Change'
  _L['Merge _Left'] = 'Merge _Left'
  _L['Merge _Right'] = 'Merge _Right'
end

local DELETE, INSERT = 0, 1 -- enum Operation {DELETE, INSERT, EQUAL};
local bit32_band = bit32.band

local view1, view2

-- Clear markers, indicators, and placeholder lines.
-- Used when re-marking changes or finished diff'ing.
local function clear_marked_changes()
  local buffer1 = _VIEWS[view1] and view1.buffer
  local buffer2 = _VIEWS[view2] and view2.buffer
  for _, mark in ipairs{MARK_ADDITION, MARK_DELETION, MARK_MODIFICATION} do
    if buffer1 then buffer1:marker_delete_all(mark) end
    if buffer2 then buffer2:marker_delete_all(mark) end
  end
  for _, indic in ipairs{INDIC_ADDITION, INDIC_DELETION} do
    if buffer1 then
      buffer1.indicator_current = indic
      buffer1:indicator_clear_range(0, buffer1.length)
    end
    if buffer2 then
      buffer2.indicator_current = indic
      buffer2:indicator_clear_range(0, buffer2.length)
    end
  end
  if buffer1 then buffer1:annotation_clear_all() end
  if buffer2 then buffer2:annotation_clear_all() end
end

-- Synchronize the scroll and line position of the other buffer.
local function synchronize()
  --local line = buffer:line_from_position(buffer.current_pos)
  --local visible_line = buffer:visible_from_doc_line(line)
  --local first_visible_line = buffer.first_visible_line
  --local x_offset = buffer.x_offset
  --ui.goto_view(view == view1 and view2 or view1)
  --buffer:goto_line(buffer:doc_line_from_visible(visible_line))
  --buffer.first_visible_line, buffer.x_offset = first_visible_line, x_offset
  --ui.goto_view(view == view2 and view1 or view2)
end

-- Mark the differences between the two buffers.
local function mark_changes()
  if not _VIEWS[view1] or not _VIEWS[view2] then return end
  clear_marked_changes() -- clear previous marks
  local buffer1, buffer2 = view1.buffer, view2.buffer

  -- Perform the diff.
  filediff.setfile(1, buffer1:get_text())
  filediff.setfile(2, buffer2:get_text())

  -- Parse the diff, marking modified lines and changed text.
  local r= filediff.getdiff( 1, 1 )
  --enum lines that are only in buffer1
  for i=1,#r,2 do
    for j=r[i],r[i+1] do
      buffer1:marker_add(j-1, MARK_DELETION)
    end
  end
  --enum lines that are only in buffer2
  r= filediff.getdiff( 2, 1 )
  for i=1,#r,2 do
    for j=r[i],r[i+1] do
      buffer2:marker_add(j-1, MARK_ADDITION)
    end
  end
  --enum modified lines
  r= filediff.getdiff( 1, 2 )
  for i=1,#r,2 do
    buffer1:marker_add(r[i]-1, MARK_MODIFICATION)
    buffer2:marker_add(r[i+1]-1, MARK_MODIFICATION)
  end

  --show the missing lines using annotations
  local nlin0= 0
  r= filediff.getdiff( 1, 3 ) --buffer#1, 3=get blank lines list
  for i=1,#r,2 do
    local lin= r[i]
    local n= r[i+1]
    if lin == 0 then
      nlin0= n  --can't put annotations in line #0, move them 1 line down
    else
      if lin == 1 then
        n= n + nlin0  --join line 0 and line 1 spaces
        nlin0= 0
      end
      buffer1.annotation_text[lin-1] = string.rep('\n', n-1)
    end
  end
  --add pending line 0 spaces
  if nlin0 > 0 then buffer1.annotation_text[0] = string.rep('\n', nlin0-1) end
  --idem buffer #2
  r= filediff.getdiff( 2, 3 )--buffer#2, 3=get blank lines list
  nlin0= 0
  for i=1,#r,2 do
    local lin= r[i]
    local n= r[i+1]
    if lin == 0 then
      nlin0= n  --can't put annotations in line #0, move them 1 line down
    else
      if lin == 1 then
        n= n + nlin0  --join line 0 and line 1 spaces
        nlin0= 0
      end
      buffer2.annotation_text[lin-1] = string.rep('\n', n-1)
    end
  end
  --add pending line 0 spaces
  if nlin0 > 0 then buffer2.annotation_text[0] = string.rep('\n', nlin0-1) end

  --mark text changes
  r= filediff.getdiff( 1, 4 )
  for i=1,#r,3 do
    if r[i] == 1 then
      buffer1.indicator_current = INDIC_DELETION
      buffer1:indicator_fill_range(r[i+1], r[i+2])
    else
      buffer2.indicator_current = INDIC_ADDITION
      buffer2:indicator_fill_range(r[i+1], r[i+2])
    end
  end

  synchronize()
end

local starting_diff = false

---
-- Highlight differences between files *file1* and *file2*, or the user-selected
-- files.
-- @param file1 Optional name of the older file. If `nil`, the user is prompted
--   for a file.
-- @param file2 Optional name of the newer file. If `nil`, the user is prompted
--   for a file.
-- @param horizontal Optional flag specifying whether or not to split the view
--   horizontally. The default value is `false`, diff'ing the two files
--   side-by-side.
function M.start(file1, file2, horizontal)
  file1 = file1 or ui.dialogs.fileselect{
    title = _L['Select the first file to compare'],
    with_directory = (buffer.filename or ''):match('^.+[/\\]') or
                     lfs.currentdir(),
    width = CURSES and ui.size[1] - 2 or nil
  }
  if not file1 then return end
  file2 = file2 or ui.dialogs.fileselect{
    title = _L['Select the file to compare to']..' '..file1:match('[^/\\]+$'),
    with_directory = file1:match('^.+[/\\]') or lfs.currentdir(),
    width = CURSES and ui.size[1] - 2 or nil
  }
  if not file2 then return end
  starting_diff = true
  if _VIEWS[view1] and view ~= view1 then ui.goto_view(view1) end
  io.open_file(file1)
  buffer.annotation_visible = buffer.ANNOTATION_STANDARD -- view1
  if not _VIEWS[view1] or not _VIEWS[view2] then
    view1, view2 = view:split(not horizontal)
  else
    ui.goto_view(view2)
  end
  io.open_file(file2)
  buffer.annotation_visible = buffer.ANNOTATION_STANDARD -- view2
  ui.goto_view(view1)
  starting_diff = false
  mark_changes()
end

-- Stops diff'ing.
local function stop()
  clear_marked_changes()
  view1, view2 = nil, nil
end
-- Stop diff'ing when one of the buffer's being diff'ed is switched or closed.
events.connect(events.BUFFER_BEFORE_SWITCH,
               function() if not starting_diff then stop() end end)
events.connect(events.BUFFER_DELETED, stop)

-- Retrieves the equivalent of line number *line* in the other buffer.
-- @param line Line to get the synchronized equivalent of in the other buffer.
-- @return line
local function get_synchronized_line(line)
  local visible_line = buffer:visible_from_doc_line(line)
  ui.goto_view(view == view1 and view2 or view1)
  line = buffer:doc_line_from_visible(visible_line)
  ui.goto_view(view == view2 and view1 or view2)
  return line
end

-- Ensure the diff buffers are scrolled in sync.
local synchronizing = false
events.connect(events.UPDATE_UI, function(updated)
  if _VIEWS[view1] and _VIEWS[view2] and updated and not synchronizing then
    if bit32_band(updated, buffer.UPDATE_H_SCROLL + buffer.UPDATE_V_SCROLL +
                           buffer.UPDATE_SELECTION) > 0 then
      synchronizing = true
      synchronize()
      synchronizing = false
    end
  end
end)

-- Highlight differences as text is typed and deleted.
events.connect(events.MODIFIED, function(modification_type)
  if not _VIEWS[view1] or not _VIEWS[view2] then return end
  if bit32_band(modification_type, 0x01 + 0x02) > 0 then mark_changes() end
end)

events.connect(events.VIEW_NEW, function()
  local markers = {
    [MARK_ADDITION] = 'green', [MARK_DELETION] = 'red',
    [MARK_MODIFICATION] = 'yellow'
  }
  for mark, color in pairs(markers) do
    buffer:marker_define(mark, buffer.MARK_BACKGROUND)
    buffer.marker_back[mark] = buffer.property_int['color.'..color]
  end
  local indicators = {[INDIC_ADDITION] = 'green', [INDIC_DELETION] = 'red'}
  for indic, color in pairs(indicators) do
    buffer.indic_style[indic] = buffer.INDIC_FULLBOX
    buffer.indic_fore[indic] = buffer.property_int['color.'..color]
    buffer.indic_alpha[indic], buffer.indic_under[indic] = 255, true
  end
end)

--args.register('-d', '--diff', 2, M.start, 'Compares two files')

keys.f8 = M.start

return M
