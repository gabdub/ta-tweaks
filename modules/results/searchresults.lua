-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.

if toolbar then
  local itemsgrp
  local nitems= 0
  local yout= 1
  local fullprint= ""

  local function search_create()
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_results_bar(itemsgrp)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
  end

  local function search_notify(switching)
  end

  local function search_showlist(show)
    --show/hide list items
    toolbar.sel_results_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  function toolbar.results_clear()
    --remove all items
    toolbar.sel_results_bar(itemsgrp,true) --empty items group
    nitems= 0
    yout= 1
    fullprint= ""
  end

  --"edit-clear" / "edit-copy"
  local function search_act(name)
    if name == "edit-clear" then toolbar.results_clear() end
    if name == "edit-copy"  then buffer:copy_text(fullprint) end
  end

  function toolbar.search_result(txt)
    toolbar.sel_results_bar(itemsgrp)
    nitems= nitems+1
    local name= "sch-item#"..nitems
    toolbar.listtb_y= yout
    fullprint= fullprint..txt.."\n"
    if #txt > 2000 then txt= txt:sub(1,2000).."..." end
    local oneline= Util.str_one_line(txt)
    if #oneline > 200 then oneline= oneline:sub(1,200).."..." end
    toolbar.list_add_txt_ico(name, oneline, txt, false, nil, nil, (nitems%2==1), 0, 0, 0)
    yout= yout + toolbar.cfg.butsize
    toolbar.showresults("searchresults")
  end

  toolbar.registerresultstb("searchresults", "Search results", "system-search", search_create, search_notify, search_showlist, search_act)
end
