-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

if toolbar then
  local titgrp, itemsgrp, loaded

  local function open_proj(cmd)
    local linenum= tonumber(string.match(cmd,".-#(.*)"))
    Proj.open_project(Proj.recent_projects[linenum]) 
  end

  local function list_clear()
    --remove all items
    toolbar.listtb_y= 1
    toolbar.sel_left_bar(titgrp,true) --empty title group
    toolbar.list_addinfo('Recent Projects', true)
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
  end

  local function load_recentproj()
    list_clear()
    if (not Proj) or (#Proj.recent_projects < 1) then
      toolbar.list_addinfo('No recent projects found')
    else
      local y= 3
      for i=1, #Proj.recent_projects do
        local fname= Util.getfilename(Proj.recent_projects[i])
        if fname ~= "" then
          local name= "goproj#"..i
          toolbar.gotopos( 3, y)
          toolbar.addtext(name, fname, "", toolbar.listwidth-13, false, true, (i==1), toolbar.cfg.barsize, 0)
          toolbar.gotopos( 3, y)
          toolbar.cmd("ico-"..name, open_proj, "", "document-properties", true)
          toolbar.cmds_n[name]= open_proj
          y= y + toolbar.cfg.butsize
        end
      end
    end
    loaded= true
  end

  local function recentproj_create()
    --title group: fixed width=300 / align top + fixed height
    titgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)
    --items group: fixed width=300 / height=use buttons + vertical scroll
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0) --show v-scroll when needed
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)

    list_clear()
    loaded= false
  end

  local function recentproj_notify(switching)
    if not loaded then load_recentproj() end
  end

  local function recentproj_showlist(show)
    --show/hide list items
    toolbar.sel_left_bar(itemsgrp)
    toolbar.showgroup(show)
    toolbar.sel_left_bar(titgrp)
    toolbar.showgroup(show)
  end

  function toolbar.recentprojlist_update() --reload list
    if toolbar.islistshown("recentprojlist") then load_recentproj() end
  end

  toolbar.registerlisttb("recentprojlist", "Recent Projects", "go-home", recentproj_create, recentproj_notify, recentproj_showlist)
end

