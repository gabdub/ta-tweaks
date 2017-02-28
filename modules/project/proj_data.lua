----------------------------------------------------------------------
-------- Project file format --------
-- Valid project lines:
-- 1)  [b] [n] '::' [fn] '::' [opt]
-- 2)  [b] [fn]
-- 3)  [b]
--
-- [b] = optional blanks to visualy group files (folding groups)
-- [n] = optional file/group name or description
--        '['n']', '('n')', '<'n'>' are color/bold hightlighted
-- [fn] = path/filename to open
--        'path\'    absolute path definition 'P'
--        'path/'    absolute path definition 'P'
--        '.\path\'  relative path definition 'p' (added to last absolute 'P')
--        './path/'  relative path definition 'p' (added to last absolute 'P')
--        'filename' open file 'fn' (absolute) or 'P'+'fn' (relative)
-- [opt] = optional control options
--        '-'     fold this group on project load
--        'C'     CTAGS file
--        'R'     RUN a command, %{projfiles} is replaced for a temporary files with the list of project files
--                               %{projfiles.ext1.ext2...} only project files with this extensions are included
--
-- (P= 'first' previous 'P'/'p' or project path)
--  The first project line MUST BE an "option 1)"
----------------------------------------------------------------------
-- Vars added to buffer:
--  _project_select  = mark this buffer as a valid project file
--               nil = regular file
--              true = project in SELECTION mode
--             false = project in EDIT mode
--
--  _is_working_project = this is the working project (in case more than one is open)
--              true = this is the one
--
--  proj_files[]     = array with the filename in each row (1...) or ''
--  proj_fold_row[]  = array with the row numbers to fold on open
--  proj_grp_path[]  = array with the path of each group or nil
-----------------------------------------------------------------------
local Proj = Proj

--Proj.init_ready = false
Proj.updating_ui= 1

Proj.PROJECTS_FILE = _USERHOME..'/projects'
Proj.SAVE_ON_QUIT = true
Proj.MAX_RECENT_FILES = 10
Proj.list_change = false

--recent Projects list
Proj.recent_projects= {}

--hilight project's open files
local indic_open = _SCINTILLA.next_indic_number()
buffer.indic_fore[indic_open]= (tonumber(buffer.property['color.prj_open_mark']) or 0x404040)
buffer.indic_style[indic_open]= buffer.INDIC_DOTS

--remove all open-indicators from project
function Proj.clear_open_indicators(pbuf)
  pbuf.indicator_current= indic_open
  pbuf:indicator_clear_range(0,pbuf.length-1)
end

function Proj.add_open_indicator(pbuf,row)
  pbuf.indicator_current= indic_open
  local pos= pbuf.line_indent_position[row]
  local len= pbuf.line_end_position[row] - pos
  pbuf:indicator_fill_range(pos,len)
end

--if buff is a project's file, hilight it with and open-indicator
function Proj.show_open_indicator(pbuf,buff)
  --ignore project and search buffers
  if buff._project_select == nil and buff._type == nil then
    local file= buff.filename
    if file then
      local row= Proj.locate_file(pbuf, file)
      if row then
        Proj.add_open_indicator(pbuf,row-1)
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

function Proj.load_projects(filename)
  local f = io.open(filename, 'rb')
  if f then
    for line in f:lines() do
      if line:find('^recent:') then
        local file = line:match('^recent: (.+)$')
        local recent, exists = Proj.recent_projects, false
        for i = 1, #recent do
          if file == recent[i] then exists = true break end
        end
        if not exists then Proj.recent_projects[#Proj.recent_projects + 1] = file end

      elseif line:find('^is_visible:') then
        Proj.is_visible= tonumber(line:match('^is_visible: (.+)$'))

      elseif line:find('^edit_width:') then
        Proj.edit_width= tonumber(line:match('^edit_width: (.+)$'))
        if Proj.edit_width < 50 then Proj.edit_width= 600 end

      elseif line:find('^select_width:') then
        Proj.select_width= tonumber(line:match('^select_width: (.+)$'))
        if Proj.select_width < 50 then Proj.select_width= 200 end
      end
    end
    f:close()
  end
  Proj.list_change = false
  Proj._read_is_visible= Proj.is_visible
end

function Proj.save_projects(filename)
  if Proj.list_change or Proj._read_is_visible ~= Proj.is_visible then
    local f = io.open(filename, 'wb')
    if f then
      local savedata = {}
      for i = 1, #Proj.recent_projects do
        if i > Proj.MAX_RECENT_FILES then break end
        savedata[#savedata + 1] = ("recent: %s"):format(Proj.recent_projects[i])
      end
      savedata[#savedata + 1] = ("is_visible: %d"):format(Proj.is_visible)
      savedata[#savedata + 1] = ("edit_width: %d"):format(Proj.edit_width)
      savedata[#savedata + 1] = ("select_width: %d"):format(Proj.select_width)
      f:write(table.concat(savedata, '\n'))
      f:close()
    end
    Proj.list_change = false
  end
end

function Proj.add_recentproject(prjfile)
  -- Add file to recent project files list, eliminating duplicates.
  for j, file in ipairs(Proj.recent_projects) do
    if file == prjfile then table.remove(Proj.recent_projects, j) break end
  end
  table.insert(Proj.recent_projects, 1, prjfile)
  --and remove file from recent "regular files" list
  for j, file in ipairs(io.recent_files) do
    if file == prjfile then table.remove(io.recent_files, j) break end
  end
  --save new list on exit
  Proj.list_change =  true
end

events.connect(events.INITIALIZED, function()
  --after session load ends, verify all the buffers
  --(this prevents view creation conflicts)
  --Proj.init_ready = true
  Proj.updating_ui= 0

  Proj.is_visible= 1  --0:hidden  1:shown in selection mode  2:shown in edit mode
  Proj.edit_width= 600
  Proj.select_width= 200
  --load recent projects list / project preferences
  if Proj.SAVE_ON_QUIT then Proj.load_projects(Proj.PROJECTS_FILE) end

  --check if search results is open
  for _, buff in ipairs(_BUFFERS) do
    if buff._type == Proj.PRJT_SEARCH then
      --activate search view
      Proj.goto_searchview()
      buff.read_only= true
      break
    end
  end

  --check if a project file is open
  for _, buff in ipairs(_BUFFERS) do
    --check buffer type
    if Proj.get_buffertype(buff) == Proj.PRJB_PROJ_NEW then
      --activate project in the proper view
      Proj.goto_projview(Proj.PRJV_PROJECT)
      my_goto_buffer(buff)
      if Proj.is_visible == 2 then
        --2:shown in edit mode
        Proj.ifproj_seteditmode(buff)
      else
        --0:hidden  1:shown in selection mode
        Proj.ifproj_setselectionmode(buff)
        Proj.is_visible= Proj._read_is_visible  --keep 0 is hidden
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
  Proj.update_after_switch()
  Proj.update_projview() --gray toggle project view button
end)

-- Saves recent projects list on quit.
events.connect(events.QUIT, function()
  if Proj.SAVE_ON_QUIT then Proj.save_projects(Proj.PROJECTS_FILE) end
end, 1)


--determines the buffer type: Proj.PRJT_...
function Proj.get_buffertype(p_buffer)
  if not p_buffer then p_buffer = buffer end  --use current buffer?

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
  --check if the current file is a valid project
  --The first file line MUST BE a valid "option 1)": ...##...##...
  local line= p_buffer:get_line(0)
  local n, fn, opt = string.match(line,'^%s*(.-)%s*::(.*)::(.-)%s*$')
  if n ~= nil then
    return Proj.PRJB_PROJ_NEW         --is a project file not marked as such yet
  end
  return Proj.PRJB_NORMAL             --is a regular file
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
    if force_view then
      --force: project in the preferred view
      if nview == nil then
        --locate the buffer view
        for i= 1, #_VIEWS do
          if _VIEWS[i].buffer == pbuff then
            nview = i
            break
          end
        end
      end
      if nview ~= projv then
        --show project in the preferred view
        local nv= _VIEWS[view]  --save actual view
        my_goto_view(projv)     --goto project view
        my_goto_buffer(pbuff)
        my_goto_view(nv)        --restore actual view
      end
    end
  end
  return pbuff
end


function Proj.splitfilename(strfilename)
  -- Returns the Path, Filename, and Extension as 3 values
  return string.match(strfilename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
end

--fill filenames array "buffer.proj_files[]"
function Proj.parse_projectbuffer(p_buffer)
  ui.statusbar_text= 'Parsing project file...'

  p_buffer.proj_files= {}
  p_buffer.proj_filestype= {}   --Proj.PRJF_...
  p_buffer.proj_fold_row = {}
  p_buffer.proj_grp_path = {}

  --get project file path (default)
  local projname= p_buffer.filename
  local abspath
  if projname ~= nil then
    local p,f,e = Proj.splitfilename(projname)
    abspath= p
  else
    --new project, use current dir
    projname= ''
    abspath= lfs.currentdir()
  end
  local path = abspath

  --parse project file line by line
  for r = 1, p_buffer.line_count do
    local fname= ''
    local line= p_buffer:get_line(r-1)

    --try option 1)
    local n, fn, opt = string.match(line,'^%s*(.-)%s*::(.*)::(.-)%s*$')
    if n == nil then
      --try option 2)
      fn= string.match(line,'^%s*(.-)%s*$')
    end
    --ui._print('Parser', 'n='..((n==nil) and 'nil' or n)..' f='..((f==nil) and 'nil' or f)..' opt='..((opt==nil) and 'nil' or opt) )

    local ftype = Proj.PRJF_EMPTY
    if fn ~= nil and fn ~= '' then
      local p,f,e= Proj.splitfilename(fn)
      if f == '' and p ~= '' then
        --only the path is given
        local dots, pathrest= string.match(p,'^(%.*[\\/])(.*)$')
        if dots == '.\\' or dots == './' then
          --relative path (only one dot is supported by now)
          path= abspath .. pathrest
        else
          --absolute path
          abspath = p
          path = abspath
        end
        p_buffer.proj_grp_path[r]= path
        ftype = Proj.PRJF_PATH

      elseif f ~= '' then
        if p == '' then
          --relative file, add current path
          fname= path .. fn
        else
          local dots, pathrest= string.match(p,'^(%.*[\\/])(.*)$')
          if dots == '.\\' or dots == './' then
            --relative file (only one dot is supported by now)
            fname= abspath .. string.sub(fn,3)
          else
            --absolute file
            fname= fn
          end
        end
        ftype = Proj.PRJF_FILE
      end
    end
    if opt ~= nil and opt ~= '' then
      if opt == '-' then
        --  '-': fold this group on project load
        p_buffer.proj_fold_row[ #p_buffer.proj_fold_row+1 ]= r
      elseif opt == 'C' then
        --  'C': CTAGS file
        if ftype == Proj.PRJF_FILE then ftype=Proj.PRJF_CTAG else ftype=Proj.PRJF_EMPTY end
      elseif opt == 'R' then
        --  'R': RUN a command
        if ftype == Proj.PRJF_FILE then ftype=Proj.PRJF_RUN else ftype=Proj.PRJF_EMPTY end
      end
    end
    --set the filename/type asigned to each row
    p_buffer.proj_files[r]= fname
    p_buffer.proj_filestype[r]= ftype
  end
  ui.statusbar_text= 'Project: '.. projname
end

--return the file position (ROW: 1..) in the given buffer file list
function Proj.locate_file(p_buffer, file)
  --check the given buffer has a list of files
  if p_buffer and p_buffer.proj_files ~= nil and file then
    for row= 1, #p_buffer.proj_files do
      if file == p_buffer.proj_files[row] then
        return row
      end
    end
  end
  --not found
  return nil
end

--------------------------------------------------------------
-- show project current row properties
function Proj.show_doc()
  --call_tip_show
  if buffer._project_select ~= nil then
    if buffer:call_tip_active() then events.emit(events.CALL_TIP_CLICK) return end
    if buffer.proj_files ~= nil then
      local r= buffer.line_from_position(buffer.current_pos)+1
      local info = buffer.proj_files[r]
      local ftype= buffer.proj_filestype[r]
      if ftype == Proj.PRJF_CTAG then info= 'CTAG: '..info
      elseif ftype == Proj.PRJF_RUN then info= 'RUN: '..info end
      if info == '' and buffer.proj_grp_path[r] ~= nil then
        info= buffer.proj_grp_path[r]
      end
      if info ~= '' then
        buffer:call_tip_show(buffer.current_pos, info )
      end
    end
  else
    --call default show doc function
    textadept.editing.show_documentation()
  end
end

--------------------------------------------------------------
--activate/create search view
function Proj.goto_searchview()
  --goto the view for search results, split views and create empty buffers if needed
  Proj.goto_projview(Proj.PRJV_SEARCH)
  --goto search results view
  if buffer._type ~= Proj.PRJT_SEARCH then
    for nbuf, sbuf in ipairs(_BUFFERS) do
      if sbuf._type == Proj.PRJT_SEARCH then
        my_goto_buffer(sbuf)
        return
      end
    end
  end
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
          if not Proj.file_exists(file) then
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
                  local p,f,e= Proj.splitfilename(file)
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
  Proj.proj_contextm_search()
  Proj.updating_ui=Proj.updating_ui-1
end

--goto the view for the requested project buffer type
--split views if needed
function Proj.goto_projview(prjv)
  local pref= Proj.prefview[prjv] --preferred view for this buffer type
  if pref == _VIEWS[view] then
    return  --already in the right view
  end
  local nv= #_VIEWS
  while pref > nv do
    --more views are needed: split the last one
    local porcent  = Proj.prefsplit[nv][1]
    local vertical = Proj.prefsplit[nv][2]
    my_goto_view(Proj.prefsplit[nv][3])
    --split view to show search results
    view:split(vertical)
    --adjust view size (actual = 50%)
    view.size= math.floor(view.size*porcent*2)
    nv= nv +1
    if nv == Proj.prefview[Proj.PRJV_FILES] then
      --create an empty file
      my_goto_view(nv)
      buffer.new()
      events.emit(events.FILE_OPENED)
    elseif nv == Proj.prefview[Proj.PRJV_SEARCH] then
      --create an empty search results buffer
      my_goto_view(nv)
      buffer.new()
      buffer._type = Proj.PRJT_SEARCH
      events.emit(events.FILE_OPENED)
    end
  end
  my_goto_view(pref)
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
    if _VIEWS[view] == 1 then my_goto_view(2) end
  else
    --if no project is open, view #1 is the left/only panel
    if _VIEWS[view] ~= 1 then my_goto_view(1) end
  end
end

--if the current view is a project or project-search, goto left/only files view. if not, keep the current view
function Proj.getout_projview(right_side)
  if (buffer._project_select ~= nil or buffer._type ~= nil) then
    --move to files view (left/only panel) and exit
    Proj.goto_filesview(true,right_side)
    return true
  end
  return false
end

--open the selected file
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

function Proj.close_search_view()
  local sv= Proj.prefview[Proj.PRJV_SEARCH]
  --if more views are open, ignore the close
  if #_VIEWS > sv then return false end
  if #_VIEWS == sv then
    --remove search from position table
    Proj.remove_search_from_pos_table()
    --activate search view
    Proj.goto_searchview()
    --close buffer / view
    buffer:set_save_point()
    io.close_buffer()
    my_goto_view( sv -1 )
    view.unsplit(view)
    return true
  end
  --no search view, try to close the search buffer
  for _, sbuffer in ipairs(_BUFFERS) do
    if sbuffer._type == Proj.PRJT_SEARCH then
      --goto search results view
      if view.buffer._type ~= Proj.PRJT_SEARCH then
        my_goto_buffer(sbuffer)
      end
      io.close_buffer()
      break
    end
  end
  return false
end

----------------------------------------
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

local function isRegularBuf(pbuffer)
  if (pbuffer._project_select ~= nil) or (pbuffer._type == Proj.PRJT_SEARCH) then
    return false  --is a project or search results
  end
  return true
end

--find the first regular buffer
--panel=0 (any), panel=1 (_right_side=false), panel=2 (_right_side=true)
function Proj.getFirstRegularBuf(panel)
  for _, buf in ipairs(_BUFFERS) do
    if isRegularBuf(buf) then
      if (panel==0) or ((panel==1) and (not buf._right_side)) or ((panel==2) and (buf._right_side)) then return buf end
    end
  end
  return nil
end

--check that at least one regular buffer remains after closing
function Proj.check_after_close_buffer()
  Proj.updating_ui=Proj.updating_ui+1
  local actv= _VIEWS[view]
  Proj.check_rightpanel()
  Proj.check_searchpanel()
  Proj.check_leftpanel()
  if #_VIEWS >= actv then my_goto_view(actv) end
  Proj.updating_ui=Proj.updating_ui-1
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
      Proj.check_after_close_buffer()
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
    if isRegularBuf(buf) and not buf._dont_close then
      --regular file, close it
      my_goto_buffer(buf)
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
  Proj.check_after_close_buffer()
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

function Proj.check_rightpanel()
  --if the right panel is open, check it
  local vfp2= Proj.prefview[Proj.PRJV_FILES_2]
  if #_VIEWS >= vfp2 then
    --goto right view
    my_goto_view(vfp2)
    --check current file
    if not isRegularBuf(buffer) or not buffer._right_side then
      --it is not a proper file for this panel, find one or close the panel
      local br= Proj.getFirstRegularBuf(2)
      if br then my_goto_buffer(br) else
        view.unsplit(view)
        Proj.close_search_view()  --close search view too (TODO: don't close search view)
      end
    end
  end
end

function Proj.check_searchpanel()
  local vsp= Proj.prefview[Proj.PRJV_SEARCH]
  if #_VIEWS >= vsp then
    Proj.goto_searchview()
  end
end

function Proj.check_leftpanel()
  --check the left/only panel content
  local vfp1= Proj.prefview[Proj.PRJV_FILES]
  if #_VIEWS >= vfp1 then
    --goto left view
    my_goto_view(vfp1)
    --check current file
    if not isRegularBuf(buffer) or buffer._right_side then
      --it is not a proper file for this panel, find one or open a blank one
      local bl= Proj.getFirstRegularBuf(1)
      if bl then my_goto_buffer(bl) else Proj.go_file() end
    end
  end
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
  my_goto_buffer(buf)
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
    my_goto_buffer(b)
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
