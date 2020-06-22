-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
-- BASED ON: file_diff module, Copyright 2015-2017 Mitchell mitchell.att.foicica.com. See LICENSE.
--
local Proj = Proj
local Util = Util

Proj.MARK_ADDITION = _SCINTILLA.next_marker_number()
Proj.MARK_DELETION = _SCINTILLA.next_marker_number()
Proj.MARK_MODIFICATION = _SCINTILLA.next_marker_number()
Proj.INDIC_ADDITION = _SCINTILLA.next_indic_number()
Proj.INDIC_DELETION = _SCINTILLA.next_indic_number()

local vfp1= 1
local vfp2= 2
local synchronizing= false
local marking= false
Proj.is_compare_on= false
Proj.is_svn_on= false

local function clear_buf_marks(b, clrflags)
  if b then
    for _, mark in ipairs{Proj.MARK_ADDITION, Proj.MARK_DELETION, Proj.MARK_MODIFICATION} do
      b:marker_delete_all(mark)
    end
    for _, indic in ipairs{Proj.INDIC_ADDITION, Proj.INDIC_DELETION} do
      b.indicator_current = indic
      b:indicator_clear_range(Util.LINE_BASE, b.length)
    end
    b:annotation_clear_all()
    if clrflags then b._comparing= nil end
  end
end

--check nv is a valid view with a buffer
local function check_vfp(nv)
  if nv and nv > 0 and nv <= #_VIEWS then
    if _VIEWS[nv].buffer then return true end
  end
  return false
end

local function clear_view_marks(nview, clrflags)
  if check_vfp(nview) then clear_buf_marks(_VIEWS[nview].buffer, clrflags) end
end

-- Clear markers, indicators, and placeholder lines.
-- Used when re-marking changes or finished diff'ing.
local function clear_marked_changes(clrflags)
  clear_view_marks(vfp1, clrflags)
  clear_view_marks(vfp2, clrflags)
end

local function update_comp_actions()
  if actions then
    actions.updateaction("toggle_filediff")
    actions.updateaction("vc_changes")
  end
  --force to select the current file in the tab bar
  if toolbar then toolbar.seltabbuf(buffer) end
end

-- Stops diff'ing.
local function diff_stop()
  if Proj.is_compare_on then
    Proj.is_compare_on= false
    Proj.is_svn_on= false
    clear_marked_changes(true)
    plugs.close_results()
    ui.statusbar_text= "File compare: OFF"
    update_comp_actions()
  end
end

--check that the buffers in both view hasn't changed
local function check_comp_buffers()
  if Proj.is_compare_on and check_vfp(vfp1) and check_vfp(vfp2) then
    local b1= _VIEWS[vfp1].buffer
    local b2= _VIEWS[vfp2].buffer
    --NOTE: when the last file in a view is closed, the same buffer can be in more than one view
    -- until the view is closed (check: b1 ~= b2)
    if (b1 ~= b2) and b1._comparing and b2._comparing then return true end
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

-- Mark the differences between the two buffers.
local function mark_changes(goto_first)
  --if not check_comp_buffers() then return end --already checked
  if marking then return end
  marking= true

  clear_marked_changes(false) -- clear previous marks
  -- Perform the diff.
  local buffer1= _VIEWS[vfp1].buffer
  local buffer2= _VIEWS[vfp2].buffer
  filediff.setfile(1, buffer1:get_text()) --#1 = new version (left)
  filediff.setfile(2, buffer2:get_text()) --#2 = old version (right)

  --add/mod/del lines for minimap display
  buffer1._mark_add= {}
  buffer1._mark_del= {}
  buffer1._mark_mod= {}
  buffer2._mark_add= {}
  buffer2._mark_del= {}
  buffer2._mark_mod= {}

  local first, n1, n2 = 0, 0, 0
  -- Parse the diff, marking modified lines and changed text.
  local r1= filediff.getdiff( 1, 1 )
  local n= 1
  --enum lines that are only in buffer1
  if #r1 > 0 then first= r1[1] end
  for i=1,#r1,2 do
    n1= n1 + r1[i+1]-r1[i]+1
    for j=r1[i],r1[i+1] do
      buffer1:marker_add(j-1+Util.LINE_BASE, Proj.MARK_ADDITION)
      buffer1._mark_add[n]= j
      n= n+1
    end
  end
  --enum lines that are only in buffer2
  local r2= filediff.getdiff( 2, 1 )
  n= 1
  for i=1,#r2,2 do
    n2= n2 + r2[i+1]-r2[i]+1
    for j=r2[i],r2[i+1] do
      buffer2:marker_add(j-1+Util.LINE_BASE, Proj.MARK_DELETION)
      buffer2._mark_del[n]= j
      n= n+1
    end
  end
  --enum modified lines
  local rm= filediff.getdiff( 1, 2 )
  if #rm > 0 and (first == 0 or rm[1]<first) then first= rm[1] end
  local n3= #rm // 2
  n= 1
  for i=1, #rm, 2 do
    buffer1:marker_add(rm[i]-1+Util.LINE_BASE, Proj.MARK_MODIFICATION)
    buffer2:marker_add(rm[i+1]-1+Util.LINE_BASE, Proj.MARK_MODIFICATION)
    buffer1._mark_mod[n]= rm[i]
    buffer2._mark_mod[n]= rm[i+1]
    n= n+1
  end

  --show the missing lines using annotations
  local r= filediff.getdiff( 1, 3 ) --buffer#1, 3=get blank lines list
  if #r > 0 and (first == 0 or r[1]<first) then first= r[1] end
  for i=1,#r,2 do
    buffer1.annotation_text[r[i]-1+Util.LINE_BASE] = string.rep('\n', r[i+1]-1)
    buffer1._mark_del[#buffer1._mark_del+1]= r[i]
  end

  --idem buffer #2
  r= filediff.getdiff( 2, 3 )--buffer#2, 3=get blank lines list
  for i=1,#r,2 do
    buffer2.annotation_text[r[i]-1+Util.LINE_BASE] = string.rep('\n', r[i+1]-1)
    buffer2._mark_add[#buffer2._mark_add+1]= r[i]
  end

  --mark text changes
  r= filediff.getdiff( 1, 4 )
  for i=1,#r,3 do
    if r[i] == 1 then
      buffer1.indicator_current = Proj.INDIC_ADDITION
      buffer1:indicator_fill_range(r[i+1]+Util.LINE_BASE, r[i+2])
    else
      buffer2.indicator_current = Proj.INDIC_DELETION
      buffer2:indicator_fill_range(r[i+1]+Util.LINE_BASE, r[i+2])
    end
  end
  if goto_first and first > 0 then buffer1:goto_line(first-1+Util.LINE_BASE) end
  synchronize()
  --load some info in the results view the first time the files are compared
  if goto_first then plugs.compare_file_result(n1, buffer1, r1, n2, buffer2, r2, n3, rm) end
  marking= false
end

---- TA EVENTS ----
--TA-EVENT: BUFFER_AFTER_SWITCH or VIEW_AFTER_SWITCH
--clear pending file-diff
function Proj.clear_pend_file_diff()
  if Proj.is_compare_on then
    if not check_comp_buffers() then diff_stop() end
  elseif buffer._comparing then clear_buf_marks(buffer, true) end
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
if Util.TA_MAYOR_VER < 11 then  --TA10
  function Proj.EVmodified(modification_type)
    if not marking and check_comp_buffers() and (modification_type & (0x01 | 0x02)) > 0 then mark_changes(false) end
  end
else  --TA11
  function Proj.EVmodified(position, modification_type)
    if not marking and check_comp_buffers() and (modification_type & (0x01 | 0x02)) > 0 then mark_changes(false) end
  end
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
function Proj.compare_status()
  return ((Proj.is_compare_on and not Proj.is_svn_on) and 1 or 2) --check
end
function Proj.diff_start(silent)
  if Proj.is_compare_on then diff_stop() return end

  --set the views used for files
  vfp1= Proj.get_projview(Proj.PRJV_FILES)
  vfp2= Proj.get_projview(Proj.PRJV_FILES_2)
  if not check_vfp(vfp2) then
    ui.statusbar_text= "Can't compare, the right panel is closed"
    update_comp_actions()
    return
  end
  if not silent then ui.statusbar_text= "File compare: ON" end

  Proj.stop_update_ui(true)
  Util.goto_view(vfp2)
  buffer.annotation_visible= buffer.ANNOTATION_STANDARD
  buffer._comparing= true

  Util.goto_view(vfp1)
  buffer.annotation_visible= buffer.ANNOTATION_STANDARD
  buffer._comparing= true

  Proj.is_compare_on= true
   --goto first change in buffer1 / show some info in search view
  mark_changes(true)

  Proj.stop_update_ui(false)
  update_comp_actions()
end

--ACTION: vc_changes
--Version control SVN/GIT changes
function Proj.vc_changes_status()
  return (Proj.is_svn_on and 1 or 2) --check
end
function Proj.vc_changes()
  Proj.goto_filesview(Proj.FILEPANEL_LEFT)
  local orgbuf= buffer
  if Proj.is_svn_on then
    diff_stop() --clear marks
    --close right file (svn HEAD)
    Proj.goto_filesview(Proj.FILEPANEL_RIGHT)
    Proj.close_buffer()
    Proj.goto_filesview(Proj.FILEPANEL_LEFT)
    Util.goto_buffer(orgbuf)
    plugs.close_results()
    ui.statusbar_text= "Compare to HEAD: OFF"
    update_comp_actions()
    return
  end

  diff_stop() --stop posible file compare
  local orgfile= buffer.filename
  if orgfile then
    --get version control params for filename
    local verctrl, cwd, url= Proj.get_versioncontrol_url(orgfile)
    if url then
      Proj.is_svn_on= true
      local enc= buffer.encoding     --keep encoding
      local lex= buffer:get_lexer()  --keep lexer
      local eol= buffer.eol_mode     --keep EOL
      --new buffer
      if actions then actions.run("new") else Proj.new_file() end
      buffer.filename= orgfile..":HEAD"
      local cmd
      if verctrl == 1 then
        cmd= "svn cat "..url
        path=nil
      else
        cmd= "git show HEAD:"..url
      end
      local p = assert(os.spawn(cmd,cwd))
      p:close()
      buffer:set_text((p:read('*a') or ''):iconv('UTF-8', enc))
      if enc ~= 'UTF-8' then buffer:set_encoding(enc) end
      --force the same EOL (git changes EOL when needed)
      buffer.eol_mode= eol
      buffer:convert_eols(eol)
      buffer:set_lexer(lex)
      buffer.read_only= true
      buffer:set_save_point()
      --show in the right panel
      Proj.toggle_showin_rightpanel()
      Proj.goto_filesview(Proj.FILEPANEL_LEFT)
      Util.goto_buffer(orgbuf)
      --compare files (keep statusbar text)
      Proj.diff_start(true)
    end
    update_comp_actions()
  end
end
