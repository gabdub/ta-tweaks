-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.

local Util = Util
local events, events_connect = events, events.connect

local filter= ""
local dialog_w= 800
local dialog_h= 600
local itemsgrp

local function update_filter()
  local ena= true
  local ftxt= filter
  if filter == "" then ena=false ftxt="Type to filter" end
  toolbar.settext("filter-txt", ftxt, "")
  toolbar.enable("filter-txt", ena)
  toolbar.enable("edit-find", ena)
end

local function filter_key(keycode)
  if keycode >= 32 and keycode <= 126 then --ascii
    filter= filter .. string.char(keycode)
  elseif keycode == toolbar.KEY.BACKSPACE then --remove last letter
    filter= filter:sub(1,-2)
  elseif keycode == toolbar.KEY.DELETE then --clear
    filter= ""
  end
  update_filter()
end

local function close_dialog()
  toolbar.popup(toolbar.DIALOG_POPUP,false) --hide dialog
end

local function close_dialog_ev(npop)
  if npop == toolbar.DIALOG_POPUP then close_dialog() end
end
events_connect("popup_close", close_dialog_ev)

local function translate_keypad_codes(keycode)
  --convert keypad keycodes: *+-./0..9
  if keycode >= toolbar.KEY.KP_MULT and keycode <= toolbar.KEY.KP9 then return keycode-toolbar.KEY.KP_MULT+toolbar.KEY.MULT end
  return keycode
end

local function dialog_key_ev(npop, keycode)
  if npop == toolbar.DIALOG_POPUP then
    --ui.statusbar_text= "dialog key= ".. keycode
    keycode= translate_keypad_codes(keycode)
    if keycode == toolbar.KEY.RETURN or keycode == toolbar.KEY.KPRETURN then
      --select and close
    elseif keycode == toolbar.KEY.UP or keycode == toolbar.KEY.LEFT then
      --select previous item
    elseif keycode == toolbar.KEY.DOWN or keycode == toolbar.KEY.RIGHT then
      --select next item
    else
      filter_key(keycode) --modify filter
    end
    --return true to cancel default key actions (like close on ESCAPE)
  end
end
events_connect("popup_key", dialog_key_ev)

local function list_clear()
  --remove all items
  toolbar.listtb_y= 1
  toolbar.listright= dialog_w-3
  toolbar.sel_dialog_popup(itemsgrp,true) --empty items group
end

local function item_clicked(cmd) --click= select
  close_dialog()
end

local function create_dialog(title, width, height)
  dialog_w= width
  dialog_h= height
  filter= ""
  toolbar.new(50, 24, 16, toolbar.DIALOG_POPUP, toolbar.themepath,1)
  toolbar.setdefaulttextfont()
  toolbar.themed_icon(toolbar.globalicon, "ttb-combo-list", toolbar.TTBI_TB.BACKGROUND) --cfg-back
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-hilight", toolbar.TTBI_TB.BUT_HILIGHT)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-press", toolbar.TTBI_TB.BUT_HIPRESSED)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-active", toolbar.TTBI_TB.BUT_SELECTED)
  toolbar.themed_icon(toolbar.globalicon, "group-vscroll-back", toolbar.TTBI_TB.VERTSCR_BACK)
  toolbar.themed_icon(toolbar.globalicon, "group-vscroll-bar", toolbar.TTBI_TB.VERTSCR_NORM)
  toolbar.themed_icon(toolbar.globalicon, "group-vscroll-bar-hilight", toolbar.TTBI_TB.VERTSCR_HILIGHT)
  toolbar.themed_icon(toolbar.globalicon, "cfg-separator-h", toolbar.TTBI_TB.HSEPARATOR)

  --title group: align top + fixed height
  toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize, false)
  toolbar.setdefaulttextfont()
  toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)
  toolbar.gotopos(2, 3)
  toolbar.addlabel(title, "", dialog_w-toolbar.cfg.butsize-10, true, true)  --left align, bold
  toolbar.listtb_y= 2
  toolbar.list_cmdright= 2
  toolbar.list_addbutton("window-close", "Close", close_dialog)

  --filter group: full width + items height
  local filtergrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize+3, false)
  toolbar.setdefaulttextfont()
  toolbar.themed_icon(toolbar.groupicon, "ttb-combo-list", toolbar.TTBI_TB.BACKGROUND)
  toolbar.gotopos(2, 3)
  toolbar.cmd("edit-find", nil, "")
  toolbar.gotopos(2+toolbar.cfg.butsize, 3)
  toolbar.addlabel("...", "", dialog_w-toolbar.cfg.butsize-10, true, false, "filter-txt")  --left align
  update_filter()

  --items group: full width + items height w/scroll
  itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, false)
  toolbar.setdefaulttextfont()
  list_clear()

  for i=1, 30 do
    toolbar.list_add_txt_ico("it#"..i, "Item num "..i, "", false, item_clicked, "t_struct", (i%2 ==1),  0, 0, 0, dialog_w-13)
  end
end

--function toolbar.show_popup(btname,anchor)
--  create_dialog("Test 1",600,300)
--  toolbar.popup(toolbar.DIALOG_POPUP,true,btname,anchor,dialog_w,dialog_h) --anchor to a button (toolbar.ANCHOR)
--end

function toolbar.show_popup_center()
  create_dialog("Test 2",600,300)
  toolbar.popup(toolbar.DIALOG_POPUP,true,300,300,-dialog_w,-dialog_h) --open at a fixed position
end
