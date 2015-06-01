----------------------------- PROJECT ---------------------------------
local events, events_connect = events, events.connect
local M = {}
-----------------------------------------------------------------------
-- Vars added to M:
--  M.proj_view       = preferred view for the project
--  M.proj_files_view = preferred view for opening files
--
--  M.proj_cmenu_num  = number of the current context menu
--                  1 = project in SELECTION mode
--                  2 = project in EDIT mode
--                  3 = regular file
--  M.proj_cmenu_idx  = 'Project' submenu position in the context menu
--
--  M.proj_updating   = number of updates in process (ignore some events if > 0)
--
--
-----------------------------------------------------------------------
M.proj_updating = 0
-----------------------------------------------------------------------
-- Vars added to buffer:
--  _is_a_project    = mark this buffer as a valid project file
--               nil = regular file
--              true = project in SELECTION mode
--             false = project in EDIT mode
--
--  _project_checked = the buffer header has been verified
--               nil = first time seen
--              true = checked
--
--  _is_working_project = this is the working project (in case more than one is open)
--              true = this is the one
--
--  proj_files[]     = array with the filename in each row
--
--
-----------------------------------------------------------------------

--project is in SELECTION mode with focus--
local function proj_show_sel_w_focus()
  --hide line numbers
  buffer.margin_width_n[0] = 0
  --highlight current line as selected
  buffer.caret_width= 0
  buffer.caret_line_back = 0xF0D0A0
end

--lost focus: if project is in SELECTION mode change current line
local function proj_show_lost_focus()
  if M.proj_updating == 0 and buffer._is_a_project then
    -- project in SELECTION mode without focus--
    buffer.caret_line_back = 0xf0e5d5
  end
end
events_connect(events.BUFFER_BEFORE_SWITCH, proj_show_lost_focus)
events_connect(events.VIEW_BEFORE_SWITCH,   proj_show_lost_focus)

--restore current line default settings
local function proj_show_default()
  --project in EDIT mode / default text file--
  --show line numbers
  local width = 4 * buffer:text_width(buffer.STYLE_LINENUMBER, '9')
  buffer.margin_width_n[0] = width + (not CURSES and 4 or 0)
  --return to default
  buffer.caret_width= 2
  buffer.caret_line_back = 0xc5e8ee
end

--if the current file is a project, enter SELECTION mode--
--check if the first file line has the form " name '::' (path) '::' "
local function proj_check_file()
  if buffer._is_a_project == nil then
    line= buffer:get_line(0)
    local col1, col2 = string.match(line,'^%s*(.-)%s*::(.+)::%s*$')
    if col1 ~= nil and col2 ~= nil then
      M.proj_set_sel_mode(true)
      ui.statusbar_text= 'Project file =' .. buffer.filename
    end
  end
end

events_connect(events.LEXER_LOADED, function(lang)
  --if we are updating, ignore this event
  if M.proj_updating > 0 then return end
  
  if lang == 'myproj' then
    --project in SELECTION mode--
    proj_show_sel_w_focus()
    
  elseif lang == 'text' then
    --normal file or project--
    if not buffer._project_checked then
      buffer._project_checked= true
      --first check: if it is a project set SELECTION mode
      proj_check_file()
    end
    if buffer._is_a_project ~= nil then
      --is a project--
      if buffer._is_a_project then
        --project in SELECTION mode--
        proj_show_sel_w_focus()
      else
        --project in EDIT mode--
        proj_show_default()
      end
    end
  end
end)

--init desired project context menu
local function proj_context_menu_init(num)
  if CURSES or M.proj_cmenu_num == num then
    --CURSES or the menu is already set, don't change the context menu
    return false
  end
  M.proj_cmenu_num= num
  
  if M.proj_cmenu_idx == nil then
    --first time here, add project menu at the end of context menu
    M.proj_cmenu_idx= #textadept.menu.context_menu +1
    --add Project to menubar (keep Help at the end)
    n= #textadept.menu.menubar
    textadept.menu.menubar[n+1]= textadept.menu.menubar[n]
    textadept.menu.menubar[n]= {
      title='Project', 
--      {_L['_New'],            M.proj_new_project},
      {_L['_Open'],           M.proj_open_project},
--      {_L['Open _Recent...'], M.proj_open_recent_project},
      {''},
      {_L['_Close'],          M.proj_close_project},
    }
  end
  --ok, change the context menu
  return true
end

-- set project context menu in SELECTION mode --
local function proj_contextm_sel()
  if proj_context_menu_init(1) then
    textadept.menu.context_menu[ M.proj_cmenu_idx ]= {
      title='Project', 
      {_L['_Open'] .. ' file   [Enter]', M.proj_open_sel_file},
      {''},
      {_L['_Edit'] .. ' project [F4]',   M.proj_toggle_sel_mode}
    }
  end
end

-- set project context menu in EDIT mode --
function proj_contextm_edit()
  if proj_context_menu_init(2) then
    textadept.menu.context_menu[ M.proj_cmenu_idx ]= {
      title='Project', 
      {'_End edit  [F4]',   M.proj_toggle_sel_mode}
    }
  end
end

-- set project context menu in a regular file --
function proj_contextm_file()
  if proj_context_menu_init(3) then
    textadept.menu.context_menu[ M.proj_cmenu_idx ]= {
      title='Project', 
      {'_Add this file to project',   M.proj_add_this_file},
      {''},
      {'_Open project files here',    M.proj_set_open_panel}
    }
  end
end

--auto-choose a view where to open the project files
local function proj_set_files_view()
--check: the current buffer is a project
  if buffer._is_a_project ~= nil then
    if #_VIEWS > 1 then
      --show files in the "next"/"prev" view
      n= _VIEWS[view]
      --set project view
      M.proj_view= n
      if M.proj_files_view == nil then
        --there isn't a file view already set, choose one
        if n < #_VIEWS then
          M.proj_files_view= _VIEWS[n+1]
        else
          M.proj_files_view= _VIEWS[n-1]
        end
      end
    else
      --only one view, reset project view
      M.proj_view= 1
      --split the view for files
      M.proj_files_view= null
    end
  end
end

--open all project files in the current view
function M.proj_set_open_panel()
  M.proj_files_view= view
end

local function proj_update_after_switch()
  --if we are updating, ignore this event
  if M.proj_updating > 0 then return end
  
  if buffer._is_a_project == nil then
    --normal file: restore current line default settings
    proj_show_default()
    --set regular file context menu
    proj_contextm_file()
    --try to select the current file in the project
    M.proj_sel_this_file()

    ui.statusbar_text = ''
    
  else
    --project buffer--
    if buffer._is_a_project then
      -- project in SELECTION mode: set "myprog" lexer --
      buffer:set_lexer('myproj')
      --highlight current line
      proj_show_sel_w_focus()
      --set SELECTION mode context menu
      proj_contextm_sel()
    else
      -- project in EDIT mode: restore current line default settings --
      proj_show_default()
      --set EDIT mode context menu
      proj_contextm_edit()
    end
    
    --check we are in the proper view
    n = _VIEWS[view]
    if M.proj_view == nil then
      --set default files view
      proj_set_files_view()
      ui.statusbar_text = 'proj in view='..M.proj_view
      
    else
      if M.proj_view > #_VIEWS then
        M.proj_view = 1
      end
      if M.proj_view ~= n then
        --we are not in the project view, try to fix this
        --first check is there is a project in M.proj_view
        if _VIEWS[M.proj_view].buffer == nil or _VIEWS[M.proj_view].buffer._is_a_project == nil then
          --not a project, swap the buffers
          ui.statusbar_text = 'swap needed'
        else
          --is a project too, check if we are in two views
          ui.statusbar_text = 'in two views'
          if #_BUFFERS == 1 then
            --open an "untitled" file
            M.proj_go_file('')
          else
            --TODO: select another file
          end
        end
      else
        ui.statusbar_text = 'proj in view ok= '..n
      end
    end  
  end
end
events_connect(events.BUFFER_AFTER_SWITCH,  proj_update_after_switch)
events_connect(events.VIEW_AFTER_SWITCH,    proj_update_after_switch)

local function splitfilename(strfilename)
  -- Returns the Path, Filename, and Extension as 3 values
  return string.match(strfilename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
end

----------------------------------------------------------------------
--TODO: check/simplify this
-- valid project file lines
-- <blanks>                        ignore
-- <blanks>     .n.   ##-##        ignore
-- <blanks>     .n.   ##.p.\##     ignore + path definition 'p'
-- <blanks>     .n.   ##.p./##     ignore + path definition 'p'
-- <blanks>     .n.   ##.f..##     open file 'f'
-- <blanks>           ##.f..##     open file 'f'
-- <blanks>     .n.                open file 'p'+'n' 
--                                 (first previous 'p' o project path)
----------------------------------------------------------------------
--set the project mode as: selected (selmode=true) or edit (selmode=false)
--if selmode=true, parse the project and build file list: "proj_file[]"
function M.proj_set_sel_mode(selmode)
  local editmode= not selmode
  --mark this buffer as a project (true=SELECTION mode) (false=EDIT mode)
  buffer._is_a_project= selmode
  --selection is read-only
  buffer.read_only= selmode
  --in SELECTION mode the current line is always visible
  buffer.caret_line_visible_always= selmode
  --and the scrollbars hidden
  buffer.h_scroll_bar= editmode
  buffer.v_scroll_bar= editmode
  
  --set default files view
  proj_set_files_view()
  
  if selmode then
    --set lexer to highlight groups and hidden control info ":: ... ::"
    buffer:set_lexer('myproj')
    --set SELECTION mode context menu
    proj_contextm_sel()
        
    --fill filenames array "buffer.proj_files[]"
    ui.statusbar_text= 'Parsing project file...'
    buffer.proj_files= {}
    --get project file path (default)
    path,fn,ext = splitfilename(buffer.filename)
    --parse project file line by line
    for r = 0, buffer.line_count do
      fname= ""
      line= buffer:get_line(r)
      local col1, col2 = string.match(line,'^%s*(.-)%s*::(.+)::%s*$')
      if col1 == nil then
        col2 = string.match(line,'^%s*::(.+)::%s*$')
        if col2 == nil then
          col1= string.match(line,'^%s*(.-)%s*$')
        end
      end
      if col2 ~= nil and col2 ~= "" and col2 ~= "-" then
        --<blanks>     .n.   ##.p./##     ignore + path definition 'p'
        p,f,e= splitfilename(col2)
        if f == "" and p ~= "" then
          path = p
        else
        -- <blanks>     .n.   ##.f..##     open file 'f
          fname= col2
        end
        
      elseif col1 ~= nil and col1 ~= "" and col2 == nil then
        -- <blanks>     .n.                open file 'p'+'n'
        fname = path .. col1
      end
      buffer.proj_files[r]= fname
      buffer.vc_home()
    end
    ui.statusbar_text= 'Open project: '.. buffer.filename
  else
    --edit project as a text file (show control info)
    buffer:set_lexer('text')    
    --set EDIT mode context menu
    proj_contextm_edit()
  end
end

--toggle project between selection and EDIT modes
function M.proj_toggle_sel_mode()
  if buffer._is_a_project == nil then
    --if this file is a valid project, enter SELECTION mode
    proj_check_file()
    if buffer._is_a_project == nil then
      ui.statusbar_text='This file is not a valid project'
    end
  else
    --toggle mode
    M.proj_set_sel_mode(not buffer._is_a_project)
  end
end

--open files in the preferred view
function M.proj_go_file(file)
  if #_VIEWS == 1 then
    view:split(true)  --split verticaly
    --left project in view #1
    ui.goto_view(1)    
    --set default project width= 20% of screen (actual = 50%)
    view.size= math.floor(view.size/2.5)
    --set default files view
    proj_set_files_view()
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
    if M.proj_files_view ~= nil then
      ui.goto_view(_VIEWS[M.proj_files_view])
    end
    if n == nil then
      buffer.new()
      n= _BUFFERS[buffer]
    end
    view.goto_buffer(view, n, false)
  else
    ui.goto_file(file:iconv(_CHARSET, 'UTF-8'), true, M.proj_files_view)
  end
end

--open the selected file/s
--when more than one line is selected, ask for confirmation
function M.proj_open_sel_file()
  --check we have a file list
  if buffer.proj_files == nil then
    return
  end
  --read selected line range
  r1= buffer.line_from_position(buffer.selection_start)
  r2= buffer.line_from_position(buffer.selection_end)
  --clear selection
  buffer.selection_start= buffer.selection_end
  if r1 < r2 then
    --more than one line, count files in range
    local flist= {}
    n= 0
    for r= r1, r2 do
      if buffer.proj_files[r] ~= "" then
        flist[n]= buffer.proj_files[r]
        n= n+1
      end
    end
    if n == 0 then
      --no files in range, use current line; action=fold
      r1= buffer.line_from_position(buffer.current_pos)
    else
      --if there is more than one file in range, ask for confirmation
      local confirm = (n == 1) or ui.dialogs.msgbox{
        title = 'Open confirmation',
        text = 'There are ' .. n .. ' files selected',
        informative_text = 'Do you want to open them?',
        icon = 'gtk-dialog-question', button1 = _L['_OK'], button2 = _L['_Cancel']
      } == 1
      if not confirm then
        return
      end
      if n == 1 then
        ui.statusbar_text= 'Open: ' .. flist[0]
      else
        ui.statusbar_text= 'Open: ' .. n .. ' files'
      end
      --open all
      for r= 0, n-1 do
        M.proj_go_file(flist[r])
      end
      --try to select the current file in the working project
      M.proj_sel_this_file()
      return
    end
  end
  --one line selected
  file = buffer.proj_files[r1]
  if file ~= "" then
    ui.statusbar_text= 'Open: ' .. file
    M.proj_go_file(file)
    --try to select the current file in the working project
    M.proj_sel_this_file()
  else
    --there is no file for this row, fold instead
    buffer.toggle_fold(r1)
  end
end

--return the working project buffer
function M.proj_work_buffer()
  -- search for the working project
  for _, buffer in ipairs(_BUFFERS) do
    if buffer._is_working_project then
      --found
      return buffer
    end
  end
  -- not found, choose a new one
  -- 1) choose the project buffer in the LOWER view
  for i= 1, #_VIEWS do
    if _VIEWS[i].buffer._is_a_project ~= nil then
      --mark this as the working project
      _VIEWS[i].buffer._is_working_project = true
      return _VIEWS[i].buffer
    end
  end
  -- 2) check all buffers, use the first found
  for _, buffer in ipairs(_BUFFERS) do
    if buffer._is_a_project ~= nil then
      --mark this as the working project
      buffer._is_working_project = true
      return buffer
    end
  end
  --no project file found
  return nil
end

function M.proj_add_this_file()
  -- add the current file to the project
  local p_buffer = M.proj_work_buffer()
  if p_buffer then
    --get file path
    file= buffer.filename
    if file then
      --if the project is in readonly, change it
      save_ro= p_buffer.read_only
      p_buffer.read_only= false
      path,fn,ext = splitfilename(file)
      p_buffer:append_text( '\n ' .. fn .. '::' .. file .. '::')
      --add the new line to the proj. file list
      if p_buffer.proj_files ~= nil then
        p_buffer.proj_files[#p_buffer.proj_files+1]= file
      end
      p_buffer.read_only= save_ro
      M.proj_sel_this_file()
      ui.statusbar_text= 'File added to project: ' .. file
    end
  else
    ui.statusbar_text='Project not found'
  end
end

--try to select the current file in the working project
function M.proj_sel_this_file()
  --if we are updating, ignore this call
  if M.proj_updating > 0 then return end

  local p_buffer = M.proj_work_buffer()
  if p_buffer and p_buffer._is_a_project then
    --found the working project and is in SELECTION mode
    --get file path
    local file= buffer.filename
    if file then
      for i= 0, #p_buffer.proj_files do
        if file == p_buffer.proj_files[i] then
          --row found
          --prevent some events to fire for ever
          M.proj_updating=  M.proj_updating+1
          if M.proj_view == nil then
            M.proj_view= 1
          end
          --this file is in the project view
          if _VIEWS[view] == M.proj_view then
            --choose another view for the file
            M.proj_files_view= nul
          end
          ui.goto_view(M.proj_view)
          --move the selection bar
          p_buffer:goto_line(i)
          --return to this file (in another view if needed)
          M.proj_go_file(file)
          --update complete
          M.proj_updating=  M.proj_updating-1
          return
        end
      end
      --file not found in project
    end
  end
end

events_connect(events.KEYPRESS, function(code)
  --TODO: check "enter from num-pad" not working
  if keys.KEYSYMS[code] == '\n' and buffer._is_a_project then
    M.proj_open_sel_file()
    return true
  end
end)
events_connect(events.DOUBLE_CLICK, function(_, line)
  if buffer._is_a_project then M.proj_open_sel_file() end
end)

--------------------------------------------------------------
--create a new project fije
function M.proj_new_project()
  --TODO: finish
end

--open an existing project file
--TODO: bug: opening a project with no other file open: left TWO "untitled" files
--TODO: bug: opening a 2nd project dosen't work
--TODO: close "untitled" file when another file is opened (if not modified)
function M.proj_open_project()
  prjfile= ui.dialogs.fileselect{
    title = 'Open Project File', 
      with_directory = (buffer.filename or ''):match('^.+[/\\]') or lfs.currentdir(),
      width = CURSES and ui.size[1] - 2 or nil,
      with_extension = {'proj'}, select_multiple = false }
  if prjfile ~= nil then
    if not M.proj_close_project() then
      ui.statusbar_text= 'Open cancelled'
      return
    end
    ui.statusbar_text= 'Open project: '.. prjfile
    
    proj_keep_file= ''  --open a new file after project open
    if buffer ~= nil and buffer.filename ~= nil then
      proj_keep_file= buffer.filename --keep this file after project open
    end
    --open the project
    io.open_file(prjfile)
    --project ui
    proj_update_after_switch()
    --restore the file that was current before opening the project
    --or open a blank one
    M.proj_go_file(proj_keep_file)
  end
end

--open a project from the recent list
function M.proj_open_recent_project()
  --TODO: finish
end

--close current project / view
function M.proj_close_project()
  local p_buffer = M.proj_work_buffer()
  if p_buffer ~= nil then
    if #_VIEWS > 1 then
      if M.proj_view ~= nil then
        ui.goto_view(M.proj_view)
      else
        ui.goto_view(1)
      end
    end
    view.goto_buffer(view, _BUFFERS[p_buffer], false)
    if io.close_buffer() then
      if #_VIEWS > 1 then
        view.unsplit(view)
      end
      --reset project view
      M.proj_view= 1
      --split the view for files
      M.proj_files_view= null
    else
      --close was cancelled
      return false
    end
  else
    ui.statusbar_text= 'No project found'
  end
  --closed / not found
  return true
end

--------------------------------------------------------------
-- F4       toggle project between selection and EDIT modes
keys.f4 = M.proj_toggle_sel_mode
--------------------------------------------------------------
