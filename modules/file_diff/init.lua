-- BASED ON: file_diff module, Copyright 2015-2017 Mitchell mitchell.att.foicica.com. See LICENSE.

--
-- DON'T USE YET (working on this module)
--

local M = {}

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

local bit32_band = bit32.band

local vfp1= Proj.prefview[Proj.PRJV_FILES]
local vfp2= Proj.prefview[Proj.PRJV_FILES_2]

local compareon=false
local buffer1, buffer2

local synchronizing = false

local function clear_buf_marks(b)
  if b then
    for _, mark in ipairs{MARK_ADDITION, MARK_DELETION, MARK_MODIFICATION} do
      b:marker_delete_all(mark)
    end
    for _, indic in ipairs{INDIC_ADDITION, INDIC_DELETION} do
      b.indicator_current = indic
      b:indicator_clear_range(0, b.length)
    end
    b:annotation_clear_all()
  end
end

-- Clear markers, indicators, and placeholder lines.
-- Used when re-marking changes or finished diff'ing.
local function clear_marked_changes()
  clear_buf_marks(buffer1)
  clear_buf_marks(buffer2)
end

-- Stops diff'ing.
local function stop()
  if compareon then
    compareon= false
    clear_marked_changes()
    buffer1, buffers = nil, nil
    ui.statusbar_text= "File compare: OFF"
  end
end

--check that the buffers in both view hasn't changed
local function check_comp_buffers()
  if compareon and (#_VIEWS < vfp2 or buffer1 ~= _VIEWS[vfp1].buffer or buffer2 ~= _VIEWS[vfp2].buffer) then stop() end
  return compareon
end

-- Synchronize the scroll and line position of the other buffer.
local function synchronize()
  synchronizing = true
  local currview= _VIEWS[view]
  local otherview= vfp2
  if currview == vfp2 then otherview= vfp1 elseif currview ~= vfp1 then return end
  Proj.updating_ui=Proj.updating_ui+1
  local line = buffer:line_from_position(buffer.current_pos)
  local visible_line = buffer:visible_from_doc_line(line)
  local first_visible_line = buffer.first_visible_line
  local x_offset = buffer.x_offset
  my_goto_view(otherview)
  buffer:goto_line(buffer:doc_line_from_visible(visible_line))
  buffer.first_visible_line, buffer.x_offset = first_visible_line, x_offset
  my_goto_view(currview)
  Proj.updating_ui=Proj.updating_ui-1
  synchronizing = false
end

-- Mark the differences between the two buffers.
local function mark_changes()
  if not check_comp_buffers() then return end
  clear_marked_changes() -- clear previous marks

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

-- Highlight differences between files in left (NEW) / right (OLD) panel
function M.start()
  if not Proj then return end
  if compareon then
    stop()
    return
  end
  if #_VIEWS < vfp2 then
    ui.statusbar_text= "Can't compare, the right panel is closed"
    return
  end
  ui.statusbar_text= "File compare: ON"

  Proj.updating_ui=Proj.updating_ui+1
  my_goto_view(vfp2)
  buffer2= buffer
  buffer2.annotation_visible= buffer.ANNOTATION_STANDARD

  my_goto_view(vfp1)
  buffer1= buffer
  buffer1.annotation_visible= buffer.ANNOTATION_STANDARD
  Proj.updating_ui=Proj.updating_ui-1

  compareon= true
  mark_changes()
end

-- Stop diff'ing when one of the buffer's being diff'ed is switched or closed.
events.connect(events.BUFFER_AFTER_SWITCH, function() check_comp_buffers() end)
events.connect(events.BUFFER_DELETED, function() check_comp_buffers() end)

-- Ensure the diff buffers are scrolled in sync.
events.connect(events.UPDATE_UI, function(updated)
  if updated and not synchronizing and check_comp_buffers() then
    if bit32_band(updated, buffer.UPDATE_H_SCROLL + buffer.UPDATE_V_SCROLL + buffer.UPDATE_SELECTION) > 0 then
      synchronize()
    end
  end
end)

-- Highlight differences as text is typed and deleted.
events.connect(events.MODIFIED, function(modification_type)
  if not check_comp_buffers() then return end
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

keys.f8 = M.start

return M
