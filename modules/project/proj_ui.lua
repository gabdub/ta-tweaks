-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
local events = events
local Proj = Proj
local data = Proj.data
local Util = Util

--  Proj.update_ui= number of ui updates in progress (ignore some events if > 0)
Proj.update_ui= 0
local _initializing= true --true until Proj.EVinitialize() is called

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

-- TA-EVENT INITIALIZED
function Proj.EVinitialize()
  --session load complete: verify all the buffers (this prevents view creation conflicts)
  Proj.stop_update_ui(false)

  --load recent projects list / project preferences
  Proj.load_config()

  --check if a project buffer is open
  plugs.init_projectview()
  --check if a search results buffer is open
  plugs.init_searchview()

  Proj.update_after_switch()
  Proj.update_projview_action() --update action: toggle_viewproj/toggle_editproj
  _initializing= false
end

-- TA-EVENT QUIT: Saves recent projects list
function Proj.EVquit()
  --end file compare
  Proj.stop_compare()
  --end edit mode at exit
  if data.show_mode == Proj.SM_EDIT then plugs.change_proj_ed_mode() end
  --remove all buf._type= Util.UNTITLED_TEXT
  for _, buf in ipairs(_BUFFERS) do
    if buf._type == Util.UNTITLED_TEXT then buf._type= nil end
  end
  Proj.save_config()
end

-------- buffer/view functions----------
--returns true if the buffer is a regular file (not a project nor a search results)
function Proj.isRegularBuf(pbuffer)
  return (pbuffer._project_select == nil) and (pbuffer._type ~= Proj.PRJT_SEARCH)
end

--returns true if the buffer must be hidden in the tab control
--NOTE: a project is hidden only in select mode
function Proj.isHiddenTabBuf(pbuffer)
  return pbuffer._project_select or pbuffer._type == Proj.PRJT_SEARCH
end

function Proj.check_is_open()
  if not data.is_open then
    ui.statusbar_text= 'You must first open a project'
  end
  return data.is_open
end

function Proj.get_projview(prjv)
  if prjv < 1 then return 0 end --invalid param
  local pref= Proj.prefview[prjv] --preferred view for this buffer type
  if not data.is_open then
    --when the project is closed use view #2 for the right panel and #1 for everything else
    pref= (prjv == Proj.PRJV_FILES_2) and 2 or 1
  end
  return pref
end

--goto the view for the requested project buffer type
--split views if needed
--return true when the view changes
function Proj.goto_projview(prjv)
  local pref= Proj.get_projview(prjv) --preferred view for this buffer type
  if prjv < 1 then return false end --invalid param

  if pref == _VIEWS[view] then return false end --already in the right view
  local nv= #_VIEWS
  while pref > nv do
    --more views are needed: split the last one
    local porcent = Proj.prefsplit[nv][1]
    local vertical= Proj.prefsplit[nv][2]
    local splitview=Proj.prefsplit[nv][3]
    if not data.is_open then
      porcent= 0.50 --the project is closed: split 50% vertical
      vertical= true
      splitview= 1
    end
    Util.goto_view(splitview)
    --split view to show search results
    view:split(vertical)
    --adjust view size (actual = 50%)
    view.size= math.floor(view.size*porcent*2)
    nv= nv +1
    if nv ~= pref and (nv == Proj.get_projview(Proj.PRJV_FILES) or nv == Proj.get_projview(Proj.PRJV_FILES_2)) then
      --create an empty file
      Util.goto_view(nv)
      buffer.new()
    elseif nv == Proj.prefview[Proj.PRJV_SEARCH] then
      --create an empty search results buffer
      Util.goto_view(nv)
      buffer.new()
      buffer._type = Proj.PRJT_SEARCH
      events.emit(events.FILE_OPENED)
    end
  end
  Util.goto_view(pref)
  return true --view changed
end

Proj.FILEPANEL_ANY=    0
Proj.FILEPANEL_LEFT=   1
Proj.FILEPANEL_RIGHT=  2
--find the first regular buffer
--panel=0 (any), panel=1 (_right_side=false), panel=2 (_right_side=true)
function Proj.getBufFromPanel(panel)
  --prefer MRU order (ask ctrl_tab_mru)
  if gettop_MRUbuff then return gettop_MRUbuff((panel==Proj.FILEPANEL_ANY), (panel==Proj.FILEPANEL_RIGHT)) end
  --ctrl_tab_mru not installed: use buffer orden
  for _, buf in ipairs(_BUFFERS) do
    if Proj.isRegularBuf(buf) then
      if (panel==Proj.FILEPANEL_ANY) or
         ((panel==Proj.FILEPANEL_LEFT) and (not buf._right_side)) or
         ((panel==Proj.FILEPANEL_RIGHT) and (buf._right_side)) then return buf end
    end
  end
  return nil
end

--goto a view for editing files (split views if needed)
--panel=0 (any), panel=1 (_right_side=false), panel=2 (_right_side=true)
--return true when the view changes
function Proj.goto_filesview(panel)
  if (not panel or panel == Proj.FILEPANEL_ANY) and Proj.isRegularBuf(buffer) then return false end  --no change is needed
  return Proj.goto_projview( (panel == Proj.FILEPANEL_RIGHT) and Proj.PRJV_FILES_2 or Proj.PRJV_FILES )
end

function Proj.tab_changeView(pbuffer)
  --when a tab is clicked check if a view change is needed
  if #_VIEWS > 1 then
    --project buffer: force project view
    if pbuffer._project_select ~= nil then return plugs.goto_projectview() end
    --search results?
    if pbuffer._type == Proj.PRJT_SEARCH then return plugs.goto_searchview() end
    --normal file: check we are not in a project view
    --change to left/right files view if needed (without project: 1/2, with project: 2/4)
    Proj.goto_filesview(pbuffer._right_side and Proj.FILEPANEL_RIGHT or Proj.FILEPANEL_LEFT)
  end
  return false
end

-- TA-EVENT TAB_CLICKED
function Proj.EVtabclicked(ntab)
  --tab clicked = buffer num; check if a view change is needed
  Proj.tab_changeView(_BUFFERS[ntab])
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
    Proj.goto_filesview(b._right_side and Proj.FILEPANEL_RIGHT or Proj.FILEPANEL_LEFT)
    Util.goto_buffer(b)
  end
end

------------------PROJECT CONTROL-------------------
function Proj.update_projview_action() --update action: toggle_viewproj/toggle_editproj
  if toolbar then
    if not USE_LISTS_PANEL then actions.updateaction("toggle_viewproj") end --only for project in BUFFER mode
    actions.updateaction("toggle_editproj")
  end
end

-- ENTER SELECTION mode
function Proj.selection_mode()
  if data.is_open then
    data.show_mode= Proj.SM_SELECT  --selection mode
    Proj.update_projview_action()  --update action: toggle_viewproj/toggle_editproj
    ui.statusbar_text= 'Project: ' .. data.filename

    --if modified, save the project buffer
    local fn = data.filename:iconv(_CHARSET, 'UTF-8')
    for _, buff in ipairs(_BUFFERS) do
      if buff.filename == fn then
        if buff.modify then
          Util.goto_buffer(buff)
          Util.save_file()
        end
        break
      end
    end
    --parse project (fill Proj.data arrays: "proj_files[]", "proj_fold_row[]" and "proj_grp_path[]")
    Proj.parse_project_file()
    --visualize select mode
    plugs.projmode_select()
  end
end

-- ENTER EDIT mode
function Proj.seteditmode()
  if data.is_open then
    data.show_mode= Proj.SM_EDIT  --edit mode
    Proj.update_projview_action()  --update action: toggle_viewproj/toggle_editproj
    ui.statusbar_text= 'Edit project: ' .. data.filename
    --visualize edit mode
    plugs.projmode_edit()
  end
end

-- TOGGLE between SELECTION and EDIT modes
function Proj.toggle_selectionmode()
  --toggle current mode: select->edit; hidden/edit->select
  if data.show_mode == Proj.SM_SELECT then Proj.seteditmode() else Proj.selection_mode() end
end

--open files in the preferred view
--optinal: goto line_num
function Proj.go_file(file, line_num)
  if file == nil or file == '' then
    Proj.goto_filesview(Proj.FILEPANEL_LEFT)
    --new file
    local n= nil
    for i=1, #_BUFFERS do
      local b= _BUFFERS[i]
      if (b.filename == nil) and (b._type == nil or b._type == Util.UNTITLED_TEXT) and (not b._right_side) then
        n= i --select this instead of adding a new one
        break
      end
    end
    if n == nil then
      buffer.new()
      n= _BUFFERS[buffer]
    end
    Util.goto_buffer(_BUFFERS[n])
  else
    --goto file / line_num
    local fn = file:iconv(_CHARSET, 'UTF-8')
    for i, buf in ipairs(_BUFFERS) do
      if buf.filename == fn then
        --already open (keep the side)
        Proj.goto_filesview(buf._right_side and Proj.FILEPANEL_RIGHT or Proj.FILEPANEL_LEFT)
        Util.goto_buffer(buf)
        fn = nil
        break
      end
    end
    Proj.goto_filesview()
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
function Proj.add_files(flist, groupfiles)
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
      Proj.goto_projview(Proj.PRJV_PROJECT)

      local added= (Proj.add_files_to_project(flist, groupfiles, all, finprj) ~= nil)
      plugs.update_proj_buffer(added)
      if added then ui.statusbar_text= '' .. nadd .. ' file/s added to project' end

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
  Proj.goto_filesview()
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
  plugs.update_after_switch()
  Proj.stop_update_ui(false)
end

------------------ TA-EVENTS -------------------
-- TA-EVENT BUFFER_BEFORE_SWITCH or VIEW_BEFORE_SWITCH
function Proj.check_lost_focus()
  plugs.check_lost_focus(buffer)
end

-- TA-EVENT BUFFER_AFTER_SWITCH or VIEW_AFTER_SWITCH
function Proj.EVafter_switch()
  --set/restore lexer/ui after a buffer/view switch
  Proj.update_after_switch()
  --clear pending file-diff
  Proj.clear_pend_file_diff()
end

-- TA-EVENT BUFFER_NEW
function Proj.EVbuffer_new()
  --ignore session load
  if not _initializing then
    --when a buffer is created in the right panel, mark it as such
    if _VIEWS[view] == Proj.get_projview(Proj.PRJV_FILES_2) then buffer._right_side=true end
    buffer._type= Util.UNTITLED_TEXT  --prevent TA auto-close
  end
end

-- TA-EVENT BUFFER_DELETED
function Proj.EVbuffer_deleted()
  plugs.buffer_deleted()
  --Stop diff'ing when one of the buffer's being diff'ed is closed
  Proj.check_diff_stop()
end

function Proj.close_untitled()
  --close "Untitled" buffers in the same view
  --only when the current buffer is a regular one
  if buffer.filename and (buffer._project_select == nil) then
    local right= (buffer._right_side == true)
    for _,buf in ipairs(_BUFFERS) do
      if buf.filename == nil and (buf._type == nil or buf._type == Util.UNTITLED_TEXT) and
        (not buf.modify) and buf._project_select == nil then
        if (right and buf._right_side) or (not right) and not buf._right_side then
          --same side, close auto_opened buffer
          Util.goto_buffer(buf)
          Util.close_buffer()
          break
        end
      end
    end
  end
end

-- TA-EVENT FILE_OPENED
--if the current file is a project, enter SELECTION mode--
function Proj.EVfile_opened()
  --remove buf._type= Util.UNTITLED_TEXT when loaded
  if buffer._type == Util.UNTITLED_TEXT then buffer._type= nil end
  --if the file is open in the right panel, mark it as such
  if _VIEWS[view] == Proj.get_projview(Proj.PRJV_FILES_2) then buffer._right_side=true end
  --ignore session load / updating ui
  if Proj.update_ui == 0 then Proj.close_untitled() end --close "Untitled" buffers in the same view
end

-- TA-EVENT FILE_AFTER_SAVE
function Proj.EVafter_save()
  --remove buf._type= Util.UNTITLED_TEXT when saved
  if buffer._type == Util.UNTITLED_TEXT then buffer._type= nil end
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
      if data.is_open and nv == Proj.prefview[Proj.PRJV_PROJECT] and data.show_mode == Proj.SM_HIDDEN then
        --in project's view, force visibility
        data.show_mode= Proj.SM_SELECT  --selection mode
        Proj.update_projview_action() --update action: toggle_viewproj/toggle_editproj
        view.size= data.select_width
        Proj.temporal_view= true  --close if escape is pressed again or if a file is opened

      elseif Proj.temporal_view then
        Proj.temporal_view= false
        Proj.toggle_projview()
      end
    end
  end
end

function Proj.show_projview()
  --Show project / goto project view
  if Proj.data.is_open then
    Proj.goto_projview(Proj.PRJV_PROJECT)
    if data.show_mode == Proj.SM_HIDDEN then
      data.show_mode= Proj.SM_SELECT  --selection mode
      Proj.update_projview_action() --update action: toggle_viewproj/toggle_editproj
      view.size= data.select_width
    end
  end
end

--Show/Hide project
function Proj.show_hide_projview()
  if Proj.data.is_open then
    if data.show_mode == Proj.SM_EDIT then
      --project in edit mode
      Proj.goto_projview(Proj.PRJV_PROJECT)
      plugs.change_proj_ed_mode() --return to select mode
      return
    end
    --select mode
    Proj.goto_projview(Proj.PRJV_PROJECT)
    if view.size then
      if data.show_mode ~= Proj.SM_HIDDEN then
        data.show_mode= Proj.SM_HIDDEN  --hidden
        Proj.update_projview_action() --update action: toggle_viewproj/toggle_editproj
        if data.select_width ~= view.size then
          data.select_width= view.size  --save current width
          if data.select_width < 50 then data.select_width= 200 end
          data.recent_prj_change= true  --save it on exit
        end
        view.size= 0
      else
        data.show_mode= Proj.SM_SELECT  --selection mode
        Proj.update_projview_action() --update action: toggle_viewproj/toggle_editproj
        view.size= data.select_width
      end
    end
    Proj.goto_filesview()
  end
end

------SEARCH VIEW------
function Proj.check_leftpanel()
  --check the left/only panel content
  local vfp1= Proj.get_projview(Proj.PRJV_FILES)
  if #_VIEWS >= vfp1 then
    --goto left view
    Util.goto_view(vfp1)
    --check current file
    if not Proj.isRegularBuf(buffer) or buffer._right_side then
      --it is not a proper file for this panel, find one or open a blank one
      local bl= Proj.getBufFromPanel(Proj.FILEPANEL_LEFT)
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
  local vfp2= Proj.get_projview(Proj.PRJV_FILES_2)
  if #_VIEWS >= vfp2 then
    --goto right view
    Util.goto_view(vfp2)
    --check current file
    if not Proj.isRegularBuf(buffer) or not buffer._right_side then
      --it is not a proper file for this panel, find one or close the panel
      local br= Proj.getBufFromPanel(Proj.FILEPANEL_RIGHT)
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
