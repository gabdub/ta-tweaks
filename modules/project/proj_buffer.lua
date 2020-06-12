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
      Proj.goto_filesview(false, true)
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
