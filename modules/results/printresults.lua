-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.

if toolbar then
  local itemsgrp
  local selitem=0
  local nitems= 0
  local yout= 1
  local fullprint= {} --copy all

  local function print_create()
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_results_bar(itemsgrp)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
  end

  local function get_rowname(n)
    return "prt-item#"..n
  end

  local function print_notify(switching)
    if selitem > 0 then toolbar.ensurevisible(get_rowname(selitem)) end
  end

  local function print_showlist(show)
    --show/hide list items
    toolbar.sel_results_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  function toolbar.print_clear()
    --remove all items
    toolbar.sel_results_bar(itemsgrp,true) --empty items group
    nitems= 0
    yout= 1
    fullprint= {}
    selitem=0
  end

  --"edit-clear" / "edit-copy"
  local function print_act(name)
    if name == "edit-clear" then toolbar.print_clear() end
    if name == "edit-copy"  then buffer:copy_text(table.concat(fullprint,'\n')) end
  end

  local function select_printrow(n)
    --restore previously selected row
    toolbar.sel_results_bar(itemsgrp)
    if selitem > 0 then toolbar.setbackcolor(get_rowname(selitem), (selitem%2==1) and toolbar.cfg.backcolor_erow or -1,false,true) end
    selitem= n --highlight new
    toolbar.setbackcolor(get_rowname(n), toolbar.cfg.backcolor_hi,false,true)
  end

  local function print_click(name) --click= select row
    select_printrow(toolbar.getnum_cmd(name))
  end

  local function print_dclick(name) --double click= copy row
    buffer:copy_text(fullprint[toolbar.getnum_cmd(name)])
  end

  function toolbar.print_result(txt)
    nitems= nitems+1
    toolbar.sel_results_bar(itemsgrp)
    local name= get_rowname(nitems)
    toolbar.listtb_y= yout
    fullprint[#fullprint+1]= txt
    if #txt > 2000 then txt= txt:sub(1,2000).."..." end
    local oneline= Util.str_one_line(txt)
    if #oneline > 200 then oneline= oneline:sub(1,200).."..." end
    toolbar.list_add_txt_ico(name, oneline, txt, true, print_click, nil, false, 0, 0, 0)
    yout= yout + toolbar.cfg.butsize
    toolbar.showresults("printresults")
    toolbar.ensurevisible(name)
    select_printrow(nitems)
  end

  -------- overwrite default ui._print function -----
  -- Helper function for printing messages to buffers.
  local function proj_print(buffer_type, ...)
    --show in the results panel
    local args, n = {...}, select('#', ...)
    for i = 1, n do args[i] = tostring(args[i]) end
    toolbar.print_result(table.concat(args, '  '))
  end
  function ui._print(buffer_type, ...) pcall(proj_print, buffer_type, ...) end
  -------------------------------------------------------

  toolbar.registerresultstb("printresults", "Console output", "system-lock-screen", print_create, print_notify, print_showlist, print_act)
  toolbar.cmd_dclick("prt-item",print_dclick)
end
