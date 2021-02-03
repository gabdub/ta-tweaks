-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
---- PROJECT ACTIONS ----
local Proj = Proj
local Util = Util
local _L = _L
local data = Proj.data

--ACTION: new
function Proj.new_file()
  Proj.goto_filesview()
  buffer.new()
end

--ACTION: open
function Proj.open_file()
  Proj.goto_filesview()
  io.open_file()
end

--ACTION: recent
function Proj.open_recent_file()
  Proj.goto_filesview()
  io.open_recent_file()
end

--ACTION: close
function Proj.close_buffer()
  if buffer._project_select ~= nil then
    --close project file and views
    Proj.close_project(false)

  elseif buffer._type == Proj.PRJT_SEARCH then
    --close search results
    plugs.close_results()

  else
    --close a regular file
    if Util.close_buffer() then
      --check that at least one regular buffer remains after closing
      Proj.check_panels()
    end
  end
end

--ACTION: closeall (close project)
--function Proj.close_all_buffers()
--  --close project file and views
--  Proj.close_project(false)
--  --close all buffers
--  io.close_all_buffers()
--end
--
--ACTION: closeall (dont'close project)
function Proj.onlykeep_projopen(keepone)
  Proj.stop_update_ui(true)
  --close search results
  plugs.close_results()
  --change to left/only file view if needed
  Proj.goto_filesview(Proj.FILEPANEL_LEFT)
  local i= 1
  local n= #_BUFFERS
  while n > 0 do
    n= n-1
    local buf=_BUFFERS[i]
    if Proj.isRegularBuf(buf) and not buf._dont_close then
      --regular file, close it
      Util.goto_buffer(buf)
      if not Util.close_buffer() then
        Proj.stop_update_ui(false)
        return --cancel close all
      end
    else
      --skip project buffers and don't close buffers
      i= i+1
      buf._dont_close= nil --remove flag
    end
  end
  --check that at least one regular buffer remains after closing
  Proj.check_panels()
  if actions then actions.updateaction("dont_close") end
  Proj.stop_update_ui(false)
end

--ACTION: open_userhome
function Proj.qopen_user()
  Proj.goto_filesview()
  io.quick_open(_USERHOME)
  plugs.track_this_file()
end

--ACTION: open_textadepthome
function Proj.qopen_home()
  Proj.goto_filesview()
  io.quick_open(_HOME)
  plugs.track_this_file()
end

--ACTION: open_currentdir
function Proj.qopen_curdir()
  Proj.goto_filesview()
  local fname= buffer.filename
  if fname then
    io.quick_open(fname:match('^(.+)[/\\]'))
    plugs.track_this_file()
  end
end

--ACTION: quick_open_projectdir
--quick open project files based on io.quick_open/snapopen @ file_io.lua
function Proj.quick_open()
  if not Proj.check_is_open() then return end

  --if the current view is a project view, goto files view
  Proj.goto_filesview()
  local utf8_list = {}
  for row= 1, #data.proj_files do
    local file= data.proj_files[row]
    local ftype= data.proj_filestype[row]
    if file and file ~= '' and (ftype == Proj.PRJF_FILE or ftype == Proj.PRJF_CTAG) then
      file = file:gsub('^%.[/\\]', ''):iconv('UTF-8', _CHARSET)
      utf8_list[#utf8_list + 1] = file
    end
  end
  local options = {
    title = _L['Open File'], columns = _L['Filename'], items = utf8_list,
    button1 = Util.OK_TEXT, button2 = Util.CANCEL_TEXT, select_multiple = true,
    string_output = true, width = CURSES and ui.size[1] - 2 or nil
  }
  local button, files = ui.dialogs.filteredlist(options)
  if button ~= Util.OK_TEXT or not files then return end
  for i = 1, #files do files[i] = files[i]:iconv(_CHARSET, 'UTF-8') end
  io.open_file(files)
  Proj.update_after_switch()
end

function Proj.get_filevcinfo(fname)
  --show filename
  local info= fname
  local fn= string.match(fname..'::','(.-):HEAD::')
  if fn then fname=fn end
  --get version control params for filename
  local cmd
  local post= ""
  local verctrl, cwd, url= Proj.get_versioncontrol_url(fname)
  if verctrl == 1 then
    cmd= "svn info "..url
    post= "SVN"
  elseif verctrl == 2 then
    info= info..'\nGIT: '..url
    cmd= "git status -sb "..url
  end
  if cmd then
    local p = assert(os.spawn(cmd,cwd))
    p:close()
    local einfo=(p:read('*a') or ''):iconv('UTF-8', _CHARSET)
    if einfo and einfo ~= '' then
      info= info..'\n'..einfo..post
    end
  end
  return info
end

--ACTION: show_filevcinfo
function Proj.show_filevcinfo()
  --call_tip_show
  if buffer.filename ~= nil then
    if buffer:call_tip_active() then events.emit(events.CALL_TIP_CLICK) return end
    local info= Proj.get_filevcinfo(buffer.filename)
    if info ~= '' then
      buffer:call_tip_show(buffer.current_pos, info )
    end
  end
end

function Proj.get_vcs_info(row, sep)
  local info= ""
  if data.proj_vcontrol then
    for i=1, #data.proj_vcontrol do  --{path, p, 1/2, row}
      if data.proj_vcontrol[i][4] == row then
        if data.proj_vcontrol[i][3] == 1 then info="SVN: " else info="GIT: " end
        info= info..data.proj_vcontrol[i][1]..(sep or " | ")..data.proj_vcontrol[i][2]
        break
      end
    end
  end
  return info
end

--ACTION: show_documentation
-- show project current row properties
function Proj.show_doc()
  --call_tip_show
  if buffer._project_select ~= nil then
    if buffer:call_tip_active() then events.emit(events.CALL_TIP_CLICK) return end
    local r= buffer.line_from_position(buffer.current_pos) +1 -Util.LINE_BASE
    local info = data.proj_files[r]
    local ftype= data.proj_filestype[r]
    if ftype == Proj.PRJF_CTAG then info= 'CTAG: '..info
    elseif ftype == Proj.PRJF_VCS then info= Proj.get_vcs_info(r)
    elseif ftype == Proj.PRJF_RUN then info= 'RUN: '..info end
    if info == '' and data.proj_grp_path[r] ~= nil then
      info= data.proj_grp_path[r]
    elseif ftype == Proj.PRJF_FILE then
      info= Proj.get_filevcinfo(info)
    end
    if info ~= '' then
      buffer:call_tip_show(buffer.current_pos, info )
    end
  else
    --call default show doc function
    textadept.editing.show_documentation()
  end
end

--ACTION: next_buffer
function Proj.next_buffer()
  if toolbar then
    toolbar.sel_top_bar()
    toolbar.gototab(1)
  else
    local nb= _BUFFERS[buffer]+1
    if nb > #_BUFFERS then nb= 1 end
    if toolbar then
      local retry= 3
      --if project files are not shown in tabs, skip them
      while toolbar.isbufhide(_BUFFERS[nb]) and retry > 0 do
        nb= nb+1
        if nb > #_BUFFERS then nb= 1 end
        retry= retry-1
      end
    end
    Proj.goto_buffer(nb)
  end
end

--ACTION: prev_buffer
function Proj.prev_buffer()
  if toolbar then
    toolbar.sel_top_bar()
    toolbar.gototab(-1)
  else
    local nb= _BUFFERS[buffer]-1
    if nb < 1 then nb= #_BUFFERS end
    if toolbar then
      local retry= 3
      --if project files are not shown in tabs, skip them
      while toolbar.isbufhide(_BUFFERS[nb]) and retry > 0 do
        nb= nb-1
        if nb < 1 then nb= #_BUFFERS end
        retry= retry-1
      end
    end
    Proj.goto_buffer(nb)
  end
end

--ACTION: switch_buffer
function Proj.switch_buffer()
  local columns, utf8_list = {_L['Name'], _L['File']}, {}
  for i = 1, #_BUFFERS do
    local buffer = _BUFFERS[i]
    local filename = buffer.filename or buffer._type or Util.UNTITLED_TEXT
    if buffer.filename then filename = filename:iconv('UTF-8', _CHARSET) end
    local basename = buffer.filename and filename:match('[^/\\]+$') or filename
    utf8_list[#utf8_list + 1] = (buffer.modify and '*' or '')..basename
    utf8_list[#utf8_list + 1] = filename
  end
  local button, i = ui.dialogs.filteredlist{
    title = _L['Switch Buffers'], columns = columns, items = utf8_list,
    width = CURSES and ui.size[1] - 2 or nil
  }
  if button == 1 and i then Proj.goto_buffer(i) end
end

--ex ACTION: refresh_syntax
-- refresh syntax highlighting + project folding
function Proj.refresh_hilight()
  plugs.proj_refresh_hilight()
  refresh_syntax()
end

--ACTION: trim_trailingspaces
--delete all trailing blanks chars
function Proj.trim_trailing_spaces()
  local buffer = buffer
  buffer:begin_undo_action()
  local n= 0
  local fromln= Util.LINE_BASE
  local toln= fromln + buffer.line_count - 1
  for line = fromln, toln do
    local trail = buffer:get_line(line):match('^.-(%s-)[\n\r]*$')
    if trail and trail ~= '' then
      local e= buffer.line_end_position[line]
      local s= e - string.len(trail)
      buffer:set_target_range(s, e)
      buffer:replace_target('')
      n= n+1
    end
  end
  buffer:end_undo_action()
  if n > 0 then
    ui.statusbar_text= 'Trimmed lines: '..n
  else
    ui.statusbar_text= 'No trailing spaces found'
  end
end

--ACTION: remove_tabs
--Convert all tabs into spaces
function Proj.remove_tabs()
  local buffer = buffer
  local nt, ne= 0, 0
  buffer:begin_undo_action()
  local pos= buffer.current_pos
  local startlin= buffer.line_from_position(pos)
  local startcol= buffer.column[pos]
  buffer:goto_pos(0)
  buffer:search_anchor()
  local tw= buffer.tab_width
  pos= buffer:search_next(0, "\t")
  while pos ~= -1 do
    buffer:set_target_range(pos, pos+1)
    local col= buffer.column[pos] -Util.LINE_BASE
    local spaces = tw - math.fmod(col, tw)
    buffer:replace_target(string.rep(' ', spaces))
    nt=nt+1
    ne=ne+spaces
    pos= buffer:search_next(0, "\t")
  end
  buffer:goto_pos(buffer:find_column(startlin, startcol))
  buffer:end_undo_action()
  ui.statusbar_text= ""..nt.." tabs replaced with "..ne.." spaces"
end

--ACTION: new_project
--create a new project fije
function Proj.new_project()
  --ask for a project name
  local dir = lfs.currentdir()
  local name = 'project.proj'
  filename = ui.dialogs.filesave{
    title = 'New project', with_directory = dir,
    with_file = name:iconv('UTF-8', _CHARSET),
    width = CURSES and ui.size[1] - 2 or nil
  }
  if not filename then return end
  --first close the current project (keep views)
  if not Proj.close_project(true) then
    ui.statusbar_text= 'New project cancelled'
    return
  end
  path,fn,ext = Util.splitfilename(filename)
  --remove extension
  if ext ~= '' then fn= fn:match('^(.+)%.') end
  --select the root of the project (suggest project path)
  rootdir = ui.dialogs.fileselect{
    title = 'Select project root (Cancel = relative to project file)',
    select_only_directories = true, with_directory = path
  }
  if not rootdir then rootdir='' else rootdir= rootdir .. Util.PATH_SEP end
  --create the project file and open it
  if Proj.create_empty_project(filename, fn, rootdir) then Proj.open_project(filename) end
end

--ACTION: open_project
--open an existing project file
function Proj.open_project(filename)
  local prjfile= filename or ui.dialogs.fileselect{
    title = 'Open Project File',
    with_directory = (buffer.filename or ''):match('^.+[/\\]') or lfs.currentdir(),
    width = CURSES and ui.size[1] - 2 or nil,
    with_extension = {'proj'}, select_multiple = false }
  if prjfile ~= nil then
    --first close the current project (keep views)
    if not Proj.close_project(true) then
      ui.statusbar_text= 'Open cancelled'
      return
    end

    data.filename= prjfile
    data.is_open= true
    if not plugs.open_project() then   --open the project file
      data.is_open= false
      Proj.closed_cleardata()
    end
  end
end

--ACTION: recent_project
--open a project from the recent list
function Proj.open_recent_project()
  local utf8_filenames = {}
  for _, filename in ipairs(data.recent_projects) do
    utf8_filenames[#utf8_filenames + 1] = filename:iconv('UTF-8', _CHARSET)
  end
  local button, i = ui.dialogs.filteredlist{
    title = 'Open Project File',
    columns = _L['File'],
    items = utf8_filenames,
    width = CURSES and ui.size[1] - 2 or nil
  }
  if button == 1 and i then Proj.open_project(data.recent_projects[i]) end
end

--ACTION: close_project
--close current project / view
function Proj.close_project(keepviews)
  return plugs.close_project(keepviews)
end

--ACTION: search_project
function Proj.search_in_files(where, suggest)
  if not Proj.ask_search_in_files then --goto_nearest module?
    ui.statusbar_text= 'goto_nearest module not found'
    return
  end
  if not Proj.check_is_open() then return end
  local currow= plugs.get_prj_currow() --get the selected project row number
  if currow > 0 then
    local find, case, word= Proj.ask_search_in_files(true, suggest)
    if find then Proj.find_in_files(currow, find, case, word, true, where) end
  end
end
--ACTION: search_sel_dir
function Proj.search_in_sel_dir()
  Proj.search_in_files(1) --1=selected directory
end
--ACTION: search_sel_file
function Proj.search_in_sel_file()
  Proj.search_in_files(2) --2=selected file
end

--ACTION: clear_search
function Proj.clear_search()
  if plugs.clear_results then plugs.clear_results() end
end

--ACTION: close_others
function Proj.close_others()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.goto_filesview()
  buffer._dont_close= true --force keep this
  --close the other buffers (except the project)
  Proj.onlykeep_projopen(true)
end

--ACTION: dont_close
function Proj.keepthisbuff_status()
  return (buffer._dont_close and 1 or 2) --check
end
function Proj.toggle_keep_thisbuffer()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.goto_filesview()
  if buffer._dont_close then buffer._dont_close= nil else buffer._dont_close= true end
  if actions then actions.updateaction("dont_close") end
end

--ACTION: showin_rightpanel
function Proj.showin_rightpanel_status()
  return (buffer._right_side and 1 or 2) --check
end
function Proj.toggle_showin_rightpanel()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.stop_update_ui(true)
  Proj.goto_filesview()
  local buf= buffer
  if buf._right_side then
    buf._right_side= nil
    --check the right panel content
    Proj.check_rightpanel()
    Proj.goto_projview(Proj.PRJV_FILES)
  else
    buf._right_side= true
    --check the left/only panel content
    Proj.check_leftpanel()
    Proj.goto_projview(Proj.PRJV_FILES_2)
  end
  --move the buffer to the other panel
  Util.goto_buffer(buf)
  Proj.close_untitled() --close "Untitled" buffers in the same view
  Proj.stop_update_ui(false)
  Proj.update_after_switch()
  if actions then actions.updateaction("showin_rightpanel") end
end

--ACTION: open_projsel (only used for project in buffers)
--open the selected file/s
--when more than one line is selected, ask for confirmation
function Proj.open_sel_file()
  plugs.open_sel_file()
end

--ACTION: toggle_editproj / _end_editproj (alias)
--toggle project between selection and EDIT modes
function Proj.toggle_editproj()
  plugs.change_proj_ed_mode()
end

--ACTION: toggle_viewproj
function Proj.toggle_projview()
  Proj.show_hide_projview()
end

--ACTION: addcurrentfile_proj
-- add the current file to the project
function Proj.add_current_file()
  if not Proj.check_is_open() then return end
  local file= buffer.filename
  if file ~= nil and buffer._project_select == nil and buffer._type == nil then
    local flist= {}
    flist[1]= file
    Proj.add_files(flist, false)
  end
end

--ACTION: addallfiles_proj
-- add all open files to the project
function Proj.add_all_files()
  if not Proj.check_is_open() then return end
  --put all buffer.filename in a list (ignore the project and special buffers)
  local flist= {}
  for _, b in ipairs(_BUFFERS) do
    local file= b.filename
    if file ~= nil and b._project_select == nil and b._type == nil then
      flist[ #flist+1 ]= file
    end
  end
  Proj.add_files(flist, false)
end

--ACTION: adddirfiles_proj
-- add files from a directory to the project
function Proj.add_dir_files(dir)
  if not Proj.check_is_open() then return end

  local defdir
  if #data.proj_files > 0 then
    defdir= data.proj_grp_path[1]
  end
  dir = dir or ui.dialogs.fileselect{
    title = 'Add all files from a Directory', select_only_directories = true,
    with_directory = defdir or (buffer.filename or ''):match('^.+[/\\]') or
                     lfs.currentdir()
  }
  if not dir then return end

  local flist= {}
  local extlist= {}
  local ext
  if Util.TA_MAYOR_VER < 11 then
    lfs.dir_foreach(dir, function(file)
      flist[ #flist+1 ]= file
      ext= file:match('[^%.\\/]+$')
      if ext then extlist[ext]= true end
      end, lfs.FILTER, nil, false)
  else
    for file in lfs.walk(dir, lfs.default_filter, nil, false) do
      flist[ #flist+1 ]= file
      ext= file:match('[^%.\\/]+$')
      if ext then extlist[ext]= true end
    end
  end
  if #flist > 0 then
    --choose extension to import
    local allext= ""
    for e,v in pairs(extlist) do
      if allext == "" then
        allext= e
      else
        allext= allext..","..e
      end
    end
    r,word= ui.dialogs.inputbox{title = 'Extension list', informative_text = 'Choose the extensions to add (empty= all)', width = 400, text = allext}
    if type(word) == 'table' then
      word= table.concat(word, ',')
    end
    if word == "" then
      --all files / dirs
      Proj.add_files(flist, true) --sort and group files with the same path
    else
      --filtered by extensions
      extlist= {}
      for i in string.gmatch(word, "[^,]+") do
        extlist[i] = true
      end
      local flist2= {}
      for i,f in ipairs(flist) do
        ext= f:match('[^%.\\/]+$')
        if ext and extlist[ext] then
          flist2[#flist2+1]= f
        end
      end
      Proj.add_files(flist2, true) --sort and group files with the same path
    end
  end
end

--ACTION: open_selfile
function Proj.open_selfile()
  Proj.open_cursor_file()
end

--ACTION: first_buffer
function Proj.first_buffer()
  if toolbar then
    toolbar.sel_top_bar()
    toolbar.gototab(0)
  end
end

--ACTION: last_buffer
function Proj.last_buffer()
  if toolbar then
    toolbar.sel_top_bar()
    toolbar.gototab(2)
  end
end
