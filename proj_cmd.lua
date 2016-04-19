local Proj = Proj
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
    Proj.track_this_file(true)
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
      local confirm = (Proj.locate_file(p_buffer, file) == nil) or ui.dialogs.msgbox{
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
          ui.goto_view(projv)
        end

        --if the project is in readonly, change it
        save_ro= p_buffer.read_only
        p_buffer.read_only= false
        path,fn,ext = Proj.splitfilename(file)
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
    flist= {}
    finprj= {}
    n_inprj= 0
    for _, b in ipairs(_BUFFERS) do
      file= b.filename
      if file ~= nil and b._project_select == nil then
        flist[ #flist+1 ]= file
        --check if already in the project
        in_prj= (Proj.locate_file(p_buffer, file) ~= nil)
        finprj[ #finprj+1]= in_prj
        if in_prj then n_inprj= n_inprj+1 end
      end
    end
    if #flist > 0 then
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
          ui.goto_view(projv)
        end

        --if the project is in readonly, change it
        save_ro= p_buffer.read_only
        p_buffer.read_only= false
        row= nil
        for i= 1, #flist do
          if all or finprj[i] == false then
            file= flist[i]
            path,fn,ext = Proj.splitfilename(file)
            --TODO: reduce the path is possible using project root
            p_buffer:append_text( '\n ' .. fn .. '::' .. file .. '::')
            --add the new line to the proj. file list
            row= #p_buffer.proj_files+1
            p_buffer.proj_files[row]= file
          end
        end
        p_buffer.read_only= save_ro
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
  else
    ui.statusbar_text='Project not found'
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
  path,fn,ext = Proj.splitfilename(filename)
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
  -- project in SELECTION mode without focus--
  Proj.set_selectionmode(true)
  Proj.show_lost_focus(buffer)
  --update ui
  Proj.updating_ui= 1
  Proj.goto_filesview() --change to files
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
function Proj.open_project()
  prjfile= ui.dialogs.fileselect{
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
    Proj.goto_filesview() --change to files
    Proj.updating_ui= 0
    -- project in SELECTION mode without focus--
    local p_buffer = Proj.get_projectbuffer(true)
    Proj.show_lost_focus(p_buffer)

    --project ui
    Proj.ifproj_setselectionmode()
    --restore the file that was current before opening the project or open an empty one
    Proj.go_file(proj_keep_file)
  end
end

-- Closes the initial "Untitled" buffer (project version)
events.connect(events.FILE_OPENED, function()
  if #_BUFFERS == 3 then
    local buf = _BUFFERS[1]
    local nbuf = 1
    if buf._project_select ~= nil then
      buf = _BUFFERS[2]
      nbuf = 2
    end
    if not (buf.filename or buf._type or buf.modify) then
      view:goto_buffer(nbuf)
      io.close_buffer()
    end
  end
end)

--open a project from the recent list
function Proj.open_recent_project()
  --TODO: finish this
end

--close current project / view
function Proj.close_project(keepviews)
  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer ~= nil then
    local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
    if #_VIEWS >= projv then
      ui.goto_view(projv)
    end
    view.goto_buffer(view, _BUFFERS[p_buffer], false)
    if io.close_buffer() then
      if not keepviews then
        if #_VIEWS > 1 then
          view.unsplit(view)  --TODO: close all views
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