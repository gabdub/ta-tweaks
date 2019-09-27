-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.

if toolbar then
  local itemsgrp
  local nitems= 0
  local yout= 1

  local function print_create()
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_results_bar(itemsgrp)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
  end

  local function print_notify(switching)
  end

  local function print_showlist(show)
    --show/hide list items
    toolbar.sel_results_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  local function list_clear()
    --remove all items
    --toolbar.listright= toolbar.listwidth-3
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
    nitems= 0
    yout= 1
  end

  function toolbar.print_result(txt)
    toolbar.sel_results_bar(itemsgrp)
    nitems= nitems+1
    local name= "prt-item#"..nitems
    toolbar.listtb_y= yout
    if #txt > 2000 then txt= txt:sub(1,2000).."..." end
    local oneline= Util.str_one_line(txt)
    if #oneline > 200 then oneline= oneline:sub(1,200).."..." end
    toolbar.list_add_txt_ico(name, oneline, txt, false, nil, nil, (nitems%2==1), 0, 0, 0)
    yout= yout + toolbar.cfg.butsize
    if not toolbar.isresultsshown("printresults") then toolbar.select_results("printresults") end
  end

  toolbar.registerresultstb("printresults", "Console output", "system-lock-screen", print_create, print_notify, print_showlist, _L['[Message Buffer]'])
end
