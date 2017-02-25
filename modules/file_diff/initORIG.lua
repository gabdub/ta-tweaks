-- Copyright 2015-2017 Mitchell mitchell.att.foicica.com. See LICENSE.

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

local lib = 'file_diff.diff'
if WIN32 then
  if jit then lib = lib..'jit' end
elseif OSX then
  lib = lib..'osx'
else
  local p = io.popen('uname -i')
  if p:read('*a'):find('64') then lib = lib..'64' end
  p:close()
end
local diff = require(lib)
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
  local line = buffer:line_from_position(buffer.current_pos)
  local visible_line = buffer:visible_from_doc_line(line)
  local first_visible_line = buffer.first_visible_line
  local x_offset = buffer.x_offset
  ui.goto_view(view == view1 and view2 or view1)
  buffer:goto_line(buffer:doc_line_from_visible(visible_line))
  buffer.first_visible_line, buffer.x_offset = first_visible_line, x_offset
  ui.goto_view(view == view2 and view1 or view2)
end

-- Mark the differences between the two buffers.
local function mark_changes()
  if not _VIEWS[view1] or not _VIEWS[view2] then return end
  clear_marked_changes() -- clear previous marks
  local buffer1, buffer2 = view1.buffer, view2.buffer
  -- Perform the diff.
  local diffs = diff(buffer1:get_text(), buffer2:get_text())
  -- Parse the diff, marking modified lines and changed text.
  --print('---')
  local pos1, pos2 = 0, 0
  for i = 1, #diffs, 2 do
    local op, text = diffs[i], diffs[i + 1]
    local text_len = #text
    if op == DELETE then
      -- Count the number of lines deleted.
      local num_lines = 1
      for _ in text:gmatch('\n') do num_lines = num_lines + 1 end
      if num_lines > 1 then
        -- Mark deleted lines (full ones only).
        local line_start = buffer1:line_from_position(pos1)
        local line_end = buffer1:line_from_position(pos1 + text_len)
        for j = line_start, line_end do
          if buffer1.line_end_position[j] ~= pos1 and
             buffer1:position_from_line(j) ~= pos1 + text_len then
            buffer1:marker_add(j, MARK_DELETION)
          end
        end
      else
        -- Mark changed line and highlight deletion.
        buffer1:marker_add(buffer1:line_from_position(pos1), MARK_MODIFICATION)
        buffer2:marker_add(buffer2:line_from_position(pos2), MARK_MODIFICATION)
        buffer1.indicator_current = INDIC_DELETION
        buffer1:indicator_fill_range(pos1, text_len)
      end
      pos1 = pos1 + text_len
      -- Fill in empty space in the other buffer.
      if num_lines > 1 then
        local blanks = string.rep('\n', num_lines - 2)
        buffer2.annotation_text[buffer2:line_from_position(pos2) - 1] = blanks
      end
    elseif op == INSERT then
      local num_lines = 1
      for _ in text:gmatch('\n') do num_lines = num_lines + 1 end
      if num_lines > 1 then
        -- Mark added lines (full ones only).
        local line_start = buffer2:line_from_position(pos2)
        local line_end = buffer2:line_from_position(pos2 + text_len)
        for j = line_start, line_end do
          if buffer2.line_end_position[j] ~= pos2 and
             buffer2:position_from_line(j) ~= pos2 + text_len then
            buffer2:marker_add(j, MARK_ADDITION)
          end
        end
      else
        -- Mark changed line and highlight addition.
        buffer2:marker_add(buffer2:line_from_position(pos2), MARK_MODIFICATION)
        buffer1:marker_add(buffer1:line_from_position(pos1), MARK_MODIFICATION)
        buffer2.indicator_current = INDIC_ADDITION
        buffer2:indicator_fill_range(pos2, text_len)
      end
      pos2 = pos2 + text_len
      -- Fill in empty space in the other buffer.
      if num_lines > 1 then
        local blanks = string.rep('\n', num_lines - 2)
        buffer1.annotation_text[buffer1:line_from_position(pos1) - 1] = blanks
      end
    else
      pos1, pos2 = pos1 + text_len, pos2 + text_len
    end
    --text = text:gsub('\n', '\\n')
    --if #text > 70 then text = text:sub(1, 30)..' ... '..text:sub(-30) end
    --print(op, '"'..text..'"')
  end
  --for i = 0, buffer.line_count do print(buffer:marker_get(i)) end
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

---
-- Jumps to the next or previous difference between the two files depending on
-- boolean *next*.
-- `start()` must have been called previously.
-- @param next Whether to go to the next or previous difference relative to the
--   current line.
function M.goto_change(next)
  if not _VIEWS[view1] or not _VIEWS[view2] then return end
  -- Determine the line to start on, keeping in mind the synchronized line
  -- numbers may be different.
  local line1, line2
  local step = next and 1 or -1
  if view == view1 then
    line1 = buffer:line_from_position(buffer.current_pos) + step
    line2 = get_synchronized_line(line1)
  else
    line2 = buffer:line_from_position(buffer.current_pos) + step
    line1 = get_synchronized_line(line2)
  end
  -- Search for the next change or set of changes, wrapping as necessary.
  -- A block of additions, deletions, or modifications should be treated as a
  -- single change.
  local buffer1, buffer2 = view1.buffer, view2.buffer
  local diff_marker = 2^MARK_ADDITION + 2^MARK_DELETION + 2^MARK_MODIFICATION
  local f = next and buffer.marker_next or buffer.marker_previous
  line1 = f(buffer1, line1, diff_marker)
  while line1 >= 0 and
        bit32_band(buffer1:marker_get(line1), diff_marker) ==
        bit32_band(buffer1:marker_get(line1 - step), diff_marker) do
    line1 = f(buffer1, line1 + step, diff_marker)
  end
  line2 = f(buffer2, line2, diff_marker)
  while line2 >= 0 and
        bit32_band(buffer2:marker_get(line2), diff_marker) ==
        bit32_band(buffer2:marker_get(line2 - step), diff_marker) do
    line2 = f(buffer2, line2 + step, diff_marker)
  end
  if line1 < 0 and line2 < 0 then
    line1 = f(buffer1, next and 0 or buffer1.line_count, diff_marker)
    line2 = f(buffer2, next and 0 or buffer2.line_count, diff_marker)
  end
  if line1 < 0 and line2 < 0 then
    ui.statusbar_text = _L['No more differences']
    return
  end
  -- Determine which change is closer to the current line, keeping in mind the
  -- synchronized line numbers may be different. (For example, one buffer may
  -- have a block of modifications next while the other buffer has a block of
  -- additions next, and those additions logically come first.)
  if view == view1 then
    if line2 >= 0 then
      ui.goto_view(view2)
      local visible_line = buffer:visible_from_doc_line(line2)
      ui.goto_view(view1)
      local line2_1 = buffer:doc_line_from_visible(visible_line)
      buffer:goto_line(line1 >= 0 and
                       (next and line1 < line2_1 or
                        not next and line1 > line2_1) and line1 or line2_1)
    else
      buffer:goto_line(line1)
    end
  else
    if line1 >= 0 then
      ui.goto_view(view1)
      local visible_line = buffer:visible_from_doc_line(line1)
      ui.goto_view(view2)
      local line1_2 = buffer:doc_line_from_visible(visible_line)
      buffer:goto_line(line2 >= 0 and
                       (next and line2 < line1_2 or
                        not next and line2 > line1_2) and line2 or line1_2)
    else
      buffer:goto_line(line2)
    end
  end
  buffer:vertical_centre_caret()
end

---
-- Merges a change from one buffer to another, depending on the change under
-- the caret and the merge direction.
-- @param left Whether to merge from right to left or left to right.
function M.merge(left)
  if not _VIEWS[view1] or not _VIEWS[view2] then return end
  local buffer1, buffer2 = view1.buffer, view2.buffer
  -- Determine whether or not there is a change to merge.
  local line_start = buffer:line_from_position(buffer.current_pos)
  local line_end = line_start + 1
  local diff_marker = 2^MARK_ADDITION + 2^MARK_DELETION + 2^MARK_MODIFICATION
  local marker = bit32_band(buffer:marker_get(line_start), diff_marker)
  if marker == 0 then
    -- Look for additions or deletions from the other buffer, which are offset
    -- one line down (side-effect of Scintilla's visible line -> doc line
    -- conversions).
    local line = get_synchronized_line(line_start) + 1
    if bit32_band((view == view1 and buffer2 or
                                     buffer1):marker_get(line)) > 0 then
      ui.goto_view(view == view1 and view2 or view1)
      buffer:line_down()
      M.merge(left)
      ui.goto_view(view == view2 and view1 or view2)
    end
    return
  end
  -- Determine the bounds of the change target it.
  while bit32_band(buffer:marker_get(line_start - 1), diff_marker) == marker do
    line_start = line_start - 1
  end
  buffer.target_start = buffer:position_from_line(line_start)
  while bit32_band(buffer:marker_get(line_end), diff_marker) == marker do
    line_end = line_end + 1
  end
  buffer.target_end = buffer:position_from_line(line_end)
  -- Perform the merge, depending on context.
  if marker == 2^MARK_ADDITION then
    if left then
      -- Merge addition from right to left.
      local line = get_synchronized_line(line_end)
      buffer1:insert_text(buffer1:position_from_line(line), buffer2.target_text)
    else
      -- Merge "deletion" (empty text) from left to right.
      buffer2:replace_target('')
    end
  elseif marker == 2^MARK_DELETION then
    if left then
      -- Merge "addition" (empty text) from right to left.
      buffer1:replace_target('')
    else
      -- Merge deletion from left to right.
      local line = get_synchronized_line(line_end)
      buffer2:insert_text(buffer2:position_from_line(line), buffer1.target_text)
    end
  elseif marker == 2^MARK_MODIFICATION then
    local target_text = buffer.target_text
    line_start = get_synchronized_line(line_start)
    line_end = get_synchronized_line(line_end)
    ui.goto_view(view == view1 and view2 or view1)
    buffer.target_start = buffer:position_from_line(line_start)
    buffer.target_end = buffer:position_from_line(line_end)
    if view == view2 and left or view == view1 and not left then
      -- Merge change from opposite view.
      target_text = buffer.target_text
      ui.goto_view(view == view2 and view1 or view2)
      buffer:replace_target(target_text)
    else
      -- Merge change to opposite view.
      buffer:replace_target(target_text)
      ui.goto_view(view == view2 and view1 or view2)
    end
  end
  mark_changes() -- refresh
end

-- TODO: connect to these in `start()` and disconnect in `stop()`?

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

args.register('-d', '--diff', 2, M.start, 'Compares two files')

-- Add a menu and configure key bindings.
-- (Insert 'Compare Files' menu in alphabetical order.)
local m_tools = textadept.menu.menubar[_L['_Tools']]
local found_area
for i = 1, #m_tools - 1 do
  if not found_area and m_tools[i + 1].title == _L['_Bookmark'] then
    found_area = true
  elseif found_area then
    local label = m_tools[i].title or m_tools[i][1]
    if 'Compare Files' < label:gsub('^_', '') or m_tools[i][1] == '' then
      table.insert(m_tools, i, {
        title = _L['_Compare Files'],
        {_L['_Compare Files...'], M.start},
        {_L['Compare This File _With...'], function()
          if buffer.filename then M.start(buffer.filename) end
        end},
        {''},
        {_L['_Next Change'], function() M.goto_change(true) end},
        {_L['_Previous Change'], M.goto_change},
        {''},
        {_L['Merge _Left'], function() M.merge(true) end},
        {_L['Merge _Right'], M.merge},
      })
      break
    end
  end
end
keys.f8 = M.start
keys.adown = m_tools[_L['_Compare Files']][_L['_Next Change']][2]
keys.aup = M.goto_change
keys.aleft = m_tools[_L['_Compare Files']][_L['Merge _Left']][2]
keys.aright = M.merge

return M
