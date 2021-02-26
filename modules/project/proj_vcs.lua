-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
---- PROJECT VERSION CONTROL ----
local Proj = Proj
local Util = Util
local data = Proj.data
local last_open_idx= 1

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

local function conv_num(num, txt)
  return ""..num.." "..txt..(num > 1 and "s" or "")
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

local function b_gitstatus(bname, chkflist)
  run_gitcmd("git status -sb")  --Show git status
end

local function b_gitpullorg(bname, chkflist)
  if Util.confirm( "GIT PULL", "Do you want to PULL the current branch ("..gitbranch.. ") from the 'origin' repository?" ) then
    run_gitcmd("git pull origin "..gitbranch)  --Pull current branch from origin
  end
  Proj.reopen_vcs_control_panel() --reopen dialog
end

local function b_gitpushorg(bname, chkflist)
  if Util.confirm( "GIT PUSH", "Do you want to PUSH the current branch ("..gitbranch.. ") to the 'origin' repository?" ) then
    run_gitcmd("git push origin "..gitbranch)  --Push current branch to origin
  end
  Proj.reopen_vcs_control_panel() --reopen dialog
end

local function b_gitcommit(bname, chkflist)
  --Commit changes to the repository
  if Util.confirm( "GIT COMMIT", "Do you want to commit the added changes?" ) then
    local ok= false
    local r,msg= ui.dialogs.inputbox{title = 'Commit message', width = 400, text = ""}
    if r == 1 then
      if type(msg) == 'table' then
        msg= table.concat(msg, ' ')
      end
      msg= Util.str_trim(msg)
      if msg ~= "" then
        msg= string.gsub(msg, '\"', "\'") --use single quotes
        run_gitcmd('git commit -m \"' ..msg..'\"')
        ok= true
        b_gitpushorg(bname, chkflist) --OK: ask to push
        return
      end
    end
    if not ok then
      ui.print("Commit cancelled!")
    end
  end
  Proj.reopen_vcs_control_panel() --reopen dialog
end

local function b_gitadd(bname, chkflist)
  --Add files to index
  if Util.confirm( "GIT ADD", "Do you want to add ".. conv_num(#chkflist, "file") .. " to the repository index?" ) then
    for i=1, #chkflist do
      run_gitcmd("git add ".. chkflist[i][1])  --add one file at the time
    end
    b_gitcommit(bname, chkflist)  --OK: ask to commit
  else
    Proj.reopen_vcs_control_panel() --reopen dialog
  end
end

local function b_svninfo(bname, chkflist)
  run_gitcmd("svn info")  --Show svn info
end


local function b_update(bname, chkflist)
  --Copy changes (O/D) to the destination folder (only checked items)
  local numO= 0
  local numD= 0
  local fnames= ""
  for i=1, #chkflist do
    local le= chkflist[i][2]
    if le == "O" then numO= numO+1 end
    if le == "D" then numD= numD+1 end
    if (le == "O" or le == "D") and (#fnames < 300) then
      fnames= fnames..(#fnames == 0 and "" or "\n")..chkflist[i][1]
      if #fnames >= 300 then fnames= fnames.."\n..." end
    end
  end
  local txt
  if numO == 0 then
    if numD == 0 then Util.info("Nothing to update", "No files marked as 'O' or 'D' found") return end
    txt= conv_num(numD, "new file")
  else
    txt= conv_num(numO, "modified file")
    if numD > 0 then
      txt= txt.." and "..conv_num(numD, "new file")
    end
  end
  if Util.confirm("Update local folder", "Copy "..txt.." to "..vcs_item_base.. " ?", fnames) then
    local numok= 0
    for i=1, #chkflist do
      local le= chkflist[i][2]
      if le == "O" or le == "D" then
        local fname= chkflist[i][1]
        if Util.copy_file(publish_folder..fname, vcs_item_base..fname) then numok= numok+1 end --ORG => DEST
      end
    end
    if numok == (numO+numD) then
      Util.info("Update local folder", conv_num(numok, "file").." copied successfully")
    else
      Util.info("Update local folder", "Warning:\nOnly "..numok.." of the "..conv_num(numO+numD, "file").." were copied successfully")
    end
  end
  Proj.reopen_vcs_control_panel() --reopen dialog
end

local function b_publish(bname, chkflist)
  --Copy changes (M/A) to the destination folder (only checked items)
  local numM= 0
  local numA= 0
  local fnames= ""
  for i=1, #chkflist do
    local le= chkflist[i][2]
    if le == "M" then numM= numM+1 end
    if le == "A" then numA= numA+1 end
    if (le == "M" or le == "A") and (#fnames < 300) then
      fnames= fnames..(#fnames == 0 and "" or "\n")..chkflist[i][1]
      if #fnames >= 300 then fnames= fnames.."\n..." end
    end
  end
  local txt
  if numM == 0 then
    if numA == 0 then Util.info("Nothing to publish", "No files marked as 'M' or 'A' found") return end
    txt= conv_num(numA, "new file")
  else
    txt= conv_num(numM, "modified file")
    if numA > 0 then
      txt= txt.." and "..conv_num(numA, "new file")
    end
  end
  if Util.confirm("Publish to folder", "Copy "..txt.." to "..publish_folder.. " ?", fnames) then
    local numok= 0
    for i=1, #chkflist do
      local le= chkflist[i][2]
      if le == "M" or le == "A" then
        local fname= chkflist[i][1]
        if Util.copy_file( vcs_item_base..fname,  publish_folder..fname) then numok= numok+1 end --ORG => DEST
      end
    end
    if numok == (numM+numA) then
      ui.statusbar_text= conv_num(numok, "file").." copied successfully"
    else
      Util.info("Publish to folder", "Warning:\nOnly "..numok.." of the "..conv_num(numM+numA, "file").." were copied successfully")
    end
  end
  Proj.reopen_vcs_control_panel() --reopen dialog
end

local function set_show_all_tit()
  toolbar.settext("dlg-show-all", toolbar.dlg_filter_col2 and "Only changed" or "Show all", "Show all/changed files", false)
end

local status_info= ""

local function b_status_info(bname, chkflist)
  ui.print(status_info)
end

local function b_show_all(bname, chkflist)
  --toggle show all/changed files
  toolbar.selected("dlg-show-all", false, toolbar.dlg_filter_col2)
  toolbar.dlg_filter_col2= not toolbar.dlg_filter_col2
  set_show_all_tit()
end

local function cond_enable_button(buttons, bname, cond)
  if not cond then
    for i=1, #buttons do
      local bt= buttons[i] --1:bname, 2:text/icon, 3:tooltip, 4:x, 5:width, 6:row, 7:callback, 8:button-flags=toolbar.DLGBUT...
      if bt[1] == bname then
        bt[8]= bt[8] | toolbar.DLGBUT.EN_OFF
        break
      end
    end
  end
end

local function remove_trailing_(txt)
  while #txt > 0 do
    local lastch= string.sub(txt,-1) --remove "_" from the end
    if lastch ~= "_" then break end
    txt= string.sub(txt,1,string.len(txt)-1)
  end
  return txt
end

function Proj.open_vcs_dialog(row)
  --open a dialog with the project files that are in this VCS item folder/subfolders
  Proj.vcs_control_panel(Proj.get_vcs_index(row))
end

function Proj.reopen_vcs_control_panel()
  if last_open_idx < 1 or last_open_idx > #data.proj_vcontrol then
    last_open_idx= 1
  end
  Proj.vcs_control_panel(last_open_idx)
end

function Proj.open_next_vcs_control_panel()
  last_open_idx= last_open_idx+1
  Proj.reopen_vcs_control_panel()
end

function Proj.vcs_control_panel(idx)
  last_open_idx= idx
  if idx and idx > 0 and idx <= #data.proj_vcontrol then
    local vctrl= data.proj_vcontrol[idx] --{path, param, vc_type, row}
    local vctype= vctrl[3]
    local vc_item_name= data.proj_rowinfo[vctrl[4]][1]
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
      if vctype == Proj.VCS_GIT then
        status_info= "GIT status options XY (X=index Y=working tree):\nM = modified\nA = added\nD = deleted\nR = renamed\nC = copied\nU = updated but unmerged\n? = untracked\n! = ignored"
--GIT 2 letters status XY (X=index Y=working tree)
--X          Y     Meaning
------------------------------------------------
--         [AMD]   not updated
--M        [ MD]   updated in index
--A        [ MD]   added to index
--D                deleted from index
--R        [ MD]   renamed in index
--C        [ MD]   copied in index
--[MARC]           index and work tree matches
--[ MARC]     M    work tree changed since index
--[ MARC]     D    deleted in work tree
--[ D]        R    renamed in work tree
--[ D]        C    copied in work tree
--D           D    unmerged, both deleted
--A           U    unmerged, added by us
--U           D    unmerged, deleted by them
--U           A    unmerged, added by them
--D           U    unmerged, deleted by us
--A           A    unmerged, both added
--U           U    unmerged, both modified
--?           ?    untracked
--!           !    ignored
------------------------------------------------
      else
        status_info= "SVN status options (1234567):\n1) ITEM: A = added, D = deleted, M =  modified, R = replaced\nC = conflict, X=external definition, I = ignored\n? = not in VC, ! = missing, ~ = different kind\n"..
        "2) PROPERTIES: M = modified, C = conflict\n"..
        "3) L = the working copy is LOCKED\n4) + = HISTORY scheduled\n5) S = parent switched\n6) K/O/T/B = file locked\n7) C = TREE CONFLICT"
------------------------------------------------
--1) The first column indicates that an item was added, deleted, or otherwise changed:
-- ' ' No modifications.
-- 'A' Item is scheduled for addition.
-- 'D' Item is scheduled for deletion.
-- 'M' Item has been modified.
-- 'R' Item has been replaced in your working copy. This means the file was scheduled for deletion, and then a new file with the same name was scheduled for addition in its place.
-- 'C' The contents (as opposed to the properties) of the item conflict with updates received from the repository.
-- 'X' Item is present because of an externals definition.
-- 'I' Item is being ignored (e.g., with the svn:ignore property).
-- '?' Item is not under version control.
-- '!' Item is missing (e.g., you moved or deleted it without using svn). This also indicates that a directory is incomplete (a checkout or update was interrupted).
-- '~' Item is versioned as one kind of object (file, directory, link), but has been replaced by a different kind of object.
--2) The second column tells the status of a file's or directory's properties:
-- ' ' No modifications.
-- 'M' Properties for this item have been modified.
-- 'C' Properties for this item are in conflict with property updates received from the repository.
--3) The third column is populated only if the working copy directory is locked (see the section called “Sometimes You Just Need to Clean Up”):
-- ' ' Item is not locked.
-- 'L' Item is locked.
--4) The fourth column is populated only if the item is scheduled for addition-with-history:
-- ' ' No history scheduled with commit.
-- '+' History scheduled with commit.
--5) The fifth column is populated only if the item is switched relative to its parent (see the section called “Traversing Branches”):
-- ' ' Item is a child of its parent directory.
-- 'S' Item is switched.
--6) The sixth column is populated with lock information:
-- ' ' When --show-updates (-u) is used, this means the file is not locked. If --show-updates (-u) is not used, this merely means that the file is not locked in this working copy.
-- 'K' File is locked in this working copy.
-- 'O' File is locked either by another user or in another working copy. This appears only when --show-updates (-u) is used.
-- 'T' File was locked in this working copy, but the lock has been “stolen” and is invalid. The file is currently locked in the repository. This appears only when --show-updates (-u) is used.
-- 'B' File was locked in this working copy, but the lock has been “broken” and is invalid. The file is no longer locked. This appears only when --show-updates (-u) is used.
--7) The seventh column is populated only if the item is the victim of a tree conflict:
-- ' ' Item is not the victim of a tree conflict.
-- 'C' Item is the victim of a tree conflict.
------------------------------------------------
      end
      repo_changes= {}
      local stcmd= (vctype == Proj.VCS_GIT) and "git status -sb" or "svn status -q"
      if cwd == nil or cwd == "" then
        if vctype == Proj.VCS_SVN then cwd= vcs_item_base end
      end
      repo_folder= cwd
      local rstat= string.gsub(Proj.get_cmd_output(stcmd, repo_folder, ""), '%\\', '/')
      --GIT uses a 2 letter status / SVN uses a 7 letter status
      local pattern= (vctype == Proj.VCS_GIT) and "(..)%s(.*)" or "(.......)%s(.*)"
      local readbranch= (vctype == Proj.VCS_GIT)
      for line in rstat:gmatch('[^\n]+') do
        if readbranch then
          readbranch= false
          gitbranch= string.match(line, '##%s*(.*)')
        else
          --split "status filename"
          --lett= 2 letters status XY (X=index Y=working tree)
          local lett, fn= string.match(line, pattern)
          if lett ~= nil and fn ~= nil then
            lett= remove_trailing_(string.gsub(lett, ' ', '_')) --make ' ' explicit + remove trailing "_"..
            repo_changes[ Util.str_trim(fn) ]= lett
          end
        end
      end

    elseif vctype == Proj.VCS_FOLDER then
      publish_folder= pref or "" --a folder is required
      status_info= "FOLDER status options:\nM = MODIFIED, NEWER local file\nO = modified, OLDER local file\nA = local file ADDED\nD = local file DELETED"
    end

    flist= {}
    local dconfig= {}
    local enupd= false
    local enpub= false
    dconfig.can_move= true  --allow to move
    dconfig.columns= {500, 50, 50} --icon+filename | status-letter | checkbox
    if #data.proj_vcontrol > 1 then dconfig.next_button_cb= Proj.open_next_vcs_control_panel end
    local buttons= {
      --1:bname, 2:text/icon, 3:tooltip, 4:x, 5:width, 6:row, 7:callback, 8:button-flags=toolbar.DLGBUT...
      {"dlg-show-all", "All", "Show all/changed files", 500, 95, 1, b_show_all, toolbar.DLGBUT.RELOAD},
      {"dlg-status-info", "help-about", status_info, 500, 0, 2, b_status_info, toolbar.DLGBUT.ICON},
      {"dlg-mark-all", "package-install", "Mark/unmark all", 550, 0, 2, toolbar.dialog_tog_check_all, toolbar.DLGBUT.ICON|toolbar.DLGBUT.EN_ITEMS}
    }
    if vctype == Proj.VCS_FOLDER then
      buttons[#buttons+1]= {"dlg-update", "Update", "Update local folder, get newer files (O/D)", 200, 95, 1, b_update, toolbar.DLGBUT.EN_MARK|toolbar.DLGBUT.CLOSE}
      buttons[#buttons+1]= {"dlg-publish", "Publish", "Copy changes (M/A) to the destination folder", 300, 95, 1, b_publish, toolbar.DLGBUT.EN_MARK|toolbar.DLGBUT.CLOSE}
      buttons[#buttons+1]= {"dlg-lbl-files", "Files", "Files", 4, 95, 2, nil, toolbar.DLGBUT.EN_OFF|toolbar.DLGBUT.LEFT|toolbar.DLGBUT.BOLD}

    elseif vctype == Proj.VCS_GIT then
      local ena= (gitbranch ~= "") and 0 or toolbar.DLGBUT.EN_OFF
      buttons[#buttons+1]= {"dlg-lbl-branch", "Branch:", "Git branch", 4, 0, 1, nil, toolbar.DLGBUT.EN_OFF}
      buttons[#buttons+1]= {"dlg-branch", gitbranch, "Show git status", 55, 0, 1, b_gitstatus, ena}

      buttons[#buttons+1]= {"dlg-git-pull", "Pull origin", "Pull current branch from origin", 4, 105, 2, b_gitpullorg, ena}

      buttons[#buttons+1]= {"dlg-git-add", "Add", "Add files to index", 190, 95, 2, b_gitadd, ena|toolbar.DLGBUT.EN_MARK|toolbar.DLGBUT.CLOSE}
      buttons[#buttons+1]= {"dlg-git-commit", "Commit", "Commit changes to the repository", 290, 95, 2, b_gitcommit, ena|toolbar.DLGBUT.CLOSE}
      buttons[#buttons+1]= {"dlg-git-push", "Push origin", "Push current branch to origin\n=Requires stored credentials=", 390, 95, 2, b_gitpushorg, ena}

    elseif vctype == Proj.VCS_SVN then
      local ena= (repo_folder ~= "") and 0 or toolbar.DLGBUT.EN_OFF
      buttons[#buttons+1]= {"dlg-svn-info", "Info", "Show svn info", 4, 95, 1, b_svninfo, ena}
    end
    dconfig.buttons= buttons
    toolbar.dlg_filter_col2= false --show all items
    for row= 1, #data.proj_files do
      if data.proj_filestype[row] == Proj.PRJF_FILE then --ignore CTAGS files / path / empty rows
        local projfile= string.gsub(data.proj_files[row], '%\\', '/')
        local fname= string.match(projfile, fmt)
        if fname and fname ~= '' then
          local col2= get_vcs_file_status(projfile, fname, vctrl)
          flist[ #flist+1 ]= {fname, col2, false}
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
    cond_enable_button(buttons, "dlg-update",  enupd and (publish_folder ~= ""))
    cond_enable_button(buttons, "dlg-publish", enpub and (publish_folder ~= ""))
    --show folder files
    toolbar.dlg_select_it=""
    toolbar.dlg_select_ev= vcs_item_selected
    toolbar.create_dialog(Proj.VCS_LIST[vctrl[3]]..": "..vctrl[1], 600, 400, flist, "MIME", dconfig)
    toolbar.selected("dlg-show-all", false, not toolbar.dlg_filter_col2)
    set_show_all_tit()
    toolbar.show_dialog()
    if toolbar.dlg_filter_col2 then toolbar.dialog_tog_check_all() end --mark all
  end
end

--ACTION: vc_controlpanel
--Version control control panel
function Proj.vc_controlpanel_status()
  local ena= 8 --disable
  if data.is_open and data.proj_vcontrol and #data.proj_vcontrol > 0 then ena=0 end
  return ena
end
