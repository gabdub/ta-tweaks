-- Copyright 2016-2022 Gabriel Dubatti. See LICENSE.
--
-- This module add a recent project list to the "lists" toolbar
--
-- ** This module is used when USE_LISTS_PANEL is true **
--
if toolbar then
  local itemsgrp, itselected

  --right-click context menu
  local recentproj_context_menu = {
    {"open_recentproj",SEPARATOR,"del_recentproj"}
  }

  local function clear_selected()
    if itselected then
      toolbar.selected(itselected,false,false)
      itselected= nil
    end
  end

  local function sel_proj(cmd) --click= select
    local linenum= toolbar.getnum_cmd(cmd)
    if linenum then
      clear_selected()
      itselected= cmd
      toolbar.selected(cmd,false,true)
    end
    return linenum
  end

  local function sel_proj_num(linenum)
    if not linenum then linenum=1 end
    if linenum > #Proj.data.recent_projects then linenum=#Proj.data.recent_projects end
    if linenum > 0 then sel_proj("goproj#"..linenum) end
  end

  local function goproj_rclick(cmd) --right click
    if sel_proj(cmd) then
      ui.toolbar_context_menu= create_uimenu_fromactions(recentproj_context_menu)
      return true --open context menu
    end
  end

  local function goproj_dclick(cmd) --double click
    local linenum= sel_proj(cmd)
    if linenum then
      clear_selected() --this project will move to the first place after openning it
      Proj.open_project(Proj.data.recent_projects[linenum])
      toolbar.select_list("projlist", true) --show project list
    end
  end

  --ACTION: open selected project from the recent list
  local function act_open_recentproj()
    goproj_dclick(itselected)
  end

  --ACTION: remove selected project from the recent list
  local function act_del_recentproj()
    local linenum= sel_proj(itselected)
    if linenum then
      if Util.confirm("Remove recent project","Do you want to remove the selected project from the list?") then
        table.remove(Proj.data.recent_projects,linenum)
        sel_proj_num(linenum)
        Proj.data.recent_prj_change= true
        toolbar.recentprojlist_update()
      end
    end
  end

  actions.add("open_recentproj", 'Open', act_open_recentproj)
  actions.add("del_recentproj", 'Remove from the list', act_del_recentproj)
  local function list_clear()
    --remove all items
    toolbar.listright= toolbar.listwidth-3
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
  end

  local function load_recentproj()
    local linenum= toolbar.getnum_cmd(itselected)
    list_clear()
    toolbar.list_init_title() --add a resize handle
    --toolbar.list_addaction("open_project")
    toolbar.list_addaction("new_project")
    toolbar.list_addinfo('Projects', true)

    toolbar.listtb_y= 3
    local w= toolbar.listwidth-13
    toolbar.sel_left_bar(itemsgrp)
    if (not Proj) or (#Proj.data.recent_projects < 1) then
      toolbar.list_addinfo('No recent projects found')
    else
      for i=1, #Proj.data.recent_projects do
        local fname= Util.getfilename(Proj.data.recent_projects[i])
        if fname ~= "" then
          local name= "goproj#"..i
          toolbar.list_add_txt_ico(name, fname, Proj.data.recent_projects[i], (i==1), sel_proj, "document-properties", (i%2==1), 0, 0, (i==1) and 2 or 0, w)
        end
      end
      toolbar.list_add_separator()
      sel_proj_num(linenum)
    end
  end

  local function mark_open_proj()
    toolbar.seticon("open-goproj#1", toolbar.get_openback_icon(Proj.data.is_open), toolbar.TTBI_TB.IT_NORMAL)
  end

  local function recentproj_create_cb()
    --LSTSEL_CREATE_CB: create callback
    --items group: fixed width=300 / height=use buttons + vertical scroll
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.setdefaulttextfont()

    list_clear()
    toolbar.cmd_rclick("goproj",goproj_rclick)
    toolbar.cmd_dclick("goproj",goproj_dclick)
  end

  local function recentproj_update_cb(reload)
    --LSTSEL_UPDATE_CB: update callback (parameter: reload == FALSE for VIEW/BUFFER_AFTER_SWITCH)
    if reload then load_recentproj() end
    mark_open_proj()
  end

  local function recentproj_showlist_cb(show)
    --LSTSEL_SHOW_CB: the list has been shown/hidden (parameter: show)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  function toolbar.recentprojlist_update() --reload list
    if toolbar.islistshown("recentprojlist") then load_recentproj() end
  end

  function toolbar.list_show_projects()
    if not toolbar.list_tb then toolbar.list_toolbar_onoff() end
    toolbar.select_list("recentprojlist",true) --activate this list
  end

  toolbar.registerlisttb("recentprojlist", "Recent Projects", "go-home", recentproj_create_cb, recentproj_update_cb, recentproj_showlist_cb, nil)
end

