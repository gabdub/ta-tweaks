-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.
local events = events
local Proj = Proj
local data = Proj.data
local Util = Util

local last_print_buftype

--  Proj.update_ui= number of ui updates in progress (ignore some events if > 0)
Proj.update_ui= 0

function Proj.stop_update_ui(onoff)
  if onoff then
    --prevent some events to fire
    Proj.update_ui= Proj.update_ui+1
    if Proj.update_ui == 1 then
      --stop updating global buffer info like windows title / status bar
      if toolbar then toolbar.updatebuffinfo(false) end
    end
  else
    --restore normal mode
    Proj.update_ui= Proj.update_ui-1
    if Proj.update_ui == 0 then
      --update pending changes to global buffer info
      if toolbar then toolbar.updatebuffinfo(true) end
    end
  end
end

--don't update the UI until Proj.EVinitialize is called
Proj.stop_update_ui(true)

-- TA-EVENT INITIALIZED
function Proj.EVinitialize()
  --after session load ends, verify all the buffers (this prevents view creation conflicts)
  Proj.stop_update_ui(false)

  --load recent projects list / project preferences
  Proj.load_config()
  --check if search results is open
  for _, buff in ipairs(_BUFFERS) do
    if buff._type == Proj.PRJT_SEARCH then
      --activate search view
      Proj.goto_searchview()
      buff.read_only= true
      break
    end
  end
  --check if a project file is open
  --TODO: mark rigth side files
  for _, buff in ipairs(_BUFFERS) do
    --check buffer type
    local pt= Proj.get_buffertype(buff)
    if pt == Proj.PRJB_PROJ_NEW or pt == Proj.PRJB_PROJ_SELECT then
      data.filename= buff.filename
      --activate project in the proper view
      Proj.goto_projview(Proj.PRJV_PROJECT)
      Util.goto_buffer(buff)
      if Proj.is_visible == 2 then
        --2:shown in edit mode
        Proj.ifproj_seteditmode(buff)
      else
        --0:hidden  1:shown in selection mode
        Proj.ifproj_setselectionmode(buff)
        Proj.is_visible= Proj.data.config.is_visible  --keep 0 is hidden
      end
      --start in left/only files view
      Proj.goto_filesview(true)
      --check that at least there's one regular buffer
      local rbuf = Proj.getFirstRegularBuf(1)
      if rbuf == nil then
        --no regular buffer found
        Proj.go_file() --open a blank file
      end
      Proj.update_projview() --update toggle project view button
      return
    end
  end
  --no project file found
  Proj.closed_cleardata() --clear Proj.data and notify end of config load
  Proj.update_after_switch()
  Proj.update_projview() --gray toggle project view button
end

-- TA-EVENT QUIT: Saves recent projects list
function Proj.EVquit()
  Proj.save_config()
end

--------buffer functions----------
--get the buffer type: Proj.PRJT_...
function Proj.get_buffertype(p_buffer)
  if not p_buffer then p_buffer = buffer end  --use current buffer?

  if p_buffer._project_select ~= nil then  --marked as a project file?
    if p_buffer._is_working_project then
      if p_buffer._project_select then
        return Proj.PRJB_PROJ_SELECT  --is a project in "selection mode"
      end
      return Proj.PRJB_PROJ_EDIT      --is a project in "edit mode"
    end
    return Proj.PRJB_PROJ_IDLE        --is a project (but not the working one)
  end
  if p_buffer._type == Proj.PRJT_SEARCH then
    return Proj.PRJB_FSEARCH          --is a search results buffer
  end
  --check if the current file is a valid project
  --The first file line MUST BE a valid "option 1)": ...##...##...
  local line= p_buffer:get_line(0)
  local n, fn, opt = string.match(line,'^%s*(.-)%s*::(.*)::(.-)%s*$')
  if n ~= nil then
    return Proj.PRJB_PROJ_NEW         --is a project file not marked as such yet
  end
  return Proj.PRJB_NORMAL             --is a regular file
end

--returns true if buffer is a regular file (not a project nor a search results)
function Proj.isRegularBuf(pbuffer)
  return (pbuffer._project_select == nil) and (pbuffer._type ~= Proj.PRJT_SEARCH)
end

--find the first regular buffer
--panel=0 (any), panel=1 (_right_side=false), panel=2 (_right_side=true)
--TO DO: use MRU order
function Proj.getFirstRegularBuf(panel)
  for _, buf in ipairs(_BUFFERS) do
    if Proj.isRegularBuf(buf) then
      if (panel==0) or ((panel==1) and (not buf._right_side)) or ((panel==2) and (buf._right_side)) then return buf end
    end
  end
  return nil
end


--------hilight project's open files--------
local indic_open = _SCINTILLA.next_indic_number()
buffer.indic_fore[indic_open]= (tonumber(buffer.property['color.prj_open_mark']) or 0x404040)
buffer.indic_style[indic_open]= buffer.INDIC_DOTS

--remove all open-indicators from project
function Proj.clear_open_indicators(pbuf)
  pbuf.indicator_current= indic_open
  pbuf:indicator_clear_range(0,pbuf.length-1)
end

function Proj.add_open_indicator(pbuf,row)
  pbuf.indicator_current= indic_open
  local pos= pbuf.line_indent_position[row]
  local len= pbuf.line_end_position[row] - pos
  pbuf:indicator_fill_range(pos,len)
end

--if buff is a project's file, hilight it with and open-indicator
function Proj.show_open_indicator(pbuf,buff)
  --ignore project and search buffers
  if buff._project_select == nil and buff._type == nil then
    local file= buff.filename
    if file then
      local row= Proj.get_file_row(file)
      if row then
        Proj.add_open_indicator(pbuf,row-1)
      end
    end
  end
end

--add and open-indicator to all project's files that are open
function Proj.mark_open_files(pbuf)
  if pbuf then
    Proj.clear_open_indicators(pbuf)
    if pbuf._project_select then --only in selection mode
      for _, b in ipairs(_BUFFERS) do
        Proj.show_open_indicator(pbuf,b)
      end
    end
  end
end

--check/force the buffer is in the preferred view
function Proj.force_buffer_inview(pbuf, nprefv)
  --locate the buffer view
  local nview
  --check "visible" buffers
  for i= 1, #_VIEWS do
    if _VIEWS[i].buffer == pbuff then
      nview = i
      break
    end
  end
  if nview ~= nprefv then
    --show the buffer in the preferred view
    Proj.stop_update_ui(true)
    local nv= _VIEWS[view]    --save actual view
    Util.goto_view(nprefv)    --goto preferred view
    Util.goto_buffer(pbuff)   --show the buffer
    Util.goto_view(nv)        --restore actual view
    Proj.stop_update_ui(false)
  end
end

-----------------CURRENT LINE-------------------
--project is in SELECTION mode with focus--
function Proj.show_sel_w_focus(buff)
  --hide line numbers
  buff.margin_width_n[0] = 0
  --highlight current line as selected
  buff.caret_width= 0
  buff.caret_line_back = buff.property['color.prj_sel_bar']
end

-- project in SELECTION mode without focus--
function Proj.show_lost_focus(buff)
  if (Proj.update_ui == 0 and buffer._project_select) or (buff ~= nil) then
    if buff == nil then buff= buffer end
    buff.caret_line_back = buff.property['color.prj_sel_bar_nof']
  end
end

--restore current line default settings
function Proj.show_default(buff)
  --project in EDIT mode / default text file--
  --show line numbers
  local width = 4 * buff:text_width(buffer.STYLE_LINENUMBER, '9')
  buff.margin_width_n[0] = width + (not CURSES and 4 or 0)
  --return to default
  buff.caret_width= 2
  buff.caret_line_back = buff.property['color.curr_line_back']
end

--set/restore lexer/ui after a buffer/view switch
function Proj.update_after_switch()
  --if we are updating, ignore this event
  if Proj.update_ui > 0 then return end
  Proj.stop_update_ui(true)
  if buffer._project_select == nil then
    --normal file: restore current line default settings
    Proj.show_default(buffer)
    if buffer._type == Proj.PRJT_SEARCH then
      --set search context menu
      Proj.set_contextm_search()
    else
      --set regular file context menu
      Proj.set_contextm_file()
      --try to select the current file in the project
      Proj.track_this_file()
    end
    --refresh some options (when views are closed this is mixed)
    --the current line is not always visible
    buffer.caret_line_visible_always= false
    --and the scrollbars shown
    buffer.h_scroll_bar= true
    if toolbar then
      buffer.v_scroll_bar= not toolbar.tbreplvscroll --minimap replace V scrollbar
    else
      buffer.v_scroll_bar=true
    end

  else
    --project buffer--
    --only process if in the project preferred view
    --(this prevents some issues when the project is shown in two views at the same time)
    local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
    if _VIEWS[view] == projv then
      if buffer._project_select then
        -- project in SELECTION mode: set "myprog" lexer --
        buffer:set_lexer('myproj')
        --project in SELECTION mode--
        Proj.show_sel_w_focus(buffer)
        --set SELECTION mode context menu
        Proj.set_contextm_sel()
      else
        -- project in EDIT mode: restore current line default settings --
        Proj.show_default(buffer)
        --set EDIT mode context menu
        Proj.set_contextm_edit()
      end
      --refresh some options (when views are closed this is mixed)
      --in SELECTION mode the current line is always visible
      buffer.caret_line_visible_always= buffer._project_select
      --and the scrollbars hidden
      buffer.h_scroll_bar= not buffer._project_select
      buffer.v_scroll_bar= buffer.h_scroll_bar
    end
  end
  Proj.stop_update_ui(false)
end

--try to select the current file in the working project
--(only if the project is currently visible)
function Proj.track_this_file()
  local p_buffer = Proj.get_projectbuffer(false)
  --only track the file if the project is visible and in SELECTION mode and is not an special buffer
  if p_buffer and p_buffer._project_select and buffer._type == nil then
    --get file path
    local file= buffer.filename
    if file ~= nil then
      row= Proj.get_file_row(file)
      if row ~= nil then
        --prevent some events to fire for ever
        Proj.stop_update_ui(true)

        local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
        Util.goto_view(projv)
        --move the selection bar
        p_buffer:ensure_visible_enforce_policy(row- 1)
        p_buffer:goto_line(row-1)
        p_buffer:home()
        --hilight the file as open
        Proj.add_open_indicator(p_buffer,row-1)
         -- project in SELECTION mode without focus--
        Proj.show_lost_focus(p_buffer)
        --return to this file (it could be in a different view)
        Proj.go_file(file)

        Proj.stop_update_ui(false)
      end
    end
  end
end

------------------ TA-EVENTS -------------------
-- TA-EVENT BUFFER_AFTER_SWITCH or VIEW_AFTER_SWITCH
function Proj.EVafter_switch()
  --set/restore lexer/ui after a buffer/view switch
  Proj.update_after_switch()
  --clear pending file-diff
  Proj.clear_pend_file_diff()
end

-- TA-EVENT BUFFER_NEW
function Proj.EVbuffer_new()
  --when a buffer is created in the right panel, mark it as such
  if _VIEWS[view] == Proj.prefview[Proj.PRJV_FILES_2] then buffer._right_side=true end
end

-- TA-EVENT BUFFER_DELETED
function Proj.EVbuffer_deleted()
  --update open files hilight if the project is visible and in SELECTION mode
  local pbuf = Proj.get_projectbuffer(false)
  if pbuf and pbuf._project_select then
    Proj.mark_open_files(pbuf)
  end
  --Stop diff'ing when one of the buffer's being diff'ed is closed
  Proj.check_diff_stop()
end

-- TA-EVENT FILE_OPENED
--if the current file is a project, enter SELECTION mode--
function Proj.EVfile_opened()
  --if the file is open in the right panel, mark it as such
  if _VIEWS[view] == Proj.prefview[Proj.PRJV_FILES_2] then buffer._right_side=true end
  --ignore session load
  if Proj.update_ui == 0 then
    --open project in selection mode
    Proj.ifproj_setselectionmode()
    -- Closes the initial "Untitled" buffer (project version)
    -- only when a regular file is opened
    -- #3: project + untitled + file
    -- #4: project + search results + untitled + file
    -- TO DO: improve this (see check_panels())
    if buffer.filename and (buffer._project_select == nil) and (#_BUFFERS == 3 or #_BUFFERS == 4) then
      for nbuf,buf in ipairs(_BUFFERS) do
        if not (buf.filename or buf._type or buf.modify or buf._project_select ~= nil) then
          Util.goto_buffer(buf)
          io.close_buffer()
          break
        end
      end
    end
  end
end

--open the selected file in the search view
function Proj.open_search_file()
  --clear selection
  buffer.selection_start= buffer.selection_end
  --get line number, format: " @ nnn:....."
  local line_num = buffer:get_cur_line():match('^%s*@%s*(%d+):.+$')
  local file
  if line_num then
    --get file name from previous lines
    for i = buffer:line_from_position(buffer.current_pos) - 1, 0, -1 do
      file = buffer:get_line(i):match('^[^@]-::(.+)::.+$')
      if file then break end
    end
  else
    --just open the file
    file= buffer:get_cur_line():match('^[^@]-::(.+)::.+$')
  end
  if file then
    textadept.bookmarks.clear()
    textadept.bookmarks.toggle()
    -- Store the current position in the jump history if applicable, clearing any
    -- jump history positions beyond the current one.
    Proj.store_current_pos(true)
    Proj.go_file(file, line_num)
    -- Store the current position at the end of the jump history.
    Proj.append_current_pos()
  end
end

local function open_proj_currrow()
  if buffer._project_select then
    Proj.open_sel_file()
  elseif buffer._type == Proj.PRJT_SEARCH then
    Proj.open_search_file()
  end
end

-- TA-EVENT DOUBLE_CLICK
function Proj.EVdouble_click(_, line) open_proj_currrow() end

-- TA-EVENT KEYPRESS
function Proj.EVkeypress(code)
  local ks= keys.KEYSYMS[code]
  if ks == '\n' or ks == 'kpenter' then  --"Enter" or "Return"
    open_proj_currrow()
    if Proj.temporal_view then
      Proj.temporal_view= false
      Proj.toggle_projview()
    end
  elseif ks == 'esc' then --"Escape"
    --1) try to close config panel
    if toolbar and toolbar.hide_config() then
      return
    end
    --2) try to close search view (only if there are not more views)
    if #_VIEWS ~= Proj.prefview[Proj.PRJV_SEARCH] or not Proj.close_search_view() then
      --3) change view
      if #_VIEWS > 1 then
        local nv= _VIEWS[view] +1
        if nv > #_VIEWS then nv=1 end
        Util.goto_view(nv)
        if nv == Proj.prefview[Proj.PRJV_PROJECT] and Proj.is_visible == 0 then
          --in project's view, force visibility
          Proj.is_visible= 1  --1:shown in selection mode
          view.size= Proj.select_width
          Proj.update_projview()
          Proj.temporal_view= true  --close if escape is again pressed or a file is opened

        elseif Proj.temporal_view then
          Proj.temporal_view= false
          Proj.toggle_projview()
        end
      end
    end
  end
end

--toggle project between selection and EDIT modes
function Proj.change_proj_ed_mode()
  if buffer._project_select ~= nil then
    --project: toggle mode
    if view.size ~= nil then
      if buffer._project_select then
        if Proj.select_width ~= view.size then
          Proj.select_width= view.size  --save current width
          if Proj.select_width < 50 then Proj.select_width= 200 end
          data.recent_prj_change= true  --save it on exit
        end
        Proj.is_visible= 2  --2:shown in edit mode
        view.size= Proj.edit_width
      else
        if Proj.edit_width ~= view.size then
          Proj.edit_width= view.size  --save current width
          if Proj.edit_width < 50 then Proj.edit_width= 600 end
          data.recent_prj_change= true  --save it on exit
        end
        Proj.is_visible= 1  --1:shown in selection mode
        view.size= Proj.select_width
      end
    end
    Proj.toggle_selectionmode()
    buffer.colourise(buffer, 0, -1)
    Proj.update_projview()
  else
    --file: goto project view
    Proj.show_projview()
  end
end

local function ena_toggle_projview()
  local ena= Proj.get_projectbuffer(true)
  Proj.update_projview() --update action: toggle_viewproj
  return ena
end

function Proj.show_projview()
  --Show project / goto project view
  if Proj.get_projectbuffer(true) then
    Proj.goto_projview(Proj.PRJV_PROJECT)
    if Proj.is_visible == 0 then
      Proj.is_visible= 1  --1:shown in selection mode
      view.size= Proj.select_width
      Proj.update_projview()
    end
  end
end

--Show/Hide project
function Proj.show_hide_projview()
  if ena_toggle_projview() then
    if Proj.isin_editmode() then
      --project in edit mode
      Proj.goto_projview(Proj.PRJV_PROJECT)
      Proj.change_proj_ed_mode() --return to select mode
      return
    end
    --select mode
    Proj.goto_projview(Proj.PRJV_PROJECT)
    if view.size then
      if Proj.is_visible > 0 then
        Proj.is_visible= 0  --0:hidden
        if Proj.select_width ~= view.size then
          Proj.select_width= view.size  --save current width
          if Proj.select_width < 50 then Proj.select_width= 200 end
          data.recent_prj_change= true  --save it on exit
        end
        view.size= 0
      else
        Proj.is_visible= 1  --1:shown in selection mode
        view.size= Proj.select_width
      end
      Proj.update_projview()
    end
    Proj.goto_filesview(true)
  end
end

function Proj.update_projview()
  --update toggle project view button
  if toolbar then actions.updateaction("toggle_viewproj") end
end

-- TA-EVENT TAB_CLICKED
function Proj.EVtabclicked(ntab)
  --tab clicked (0...) check if a view change is needed
  if #_VIEWS > 1 then
    if _BUFFERS[ntab]._project_select ~= nil then
      --project buffer: force project view
      local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
      Util.goto_view(projv)
    --search results?
    elseif _BUFFERS[ntab]._type == Proj.PRJT_SEARCH then Proj.goto_searchview()
    --normal file: check we are not in a project view
    else Proj.goto_filesview(false, _BUFFERS[ntab]._right_side) end
  end
end

--goto the view for the requested project buffer type
--split views if needed
function Proj.goto_projview(prjv)
  local pref= Proj.prefview[prjv] --preferred view for this buffer type
  if pref == _VIEWS[view] then
    return  --already in the right view
  end
  local nv= #_VIEWS
  while pref > nv do
    --more views are needed: split the last one
    local porcent  = Proj.prefsplit[nv][1]
    local vertical = Proj.prefsplit[nv][2]
    Util.goto_view(Proj.prefsplit[nv][3])
    --split view to show search results
    view:split(vertical)
    --adjust view size (actual = 50%)
    view.size= math.floor(view.size*porcent*2)
    nv= nv +1
    if nv == Proj.prefview[Proj.PRJV_FILES] then
      --create an empty file
      Util.goto_view(nv)
      buffer.new()
      events.emit(events.FILE_OPENED)
    elseif nv == Proj.prefview[Proj.PRJV_SEARCH] then
      --create an empty search results buffer
      Util.goto_view(nv)
      buffer.new()
      buffer._type = Proj.PRJT_SEARCH
      events.emit(events.FILE_OPENED)
    end
  end
  Util.goto_view(pref)
end

function Proj.goto_filesview(dontprjcheck, right_side)
  --goto the view for editing files, split views if needed
  if dontprjcheck or Proj.get_projectbuffer(false) ~= nil then
    --if a project is open, this will create all the needed views
    if right_side then Proj.goto_projview(Proj.PRJV_FILES_2) else Proj.goto_projview(Proj.PRJV_FILES) end
  elseif right_side then
    --if no project is open, view #2 is the right_side panel
    if #_VIEWS == 1 then
      view:split(true)
    end
    if _VIEWS[view] == 1 then Util.goto_view(2) end
  else
    --if no project is open, view #1 is the left/only panel
    if _VIEWS[view] ~= 1 then Util.goto_view(1) end
  end
end

--if the current view is a project or project-search, goto left/only files view. if not, keep the current view
function Proj.getout_projview(right_side)
  if (buffer._project_select ~= nil or buffer._type ~= nil) then
    --move to files view (left/only panel) and exit
    Proj.goto_filesview(true,right_side)
    return true
  end
  return false
end

function Proj.goto_buffer(nb)
  local b= _BUFFERS[nb]
  if b == nil then return end
  if b._project_select ~= nil then
    --activate project in the proper view
    Proj.goto_projview(Proj.PRJV_PROJECT)
  elseif b._type == Proj.PRJT_SEARCH then
    --activate project in the proper view
    Proj.goto_searchview()
  else
    --activate files view
    Proj.goto_filesview(true, b._right_side)
    Util.goto_buffer(b)
  end
end

------SEARCH VIEW------
--activate/create search view
function Proj.goto_searchview()
  --goto the view for search results, split views and create empty buffers if needed
  Proj.goto_projview(Proj.PRJV_SEARCH)
  --goto search results view
  if buffer._type ~= Proj.PRJT_SEARCH then
    for nbuf, sbuf in ipairs(_BUFFERS) do
      if sbuf._type == Proj.PRJT_SEARCH then
        Util.goto_buffer(sbuf)
        return
      end
    end
  end
end

function Proj.clear_search_results()
  local sv= Proj.prefview[Proj.PRJV_SEARCH]
  if #_VIEWS < sv then return false end
  Proj.beg_search_add()
   --delete search content
  textadept.bookmarks.clear()
  Proj.remove_search_from_pos_table()
  buffer:set_text('')
  Proj.end_search_add()
end

--goto search view and activate text modifications
function Proj.beg_search_add()
  Proj.goto_searchview()
  buffer.read_only= false
end

--end search text modifications
function Proj.end_search_add(buftype)
  buffer:set_save_point()
  buffer.read_only= true
  buffer:set_lexer('myproj')
  last_print_buftype= buftype
end

function Proj.close_search_view()
  local sv= Proj.prefview[Proj.PRJV_SEARCH]
  --if more views are open, ignore the close
  if #_VIEWS > sv then return false end
  last_print_buftype=''
  if #_VIEWS == sv then
    --remove search from position table
    Proj.remove_search_from_pos_table()
    --activate search view
    Proj.goto_searchview()
    --close buffer / view
    buffer:set_save_point()
    io.close_buffer()
    Util.goto_view( sv -1 )
    view.unsplit(view)
    return true
  end
  --no search view, try to close the search buffer
  for _, sbuffer in ipairs(_BUFFERS) do
    if sbuffer._type == Proj.PRJT_SEARCH then
      --goto search results view
      if view.buffer._type ~= Proj.PRJT_SEARCH then
        Util.goto_buffer(sbuffer)
      end
      io.close_buffer()
      break
    end
  end
  return false
end

function Proj.check_leftpanel()
  --check the left/only panel content
  local vfp1= Proj.prefview[Proj.PRJV_FILES]
  if #_VIEWS >= vfp1 then
    --goto left view
    Util.goto_view(vfp1)
    --check current file
    if not Proj.isRegularBuf(buffer) or buffer._right_side then
      --it is not a proper file for this panel, find one or open a blank one
      local bl= Proj.getFirstRegularBuf(1)
      if bl then Util.goto_buffer(bl) else Proj.go_file() end
    end
  end
end

function Proj.check_searchpanel()
  local vsp= Proj.prefview[Proj.PRJV_SEARCH]
  if #_VIEWS >= vsp then
    Proj.goto_searchview()
  end
end

function Proj.check_rightpanel()
  --if the right panel is open, check it
  local vfp2= Proj.prefview[Proj.PRJV_FILES_2]
  if #_VIEWS >= vfp2 then
    --goto right view
    Util.goto_view(vfp2)
    --check current file
    if not Proj.isRegularBuf(buffer) or not buffer._right_side then
      --it is not a proper file for this panel, find one or close the panel
      local br= Proj.getFirstRegularBuf(2)
      if br then Util.goto_buffer(br) else
        view.unsplit(view)
        Proj.close_search_view()  --close search view too (TODO: don't close search view)
      end
    end
  end
end

--check the buffer type of every open view
function Proj.check_panels()
  Proj.stop_update_ui(true)
  local actv= _VIEWS[view]
  Proj.check_rightpanel()
  Proj.check_searchpanel()
  Proj.check_leftpanel()
  if #_VIEWS >= actv then Util.goto_view(actv) end
  Proj.stop_update_ui(false)
end

-------- overwrite default ui._print function -----
-- Helper function for printing messages to buffers.
local function proj_print(buffer_type, ...)
  --print allways in search-view
  Proj.beg_search_add()
  --show buffer_type when changed
  if last_print_buftype ~= buffer_type then buffer:append_text(buffer_type..'\n') end
  buffer:goto_pos(buffer.length)
  local args, n = {...}, select('#', ...)
  for i = 1, n do args[i] = tostring(args[i]) end
  buffer:append_text(table.concat(args, '\t'))
  buffer:append_text('\n')
  Proj.end_search_add(buffer_type)
end
function ui._print(buffer_type, ...) pcall(proj_print, buffer_type, ...) end

-- replace Open uri(s) code (core/ui.lua)
function Proj.drop_uri(utf8_uris)
  ui.goto_view(view) -- work around any view focus synchronization issues
  Proj.goto_filesview() --don't drop files in project views
  for utf8_uri in utf8_uris:gmatch('[^\r\n]+') do
    if utf8_uri:find('^file://') then
      local uri = utf8_uri:iconv(_CHARSET, 'UTF-8')
      uri = uri:match('^file://([^\r\n]+)'):gsub('%%(%x%x)', function(hex)
        return string.char(tonumber(hex, 16))
      end)
      -- In WIN32, ignore a leading '/', but not '//' (network path).
      if WIN32 and not uri:match('^//') then uri = uri:sub(2, -1) end
      local mode = lfs.attributes(uri, 'mode')
      if mode and mode ~= 'directory' then io.open_file(uri) end
    end
  end
  Proj.update_after_switch()
  return false
end
