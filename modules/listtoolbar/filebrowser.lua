-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
--
-- This module add a recent project list to the "lists" toolbar
--
-- ** This module is used when USE_LISTS_PANEL is true **
--
if toolbar then
  local itemsgrp, itselected
  local flist= {}
  local openfs= {}
  local collarow= {}
  local collalen= {}
  local openfolders= {}
  local rowfolders= {}

  local browse_dir= _USERHOME

  --right-click context menu
  local filebrowser_context_menu = {
    {"open_filebrowser", SEPARATOR, "browse_folder", SEPARATOR, "browse_up_folder"}
  }
  local nofile_filebrowser_cmenu = {
    {"browse_up_folder"}
  }

  local function clear_selected()
    if itselected then
      toolbar.selected(itselected,false,false)
      itselected= nil
    end
  end

  local function sel_brwfile(cmd) --click= select
    local linenum= toolbar.getnum_cmd(cmd)
    if linenum and linenum > 0 then
      expand_brw_parents(cmd)
      clear_selected()
      itselected= "brwfile#"..linenum
      toolbar.selected(itselected,false,true)
      toolbar.ensurevisible(itselected)
      return linenum
    end
    return nil
  end

  local function sel_brwfile_num(linenum)
    if not linenum then linenum=1 end
    if linenum > #flist then linenum=#flist end
    if linenum > 0 then sel_brwfile("brwfile#"..linenum) end
  end

  local function brwfile_rclick(cmd) --right click
    if sel_brwfile(cmd) then
      ui.toolbar_context_menu= create_uimenu_fromactions(filebrowser_context_menu)
    else
      ui.toolbar_context_menu= create_uimenu_fromactions(nofile_filebrowser_cmenu)
    end
    return true --open context menu
  end

  local function nofile_rclick(cmd) --right click
    ui.toolbar_context_menu= create_uimenu_fromactions(nofile_filebrowser_cmenu)
    return true --open context menu
  end

  local function brwfile_dclick(cmd) --double click
    local linenum= sel_brwfile(cmd)
    if linenum then
      local name= "exp-"..cmd
      local r= collarow[name]
      if r == nil then --open file
        if rowfolders[linenum] then
          add_filesfromfolder(flist[linenum])
          expand_brw_list(name)
        else
          Proj.go_file(flist[linenum])
        end
      else --open/close folder
        if r then expand_brw_list(name) else collapse_brw_list(name) end
      end
    end
  end

  --ACTION: open selected file/folder
  local function act_open_filebrowser()
    brwfile_dclick(itselected)
  end
  actions.add("open_filebrowser", 'Open', act_open_filebrowser)

  --ACTION: browse from the selected file/folder
  local function act_browse_folder()
    local linenum= sel_brwfile(itselected)
    if linenum then
      local fname= flist[linenum]
      browse_dir= Util.remove_pathsep_end(fname)
      if browse_dir == fname then
        local pa,fa,ea = Util.splitfilename(fname)
        if pa ~= "/" then browse_dir=Util.remove_pathsep_end(pa) else browse_dir=pa end
      end
      load_filebrowser()
    end
  end

  actions.add("browse_folder", 'Browse this folder', act_browse_folder)

  --ACTION: browse one folder up
  local function act_browse_up_folder()
    if browse_dir ~= "/" then
      openfolders[ browse_dir .. Util.PATH_SEP ]= true
      local pa,fa,ea = Util.splitfilename(browse_dir)
      if pa ~= "/" then browse_dir=Util.remove_pathsep_end(pa) else browse_dir=pa end
      brw_reload_all() --keep open folders
    end
  end
  local function browse_up_folder_status()
    return (browse_dir == "/") and 8 or 0 --0=normal 8=disabled
  end
  actions.add("browse_up_folder", 'Browse one folder up', act_browse_up_folder, nil, "go-up", browse_up_folder_status)

  local function list_clear()
    --remove all items
    toolbar.listright= toolbar.listwidth-3
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
    collarow= {}
    collalen= {}
    rowfolders= {}
  end

  function expand_brw_list(cmd)
    sel_brwfile(cmd)
    toolbar.set_expand_icon(cmd,"list-colapse2")
    toolbar.cmds_n[cmd]= collapse_brw_list
    toolbar.collapse(cmd, false)
    collarow[cmd]= false
    local id= toolbar.getnum_cmd(cmd)
    if id then
      local folder= flist[id]
      if folder then openfolders[folder]= true end
    end
  end

  function collapse_brw_list(cmd)
    sel_brwfile(cmd)
    toolbar.set_expand_icon(cmd,"list-expand2")
    toolbar.cmds_n[cmd]= expand_brw_list
    toolbar.collapse(cmd, true)
    collarow[cmd]= true
    local id= toolbar.getnum_cmd(cmd)
    if id then
      local folder= flist[id]
      if folder then openfolders[folder]= nil end
    end
  end

  function expand_brw_parents(cmd)
    local id= toolbar.getnum_cmd(cmd)
    if id and id > 1 then
      for i=1, id-1 do
        if collalen[i] and i+collalen[i] >= id then --expand all parents
          local ecmd= "exp-brwfile#"..i
          if collarow[ecmd] then expand_brw_list(ecmd) end
        end
      end
    end
  end

  local function file_sort(filea,fileb)
    local pa,fa,ea = Util.splitfilename(filea)
    local pb,fb,eb = Util.splitfilename(fileb)
    if pa == pb then return fa < fb end
    return pa < pb
  end

  local function get_file_level(fname)
    local _, ind= string.gsub(fname,'[/\\]',"")
    return ind or 0
  end

  local function get_idlen_folder(i)
    local basefolder= flist[i]
    local n= 0
    for j=i+1,#flist do
      if not Util.str_starts(flist[j], basefolder) then break end
      n= n+1
    end
    return n
  end

  --return the file position (ROW: 1..) in the list
  local function get_brwfile_row(file)
    if #flist > 0 and file then
      for row=1, #flist do
        if file == flist[row] then return row end
      end
    end
    return nil --not found
  end

  local function track_file() --select the current buffer in the list
    local file= buffer.filename
    if file ~= nil then
      local row= get_brwfile_row(file)
      if row then sel_brwfile_num(row) end
    end
  end

  local function mark_open_files()
    for k,v in pairs(openfs) do openfs[k]= false end
    for _, b in ipairs(_BUFFERS) do
      if b._project_select == nil and b._type == nil then
        local file= b.filename
        if file then
          local row= get_brwfile_row(file)
          if row then
            local name= "open-brwfile#"..row
            if not openfs[name] then toolbar.setthemeicon(name,"open-back") end
            openfs[name]= true
          end
        end
      end
    end
    for k,v in pairs(openfs) do
      if not v then
        toolbar.setthemeicon(k,"closed-back")
        openfs[k]= nil
      end
    end

    toolbar.enable("brw-proj", Proj and Proj.data.is_open) --enable browse project base folder
  end

  local function load_files(brwdir, brwlevel)
    local flistsz= #flist
    if Util.TA_MAYOR_VER < 11 then
      lfs.dir_foreach(brwdir, function(file)
        flist[ #flist+1 ]= file
        end, lfs.FILTER, brwlevel, true)
    else
      for file in lfs.walk(brwdir, lfs.default_filter, brwlevel, true) do
        flist[ #flist+1 ]= file
      end
    end
    if flistsz < #flist then  --some files were added
      table.sort(flist, file_sort)
      return true
    end
    return false
  end

  local function brw_userhome()
    browse_dir= _USERHOME
    load_filebrowser()
  end

  local function brw_projfolder()
    if Proj and Proj.data.is_open then
      browse_dir= Util.remove_pathsep_end( Proj.data.proj_grp_path[1] )
      load_filebrowser()
    end
  end

  local function brw_folder()
    local folder = ui.dialogs.fileselect{ title = 'Select folder', select_only_directories = true, with_directory = browse_dir }
    if folder then
      browse_dir= folder
      load_filebrowser()
    end
  end

  function add_filesfromfolder(folder)
    if load_files(folder, 0) then load_brw_tree() else ui.statusbar_text= "folder "..folder.." is empty" end
  end

  function load_filebrowser()
    flist= {}
    openfolders= {}
    load_files(browse_dir, 0)
    load_brw_tree()
  end

  function brw_reload_all()
    flist= {}
    load_files(browse_dir, 0)
    for folder,_ in pairs(openfolders) do
      load_files(folder, 0)
    end
    load_brw_tree()
  end

  function load_brw_tree()
    local linenum= toolbar.getnum_cmd(itselected)
    list_clear()
    toolbar.list_init_title() --add a resize handle
    toolbar.list_addbutton("brw-refresh", "Reload", brw_reload_all, "view-refresh")
    toolbar.list_addbutton("brw-folder", "Change folder", brw_folder, "document-open")
    toolbar.list_addbutton("brw-proj", "Project base folder", brw_projfolder, "document-properties")
    toolbar.list_addbutton("brw-home", "User home", brw_userhome, "go-home")

    local base_level= 1
    if browse_dir == "/" then
      toolbar.list_addinfo(browse_dir, true)
    else
      toolbar.list_addinfo(Util.getfilename(browse_dir,true), true)
      base_level= get_file_level(browse_dir) + 1
    end

    toolbar.listtb_y= 3
    local w= toolbar.listwidth-13
    toolbar.sel_left_bar(itemsgrp)
    if #flist == 0 then
      toolbar.list_add_txt_ico("brwfile#0", "The folder is empty", browse_dir, false, nil, "gtk-no", false, 0, 0, 0, w)
      return
    end

    local fold_row= {}
    for i=1, #flist do
      local fname= Util.getfilename(flist[i],true)
      local bicon
      local idlen= 0
      local ind= (get_file_level(flist[i]) - base_level) * 12
      if fname ~= "" then --file
        bicon= toolbar.icon_fname(flist[i])
      else  --folder
        fname= Util.remove_pathsep_end( flist[i] ) --remove "\" or "/" from the end
        fname= Util.getfilename(fname,true)
        idlen= get_idlen_folder(i)
        if ind >= 12 then ind= ind -12 end
        rowfolders[i]= true
      end
      local name= "brwfile#"..i
      if toolbar.list_add_txt_ico(name, fname, flist[i], (bicon==nil), sel_brwfile, bicon, (i%2==1), ind, idlen, 2, w) then
        toolbar.list_add_collapse(name, collapse_brw_list, ind, idlen, collarow)
        fold_row[#fold_row+1]= i --initially fold all folders
      end
      collalen[i]= idlen
    end
    for i= #fold_row, 1, -1 do
      local r= fold_row[i]
      if openfolders[flist[r]] == nil then collapse_brw_list("exp-brwfile#"..r ) end
    end
    sel_brwfile_num(linenum)
    track_file()
    mark_open_files()
  end

  local function filebrowser_create_cb()
    --LSTSEL_CREATE_CB: create callback
    --items group: fixed width=300 / height=use buttons + vertical scroll
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.setdefaulttextfont()

    list_clear()
    toolbar.cmd_rclick("brwfile",brwfile_rclick)
    toolbar.cmd_dclick("brwfile",brwfile_dclick)
    toolbar.cmd_rclick("GROUP"..itemsgrp.."-"..toolbar.LEFT_TOOLBAR, nofile_rclick)  --on itemsgroup
    toolbar.cmd_rclick("TOOLBAR"..toolbar.LEFT_TOOLBAR, nofile_rclick)  --on the toolbar (outside any group)
  end

  local loaded= false

  local function filebrowser_update_cb(reload)
    --LSTSEL_UPDATE_CB: update callback (parameter: reload == FALSE for VIEW/BUFFER_AFTER_SWITCH)
    if not loaded then
      loaded= true
      load_filebrowser()  --load only once
    elseif reload then
      load_brw_tree()
    else
      track_file()
      mark_open_files()
    end
  end

  local function filebrowser_showlist_cb(show)
    --LSTSEL_SHOW_CB: the list has been shown/hidden (parameter: show)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  toolbar.registerlisttb("filebrowser", "File browser", "document-open", filebrowser_create_cb, filebrowser_update_cb, filebrowser_showlist_cb)
end
