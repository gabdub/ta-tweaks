local Proj = Proj
local Util = Util
local _L = _L

--open the selected file/s
--when more than one line is selected, ask for confirmation
function Proj.open_sel_file()
  --check we have a file list
  if buffer.proj_files == nil then
    return
  end

  --read selected line range
  local r1= buffer.line_from_position(buffer.selection_start)+1
  local r2= buffer.line_from_position(buffer.selection_end)+1
  --clear selection
  buffer.selection_start= buffer.selection_end

  --count files/run in range
  local flist= {}
  local rlist= {}
  for r= r1, r2 do
    if buffer.proj_files[r] ~= "" then
      local ft= buffer.proj_filestype[r]
      if ft == Proj.PRJF_FILE or ft == Proj.PRJF_CTAG then
        flist[ #flist+1 ]= buffer.proj_files[r]
      elseif ft == Proj.PRJF_RUN then
        rlist[ #rlist+1 ]= buffer.proj_files[r]
      end
    end
  end
  if #flist == 0 and #rlist == 0 then
    --no files/run in range, use current line; action=fold
    r1= buffer.line_from_position(buffer.current_pos)+1
    if buffer.proj_files[r] ~= "" then
      local ft= buffer.proj_filestype[r]
      if ft == Proj.PRJF_FILE or ft == Proj.PRJF_CTAG then
        flist[ #flist+1 ]= buffer.proj_files[r]
      elseif ft == Proj.PRJF_RUN then
        rlist[ #rlist+1 ]= buffer.proj_files[r]
      end
    end
  end

  --don't mix open/run (if both are selected: open)
  local list = {}
  local action
  if #flist > 0 then
    list= flist
    action= 'Open'
  elseif #rlist > 0 then
    list= rlist
    action= 'Run'
  end

  if action then
    --if there is more than one file in range, ask for confirmation
    local confirm = (#list == 1) or ui.dialogs.msgbox{
      title = action..' confirmation',
      text = 'There are ' .. #list .. ' files selected',
      informative_text = 'Do you want to open them?',
      icon = 'gtk-dialog-question', button1 = _L['_OK'], button2 = _L['_Cancel']
    } == 1
    if not confirm then
      return
    end
    if #list == 1 then
      ui.statusbar_text= action..': ' .. list[1]
    else
      ui.statusbar_text= action..': ' .. #list .. ' files'
    end
    if action == 'Open' then
      --open all
      for r= 1, #list do
        Proj.go_file(list[r])
      end
    elseif action == 'Run' then
      --run all
      for r= 1, #list do
        Proj.run_command(list[r])
      end
    end
    --try to select the current file in the working project
    Proj.track_this_file()
    return
  end
  --there is no file for this row, fold instead
  buffer.toggle_fold(r1)
end

-- add the current file to the project
function Proj.add_this_file()
  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer then
    --get file path
    file= buffer.filename
    if file then
      --if the file is already in the project, ask for confirmation
      local confirm = (Proj.get_file_row(p_buffer, file) == nil) or ui.dialogs.msgbox{
        title = 'Add confirmation',
        text = 'The file ' .. file .. ' is already in the project',
        informative_text = 'Do you want to add it again?',
        icon = 'gtk-dialog-question', button1 = _L['_OK'], button2 = _L['_Cancel']
      } == 1
      if confirm then
        --prevent some events to fire for ever
        Proj.updating_ui= Proj.updating_ui+1

        local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
          --this file is in the project view
        if _VIEWS[view] ~= projv then
          Util.goto_view(projv)
        end

        --if the project is in readonly, change it
        save_ro= p_buffer.read_only
        p_buffer.read_only= false
        path,fn,ext = Util.splitfilename(file)
        --TODO: reduce the path is possible using project root
        p_buffer:append_text( '\n ' .. fn .. '::' .. file .. '::')
        --add the new line to the proj. file list
        row= #p_buffer.proj_files+1
        p_buffer.proj_files[row]= file
        p_buffer.read_only= save_ro
        --move the selection bar
        p_buffer:ensure_visible_enforce_policy(row- 1)
        p_buffer:goto_line(row-1)
        -- project in SELECTION mode without focus--
        Proj.show_lost_focus(p_buffer)
        p_buffer.home()
        --return to this file (it could be in a different view)
        Proj.go_file(file)
        ui.statusbar_text= 'File added to project: ' .. file .. ' in row ' .. row

        Proj.updating_ui= Proj.updating_ui-1
      end
    end
  else
    ui.statusbar_text='Project not found'
  end
end

-- add all open files to the project
function Proj.add_all_files()
  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer then
    --put all buffer.filename in a list (ignore the project and special buffers)
    flist= {}
    for _, b in ipairs(_BUFFERS) do
      local file= b.filename
      if file ~= nil and b._project_select == nil and b._type == nil then
        flist[ #flist+1 ]= file
      end
    end
    Proj.add_files(p_buffer, flist, false)
  else
    ui.statusbar_text='Project not found'
  end
end

-- add files from a directory to the project
function Proj.add_dir_files(dir)
  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer then
    local defdir
    if #p_buffer.proj_files > 0 then
      defdir= p_buffer.proj_grp_path[1]
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
    if Util.TA_MAYOR_VER < 9 then
      lfs.dir_foreach(dir, function(file)
        flist[ #flist+1 ]= file
        ext= file:match('[^%.\\/]+$')
        if ext then extlist[ext]= true end
        end, lfs.FILTER, false)
    else
      lfs.dir_foreach(dir, function(file)
        flist[ #flist+1 ]= file
        ext= file:match('[^%.\\/]+$')
        if ext then extlist[ext]= true end
        end, lfs.FILTER, nil, false)
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
        Proj.add_files(p_buffer, flist, true) --sort and group files with the same path
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
        Proj.add_files(p_buffer, flist2, true) --sort and group files with the same path
      end
    end
  else
    ui.statusbar_text='Project not found'
  end
end

local function file_sort(filea,fileb)
  local pa,fa,ea = Util.splitfilename(filea)
  local pb,fb,eb = Util.splitfilename(fileb)
  if pa == pb then return fa < fb end
  return pa < pb
end

--add a list of files to the project (check for duplicates)
function Proj.add_files(p_buffer, flist, groupfiles)
  local finprj= {}
  local n_inprj= 0
  if #flist > 0 then
    if groupfiles then --sort and group files with the same path
      table.sort(flist, file_sort)
    end
    for _,file in ipairs(flist) do
      --check if already in the project
      local in_prj= (Proj.get_file_row(p_buffer, file) ~= nil)
      finprj[ #finprj+1]= in_prj
      if in_prj then n_inprj= n_inprj+1 end
    end
    --if some files are already in the project, ask for confirmation
    if n_inprj == 1 then
      info= '1 file is'
    else
      info= '' .. n_inprj .. ' files are'
    end
    all= true
    nadd= #flist
    local confirm = (n_inprj == 0) or ui.dialogs.msgbox{
      title = 'Add confirmation',
      text = info..' already in the project',
      informative_text = 'Do you want to add it/them again?',
      icon = 'gtk-dialog-question', button1 = _L['_OK'], button2 = _L['_Cancel']
    } == 1
    if (not confirm) and (#flist > n_inprj) then
      all= false
      nadd= #flist - n_inprj
      if nadd == 1 then
        info= '1 file is'
      else
        info= '' .. nadd .. ' files are'
      end
      confirm = (n_inprj == 0) or ui.dialogs.msgbox{
        title = 'Add confirmation',
        text = info..' not in the project',
        informative_text = 'Do you want to add it/them?',
        icon = 'gtk-dialog-question', button1 = _L['_OK'], button2 = _L['_Cancel']
      } == 1
    end
    if confirm then
      --prevent some events to fire for ever
      Proj.updating_ui= Proj.updating_ui+1

      local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
      --this file is in the project view
      if _VIEWS[view] ~= projv then
        Util.goto_view(projv)
      end

      --if the project is in readonly, change it
      save_ro= p_buffer.read_only
      p_buffer.read_only= false
      row= nil
      local curpath
      local defdir= p_buffer.proj_grp_path[1]
      for i,file in ipairs(flist) do
        if all or finprj[i] == false then
          path,fn,ext = Util.splitfilename(file)
          if groupfiles then
            --add file with relative path
            if curpath == nil or curpath ~= path then
              curpath= path
              local ph=path
              --remove default proyect base
              if defdir and string.sub(ph,1,string.len(defdir)) == defdir then
                ph= string.sub(ph,string.len(defdir)+1)
                if ph ~= "" then
                  local lastch= string.sub(ph,-1) --remove "\" or "/" end
                  if lastch == "\\" or lastch == "/" then ph= string.sub(ph,1,string.len(ph)-1) end
                end
              end
              p_buffer:append_text( '\n (' .. ph .. ')::' .. path .. '::')
            end
            p_buffer:append_text( '\n  ' .. fn)
          else
            --add files with absolute path
            p_buffer:append_text( '\n ' .. fn .. '::' .. file .. '::')
          end
          --add the new line to the proj. file list
          row= #p_buffer.proj_files+1
          p_buffer.proj_files[row]= file
        end
      end
      p_buffer.read_only= save_ro
      --update buffer arrays: "proj_files[]", "proj_fold_row[]" and "proj_grp_path[]"
      Proj.parse_projectbuffer(p_buffer)

      if row then
        --move the selection bar
        p_buffer:ensure_visible_enforce_policy(row- 1)
        p_buffer:goto_line(row-1)
      end
      -- project in SELECTION mode without focus--
      Proj.show_lost_focus(p_buffer)
      p_buffer.home()
      ui.statusbar_text= '' .. nadd .. ' file/s added to project'

      Proj.updating_ui= Proj.updating_ui-1
    end
  end
end

--------------------------------------------------------------
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
    ui.statusbar_text= 'Open cancelled'
    return
  end
  path,fn,ext = Util.splitfilename(filename)
  if ext ~= '' then
    --remove extension
    fn= fn:match('^(.+)%.')
  end
  --select the root of the project (suggest project path)
  rootdir = ui.dialogs.fileselect{
    title = 'Select project root (Cancel = relative to project file)',
    select_only_directories = true, with_directory = path
  }
  if not rootdir then
    rootdir=''  --relative
  else
    rootdir= rootdir .. (WIN32 and '\\' or '/')
  end

  --keep current file after project open
  local proj_keep_file
  if buffer ~= nil and buffer.filename ~= nil then
    proj_keep_file= buffer.filename
  end
  Proj.goto_projview(Proj.PRJV_PROJECT)
  --create the project buffer
  local buffer = buffer.new()
  buffer.filename = filename
  buffer:append_text('[' .. fn .. ']::' .. rootdir .. '::')
  --save project file
  io.save_file()
  --remember project file in recent list
  Proj.add_recentproject(filename)

  -- project in SELECTION mode without focus--
  Proj.set_selectionmode(buffer,true)
  Proj.show_lost_focus(buffer)
  --update ui
  Proj.updating_ui= 1
  Proj.goto_filesview(true) --change to files
  Proj.updating_ui= 0
  -- project in SELECTION mode without focus--
  --local p_buffer = Proj.get_projectbuffer(true)
  --Proj.show_lost_focus(p_buffer)

  --project ui
  Proj.ifproj_setselectionmode()
  --restore the file that was current before opening the project or open an empty one
  Proj.go_file(proj_keep_file)
end

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

    --TODO: check if there are buffers open (except a project and/or Untitled not modified buffer)
    --and ask to close all buffers before open the project
    --io.close_all_buffers()
    --TODO: add "project-sessions" to keep track of project open files

    --keep current file after project open
    local proj_keep_file
    if buffer ~= nil and buffer.filename ~= nil then
      proj_keep_file= buffer.filename
    end
    Proj.goto_projview(Proj.PRJV_PROJECT)
    --open the project
    io.open_file(prjfile)

    --update ui
    Proj.updating_ui= 1
    Proj.goto_filesview(true) --change to files
    Proj.updating_ui= 0
    -- project in SELECTION mode without focus--
    local p_buffer = Proj.get_projectbuffer(true)
    Proj.show_lost_focus(p_buffer)
    if p_buffer then
      --remember project file in recent list
      Proj.add_recentproject(prjfile)
    end

    --project ui
    Proj.ifproj_setselectionmode()
    --restore the file that was current before opening the project or open an empty one
    Proj.go_file(proj_keep_file)
  end
end

--open a project from the recent list
function Proj.open_recent_project()
  local utf8_filenames = {}
  for _, filename in ipairs(Proj.recent_projects) do
    utf8_filenames[#utf8_filenames + 1] = filename:iconv('UTF-8', _CHARSET)
  end
  local button, i = ui.dialogs.filteredlist{
    title = 'Open Project File',
    columns = _L['File'],
    items = utf8_filenames,
    width = CURSES and ui.size[1] - 2 or nil
  }
  if button == 1 and i then Proj.open_project(Proj.recent_projects[i]) end
end

--close current project / view
function Proj.close_project(keepviews)
  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer ~= nil then
    local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
    if #_VIEWS >= projv then
      Util.goto_view(projv)
    end
    Util.goto_buffer(p_buffer)
    if io.close_buffer() then
      ui.statusbar_text= 'Project closed'
      Proj.update_projview()  --update project view button
      if not keepviews then
        Proj.close_search_view()
        if #_VIEWS > 1 then
          view.unsplit(view)
        end
      end
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

-- find text in project's files
-- code adapted from module: find.lua
function Proj.find_in_files(p_buffer,text,match_case,whole_word)
  Proj.updating_ui=Proj.updating_ui+1
  --activate/create search view
  Proj.goto_searchview()

  buffer.read_only= false
  buffer:append_text('['..text..']\n')
  buffer:goto_pos(buffer.length)
  buffer.indicator_current = ui.find.INDIC_FIND
  if whole_word then text = '%f[%w_]'..(match_case and text or text:lower())..'%f[^%w_]' end

  local nfiles= 0
  local totfiles= 0
  local nfound= 0
  local filesnf= 0
  --check the given buffer has a list of files
  if p_buffer and p_buffer.proj_files ~= nil then
    for row= 1, #p_buffer.proj_files do
      local ftype= p_buffer.proj_filestype[row]
      if ftype == Proj.PRJF_FILE then --ignore CTAGS files / path / empty rows
        local file= p_buffer.proj_files[row]
        if file and file ~= '' then
          if not Util.file_exists(file) then
            filesnf= filesnf+1 --file not found
            buffer:append_text(('(%s NOT FOUND)::::\n'):format(file))
          else
            local line_num = 1
            totfiles = totfiles + 1
            local prt_fname= true
            for line in io.lines(file) do
              local s, e = (match_case and line or line:lower()):find(text)
              if s and e then
                file = file:iconv('UTF-8', _CHARSET)
                if prt_fname then
                  prt_fname= false
                  local p,f,e= Util.splitfilename(file)
                  if f == '' then
                    f= file
                  end
                  buffer:append_text((' %s::%s::\n'):format(f, file))
                  nfiles = nfiles + 1
                  if nfiles == 1 then buffer:goto_pos(buffer.length) end
                end
                local snum= ('%4d'):format(line_num)
                buffer:append_text(('  @%s:%s\n'):format(snum, line))

                local pos = buffer:position_from_line(buffer.line_count - 2) + #snum + 4
                buffer:indicator_fill_range(pos + s - 1, e - s + 1)
                nfound = nfound + 1
              end
              line_num = line_num + 1
            end
          end
        end
      end
    end
  end

  if nfound == 0 then buffer:append_text(' '.._L['No results found']..'\n') end
  buffer:append_text('\n')
  buffer:set_save_point()

  local result= ''..nfound..' matches in '..nfiles..' of '..totfiles..' files'
  if filesnf > 0 then
    result= result .. ' / '..filesnf..' files NOT FOUND'
  end
  ui.statusbar_text= result
  buffer:set_lexer('myproj')
  buffer.read_only= true
  --set search context menu
  Proj.set_contextm_search()
  Proj.updating_ui=Proj.updating_ui-1
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

--snapopen project files based on io.snapopen @ file_io.lua
function Proj.snapopen()
  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer == nil then
    ui.statusbar_text= 'No project found'
    return
  end
  if p_buffer.proj_files ~= nil then
    --if the current view is a project view, goto files view
    Proj.getout_projview()
    local utf8_list = {}
    for row= 1, #p_buffer.proj_files do
      local file= p_buffer.proj_files[row]
      local ftype= p_buffer.proj_filestype[row]
      if file and file ~= '' and (ftype == Proj.PRJF_FILE or ftype == Proj.PRJF_CTAG) then
        file = file:gsub('^%.[/\\]', ''):iconv('UTF-8', _CHARSET)
        utf8_list[#utf8_list + 1] = file
      end
    end
    local options = {
      title = _L['Open'], columns = _L['File'], items = utf8_list,
      button1 = _L['_OK'], button2 = _L['_Cancel'], select_multiple = true,
      string_output = true, width = CURSES and ui.size[1] - 2 or nil
    }
    local button, files = ui.dialogs.filteredlist(options)
    if button ~= _L['_OK'] or not files then return end
    for i = 1, #files do files[i] = files[i]:iconv(_CHARSET, 'UTF-8') end
    io.open_file(files)
    Proj.update_after_switch()
  end
end

function Proj.close_buffer()
  if buffer._project_select ~= nil then
    --close project file and views
    Proj.close_project(false)

  elseif buffer._type == Proj.PRJT_SEARCH then
    --close search results
    Proj.close_search_view()

  else
    --close a regular file
    if io.close_buffer() then
      --check that at least one regular buffer remains after closing
      Proj.check_panels()
    end
  end
end

function Proj.close_all_buffers()
  --close project file and views
  Proj.close_project(false)
  --close all buffers
  io.close_all_buffers()
  Proj.update_projview()  --update project view button
end

function Proj.onlykeep_projopen(keepone)
  Proj.updating_ui=Proj.updating_ui+1
  --close all buffers except project (and buffer._dont_close)
  if Proj.get_projectbuffer(false) ~= nil then
    --close search results
    Proj.close_search_view()
    --change to left/only file view if needed
    Proj.goto_filesview(true)
  elseif not keepone then
     io.close_all_buffers()
     Proj.updating_ui=Proj.updating_ui-1
     return
  end
  local i=1
  while i <= #_BUFFERS do
    local buf=_BUFFERS[i]
    if Proj.isRegularBuf(buf) and not buf._dont_close then
      --regular file, close it
      Util.goto_buffer(buf)
      if not io.close_buffer() then
        Proj.updating_ui=Proj.updating_ui-1
        return
      end
    else
      --skip project buffers and don't close buffers
      i= i+1
      buf._dont_close= nil --remove flag
    end
  end
  --check that at least one regular buffer remains after closing
  Proj.check_panels()
  actions.updateaction("dont_close")
  Proj.updating_ui=Proj.updating_ui-1
end

function Proj.keepthisbuff_status()
  return (buffer._dont_close and 1 or 2) --check
end

function Proj.toggle_keep_thisbuffer()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.getout_projview()
  if buffer._dont_close then buffer._dont_close=nil else buffer._dont_close= true end
  actions.updateaction("dont_close")
end

function Proj.showin_rightpanel_status()
  return (buffer._right_side and 1 or 2) --check
end

function Proj.toggle_showin_rightpanel()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.updating_ui=1
  Proj.getout_projview()
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
  Proj.updating_ui=0
  actions.updateaction("showin_rightpanel")
end

function Proj.close_others()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.getout_projview()
  buffer._dont_close= true --force keep this
  --close the other buffers (except the project)
  Proj.onlykeep_projopen(true)
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

function Proj.first_buffer()
  if toolbar then
    toolbar.sel_top_bar()
    toolbar.gototab(0)
  end
end
function Proj.last_buffer()
  if toolbar then
    toolbar.sel_top_bar()
    toolbar.gototab(2)
  end
end

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
        nb=nb+1
        if nb > #_BUFFERS then nb= 1 end
        retry=retry-1
      end
    end
    Proj.goto_buffer(nb)
  end
end

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
        nb=nb-1
        if nb < 1 then nb= #_BUFFERS end
        retry=retry-1
      end
    end
    Proj.goto_buffer(nb)
  end
end

function Proj.switch_buffer()
  local columns, utf8_list = {_L['Name'], _L['File']}, {}
  for i = 1, #_BUFFERS do
    local buffer = _BUFFERS[i]
    local filename = buffer.filename or buffer._type or _L['Untitled']
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

local function try_open(fn)
  if Util.file_exists(fn) then
    ui.statusbar_text= "Open: "..fn
    io.open_file(fn)
    return true
  end
  return false
end

local function try_open_partner(mext, listext)
  local fc= buffer.filename
  if fc then
    fc= fc:match(mext)
    if fc then
      for _,newext in pairs(listext) do
        if try_open(fc..newext) then return true end
      end
    end
  end
  return false
end

--open a file using the selected text or the text under the cursor
--or change buffer extension {c,cpp} <--> {h,hpp} or ask
function Proj.open_cursor_file()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.getout_projview()
  local s, e = buffer.selection_start, buffer.selection_end
  if s == e then
    --suggest current word
    local savewc= buffer.word_chars
    buffer.word_chars= savewc .. ".\\/:-"
    s, e = buffer:word_start_position(s,true), buffer:word_end_position(s,true)
    buffer.word_chars= savewc
  end
  local fn= Util.str_trim(buffer:text_range(s, e))  --remove trailing blanks (like \n)
  local isabspath= fn:match('^/') or fn:match('^\\') or fn:match('^.*:\\')
  if not isabspath then
    --relative path: add buffer dir
    fn= ((buffer.filename or ''):match('^.+[/\\]') or lfs.currentdir())..fn
    --replace aaaa"/dir/../"bbbb" with aaaa"/"bbbb
    while true do
      local a,b= fn:match('(.*)[/\\][^./\\]-[/\\]%.%.[/\\](.*)')
      if a and b then fn= a..(WIN32 and "\\" or "/")..b
      else break end
    end
  end
  if not try_open(fn) then
    if not try_open_partner('^(.+)%.c$', {'.h', '.hpp'}) then
      if not try_open_partner('^(.+)%.cpp$', {'.hpp', '.h'}) then
        if not try_open_partner('^(.+)%.h$', {'.c', '.cpp'}) then
          if not try_open_partner('^(.+)%.hpp$', {'.cpp', '.c'}) then
            ui.statusbar_text= fn.." not found"
            io.open_file() --show open dialog
          end
        end
      end
    end
  end
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
