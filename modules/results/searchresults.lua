-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.

if toolbar then
  local itemsgrp

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

  toolbar.registerresultstb("searchresults", "Search results", "system-search", search_create, search_notify, search_showlist, _L['[Files Found Buffer]'])
end
