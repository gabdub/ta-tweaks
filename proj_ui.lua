local events, events_connect = events, events.connect
local Proj = Proj
local _L = _L

-----------------CURRENT LINE-------------------
--project is in SELECTION mode with focus--
local function proj_show_sel_w_focus(buff)
  --hide line numbers
  buff.margin_width_n[0] = 0
  --highlight current line as selected
  buff.caret_width= 0
  buff.caret_line_back = 0x88acdf --property['color.base10'] -0x202020
end

--lost focus: if project is in SELECTION mode change current line
function Proj.show_lost_focus(p_buffer)
  if (Proj.updating_ui == 0 and buffer._project_select) or (p_buffer ~= nil) then
    if p_buffer == nil then p_buffer= buffer end
    -- project in SELECTION mode without focus--
    p_buffer.caret_line_back = 0xa8ccff --property['color.base10']
  end
end

--restore current line default settings
local function proj_show_default(buff)
  --project in EDIT mode / default text file--
  --show line numbers
  local width = 4 * buff:text_width(buffer.STYLE_LINENUMBER, '9')
  buff.margin_width_n[0] = width + (not CURSES and 4 or 0)
  --return to default
  buff.caret_width= 2
  buff.caret_line_back = 0xf5f9ff --property['color.base06']
end

-----------------MENU/CONTEXT MENU-------------------
--init desired project context menu
local function proj_context_menu_init(num)
  if CURSES or Proj.cmenu_num == num then
    --CURSES or the menu is already set, don't change the context menu
    return false
  end
  Proj.cmenu_num= num

  if Proj.cmenu_idx == nil then
    --first time here, add project menu at the end of context menu
    Proj.cmenu_idx= #textadept.menu.context_menu +1
    --add Project to menubar (keep Help at the end)
    n= #textadept.menu.menubar
    textadept.menu.menubar[n+1]= textadept.menu.menubar[n]
    textadept.menu.menubar[n]= {
      title='Project',
      {_L['_New'],            Proj.new_project},
      {_L['_Open'],           Proj.open_project},
      {_L['Open _Recent...'], Proj.open_recent_project},
      {_L['_Close'],          Proj.close_project},
      {''},
      {'Project _Search',     Proj.search_in_files },
      {'Goto _Tag',           Proj.goto_tag},
      {'S_ave position',      Proj.store_current_pos},
      {'_Prev position',      Proj.goto_prev_pos},
      {'Ne_xt position',      Proj.goto_next_pos},
    }

    --modify edit menu
    local med=textadept.menu.menubar[_L['_Edit']]
    med[#med+1]= {''}
    med[#med+1]= {'Trim trailing spaces', Proj.trim_trailing_spaces}
  end
  --ok, change the context menu
  return true
end

-- set project context menu in SELECTION mode --
local function proj_contextm_sel()
  if proj_context_menu_init(1) then
    textadept.menu.context_menu[ Proj.cmenu_idx ]= {
      title='Project',
      {_L['_Open'] .. ' file  [Enter]', Proj.open_sel_file},
      {'_Snapopen',                     Proj.snapopen},
      {''},
      {_L['_Edit'] .. ' project',       Proj.change_proj_ed_mode},
      {'_Hide/show project',            Proj.toggle_projview},
      {''},
      {'Add files from a _Dir',         Proj.add_dir_files},
      {'_Project Search',               Proj.search_in_files },
    }
  end
end

-- set project context menu in EDIT mode --
local function proj_contextm_edit()
  if proj_context_menu_init(2) then
    textadept.menu.context_menu[ Proj.cmenu_idx ]= {
      title='Project',
      {'_End edit',   Proj.change_proj_ed_mode}
    }
  end
end

-- set project context menu for a regular file --
local function proj_contextm_file()
  if proj_context_menu_init(3) then
    textadept.menu.context_menu[ Proj.cmenu_idx ]= {
      title='Project',
      {'_Add this file',        Proj.add_this_file},
      {'Add all open _Files',   Proj.add_all_files},
      {'Add files from a _Dir', Proj.add_dir_files},
      {''},
      {'Project _Search',       Proj.search_in_files },
      {'Goto _Tag',             Proj.goto_tag},
      {'S_ave position',        Proj.store_current_pos},
      {'_Prev position',        Proj.goto_prev_pos},
      {'Ne_xt position',        Proj.goto_next_pos},
      {''},
      {'_Hide/show project',    Proj.toggle_projview},
    }
  end
end

------------------PROJECT CONTROL-------------------
--if the current file is a project, enter SELECTION mode--
function Proj.ifproj_setselectionmode(p_buffer)
  if not p_buffer then p_buffer = buffer end  --use current buffer?
  if Proj.get_buffertype(p_buffer) >= Proj.PRJB_PROJ_MIN then
    Proj.set_selectionmode(p_buffer,true)
    if p_buffer.filename then
      ui.statusbar_text= 'Project file =' .. buffer.filename
    end
    return true
  end
  return false
end

--if the current file is a project, enter EDIT mode--
function Proj.ifproj_seteditmode(buff)
  if not p_buffer then p_buffer = buffer end  --use current buffer?
  if Proj.get_buffertype(p_buffer) >= Proj.PRJB_PROJ_MIN then
    Proj.set_selectionmode(p_buffer,false)
    if p_buffer.filename then
      ui.statusbar_text= 'Project file =' .. buffer.filename
    end
    return true
  end
  return false
end

--toggle project between SELECTION and EDIT modes
function Proj.toggle_selectionmode()
  local mode= Proj.get_buffertype()
  if mode == Proj.PRJB_PROJ_SELECT or mode == Proj.PRJB_PROJ_EDIT then
    Proj.set_selectionmode(buffer, (mode == Proj.PRJB_PROJ_EDIT)) --toggle current mode
  else
    --if the current file is a project, enter SELECTION mode--
    if not Proj.ifproj_setselectionmode() then
      ui.statusbar_text='This file is not a project'
    end
  end
  buffer.home()
end

--set the project mode as: selected (selmode=true) or edit (selmode=false)
--if selmode=true, parse the project and build file list: "proj_file[]"
function Proj.set_selectionmode(buff,selmode)
  local editmode= not selmode
  --mark this buffer as a project (true=SELECTION mode) (false=EDIT mode)
  buff._project_select= selmode
  --selection is read-only
  buff.read_only= selmode
  --in SELECTION mode the current line is always visible
  buff.caret_line_visible_always= selmode
  --and the scrollbars hidden
  buff.h_scroll_bar= editmode
  buff.v_scroll_bar= editmode

  if selmode then
    --fill buffer arrays: "proj_files[]", "proj_fold_row[]" and "proj_grp_path[]"
    Proj.parse_projectbuffer(buff)
    --set lexer to highlight groups and hidden control info ":: ... ::"
    buff:set_lexer('myproj')
    --project in SELECTION mode--
    proj_show_sel_w_focus(buff)

    --set SELECTION mode context menu
    proj_contextm_sel()

    --fold the requested folders
    for i= #buff.proj_fold_row, 1, -1 do
      buff.toggle_fold(buff.proj_fold_row[i])
    end
    Proj.is_visible= 1  --1:shown in selection mode
    Proj.mark_open_files(buff)
  else
    --edit project as a text file (show control info)
    buff:set_lexer('text')
    --set EDIT mode context menu
    proj_contextm_edit()
    --project in EDIT mode--
    proj_show_default(buff)
    Proj.is_visible= 2  --2:shown in edit mode
    Proj.clear_open_indicators(buff)
  end
  if toolbar then
    Proj.update_projview()  --update project view button
    toolbar.seltabbuf(buff) --hide/show and select tab in edit mode
  end
end

------------------HELPERS-------------------
--open files in the preferred view
--optinal: goto line_num
function Proj.go_file(file, line_num)
  Proj.goto_filesview() --change to files view if needed
  if file == nil or file == '' then
    --new file (add only one)
    local n= nil
    for i=1, #_BUFFERS do
      if (_BUFFERS[i].filename == nil) and (_BUFFERS[i]._type ~= Proj.PRJT_SEARCH) then
        --there is one new file, select this instead of adding a new one
        n= i
        break
      end
    end
    if n == nil then
      buffer.new()
      n= _BUFFERS[buffer]
    end
    if TA_MAYOR_VER < 9 then
      view.goto_buffer(view, n, false)
    else
      view.goto_buffer(view, _BUFFERS[n])
    end
  else
    --goto file / line_num
    local fn = file:iconv(_CHARSET, 'UTF-8')
    for i, buf in ipairs(_BUFFERS) do
      if buf.filename == fn then
        --already open
        if TA_MAYOR_VER < 9 then
          view:goto_buffer(i)
        else
          view:goto_buffer(buf)
        end
        fn = nil
        break
      end
    end
    if fn then io.open_file(fn) end

    if line_num then my_goto_line(buffer, line_num-1) end
    Proj.update_after_switch()
  end
end

--RUN a command
--%{projfiles} is replaced for a temporary file with the complete list of project files
--%{projfiles.ext1.ext2...} only project files with this extensions are included
function Proj.run_command(cmd)
  if cmd ~= nil and cmd ~= '' then
    local tmpfile, ext
    --replace special vars
    local s, e = cmd:find('%{projfiles}')
    if not s then
      s, e = cmd:find('%{projfiles%..*}')
      if s and e then
        --get extensions
        local se= cmd:match('%{projfiles%.(.*)}')
        if se then
          ext={}
          for i in string.gmatch(se, "[^%.]+") do
            ext[i] = true
          end
        end
      end
    end
    if s and e then
      --replace %{projfiles} is with a temporary file with the list of project files
      local p_buffer = Proj.get_projectbuffer(true)
      if p_buffer == nil or p_buffer.proj_files == nil then
        ui.statusbar_text= 'No project found'
        return
      end

      --get a list of project files
      local flist= {}
      for row= 1, #p_buffer.proj_files do
        local ftype= p_buffer.proj_filestype[row]
        if ftype == Proj.PRJF_FILE then --ignore CTAGS files / path / empty rows
          local file= p_buffer.proj_files[row]
          if not ext or ext[file:match('[^%.]+$')] then
            --all files / listed extension
            flist[ #flist+1 ]= file
          end
        end
      end
      if #flist == 0 then
        ui.statusbar_text= 'File not found in project'
        return
      end
      --write the project files list in a temp file
      tmpfile = p_buffer.filename..'_tmp'
      local f = io.open(tmpfile, 'wb')
      if f then
        f:write(table.concat(flist, '\n'))
        f:close()
      end
      cmd= string.sub(cmd,1,s-2)..tmpfile..string.sub(cmd,e+1)
    end
    Proj.last_run_command= cmd
    Proj.last_run_tmpfile= tmpfile
    if string.len(Proj.last_run_command) > 40 then
      Proj.last_run_command= string.sub(Proj.last_run_command,1,40)..'...'
    end
    local proc= spawn(cmd,nil,nil,nil,function(status)
        ui.statusbar_text= 'RUN '..Proj.last_run_command..' ended with status '..status
        if Proj.last_run_tmpfile then
          os.remove(Proj.last_run_tmpfile)
          Proj.last_run_tmpfile= nil
        end
      end)
    ui.statusbar_text= 'RUNNING: '..Proj.last_run_command
  end
end

--set/restore lexer/ui after a buffer/view switch
function Proj.update_after_switch()
  --if we are updating, ignore this event
  if Proj.updating_ui > 0 then return end
  Proj.updating_ui= 1
  if buffer._project_select == nil then
    --normal file: restore current line default settings
    proj_show_default(buffer)
    --set regular file context menu
    proj_contextm_file()
    --try to select the current file in the project
    Proj.track_this_file()

    --refresh some options (when views are closed this is mixed)
    --the current line is not always visible
    buffer.caret_line_visible_always= false
    --and the scrollbars shown
    buffer.h_scroll_bar= true
    buffer.v_scroll_bar= true

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
        proj_show_sel_w_focus(buffer)
        --set SELECTION mode context menu
        proj_contextm_sel()
      else
        -- project in EDIT mode: restore current line default settings --
        proj_show_default(buffer)
        --set EDIT mode context menu
        proj_contextm_edit()
      end
      --refresh some options (when views are closed this is mixed)
      --in SELECTION mode the current line is always visible
      buffer.caret_line_visible_always= buffer._project_select
      --and the scrollbars hidden
      buffer.h_scroll_bar= not buffer._project_select
      buffer.v_scroll_bar= buffer.h_scroll_bar
    end
  end
  Proj.updating_ui= 0
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
      row= Proj.locate_file(p_buffer, file)
      if row ~= nil then
        --prevent some events to fire for ever
        Proj.updating_ui= Proj.updating_ui+1

        local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
        my_goto_view(projv)
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

        Proj.updating_ui= Proj.updating_ui-1
      end
    end
  end
end

------------------EVENTS-------------------
events_connect(events.BUFFER_BEFORE_SWITCH, Proj.show_lost_focus)
events_connect(events.VIEW_BEFORE_SWITCH,   Proj.show_lost_focus)

events_connect(events.BUFFER_AFTER_SWITCH,  Proj.update_after_switch)
events_connect(events.VIEW_AFTER_SWITCH,    Proj.update_after_switch)

events_connect(events.BUFFER_DELETED, function()
  --update open files hilight if the project is visible and in SELECTION mode
  local pbuf = Proj.get_projectbuffer(false)
  if pbuf and pbuf._project_select then
    Proj.mark_open_files(pbuf)
  end
end)

--if the current file is a project, enter SELECTION mode--
events_connect(events.FILE_OPENED, function()
  --ignore session load
  --if Proj.init_ready then Proj.ifproj_setselectionmode() end
  if Proj.updating_ui == 0 then Proj.ifproj_setselectionmode() end
end)

local function open_proj_currrow()
  if buffer._project_select then
    Proj.open_sel_file()
  elseif buffer._type == Proj.PRJT_SEARCH then
    Proj.open_search_file()
  end
end

events_connect(events.DOUBLE_CLICK, function(_, line)
  open_proj_currrow()
end)
events_connect(events.KEYPRESS, function(code)
  local ks= keys.KEYSYMS[code]
  if ks == '\n' or ks == 'kpenter' then  --"Enter" or "Return"
    open_proj_currrow()
    if Proj.temporal_view then
      Proj.temporal_view= false
      Proj.toggle_projview()
    end
  elseif ks == 'esc' then --"Escape"
    if not Proj.close_search_view() then
      --change view
      if #_VIEWS > 1 then
        local nv= _VIEWS[view] +1
        if nv > #_VIEWS then nv=1 end
        my_goto_view(nv)
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
end)

--toggle project between selection and EDIT modes
function Proj.change_proj_ed_mode()
  if buffer._project_select ~= nil then
    --project: toggle mode
    if view.size ~= nil then
      if buffer._project_select then
        if Proj.select_width ~= view.size then
          Proj.select_width= view.size  --save current width
          if Proj.select_width < 50 then Proj.select_width= 200 end
          Proj.list_change= true  --save it on exit
        end
        Proj.is_visible= 2  --2:shown in edit mode
        view.size= Proj.edit_width
      else
        if Proj.edit_width ~= view.size then
          Proj.edit_width= view.size  --save current width
          if Proj.edit_width < 50 then Proj.edit_width= 600 end
          Proj.list_change= true  --save it on exit
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
  if toolbar then
    local b="tog-projview"
    toolbar.enable(b, ena) --gray button
    --not enabled: "GRAYED" selection mode icon
    if not ena then toolbar.setthemeicon(b, "ttb-proj-o") end
  end
  return ena
end

local function proj_in_editmode()
  local pbuf= Proj.get_projectbuffer(true)
  return pbuf and (Proj.get_buffertype(pbuf) == Proj.PRJB_PROJ_EDIT)
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

function Proj.toggle_projview()
  --Show/Hide project
  if ena_toggle_projview() then
    if proj_in_editmode() then
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
          Proj.list_change= true  --save it on exit
        end
        view.size= 0
      else
        Proj.is_visible= 1  --1:shown in selection mode
        view.size= Proj.select_width
      end
      Proj.update_projview()
    end
    Proj.goto_filesview()
  end
end

function Proj.update_projview()
  --update toggle project view button
  if ena_toggle_projview() and toolbar then
    local b="tog-projview"
    if Proj.is_visible == 2 then      --2:shown in edit mode
      toolbar.setthemeicon(b, "ttb-proj-e")
      toolbar.settooltip(b, "End edit mode [Shift+F4]")
    elseif Proj.is_visible == 1 then  --1:shown in selection mode
      toolbar.setthemeicon(b, "ttb-proj-o")
      toolbar.settooltip(b, "Hide project [Shift+F4]")
    else                              --0:hidden
      toolbar.setthemeicon(b, "ttb-proj-c")
      toolbar.settooltip(b, "Show project [Shift+F4]")
    end
  end
end

-- refresh syntax highlighting + project folding
local function refresh_proj_hilight()
  if buffer._project_select ~= nil then
    Proj.toggle_selectionmode()
    Proj.toggle_selectionmode()
  end
  buffer.colourise(buffer, 0, -1)
end

------------------- tab-clicked event ---------------
--- when a tab is clicked, change the view if needed
--- (Textadept version >= 9)
---
---  * For Textadept version 8:
---    * add the following line to the function "t_tabchange()" in "textadept.c" @1828
---      lL_event(lua, "tab_clicked", LUA_TNUMBER, page_num + 1, -1);
---    * recompile textadept
---    * add "'tab_clicked'," to "ta_events = {}" in "events.lua" (to register the new event) @369
if TA_MAYOR_VER >= 9 then
  events.connect(events.TAB_CLICKED, function(ntab)
    --tab clicked (0...) check if a view change is needed
    if #_VIEWS > 1 then
      if _BUFFERS[ntab]._project_select ~= nil then
        --project buffer: force project view
        local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
        my_goto_view(projv)
        elseif _BUFFERS[ntab]._type == Proj.PRJT_SEARCH then
        --project search
        if Proj.search_vn ~= nil then
          my_goto_view(Proj.search_vn)
        else
          --activate search view
          Proj.goto_searchview()
          Proj.search_vn= _VIEWS[view]
        end
      else
        --normal file: check we are not in project view
        Proj.goto_filesview() --change to files view if needed
      end
    end
  end, 1)
end

--delete all trailing blanks chars
function Proj.trim_trailing_spaces()
  local buffer = buffer
  buffer:begin_undo_action()
  local n=0
  for line = 0, buffer.line_count - 1 do
    local trail = buffer:get_line(line):match('^.-(%s-)[\n\r]*$')
    if trail and trail ~= '' then
      local e = buffer.line_end_position[line]
      local s = e - string.len(trail)
      buffer:set_target_range(s, e)
      buffer:replace_target('')
      n=n+1
    end
  end
  buffer:end_undo_action()
  if n > 0 then
    ui.statusbar_text= 'Trimmed lines: '..n
  else
    ui.statusbar_text= 'No trailing spaces found'
  end
end

function Proj.open_file()
  Proj.goto_filesview() --change to files view if needed
  io.open_file()
end

function Proj.open_recent_file()
  Proj.goto_filesview() --change to files view if needed
  io.open_recent_file()
end

function Proj.qopen_user()
  Proj.goto_filesview() --change to files view if needed
  io.quick_open(_USERHOME)
  Proj.track_this_file()
end

function Proj.qopen_home()
  Proj.goto_filesview() --change to files view if needed
  io.quick_open(_HOME)
  Proj.track_this_file()
end

function Proj.qopen_curdir()
  local fname= buffer.filename
  Proj.goto_filesview() --change to files view if needed
  if fname then
    io.quick_open(fname:match('^(.+)[/\\]'))
    Proj.track_this_file()
  end
end

local function insert_menu(menu,pos,item)
  local i= #menu
  while i >= pos do
    menu[i+1]=menu[i]
    i=i-1
  end
  menu[pos]=item
end

--replace some menu commands with the corresponding project version
function Proj.change_menu_cmds()
  local menu= textadept.menu.menubar[_L['_File']]
  menu[_L['_Open']][2]= Proj.open_file
  menu[_L['Open _Recent...']][2]= Proj.open_recent_file
  menu[_L['_Close']][2]= Proj.close_buffer
  menu[_L['Close All']][2]= Proj.close_all_buffers

  local menu= textadept.menu.tab_context_menu
  insert_menu(menu,2,{'Close Others', Proj.close_others})
  insert_menu(menu,3,{"Mark as don't close", Proj.keep_thisbuffer})
  insert_menu(menu,4,{_L['Close All'], Proj.onlykeep_projopen})

  menu= textadept.menu.menubar[_L['_Buffer']]
  menu[_L['_Next Buffer']][2]= Proj.next_buffer
  menu[_L['_Previous Buffer']][2]= Proj.prev_buffer
  menu[_L['_Switch to Buffer...']][2]= Proj.switch_buffer

  menu= textadept.menu.menubar[_L['_Tools']][_L['Quick _Open']]
  menu[_L['Quickly Open _User Home']][2]= Proj.qopen_user
  menu[_L['Quickly Open _Textadept Home']][2]= Proj.qopen_home
  menu[_L['Quickly Open _Current Directory']][2]= Proj.qopen_curdir
  menu[_L['Quickly Open Current _Project']][2]= Proj.snapopen
end

--------------------------------------------------------------
-- Control+W=         close buffer
-- Control+Shift+W=   close all buffers
-- Control+H=         show project current row properties
-- Control+O =        open file
-- Control+Alt+O =    open recent file
-- Control+Shift+O =  project snap open
-- Control+Shift+Alt+O = open current directory
-- Control+U =        quick open user folder
-- F4 =               toggle project between selection and EDIT modes
-- SHIFT+F4 =         toggle project visibility
-- F5 =               refresh syntax highlighting + project folding
-- Control+B=         switch buffer
-- Control+PgUp=      previous buffer
-- Control+PgDn=      next buffer
keys.cw = Proj.close_buffer
keys.cW = Proj.close_all_buffers
keys.ch = Proj.show_doc
keys.co = Proj.open_file
keys.cao= Proj.open_recent_file
keys.cO = Proj.snapopen
keys.caO= Proj.qopen_curdir
keys.cu = Proj.qopen_user
keys.f4 = Proj.change_proj_ed_mode
keys.sf4= Proj.toggle_projview
keys.f5 = refresh_proj_hilight
keys.cb = Proj.switch_buffer
keys['cpgup'] = Proj.prev_buffer
keys['cpgdn'] = Proj.next_buffer
keys['apgup'] = Proj.first_buffer
keys['apgdn'] = Proj.last_buffer
