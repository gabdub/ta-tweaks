-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

if toolbar then
  toolbar.listtb_hide_p= false

  local titgrp, itemsgrp, firsttag
  local function list_clear()
    --remove all items
    toolbar.tag_list= {}
    toolbar.tag_listedfile= ""
    toolbar.tag_list_find= ""
    toolbar.listtb_y= 1
    toolbar.listright= toolbar.listwidth
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
    toolbar.sel_left_bar(titgrp,true) --empty title group
    firsttag= nil
  end

  local function set_list_width()
    if not toolbar.listwidth then toolbar.listwidth=250 end
    if Proj and Proj.select_width then toolbar.listwidth= Proj.select_width end  --try to use the same width as the project
    if toolbar.listwidth < 100 then toolbar.listwidth=100 end
  end

  function toolbar.createlisttb()
    toolbar.sel_left_bar()
    set_list_width()
    --create a new empty toolbar
    toolbar.new(toolbar.listwidth, toolbar.cfg.butsize, toolbar.cfg.imgsize, toolbar.LEFT_TOOLBAR, toolbar.themepath)
    --add/change some images
    toolbar.themed_icon(toolbar.globalicon, "cfg-back", toolbar.TTBI_TB.BACKGROUND)
    toolbar.themed_icon(toolbar.globalicon, "ttb-button-hilight", toolbar.TTBI_TB.BUT_HILIGHT)
    toolbar.themed_icon(toolbar.globalicon, "ttb-button-press", toolbar.TTBI_TB.BUT_HIPRESSED)
    toolbar.themed_icon(toolbar.globalicon, "group-vscroll-back", toolbar.TTBI_TB.VERTSCR_BACK)
    toolbar.themed_icon(toolbar.globalicon, "group-vscroll-bar", toolbar.TTBI_TB.VERTSCR_NORM)
    toolbar.themed_icon(toolbar.globalicon, "group-vscroll-bar-hilight", toolbar.TTBI_TB.VERTSCR_HILIGHT)
    --title group: fixed width=300 / align top + fixed height
    titgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.FIRST, 0, toolbar.cfg.barsize)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)
    --items group: fixed width=300 / height=use buttons + vertical scroll
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0) --show v-scroll when needed
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)

    list_clear()
    if actions then
      toolbar.idviewlisttb= actions.add("toggle_viewctaglist", 'Show _Ctag List', toolbar.list_toolbar_onoff, "sf10", "t_struct", function()
        return (toolbar.list_tb and 1 or 2) end) --check
      local med= actions.getmenu_fromtitle(_L['_View'])
      if med then
        local m=med[#med]
        m[#m+1]= "toggle_viewctaglist"
      end
      actions.add("filter_ctaglist", 'Filter Ctag _List', toolbar.list_find_sym, "cf10", "edit-find")
    end
    toolbar.list_tb= false --hide for now...
    toolbar.show(false, toolbar.listwidth)

    toolbar.sel_top_bar()
  end

  local function list_addbutton(name, tooltip, funct)
    toolbar.listright= toolbar.listright - toolbar.cfg.butsize
    toolbar.gotopos( toolbar.listright, toolbar.listtb_y)
    toolbar.cmd(name, funct, tooltip or "", name, true)
  end

  local function list_addaction(action)
    toolbar.listright= toolbar.listright - toolbar.cfg.butsize
    toolbar.gotopos( toolbar.listright, toolbar.listtb_y)
    toolbar.addaction(action)
  end

  local function list_addinfo(text,bold)
    --add a text to the list
    toolbar.gotopos( 3, toolbar.listtb_y)
    toolbar.addlabel(text, "", toolbar.listright, true, bold)
    toolbar.listtb_y= toolbar.listtb_y + toolbar.cfg.butsize
    toolbar.listright= toolbar.listwidth
  end

  local function gototag(cmd)
    Proj.getout_projview()
    local linenum= tonumber(string.match(cmd,".-#(.*)"))
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
      list_addinfo('No CTAGS found in this file')
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
          toolbar.cmd(gt, gototag, "", bicon, true)
          toolbar.gotopos( toolbar.cfg.barsize, y)
          toolbar.addtext(gt, name, "")
          toolbar.cmds_n[gt]= gototag
          y= y + toolbar.cfg.butsize
          if not firsttag then firsttag= gt end
          n= n+1
        end
      end
      toolbar.listtb_y= y
      if n == 0 then list_addinfo('No CTAGS match the filter') end
    end
  end

  local function load_ctags()
    --ignore project views
    if Proj and (buffer._project_select or buffer._type == Proj.PRJT_SEARCH) then return end
    list_clear()
    list_addbutton("window-close", "Close list [Shift+F10]", toolbar.list_toolbar_onoff)
    local bname= buffer.filename
    if bname == nil then
      list_addinfo('No filename')
      return
    end
    if Proj == nil then
      list_addinfo('The project module is not installed')
      return
    end
    local p_buffer = Proj.get_projectbuffer(true)
    if p_buffer == nil then
      list_addinfo('No open project')
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
      list_addinfo('No CTAGS files found in project')
      return
    end
    toolbar.tag_listedfile= bname
    local fname= bname:match('[^/\\]+$') -- filename only
    list_addbutton("view-refresh", "Reload list", toolbar.list_toolbar_reload)
    list_addaction("filter_ctaglist")
    list_addinfo(fname, true)
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

  function toolbar.list_toolbar_update()
    if toolbar.list_tb then load_ctags() end
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

  function toolbar.list_toolbar_onoff()
    --if the current view is a project view, goto left/only files view. if not, keep the current view
    if toolbar.list_tb == true then
      toolbar.list_tb= false
    else
      toolbar.list_tb= true
    end
    if Proj then
      Proj.getout_projview()
      local washidebylist= toolbar.listtb_hide_p
      toolbar.listtb_hide_p= false
      if toolbar.get_check_val("tblist_hideprj") then
        if Proj.isin_editmode() then Proj.show_hide_projview() end --end edit mode
        if (Proj.is_visible > 0) and toolbar.list_tb then
          toolbar.listtb_hide_p= true
          Proj.show_hide_projview()
        elseif washidebylist and (Proj.is_visible == 0) and (not toolbar.list_tb) then
          Proj.show_hide_projview()
        end
      end
    end
    set_list_width()
    toolbar.sel_left_bar()
    toolbar.list_toolbar_update()
    toolbar.show(toolbar.list_tb, toolbar.listwidth)
    --check menuitem
    if toolbar.idviewlisttb then actions.setmenustatus(toolbar.idviewlisttb, (toolbar.list_tb and 1 or 2)) end
    if toolbar then toolbar.setcfg_from_buff_checks() end --update config panel
    if actions then
      actions.updateaction("toggle_viewctaglist")
      toolbar.selected("toggle_viewctaglist", false, toolbar.list_tb)
    end
  end

  local function list_update() --update only when the file change
    if toolbar.list_tb and (toolbar.tag_listedfile ~= buffer.filename) then load_ctags() end
  end
  events.connect(events.BUFFER_AFTER_SWITCH,  list_update)
  events.connect(events.VIEW_AFTER_SWITCH,    list_update)
  events.connect(events.BUFFER_NEW,           toolbar.list_toolbar_update)
  events.connect(events.FILE_OPENED,          toolbar.list_toolbar_update)
  events.connect(events.FILE_CHANGED,         toolbar.list_toolbar_update)
  events.connect(events.FILE_AFTER_SAVE,      toolbar.list_toolbar_update)
end
