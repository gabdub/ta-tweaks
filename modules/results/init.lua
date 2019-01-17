-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.

if toolbar then
  local events, events_connect = events, events.connect
  local titgrp, curresult, curresultidx
  local lbl_n= 0

  toolbar.resultsselect= {}
  toolbar.resultsheight= 200

  local function results_update(switching)
    --{name, tooltip, icon, createfun, **notify**, show}
    if toolbar.results_tb and curresultidx > 0 then toolbar.resultsselect[curresultidx][5](switching or false) end
  end

  function toolbar.select_results(listname, dont_hide_show)
    if listname == curresult then
      --click on the active list= show/hide toolbar
      if not dont_hide_show then toolbar.results_onoff() end
    else
      if (not dont_hide_show) and (not toolbar.results_tb) then toolbar.results_onoff() end  --show toolbar
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
        results_update()
      end
    end
  end

  function toolbar.next_results_list()
    local n=curresultidx
    if toolbar.results_tb then
      if n < #toolbar.resultsselect then n=n+1 else n=1 end
    end
    toolbar.select_results(toolbar.resultsselect[n][1])
  end

  function toolbar.prev_results_list()
    local n=curresultidx
    if toolbar.results_tb then
      if n > 1 then n=n-1 else n=#toolbar.resultsselect end
    end
    toolbar.select_results(toolbar.resultsselect[n][1])
  end

  function toolbar.isresultsshown(name)
    return (toolbar.results_tb) and (curresult==name)
  end

  function toolbar.registerresultstb(name, tooltip, icon, createfun, notify, showlist)
    toolbar.resultsselect[#toolbar.resultsselect+1]= {name, tooltip, icon, createfun, notify, showlist}
  end

  --the toolbar config is saved inside the project configuration file
  local function beforeload_res(cfg)
    Util.add_config_field(cfg, "results_height", Util.cfg_int, 200)
    Util.add_config_field(cfg, "results_show",   Util.cfg_bool, true)
  end

  local function afterload_res(cfg)
    --show list toolbar
    toolbar.sel_results_bar()
    toolbar.results_tb= cfg.results_show
    toolbar.resultsheight= cfg.results_height
    --select first result option
    if #toolbar.resultsselect > 0 then toolbar.select_results(toolbar.resultsselect[1][1]) end
    toolbar.show(toolbar.results_tb, toolbar.resultsheight)
  end

  local function beforesave_res(cfg)
    local changed= false
    if cfg.results_show  ~= toolbar.results_tb     then cfg.results_show=toolbar.results_tb      changed=true end
    if cfg.results_height ~= toolbar.resultsheight then cfg.results_height=toolbar.resultsheight changed=true end
    return changed
  end

  local function projloaded_res(cfg)
    --the project file parsing is complete
    if curresultidx > 0 then
      toolbar.selected(curresult, false, toolbar.results_tb)
      toolbar.resultsselect[curresultidx][6](true) --show list
      results_update()
    end
    if #toolbar.resultsselect == 0 then
      toolbar.results_init_title()
      toolbar.list_addinfo("No results module found",true)
    end
  end

  Proj.add_config_hook(beforeload_res, afterload_res, beforesave_res, projloaded_res)

  function toolbar.createresultstb()
    curresult=""
    curresultidx=0

    toolbar.sel_results_bar()
    --create a new empty toolbar
    toolbar.new(toolbar.resultsheight, toolbar.cfg.butsize, toolbar.cfg.imgsize, toolbar.RESULTS_TOOLBAR, toolbar.themepath)
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

    toolbar.show(false, toolbar.resultsheight)  --hide until the project config is loaded

    for i=1,#toolbar.resultsselect do
      local ls= toolbar.resultsselect[i] --{name, tooltip, icon, createfun, notify, show}
      ls[4]() --create list
    end

    toolbar.sel_top_bar() --restore current bar
--    toolbar.sel_top_bar() --add buttons to select the lists in the top toolbar
--    if #toolbar.resultsselect > 0 then
--      for i=1,#toolbar.resultsselect do
--        local ls= toolbar.resultsselect[i] --{name, tooltip, icon, createfun, notify, show}
--        toolbar.cmd(ls[1], toolbar.select_results, ls[2], ls[3], true)
--      end
--      toolbar.addspace()
--    end

    if actions then
      toolbar.idviewresultstb= actions.add("toggle_viewresults", 'Show _Results toolbar', toolbar.results_onoff, nil, "view-list-compact-symbolic", function()
        return (toolbar.results_tb and 1 or 2) end) --check
      local med= actions.getmenu_fromtitle(_L['_View'])
      if med then
        local m=med[#med]
        m[#m+1]= "toggle_viewresults"
      end
      actions.add("next_results_list", 'Next results list',     toolbar.next_results_list)
      actions.add("prev_results_list", 'Previous results list', toolbar.prev_results_list)
    end
  end

  local function new_tb_size() --the toolbar was resized
    toolbar.resultsheight= toolbar.getsize(toolbar.RESULTS_TOOLBAR)
  end

  function toolbar.results_init_title()
    toolbar.listtb_y= 1
    toolbar.listtb_x= 3
    toolbar.list_cmdright= 18
    toolbar.sel_results_bar(titgrp,true) --empty title group
    toolbar.top_right_resize_handle("resizeResult", 50, new_tb_size) --add a resize handle
    toolbar.gotopos( 0, toolbar.listtb_y)
    toolbar.cmd("results-close", toolbar.results_onoff, "Close", "window-close")
    toolbar.listtb_x= 23
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
end
