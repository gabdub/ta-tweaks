-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.

if toolbar then
  local events, events_connect = events, events.connect
  local titgrp, currlist, currlistidx
  local listtb_hide_p= false --hide project

  toolbar.listselections= {}
  toolbar.listwidth= 250

  local LSTSEL_NAME=      1  --list name
  local LSTSEL_TOOLTIP=   2  --list tooltip
  local LSTSEL_ICON=      3  --list icon
  local LSTSEL_CREATE_CB= 4  --create callback
  local LSTSEL_UPDATE_CB= 5  --update callback (parameter: reload == FALSE for VIEW/BUFFER_AFTER_SWITCH)
  local LSTSEL_SHOW_CB=   6  --the list has been shown/hidden (parameter: show)

  function toolbar.registerlisttb(name, tooltip, icon, createfun_cb, notify_cb, showlist_cb)
    toolbar.listselections[#toolbar.listselections+1]= {name, tooltip, icon, createfun_cb, notify_cb, showlist_cb}
  end

  local function listtb_update(reload)
    --notify the list is shown (parameter: reload == FALSE for VIEW/BUFFER_AFTER_SWITCH)
    if toolbar.list_tb and currlistidx > 0 then toolbar.listselections[currlistidx][LSTSEL_UPDATE_CB](reload or false) end
  end

  local function reload_list()
    listtb_update(true) --reload the list
  end

  events_connect(events.BUFFER_AFTER_SWITCH,  listtb_update)  --no need to reload the list
  events_connect(events.VIEW_AFTER_SWITCH,    listtb_update)  --no need to reload the list
  events_connect(events.BUFFER_NEW,           reload_list)    --reload the list
  events_connect(events.FILE_OPENED,          reload_list)    --reload the list
  events_connect(events.FILE_CHANGED,         reload_list)    --reload the list
  events_connect(events.FILE_AFTER_SAVE,      reload_list)    --reload the list

  function toolbar.select_list(listname, dont_hide_show)
    if listname == currlist then
      --click on the active list= show/hide toolbar
      if not dont_hide_show then toolbar.list_toolbar_onoff() end
    else
      if (not dont_hide_show) and (not toolbar.list_tb) then toolbar.list_toolbar_onoff() end  --show toolbar
      --change the active list
      if currlistidx > 0 then
        toolbar.selected(currlist, false, false)
        toolbar.listselections[currlistidx][LSTSEL_SHOW_CB](false) --hide
      end
      for i=1,#toolbar.listselections do
        if toolbar.listselections[i][LSTSEL_NAME] == listname then
          currlist= listname
          currlistidx= i
          break
        end
      end
      if currlistidx > 0 then
        toolbar.selected(currlist, false, toolbar.list_tb)
        toolbar.listselections[currlistidx][LSTSEL_SHOW_CB](true) --show
        reload_list() --reload the list
      end
    end
  end

  function toolbar.next_list()
    local n=currlistidx
    if toolbar.list_tb then
      if n < #toolbar.listselections then n=n+1 else n=1 end
    end
    toolbar.select_list(toolbar.listselections[n][LSTSEL_NAME])
  end

  function toolbar.prev_list()
    local n=currlistidx
    if toolbar.list_tb then
      if n > 1 then n=n-1 else n=#toolbar.listselections end
    end
    toolbar.select_list(toolbar.listselections[n][LSTSEL_NAME])
  end

  function toolbar.islistshown(name)
    return (toolbar.list_tb) and (currlist==name)
  end

  --the toolbar config is saved inside the project configuration file
  local function beforeload_ltb(cfg)
    --CFGHOOK_BEFORE_LOAD: add hooked fields to config
    Util.add_config_field(cfg, "lst_width", Util.cfg_int, 250)
    Util.add_config_field(cfg, "lst_show",  Util.cfg_bool, true)
    Util.add_config_field(cfg, "open_proj", Util.cfg_str, "")
  end

  local function afterload_ltb(cfg)
    --CFGHOOK_CONFIG_LOADED: notify config loaded
    --show list toolbar
    toolbar.sel_left_bar()
    toolbar.list_tb= cfg.lst_show
    toolbar.listwidth= cfg.lst_width
    --start in "recent projects list" or "project list" if the project is open
    toolbar.select_list((cfg.open_proj ~= "") and "projlist" or "recentprojlist", true)
    toolbar.show(toolbar.list_tb, toolbar.listwidth)
  end

  local function beforesave_ltb(cfg)
    --CFGHOOK_BEFORE_SAVE: get hooked fields value
    local changed= false
    if cfg.lst_show  ~= toolbar.list_tb    then cfg.lst_show=toolbar.list_tb     changed=true end
    if cfg.lst_width ~= toolbar.listwidth  then cfg.lst_width=toolbar.listwidth  changed=true end
    if cfg.open_proj ~= Proj.data.filename then cfg.open_proj=Proj.data.filename changed=true end
    return changed
  end

  local function projloaded_ltb(cfg)
    --CFGHOOK_PROJ_LOADED: the project parsing is complete
    if cfg.open_proj ~= "" then toolbar.select_list("projlist", true) end
    if currlistidx > 0 then
      toolbar.selected(currlist, false, toolbar.list_tb)
      toolbar.listselections[currlistidx][LSTSEL_SHOW_CB](true) --show
      reload_list() --reload the list
    end
    if #toolbar.listselections == 0 then
      toolbar.list_init_title()
      toolbar.list_addinfo("No list module found",true)
    end
  end

  Proj.add_config_hook(beforeload_ltb, afterload_ltb, beforesave_ltb, projloaded_ltb)

  function toolbar.createlisttb()
    currlist=""
    currlistidx=0

    toolbar.sel_left_bar()
    --create a new empty toolbar
    toolbar.new(toolbar.listwidth, toolbar.cfg.butsize, toolbar.cfg.imgsize, toolbar.LEFT_TOOLBAR, toolbar.themepath)
    --add/change some images
    toolbar.themed_icon(toolbar.globalicon, "cfg-back", toolbar.TTBI_TB.BACKGROUND)
    toolbar.themed_icon(toolbar.globalicon, "ttb-button-hilight", toolbar.TTBI_TB.BUT_HILIGHT)
    toolbar.themed_icon(toolbar.globalicon, "ttb-button-press", toolbar.TTBI_TB.BUT_HIPRESSED)
    toolbar.themed_icon(toolbar.globalicon, "ttb-button-active", toolbar.TTBI_TB.BUT_SELECTED)
    toolbar.themed_icon(toolbar.globalicon, "group-vscroll-back", toolbar.TTBI_TB.VERTSCR_BACK)
    toolbar.themed_icon(toolbar.globalicon, "group-vscroll-bar", toolbar.TTBI_TB.VERTSCR_NORM)
    toolbar.themed_icon(toolbar.globalicon, "group-vscroll-bar-hilight", toolbar.TTBI_TB.VERTSCR_HILIGHT)
    toolbar.themed_icon(toolbar.globalicon, "cfg-separator-h", toolbar.TTBI_TB.HSEPARATOR)

    --title group: align top + fixed height
    titgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize, false)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)

    toolbar.show(false, toolbar.listwidth)  --hide until the project config is loaded

    --create lists
    for i=1,#toolbar.listselections do toolbar.listselections[i][LSTSEL_CREATE_CB]() end

    toolbar.sel_top_bar() --add buttons to select the lists in the top toolbar
    if #toolbar.listselections > 0 then
      for i=1,#toolbar.listselections do
        local ls= toolbar.listselections[i]
        toolbar.cmd(ls[LSTSEL_NAME], toolbar.select_list, ls[LSTSEL_TOOLTIP], ls[LSTSEL_ICON], true)
      end
      toolbar.addspace()
    end

    if actions then
      toolbar.idviewlisttb= actions.add("toggle_viewlist", 'Show _List toolbar', toolbar.list_toolbar_onoff, "cf6", "view-list-compact-symbolic", function()
        return (toolbar.list_tb and 1 or 2) end) --check
      local med= actions.getmenu_fromtitle(Util.VIEWMENU_TEXT)
      if med then
        local m=med[#med]
        m[#m+1]= "toggle_viewlist"
      end
      actions.add("next_list", 'Next list',     toolbar.next_list, "f6")
      actions.add("prev_list", 'Previous list', toolbar.prev_list, "sf6")
    end
  end

  local function new_tb_size() --the toolbar was resized
    local w= toolbar.getsize(toolbar.LEFT_TOOLBAR)
    toolbar.listwidth= w
    Proj.select_width= w
    Proj.data.recent_prj_change= true --save it on exit
  end

  function toolbar.list_init_title()
    toolbar.listtb_y= 1
    toolbar.listtb_x= 3
    toolbar.list_cmdright= 18
    toolbar.sel_left_bar(titgrp,true) --empty title group
    toolbar.top_right_resize_handle("resizeList", 150, new_tb_size) --add a resize handle
  end

  function toolbar.list_toolbar_onoff()
    if toolbar.list_tb == true then
      toolbar.list_tb= false
    else
      toolbar.list_tb= true
    end

    if Proj then
      Proj.getout_projview()
      local washidebylist= listtb_hide_p
      listtb_hide_p= false
      if toolbar.get_check_val("tblist_hideprj") then
        if Proj.isin_editmode() then Proj.show_hide_projview() end --end edit mode
        if (Proj.is_visible > 0) and toolbar.list_tb then
          listtb_hide_p= true
          Proj.show_hide_projview()
        elseif washidebylist and (Proj.is_visible == 0) and (not toolbar.list_tb) then
          Proj.show_hide_projview()
        end
      end
    end
    toolbar.sel_left_bar()
    reload_list() --reload the list

    toolbar.show(toolbar.list_tb, toolbar.listwidth)
    --check menuitem
    if toolbar.idviewlisttb then actions.setmenustatus(toolbar.idviewlisttb, (toolbar.list_tb and 1 or 2)) end
    if toolbar then toolbar.setcfg_from_buff_checks() end --update config panel
    if actions then
      actions.updateaction("toggle_viewlist")
      toolbar.selected("toggle_viewlist", false, toolbar.list_tb)
    end
    --only show as selected when the list is visible
    toolbar.selected(currlist, false, toolbar.list_tb)
  end
end
