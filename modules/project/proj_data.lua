-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
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
--   is_open            = (filename ~= "")
--   parse_ver          = parse version (+1 in every parse)
--   proj_files[]       = array with the filename in each row (1...) or ''
--   proj_filestype[]   = array with the type of each row: Proj.PRJF_...
--   proj_fold_row[]    = array with the row numbers to fold on open
--   proj_grp_path[]    = array with the path of each group or nil
--   proj_vcontrol[]    = array with the SVN/GIT version control rows
--   proj_rowinfo[]     = array {row-text, indent, indent-len}
--   config_hooks[]     = objects/toolbars that use the project configuration
--                          {beforeload, afterload, beforesave, projloaded}
-----------------------------------------------------------------------
--  Proj.data:          RECENT PROJECTS
--   recent_projects[]  = recent Projects list (array[ Proj.MAX_RECENT_PROJ ])
--   recent_prj_change  = the recent Projects list has been modified
-----------------------------------------------------------------------
--  Proj.data.config[]  PROJECT CONFIGURATION
--   [show_mode]        = 0=hidden  1=shown in selection mode  2=shown in edit mode
--   [edit_width]       = view width in edit mode
--   [select_width]     = view width in selection mode
--   [recent#1..30]     = recent projects (#1= the most recent)
--  Proj.data.config.show_mode/edit_width/..= last saved configuration
--  Proj.data.show_mode/edit_width/..= current value
-----------------------------------------------------------------------
local Proj = Proj
local Util = Util

Proj.PROJ_CONFIG_FILE = _USERHOME..'/project_config'
Proj.MAX_RECENT_PROJ = 30

Proj.data= {}
local data= Proj.data
data.filename= ""  --open project filename or ""
data.is_open= false
data.parse_ver= 0

--show mode
Proj.SM_HIDDEN= 0
Proj.SM_SELECT= 1
Proj.SM_EDIT=   2
data.show_mode= Proj.SM_HIDDEN  --0=hidden  1=selection mode  2=edit mode

data.edit_width= 600
data.select_width= 200
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
  data.parse_ver= data.parse_ver+1 --advance parse version
end
Proj.clear_proj_arrays()

local CFGHOOK_BEFORE_LOAD=   1  --add hooked fields to config
local CFGHOOK_CONFIG_LOADED= 2  --notify config loaded
local CFGHOOK_BEFORE_SAVE=   3  --get hooked fields value
local CFGHOOK_PROJ_LOADED=   4  --notify project loaded

function Proj.add_config_hook(beforeload, afterload, beforesave, projloaded)
  data.config_hooks[#data.config_hooks+1]= {beforeload, afterload, beforesave, projloaded}
end

function Proj.load_config()
  data.config= {}
  local cfg= data.config
  Util.add_config_field(cfg, "show_mode",    Util.cfg_int, Proj.SM_HIDDEN)
  Util.add_config_field(cfg, "edit_width",   Util.cfg_int, 600)
  Util.add_config_field(cfg, "select_width", Util.cfg_int, 200)
  Util.add_config_field(cfg, "recent",       Util.cfg_str, "", Proj.MAX_RECENT_PROJ)
  --add hooked fields to config
  for i=1, #data.config_hooks do data.config_hooks[i][CFGHOOK_BEFORE_LOAD](cfg) end
  Util.load_config_file(cfg, Proj.PROJ_CONFIG_FILE)
  data.recent_prj_change= false

  data.show_mode= cfg.show_mode
  data.edit_width= cfg.edit_width
  if data.edit_width < 50 then data.edit_width= 600 end
  data.select_width= cfg.select_width
  if data.select_width < 50 then data.select_width= 200 end

  data.recent_projects={}
  for i=1, Proj.MAX_RECENT_PROJ do
    local rc= cfg["recent#"..i]
    if rc and (rc ~= "") then data.recent_projects[#data.recent_projects+1]=rc end
  end
  --notify config loaded
  for i=1, #data.config_hooks do data.config_hooks[i][CFGHOOK_CONFIG_LOADED](data.config) end
end

local function notify_projload_ends() --notify hooks projloaded
  for i=1, #data.config_hooks do data.config_hooks[i][CFGHOOK_PROJ_LOADED](data.config) end
end

function Proj.save_config()
  local cfg= data.config
  local changed= data.recent_prj_change
  for i=1, #data.config_hooks do --get hooked fields value
    if data.config_hooks[i][CFGHOOK_BEFORE_SAVE](cfg) then changed=true end
  end
  if changed or Proj.data.config.show_mode ~= Proj.data.show_mode then
    cfg.show_mode= Proj.data.show_mode
    cfg.edit_width= data.edit_width
    cfg.select_width= data.select_width
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
  if toolbar and toolbar.recentprojlist_update then toolbar.recentprojlist_update() end
end

function Proj.create_empty_project(filename, projname, rootdir)
  local fo, err= io.open(filename, 'wb')
  if not fo then
    Util.info("ERROR: Can't create the project file", err)
    ui.statusbar_text= "ERROR: Can't create the project file"
    return false
  end
  fo:write('[' .. projname .. ']::' .. rootdir .. '::')
  fo:close()
  return true
end

function Proj.add_files_to_project(flist, groupfiles, all, finprj)
  if not data.is_open then return nil end
  local fo, err= io.open(data.filename, 'a+b')
  if not fo then
    Util.info("ERROR: Can't add file/s to project", err)
    ui.statusbar_text= "ERROR: Can't add file/s to project"
    return nil
  end
  local row= nil
  local curpath= nil
  local defdir= data.proj_grp_path[1]
  for i,file in ipairs(flist) do
    if all or finprj[i] == false then --all files or just new ones
      local path,fn,ext = Util.splitfilename(file)
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
          fo:write( '\n (' .. ph .. ')::' .. path .. '::')
        end
        fo:write( '\n  ' .. fn)
      else
        --add files with absolute path
        fo:write( '\n ' .. fn .. '::' .. file .. '::')
      end
      --add the new line to the proj. file list
      if not row then row= #data.proj_files+1 end
    end
  end
  fo:close()
  --update Proj.data arrays: "proj_files[]", "proj_fold_row[]" and "proj_grp_path[]"
  Proj.parse_project_file()
  return row
end

function Proj.is_prj_buffer(p_buffer)
  --check if the buffer is a valid project
  --The first file line MUST BE a valid "option 1)": ...##...##...
  local line= p_buffer:get_line( Util.LINE_BASE )
  local n, fn, opt = string.match(line,'^%s*(.-)%s*::(.*)::(.-)%s*$')
  return (n ~= nil)   --return: is a project file
end

--parse Proj.data.filename and fill project arrays
function Proj.parse_project_file()
  Proj.clear_proj_arrays()  --clear data and advance parse version
  if not data.is_open then
    notify_projload_ends()
    Util.info("ERROR", "Unknown project filename")
    ui.statusbar_text= 'ERROR: Unknown project filename'
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
  if data.is_open then ui.statusbar_text= 'Project closed' end
  data.filename= ""
  data.is_open= false
  data.show_mode= Proj.SM_HIDDEN
  Proj.update_projview_action() --update action: toggle_viewproj/toggle_editproj
  Proj.clear_proj_arrays() --clear data and advance parse version
  notify_projload_ends()
end

--return the file position (ROW: 1..) in the project file list
function Proj.get_file_row(file)
  if #data.proj_files > 0 and file then
    for row=1, #data.proj_files do
      if file == data.proj_files[row] then return row end
    end
  end
  return nil --not found
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
      if not Proj.check_is_open() then return end

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
      tmpfile = data.filename..'_tmp'
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

--get "version control number, path, url" for filename
function Proj.get_versioncontrol_url(filename)
  if not Proj.check_is_open() then return end

  if data.proj_vcontrol == nil or #data.proj_vcontrol == 0 then
    ui.statusbar_text= 'No SVN/GIT repository set in project'
    return
  end
  filename=string.gsub(filename, '%\\', '/')
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
