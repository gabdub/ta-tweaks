-- Copyright 2016-2017 Gabriel Dubatti. See LICENSE.
-- BASED ON: file_diff module, Copyright 2015-2017 Mitchell mitchell.att.foicica.com. See LICENSE.
--
local Proj = Proj
local Util = Util

Proj.MARK_ADDITION = _SCINTILLA.next_marker_number()
Proj.MARK_DELETION = _SCINTILLA.next_marker_number()
Proj.MARK_MODIFICATION = _SCINTILLA.next_marker_number()
Proj.INDIC_ADDITION = _SCINTILLA.next_indic_number()
Proj.INDIC_DELETION = _SCINTILLA.next_indic_number()

local vfp1= Proj.prefview[Proj.PRJV_FILES]
local vfp2= Proj.prefview[Proj.PRJV_FILES_2]
local compareon=false
local synchronizing = false

local function clear_buf_marks(b)
  if b then
    for _, mark in ipairs{Proj.MARK_ADDITION, Proj.MARK_DELETION, Proj.MARK_MODIFICATION} do
      b:marker_delete_all(mark)
    end
    for _, indic in ipairs{Proj.INDIC_ADDITION, Proj.INDIC_DELETION} do
      b.indicator_current = indic
      b:indicator_clear_range(0, b.length)
    end
    b:annotation_clear_all()
    b._annot_list= nil
    b._annot_lines= 0
  end
end

local function clear_view_marks(nview)
  if #_VIEWS >= nview then
    clear_buf_marks(_VIEWS[nview].buffer)
  end
end

-- Clear markers, indicators, and placeholder lines.
-- Used when re-marking changes or finished diff'ing.
local function clear_marked_changes()
  clear_view_marks(vfp1)
  clear_view_marks(vfp2)
end

-- Stops diff'ing.
local function diff_stop()
  if compareon then
    compareon= false
    clear_marked_changes()
    ui.statusbar_text= "File compare: OFF"
  end
end

--check that the buffers in both view hasn't changed
local function check_comp_buffers()
  if compareon and #_VIEWS >= vfp2 then
    local b1= _VIEWS[vfp1].buffer
    local b2= _VIEWS[vfp2].buffer
    return b1 and b2 and b1._comparing and b2._comparing
  end
  return false
end

-- Synchronize the scroll and line position of the other buffer.
local function synchronize()
  local currview= _VIEWS[view]
  local otherview= vfp2
  if currview == vfp2 then otherview= vfp1 elseif currview ~= vfp1 then return end
  if check_comp_buffers() then
    synchronizing = true
    Proj.stop_update_ui(true)
    local line = buffer:line_from_position(buffer.current_pos)
    local visible_line = buffer:visible_from_doc_line(line)
    local first_visible_line = buffer.first_visible_line
    local x_offset = buffer.x_offset
    Util.goto_view(otherview)
    buffer:goto_line(buffer:doc_line_from_visible(visible_line))
    buffer.first_visible_line, buffer.x_offset = first_visible_line, x_offset
    Util.goto_view(currview)
    Proj.stop_update_ui(false)
    synchronizing = false
  end
end

local function dump_changes(n, buff, r)
  if n > 0 then
    local c= 10
    for i=1, #r, 2 do
      local snum= ('%4d'):format(r[i])
      local line= buff:get_line(r[i]-1)
      buffer:append_text(('  @%s:%s'):format(snum, line))
      c= c-1
      if c == 0 then --only show first 10 blocks
        if i < #r-1 then buffer:append_text('  ...') end
        break
      end
    end
  end
  buffer:append_text('\n')
end

-- Mark the differences between the two buffers.
local function mark_changes(goto_first)
  --if not check_comp_buffers() then return end --already checked
  clear_marked_changes() -- clear previous marks
  -- Perform the diff.
  local buffer1= _VIEWS[vfp1].buffer
  local buffer2= _VIEWS[vfp2].buffer
  filediff.setfile(1, buffer1:get_text()) --#1 = new version (left)
  filediff.setfile(2, buffer2:get_text()) --#2 = old version (right)

  local first, n1, n2 = 0, 0, 0
  -- Parse the diff, marking modified lines and changed text.
  local r1= filediff.getdiff( 1, 1 )
  --enum lines that are only in buffer1
  if #r1 > 0 then first= r1[1] end
  for i=1,#r1,2 do
    n1= n1 + r1[i+1]-r1[i]+1
    for j=r1[i],r1[i+1] do
      buffer1:marker_add(j-1, Proj.MARK_ADDITION)
    end
  end
  --enum lines that are only in buffer2
  local r2= filediff.getdiff( 2, 1 )
  for i=1,#r2,2 do
    n2= n2 + r2[i+1]-r2[i]+1
    for j=r2[i],r2[i+1] do
      buffer2:marker_add(j-1, Proj.MARK_DELETION)
    end
  end
  --enum modified lines
  local rm= filediff.getdiff( 1, 2 )
  if #rm > 0 and (first == 0 or rm[1]<first) then first= rm[1] end
  local n3= #rm / 2
  for i=1, #rm, 2 do
    buffer1:marker_add(rm[i]-1, Proj.MARK_MODIFICATION)
    buffer2:marker_add(rm[i+1]-1, Proj.MARK_MODIFICATION)
  end

  --show the missing lines using annotations
  buffer1._annot_list= filediff.getdiff( 1, 3 ) --buffer#1, 3=get blank lines list
  local r= buffer1._annot_list
  local nr= 0
  if #r > 0 and (first == 0 or r[1]<first) then first= r[1] end
  for i=1,#r,2 do
    buffer1.annotation_text[r[i]-1] = string.rep('\n', r[i+1]-1)
    nr= nr + r[i+1]-1
  end
  buffer1._annot_lines= nr

  --idem buffer #2
  buffer2._annot_list= filediff.getdiff( 2, 3 )--buffer#2, 3=get blank lines list
  r= buffer2._annot_list
  nr= 0
  for i=1,#r,2 do
    buffer2.annotation_text[r[i]-1] = string.rep('\n', r[i+1]-1)
    nr= nr + r[i+1]-1
  end
  buffer2._annot_lines= nr

  --mark text changes
  r= filediff.getdiff( 1, 4 )
  for i=1,#r,3 do
    if r[i] == 1 then
      buffer1.indicator_current = Proj.INDIC_ADDITION
      buffer1:indicator_fill_range(r[i+1], r[i+2])
    else
      buffer2.indicator_current = Proj.INDIC_DELETION
      buffer2:indicator_fill_range(r[i+1], r[i+2])
    end
  end
  if goto_first and first > 0 then buffer1:goto_line(first-1) end
  synchronize()

  if goto_first then
    Proj.clear_search_results()
    --activate/create search view
    Proj.goto_searchview()
    buffer.read_only= false
     --delete search content
    buffer:append_text('[File compare]\n')
    buffer:goto_pos(buffer.length)
    local fn1= buffer1.filename and buffer1.filename or 'left buffer'
    local p,f,e= Util.splitfilename(fn1)
    if f == '' then f= fn1 end
    buffer:append_text((' (+)%4d %s::%s::\n'):format(n1, f, fn1))
    --enum lines that are only in buffer 1
    dump_changes(n1,buffer1,r1)

    local fn2= buffer2.filename and buffer2.filename or 'right buffer'
    p,f,e= Util.splitfilename(fn2)
    if f == '' then f= fn2 end
    buffer:append_text((' (-)%4d %s::%s::\n'):format(n2, f, fn2))
    --enum lines that are only in buffer 2
    dump_changes(n2,buffer2,r2)

    buffer:append_text((' (*)%4d edited lines::%s::\n'):format(n3,fn1))
    --enum modified lines in buffer 1
    dump_changes(n3,buffer1,rm)

    buffer:append_text('\n')
    buffer:set_save_point()
    buffer.read_only= true
    buffer:set_lexer('myproj')
    --return to file #1
    Util.goto_view(vfp1)
  end
end

---- TA EVENTS ----
--TA-EVENT: BUFFER_AFTER_SWITCH or VIEW_AFTER_SWITCH
--clear pending file-diff
function Proj.clear_pend_file_diff()
  if buffer._comparing and not compareon then
    clear_buf_marks(buffer)
    buffer._comparing=nil
  end
end

--TA-EVENT: BUFFER_DELETED
--Stop diff'ing when one of the buffer's being diff'ed is closed
function Proj.check_diff_stop()
  if not check_comp_buffers() then diff_stop() end
end

--TA-EVENT: UPDATE_UI
--Ensure the diff buffers are scrolled in sync
function Proj.EVupdate_ui(updated)
  if updated and not synchronizing and check_comp_buffers() then
    if updated & (buffer.UPDATE_H_SCROLL | buffer.UPDATE_V_SCROLL | buffer.UPDATE_SELECTION) > 0 then
      synchronize()
    end
  end
end

--TA-EVENT: MODIFIED
-- Highlight differences as text is typed and deleted.
function Proj.EVmodified(modification_type)
  if check_comp_buffers() and (modification_type & (0x01 | 0x02)) > 0 then mark_changes(false) end
end

--TA-EVENT: VIEW_NEW
function Proj.EVview_new()
  local markers = {
    [Proj.MARK_ADDITION] = 'green', [Proj.MARK_DELETION] = 'red',
    [Proj.MARK_MODIFICATION] = 'yellow'
  }
  for mark, color in pairs(markers) do
    buffer:marker_define(mark, buffer.MARK_BACKGROUND)
    buffer.marker_back[mark] = buffer.property_int['color.'..color]
  end
  local indicators = {[Proj.INDIC_ADDITION] = 'green', [Proj.INDIC_DELETION] = 'red'}
  for indic, color in pairs(indicators) do
    buffer.indic_style[indic] = buffer.INDIC_FULLBOX
    buffer.indic_fore[indic] = buffer.property_int['color.'..color]
    buffer.indic_alpha[indic], buffer.indic_under[indic] = 255, true
  end
end

---- ACTIONS ----
--ACTION: toggle_filediff
-- Highlight differences between files in left (NEW) / right (OLD) panel
function Proj.diff_start(silent)
  if not Proj then return end
  clear_marked_changes()
  if compareon then
    diff_stop()
    return
  end
  if #_VIEWS < vfp2 then
    ui.statusbar_text= "Can't compare, the right panel is closed"
    return
  end
  if not silent then ui.statusbar_text= "File compare: ON" end

  Proj.stop_update_ui(true)
  Util.goto_view(vfp2)
  buffer.annotation_visible= buffer.ANNOTATION_STANDARD
  buffer._comparing=true

  Util.goto_view(vfp1)
  buffer.annotation_visible= buffer.ANNOTATION_STANDARD
  buffer._comparing=true

  compareon= true
   --goto first change in buffer1 / show some info in search view
  mark_changes(true)

  Proj.stop_update_ui(false)
end
