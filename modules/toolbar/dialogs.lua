-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.

local Util = Util
local events, events_connect = events, events.connect

local dialog_w= 800
local dialog_h= 600
local dialog_title= ""
local itemsgrp
local previewgrp1
local previewgrp2
local filtergrp

local dialog_list= {}
local dialog_cols= {}
local dialog_buttons= {}
local dialog_accel= {}
local dialog_data_icon= ""
local dialog_font_preview= false
local dialog_single_click= false
local dialog_native= false

local dlg_can_move= false
local dlg_filter_is_edit= false
local dlg_filter_empty_text= ""
local dlg_start_x= 300
local dlg_start_y= 300

toolbar.dlg_select_it= ""
toolbar.dlg_select_ev= nil
toolbar.dlg_filter_col2= false

local filter= ""
local idx_filtered= {}
local ensure_it_vis= nil
local idx_sel_i= 0

local finddlgopen= false

local function get_list_itemstr(idx)
  local name= dialog_list[idx] --string list
  if type(name) == "table" then name= name[1] end --multi column list: use first column
  return name
end

local function get_list_col(idx, ncol)
  local item= dialog_list[idx]
  if type(item) == "table" and #item >= ncol then return item[ncol] end
  return ""
end

local function close_dialog()
  toolbar.popup(toolbar.DIALOG_POPUP, toolbar.PSHOW.HIDE) --hide dialog
  if finddlgopen then
    finddlgopen= false
    toolbar.selected("find_dialog", false, false)
  end
end

function toolbar.hide_find_dialog()
  if finddlgopen then
    close_dialog()
    return true
  end
  return false
end

events.connect(events.RESET_BEFORE, close_dialog, 1)

local function close_dialog_ev(npop)
  if npop == toolbar.DIALOG_POPUP then close_dialog() end
end
events_connect("popup_close", close_dialog_ev)

local function update_filter()
  local ena= true
  local ftxt= filter
  if filter == "" then ena=false ftxt=dlg_filter_empty_text end
  toolbar.settext("filter-txt", ftxt, "Copy")
  toolbar.enable("filter-txt", ena)
end

local function focus_dialog_ev(npop, focused)
  if npop == toolbar.DIALOG_POPUP then
    toolbar.sel_dialog_popup(filtergrp,false)
    if focused == 1 then
      toolbar.themed_icon(toolbar.groupicon, "ttb-button-normal", toolbar.TTBI_TB.BACKGROUND)
      update_filter()
    else
      toolbar.themed_icon(toolbar.groupicon, "ttb-button-disabled", toolbar.TTBI_TB.BACKGROUND)
      toolbar.enable("filter-txt", false)
    end
  end
end
events_connect("popup_focus", focus_dialog_ev)

local function update_preview()
  if dialog_font_preview and (idx_sel_i > 0) then
    local font= get_list_itemstr(idx_filtered[idx_sel_i])
    toolbar.sel_dialog_popup(previewgrp1,false)
    toolbar.textfont(24, 0, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed, toolbar.get_font_num(font))
    toolbar.sel_dialog_popup(previewgrp2,false)
    toolbar.textfont(12, 0, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed, toolbar.get_font_num(font))
  end
end

local function ensure_sel_view()
  if ensure_it_vis then
    toolbar.ensurevisible(ensure_it_vis, true)
    ensure_it_vis= nil
  end
end

local function change_selection(newsel)
  if newsel and idx_sel_i ~= newsel and #idx_filtered > 1 then
    if newsel < 1 then newsel=1 end
    if newsel > #idx_filtered then newsel= #idx_filtered end
    toolbar.selected("it#"..idx_filtered[idx_sel_i], false, false)
    idx_sel_i= newsel
    ensure_it_vis= "it#"..idx_filtered[idx_sel_i]
    toolbar.selected(ensure_it_vis, false, true)
    ensure_sel_view()
    update_preview()
    return true
  end
  return false
end

local function choose_item(cmd)
  local itnum= toolbar.getnum_cmd(cmd)
  if itnum then
    toolbar.dlg_select_it= get_list_itemstr(itnum)
    if toolbar.dlg_select_ev then
      local keepopen= toolbar.dlg_select_ev(toolbar.dlg_select_it)
      if keepopen then --return true to keep the dialog open
        toolbar.sel_dialog_popup(itemsgrp,false) --keep the popup toolbar selected
        return
      end
    end
  end
  close_dialog()
end

local function click_item(cmd)
  if dialog_single_click then
    choose_item(cmd) --choose and close
  else
    --select item
    local id= toolbar.getnum_cmd(cmd)
    local n= 0
    for i=1, #idx_filtered do
      if idx_filtered[i]==id then n=i break end
    end
    change_selection(n)
  end
end

local check_val= {}

local function enable_buttons()
  for i=1, #dialog_buttons do
    local bt= dialog_buttons[i] --1:bname, 2:text/icon, 3:tooltip, 4:x, 5:width, 6:row, 7:callback, 8:button-flags=toolbar.DLGBUT..., 9:key-accel
    local flg= bt[8]
    if (flg & toolbar.DLGBUT.EN_OFF) ~= 0 then
      toolbar.enable(bt[1], false)  --disabled
    elseif (flg & toolbar.DLGBUT.EN_ITEMS) ~= 0 then
      toolbar.enable(bt[1], (#idx_filtered > 0)) --enable when there is at least one item
    elseif (flg & toolbar.DLGBUT.EN_MARK) ~= 0 then
      local ena= false
      for k,v in pairs(check_val) do
        if v then ena=true break end --enable when something is checked
      end
      toolbar.enable(bt[1], ena)
    end
  end
end

function toolbar.dialog_tog_check_all()
  --toggle all checks
  local setchk= false
  for k,v in pairs(check_val) do
    if not v then setchk=true break end --at least one is unchecked
  end
  for k,v in pairs(check_val) do
    check_val[k]= setchk
    toolbar.selected(k, setchk, false)
  end
  enable_buttons()
end

local function chg_check(cmd) --check-box clicked
  check_val[cmd]= not check_val[cmd]
  toolbar.selected(cmd, check_val[cmd], false)
  enable_buttons()
end

function toolbar.dialog_tog_one_check()
  --toggle current check
  if idx_sel_i > 0 then chg_check("dlg-check#"..idx_filtered[idx_sel_i]) end
end

local function show_col_data(nrow, ncol, xcol, wcol)
  local txt= get_list_col(nrow, ncol)
  if type(txt) == "boolean" then
    toolbar.gotopos(xcol, toolbar.listtb_y - toolbar.cfg.butsize)
    local name= "dlg-check#"..nrow
    toolbar.cmd(name, chg_check, "", "", toolbar.TTBI_TB.CHECK_BASE)
    check_val[name]= txt
  elseif txt ~= "" then
    toolbar.gotopos(xcol, toolbar.listtb_y - toolbar.cfg.butsize)
    toolbar.addlabel(txt, "", wcol, true) --left-align
  end
end

local function load_data(keep_marks)
  local chknum= {}    --save checks
  if keep_marks then
    for k,v in pairs(check_val) do
      if v then chknum[#chknum+1]= k end
    end
  end
  --remove all items
  toolbar.listtb_y= 1
  toolbar.listright= dialog_w-3
  toolbar.sel_dialog_popup(itemsgrp,true) --empty items group
  --load data
  local flt= string.lower(Util.escape_filter(filter))
  local n= 0
  idx_sel_i= 0
  idx_filtered= {}
  check_val= {}
  local i
  local icon= dialog_data_icon
  local isMime= (dialog_data_icon == "MIME")
  local isLexer= (dialog_data_icon == "LEXER")
  local x2= 0
  local w2= 0
  local x3= 0
  local w3= 0
  local lex_icon= {}
  if dialog_cols and #dialog_cols > 1 then
    x2= dialog_cols[1]
    w2= dialog_cols[2]
    if #dialog_cols > 2 then
      x3= x2+w2
      w3= dialog_cols[3]
    end
  end
  for i=1, #dialog_list do
    local itstr= get_list_itemstr(i)
    local itname= string.lower(itstr)  --ignore case
    if (flt == '' or itname:match(flt)) and ((not toolbar.dlg_filter_col2) or (get_list_col(i,2) ~= '')) then --filter by name and col2
      n= n+1
      idx_filtered[n]= i
      local btname= "it#"..i
      if isMime then icon= toolbar.icon_fname(itstr) elseif isLexer then icon= toolbar.icon_lexer(itstr) end
      toolbar.list_add_txt_ico(btname, itstr, "", false, click_item, icon, (n%2 ==1),  0, 0, 0, dialog_w-13)
      if w2 > 0 then show_col_data(i, 2, x2, w2) end --col #2
      if w3 > 0 then show_col_data(i, 3, x3, w3) end --col #3
      toolbar.cmd_dclick(btname, choose_item)
      if toolbar.dlg_select_it == "" then toolbar.dlg_select_it= itstr end --select first when none is provided
      if toolbar.dlg_select_it == itstr then idx_sel_i= n ensure_it_vis=btname toolbar.selected(ensure_it_vis, false, true) end
    end
  end
  if idx_sel_i == 0 and n > 0 then
    idx_sel_i= 1
    i= idx_filtered[idx_sel_i]
    toolbar.dlg_select_it= get_list_itemstr(i)
    ensure_it_vis="it#"..i
    toolbar.selected(ensure_it_vis, false, true)
  end
  if keep_marks then --try to keep checks
    for i=1,#chknum do
      local k= chknum[i]
      if check_val[k] ~= nil then chg_check(k) end
    end
  end
  update_preview()
  enable_buttons()
end

local function paste_filter()
  filter= Util.str_trim(ui.clipboard_text)
  update_filter()
  load_data( true ) --try to keep marks
end

local function copy_filter()
  buffer:copy_text(filter)
end

local function filter_key(keycode, keyflags)
  local afltr= filter
  if (keyflags & toolbar.KEYFLAGS.CTRL_ALT_META) == 0 then  --ignore key if ctrl/alt/meta are pressed
    if keycode >= 32 and keycode <= 126 then --ASCII (ignore SHIFT)
      filter= filter .. string.char(keycode)
    elseif (keyflags & toolbar.KEYFLAGS.SHIFT) == 0 then  --ignore key if shift is pressed
      if keycode == toolbar.KEY.BACKSPACE then --remove last letter
        filter= filter:sub(1,-2)
      elseif keycode == toolbar.KEY.DELETE then --clear
        filter= ""
      end
    end
  end
  if afltr ~= filter then
    update_filter()
    load_data( true ) --try to keep marks
  end
end

local function translate_key_codes(keycode)
  --convert keypad keycodes: *+-./0..9
  if keycode >= toolbar.KEY.KP_MULT and keycode <= toolbar.KEY.KP9 then return keycode-toolbar.KEY.KP_MULT+toolbar.KEY.MULT end
  if keycode >= toolbar.KEY.KP_MULT and keycode <= toolbar.KEY.KP9 then return keycode-toolbar.KEY.KP_MULT+toolbar.KEY.MULT end
  if keycode == toolbar.KEY.TAB or keycode == toolbar.KEY.SHIFT_TAB then return 9 end
  return keycode
end

local function db_pressed(bname)
  for i=1, #dialog_buttons do
    local bt= dialog_buttons[i] --1:bname, 2:text/icon, 3:tooltip, 4:x, 5:width, 6:row, 7:callback, 8:button-flags=toolbar.DLGBUT..., 9:key-accel
    if bt[1] == bname then
      local chkflist= {}  --list of checked items
      for k,v in pairs(check_val) do
        if v then
          local itnum= toolbar.getnum_cmd(k)
          chkflist[#chkflist+1]= dialog_list[itnum]
        end
      end
      local flg= bt[8]
      if (flg & toolbar.DLGBUT.CLOSE) ~= 0 then close_dialog() end  --close dialog
      if bt[7] ~= nil then bt[7](bname, chkflist) end --callback
      if (flg & (toolbar.DLGBUT.CLOSE|toolbar.DLGBUT.RELOAD)) == toolbar.DLGBUT.RELOAD then
        load_data( (flg & toolbar.DLGBUT.KEEP_MARKS) ~= 0 ) --reload-list
      end
      return true
    end
  end
  return false
end

local function dialog_key_ev(npop, keycode,keyflags)
  toolbar.keyflags= keyflags
  if npop == toolbar.DIALOG_POPUP then
    keycode= translate_key_codes(keycode)
    local kc= keycode
    if kc >= 65 and kc <= 90 then kc= kc+32 end --lower case letter (A..Z)
    keyflags= keyflags & toolbar.KEYFLAGS.ALL_MODS --keep only SHIFT/CTRL/ALT/META
    --ui.statusbar_text= "dialog key= ".. kc.." flags= ".. keyflags
    --check accelerators
    for i=1,#dialog_accel do  --{keycode, keyflags, buttname}
      if dialog_accel[i][1] == kc and dialog_accel[i][2] == keyflags then
        toolbar.keyflags= 0
        local bname= dialog_accel[i][3]
        if not db_pressed(bname) then --try dialog buttons
          if toolbar.cmds[bname] ~= nil then toolbar.cmds[bname](bname) end --try other buttons
        end
        toolbar.sel_dialog_popup(itemsgrp,false) --keep the popup toolbar selected
        return
      end
    end
    if keycode == toolbar.KEY.RETURN or keycode == toolbar.KEY.KPRETURN then
      if dlg_filter_is_edit then
        toolbar.dlg_select_it= filter
        if toolbar.dlg_select_ev then
          local keepopen= toolbar.dlg_select_ev(toolbar.dlg_select_it)
          --return true to keep the dialog open
          if keepopen then return end
        end
        close_dialog()
        return
      end
      if idx_sel_i > 0 then choose_item("it#"..idx_filtered[idx_sel_i]) end --select and close

    elseif keyflags == 0 then  --ignore key if shift/ctrl/alt/meta are pressed
      if keycode == toolbar.KEY.UP or keycode == toolbar.KEY.LEFT then
        change_selection( idx_sel_i-1 )  --select previous item
      elseif keycode == toolbar.KEY.DOWN or keycode == toolbar.KEY.RIGHT then
        change_selection( idx_sel_i+1 )  --select next item
      elseif keycode == toolbar.KEY.PG_UP then
        change_selection( idx_sel_i-10 )  --select previous page item
      elseif keycode == toolbar.KEY.PG_DWN then
        change_selection( idx_sel_i+10 )  --select next page item
      elseif keycode == toolbar.KEY.HOME then
        change_selection( 1 )  --select previous page item
      elseif keycode == toolbar.KEY.END then
        change_selection( #idx_filtered )  --select next page item
      end
    end
    filter_key(keycode, keyflags) --modify filter
    --return true to cancel default key actions (like close on ESCAPE)
  end
end
events_connect("popup_key", dialog_key_ev)

local function add_accelerator(keyname, buttname)
  local keyflags= 0
  keyname= string.lower(keyname)
  if keyname:match("control+")  then keyflags= keyflags | toolbar.KEYFLAGS.CONTROL  keyname= keyname:gsub("control%+","") end
  if keyname:match("alt+")      then keyflags= keyflags | toolbar.KEYFLAGS.ALT      keyname= keyname:gsub("alt%+","") end
  if keyname:match("meta+")     then keyflags= keyflags | toolbar.KEYFLAGS.META     keyname= keyname:gsub("meta%+","") end
  if keyname:match("shift+")    then keyflags= keyflags | toolbar.KEYFLAGS.SHIFT    keyname= keyname:gsub("shift%+","") end
  local keycode= 0
  if #keyname == 1 then
    keycode= string.byte(keyname) --in lower case
  else
    local fk= keyname:match("[fF](%d*)")
    if fk then keycode= tonumber(fk) +toolbar.KEY.F1 -1 end
  end
  if keycode ~= 0 then dialog_accel[#dialog_accel+1]= {keycode, keyflags, buttname} end
end

local function beforeload_dlg(cfg)
  --CFGHOOK_BEFORE_LOAD: add hooked fields to config
  Util.add_config_field(cfg, "dlg_x", Util.cfg_int, 300)
  Util.add_config_field(cfg, "dlg_y", Util.cfg_int, 300)
end

local function afterload_dlg(cfg)
  --CFGHOOK_CONFIG_LOADED: notify config loaded
  dlg_start_x= cfg.dlg_x
  dlg_start_y= cfg.dlg_y
end

local function beforesave_dlg(cfg)
  --CFGHOOK_BEFORE_SAVE: get hooked fields value
  local changed= false
  if cfg.dlg_x ~= dlg_start_x then cfg.dlg_x=dlg_start_x changed=true end
  if cfg.dlg_y ~= dlg_start_y then cfg.dlg_y=dlg_start_y changed=true end
  return changed
end

local function projloaded_dlg(cfg)
  --CFGHOOK_PROJ_LOADED: the project parsing is complete
end

Proj.add_config_hook(beforeload_dlg, afterload_dlg, beforesave_dlg, projloaded_dlg)

local function end_dlg_drag(cmd)
  if dlg_can_move then
    local lastpos= toolbar.getversion(toolbar.GETVER.POPUP_POS)
    if lastpos ~= nil and lastpos ~= "" then
      --integer,integer
      local a,b = lastpos:match('^(.-),(.+)$')
      if a and b then
        dlg_start_x= tonumber(a)
        dlg_start_y= tonumber(b)
      end
    end
  end
end

function toolbar.create_dialog(title, width, height, datalist, dataicon, config)
  close_dialog() --make sure there is no open dialog
  dialog_w= width
  dialog_h= height
  dialog_list= datalist
  dialog_title= title
  dlg_filter_empty_text= "Type to filter"
  if config then
    dialog_cols= config["columns"]  --columns width (up to 3 for now...)
    if dialog_cols == nil then dialog_cols= {} end
    dialog_buttons= config["buttons"] --add this buttons to the dialog
    if dialog_buttons == nil then dialog_buttons= {} end
    dlg_can_move= config.can_move or false --the dialog can be moved
    dialog_single_click= config.singleclick or false --choose and close on single click (combo style)
    dialog_font_preview= config.fontpreview or false --show a font preview of the selected item (items are font names)
    dlg_filter_is_edit= config.editmode or false
    if config.filter_empty_text then dlg_filter_empty_text=config.filter_empty_text end
  else
    dialog_cols= {}
    dialog_buttons= {}
    dlg_can_move= false
    dialog_single_click= false
    dialog_font_preview= false
    dlg_filter_is_edit= false
  end
  dialog_data_icon= dataicon
  dialog_accel= {}

  filter= ""
  local canmove= dlg_can_move and (toolbar.setmovepopup ~= nil)
  dialog_native= canmove and toolbar.get_check_val("tbnativedialogs") --use native window borders or implement the title bar using controls
  toolbar.new(50, 24, 16, toolbar.DIALOG_POPUP, toolbar.themepath, dialog_native and 0 or 1)
  toolbar.setdefaulttextfont()
  toolbar.themed_icon(toolbar.globalicon, "ttb-combo-list", toolbar.TTBI_TB.BACKGROUND)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-hilight", toolbar.TTBI_TB.BUT_HILIGHT)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-press", toolbar.TTBI_TB.BUT_HIPRESSED)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-active", toolbar.TTBI_TB.BUT_SELECTED)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-normal-drop", toolbar.TTBI_TB.DDBUT_NORMAL)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-hilight-drop", toolbar.TTBI_TB.DDBUT_HILIGHT)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-press-drop", toolbar.TTBI_TB.DDBUT_HIPRESSED)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-active-drop", toolbar.TTBI_TB.DDBUT_SELECTED)
  toolbar.themed_icon(toolbar.globalicon, "group-vscroll-back", toolbar.TTBI_TB.VERTSCR_BACK)
  toolbar.themed_icon(toolbar.globalicon, "group-vscroll-bar", toolbar.TTBI_TB.VERTSCR_NORM)
  toolbar.themed_icon(toolbar.globalicon, "group-vscroll-bar-hilight", toolbar.TTBI_TB.VERTSCR_HILIGHT)
  toolbar.themed_icon(toolbar.globalicon, "cfg-separator-h", toolbar.TTBI_TB.HSEPARATOR)
  toolbar.themed_icon(toolbar.globalicon, "ttb-checkbox-normal", toolbar.TTBI_TB.CHECK_OFF)
  toolbar.themed_icon(toolbar.globalicon, "ttb-checkbox-selected", toolbar.TTBI_TB.CHECK_ON)
  toolbar.themed_icon(toolbar.globalicon, "ttb-checkbox-hilight", toolbar.TTBI_TB.CHECK_HILIGHT)
  toolbar.themed_icon(toolbar.globalicon, "ttb-checkbox-press", toolbar.TTBI_TB.CHECK_HIPRESS)

  --title group: align top + fixed height
  if canmove then
    if not dialog_native then --implement a title bar using controls
      toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize, false)
      toolbar.setdefaulttextfont()
      local sw= toolbar.cfg.butsize
      toolbar.cfg.butsize= dialog_w-toolbar.cfg.butsize-3 --substract the close button
      toolbar.gotopos(1, 2) --title bar
      --text,func,tooltip,name,usebutsz,dropbt,leftalign,bold
      toolbar.cmdtext(title, end_dlg_drag, "", "dlg-caption", true, false, true, true) --save last dialog position
      toolbar.setthemeicon("dlg-caption", "transparent", toolbar.TTBI_TB.IT_NORMAL)
      toolbar.setthemeicon("dlg-caption", "transparent", toolbar.TTBI_TB.IT_HILIGHT)
      toolbar.setthemeicon("dlg-caption", "transparent", toolbar.TTBI_TB.IT_HIPRESSED)
      toolbar.setmovepopup("dlg-caption", true)
      toolbar.cfg.butsize= sw
    else
      toolbar.cmds["popup-caption-endmove"]= end_dlg_drag --save last dialog position
    end
  else
    --if the dialog cannot move: use a custom border
    toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize, false)
    toolbar.setdefaulttextfont()
    toolbar.gotopos(2, 3)
    toolbar.addlabel(title, "", dialog_w-toolbar.cfg.butsize-10, true, true)  --left align, bold
  end
  if dialog_native then
    toolbar.setbackcolor(toolbar.globalicon, toolbar.cfg.popup_back, false, true) --solid background
  else
    toolbar.themed_icon(toolbar.globalicon, "ttb-dialog-border", toolbar.TTBI_TB.BACKGROUND) --draw borders
    --implement a close button using controls
    toolbar.listtb_y= 0
    toolbar.list_cmdright= 0
    toolbar.list_addbutton("close_dlg", "Close", close_dialog, "transparent")
    toolbar.seticon("close_dlg", "ttb-close-normal",  toolbar.TTBI_TB.BACKGROUND, true)
    toolbar.seticon("close_dlg", "ttb-close-hilight", toolbar.TTBI_TB.IT_HILIGHT, true)
    toolbar.seticon("close_dlg", "ttb-close-press",   toolbar.TTBI_TB.IT_HIPRESSED, true)
  end

  if dialog_font_preview then
    local prevtxt= "0123456789-AaBbCcDdEdFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz~{}[]"
    previewgrp1= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, 25, false)
    toolbar.textfont(24, 0, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.addlabel(prevtxt, "", dialog_w-5, true)
    previewgrp2= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, 25, false)
    toolbar.textfont(12, 0, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.addlabel(prevtxt, "", dialog_w-5, true)
  end

  --filter group: full width + items height
  filtergrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize+3, false)
  toolbar.list_cmdright= 2
  toolbar.listtb_y= 2
  for i=1, #dialog_buttons do
    local bt= dialog_buttons[i] --1:bname, 2:text/icon, 3:tooltip, 4:x, 5:width, 6:row, 7:callback, 8:button-flags=toolbar.DLGBUT..., 9:key-accel
    local nr= bt[6]   --6:row= -1 (at the end of the filter input)
    local flg= bt[8]
    if nr == -1 and (flg & toolbar.DLGBUT.ICON) ~= 0 then  --must be an ICON
      local tooltip= bt[3]
      if bt[9] then --add button accelerator
        if #tooltip > 30 then tooltip= tooltip.."\n".."["..bt[9].."]" else tooltip= tooltip.." ["..bt[9].."]" end
        add_accelerator(bt[9], bt[1])
      end
      toolbar.list_addbutton(bt[1], tooltip, bt[7], bt[2])
    end
  end
  toolbar.setdefaulttextfont()
  toolbar.themed_icon(toolbar.groupicon, "ttb-button-normal", toolbar.TTBI_TB.BACKGROUND)
  toolbar.gotopos(2, 3)
  local icon= dlg_filter_is_edit and dialog_data_icon or "edit-find"
  toolbar.cmd("filter-find", paste_filter, "Paste", icon)
  toolbar.gotopos(2+toolbar.cfg.butsize, 3)
  toolbar.addlabel("...", "Copy", dialog_w-toolbar.cfg.butsize-4-toolbar.list_cmdright, true, false, "filter-txt")  --left align
  toolbar.cmds["filter-txt"]= copy_filter
  update_filter()

  if dialog_buttons and #dialog_buttons > 0 then
    local nrows= 0
    for i=1, #dialog_buttons do
      local nr= dialog_buttons[i][6]
      if nr > nrows then nrows= nr end
    end
    if nrows > 0 then
      local buttons= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize * nrows +1, false)
      toolbar.themed_icon(toolbar.groupicon, "ttb-button-normal", toolbar.TTBI_TB.BUT_NORMAL)
      toolbar.setdefaulttextfont()
      toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)
      local sw= toolbar.cfg.butsize
      for i=1, #dialog_buttons do
        local bt= dialog_buttons[i] --1:bname, 2:text/icon, 3:tooltip, 4:x, 5:width, 6:row, 7:callback, 8:button-flags=toolbar.DLGBUT..., 9:key-accel
        local nr= bt[6]
        if nr > 0 then
          toolbar.gotopos(bt[4], (nr-1)*toolbar.cfg.barsize+2)
          toolbar.cfg.butsize= bt[5]
        end
        local flg= bt[8]
        local leftalign= ((flg & toolbar.DLGBUT.LEFT) ~= 0)
        local boldtxt= ((flg & toolbar.DLGBUT.BOLD) ~= 0)
        local dropdown= ((flg & toolbar.DLGBUT.DROPDOWN) ~= 0)
        local tooltip= bt[3]
        if nr > 0 then  --button
          if bt[9] then --add button accelerator
            if #tooltip > 30 then tooltip= tooltip.."\n".."["..bt[9].."]" else tooltip= tooltip.." ["..bt[9].."]" end
            add_accelerator(bt[9], bt[1])
          end
          if (flg & toolbar.DLGBUT.ICON) ~= 0 then  --ICON
            toolbar.cmd(bt[1], db_pressed, tooltip, bt[2]) --name,func,tooltip,icon,base
          elseif (flg & toolbar.DLGBUT.LABEL) ~= 0 then --LABEL
            toolbar.addlabel(bt[2], tooltip, 0, true, boldtxt, bt[1]) --text,tooltip,width,leftalign,bold,name,xoff,yoff
          else --TEXT BUTTON
            --text,func,tooltip,name,usebutsz,dropbt,leftalign,bold
            toolbar.cmdtext(bt[2], db_pressed, tooltip, bt[1], true, dropdown, leftalign, boldtxt)
            toolbar.themed_icon(bt[1], "ttb-button-disabled", toolbar.TTBI_TB.IT_DISABLED)
          end
        elseif nr == 0 and bt[9] then   --accelerator only
          toolbar.cmds[bt[1]]= db_pressed
          add_accelerator(bt[9], bt[1])
        end
      end
      toolbar.cfg.butsize= sw
    end
  end

  --items group: full width + items height w/scroll
  itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, false)
  toolbar.setdefaulttextfont()
  load_data( false )
end

function toolbar.show_dialog()
  local smode= dialog_native and toolbar.PSHOW.NATIVE or toolbar.PSHOW.DRAW
  toolbar.popup(toolbar.DIALOG_POPUP, smode, dlg_start_x,dlg_start_y, -dialog_w,-dialog_h, dialog_title)
end

function toolbar.font_chooser(title, sel_font, font_selected, btname, anchor)
  toolbar.dlg_select_it= sel_font
  toolbar.dlg_select_ev= font_selected
  toolbar.dlg_filter_col2= false
  toolbar.create_dialog(title or "Font chooser", 600, 331, toolbar.get_font_list(), "format-text-italic", {fontpreview=true, can_move=(btname==nil)})
  if btname then
    toolbar.popup(toolbar.DIALOG_POPUP,toolbar.PSHOW.DRAW,btname,anchor,-dialog_w,-dialog_h) --anchor to a button (toolbar.ANCHOR) (use custom dialog borders)
  else
    toolbar.show_dialog() --open at a fixed position
  end
  ensure_sel_view()
end

function toolbar.small_chooser(title, sel_enc, enc_selected, enc_list, btname, anchor, width, height, icon)
  toolbar.dlg_select_it= sel_enc
  toolbar.dlg_select_ev= enc_selected
  toolbar.dlg_filter_col2= false
  toolbar.create_dialog(title, width, height, enc_list, icon, {singleclick=true, can_move=(btname==nil)})
  if btname then
    toolbar.popup(toolbar.DIALOG_POPUP,toolbar.PSHOW.DRAW,btname,anchor,-dialog_w,-dialog_h) --anchor to a button (toolbar.ANCHOR) (use custom dialog borders)
  else
    toolbar.show_dialog() --open at a fixed position
  end
  ensure_sel_view()
end

function toolbar.small_edit(title, txt_value, txt_info, val_changed, btname, anchor, width, height, icon)
  toolbar.dlg_select_it= txt_value
  toolbar.dlg_select_ev= val_changed
  toolbar.dlg_filter_col2= false
  toolbar.create_dialog(title, width, height, {}, icon, {editmode= true, filter_empty_text=txt_info, can_move=(btname==nil)})
  if btname then
    toolbar.popup(toolbar.DIALOG_POPUP,toolbar.PSHOW.DRAW,btname,anchor,-dialog_w,-dialog_h) --anchor to a button (toolbar.ANCHOR) (use custom dialog borders)
  else
    toolbar.show_dialog() --open at a fixed position
  end
end

local fdialog_opt= ""
local fdialog_currdir= ""
local fdialog_brow_dir= ""
local function file_sort(filea,fileb)
  local pa,fa,ea = Util.splitfilename(filea)
  local pb,fb,eb = Util.splitfilename(fileb)
  if pa == pb then return fa < fb end
  return pa < pb
end

local ncd_butt= 1
local function b_change_dir(cmd)
  ncd_butt= 1
  for i=1,#dialog_buttons do
    if dialog_buttons[i][1] == cmd then
      ncd_butt=i
      if dialog_buttons[i][8] & toolbar.DLGBUT.EN_OFF ~= 0 then return end  --the button is disabled
      break
    end
  end
  --change current dir
  if fdialog_opt ~= "" then toolbar.selected(fdialog_opt, false, false, true) end --unmark old option
  fdialog_opt= cmd
  toolbar.selected(fdialog_opt, false, true, true) --mark new option
  toolbar.dlg_select_it= ""
  --clear filter
  filter= ""
  update_filter()
  --load file list
  dialog_list= {}
  local nrec= 0
  if (toolbar.keyflags & toolbar.KEYFLAGS.SHIFT) ~= 0 then nrec= 1  --SHIFT+click= 1 level recursion
  elseif (toolbar.keyflags & toolbar.KEYFLAGS.CONTROL) ~= 0 then nrec= nil end --CONTROL+click= full recursion
  if fdialog_opt == "fdlg-project" then
    --project files (ignore shift/control modifiers)
    if Proj and Proj.data.is_open then
      for r=1,#Proj.data.proj_files do
        local ft= Proj.data.proj_filestype[r]
        if ft == Proj.PRJF_FILE or ft == Proj.PRJF_CTAG then
          dialog_list[ #dialog_list+1 ]= Proj.data.proj_files[r]
        end
      end
    end
  elseif fdialog_opt == "fdlg-browdir" then
    if fdialog_brow_dir ~= "" then
      for file in lfs.walk(fdialog_brow_dir, lfs.default_filter, nrec, false) do
        dialog_list[ #dialog_list+1 ]= file:iconv('UTF-8', _CHARSET)
      end
      if nrec == 0 then
        --show all open dirs in browse panel
        local of= toolbar.get_filebrowser_openfolders()
        for fdir,_ in pairs(of) do
          for file in lfs.walk(fdir, lfs.default_filter, nrec, false) do
            dialog_list[ #dialog_list+1 ]= file:iconv('UTF-8', _CHARSET)
          end
        end
      end
      table.sort(dialog_list, file_sort)
    end
  else
    --walk folder
    local fdir= _USERHOME
    if fdialog_opt == "fdlg-ta-home" then fdir= _HOME
    elseif fdialog_opt == "fdlg-currdir" then fdir= fdialog_currdir end
    for file in lfs.walk(fdir, lfs.default_filter, nrec, false) do
      dialog_list[ #dialog_list+1 ]= file:iconv('UTF-8', _CHARSET)
    end
    table.sort(dialog_list, file_sort)
  end
  load_data(false)
end

local function fdlg_item_selected(fname)
  Proj.go_file( fname )
  --keep dialog open if SHIFT or CONTROL is pressed
  return (toolbar.keyflags & (toolbar.KEYFLAGS.CONTROL|toolbar.KEYFLAGS.SHIFT) ~= 0)
end

local n_fdlg_opts= 5  --number of "fdlg-xxx" buttons
local function fdialog_prev_tab(cmd)
  local n= ncd_butt
  repeat
    n= n-1
    if n < 1 then n= n_fdlg_opts end
  until dialog_buttons[n][8] & toolbar.DLGBUT.EN_OFF == 0 --skip disabled buttons
  b_change_dir(dialog_buttons[n][1])
end
local function fdialog_next_tab(cmd)
  local n= ncd_butt
  repeat
    n= n+1
    if n > n_fdlg_opts then n= 1 end
  until dialog_buttons[n][8] & toolbar.DLGBUT.EN_OFF == 0 --skip disabled buttons
  b_change_dir(dialog_buttons[n][1])
end
local function fdialog_basic_reload(cmd)
  b_change_dir(dialog_buttons[ncd_butt][1]) --no recursion reload
  toolbar.keyflags= 0
end
local function fdialog_1level_reload(cmd)
  toolbar.keyflags= toolbar.KEYFLAGS.SHIFT  --1 level recursion reload
  fdialog_basic_reload(cmd)
end
local function fdialog_full_rec(cmd)
  toolbar.keyflags= toolbar.KEYFLAGS.CONTROL  --full recursion reload
  fdialog_basic_reload(cmd)
end

local function fdialog_brow_sel_folder(cmd)
  local folder = ui.dialogs.fileselect{ title = 'Select folder', select_only_directories = true, with_directory = fdialog_brow_dir }
  if folder then
    toolbar.set_filebrowser_dir(folder)
  end
  toolbar.file_chooser(5) --reopen the dialog
end

function toolbar.file_chooser(option, title)
  local flist= {}
  local dconfig= {}
  fdialog_currdir= ""
  fdialog_brow_dir=""
  local enbr= toolbar.DLGBUT.EN_OFF
  local fname= buffer.filename
  if fname then fdialog_currdir=fname:match('^(.+)[/\\]') end
  local isprj= (Proj and Proj.data.is_open)
  if toolbar.get_filebrowser_dir then fdialog_brow_dir= toolbar.get_filebrowser_dir() enbr=0 end
  local click_info= "\n  Click / Control+R= no sub-folders reload\n  Shift+Click / Control+1= 1 sub-folder reload\n  Control+Click / Control+A= all sub-folders reload"
  local buttons= {
    --1:bname, 2:text/icon, 3:tooltip, 4:x, 5:width, 6:row, 7:callback, 8:button-flags=toolbar.DLGBUT..., 9:key-accel
    {"fdlg-project", "Project", "Project files", 5, 95, 1, b_change_dir, isprj and 0 or toolbar.DLGBUT.EN_OFF, "Control+P"},
    {"fdlg-user",    "User home", _USERHOME..click_info, 105, 95, 1, b_change_dir, 0, "Control+U"},
    {"fdlg-ta-home", "TA home", _HOME..click_info, 205, 95, 1, b_change_dir, 0, "Control+T"},
    {"fdlg-currdir", "Current", fdialog_currdir..click_info, 305, 95, 1, b_change_dir, (fdialog_currdir~="") and 0 or toolbar.DLGBUT.EN_OFF, "Control+C"},
    {"fdlg-browdir", "File browser", fdialog_brow_dir..click_info, 405, 95, 1, b_change_dir, enbr, "Control+F"},
    {"fdlg-change-browdir", "document-open", "Select folder", 505, 24, 1, fdialog_brow_sel_folder, enbr|toolbar.DLGBUT.ICON|toolbar.DLGBUT.CLOSE, "Control+O"},
    {"acc-fdlg-ntab", "", "", 0, 0, 0, fdialog_next_tab, 0, "\t"}, --accelerators
    {"acc-fdlg-ptab", "", "", 0, 0, 0, fdialog_prev_tab, 0, "Shift+\t"},
    {"acc-fdlg-0reload", "", "", 0, 0, 0, fdialog_basic_reload, 0, "Control+R"}, --no recursion reload
    {"acc-fdlg-1reload", "", "", 0, 0, 0, fdialog_1level_reload, 0, "Control+1"}, --1 level recursion reload
    {"acc-fdlg-reload", "", "", 0, 0, 0, fdialog_full_rec, 0, "Control+A"}  --full recursion reload
  }
  dconfig.can_move= true  --allow to move
  dconfig.buttons= buttons
  toolbar.dlg_select_it= ""
  toolbar.dlg_select_ev= fdlg_item_selected
  toolbar.dlg_filter_col2= false
  toolbar.create_dialog(title or "File chooser", 600, 400, flist, "MIME", dconfig)
  if not option or option < 1 or option > #buttons then option= (isprj) and 1 or 2 end
  b_change_dir(buttons[option][1])
  toolbar.show_dialog()
end

--ACTION: quick_browse
local function quick_browse()
  toolbar.file_chooser(5)
end
actions.add("quick_browse", 'Quickly Open Browse Directory', quick_browse, Util.KEY_ALT.."O")

local function dlg_find_next()
  actions.run("match_next")
end
local function dlg_find_prev()
  actions.run("match_prev")
end
local function dlg_enter()
  --enter= next / shift+enter= previous
  if (toolbar.keyflags & toolbar.KEYFLAGS.SHIFT) ~= 0 then dlg_find_prev() else dlg_find_next() end
  return true --don't close
end

local find_flags= {}
find_flags["dlg-find-case"]= true --set defaults modifiers

local function dlg_mod(cmd)
  local flg= find_flags[cmd] or false
  flg= not flg
  find_flags[cmd]= flg
  toolbar.selected(cmd, false, flg)
end
local function set_dlg_mod(cmd)
  toolbar.selected(cmd, false, find_flags[cmd] or false)
end
function toolbar.find_dialog()
  if finddlgopen then
    finddlgopen= false
    toolbar.popup(toolbar.DIALOG_POPUP,toolbar.PSHOW.HIDE)
  else
    toolbar.dlg_select_it= ""
    toolbar.dlg_select_ev= dlg_enter
    toolbar.dlg_filter_col2= false
    local width= 500
    local height= 59
    local dconfig= {editmode= true, filter_empty_text="Text to find"}
    local buttons= {
      {"dlg-find-next", "go-down", "Next [Enter] /", 0, 0, -1, dlg_find_next, toolbar.DLGBUT.ICON, "F3"},
      {"dlg-find-prev", "go-up", "Previous [Shift+Enter] /", 0, 0, -1, dlg_find_prev, toolbar.DLGBUT.ICON, "Control+F3"},
      {"dlg-find-increm", "mod-increm", "Incremental", 0, 0, -1, dlg_mod, toolbar.DLGBUT.ICON, "Control+I"},
      {"dlg-find-regexp", "mod-regexp", "Regular expression", 0, 0, -1, dlg_mod, toolbar.DLGBUT.ICON, "Control+R"},
      {"dlg-find-word", "mod-word", "Whole word", 0, 0, -1, dlg_mod, toolbar.DLGBUT.ICON, "Control+W"},
      {"dlg-find-case", "mod-case", "Match case", 0, 0, -1, dlg_mod, toolbar.DLGBUT.ICON, "Control+A"}
    }
    dconfig.buttons= buttons
    toolbar.create_dialog("Find", width, height, {}, "edit-find", dconfig)
    local anchor= toolbar.ANCHOR.POP_L_IT_L | toolbar.ANCHOR.POP_T_IT_B
    toolbar.popup(toolbar.DIALOG_POPUP,toolbar.PSHOW.DRAW|toolbar.PSHOW.KEEPOPEN,"find_dialog",anchor,-width,-height)
    finddlgopen= true
    set_dlg_mod("dlg-find-increm")
    set_dlg_mod("dlg-find-regexp")
    set_dlg_mod("dlg-find-word")
    set_dlg_mod("dlg-find-case")
  end
  toolbar.selected("find_dialog", false, finddlgopen)
end

--ACTION: find_dialog
actions.add("find_dialog", "Open find dialog", toolbar.find_dialog, Util.KEY_CTRL.."f1", "edit-find")
