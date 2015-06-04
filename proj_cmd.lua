local Proj = Proj
local _L = _L

--open all project files in the current view
function Proj.set_open_panel()
  Proj.files_vn= _VIEWS[view]
end

--open the selected file/s
--when more than one line is selected, ask for confirmation
function Proj.open_sel_file()
  --check we have a file list
  if buffer.proj_files == nil then
    return
  end

  --set project view = this view
  Proj.set_files_view()

  --read selected line range
  r1= buffer.line_from_position(buffer.selection_start)+1
  r2= buffer.line_from_position(buffer.selection_end)+1
  --clear selection
  buffer.selection_start= buffer.selection_end
  if r1 < r2 then
    --more than one line, count files in range
    local flist= {}
    n= 0
    for r= r1, r2 do
      if buffer.proj_files[r] ~= "" then
        n= n+1
        flist[n]= buffer.proj_files[r]
      end
    end
    if n == 0 then
      --no files in range, use current line; action=fold
      r1= buffer.line_from_position(buffer.current_pos)+1
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
        ui.statusbar_text= 'Open: ' .. flist[1]
      else
        ui.statusbar_text= 'Open: ' .. n .. ' files'
      end
      --open all
      for r= 1, n do
        Proj.go_file(flist[r])
      end
      --try to select the current file in the working project
      Proj.track_this_file(true)
      return
    end
  end
  --one line selected
  file = buffer.proj_files[r1]
  if file ~= "" then
    ui.statusbar_text= 'Open: ' .. file
    Proj.go_file(file)
    --try to select the current file in the working project
    Proj.track_this_file(true)
  else
    --there is no file for this row, fold instead
    buffer.toggle_fold(r1)
  end
end

-- add the current file to the project
function Proj.add_this_file()
  local p_buffer = Proj.get_work_buffer()
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

        if Proj.view_n == nil then
          Proj.view_n= 1
        end
        --this file is in the project view
        if _VIEWS[view] == Proj.view_n then
          --choose another view for the file
          Proj.files_vn= nul
        else
          ui.goto_view(Proj.view_n)
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
  local p_buffer = Proj.get_work_buffer()
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

        if Proj.view_n == nil then
          Proj.view_n= 1
        end
        --this file is in the project view
        if _VIEWS[view] == Proj.view_n then
          --choose another view for the file
          Proj.files_vn= nul
        else
          ui.goto_view(Proj.view_n)
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
          p_buffer:goto_line(row-1)
        end
        -- project in SELECTION mode without focus--
        Proj.show_lost_focus(p_buffer)
        p_buffer.home()
        --return to this file (it could be in a different view)
        --Proj.go_file(file)
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

  local buffer = buffer.new()
  buffer.filename = filename
  buffer:append_text('[' .. fn .. ']::' .. rootdir .. '::')
  Proj.check_and_select()
end

--open an existing project file
--TODO: close "untitled" file when another file is opened (if not modified)
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
    ui.goto_view(1)
    ui.statusbar_text= 'Open project: '.. prjfile
    --keep current file after project open
    proj_keep_file= nil
    if buffer ~= nil and buffer.filename ~= nil then
      proj_keep_file= buffer.filename
    end
    --open the project
    io.open_file(prjfile)
    --project ui
    Proj.update_after_switch()
    --restore the file that was current before opening the project
    if proj_keep_file then
      Proj.go_file(proj_keep_file)
    end
  end
end

--open a project from the recent list
function Proj.open_recent_project()
  --TODO: finish this
end

--close current project / view
function Proj.close_project(keepviews)
  local p_buffer = Proj.get_work_buffer()
  if p_buffer ~= nil then
    if #_VIEWS > 1 then
      if Proj.view_n ~= nil then
        ui.goto_view(Proj.view_n)
      else
        ui.goto_view(1)
      end
    end
    view.goto_buffer(view, _BUFFERS[p_buffer], false)
    if io.close_buffer() then
      if not keepviews then
        if #_VIEWS > 1 then
          view.unsplit(view)
        end
        --reset project view
        Proj.view_n= 1
        --split the view for files
        Proj.files_vn= null
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