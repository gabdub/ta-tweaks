-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.
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
----------
--        'C'     CTAGS file
--          e.g. ctags-ta.ctag::C:\textadept\ctags-ta.ctag::C
----------
--        'R'     RUN a command, %{projfiles} is replaced with a temporary files with the list of project files
--                               %{projfiles.ext1.ext2...} only project files with this extensions are included
--          e.g. [Update CTAGS]::C:\GNU\ctags.exe -n -L %{projfiles.lua.c} -f C:\textadept\ctags-ta.ctag::R
----------
--        'Sxxx[,ccc]' SVN folder and repository base (xxx=URL prefix, ccc=working directory)
--          e.g. [svn]::/home/user/mw/::Shttps://192.168.0.11:8443/svn/
--                /home/user/mw/MGWdrv/trunk/v.c ==> svn cat https://192.168.0.11:8443/svn/MGWdrv/trunk/v.c
--                working dir= no need to set
----------
--        'Gxxx[,ccc]' GIT folder and repository base (xxx=URL prefix, ccc=working directory)
--          e.g. [git]::C:\Users\desa1\.textadept\::G,C:\Users\desa1\.textadept\ta-tweaks
--                C:\Users\desa1\.textadept\modules\init.lua ==> git show HEAD:modules\init.lua
--                working dir= C:\Users\desa1\.textadept\ta-tweaks
--
--          e.g. [git]::C:\textadept\ta9\src\::Gtatoolbar/src/,C:\Users\desa1\.textadept\ta-tweaks
--                C:\textadept\ta9\src\textadept.c ==> git show HEAD:tatoolbar/src/textadept.c
--                working dir= C:\Users\desa1\.textadept\ta-tweaks
----------
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
-----------------------------------------------------------------------
--  Proj.data:          PROJECT DATA
--   filename           = open project filename or ""
--   proj_parsed        = the project file was parsed
--   proj_files[]       = array with the filename in each row (1...) or ''
--   proj_filestype[]   = array with the type of each row: Proj.PRJF_...
--   proj_fold_row[]    = array with the row numbers to fold on open
--   proj_grp_path[]    = array with the path of each group or nil
--   proj_vcontrol[]    = array with the SVN/GIT version control rows
--   proj_rowinfo[]     = array {row-text, indent, indent-len}
--   config_hooks[]     = objects/toolbars that use the project configuration {beforeload, afterload, beforesave}
-----------------------------------------------------------------------
--  Proj.data:          RECENT PROJECTS
--   recent_projects[]  = recent Projects list (array[ Proj.MAX_RECENT_PROJ ])
--   recent_prj_change  = the recent Projects list has been modified
-----------------------------------------------------------------------
--  Proj.data.config:   PROJECT CONFIGURATION
--   is_visible         = 0=hidden  1=shown in selection mode  2=shown in edit mode
--   edit_width         = view width in edit mode
--   select_width       = view width in selection mode
--   recent#1..30       = recent projects (#1= the more recent)
-----------------------------------------------------------------------
local Proj = Proj
local Util = Util

Proj.PROJ_CONFIG_FILE = _USERHOME..'/project_config'
Proj.MAX_RECENT_PROJ = 30

Proj.data= {}
local data= Proj.data
data.filename= ""  --open project filename or ""
data.proj_parsed= true
data.recent_projects= {} --recent Projects list
data.recent_prj_change = false
data.config= {}
data.config_hooks= {}

function Proj.clear_proj_arrays()
  data.proj_files= {}
  data.proj_filestype= {}   --Proj.PRJF_...
  data.proj_fold_row=  {}
  data.proj_grp_path=  {}
  data.proj_vcontrol=  {}
  data.proj_rowinfo=   {}   --{row-text, indent, indent-len}
end
Proj.clear_proj_arrays()

function Proj.add_config_hook(beforeload, afterload, beforesave, projloaded)
  data.config_hooks[#data.config_hooks+1]= {beforeload, afterload, beforesave, projloaded}
end

function Proj.load_config()
  data.config= {}
  local cfg= data.config
  Util.add_config_field(cfg, "is_visible",   Util.cfg_int, 1)
  Util.add_config_field(cfg, "edit_width",   Util.cfg_int, 600)
  Util.add_config_field(cfg, "select_width", Util.cfg_int, 200)
  Util.add_config_field(cfg, "recent",       Util.cfg_str, "", Proj.MAX_RECENT_PROJ)
  for i=1, #data.config_hooks do data.config_hooks[i][1](cfg) end  --add hooked fields to config
  Util.load_config_file(cfg, Proj.PROJ_CONFIG_FILE)
  data.recent_prj_change= false

  Proj.is_visible= cfg.is_visible
  Proj.edit_width= cfg.edit_width
  if Proj.edit_width < 50 then Proj.edit_width= 600 end
  Proj.select_width= cfg.select_width
  if Proj.select_width < 50 then Proj.select_width= 200 end

  data.recent_projects={}
  for i=1, Proj.MAX_RECENT_PROJ do
    local rc= cfg["recent#"..i]
    if rc and (rc ~= "") then data.recent_projects[#data.recent_projects+1]=rc end
  end
  for i=1, #data.config_hooks do data.config_hooks[i][2](data.config) end  --notify hooks afterload
end

local function notify_projload_ends()
  for i=1, #data.config_hooks do data.config_hooks[i][4](data.config) end  --notify hooks projloaded
end

function Proj.save_config()
  local cfg= data.config
  local changed= data.recent_prj_change
  for i=1, #data.config_hooks do
    if data.config_hooks[i][3](cfg) then changed=true end  --get hooked fields value
  end
  if changed or Proj.data.config.is_visible ~= Proj.is_visible then
    cfg.is_visible= Proj.is_visible
    cfg.edit_width= Proj.edit_width
    cfg.select_width= Proj.select_width
    for i=1, #data.recent_projects do cfg["recent#"..i]= data.recent_projects[i] end
    if #data.recent_projects < Proj.MAX_RECENT_PROJ then
      for i=#data.recent_projects+1, Proj.MAX_RECENT_PROJ do cfg["recent#"..i]= "" end
    end

    Util.save_config_file(cfg, Proj.PROJ_CONFIG_FILE)
    data.recent_prj_change= false
  end
end

function Proj.add_recentproject()
  -- Add Proj.data.filename to the recent project files list, eliminating duplicates
  for j, file in ipairs(data.recent_projects) do
    if file == data.filename then table.remove(data.recent_projects, j) break end
  end
  table.insert(data.recent_projects, 1, data.filename)
  --and remove file from recent "regular files" list
  for j, file in ipairs(io.recent_files) do
    if file == data.filename then table.remove(io.recent_files, j) break end
  end
  --save new list on exit
  data.recent_prj_change= true
  --update recent project list
  if toolbar.recentprojlist_update then toolbar.recentprojlist_update() end
end

--parse Proj.data.filename and fill project arrays
function Proj.parse_project_file()
  data.proj_parsed= true
  Proj.clear_proj_arrays()
  if data.filename == nil or data.filename == "" then
    notify_projload_ends()
    Util.info("ERROR", "Project filename unknown")
    ui.statusbar_text= 'ERROR: Project filename unknown'
    return
  end
  local fi, err= io.open(data.filename, 'rb')
  if not fi then
    notify_projload_ends()
    Util.info("ERROR: Can't open the project file", err)
    ui.statusbar_text= "ERROR: Can't open the project file"
    return
  end
  ui.statusbar_text= 'Parsing project file...'

  --get project file path (default)
  local p,f,e = Util.splitfilename(data.filename)
  local abspath= p
  local path= abspath

  --parse project file line by line
  local r= 0
  for line in fi:lines() do
    r= r+1
    local fname= ''
    local line= Util.str_trim_final(line) --remove final blanks/CR-LF

    --try option 1)
    local ind, rown, fn, opt = string.match(line,'^(%s*)(.-)%s*::(.*)::(.-)%s*$')
    if ind == nil then
      --try option 2)
      ind, fn= string.match(line,'^(%s*)(.-)%s*$')
      rown= fn
      if ind == nil then ind="" end
    end
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
        data.proj_grp_path[r]= path
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
      local o, p= string.match(opt, '(.)(.*)')
      if o == '-' then
        --  '-': fold this group on project load
        data.proj_fold_row[ #data.proj_fold_row+1 ]= r
      elseif o == 'C' then
        --  'C': CTAGS file
        if ftype == Proj.PRJF_FILE then ftype=Proj.PRJF_CTAG else ftype=Proj.PRJF_EMPTY end
      elseif o == 'R' then
        --  'R': RUN a command
        if ftype == Proj.PRJF_FILE then ftype=Proj.PRJF_RUN else ftype=Proj.PRJF_EMPTY end
      elseif o == 'S' or o == 'G' then
        --  'S': SVN repository base (1)
        --  'G': GIT repository base (2)
        ftype= Proj.PRJF_VCS
        data.proj_vcontrol[ #data.proj_vcontrol+1 ]= { path, p, (o == 'S') and 1 or 2, r }
      end
    end
    --set the filename/type asigned to each row
    data.proj_files[r]= fname
    data.proj_filestype[r]= ftype
    data.proj_rowinfo[r]= {rown, #ind, 0} --{row-name, indent, indent-len}
  end
  --set indent blocks len
  if #data.proj_rowinfo > 1 then
    for r= 2, #data.proj_rowinfo do
      local ic= data.proj_rowinfo[r-1][2]
      if ic < data.proj_rowinfo[r][2] then  --indent start at r-1
        local ilen= 1
        for re= r+1, #data.proj_rowinfo do
          if ic >= data.proj_rowinfo[re][2] then break end
          ilen= ilen+1
        end
        data.proj_rowinfo[r-1][3]= ilen
      end
    end
  end
  fi:close()
  ui.statusbar_text= 'Project: '.. data.filename
  notify_projload_ends()
end

function Proj.closed_cleardata()
  data.filename= ""
  Proj.clear_proj_arrays()
  ui.statusbar_text= 'Project closed'
  notify_projload_ends()
end

--return the file position (ROW: 1..) in the given buffer file list
function Proj.get_file_row(file)
  if #data.proj_files > 0 and file then
    for row=1, #data.proj_files do
      if file == data.proj_files[row] then return row end
    end
  end
  return nil --not found
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
  if selmode and buffer.modify then
    data.proj_parsed= false --prevent list update when saving the project until it's parsed
    io.save_file()
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
    if toolbar then toolbar.seltabbuf(buff) end --hide/show and select tab in edit mode
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
      if p_buffer == nil then
        ui.statusbar_text= 'No project found'
        return
      end

      --get a list of project files
      local flist= {}
      for row= 1, #data.proj_files do
        local ftype= data.proj_filestype[row]
        if ftype == Proj.PRJF_FILE then --ignore CTAGS files / path / empty rows
          local file= data.proj_files[row]
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
    local proc= os.spawn(cmd,nil,nil,function(status)
        ui.statusbar_text= 'RUN '..Proj.last_run_command..' ended with status '..status
        if Proj.last_run_tmpfile then
          os.remove(Proj.last_run_tmpfile)
          Proj.last_run_tmpfile= nil
        end
        --ctags? update list toolbar
        if toolbar.ctaglist_update then
          if Proj.last_run_command:match('ctags') then toolbar.ctaglist_update() end
        end
      end)
    ui.statusbar_text= 'RUNNING: '..Proj.last_run_command
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
      local in_prj= (Proj.get_file_row(file) ~= nil)
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

      --if the project is in readonly, change it
      save_ro= p_buffer.read_only
      p_buffer.read_only= false
      row= nil
      local curpath
      local defdir= data.proj_grp_path[1]
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
          if not row then row= #data.proj_files+1 end
        end
      end
      data.proj_parsed= false --prevent list update when saving the project until it's parsed
      io.save_file()
      p_buffer.read_only= save_ro
      --update Proj.data arrays: "proj_files[]", "proj_fold_row[]" and "proj_grp_path[]"
      Proj.parse_project_file()

      if row then
        --move the selection bar
        p_buffer:ensure_visible_enforce_policy(row- 1)
        p_buffer:goto_line(row-1)
      end
      -- project in SELECTION mode without focus--
      Proj.show_lost_focus(p_buffer)
      p_buffer.home()
      ui.statusbar_text= '' .. nadd .. ' file/s added to project'

      Proj.stop_update_ui(false)
    end
  end
end

-- find text in project's files
-- code adapted from module: find.lua
-- where: 0=ALL project files, 1=selected directory, 2=selected file
function Proj.find_in_files(p_buffer, text, match_case, whole_word, escapetext, where)
  local fromrow=1
  local filterpath
  if where == 1 then --only in selected directory
    if p_buffer then
      local r= p_buffer.line_from_position(p_buffer.current_pos)+1
      if r <= #data.proj_files then
        local ftype= data.proj_filestype[r]
        if ftype == Proj.PRJF_PATH then
          filterpath= data.proj_grp_path[r]
        elseif ftype == Proj.PRJF_FILE then
          local file= data.proj_files[r]
          if file and file ~= '' then
            local p,f,e= Util.splitfilename(file)
            filterpath= p
          end
        end
      end
    end
    if not filterpath then
      ui.statusbar_text= "No selected directory"
      return
    end
  elseif where == 2 then --only in selected file
    fromrow= p_buffer.line_from_position(p_buffer.current_pos)+1
  end

  Proj.stop_update_ui(true)
  --activate/create search view
  Proj.beg_search_add()

  buffer:append_text('['..text..']\n')
  if escapetext then text= Util.escape_match(text) end
  if filterpath then buffer:append_text(' search dir '..filterpath..'::::\n') end

  buffer:goto_pos(buffer.length)
  buffer.indicator_current = ui.find.INDIC_FIND
  if whole_word then text = '%f[%w_]'..(match_case and text or text:lower())..'%f[^%w_]' end

  local nfiles= 0
  local totfiles= 0
  local nfound= 0
  local filesnf= 0
  --check the given buffer has a list of files
  if p_buffer then
    local torow= #data.proj_files
    if where == 2 and fromrow < torow then torow= fromrow end
    for row= fromrow, torow do
      local ftype= data.proj_filestype[row]
      if ftype == Proj.PRJF_FILE then --ignore CTAGS files / path / empty rows
        local file= data.proj_files[row]
        if file and file ~= '' then
          if not Util.file_exists(file) then
            filesnf= filesnf+1 --file not found
            buffer:append_text(('(%s NOT FOUND)::::\n'):format(file))
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
  end

  if nfound == 0 then buffer:append_text(' '.._L['No results found']..'\n') end
  buffer:append_text('\n')

  local result= ''..nfound..' matches in '..nfiles..' of '..totfiles..' files'
  if filesnf > 0 then
    result= result .. ' / '..filesnf..' files NOT FOUND'
  end
  ui.statusbar_text= result
  Proj.end_search_add()
  --set search context menu
  Proj.set_contextm_search()
  Proj.stop_update_ui(false)
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

--get "version control number, path, url" for filename
function Proj.get_versioncontrol_url(filename)
  filename=string.gsub(filename, '%\\', '/')
  local p_buffer= Proj.get_projectbuffer(true)
  if p_buffer == nil then
    ui.statusbar_text= 'No project found'
    return
  end
  if data.proj_vcontrol == nil or #data.proj_vcontrol == 0 then
    ui.statusbar_text= 'No SVN/GIT repository set in project'
    return
  end
  local url= ""
  local nvc= 1
  while nvc <= #data.proj_vcontrol do
    local base= data.proj_vcontrol[nvc][1]
    if base and base ~= '' then
      base= string.gsub(base, '%\\', '/')
      --remove base dir
      local fmt= '^'..Util.escape_match(base)..'(.*)'
      url= string.match(filename,fmt)
      if url and url ~= '' then
        break
      end
    end
    nvc=nvc+1
  end
  if nvc > #data.proj_vcontrol then
    ui.statusbar_text= 'The file is outside project base directory'
    return
  end
  local param= data.proj_vcontrol[nvc][2] --add prefix to url [,currentdir]
  local pref, cwd= string.match(param, '(.-),(.*)')
  if not pref then pref= param end
  url= pref..url
  local verctrl= data.proj_vcontrol[nvc][3]
  ui.statusbar_text= (verctrl == 1 and 'SVN: ' or 'GIT: ')..url
  return verctrl, cwd, url
end
