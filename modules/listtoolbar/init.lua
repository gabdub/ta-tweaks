-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

if toolbar then
  local events, events_connect = events, events.connect
  local selectgrp, currlist, currlistidx

  toolbar.listtb_hide_p= false
  toolbar.listselections= {}

  local function listtb_switch()
    --{name, tooltip, icon, createfun, notify, show}
    if toolbar.list_tb and currlistidx > 0 then toolbar.listselections[currlistidx][5](true) end
  end

  local function listtb_update()
    if toolbar.list_tb and currlistidx > 0 then toolbar.listselections[currlistidx][5](false) end
  end

  events_connect(events.BUFFER_AFTER_SWITCH,  listtb_switch)
  events_connect(events.VIEW_AFTER_SWITCH,    listtb_switch)
  events_connect(events.BUFFER_NEW,           listtb_update)
  events_connect(events.FILE_OPENED,          listtb_update)
  events_connect(events.FILE_CHANGED,         listtb_update)
  events_connect(events.FILE_AFTER_SAVE,      listtb_update)

  local function set_list_width()
    if not toolbar.listwidth then toolbar.listwidth=250 end
    if Proj and Proj.select_width then toolbar.listwidth= Proj.select_width end  --try to use the same width as the project
    if toolbar.listwidth < 100 then toolbar.listwidth=100 end
  end

  function toolbar.list_addbutton(name, tooltip, funct)
    toolbar.listright= toolbar.listright - toolbar.cfg.butsize
    toolbar.gotopos( toolbar.listright, toolbar.listtb_y)
    toolbar.cmd(name, funct, tooltip or "", name, true)
  end

  function toolbar.list_addaction(action)
    toolbar.listright= toolbar.listright - toolbar.cfg.butsize
    toolbar.gotopos( toolbar.listright, toolbar.listtb_y)
    toolbar.addaction(action)
  end

  function toolbar.list_addinfo(text,bold)
    --add a text to the list
    toolbar.gotopos( 3, toolbar.listtb_y)
    toolbar.addlabel(text, "", toolbar.listright, true, bold)
    toolbar.listtb_y= toolbar.listtb_y + toolbar.cfg.butsize
    toolbar.listright= toolbar.listwidth
  end

  function toolbar.select_list(listname, donthide)
    if listname == currlist then
      --click on the active list= hide toolbar
      if not donthide then toolbar.list_toolbar_onoff() end
    else
      --change the active list
      toolbar.selected(currlist, false, false)
      if currlistidx > 0 then toolbar.listselections[currlistidx][6](false) end --hide list items
      for i=1,#toolbar.listselections do
        if toolbar.listselections[i][1] == listname then
          currlist= listname
          currlistidx= i
          break
        end
      end
      toolbar.selected(currlist, false, true)
      if currlistidx > 0 then toolbar.listselections[currlistidx][6](true) end --show list items
      listtb_update()
    end
  end

  function toolbar.islistshown(name)
    return (toolbar.list_tb) and (currlist==name)
  end

  function toolbar.registerlisttb(name, tooltip, icon, createfun, notify, showlist)
    toolbar.listselections[#toolbar.listselections+1]= {name, tooltip, icon, createfun, notify, showlist}
  end

  function toolbar.createlisttb()
    currlist=""
    currlistidx=0
    toolbar.sel_left_bar()
    set_list_width()
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

    --list select group: fixed width=300 / align top + fixed height
    selectgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.FIRST, 0, toolbar.cfg.barsize)

    local x= 3
    if #toolbar.listselections > 0 then
      for i=1,#toolbar.listselections do
        local ls= toolbar.listselections[i] --{name, tooltip, icon, createfun, notify, show}
        ls[4]() --create list

        toolbar.sel_left_bar(selectgrp)
        toolbar.gotopos(x, 1)
        toolbar.cmd(ls[1], toolbar.select_list, ls[2], ls[3], true)
        x= x + toolbar.cfg.butsize
      end
      currlistidx=1
      currlist= toolbar.listselections[currlistidx][1] --activate the first one
      toolbar.selected(currlist, false, true)
    end
    --toolbar.gotopos(x, 1)
    --toolbar.cmd("window-close", toolbar.list_toolbar_onoff, "Close list [Shift+F10]", "window-close", true)

    if actions then
      toolbar.idviewlisttb= actions.add("toggle_viewlist", 'Show _List toolbar', toolbar.list_toolbar_onoff, "sf10", "document-properties", function()
        return (toolbar.list_tb and 1 or 2) end) --check
      local med= actions.getmenu_fromtitle(_L['_View'])
      if med then
        local m=med[#med]
        m[#m+1]= "toggle_viewlist"
      end
    end
    toolbar.list_tb= false --hide for now...
    toolbar.show(false, toolbar.listwidth)

    toolbar.sel_top_bar()
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
    listtb_update()

    toolbar.show(toolbar.list_tb, toolbar.listwidth)
    --check menuitem
    if toolbar.idviewlisttb then actions.setmenustatus(toolbar.idviewlisttb, (toolbar.list_tb and 1 or 2)) end
    if toolbar then toolbar.setcfg_from_buff_checks() end --update config panel
    if actions then
      actions.updateaction("toggle_viewlist")
      toolbar.selected("toggle_viewlist", false, toolbar.list_tb)
    end
  end

end
