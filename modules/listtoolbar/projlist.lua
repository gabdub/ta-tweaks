-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

if toolbar then
  local titgrp, itemsgrp

  local function list_clear()
    --remove all items
    toolbar.listtb_y= 1
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
    toolbar.sel_left_bar(titgrp,true) --empty title group
  end

  local function proj_create()
    --title group: fixed width=300 / align top + fixed height
    titgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)
    --items group: fixed width=300 / height=use buttons + vertical scroll
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0) --show v-scroll when needed
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)

    list_clear()
  end

  local function proj_notify(switching)
    --when switching buffers/view: update only if the current buffer filename change
    --if (not switch) or (toolbar.tag_listedfile ~= buffer.filename) then load_ctags() end
  end

  local function proj_showlist(show)
    --show/hide list items
    toolbar.sel_left_bar(itemsgrp)
    toolbar.showgroup(show)
    toolbar.sel_left_bar(titgrp)
    toolbar.showgroup(show)
  end

  toolbar.registerlisttb("projlist", "Project", "document-properties", proj_create, proj_notify, proj_showlist)
end

