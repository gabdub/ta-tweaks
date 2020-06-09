-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
local events = events
local Proj = Proj
local data = Proj.data
local Util = Util

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

--get the buffer type: Proj.PRJT_...
local function getprj_buffertype(p_buffer)
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
  --check if the buffer is a valid project
  --The first file line MUST BE a valid "option 1)": ...##...##...
  local line= p_buffer:get_line( Util.LINE_BASE )
  local n, fn, opt = string.match(line,'^%s*(.-)%s*::(.*)::(.-)%s*$')
  if n ~= nil then
    return Proj.PRJB_PROJ_NEW         --is a project file not marked as such yet
  end
  return Proj.PRJB_NORMAL             --is a regular file
end

-- TA-EVENT INITIALIZED
function Proj.EVinitialize()
  --session load complete: verify all the buffers (this prevents view creation conflicts)
  Proj.stop_update_ui(false)

  --load recent projects list / project preferences
  Proj.load_config()
  --check if a search results buffer is open
  plugs.init_searchview()
  --check if a project file is open
  --TODO: mark rigth side files
  for _, buff in ipairs(_BUFFERS) do
    --check buffer type
    local pt= getprj_buffertype(buff)
    if pt == Proj.PRJB_PROJ_NEW or pt == Proj.PRJB_PROJ_SELECT then
      data.filename= buff.filename
      data.is_open= true
      --activate project in the proper view
      Proj.goto_projview(Proj.PRJV_PROJECT)
      Util.goto_buffer(buff)
      if data.is_visible == Proj.V_EDIT then
        Proj.ifproj_seteditmode(buff)  --edit mode
      else
        --hidden / shown in selection mode
        Proj.ifproj_setselectionmode(buff) --selection mode (this set data.is_visible= selection mode)
        data.is_visible= data.config.is_visible  --keep the original value (hidden or selection mode)
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
--returns true if the buffer is a regular file (not a project nor a search results)
function Proj.isRegularBuf(pbuffer)
  return (pbuffer._project_select == nil) and (pbuffer._type ~= Proj.PRJT_SEARCH)
end

--returns true if the buffer must be hidden in the tab control
--NOTE: a project is hidden only in select mode
function Proj.isHiddenTabBuf(pbuffer)
  return pbuffer._project_select or pbuffer._type == Proj.PRJT_SEARCH
end

function Proj.changeViewBuf(pbuffer)
  --check if a view change is needed
  if #_VIEWS > 1 then
    if pbuffer._project_select ~= nil then
      --project buffer: force project view
      Util.goto_view(Proj.prefview[Proj.PRJV_PROJECT]) --preferred view for project
      return true --changed
    end
    --search results?
    if pbuffer._type == Proj.PRJT_SEARCH then
      plugs.goto_searchview()
      return true --changed
    end
    --normal file: check we are not in a project view
    --change to left/right files view if needed (without project: 1/2, with project: 2/4)
    Proj.goto_filesview(false, pbuffer._right_side)
  end
  return false
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

------------------PROJECT CONTROL-------------------
--set the project mode as: selected (selmode=true) or edit (selmode=false)
--if selmode=true, parse the project and build file list: "proj_file[]"
local function setproj_selectionmode(buff,selmode)
  if selmode and buff.modify then
    data.is_parsed= false --prevent list update when saving the project until it's parsed
    Util.save_file()
  end
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
    --fill Proj.data arrays: "proj_files[]", "proj_fold_row[]" and "proj_grp_path[]"
    Proj.parse_project_file()
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
    data.is_visible= Proj.V_SELECT  --selection mode
    Proj.mark_open_files(buff)
  else
    --edit project as a text file (show control info)
    buff:set_lexer('text')
    --set EDIT mode context menu
    Proj.set_contextm_edit()
    --project in EDIT mode--
    Proj.show_default(buff)
    data.is_visible= Proj.V_EDIT  --edit mode
    Proj.clear_open_indicators(buff)
  end
  if toolbar then
    Proj.update_projview()  --update project view button
    if toolbar then toolbar.seltabbuf(buff) end --hide/show and select tab in edit mode
  end
end

--if the current file is a project, enter SELECTION mode--
function Proj.ifproj_setselectionmode(p_buffer)
  if not p_buffer then p_buffer = buffer end  --use current buffer?
  if getprj_buffertype(p_buffer) >= Proj.PRJB_PROJ_MIN then
    setproj_selectionmode(p_buffer,true)
    if p_buffer.filename then
      ui.statusbar_text= 'Project file =' .. p_buffer.filename
    end
    return true
  end
  return false
end

--if the current file is a project, enter EDIT mode--
function Proj.ifproj_seteditmode(p_buffer)
  if not p_buffer then p_buffer = buffer end  --use current buffer?
  if getprj_buffertype(p_buffer) >= Proj.PRJB_PROJ_MIN then
    setproj_selectionmode(p_buffer,false)
    if p_buffer.filename then
      ui.statusbar_text= 'Project file =' .. p_buffer.filename
    end
    return true
  end
  return false
end

--toggle project between SELECTION and EDIT modes
function Proj.toggle_selectionmode()
  local mode= getprj_buffertype(buffer)
  if mode == Proj.PRJB_PROJ_SELECT or mode == Proj.PRJB_PROJ_EDIT then
    setproj_selectionmode(buffer, (mode == Proj.PRJB_PROJ_EDIT)) --toggle current mode
  else
    --if the current file is a project, enter SELECTION mode--
    if not Proj.ifproj_setselectionmode() then
      ui.statusbar_text= 'This file is not a project'
    end
  end
  buffer.home()
end

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

--open files in the preferred view
--optinal: goto line_num
function Proj.go_file(file, line_num)
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  if file == nil or file == '' then
    Proj.getout_projview()
    --new file (add only one)
    local n= nil
    for i=1, #_BUFFERS do
      local b= _BUFFERS[i]
      if (b.filename == nil) and (b._type == nil) and (not b._right_side) then
        n= i --there is one new file, select this instead of adding a new one
        break
      end
    end
    if n == nil then
      buffer.new()
      n= _BUFFERS[buffer]
      events.emit(events.FILE_OPENED)
    end
    Util.goto_buffer(_BUFFERS[n])
  else
    --goto file / line_num
    local fn = file:iconv(_CHARSET, 'UTF-8')
    for i, buf in ipairs(_BUFFERS) do
      if buf.filename == fn then
        --already open (keep panel)
        Proj.getout_projview(buf._right_side, true)
        Util.goto_buffer(buf)
        fn = nil
        break
      end
    end
    Proj.getout_projview()
    if fn then io.open_file(fn) end

    if line_num then Util.goto_line(buffer, line_num) end
    Proj.update_after_switch()
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
      --check if this file is in the project
      local in_prj= (Proj.get_file_row(file) ~= nil)
      finprj[ #finprj+1]= in_prj
      if in_prj then n_inprj= n_inprj+1 end
    end
    --if some files are already in the project, ask for confirmation
    local info= '1 file is'
    if n_inprj > 1 then info= '' .. n_inprj .. ' files are' end
    local all= true
    local nadd= #flist
    local confirm = (n_inprj == 0) or Util.confirm( 'Add confirmation',
      info..' already in the project', 'Do you want to add it/them again?')
    if (not confirm) and (#flist > n_inprj) then
      all= false
      nadd= #flist - n_inprj
      if nadd == 1 then
        info= '1 file is'
      else
        info= '' .. nadd .. ' files are'
      end
      confirm = (n_inprj == 0) or Util.confirm( 'Add confirmation',
        info..' not in the project', 'Do you want to add it/them?')
    end
    if confirm then
      --prevent some events to fire forever
      Proj.stop_update_ui(true)

      local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
      --this file is in the project view
      if _VIEWS[view] ~= projv then
        Util.goto_view(projv)
      end

      local row= Proj.add_files_to_project(flist, groupfiles, all, finprj)
      if row then
        local save_ro= p_buffer.read_only
        p_buffer.read_only= false
        Util.reload_file()
        p_buffer.read_only= save_ro

        --move the selection bar to the first added file
        Util.goto_line(p_buffer, row)
      end

      -- project in SELECTION mode without focus--
      Proj.show_lost_focus(p_buffer)
      p_buffer.home()
      if row then ui.statusbar_text= '' .. nadd .. ' file/s added to project' end

      Proj.stop_update_ui(false)
    end
  end
end

-- find text in project's files
-- code adapted from module: find.lua
-- where: 0=ALL project files, 1=selected directory, 2=selected file
function Proj.find_in_files(currow, text, match_case, whole_word, escapetext, where)
  local fromrow=1
  local filterpath
  if where == 1 then --only in selected directory
    if currow <= #data.proj_files then
      local ftype= data.proj_filestype[currow]
      if ftype == Proj.PRJF_PATH then
        filterpath= data.proj_grp_path[currow]
      elseif ftype == Proj.PRJF_FILE then
        local file= data.proj_files[currow]
        if file and file ~= '' then
          local p,f,e= Util.splitfilename(file)
          filterpath= p
        end
      end
    end
    if not filterpath then
      ui.statusbar_text= "No selected directory"
      return
    end
  elseif where == 2 then --only in selected file
    fromrow= currow
  end

  if not plugs.search_result_start then
    ui.statusbar_text= "No search results module found"
    return
  end
  --a new "search in files" begin
  plugs.search_result_start(text, filterpath)

  if escapetext then text= Util.escape_match(text) end
  if whole_word then text = '%f[%w_]'..(match_case and text or text:lower())..'%f[^%w_]' end

  local nfiles= 0
  local totfiles= 0
  local nfound= 0
  local filesnf= 0
  local torow= #data.proj_files
  if where == 2 and fromrow < torow then torow= fromrow end
  for row= fromrow, torow do
    local ftype= data.proj_filestype[row]
    if ftype == Proj.PRJF_FILE then --ignore CTAGS files / path / empty rows
      local file= data.proj_files[row]
      if file and file ~= '' then
        if not Util.file_exists(file) then
          filesnf= filesnf+1 --file not found
          plugs.search_result_info(file..' NOT FOUND', true)
        else
          file = file:iconv('UTF-8', _CHARSET)
          local p,f,e= Util.splitfilename(file)
          if f == '' then
            f= file
          end
          if (not filterpath) or (filterpath == p) then
            local line_num = 1
            totfiles = totfiles + 1
            local prt_fname= true
            for line in io.lines(file) do
              local s, e = (match_case and line or line:lower()):find(text)
              if s and e then
                if prt_fname then
                  prt_fname= false
                  nfiles = nfiles + 1
                  plugs.search_result_in_file(f, file, nfiles)
                end
                plugs.search_result_found(file, line_num, line, s, e)
                nfound = nfound + 1
              end
              line_num = line_num + 1
            end
          end
        end
      end
    end
  end

  if nfound == 0 then
    plugs.search_result_info(_L['No results found'], false)
  end
  plugs.search_result_end()

  local result= ''..nfound..' matches in '..nfiles..' of '..totfiles..' files'
  if filesnf > 0 then
    result= result .. ' / '..filesnf..' files NOT FOUND'
  end
  ui.statusbar_text= result
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

--------hilight project's open files--------
local indic_open = _SCINTILLA.next_indic_number()
buffer.indic_fore[indic_open]= (tonumber(buffer.property['color.prj_open_mark']) or 0x404040)
buffer.indic_style[indic_open]= buffer.INDIC_DOTS

--remove all open-indicators from project
function Proj.clear_open_indicators(pbuf)
  pbuf.indicator_current= indic_open
  pbuf:indicator_clear_range(Util.LINE_BASE, pbuf.length)
end

function Proj.add_open_indicator(pbuf,row)
  local r= row -1 + Util.LINE_BASE
  pbuf.indicator_current= indic_open
  local pos= pbuf.line_indent_position[r]
  local len= pbuf.line_end_position[r] - pos
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
        Proj.add_open_indicator(pbuf,row)
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
  buff.margin_width_n[Util.LINE_BASE] = 0
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
  buff.margin_width_n[ Util.LINE_BASE ] = width + (not CURSES and 4 or 0)
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
    --NOT a PROJECT buffer: restore current line default settings
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
          Util.close_buffer()
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
    local fromln= buffer:line_from_position(buffer.current_pos) + Util.LINE_BASE-1
    local toln= Util.LINE_BASE
    for i = fromln, toln, -1 do
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
    --1) try to close the config panel
    if toolbar and toolbar.hide_config() then return end
    --2) try to close the search view
    if plugs.close_results() then return end
    --3) change view
    if #_VIEWS > 1 then
      local nv= _VIEWS[view] +1
      if nv > #_VIEWS then nv=1 end
      Util.goto_view(nv)
      if nv == Proj.prefview[Proj.PRJV_PROJECT] and data.is_visible == Proj.V_HIDDEN then
        --in project's view, force visibility
        data.is_visible= Proj.V_SELECT  --selection mode
        view.size= data.select_width
        Proj.update_projview()
        Proj.temporal_view= true  --close if escape is pressed again or if a file is opened

      elseif Proj.temporal_view then
        Proj.temporal_view= false
        Proj.toggle_projview()
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
        if data.select_width ~= view.size then
          data.select_width= view.size  --save current width
          if data.select_width < 50 then data.select_width= 200 end
          data.recent_prj_change= true  --save it on exit
        end
        data.is_visible= Proj.V_EDIT  --edit mode
        view.size= data.edit_width
      else
        if data.edit_width ~= view.size then
          data.edit_width= view.size  --save current width
          if data.edit_width < 50 then data.edit_width= 600 end
          data.recent_prj_change= true  --save it on exit
        end
        data.is_visible= Proj.V_SELECT  --selection mode
        view.size= data.select_width
      end
    end
    Proj.toggle_selectionmode()
    refresh_syntax()
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
    if data.is_visible == Proj.V_HIDDEN then
      data.is_visible= Proj.V_SELECT  --selection mode
      view.size= data.select_width
      Proj.update_projview()
    end
  end
end

--Show/Hide project
function Proj.show_hide_projview()
  if ena_toggle_projview() then
    if data.is_visible == Proj.V_EDIT then
      --project in edit mode
      Proj.goto_projview(Proj.PRJV_PROJECT)
      Proj.change_proj_ed_mode() --return to select mode
      return
    end
    --select mode
    Proj.goto_projview(Proj.PRJV_PROJECT)
    if view.size then
      if data.is_visible ~= Proj.V_HIDDEN then
        data.is_visible= Proj.V_HIDDEN  --hidden
        if data.select_width ~= view.size then
          data.select_width= view.size  --save current width
          if data.select_width < 50 then data.select_width= 200 end
          data.recent_prj_change= true  --save it on exit
        end
        view.size= 0
      else
        data.is_visible= Proj.V_SELECT  --selection mode
        view.size= data.select_width
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
    elseif _BUFFERS[ntab]._type == Proj.PRJT_SEARCH then plugs.goto_searchview()
    --normal file: check we are not in a project view
    else Proj.goto_filesview(false, _BUFFERS[ntab]._right_side) end
  end
end

--goto the view for the requested project buffer type
--split views if needed
function Proj.goto_projview(prjv)
  local pref= Proj.prefview[prjv] --preferred view for this buffer type
  if pref == _VIEWS[view] then
    return false --already in the right view
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
  return true
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
function Proj.getout_projview(right_side, force)
  if (buffer._project_select ~= nil or buffer._type ~= nil) then
    --move to files view (left/only panel) and exit
    Proj.goto_filesview(true,right_side)
    return true
  end
  if force then --enforce left/right view?
    return Proj.goto_projview( (right_side) and Proj.PRJV_FILES_2 or Proj.PRJV_FILES )
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
    plugs.goto_searchview()
  else
    --activate files view
    Proj.goto_filesview(true, b._right_side)
    Util.goto_buffer(b)
  end
end

------SEARCH VIEW------
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
  if (vsp > 0) and (#_VIEWS >= vsp) then
    plugs.goto_searchview()
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
        plugs.close_results(true) --close the search view too
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

-- replace Open uri(s) code (core/ui.lua)
function Proj.drop_uri(utf8_uris)
  ui.goto_view(view) -- work around any view focus synchronization issues
  Proj.goto_filesview() --don't drop files in project views
  for utf8_uri in utf8_uris:gmatch('[^\r\n]+') do
    if utf8_uri:find('^file://') then
      local path = utf8_uri:match('^file://([^\r\n]+)')
      path = path:gsub('%%(%x%x)', function(hex)
        return string.char(tonumber(hex, 16))
      end):iconv(_CHARSET, 'UTF-8')
      -- In WIN32, ignore a leading '/', but not '//' (network path).
      if WIN32 and not path:match('^//') then path = path:sub(2, -1) end
      local mode = lfs.attributes(path, 'mode')
      if mode and mode ~= 'directory' then io.open_file(path) end
    end
  end
  Proj.update_after_switch()
  return false
end
