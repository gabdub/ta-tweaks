-- Copyright 2016-2022 Gabriel Dubatti. See LICENSE.
--
-- This module overwrites ui._print() to display its output in the "results" toolbar
--
-- ** This module is used when USE_RESULTS_PANEL is true **
--
if toolbar then
  local itemsgrp
  local selitem=0
  local nitems= 0
  local yout= 1
  local fullprint= {} --copy all

  local function print_create()
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_results_bar(itemsgrp)
    toolbar.setdefaulttextfont()
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
    if name == "edit-clear" then toolbar.print_clear()
    elseif name == "edit-select-all" then buffer:copy_text(table.concat(fullprint,'\n'))
    elseif name == "edit-copy" then if selitem > 0 then buffer:copy_text(fullprint[selitem]) end
    end
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

  local function get_fileerror(ln)
    local fname, linenum, errtxt= string.match(ln, 'lua:%s(.-):(%d*):%s(.*)')
    if not fname then
      --try with incomplete path ".../path/../fname.lua:linenum: error description"
      fname, linenum, errtxt= string.match(ln, '%.%.%.(.-):(%d*):%s(.*)')
      if fname then
        if Proj.data.is_open then
          --try to complete the path
          local lenfname= #fname
          for k,v in ipairs(Proj.data.proj_files) do
            if #v > lenfname then
              if fname == string.sub(v,-lenfname) then
                fname= v  --found, open this file
                break
              end
            end
          end
        end
      end
    end
    if fname and Util.file_exists(fname) then
      return fname, linenum, errtxt
    end
    return nil
  end

  local function print_dclick(name) --double click= copy row
    --lua error: "lua: /path/../fname.lua:linenum: error description" ==> goto error
    local ln= fullprint[toolbar.getnum_cmd(name)]
    local fname, linenum, errtxt= get_fileerror(ln)
    if fname then
      ui.statusbar_text= "> "..errtxt
      Proj.go_file(fname, linenum)
    else
      ui.statusbar_text= "Text copied to clipboard"
      buffer:copy_text(ln)
    end
  end

  toolbar.print_console_icon= false

  function toolbar.print_result(ml_txt)
    local savect= toolbar.current_toolbar --save current toolbar/group
    local savecg= toolbar.current_tb_group
    toolbar.sel_results_bar(itemsgrp)
    local name, firstname
    local firstitem= nitems+1
    for txt in ml_txt:gmatch("[^\r\n]+") do --split lines
      nitems= nitems+1
      name= get_rowname(nitems)
      if firstname == nil then firstname= name end
      toolbar.listtb_y= yout
      fullprint[#fullprint+1]= txt
      local icon= nil
      if toolbar.print_console_icon then
        toolbar.print_console_icon= false
        icon= toolbar.icon_ext_path.."text-x-script.png"  --mark console commands
      else
        local fname, linenum, errtxt= get_fileerror(txt)
        if fname then icon="lpi-bug" end  --mark lua errors (d-click jumps to error)
      end
      if #txt > 2000 then txt= txt:sub(1,2000).."..." end
      txt= string.gsub(txt, '\t', ' ') --replace tabs with spaces
      local oneline= txt --Util.str_one_line(txt)
      if #oneline > 200 then oneline= oneline:sub(1,200).."..." end
      toolbar.list_add_txt_ico(name, oneline, txt, false, print_click, icon, false, 0, 0, 0, 250)
      yout= yout + toolbar.cfg.butsize
    end
    toolbar.showresults("printresults")
    toolbar.ensurevisible(firstname)
    select_printrow(firstitem)
    toolbar.sel_toolbar_n(savect, savecg, false)  --restore current toolbar/group
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
