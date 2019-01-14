-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.

if toolbar then
  local events, events_connect = events, events.connect
  local titgrp, currlist, currlistidx
  local lbl_n= 0

  toolbar.listtb_hide_p= false
  toolbar.listselections= {}
  toolbar.cmdright= 18
  toolbar.listwidth=250

  local function listtb_switch()
    --{name, tooltip, icon, createfun, **notify**, show}
    if toolbar.list_tb and currlistidx > 0 then toolbar.listselections[currlistidx][5](true) end
  end

  local function listtb_update()
    --{name, tooltip, icon, createfun, **notify**, show}
    if toolbar.list_tb and currlistidx > 0 then toolbar.listselections[currlistidx][5](false) end
  end

  events_connect(events.BUFFER_AFTER_SWITCH,  listtb_switch)
  events_connect(events.VIEW_AFTER_SWITCH,    listtb_switch)
  events_connect(events.BUFFER_NEW,           listtb_update)
  events_connect(events.FILE_OPENED,          listtb_update)
  events_connect(events.FILE_CHANGED,         listtb_update)
  events_connect(events.FILE_AFTER_SAVE,      listtb_update)

  function toolbar.list_addbutton(name, tooltip, funct)
    toolbar.gotopos( 0, toolbar.listtb_y)
    toolbar.cmd(name, funct, tooltip or "", name, true)
    toolbar.cmdright= toolbar.cmdright + toolbar.cfg.butsize
    toolbar.anchor(name, toolbar.cmdright) --anchor to the right
  end

  function toolbar.list_addaction(action)
    toolbar.gotopos( 0, toolbar.listtb_y)
    toolbar.addaction(action)
    toolbar.cmdright= toolbar.cmdright + toolbar.cfg.butsize
    toolbar.anchor(action, toolbar.cmdright) --anchor to the right
  end

  function toolbar.list_addinfo(text,bold)
    --add a text to the list
    toolbar.gotopos( 3, toolbar.listtb_y)
    lbl_n= lbl_n+1
    local name= "_lbl_"..lbl_n
    toolbar.addlabel(text, "", toolbar.listright, true, bold, name)
    toolbar.listtb_y= toolbar.listtb_y + toolbar.cfg.butsize
    toolbar.cmdright= 18
    toolbar.anchor(name, toolbar.cmdright, true)
  end

  function toolbar.select_list(listname, dont_hide_show)
    if listname == currlist then
      --click on the active list= show/hide toolbar
      if not dont_hide_show then toolbar.list_toolbar_onoff() end
    else
      if (not dont_hide_show) and (not toolbar.list_tb) then toolbar.list_toolbar_onoff() end  --show toolbar
      --change the active list
      if currlistidx > 0 then
        toolbar.selected(currlist, false, false)
        toolbar.listselections[currlistidx][6](false) --hide list items
      end
      for i=1,#toolbar.listselections do
        if toolbar.listselections[i][1] == listname then
          currlist= listname
          currlistidx= i
          break
        end
      end
      if currlistidx > 0 then
        toolbar.selected(currlist, false, toolbar.list_tb)
        toolbar.listselections[currlistidx][6](true) --show list items
        listtb_update()
      end
    end
  end

  function toolbar.next_list()
    local n=currlistidx
    if toolbar.list_tb then
      if n < #toolbar.listselections then n=n+1 else n=1 end
    end
    toolbar.select_list(toolbar.listselections[n][1])
  end

  function toolbar.prev_list()
    local n=currlistidx
    if toolbar.list_tb then
      if n > 1 then n=n-1 else n=#toolbar.listselections end
    end
    toolbar.select_list(toolbar.listselections[n][1])
  end

  function toolbar.islistshown(name)
    return (toolbar.list_tb) and (currlist==name)
  end

  function toolbar.registerlisttb(name, tooltip, icon, createfun, notify, showlist)
    toolbar.listselections[#toolbar.listselections+1]= {name, tooltip, icon, createfun, notify, showlist}
  end

  --the toolbar config is saved inside the project configuration file
  local function beforeload_ltb(cfg)
    Util.add_config_field(cfg, "lst_width", Util.cfg_int, 250)
    Util.add_config_field(cfg, "lst_show",  Util.cfg_bool, true)
    Util.add_config_field(cfg, "open_proj", Util.cfg_str, "")
  end

  local function afterload_ltb(cfg)
    --show list toolbar
    toolbar.sel_left_bar()
    toolbar.list_tb= cfg.lst_show
    toolbar.listwidth= cfg.lst_width
    --start in "recent projects list" or "project list" if the project is open
    toolbar.select_list((cfg.open_proj ~= "") and "projlist" or "recentprojlist", true)
    toolbar.show(toolbar.list_tb, toolbar.listwidth)
  end

  local function beforesave_ltb(cfg)
    local changed= false
    if cfg.lst_show  ~= toolbar.list_tb    then cfg.lst_show=toolbar.list_tb     changed=true end
    if cfg.lst_width ~= toolbar.listwidth  then cfg.lst_width=toolbar.listwidth  changed=true end
    if cfg.open_proj ~= Proj.data.filename then cfg.open_proj=Proj.data.filename changed=true end
    return changed
  end

  local function projloaded_ltb(cfg)
    --the project file parsing is complete
    if currlistidx > 0 then
      toolbar.selected(currlist, false, toolbar.list_tb)
      toolbar.listselections[currlistidx][6](true) --show list
      listtb_update()
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

    --title group: fixed width=300 / align top + fixed height
    titgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize, false)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)

    toolbar.show(false, toolbar.listwidth)  --hide until the project config is loaded

    if #toolbar.listselections > 0 then
      for i=1,#toolbar.listselections do
        local ls= toolbar.listselections[i] --{name, tooltip, icon, createfun, notify, show}
        ls[4]() --create list
      end
    end

    toolbar.sel_top_bar() --add buttons to select the lists in the top toolbar
    if #toolbar.listselections > 0 then
      for i=1,#toolbar.listselections do
        local ls= toolbar.listselections[i] --{name, tooltip, icon, createfun, notify, show}
        toolbar.cmd(ls[1], toolbar.select_list, ls[2], ls[3], true)
      end
      toolbar.addspace()
    end

    if actions then
      toolbar.idviewlisttb= actions.add("toggle_viewlist", 'Show _List toolbar', toolbar.list_toolbar_onoff, "cf6", "view-list-compact-symbolic", function()
        return (toolbar.list_tb and 1 or 2) end) --check
      local med= actions.getmenu_fromtitle(_L['_View'])
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
    toolbar.cmdright= 18
    toolbar.sel_left_bar(titgrp,true) --empty title group
    toolbar.top_right_resize_handle("resizeList", 150, new_tb_size) --add a resize handle
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
    --only show as selected when the list is visible
    toolbar.selected(currlist, false, toolbar.list_tb)
  end

  toolbar.icon_ext= {
    ["txt"]=  "text-plain",
    ["md"]=   "text-richtext",
    ["c"]=    "text-x-c",
    ["cpp"]=  "text-x-c++",
    ["h"]=    "text-x-chdr",
    ["hpp"]=  "text-x-c++hdr",
    ["lua"]=  "text-x-lua",
    ["py"]=   "text-x-python",
    ["java"]= "text-x-java",
    ["ctag"]= "text-x-ctag",
    ["asm"]=  "text-x-source",
    ["mas"]=  "text-x-source",
    ["inc"]=  "text-x-source",
    ["lst"]=  "x-office-document",
    ["map"]=  "application-msword",
    ["sym"]=  "application-msword",
    ["s19"]=  "multipart-encrypted",
    ["html"]= "text-html",
    ["htm"]=  "text-html",
    ["xml"]=  "text-xml",
    ["css"]=  "text-css",
    ["js"]=   "text-x-javascript",
    ["php"]=  "application-x-php",
    ["conf"]= "text-x-copying",
    ["pdf"]=  "application-pdf",
    ["sh"]=   "text-x-script",
    ["bash"]= "text-x-script",
    ["glade"]="text-x-generic-template",
    ["exe"]=  "application-x-executable",
    ["bat"]=  "text-x-script",
    ["rc"]=   "text-x-generic-template",
  }

  toolbar.icon_ext_path= _USERHOME.."/toolbar/icons/mime/"

  function toolbar.icon_fname(fname)
    local p,f,e= Util.splitfilename(string.lower(fname))
    if p then
      local icon= toolbar.icon_ext[e]
      if icon then return toolbar.icon_ext_path..icon..".png" end
      if f == "makefile" then return toolbar.icon_ext_path.."text-x-makefile.png" end
      if f == "readme" then return toolbar.icon_ext_path.."text-x-readme.png" end
    end
    return toolbar.icon_ext_path.."text-plain.png"
  end
end
