local events, events_connect = events, events.connect
local Proj = Proj
local _L = _L

-----------------CURRENT LINE-------------------
--project is in SELECTION mode with focus--
local function proj_show_sel_w_focus()
  --hide line numbers
  buffer.margin_width_n[0] = 0
  --highlight current line as selected
  buffer.caret_width= 0
  buffer.caret_line_back = 0x88acdf --property['color.base10'] -0x202020
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
local function proj_show_default()
  --project in EDIT mode / default text file--
  --show line numbers
  local width = 4 * buffer:text_width(buffer.STYLE_LINENUMBER, '9')
  buffer.margin_width_n[0] = width + (not CURSES and 4 or 0)
  --return to default
  buffer.caret_width= 2
  buffer.caret_line_back = 0xf5f9ff --property['color.base06']
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
--      {_L['Open _Recent...'], Proj.open_recent_project},
      {''},
      {_L['_Close'],          Proj.close_project},
    }
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
      {_L['_Edit'] .. ' project',       Proj.toggle_selectionmode}
    }
  end
end

-- set project context menu in EDIT mode --
local function proj_contextm_edit()
  if proj_context_menu_init(2) then
    textadept.menu.context_menu[ Proj.cmenu_idx ]= {
      title='Project',
      {'_End edit',   Proj.toggle_selectionmode}
    }
  end
end

-- set project context menu in a regular file --
local function proj_contextm_file()
  if proj_context_menu_init(3) then
    textadept.menu.context_menu[ Proj.cmenu_idx ]= {
      title='Project',
      {'_Add this file',           Proj.add_this_file},
      {'Add all open _Files',      Proj.add_all_files},
      {''},
      {'_Open project files here', Proj.set_open_panel}
    }
  end
end

------------------PROJECT CONTROL-------------------
--if the current file is a project, enter SELECTION mode--
function Proj.ifproj_setselectionmode()
  if Proj.get_buffertype() >= Proj.PRJB_PROJ_MIN then
    Proj.set_selectionmode(true)
    if buffer.filename then
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
    Proj.set_selectionmode(mode == Proj.PRJB_PROJ_EDIT) --toggle current mode
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
function Proj.set_selectionmode(selmode)
  local editmode= not selmode
  --mark this buffer as a project (true=SELECTION mode) (false=EDIT mode)
  buffer._project_select= selmode
  --selection is read-only
  buffer.read_only= selmode
  --in SELECTION mode the current line is always visible
  buffer.caret_line_visible_always= selmode
  --and the scrollbars hidden
  buffer.h_scroll_bar= editmode
  buffer.v_scroll_bar= editmode

  --set default files view
  Proj.set_files_view()

  if selmode then
    --fill buffer arrays: "proj_files[]", "proj_fold_row[]" and "proj_grp_path[]"
    Proj.parse_projectbuffer()
    --set lexer to highlight groups and hidden control info ":: ... ::"
    buffer:set_lexer('myproj')
    --project in SELECTION mode--
    proj_show_sel_w_focus()
    --set SELECTION mode context menu
    proj_contextm_sel()

    --fold the requested folders
    for i= #buffer.proj_fold_row, 1, -1 do
      buffer.toggle_fold(buffer.proj_fold_row[i])
    end

  else
    --edit project as a text file (show control info)
    buffer:set_lexer('text')
    --set EDIT mode context menu
    proj_contextm_edit()
    --project in EDIT mode--
    proj_show_default()
  end
end

------------------HELPERS-------------------
--open files in the preferred view
function Proj.go_file(file)
  if #_VIEWS == 1 then
    view:split(true)  --split verticaly
    --left project in view #1
    ui.goto_view(1)
    if view.size ~= nil then
      --set default project width= 20% of screen (actual = 50%)
      view.size= math.floor(view.size/2.5)
    end
    --set default files view
    Proj.set_files_view()
  end
  if file == nil or file == '' then
    --new file (only one)
    local n= nil
    for i=1, #_BUFFERS do
      if _BUFFERS[i].filename == nil then
        --there is one new file, select this instead of adding a new one
        n= i
        break
      end
    end
    if Proj.files_vn ~= nil then
      ui.goto_view(Proj.files_vn)
    end
    if n == nil then
      buffer.new()
      n= _BUFFERS[buffer]
    end
    view.goto_buffer(view, n, false)
  else
    ui.goto_file(file:iconv(_CHARSET, 'UTF-8'), true, _VIEWS[Proj.files_vn])
  end
end

--set/restore lexer/ui after a buffer/view switch
function Proj.update_after_switch()
  --if we are updating, ignore this event
  if Proj.updating_ui > 0 then return end
  Proj.updating_ui= 1
  if buffer._project_select == nil then
    --normal file: restore current line default settings
    proj_show_default()
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
    if buffer._project_select then
      -- project in SELECTION mode: set "myprog" lexer --
      buffer:set_lexer('myproj')
      --project in SELECTION mode--
      proj_show_sel_w_focus()
      --set SELECTION mode context menu
      proj_contextm_sel()
    else
      -- project in EDIT mode: restore current line default settings --
      proj_show_default()
      --set EDIT mode context menu
      proj_contextm_edit()
    end
    --refresh some options (when views are closed this is mixed)
    --in SELECTION mode the current line is always visible
    buffer.caret_line_visible_always= buffer._project_select
    --and the scrollbars hidden
    buffer.h_scroll_bar= not buffer._project_select
    buffer.v_scroll_bar= buffer.h_scroll_bar

    --check project view / set default files view
    if Proj.view_n == nil then
      Proj.set_files_view()
    end
    if #_BUFFERS == 1 then --and #_VIEWS > 1 then
--doesn't work as spected when a file is closed. TODO: move somewhere...
--      --only the project is open, close all views
--      --(looks better than the project in two views)
--      while view:unsplit() do end
      Proj.view_n = 1
      Proj.set_files_view()

    elseif Proj.view_n > #_VIEWS then
      --correct invalid project view
      Proj.view_n = 1
      Proj.set_files_view()
    end
  end
--  buffer.home()
  Proj.updating_ui= 0
end

--set project view = this view
--auto-choose a view where to open the project files
function Proj.set_files_view()
--check: the current buffer is a project
  if buffer._project_select ~= nil then
    local n= _VIEWS[view]
    --set project view = this view
    Proj.view_n= n
    if #_VIEWS > 1 then
      --don't use the same view for the project and the files
      if Proj.files_vn == nil or Proj.files_vn == n or Proj.files_vn > #_VIEWS then
        --show files in the "next"/"prev" view
        if n < #_VIEWS then
          Proj.files_vn= n+1
        else
          Proj.files_vn= n-1
        end
      end
    else
      --only one view, split the view for files
      Proj.files_vn= null
    end
  end
end

--try to select the current file in the working project
--(only if the project is currently visible)
function Proj.track_this_file( proj_in_view )
  local p_buffer = Proj.get_projectbuffer()
  if p_buffer and p_buffer._project_select then
    --ok, the working project is in SELECTION mode
    if not proj_in_view then
      --not sure if the project is in view...
      --update project view
      Proj.view_n= nil
      for i=1, #_VIEWS do
        if _VIEWS[i].buffer == p_buffer then
          Proj.view_n= i
          --if the project is in the files view, reset files view
          if Proj.files_vn == i then
            Proj.files_vn= nil
          end
          break
        end
      end
    end

    --only track the file if the project is visible and is not an special buffer
    if Proj.view_n ~= nil and buffer._type == nil then
      --get file path
      local file= buffer.filename
      if file ~= nil then
        row= Proj.locate_file(p_buffer, file)
        if row ~= nil then
          --row found
          --prevent some events to fire for ever
          Proj.updating_ui= Proj.updating_ui+1

          ui.goto_view(Proj.view_n)
          --move the selection bar
          p_buffer:ensure_visible_enforce_policy(row- 1)
          p_buffer:goto_line(row-1)
          p_buffer:home()
           -- project in SELECTION mode without focus--
          Proj.show_lost_focus(p_buffer)
          --return to this file (it could be in a different view)
          Proj.go_file(file)

          Proj.updating_ui= Proj.updating_ui-1
        end
      end
    end
  end
end

------------------EVENTS-------------------
events_connect(events.BUFFER_BEFORE_SWITCH, Proj.show_lost_focus)
events_connect(events.VIEW_BEFORE_SWITCH,   Proj.show_lost_focus)

events_connect(events.BUFFER_AFTER_SWITCH,  Proj.update_after_switch)
events_connect(events.VIEW_AFTER_SWITCH,    Proj.update_after_switch)

--if the current file is a project, enter SELECTION mode--
events_connect(events.FILE_OPENED, function()
  Proj.ifproj_setselectionmode()
end)

events_connect(events.DOUBLE_CLICK, function(_, line)
  if buffer._project_select then
    Proj.open_sel_file()
  elseif buffer._type == Proj.PRJT_SEARCH then
    Proj.open_search_file()
  end
end)
events_connect(events.KEYPRESS, function(code)
  local ks= keys.KEYSYMS[code]
  if ks == '\n' or ks == 'kpenter' then  --"Enter" or "Return"
    if buffer._project_select then
      Proj.open_sel_file()
      return true
    end
    if buffer._type == Proj.PRJT_SEARCH then
      Proj.open_search_file()
      return true
    end
  elseif ks == 'esc' then --"Escape"
    return Proj.close_search_view()
  end
end)
--------------------------------------------------------------
-- F4       toggle project between selection and EDIT modes
keys.f4 = function()
  Proj.toggle_selectionmode()
  if buffer._project_select ~= nil and view.size ~= nil then
    if buffer._project_select then
      view.size= math.floor(view.size/3.0)
    else
      view.size= math.floor(view.size*3.0)
    end
  end
end
  
--------------------------------------------------------------
-- F5       Refresh syntax highlighting + project folding
keys.f5 = function()
  if buffer._project_select ~= nil then
    Proj.toggle_selectionmode()
    Proj.toggle_selectionmode()
  end
  buffer.colourise(buffer, 0, -1)
end
--------------------------------------------------------------
-- CTRL+H  show current row properties or textadept's doc.
keys.ch = Proj.show_doc

------------------- tab-clicked event ---------------
---change the view, if needed, when a tab is clicked
---requires:
---  * add the following line to the function "t_tabchange()" in "textadept.c" @1828
---    lL_event(lua, "tab_clicked", LUA_TNUMBER, page_num + 1, -1);
---
---  * recompile textadept
---
---  * add the following line to "ta_events = {}" in "events.lua" (to register the new event) @369
---    'tab_clicked',
---
---  * COMMENT the following event handler if not used
---
events.connect(events.TAB_CLICKED, function(ntab)
  --tab clicked (0...) check if a view change is needed
  if #_VIEWS > 1 then
    if _BUFFERS[ntab]._project_select ~= nil then
      --project buffer: force project view
      if Proj.view_n ~= nil then
        ui.goto_view(Proj.view_n)
      end
    elseif _BUFFERS[ntab]._type == Proj.PRJT_SEARCH then
      --project search
      if Proj.search_vn ~= nil then
        ui.goto_view(Proj.search_vn)
      end
    else
      --normal file: check we are not in project view
      if Proj.files_vn ~= nil then
        ui.goto_view(Proj.files_vn)
      end
    end
  end
end)

--ctrl-shift-o = project snap open
keys.cO = Proj.snapopen