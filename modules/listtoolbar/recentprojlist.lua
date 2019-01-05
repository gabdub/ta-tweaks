-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

if toolbar then
  local titgrp, itemsgrp, itselected

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
    if linenum > #Proj.recent_projects then linenum=#Proj.recent_projects end
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
      toolbar.list_toolbar_onoff() --hide toolbar to see the project
      Proj.open_project(Proj.recent_projects[linenum])
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
        table.remove(Proj.recent_projects,linenum)
        sel_proj_num(linenum)
        Proj.prjlist_change = true
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
    toolbar.sel_left_bar(titgrp,true) --empty title group
  end

  local function load_recentproj()
    local linenum= toolbar.getnum_cmd(itselected)
    list_clear()
    toolbar.listtb_y= 1
    toolbar.cmdright= 3
    toolbar.list_addaction("open_project")
    toolbar.list_addaction("new_project")
    toolbar.list_addinfo('Recent Projects', true)

    toolbar.sel_left_bar(itemsgrp)
    if (not Proj) or (#Proj.recent_projects < 1) then
      toolbar.listtb_y= 3
      toolbar.list_addinfo('No recent projects found')
    else
      local y= 3
      for i=1, #Proj.recent_projects do
        local fname= Util.getfilename(Proj.recent_projects[i])
        if fname ~= "" then
          local name= "goproj#"..i
          toolbar.gotopos( 3, y)
          toolbar.addtext(name, fname, Proj.recent_projects[i], toolbar.listwidth-13, false, true, (i==1), toolbar.cfg.barsize, 0)
          toolbar.anchor(name, 10, true)
          toolbar.gotopos( 3, y)
          local icbut= "ico-"..name
          toolbar.cmd(icbut, sel_proj, "", "document-properties", true)
          toolbar.enable(icbut,false,false) --non-selectable image
          toolbar.cmds_n[name]= sel_proj
          y= y + toolbar.cfg.butsize
        end
      end
      sel_proj_num(linenum)
    end
  end

  local function recentproj_create()
    --title group: fixed width=300 / align top + fixed height
    titgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize, true)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)
    --items group: fixed width=300 / height=use buttons + vertical scroll
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)

    list_clear()
    toolbar.cmd_rclick("goproj",goproj_rclick)
    toolbar.cmd_dclick("goproj",goproj_dclick)
  end

  local function recentproj_notify(switching)
    if not switching then load_recentproj() end
  end

  local function recentproj_showlist(show)
    --show/hide list items
    toolbar.sel_left_bar(titgrp)
    toolbar.showgroup(show)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  function toolbar.recentprojlist_update() --reload list
    if toolbar.islistshown("recentprojlist") then load_recentproj() end
  end

  toolbar.registerlisttb("recentprojlist", "Recent Projects", "go-home", recentproj_create, recentproj_notify, recentproj_showlist)
end

