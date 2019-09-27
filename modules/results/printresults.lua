-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.

if toolbar then
  local itemsgrp

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

  toolbar.registerresultstb("printresults", "Console output", "system-lock-screen", print_create, print_notify, print_showlist, _L['[Message Buffer]'])
end
