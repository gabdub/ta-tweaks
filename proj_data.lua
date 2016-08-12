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
      end
    end
    f:close()
  end
  Proj.list_change = false
end

function Proj.save_projects(filename)
  if Proj.list_change then
    local f = io.open(filename, 'wb')
    if f then
      local savedata = {}
      for i = 1, #Proj.recent_projects do
        if i > Proj.MAX_RECENT_FILES then break end
        savedata[#savedata + 1] = ("recent: %s"):format(Proj.recent_projects[i])
      end
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

  --use Proj.buffer functions in menues
  textadept.menu.menubar[_L['_File']][_L['_Close']][2]= Proj.close_buffer
  textadept.menu.menubar[_L['_File']][_L['Close All']][2]= Proj.close_all_buffers
  textadept.menu.tab_context_menu[_L['_Close']][2]= Proj.close_buffer

  textadept.menu.menubar[_L['_Buffer']][_L['_Next Buffer']][2]= Proj.next_buffer
  textadept.menu.menubar[_L['_Buffer']][_L['_Previous Buffer']][2]= Proj.prev_buffer
  textadept.menu.menubar[_L['_Buffer']][_L['_Switch to Buffer...']][2]= Proj.switch_buffer

  --load recent projects list
  if Proj.SAVE_ON_QUIT then Proj.load_projects(Proj.PROJECTS_FILE) end
  
  --check if search results is open
  for _, buff in ipairs(_BUFFERS) do
    if buff._type == Proj.PRJT_SEARCH then
      --activate search view
      Proj.goto_searchview()
      Proj.search_vn= _VIEWS[view]
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
      if TA_MAYOR_VER < 9 then
        view:goto_buffer(_BUFFERS[buff])
      else
        view:goto_buffer(buff)
      end
      Proj.ifproj_setselectionmode(buff)
      --start in files view
      Proj.goto_filesview()
      --check that at least there's one regular buffer
      local rbuf = Proj.getFirstRegularBuf()
      if rbuf == nil then
        --no regular buffer found
        Proj.go_file() --open a blank file
      end
      return
    end
  end

  --no project file found
  Proj.update_after_switch()
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
        if TA_MAYOR_VER < 9 then
          view:goto_buffer(_BUFFERS[pbuff])
        else
          view:goto_buffer(pbuff)
        end
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
        if TA_MAYOR_VER < 9 then
          view:goto_buffer(nbuf)
        else
          view:goto_buffer(sbuf)
        end
        return
      end
    end
  end
end

-- find text in project's files
-- code adapted from module: find.lua
function Proj.find_in_files(p_buffer,text,match_case,whole_word)
  --activate/create search view
  Proj.goto_searchview()
  Proj.search_vn= _VIEWS[view]

  buffer.read_only= false
  buffer:append_text('['..text..']\n')
  buffer:goto_pos(buffer.length)
  buffer.indicator_current = ui.find.INDIC_FIND
  if whole_word then text = '%f[%w_]'..(match_case and text or text:lower())..'%f[^%w_]' end

  local nfiles= 0
  local totfiles= 0
  local nfound= 0
  --check the given buffer has a list of files
  if p_buffer and p_buffer.proj_files ~= nil then
    for row= 1, #p_buffer.proj_files do
      local ftype= p_buffer.proj_filestype[row]
      if ftype == Proj.PRJF_FILE then --ignore CTAGS files / path / empty rows
        local file= p_buffer.proj_files[row]
        if file and file ~= '' then
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
  
  if nfound == 0 then buffer:append_text(' '.._L['No results found']..'\n') end
  buffer:append_text('\n')
  buffer:set_save_point()
  
  ui.statusbar_text= ''..nfound..' matches found in '..nfiles..' of '..totfiles..' files'
  buffer:set_lexer('myproj')
  buffer.read_only= true
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
    my_goto_view(nv)
    local porcent  = Proj.prefsplit[nv][1]
    local vertical = Proj.prefsplit[nv][2]
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
      local search_buffer = buffer.new()
      search_buffer._type = Proj.PRJT_SEARCH
      events.emit(events.FILE_OPENED)
    end
  end
  my_goto_view(pref)
end

function Proj.goto_filesview()
  --goto the view for editing files, split views if needed
  Proj.goto_projview(Proj.PRJV_FILES)
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
    Proj.store_current_pos()
    Proj.go_file(file, line_num)
    -- Store the current position at the end of the jump history.
    Proj.append_current_pos()
  end
end

function Proj.close_search_view()
  --remove search from position table
  Proj.remove_search_from_pos_table()
  if Proj.search_vn then
    --activate search view
    Proj.goto_searchview()
    Proj.search_vn = nil
    --close buffer / view
    buffer:set_save_point()
    io.close_buffer()
    if Proj.prefview[Proj.PRJV_SEARCH] > 0 then
      my_goto_view( Proj.prefview[Proj.PRJV_SEARCH] -1 )
    end
    view.unsplit(view)
    return true
  end
  --no search results, try to close the search buffer and view
  for _, sbuffer in ipairs(_BUFFERS) do
    if sbuffer._type == Proj.PRJT_SEARCH then
      --goto search results view
      if view.buffer._type ~= Proj.PRJT_SEARCH then
        if TA_MAYOR_VER < 9 then
          view:goto_buffer(_BUFFERS[sbuffer])
        else
          view:goto_buffer(sbuffer)
        end
      end
      io.close_buffer()
      break
    end
  end
  if #_VIEWS == Proj.prefview[Proj.PRJV_SEARCH] then
    if Proj.prefview[Proj.PRJV_SEARCH] > 0 then
      my_goto_view( Proj.prefview[Proj.PRJV_SEARCH] -1 )
      view.unsplit(view)
      return true
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
    Proj.goto_filesview() --change to files view if needed
    local utf8_list = {}
    for row= 1, #p_buffer.proj_files do
      local file= p_buffer.proj_files[row]
      if file and file ~= '' then
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
function Proj.getFirstRegularBuf()
  for _, buf in ipairs(_BUFFERS) do
    if isRegularBuf(buf) then
      return buf
    end
  end
  return nil
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
      local rbuf = Proj.getFirstRegularBuf()
      if rbuf == nil then
        --no regular buffer found
        Proj.go_file() --open a blank file
        
      elseif not isRegularBuf(buffer) then
        --replace current buffer with a regular one
        if TA_MAYOR_VER < 9 then
          view:goto_buffer(_BUFFERS[rbuf])
        else
          view:goto_buffer(rbuf)
        end
      end
    end
  end
end

function Proj.close_all_buffers()
  --close project file and views
  Proj.close_project(false)
  --close all buffers
  io.close_all_buffers()
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
    Proj.goto_filesview()
    if TA_MAYOR_VER < 9 then
      view:goto_buffer(nb)
    else
      view:goto_buffer(b)
    end
  end
end

function Proj.next_buffer()
  local nb= _BUFFERS[buffer]+1
  if nb > #_BUFFERS then nb= 1 end
  Proj.goto_buffer(nb)
end

function Proj.prev_buffer()
  local nb= _BUFFERS[buffer]-1
  if nb < 1 then nb= #_BUFFERS end
  Proj.goto_buffer(nb)
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
