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
--        '-'     fold this group on project load / refresh
--        'C'     CTAGS file
--        'R'     RUN a command, %{projfiles} is replaced with a temporary files with the list of project files
--                               %{projfiles.ext1.ext2...} only project files with this extensions are included
--
-- (P= 'first' previous 'P'/'p' or project path)
--  The first project line MUST BE an "option 1)"
----------------------------------------------------------------------
-- Main vars added to project buffer:
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
--
--  Proj.updating_ui= number of ui updates in progress (ignore some events if > 0)
--  Proj.cmenu_num  = number of the current context menu
-----------------------------------------------------------------------
local Proj = Proj
local Util = Util

Proj.updating_ui= 1 --don't update the UI until Proj.EVinitialize is called

Proj.PROJECTS_FILE = _USERHOME..'/projects'
Proj.MAX_RECENT_PROJ = 10
Proj.prjlist_change = false

--recent Projects list
Proj.recent_projects= {}

local function load_recent_projects(filename)
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
  Proj.prjlist_change = false
  Proj._read_is_visible= Proj.is_visible
end

local function save_recent_projects(filename)
  if Proj.prjlist_change or Proj._read_is_visible ~= Proj.is_visible then
    local f = io.open(filename, 'wb')
    if f then
      local savedata = {}
      for i = 1, #Proj.recent_projects do
        if i > Proj.MAX_RECENT_PROJ then break end
        savedata[#savedata + 1] = ("recent: %s"):format(Proj.recent_projects[i])
      end
      savedata[#savedata + 1] = ("is_visible: %d"):format(Proj.is_visible)
      savedata[#savedata + 1] = ("edit_width: %d"):format(Proj.edit_width)
      savedata[#savedata + 1] = ("select_width: %d"):format(Proj.select_width)
      f:write(table.concat(savedata, '\n'))
      f:close()
    end
    Proj.prjlist_change = false
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
  Proj.prjlist_change =  true
end

-- TA-EVENT INITIALIZED
function Proj.EVinitialize()
  --after session load ends, verify all the buffers (this prevents view creation conflicts)
  Proj.updating_ui= 0
  Proj.is_visible= 1  --0:hidden  1:shown in selection mode  2:shown in edit mode
  Proj.edit_width= 600
  Proj.select_width= 200
  --load recent projects list / project preferences
  load_recent_projects(Proj.PROJECTS_FILE)
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
  --TODO: mark rigth side files
  for _, buff in ipairs(_BUFFERS) do
    --check buffer type
    if Proj.get_buffertype(buff) == Proj.PRJB_PROJ_NEW then
      --activate project in the proper view
      Proj.goto_projview(Proj.PRJV_PROJECT)
      Util.goto_buffer(buff)
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
end

-- TA-EVENT QUIT: Saves recent projects list
function Proj.EVquit()
  save_recent_projects(Proj.PROJECTS_FILE)
end

--get the buffer type: Proj.PRJT_...
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

--parse buffer and fill filenames array "buffer.proj_files[]"
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
    local p,f,e = Util.splitfilename(projname)
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
      local p,f,e= Util.splitfilename(fn)
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
function Proj.get_file_row(p_buffer, file)
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

--returns true if buffer is a regular file (not a project nor a search results)
function Proj.isRegularBuf(pbuffer)
  return (pbuffer._project_select == nil) and (pbuffer._type ~= Proj.PRJT_SEARCH)
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
--if the current file is a project, enter SELECTION mode--
function Proj.ifproj_setselectionmode(p_buffer)
  if not p_buffer then p_buffer = buffer end  --use current buffer?
  if Proj.get_buffertype(p_buffer) >= Proj.PRJB_PROJ_MIN then
    Proj.set_selectionmode(p_buffer,true)
    if p_buffer.filename then
      ui.statusbar_text= 'Project file =' .. buffer.filename
    end
    return true
  end
  return false
end

--if the current file is a project, enter EDIT mode--
function Proj.ifproj_seteditmode(buff)
  if not p_buffer then p_buffer = buffer end  --use current buffer?
  if Proj.get_buffertype(p_buffer) >= Proj.PRJB_PROJ_MIN then
    Proj.set_selectionmode(p_buffer,false)
    if p_buffer.filename then
      ui.statusbar_text= 'Project file =' .. buffer.filename
    end
    return true
  end
  return false
end

--return if a project is open in edit mode
function Proj.isin_editmode()
  local pbuf= Proj.get_projectbuffer(true)
  return pbuf and (Proj.get_buffertype(pbuf) == Proj.PRJB_PROJ_EDIT)
end

--toggle project between SELECTION and EDIT modes
function Proj.toggle_selectionmode()
  local mode= Proj.get_buffertype()
  if mode == Proj.PRJB_PROJ_SELECT or mode == Proj.PRJB_PROJ_EDIT then
    Proj.set_selectionmode(buffer, (mode == Proj.PRJB_PROJ_EDIT)) --toggle current mode
  else
    --if the current file is a project, enter SELECTION mode--
    if not Proj.ifproj_setselectionmode() then
      ui.statusbar_text='This file is not a project'
    end
  end
  buffer.home()
end

--set the project mode as: selected (selmode=true) or edit (selmode=false)
--if selmode=true, parse the project and build file list: "proj_file[]"
function Proj.set_selectionmode(buff,selmode)
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
    --fill buffer arrays: "proj_files[]", "proj_fold_row[]" and "proj_grp_path[]"
    Proj.parse_projectbuffer(buff)
    --set lexer to highlight groups and hidden control info ":: ... ::"
    buff:set_lexer('myproj')
    --project in SELECTION mode--
    Proj.show_sel_w_focus(buff)

    --set SELECTION mode context menu
    Proj.set_contextm_sel()

    --fold the requested folders
    for i= #buff.proj_fold_row, 1, -1 do
      buff.toggle_fold(buff.proj_fold_row[i])
    end
    Proj.is_visible= 1  --1:shown in selection mode
    Proj.mark_open_files(buff)
  else
    --edit project as a text file (show control info)
    buff:set_lexer('text')
    --set EDIT mode context menu
    Proj.set_contextm_edit()
    --project in EDIT mode--
    Proj.show_default(buff)
    Proj.is_visible= 2  --2:shown in edit mode
    Proj.clear_open_indicators(buff)
  end
  if toolbar then
    Proj.update_projview()  --update project view button
    toolbar.seltabbuf(buff) --hide/show and select tab in edit mode
  end
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

------------------HELPERS-------------------
--open files in the preferred view
--optinal: goto line_num
function Proj.go_file(file, line_num)
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  if file == nil or file == '' then
    Proj.getout_projview()
    --new file (add only one)
    local n= nil
    for i=1, #_BUFFERS do
      if (_BUFFERS[i].filename == nil) and (_BUFFERS[i]._type ~= Proj.PRJT_SEARCH) and not _BUFFERS[i]._right_side then
        --there is one new file, select this instead of adding a new one
        n= i
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
        Proj.getout_projview(buf._right_side)
        Util.goto_buffer(buf)
        fn = nil
        break
      end
    end
    Proj.getout_projview()
    if fn then io.open_file(fn) end

    if line_num then Util.goto_line(buffer, line_num-1) end
    Proj.update_after_switch()
  end
end

--RUN a command
--%{projfiles} is replaced for a temporary file with the complete list of project files
--%{projfiles.ext1.ext2...} only project files with this extensions are included
function Proj.run_command(cmd)
  if cmd ~= nil and cmd ~= '' then
    local tmpfile, ext
    --replace special vars
    local s, e = cmd:find('%{projfiles}')
    if not s then
      s, e = cmd:find('%{projfiles%..*}')
      if s and e then
        --get extensions
        local se= cmd:match('%{projfiles%.(.*)}')
        if se then
          ext={}
          for i in string.gmatch(se, "[^%.]+") do
            ext[i] = true
          end
        end
      end
    end
    if s and e then
      --replace %{projfiles} is with a temporary file with the list of project files
      local p_buffer = Proj.get_projectbuffer(true)
      if p_buffer == nil or p_buffer.proj_files == nil then
        ui.statusbar_text= 'No project found'
        return
      end

      --get a list of project files
      local flist= {}
      for row= 1, #p_buffer.proj_files do
        local ftype= p_buffer.proj_filestype[row]
        if ftype == Proj.PRJF_FILE then --ignore CTAGS files / path / empty rows
          local file= p_buffer.proj_files[row]
          if not ext or ext[file:match('[^%.]+$')] then
            --all files / listed extension
            flist[ #flist+1 ]= file
          end
        end
      end
      if #flist == 0 then
        ui.statusbar_text= 'File not found in project'
        return
      end
      --write the project files list in a temp file
      tmpfile = p_buffer.filename..'_tmp'
      local f = io.open(tmpfile, 'wb')
      if f then
        f:write(table.concat(flist, '\n'))
        f:close()
      end
      cmd= string.sub(cmd,1,s-2)..tmpfile..string.sub(cmd,e+1)
    end
    Proj.last_run_command= cmd
    Proj.last_run_tmpfile= tmpfile
    if string.len(Proj.last_run_command) > 40 then
      Proj.last_run_command= string.sub(Proj.last_run_command,1,40)..'...'
    end
    local proc= spawn(cmd,nil,nil,nil,function(status)
        ui.statusbar_text= 'RUN '..Proj.last_run_command..' ended with status '..status
        if Proj.last_run_tmpfile then
          os.remove(Proj.last_run_tmpfile)
          Proj.last_run_tmpfile= nil
        end
      end)
    ui.statusbar_text= 'RUNNING: '..Proj.last_run_command
  end
end

