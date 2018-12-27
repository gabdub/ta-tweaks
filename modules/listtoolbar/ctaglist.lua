-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

if toolbar then
  local titgrp, itemsgrp, firsttag

  local function list_clear()
    --remove all items
    toolbar.tag_list= {}
    toolbar.tag_listedfile= ""
    toolbar.tag_list_find= ""
    toolbar.listright= toolbar.listwidth-3
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
    toolbar.sel_left_bar(titgrp,true) --empty title group
    firsttag= nil
  end

  local function ctags_create()
    --title group: fixed width=300 / align top + fixed height
    titgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize, true)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)
    --items group: fixed width=300 / height=use buttons + vertical scroll
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)

    list_clear()

    if actions then actions.add("filter_ctaglist", 'Filter Ctag _List', toolbar.list_find_sym, "cf10", "edit-find") end
  end

  local function gototag(cmd)
    Proj.getout_projview()
    local linenum= toolbar.getnum_cmd(cmd)
    Util.goto_line(buffer, linenum-1)
    buffer:vertical_centre_caret()
  end

  local function list_addtag(name, line, ext_fields)
    --add an item to the list
    local bicon= "t_var"
    local extra
    if ext_fields:find('.-\t.+') then ext_fields,extra=ext_fields:match('(.-)\t(.+)') end
    if extra and extra:find('.-\t.+') then extra=extra:match('(.-)\t.+') end
    if ext_fields == "f" then name= name.." ( )" bicon="t_func"
    elseif ext_fields == "d" then bicon="t_def"
    elseif ext_fields == "t" then bicon="t_type"
    elseif ext_fields == "s" then name= "struct "..name bicon="t_struct"
    elseif ext_fields == "m" and extra then name= extra.."."..name bicon="t_struct" end

    local gt= "gotag"..#toolbar.tag_list.."#"..line
    toolbar.tag_list[#toolbar.tag_list+1]= {gt, name, bicon}
  end

  local function filter_ctags()
    --show the tags that pass the filter
    firsttag= nil
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
    toolbar.listtb_y= 3
    if #toolbar.tag_list == 0 then
      toolbar.list_addinfo('No CTAG entry found in this file')
    else
      local filter= Util.escape_filter(toolbar.tag_list_find)
      local y= 3
      local n=0
      for i=1,#toolbar.tag_list do
        local name=  toolbar.tag_list[i][2]
        if filter == '' or name:match(filter) then
          local gt= toolbar.tag_list[i][1]
          local bicon= toolbar.tag_list[i][3]
          toolbar.gotopos( 3, y)
          toolbar.addtext(gt, name, "", toolbar.listwidth-13, false, true, false, toolbar.cfg.barsize, 0)
          toolbar.gotopos( 3, y)
          local icbut= "ico-"..gt
          toolbar.cmd(icbut, gototag, "", bicon, true)
          toolbar.enable(icbut,false,false) --non-selectable image
          toolbar.cmds_n[gt]= gototag
          y= y + toolbar.cfg.butsize-2
          if not firsttag then firsttag= gt end
          n= n+1
        end
      end
      if n == 0 then toolbar.list_addinfo('No CTAG entry match the filter') end
    end
  end

  local function load_ctags()
    --ignore project views
    if Proj and (buffer._project_select or buffer._type == Proj.PRJT_SEARCH) then return end
    list_clear()
    --title group
    toolbar.listtb_y= 1
    local bname= buffer.filename
    if bname == nil then
      toolbar.list_addinfo('No filename')
      return
    end
    if Proj == nil then
      toolbar.list_addinfo('The project module is not installed')
      return
    end
    local p_buffer = Proj.get_projectbuffer(true)
    if p_buffer == nil then
      toolbar.list_addinfo('No open project')
      return
    end
    local tag_files = {}
    if p_buffer.proj_files ~= nil then
      for row= 1, #p_buffer.proj_files do
        local ftype= p_buffer.proj_filestype[row]
        if ftype == Proj.PRJF_CTAG then
          tag_files[ #tag_files+1 ]= p_buffer.proj_files[row]
        end
      end
    end
    if #tag_files < 1 then
      toolbar.list_addinfo('No CTAG file found in the project')
      return
    end
    toolbar.tag_listedfile= bname
    local fname= bname:match('[^/\\]+$') -- filename only
    toolbar.list_addbutton("view-refresh", "Update Ctag List", toolbar.list_toolbar_reload)
    toolbar.list_addaction("filter_ctaglist")
    toolbar.list_addinfo(fname, true)
    for i = 1, #tag_files do
      local dir = tag_files[i]:match('^.+[/\\]')
      local f = io.open(tag_files[i])
      for line in f:lines() do
        local tag, file, linenum, ext_fields = line:match('^([_.%w]-)\t(.-)\t(.-);"\t?(.*)$')
        if tag and (file == bname) then --only show current file
          if not file:find('^%a?:?[/\\]') then file = dir..file end
          if linenum:find('^/') then linenum = linenum:match('^/^(.+)$/$') end
          if linenum then list_addtag(tag, linenum, ext_fields) end
        end
      end
      f:close()
    end
    filter_ctags()
  end

  function toolbar.list_find_sym()
    if not toolbar.list_tb then toolbar.list_toolbar_onoff() end
    toolbar.select_list("ctaglist",true) --activate this list
    local orgfind = toolbar.tag_list_find
    local word = ''
    r,word= ui.dialogs.inputbox{title = 'Tag search', width = 400, text = toolbar.tag_list_find}
    toolbar.tag_list_find= ''
    if r == 1 then toolbar.tag_list_find= word end
    if orgfind ~= toolbar.tag_list_find then --filter changed: update
      filter_ctags()
      if firsttag and toolbar.tag_list_find ~= '' then gototag(firsttag) end
    end
  end

  function toolbar.list_toolbar_reload()
    if toolbar.list_tb then
      local cmd
      --locate project RUN command that updates TAGS (ctags)
      if Proj then
        local p_buffer = Proj.get_projectbuffer(false)
        if p_buffer and p_buffer.proj_filestype then
          for r=1, #p_buffer.proj_filestype do
            if p_buffer.proj_filestype[r] == Proj.PRJF_RUN then
              if p_buffer.proj_files[r]:match('ctags') then
                cmd= p_buffer.proj_files[r]
                break
              end
            end
          end
        end
      end
      if cmd then Proj.run_command(cmd) else load_ctags() end
    end
  end

  local function ctags_notify(switching)
    --when switching buffers/view: update only if the current buffer filename change
    if (not switch) or (toolbar.tag_listedfile ~= buffer.filename) then load_ctags() end
  end

  local function ctags_showlist(show)
    --show/hide list items
    toolbar.sel_left_bar(titgrp)
    toolbar.showgroup(show)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  function toolbar.ctaglist_update() --the CTAG file was regenerated
    if toolbar.islistshown("ctaglist") then load_ctags() end
  end

  toolbar.registerlisttb("ctaglist", "Ctag List", "t_struct", ctags_create, ctags_notify, ctags_showlist)
end
