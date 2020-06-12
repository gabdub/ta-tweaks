-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
--
-- This module control the "results" toolbar
--
-- ** This module is used when USE_RESULTS_PANEL is true **
-- The SEARCH RESULTS INTERFACE is accessed through the "plugs" object
--
if toolbar then
  local events, events_connect = events, events.connect
  local titgrp, curresult, curresultidx
  local lblResult

  toolbar.resultsselect= {}
  toolbar.resultsheight= 200

  function toolbar.registerresultstb(name, tooltip, icon, createfun, notify, showlist, resaction)
    toolbar.resultsselect[#toolbar.resultsselect+1]= {name, tooltip, icon, createfun, notify, showlist, resaction}
  end

  local function results_update(switching)
    --{name, tooltip, icon, createfun, **notify**, show}
    if toolbar.results_tb and curresultidx > 0 then toolbar.resultsselect[curresultidx][5](switching or false) end
  end

  local function select_results(listname)
    if (not toolbar.results_tb) then toolbar.results_onoff() end  --show toolbar
    if listname ~= curresult then
      --change the active list
      if curresultidx > 0 then
        toolbar.selected(curresult, false, false)
        toolbar.resultsselect[curresultidx][6](false) --hide list items
      end
      for i=1,#toolbar.resultsselect do
        if toolbar.resultsselect[i][1] == listname then
          curresult= listname
          curresultidx= i
          break
        end
      end
      if curresultidx > 0 then
        toolbar.selected(curresult, false, toolbar.results_tb)
        toolbar.resultsselect[curresultidx][6](true) --show list items
        if lblResult then toolbar.settext(lblResult, toolbar.resultsselect[curresultidx][2]) end
        results_update()
      end
    end
  end

  function toolbar.next_results_list()
    local n=curresultidx
    if toolbar.results_tb then
      if n < #toolbar.resultsselect then n=n+1 else n=1 end
    end
    select_results(toolbar.resultsselect[n][1])
  end

  function toolbar.prev_results_list()
    local n=curresultidx
    if toolbar.results_tb then
      if n > 1 then n=n-1 else n=#toolbar.resultsselect end
    end
    select_results(toolbar.resultsselect[n][1])
  end

  function toolbar.isresultsshown(name)
    return (toolbar.results_tb) and (curresult==name)
  end

  function toolbar.showresults(name)
    if not toolbar.isresultsshown(name) then select_results(name) end
  end

  --the toolbar config is saved inside the project configuration file
  local function beforeload_res(cfg)
    Util.add_config_field(cfg, "results_height", Util.cfg_int, 200)
    Util.add_config_field(cfg, "results_show",   Util.cfg_bool, true)
  end

  local function afterload_res(cfg)
    toolbar.resultsheight= cfg.results_height
    toolbar.sel_results_bar()
    --select first result option
    if #toolbar.resultsselect > 0 then select_results(toolbar.resultsselect[1][1]) end
    toolbar.results_tb= cfg.results_show
    toolbar.show(toolbar.results_tb, toolbar.resultsheight)
  end

  local function beforesave_res(cfg)
    local changed= false
    if cfg.results_show  ~= toolbar.results_tb     then cfg.results_show=toolbar.results_tb      changed=true end
    if cfg.results_height ~= toolbar.resultsheight then cfg.results_height=toolbar.resultsheight changed=true end
    return changed
  end

  local function results_act(name)  --pass the pressed button name
    if curresultidx > 0 then toolbar.resultsselect[curresultidx][7](name) end
  end

  local function new_tb_size() --the toolbar was resized
    toolbar.resultsheight= toolbar.getsize(toolbar.RESULTS_TOOLBAR)
  end

  function toolbar.results_init_title(show_but)
    toolbar.listtb_y= 1
    toolbar.listtb_x= 3
    toolbar.list_cmdright= 24
    toolbar.sel_results_bar(titgrp,true) --empty title group
    toolbar.top_right_resize_handle("resizeResult", 50, new_tb_size) --add a resize handle
    toolbar.list_addbutton("window-close", "Close", toolbar.results_onoff)
    if show_but then
      toolbar.list_addbutton("edit-clear", "Clear all", results_act)
      toolbar.list_addbutton("edit-select-all", "Copy all", results_act)
      toolbar.list_addbutton("edit-copy", "Copy", results_act)
    end
  end

  local function projloaded_res(cfg)
    --the project file parsing is complete
    if curresultidx > 0 then
      toolbar.selected(curresult, false, toolbar.results_tb)
      toolbar.resultsselect[curresultidx][6](true) --show list
      results_update()
    end
    if #toolbar.resultsselect == 0 then
      toolbar.results_init_title(false) --only resize and close buttons
      toolbar.list_addinfo("No results module found",true)
    end
  end

  Proj.add_config_hook(beforeload_res, afterload_res, beforesave_res, projloaded_res)

  function toolbar.createresultstb()
    curresult=""
    curresultidx=0
    lblResult=nil

    toolbar.sel_results_bar()
    --create a new empty toolbar
    toolbar.new(toolbar.resultsheight, toolbar.cfg.butsize, toolbar.cfg.imgsize, toolbar.RESULTS_TOOLBAR, toolbar.themepath)
    --add/change some images
    toolbar.themed_icon(toolbar.globalicon, "res-back", toolbar.TTBI_TB.BACKGROUND)
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

    toolbar.show(false, toolbar.resultsheight)  --hide until the project config is loaded

    for i=1,#toolbar.resultsselect do
      local ls= toolbar.resultsselect[i] --{name, tooltip, icon, createfun, notify, show}
      ls[4]() --create list
    end

    --add buttons to select the lists
    if #toolbar.resultsselect > 0 then
      toolbar.results_init_title(true) --show all buttons

      for i=1,#toolbar.resultsselect do
        local ls= toolbar.resultsselect[i] --{name, tooltip, icon, createfun, notify, show}
        toolbar.gotopos( toolbar.listtb_x, toolbar.listtb_y)
        toolbar.listtb_x=toolbar.listtb_x+toolbar.cfg.butsize
        toolbar.cmd(ls[1], select_results, ls[2], ls[3], true)
      end
      toolbar.listtb_x=toolbar.listtb_x+toolbar.cfg.butsize/2
      lblResult= toolbar.list_addinfo("Results",true)
    end
    toolbar.sel_top_bar() --restore current bar

    if actions then
      toolbar.idviewresultstb= actions.add("toggle_viewresults", 'Show _Results toolbar', toolbar.results_onoff, "cf10", "view-list-compact-symbolic", function()
        return (toolbar.results_tb and 1 or 2) end) --check
      local med= actions.getmenu_fromtitle(Util.VIEWMENU_TEXT)
      if med then
        local m=med[#med]
        m[#m+1]= "toggle_viewresults"
      end
      actions.add("next_results_list", 'Next results list',     toolbar.next_results_list, "sf10")
      actions.add("prev_results_list", 'Previous results list', toolbar.prev_results_list, "csf10")
    end
  end

  function toolbar.results_onoff()
    if toolbar.results_tb == true then
      toolbar.results_tb= false
    else
      toolbar.results_tb= true
    end

    toolbar.sel_results_bar()
    results_update()

    toolbar.show(toolbar.results_tb, toolbar.resultsheight)
    --check menuitem
    if toolbar.idviewresultstb then actions.setmenustatus(toolbar.idviewresultstb, (toolbar.results_tb and 1 or 2)) end
    if toolbar then toolbar.setcfg_from_buff_checks() end --update config panel
    if actions then
      actions.updateaction("toggle_viewresults")
      toolbar.selected("toggle_viewresults", false, toolbar.results_tb)
    end
    --only show as selected when the list is visible
    toolbar.selected(curresult, false, toolbar.results_tb)
  end

  --------------- RESULTS INTERFACE --------------
  function plugs.init_searchview()
    --check if a search results buffer is open (not used with panels)
  end

  function plugs.goto_searchview()
    return false --activate/create search view (not used with panels)
  end

  function plugs.close_results(viewclosed)
    --viewclosed= true (the right view was closed, don't close, results are in a toolbar not in a buffer)
    if not viewclosed and toolbar.results_tb then toolbar.results_onoff() return true end
    return false --already closed
  end

  function plugs.clear_results()
    toolbar.results_clear()
    toolbar.print_clear()
  end
  -------------------------------------------------------

end
