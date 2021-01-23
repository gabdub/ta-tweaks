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
  local openfolders= {}

  local browse_dir= _USERHOME

  --right-click context menu
  local filebrowser_context_menu = {
    {"open_filebrowser"}
  }

  local function clear_selected()
    if itselected then
      toolbar.selected(itselected,false,false)
      itselected= nil
    end
  end

  local function sel_brwfile(cmd) --click= select
    local linenum= toolbar.getnum_cmd(cmd)
    if linenum then
      clear_selected()
      itselected= cmd
      toolbar.selected(cmd,false,true)
      toolbar.ensurevisible(cmd)
    end
    return linenum
  end

  local function sel_brwfile_num(linenum)
    if not linenum then linenum=1 end
    if linenum > #flist then linenum=#flist end
    if linenum > 0 then sel_brwfile("brwfile#"..linenum) end
  end

  local function brwfile_rclick(cmd) --right click
    if sel_brwfile(cmd) then
      ui.toolbar_context_menu= create_uimenu_fromactions(filebrowser_context_menu)
      return true --open context menu
    end
  end

  local function brwfile_dclick(cmd) --double click
    local linenum= sel_brwfile(cmd)
    if linenum then
      local name= "exp-"..cmd
      local r= collarow[name]
      if r == nil then --open file
        Proj.go_file(flist[linenum])
      else --open/close folder
        if r then expand_list(name) else collapse_list(name) end
      end
    end
  end

  --ACTION: open selected project from the recent list
  local function act_open_filebrowser()
    brwfile_dclick(itselected)
  end

  actions.add("open_filebrowser", 'Open', act_open_filebrowser)
  local function list_clear()
    --remove all items
    toolbar.listright= toolbar.listwidth-3
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
    collarow= {}
  end

  function expand_list(cmd)
    sel_brwfile(cmd)
    toolbar.set_expand_icon(cmd,"list-colapse2")
    toolbar.cmds_n[cmd]= collapse_list
    toolbar.collapse(cmd, false)
    collarow[cmd]= false
    local id= toolbar.getnum_cmd(cmd)
    if id then
      local folder= flist[id]
      if folder then openfolders[folder]= true end
    end
  end

  function collapse_list(cmd)
    sel_brwfile(cmd)
    toolbar.set_expand_icon(cmd,"list-expand2")
    toolbar.cmds_n[cmd]= expand_list
    toolbar.collapse(cmd, true)
    collarow[cmd]= true
    local id= toolbar.getnum_cmd(cmd)
    if id then
      local folder= flist[id]
      if folder then openfolders[folder]= nil end
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
  end

  local function load_files()
    flist= {}
    --local extlist= {}
    --local ext

    if Util.TA_MAYOR_VER < 11 then
      lfs.dir_foreach(browse_dir, function(file)
        flist[ #flist+1 ]= file
        --ext= file:match('[^%.\\/]+$')
        --if ext then extlist[ext]= true end
        end, lfs.FILTER, nil, true)
    else
      for file in lfs.walk(browse_dir, lfs.default_filter, nil, true) do
        flist[ #flist+1 ]= file
        --ext= file:match('[^%.\\/]+$')
        --if ext then extlist[ext]= true end
      end
    end
    table.sort(flist, file_sort)
  end

  local function load_filebrowser()
    load_files()

    local linenum= toolbar.getnum_cmd(itselected)
    list_clear()
    toolbar.list_init_title() --add a resize handle
    toolbar.list_addbutton("view-refresh", "Reload", load_filebrowser)

    toolbar.list_addinfo('Files', true)

    local base_level= get_file_level(browse_dir) + 1
    toolbar.listtb_y= 3
    local w= toolbar.listwidth-13
    toolbar.sel_left_bar(itemsgrp)
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
        fname= Util.getfilename(fname,false)
        idlen= get_idlen_folder(i)
        if ind >= 12 then ind= ind -12 end
      end
      local name= "brwfile#"..i
      if toolbar.list_add_txt_ico(name, fname, flist[i], (bicon==nil), sel_brwfile, bicon, (i%2==1), ind, idlen, 2, w) then
        toolbar.list_add_collapse(name, collapse_list, ind, idlen, collarow)
        fold_row[#fold_row+1]= i --initially fold all folders
      end
    end
    for i= #fold_row, 1, -1 do
      local r= fold_row[i]
      if openfolders[flist[r]] == nil then collapse_list("exp-brwfile#"..r ) end
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
  end

  local function filebrowser_update_cb(reload)
    --LSTSEL_UPDATE_CB: update callback (parameter: reload == FALSE for VIEW/BUFFER_AFTER_SWITCH)
    if reload then
      load_filebrowser()
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

--  function toolbar.filebrowser_update() --reload list
--    if toolbar.islistshown("filebrowser") then load_filebrowser() end
--  end

  toolbar.registerlisttb("filebrowser", "File browser", "document-open", filebrowser_create_cb, filebrowser_update_cb, filebrowser_showlist_cb)
end
