-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
---- PROJECT ACTIONS ----
local Proj = Proj
local Util = Util
local _L = _L
local data = Proj.data

--ACTION: new
function Proj.new_file()
  Proj.goto_filesview()
  buffer.new()
end

--ACTION: open
function Proj.open_file()
  Proj.goto_filesview()
  io.open_file()
end

--ACTION: recent
function Proj.open_recent_file()
  Proj.goto_filesview()
  io.open_recent_file()
end

--ACTION: close
function Proj.close_buffer()
  if buffer._project_select ~= nil then
    --close project file and views
    Proj.close_project(false)

  elseif buffer._type == Proj.PRJT_SEARCH then
    --close search results
    plugs.close_results()

  else
    --close a regular file
    if Util.close_buffer() then
      --check that at least one regular buffer remains after closing
      Proj.check_panels()
    end
  end
end

--ACTION: closeall (close project)
--function Proj.close_all_buffers()
--  --close project file and views
--  Proj.close_project(false)
--  --close all buffers
--  io.close_all_buffers()
--end
--
--ACTION: closeall (dont'close project)
function Proj.onlykeep_projopen(keepone)
  Proj.stop_update_ui(true)
  --close search results
  plugs.close_results()
  --change to left/only file view if needed
  Proj.goto_filesview(Proj.FILEPANEL_LEFT)
  local i= 1
  local n= #_BUFFERS
  while n > 0 do
    n= n-1
    local buf=_BUFFERS[i]
    if Proj.isRegularBuf(buf) and not buf._dont_close then
      --regular file, close it
      Util.goto_buffer(buf)
      if not Util.close_buffer() then
        Proj.stop_update_ui(false)
        return --cancel close all
      end
    else
      --skip project buffers and don't close buffers
      i= i+1
      buf._dont_close= nil --remove flag
    end
  end
  --check that at least one regular buffer remains after closing
  Proj.check_panels()
  if actions then actions.updateaction("dont_close") end
  Proj.stop_update_ui(false)
end

--ACTION: open_userhome
function Proj.qopen_user()
  Proj.goto_filesview()
  io.quick_open(_USERHOME)
  plugs.track_this_file()
end

--ACTION: open_textadepthome
function Proj.qopen_home()
  Proj.goto_filesview()
  io.quick_open(_HOME)
  plugs.track_this_file()
end

--ACTION: open_currentdir
function Proj.qopen_curdir()
  Proj.goto_filesview()
  local fname= buffer.filename
  if fname then
    io.quick_open(fname:match('^(.+)[/\\]'))
    plugs.track_this_file()
  end
end

--ACTION: quick_open_projectdir
--quick open project files based on io.quick_open/snapopen @ file_io.lua
function Proj.quick_open()
  if not Proj.check_is_open() then return end

  --if the current view is a project view, goto files view
  Proj.goto_filesview()
  local utf8_list = {}
  for row= 1, #data.proj_files do
    local file= data.proj_files[row]
    local ftype= data.proj_filestype[row]
    if file and file ~= '' and (ftype == Proj.PRJF_FILE or ftype == Proj.PRJF_CTAG) then
      file = file:gsub('^%.[/\\]', ''):iconv('UTF-8', _CHARSET)
      utf8_list[#utf8_list + 1] = file
    end
  end
  local options = {
    title = _L['Open File'], columns = _L['Filename'], items = utf8_list,
    button1 = Util.OK_TEXT, button2 = Util.CANCEL_TEXT, select_multiple = true,
    string_output = true, width = CURSES and ui.size[1] - 2 or nil
  }
  local button, files = ui.dialogs.filteredlist(options)
  if button ~= Util.OK_TEXT or not files then return end
  for i = 1, #files do files[i] = files[i]:iconv(_CHARSET, 'UTF-8') end
  io.open_file(files)
  Proj.update_after_switch()
end

function Proj.get_cmd_output(cmd, cwd, info)
  if cmd and cmd ~= "" then
    local p = assert(os.spawn(cmd,cwd))
    p:close()
    local einfo=(p:read('*a') or ''):iconv('UTF-8', _CHARSET)
    if einfo and einfo ~= '' then
      if info and info ~= '' then return info..'\n'..einfo end
      return einfo
    end
  end
  return info
end

function debug_cmd(cmd, cwd) --run a command from the "Command entry"; output in one line
  --e.g.: debug_cmd("git status -sb", "C:\\Users\\gabriel\\.textadept\\ta-tweaks\\")
  return string.gsub(Proj.get_cmd_output(cmd, cwd, ""), "\n", " ")
end

function Proj.get_filevcinfo(fname)
  --show file VCS info (up to 2 different types. e.g.: GIT + FOLDER)
  local infotot= ""
  local fn= string.match(fname..'::','(.-):HEAD::')
  if fn then fname=fn end
  local cmd, pre2, cmd2, info, post
  local lastverctrl= 0
  for i=1, 2 do
    --get version control params for filename
    local verctrl, cwd, url= Proj.get_versioncontrol_url(fname, (i==2))
    if verctrl == lastverctrl then break end  --don't show the same VCS type twice
    lastverctrl= verctrl
    post= ""
    cmd= ""
    pre2= ""
    cmd2= ""
    if verctrl == Proj.VCS_SVN and url ~= "" then
      info= fname
      cmd= "svn info "..url
      post= "SVN"
    elseif verctrl == Proj.VCS_GIT and url ~= "" then
      info= fname..'\nGIT: '..url
      cmd= "git status -sb "..url
      pre2= "\n--- Last 2 commits ----"
      cmd2= "git log -n2 "..url
    elseif verctrl == Proj.VCS_FOLDER then
      local dm1= lfs.attributes(fname, 'modification')
      local sz1= lfs.attributes(fname, 'size')
      if url == "" then
        info= 'LOCAL: '..fname..'\n'..os.date('%c',dm1)..'\n'..sz1..' bytes\n\nFOLDER: NOT DEFINED'
      else
        local dm2= 0
        local sz2= 0
        local fm2= "FILE NOT FOUND"
        local same= false
        if Util.file_exists(url) then
          dm2= lfs.attributes(url, 'modification')
          sz2= lfs.attributes(url, 'size')
          fm2= os.date('%c',dm2)..((dm2 > dm1) and " * NEW *" or "")..'\n'..sz2..' bytes'
          --same size (ignore dates): check the file content
          if sz1 == sz2 then same= Util.compare_file_content(fname, url) end
        end
        local fm1= os.date('%c',dm1)..((dm1 > dm2) and " * NEW *" or "")..'\n'..sz1..' bytes'
        info= 'LOCAL: '..fname..'\n'..fm1..'\n\nFOLDER: '..url..'\n'..fm2..(same and '\nSAME CONTENT' or '\nMODIFIED')
      end
    else
      break
    end
    if cmd then
      info= Proj.get_cmd_output(cmd, cwd, info)..Proj.get_cmd_output(cmd2, cwd, pre2)..post
    end
    if infotot == "" then infotot= info else infotot=infotot..'\n-----------------------\n'..info end
  end
  return infotot
end

--ACTION: show_filevcinfo
function Proj.show_filevcinfo()
  --call_tip_show
  if buffer.filename ~= nil then
    if buffer:call_tip_active() then events.emit(events.CALL_TIP_CLICK) return end
    local info= Proj.get_filevcinfo(buffer.filename)
    if info ~= '' then
      buffer:call_tip_show(buffer.current_pos, info )
    end
  end
end

function Proj.get_vcs_index(row)
  if data.proj_vcontrol then
    for i=1, #data.proj_vcontrol do  --{path, p, vc_type, row}
      if data.proj_vcontrol[i][4] == row then
        return i
      end
    end
  end
  return nil
end

function Proj.get_vcs_info(row, sep)
  local idx= Proj.get_vcs_index(row)
  --{path, p, vc_type, row}
  if idx then return Proj.VCS_LIST[data.proj_vcontrol[idx][3]] ..": "..data.proj_vcontrol[idx][1]..(sep or " | ")..data.proj_vcontrol[idx][2] end
  return ""
end

local vcs_item_base= ""
local function vcs_item_selected(fname)
  Proj.go_file( vcs_item_base..fname )
  return true --keep dialog open
end

local repo_changes= {}
local function get_vcs_file_status(file1, fname, vctrl)
  --compare files and return a status character:
  -- "M" = different files (local is NEWER)
  -- "O" = different files (local is OLDER)
  -- "A" = new local file
  -- "D" = local file not present
  -- "-" = no files found

  --vctrl= {path, param, vc_type, row}
  local param= vctrl[2] --add prefix to url [,currentdir]
  if param ~= "" then
    local pref, cwd= string.match(param, '(.-),(.*)')
    if not pref then pref= param end
    local file2= pref..fname

    local vctype= vctrl[3]
    if vctype == Proj.VCS_GIT or vctype == Proj.VCS_SVN then --check parsed "git/svn status"
      return repo_changes[fname] or ""
    end
    if vctype == Proj.VCS_FOLDER then
      --test file1/2 existence
      local ex1= Util.file_exists(file1)
      local ex2= Util.file_exists(file2)
      if (not ex1) and (not ex2) then return "-" end  --no file found on both sides
      if not ex2 then return "A" end  --new local file
      if not ex1 then return "D" end  --local file deleted
      --compare file1/2 (quick test)
      local sz1= lfs.attributes(file1, 'size')
      local sz2= lfs.attributes(file2, 'size')
      local modif= false --different size/content
      if sz1 ~= sz2 then modif=true else modif= not Util.compare_file_content(file1, file2) end
      if modif then
        local dm1= lfs.attributes(file1, 'modification')
        local dm2= lfs.attributes(file2, 'modification')
        if dm1 >= dm2 then return "M" end --modified and NEWER
        return "O" --modified but OLDER
      end
    end
  end
  return "" --same
end

--list files in this VCS folder/subfolders
local flist= {}
local publish_folder= ""
local gitbranch= ""

local function b_update(bname)
  --Copy changes (O/D) to the destination folder
  local numO= 0
  local numD= 0
  local fnames= ""
  for i=1, #flist do
    local le= flist[i][2]
    if le == "O" then numO= numO+1 end
    if le == "D" then numD= numD+1 end
    if (le == "O" or le == "D") and (#fnames < 300) then
      fnames= fnames..(#fnames == 0 and "" or "\n")..flist[i][1]
      if #fnames >= 300 then fnames= fnames.."\n..." end
    end
  end
  local txt
  if numO == 0 then
    if numD == 0 then Util.info("Nothing to update", "No files marked as 'O' or 'D' found") return end
    txt= ""..numD.. " new file"..(numD > 1 and "s" or "")
  else
    txt= ""..numO.. " modified file"..(numO > 1 and "s" or "")
    if numD > 0 then
      txt= txt.." and "..numD.. " new file"..(numD > 1 and "s" or "")
    end
  end
  if Util.confirm("Update local folder", "Copy "..txt.." to "..vcs_item_base.. " ?", fnames) then
    local numok= 0
    for i=1, #flist do
      local le= flist[i][2]
      if le == "O" or le == "D" then
        local fname= flist[i][1]
        if Util.copy_file(publish_folder..fname, vcs_item_base..fname) then numok= numok+1 end --ORG => DEST
      end
    end
    if numok == (numO+numD) then
      Util.info("Update local folder", ""..numok.. " files copied successfully")
    else
      Util.info("Update local folder", "Warning:\nOnly "..numok.." of the "..(numO+numD).. " files were copied successfully")
    end
  end
end

local function b_publish(bname)
  --Copy changes (M/A) to the destination folder
  local numM= 0
  local numA= 0
  local fnames= ""
  for i=1, #flist do
    local le= flist[i][2]
    if le == "M" then numM= numM+1 end
    if le == "A" then numA= numA+1 end
    if (le == "M" or le == "A") and (#fnames < 300) then
      fnames= fnames..(#fnames == 0 and "" or "\n")..flist[i][1]
      if #fnames >= 300 then fnames= fnames.."\n..." end
    end
  end
  local txt
  if numM == 0 then
    if numA == 0 then Util.info("Nothing to publish", "No files marked as 'M' or 'A' found") return end
    txt= ""..numA.. " new file"..(numA > 1 and "s" or "")
  else
    txt= ""..numM.. " modified file"..(numM > 1 and "s" or "")
    if numA > 0 then
      txt= txt.." and "..numA.. " new file"..(numA > 1 and "s" or "")
    end
  end
  if Util.confirm("Publish to folder", "Copy "..txt.." to "..publish_folder.. " ?", fnames) then
    local numok= 0
    for i=1, #flist do
      local le= flist[i][2]
      if le == "M" or le == "A" then
        local fname= flist[i][1]
        if Util.copy_file( vcs_item_base..fname,  publish_folder..fname) then numok= numok+1 end --ORG => DEST
      end
    end
    if numok == (numM+numA) then
      Util.info("Publish to folder", ""..numok.. " files copied successfully")
    else
      Util.info("Publish to folder", "Warning:\nOnly "..numok.." of the "..(numM+numA).. " files were copied successfully")
    end
  end
end

local function b_show_all(bname)
  --toggle show all/changed files
  toolbar.selected("dlg-show-all", false, toolbar.dlg_filter_col2)
  toolbar.dlg_filter_col2= not toolbar.dlg_filter_col2
end

function Proj.open_vcs_dialog(row)
  --open a dialog with the project files that are in this VCS item folder/subfolders
  local idx= Proj.get_vcs_index(row)
  if idx then
    local vc_item_name= data.proj_rowinfo[row][1]
    local vctrl= data.proj_vcontrol[idx] --{path, param, vc_type, row}
    local vctype= vctrl[3]
    ui.statusbar_text= Proj.VCS_LIST[vctype] ..": "..vc_item_name
    vcs_item_base= string.gsub(vctrl[1], '%\\', '/')
    local fmt= '^'..Util.escape_match(vcs_item_base)..'(.*)'

    publish_folder= ""
    gitbranch= ""
    local pref, cwd
    local param= vctrl[2] --param
    if param ~= "" then pref, cwd= string.match(param, '(.-),(.*)') if not pref then pref= param end end
    if vctype == Proj.VCS_GIT or vctype == Proj.VCS_SVN then
      --parse GIT/SVN changes
      repo_changes= {}
      local stcmd= (vctype == Proj.VCS_GIT) and "git status -sb" or "svn status -q"
      if cwd == nil or cwd == "" then
        if vctype == Proj.VCS_SVN then cwd= vcs_item_base end
      end
      --ui.statusbar_text= stcmd.." | " ..(cwd or "")
      local rstat= string.gsub(Proj.get_cmd_output(stcmd, cwd, ""), '%\\', '/')
      local readbranch= (vctype == Proj.VCS_GIT)
      for line in rstat:gmatch('[^\n]+') do
        if readbranch then
          readbranch= false
          gitbranch= string.match(line, '##%s*(.*)')
        else
          --split "letter filename"
          local lett, fn= string.match(line, '%s*(.-)%s(.*)')
          if fn then repo_changes[ Util.str_trim(fn) ]= lett end
        end
      end

    elseif vctype == Proj.VCS_FOLDER then
      publish_folder= pref or "" --folder??
    end

    flist= {}
    local dconfig= {}
    local enupd= false
    local enpub= false
    dconfig["columns"]= {550, 50} --icon+filename | status-letter
    local buttons= {
      --1:bname, 2:text, 3:tooltip, 4:x, 5:width, 6:row, 7:callback, 8:button-flags=toolbar.DLGBUT...
      {"dlg-update", "Update", "Update local folder, get newer files (O/D)", 300, 95, 1, b_update, toolbar.DLGBUT.CLOSE},
      {"dlg-publish", "Publish", "Copy changes (M/A) to the destination folder", 400, 95, 1, b_publish, toolbar.DLGBUT.CLOSE},
      {"dlg-show-all", "Show All", "Show all/changed files", 500, 95, 1, b_show_all, toolbar.DLGBUT.RELOAD}
    }
    if gitbranch ~= "" then
      buttons[#buttons+1]= {"dlg-branch", gitbranch, "Git branch", 4, 0, 1, nil, toolbar.DLGBUT.CLOSE|toolbar.DLGBUT.BOLD}
    end
    dconfig["buttons"]= buttons
    toolbar.dlg_filter_col2= false --show all items
    for row= 1, #data.proj_files do
      if data.proj_filestype[row] == Proj.PRJF_FILE then --ignore CTAGS files / path / empty rows
        local projfile= string.gsub(data.proj_files[row], '%\\', '/')
        local fname= string.match(projfile, fmt)
        if fname and fname ~= '' then
          local col2= get_vcs_file_status(projfile, fname, vctrl)
          flist[ #flist+1 ]= {fname, col2}
          if col2 ~= "" then
            toolbar.dlg_filter_col2= true --only show items with something in col2
            if vctype == Proj.VCS_FOLDER then
              enupd= ((col2=='O') or (col2=='D'))
              enpub= ((col2=='M') or (col2=='A'))
            end
          end
        end
      end
    end
    --show folder files
    toolbar.dlg_select_it=""
    toolbar.dlg_select_ev= vcs_item_selected
    toolbar.create_dialog(Proj.VCS_LIST[vctrl[3]]..": "..vctrl[1], 600, 400, flist, "MIME", false, false, dconfig) --double-click= select and close
    toolbar.selected("dlg-show-all", false, not toolbar.dlg_filter_col2)
    toolbar.enable("dlg-update",  enupd and (publish_folder ~= ""))
    toolbar.enable("dlg-publish", enpub and (publish_folder ~= ""))
    toolbar.enable("dlg-branch", false)
    toolbar.popup(toolbar.DIALOG_POPUP,true,300,300,-600,-400) --open at a fixed position
  end
end

--ACTION: show_documentation
-- show project current row properties
function Proj.show_doc()
  --call_tip_show
  if buffer._project_select ~= nil then
    if buffer:call_tip_active() then events.emit(events.CALL_TIP_CLICK) return end
    local r= buffer.line_from_position(buffer.current_pos) +1 -Util.LINE_BASE
    local info = data.proj_files[r]
    local ftype= data.proj_filestype[r]
    if ftype == Proj.PRJF_CTAG then info= 'CTAG: '..info
    elseif ftype == Proj.PRJF_VCS then info= Proj.get_vcs_info(r)
    elseif ftype == Proj.PRJF_RUN then info= 'RUN: '..info end
    if info == '' and data.proj_grp_path[r] ~= nil then
      info= data.proj_grp_path[r]
    elseif ftype == Proj.PRJF_FILE then
      info= Proj.get_filevcinfo(info)
    end
    if info ~= '' then
      buffer:call_tip_show(buffer.current_pos, info )
    end
  else
    --call default show doc function
    textadept.editing.show_documentation()
  end
end

--ACTION: next_buffer
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
        nb= nb+1
        if nb > #_BUFFERS then nb= 1 end
        retry= retry-1
      end
    end
    Proj.goto_buffer(nb)
  end
end

--ACTION: prev_buffer
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
        nb= nb-1
        if nb < 1 then nb= #_BUFFERS end
        retry= retry-1
      end
    end
    Proj.goto_buffer(nb)
  end
end

--ACTION: switch_buffer
function Proj.switch_buffer()
  local columns, utf8_list = {_L['Name'], _L['File']}, {}
  for i = 1, #_BUFFERS do
    local buffer = _BUFFERS[i]
    local filename = buffer.filename or buffer._type or Util.UNTITLED_TEXT
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

--ex ACTION: refresh_syntax
-- refresh syntax highlighting + project folding
function Proj.refresh_hilight()
  plugs.proj_refresh_hilight()
  refresh_syntax()
end

--ACTION: trim_trailingspaces
--delete all trailing blanks chars
function Proj.trim_trailing_spaces()
  local buffer = buffer
  buffer:begin_undo_action()
  local n= 0
  local fromln= Util.LINE_BASE
  local toln= fromln + buffer.line_count - 1
  for line = fromln, toln do
    local trail = buffer:get_line(line):match('^.-(%s-)[\n\r]*$')
    if trail and trail ~= '' then
      local e= buffer.line_end_position[line]
      local s= e - string.len(trail)
      buffer:set_target_range(s, e)
      buffer:replace_target('')
      n= n+1
    end
  end
  buffer:end_undo_action()
  if n > 0 then
    ui.statusbar_text= 'Trimmed lines: '..n
  else
    ui.statusbar_text= 'No trailing spaces found'
  end
end

--ACTION: remove_tabs
--Convert all tabs into spaces
function Proj.remove_tabs()
  local buffer = buffer
  local nt, ne= 0, 0
  buffer:begin_undo_action()
  local pos= buffer.current_pos
  local startlin= buffer.line_from_position(pos)
  local startcol= buffer.column[pos]
  buffer:goto_pos(0)
  buffer:search_anchor()
  local tw= buffer.tab_width
  pos= buffer:search_next(0, "\t")
  while pos ~= -1 do
    buffer:set_target_range(pos, pos+1)
    local col= buffer.column[pos] -Util.LINE_BASE
    local spaces = tw - math.fmod(col, tw)
    buffer:replace_target(string.rep(' ', spaces))
    nt=nt+1
    ne=ne+spaces
    pos= buffer:search_next(0, "\t")
  end
  buffer:goto_pos(buffer:find_column(startlin, startcol))
  buffer:end_undo_action()
  ui.statusbar_text= ""..nt.." tabs replaced with "..ne.." spaces"
end

--ACTION: new_project
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
    ui.statusbar_text= 'New project cancelled'
    return
  end
  path,fn,ext = Util.splitfilename(filename)
  --remove extension
  if ext ~= '' then fn= fn:match('^(.+)%.') end
  --select the root of the project (suggest project path)
  rootdir = ui.dialogs.fileselect{
    title = 'Select project root (Cancel = relative to project file)',
    select_only_directories = true, with_directory = path
  }
  local vc_dir, vc_workdir, vc_param
  if not rootdir then
    rootdir=''  --relative to project file
    vc_dir= path --with file separator
    vc_workdir= Util.remove_pathsep_end(vc_dir) --without file separator
  else
    vc_workdir= rootdir --without file separator
    rootdir= rootdir .. Util.PATH_SEP
    vc_dir= rootdir --with file separator
  end
  --check for ".git"/".svn" folders
  if Util.dir_exists(vc_dir..".git") then
    if Util.confirm("GIT support", "The project folder contains a GIT repository", "Do you want to add it to the project?") then
      --[git]::C:\Users\desa1\test\::G,C:\Users\desa1\test
      vc_param= {"[git]", vc_dir, "G,"..vc_workdir}
    end
  elseif Util.dir_exists(vc_dir..".svn") then
    if Util.confirm("SVN support", "The project folder contains an SVN repository", "Do you want to add it to the project?") then
      local r,vc_pref= ui.dialogs.inputbox{title = 'SVN Server', informative_text = 'Input the full SVN server path\n(e.g. https://192.168.0.11:8443/svn/repo-name/\n or http://192.168.0.60/svn/repo-name/)', width = 400, text = ""}
      if type(vc_pref) == 'table' then
        vc_pref= table.concat(vc_pref, ' ')
      end
      --[svn]::/home/user/::Shttps://192.168.0.11:8443/svn/
      --[svn]::/home/user/repo-name/::Shttp://192.168.0.60/svn/repo-name/
      if vc_pref ~= "" then vc_param= {"[svn]", vc_dir, "S"..vc_pref} end
    end
  end
  --create the project file and open it
  if Proj.create_empty_project(filename, fn, rootdir, vc_param) then
    Proj.open_project(filename)
    Proj.add_dir_files(vc_workdir)
  end
end

--ACTION: open_project
--open an existing project file
function Proj.open_project(filename)
  local prjfile= filename or ui.dialogs.fileselect{
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

    data.filename= prjfile
    data.is_open= true
    if not plugs.open_project() then   --open the project file
      data.is_open= false
      Proj.closed_cleardata()
    end
  end
end

--ACTION: recent_project
--open a project from the recent list
function Proj.open_recent_project()
  local utf8_filenames = {}
  for _, filename in ipairs(data.recent_projects) do
    utf8_filenames[#utf8_filenames + 1] = filename:iconv('UTF-8', _CHARSET)
  end
  local button, i = ui.dialogs.filteredlist{
    title = 'Open Project File',
    columns = _L['File'],
    items = utf8_filenames,
    width = CURSES and ui.size[1] - 2 or nil
  }
  if button == 1 and i then Proj.open_project(data.recent_projects[i]) end
end

--ACTION: close_project
--close current project / view
function Proj.close_project(keepviews)
  return plugs.close_project(keepviews)
end

--ACTION: search_project
function Proj.search_in_files(where, suggest)
  if not Proj.ask_search_in_files then --goto_nearest module?
    ui.statusbar_text= 'goto_nearest module not found'
    return
  end
  if not Proj.check_is_open() then return end
  local currow= plugs.get_prj_currow() --get the selected project row number
  if currow > 0 then
    local find, case, word= Proj.ask_search_in_files(true, suggest)
    if find then Proj.find_in_files(currow, find, case, word, true, where) end
  end
end
--ACTION: search_sel_dir
function Proj.search_in_sel_dir()
  Proj.search_in_files(1) --1=selected directory
end
--ACTION: search_sel_file
function Proj.search_in_sel_file()
  Proj.search_in_files(2) --2=selected file
end

--ACTION: clear_search
function Proj.clear_search()
  if plugs.clear_results then plugs.clear_results() end
end

--ACTION: close_others
function Proj.close_others()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.goto_filesview()
  buffer._dont_close= true --force keep this
  --close the other buffers (except the project)
  Proj.onlykeep_projopen(true)
end

--ACTION: dont_close
function Proj.keepthisbuff_status()
  return (buffer._dont_close and 1 or 2) --check
end
function Proj.toggle_keep_thisbuffer()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.goto_filesview()
  if buffer._dont_close then buffer._dont_close= nil else buffer._dont_close= true end
  if actions then actions.updateaction("dont_close") end
end

--ACTION: showin_rightpanel
function Proj.showin_rightpanel_status()
  return (buffer._right_side and 1 or 2) --check
end
function Proj.toggle_showin_rightpanel()
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.stop_update_ui(true)
  Proj.goto_filesview()
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
  Util.goto_buffer(buf)
  Proj.close_untitled() --close "Untitled" buffers in the same view
  Proj.stop_update_ui(false)
  Proj.update_after_switch()
  if actions then actions.updateaction("showin_rightpanel") end
end

--ACTION: open_projsel (only used for project in buffers)
--open the selected file/s
--when more than one line is selected, ask for confirmation
function Proj.open_sel_file()
  plugs.open_sel_file()
end

--ACTION: toggle_editproj / _end_editproj (alias)
--toggle project between selection and EDIT modes
function Proj.toggle_editproj()
  plugs.change_proj_ed_mode()
end

--ACTION: toggle_viewproj
function Proj.toggle_projview()
  Proj.show_hide_projview()
end

--ACTION: addcurrentfile_proj
-- add the current file to the project
function Proj.add_current_file()
  if not Proj.check_is_open() then return end
  local file= buffer.filename
  if file ~= nil and buffer._project_select == nil and buffer._type == nil then
    local flist= {}
    flist[1]= file
    Proj.add_files(flist, false)
  end
end

--ACTION: addallfiles_proj
-- add all open files to the project
function Proj.add_all_files()
  if not Proj.check_is_open() then return end
  --put all buffer.filename in a list (ignore the project and special buffers)
  local flist= {}
  for _, b in ipairs(_BUFFERS) do
    local file= b.filename
    if file ~= nil and b._project_select == nil and b._type == nil then
      flist[ #flist+1 ]= file
    end
  end
  Proj.add_files(flist, false)
end

--ACTION: adddirfiles_proj
-- add files from a directory to the project
function Proj.add_dir_files(dir)
  if not Proj.check_is_open() then return end

  local defdir
  if #data.proj_files > 0 then
    defdir= data.proj_grp_path[1]
  end
  dir = dir or ui.dialogs.fileselect{
    title = 'Add all files from a Directory', select_only_directories = true,
    with_directory = defdir or (buffer.filename or ''):match('^.+[/\\]') or
                     lfs.currentdir()
  }
  if not dir then return end

  local flist= {}
  local extlist= {}
  local ext
  if Util.TA_MAYOR_VER < 11 then
    lfs.dir_foreach(dir, function(file)
      flist[ #flist+1 ]= file
      ext= file:match('[^%.\\/]+$')
      if ext then extlist[ext]= true end
      end, lfs.FILTER, nil, false)
  else
    for file in lfs.walk(dir, lfs.default_filter, nil, false) do
      flist[ #flist+1 ]= file
      ext= file:match('[^%.\\/]+$')
      if ext then extlist[ext]= true end
    end
  end
  if #flist > 0 then
    --choose extension to import
    local allext= ""
    for e,v in pairs(extlist) do
      if allext == "" then
        allext= e
      else
        allext= allext..","..e
      end
    end
    r,word= ui.dialogs.inputbox{title = 'Add files by extension', informative_text = 'Choose the extensions of the files to add (empty= all)', width = 400, text = allext}
    if type(word) == 'table' then
      word= table.concat(word, ',')
    end
    if word == "" then
      --all files / dirs
      Proj.add_files(flist, true) --sort and group files with the same path
    else
      --filtered by extensions
      extlist= {}
      for i in string.gmatch(word, "[^,]+") do
        extlist[i] = true
      end
      local flist2= {}
      for i,f in ipairs(flist) do
        ext= f:match('[^%.\\/]+$')
        if ext and extlist[ext] then
          flist2[#flist2+1]= f
        end
      end
      Proj.add_files(flist2, true) --sort and group files with the same path
    end
  end
end

--ACTION: open_selfile
function Proj.open_selfile()
  Proj.open_cursor_file()
end

--ACTION: first_buffer
function Proj.first_buffer()
  if toolbar then
    toolbar.sel_top_bar()
    toolbar.gototab(0)
  end
end

--ACTION: last_buffer
function Proj.last_buffer()
  if toolbar then
    toolbar.sel_top_bar()
    toolbar.gototab(2)
  end
end
