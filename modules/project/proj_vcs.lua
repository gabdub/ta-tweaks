-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
---- PROJECT VERSION CONTROL ----
local Proj = Proj
local Util = Util
local data = Proj.data

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

function debug_cmd(cmd, cwd) --run a command from the "Command entry"
  --e.g.: debug_cmd("git status -sb", "C:\\Users\\gabriel\\.textadept\\ta-tweaks\\")
  return Proj.get_cmd_output(cmd, cwd, "")
end

function Proj.get_vc_param_newproj(rootdir, path)
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
  return vc_param
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

    local vctype= vctrl[3]
    if vctype == Proj.VCS_GIT or vctype == Proj.VCS_SVN then --check parsed "git/svn status"
      if not pref then pref= "" end
      local file2= pref..fname
      return repo_changes[file2] or ""
    end
    if vctype == Proj.VCS_FOLDER then
      if not pref then pref= param end
      local file2= pref..fname
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
local repo_folder= ""

local function run_gitcmd(cmd)
  --print git status
  if repo_folder ~= "" then ui.print(Proj.get_cmd_output(cmd, repo_folder, repo_folder.."> "..cmd.."\n")) end
end

local function b_gitstatus(bname)
  run_gitcmd("git status -sb")
end

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
    repo_folder= ""
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
      repo_folder= cwd
      local rstat= string.gsub(Proj.get_cmd_output(stcmd, repo_folder, ""), '%\\', '/')
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
    dconfig.can_move= true  --allow to move
    dconfig.columns= {550, 50} --icon+filename | status-letter
    local buttons= {
      --1:bname, 2:text, 3:tooltip, 4:x, 5:width, 6:row, 7:callback, 8:button-flags=toolbar.DLGBUT...
      {"dlg-update", "Update", "Update local folder, get newer files (O/D)", 300, 95, 1, b_update, toolbar.DLGBUT.CLOSE},
      {"dlg-publish", "Publish", "Copy changes (M/A) to the destination folder", 400, 95, 1, b_publish, toolbar.DLGBUT.CLOSE},
      {"dlg-show-all", "Show All", "Show all/changed files", 500, 95, 1, b_show_all, toolbar.DLGBUT.RELOAD}
    }
    if gitbranch ~= "" then
      buttons[#buttons+1]= {"dlg-branch", gitbranch, "Git branch", 4, 0, 1, nil, toolbar.DLGBUT.CLOSE|toolbar.DLGBUT.BOLD}
      buttons[#buttons+1]= {"dlg-status", "Status", "Show git status", 200, 95, 1, b_gitstatus, toolbar.DLGBUT.CLOSE}
    end
    dconfig.buttons= buttons
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
    toolbar.create_dialog(Proj.VCS_LIST[vctrl[3]]..": "..vctrl[1], 600, 400, flist, "MIME", dconfig)
    toolbar.selected("dlg-show-all", false, not toolbar.dlg_filter_col2)
    toolbar.enable("dlg-update",  enupd and (publish_folder ~= ""))
    toolbar.enable("dlg-publish", enpub and (publish_folder ~= ""))
    toolbar.enable("dlg-branch", false)
    toolbar.show_dialog()
  end
end
