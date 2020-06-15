-- Copyright 2020 Gabriel Dubatti. See LICENSE.
--
-- This module implements the selection of project files using a buffer
--
-- ** This module is NOT used when USE_LISTS_PANEL is true **
--
local Proj = Proj
local data = Proj.data
local Util = Util

--return the project buffer (the working one)
--enforce: project in preferred view, mark it as the "working one"
function Proj.get_projectbuffer(force_view)
  -- search for the working project
  local pbuff, nview
  local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
  for _, buffer in ipairs(_BUFFERS) do
    if buffer._is_working_project then
      --working project found
      if not force_view or _VIEWS[projv].buffer == buffer then
        return buffer --ok (is in the right view)
      end
      --need to change the view
      pbuff = buffer
      break
    end
  end
  if pbuff == nil then
    -- not found, choose a new one
    -- 1) check the preferred project view
    if projv <= #_VIEWS and _VIEWS[projv].buffer._project_select ~= nil then
      _VIEWS[projv].buffer._is_working_project = true
      return _VIEWS[projv].buffer --ok (marked and in the right view)
    end
    -- 2) check projects in all views
    for i= 1, #_VIEWS do
      if _VIEWS[i].buffer._project_select ~= nil then
        pbuff = _VIEWS[i].buffer
        nview = i
        break
      end
    end
    if pbuff == nil then
      -- 3) check all buffers, use the first found
      for _, buffer in ipairs(_BUFFERS) do
        if buffer._project_select ~= nil then
          pbuff = buffer
          break
        end
      end
    end
  end

  if pbuff then
    --force: marked as the working project
    pbuff._is_working_project = true
    --force: show the project in the preferred view
    if force_view then Proj.force_buffer_inview(pbuff, projv) end
  end
  return pbuff
end

--------------- LISTS INTERFACE --------------
function plugs.init_projectview()
  --check if a project buffer is open
  --TODO: use Proj.data.is_open
  --TODO: mark rigth side files
  for _, buff in ipairs(_BUFFERS) do
    if Proj.is_prj_buffer(buff) then  --the buffer is a valid project?
      data.filename= buff.filename
      data.is_open= true
      --activate project in the proper view
      Proj.goto_projview(Proj.PRJV_PROJECT)
      Util.goto_buffer(buff)
      --hidden / shown in selection mode
      Proj.selection_mode() --open in selection mode (parse data.filename)
      --keep the saved value (hidden / selection mode)
      if data.config.show_mode == Proj.SM_HIDDEN then data.show_mode= Proj.SM_HIDDEN end
      --start in left/only files view
      Proj.goto_filesview(Proj.FILEPANEL_LEFT)
      --check that at least there's one regular buffer
      local rbuf = Proj.getBufFromPanel(Proj.FILEPANEL_LEFT)
      if rbuf == nil then
        --no regular buffer found
        Proj.go_file() --open a blank file
      end
      return
    end
  end
  --no project file found
  Proj.closed_cleardata() --clear Proj.data and notify end of config load
end

function plugs.goto_projectview()
  --activate/create project view
  Util.goto_view(Proj.prefview[Proj.PRJV_PROJECT])
  return true
end

function plugs.projmode_select()
  --activate select mode
  local buff= Proj.get_projectbuffer(false) or buffer

  --mark this buffer as a project in SELECTION mode
  buff._project_select= true
  --selection is read-only
  buff.read_only= true
  --the current caret line is always visible
  buff.caret_line_visible_always= true
  --hide scrollbars
  buff.h_scroll_bar= false
  buff.v_scroll_bar= false

  --set lexer to highlight groups and hidden control info ":: ... ::"
  buff:set_lexer('myproj')
  --project in SELECTION mode--
  Proj.show_sel_w_focus(buff)

  --set SELECTION mode context menu
  Proj.set_contextm_sel()

  --fold the requested folders
  for i= #data.proj_fold_row, 1, -1 do
    buff.toggle_fold(data.proj_fold_row[i])
  end
  Proj.mark_open_files(buff)

  if toolbar then toolbar.seltabbuf(buff) end --hide/show and select tab in edit mode
end

function plugs.projmode_edit()
  --activate edit mode
  local buff= Proj.get_projectbuffer(false) or buffer

  --mark this buffer as a project in EDIT mode
  buff._project_select= false
  --allow to edit the project
  buff.read_only= false
  --the current line is not always visible
  buff.caret_line_visible_always= false
  --show scrollbars
  buff.h_scroll_bar= true
  buff.v_scroll_bar= true

  --edit project as a text file (show control info)
  buff:set_lexer('text')
  --set EDIT mode context menu
  Proj.set_contextm_edit()
  --project in EDIT mode--
  Proj.show_default(buff)
  Proj.clear_open_indicators(buff)

  if toolbar then toolbar.seltabbuf(buff) end --hide/show and select tab in edit mode
end

--try to select the current file in the working project
--(only if the project is currently visible)
function plugs.track_this_file()
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
        Util.goto_line(p_buffer,row)
        p_buffer:home()
        --hilight the file as open
        Proj.add_open_indicator(p_buffer,row)
         -- project in SELECTION mode without focus--
        Proj.show_lost_focus(p_buffer)
        --return to this file (it could be in a different view)
        Proj.go_file(file)

        Proj.stop_update_ui(false)
      end
    end
  end
end

function plugs.proj_refresh_hilight()
  -- refresh syntax highlighting + project folding
  if buffer._project_select ~= nil then
    Proj.toggle_selectionmode()
    Proj.toggle_selectionmode()
  end
end

function plugs.close_project(keepviews)
  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer ~= nil then
    local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
    if #_VIEWS >= projv then
      Util.goto_view(projv)
    end
    Util.goto_buffer(p_buffer)
    if Util.close_buffer() then
      Proj.closed_cleardata()
      if not keepviews then
        plugs.close_results()
        if #_VIEWS > 1 then
          view.unsplit(view)
        end
      end
    else
      --close was cancelled
      return false
    end
  end

  --<<<< REMOVE THIS WHEN READY
  if toolbar and toolbar.list_show_projects then toolbar.list_show_projects() end

  return true
end

function plugs.get_prj_currow()
  --get the selected project row number
  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer == nil then
    ui.statusbar_text= 'No project found'
    return 0
  end
  return p_buffer.line_from_position(p_buffer.current_pos) +1 -Util.LINE_BASE
end

--open the selected file/s
--when more than one line is selected, ask for confirmation
function plugs.open_sel_file()
  --check we have a file list
  if #data.proj_files == 0 then return end

  --read selected line range
  local r1= buffer.line_from_position(buffer.selection_start) +1 -Util.LINE_BASE
  local r2= buffer.line_from_position(buffer.selection_end) +1 -Util.LINE_BASE
  --clear selection
  buffer.selection_start= buffer.selection_end

  --count files/run in range
  local flist= {}
  local rlist= {}
  for r= r1, r2 do
    if data.proj_files[r] ~= "" then
      local ft= data.proj_filestype[r]
      if ft == Proj.PRJF_FILE or ft == Proj.PRJF_CTAG then
        flist[ #flist+1 ]= data.proj_files[r]
      elseif ft == Proj.PRJF_RUN then
        rlist[ #rlist+1 ]= data.proj_files[r]
      end
    end
  end
  if #flist == 0 and #rlist == 0 then
    --no files/run in range, use current line; action=fold
    r1= buffer.line_from_position(buffer.current_pos) +1 -Util.LINE_BASE
    if data.proj_files[r] ~= "" then
      local ft= data.proj_filestype[r]
      if ft == Proj.PRJF_FILE or ft == Proj.PRJF_CTAG then
        flist[ #flist+1 ]= data.proj_files[r]
      elseif ft == Proj.PRJF_RUN then
        rlist[ #rlist+1 ]= data.proj_files[r]
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
    local confirm = (#list == 1) or Util.confirm( action..' confirmation',
      'There are ' .. #list .. ' files selected', 'Do you want to open them?')
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
    plugs.track_this_file()
  else
    --there is no file for this row, fold instead
    buffer.toggle_fold(r1)
  end
end
