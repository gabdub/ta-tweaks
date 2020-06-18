-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
--functions to define common controls like buttons, combo-boxes, etc in the toolbars
local events, events_connect = events, events.connect

--buttons callback functions
toolbar.cmds={}     --functions without the name of the clicked button as an argument
toolbar.cmds_n={}   --functions with the name of the clicked button as an argument
toolbar.cmds_d={}   --functions with the name of the double clicked button as an argument
toolbar.cmds_r={}   --functions with the name of the right clicked button as an argument

--config panel values
toolbar.cfgpnl_chkval={}    --checks/radios value
toolbar.cfgpnl_chknotify={} --checks/radios callbacks

local function rm_namenum(buttonname)
  --"name#num" --> "name"
  local bname,lnum= string.match(buttonname,"(.-)#(.*)")
  if bname then return bname end
  return buttonname
end

function toolbar.getnum_cmd(cmd)
  if cmd then return tonumber(string.match(cmd,".-#(.*)")) end
end

--define a graphical toolbar button
function toolbar.cmd(name,func,tooltip,icon,passname,base)
  toolbar.addbutton(name,tooltip,base)
  if passname then toolbar.cmds_n[name]= func else toolbar.cmds[name]= func end
  if icon == nil then
    toolbar.setthemeicon(name,name) --no icon: use 'name' from theme
  elseif string.match(icon,"%.png") == nil then
    toolbar.setthemeicon(name,icon) --no ".png": use 'icon' from theme
  else
    toolbar.seticon(name,icon,toolbar.TTBI_TB.IT_NORMAL)  --"icon.png": use the given icon file
  end
end

--define a text toolbar button
function toolbar.cmdtext(text,func,tooltip,name,usebutsz,dropbt,leftalign,bold)
  if not name then name=text end
  local w=0
  if usebutsz then w=toolbar.cfg.butsize end
  toolbar.addtext(name,text,tooltip,w,dropbt,leftalign,bold)
  toolbar.cmds[name]= func
end

--define a combo-box using a pop-up toolbar
local combo_open= 0 --1:open 2:open + auto-close (timer running)
local combo_op_name= ""
local function end_combo_select()
  if combo_op_name ~= "" then
    toolbar.selected(combo_op_name, false, false)
    combo_op_name= ""
  end
  combo_open= 0
end

local function end_combo_open()
  if combo_open == 2 then end_combo_select() end
  return false
end

local function closepopup(npop)
  toolbar.popup(npop,false) --hide popup
  if npop == toolbar.COMBO_POPUP and combo_open == 1 then
    end_combo_select()
    combo_open= 2 --auto-close
    timeout(1,end_combo_open)
  end
end
events_connect("popup_close", closepopup)

local combo_data= {}
local combo_width= {}
local combo_func= {}
local combo_txt= {}
local function combo_clicked(btname)
  end_combo_select()
  closepopup(5)
  local cname, cval= string.match(btname, "(.-)#(.+)$")
  if cname then
    local newidx= tonumber(cval)
    local newtxt= combo_data[cname][newidx]
    combo_txt[cname]= newtxt
    toolbar.settext(cname, newtxt)
    local cback= combo_func[name]
    if cback then cback(cname, newidx, newtxt) end
  end
end

function toolbar.get_combo_txt(name)
  return combo_txt[name]
end

local function show_combo_list(btname)
  if combo_open > 0 then
    end_combo_select()
    return
  end
  combo_open= 1
  combo_op_name= btname
  toolbar.selected(combo_op_name, false, true)
  toolbar.new(27, 24, 16, toolbar.COMBO_POPUP, toolbar.themepath)
  toolbar.addgroup(toolbar.GRPC.ITEMSIZE, toolbar.GRPC.ITEMSIZE|toolbar.GRPC.VERT_SCROLL,0,0)
  toolbar.adjust(24,24,3,3,0,0)
  toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
  toolbar.themed_icon(toolbar.globalicon, "ttb-combo-list",     toolbar.TTBI_TB.BACKGROUND)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-hilight", toolbar.TTBI_TB.BUT_HILIGHT)
  toolbar.themed_icon(toolbar.globalicon, "ttb-button-press",   toolbar.TTBI_TB.BUT_HIPRESSED)
  toolbar.themed_icon(toolbar.globalicon, "ttb-combo-selected", toolbar.TTBI_TB.BUT_SELECTED)

  local currit= combo_txt[btname]
  for i=1,#combo_data[btname] do
    local itname= btname.."#"..i
    local ittxt= combo_data[btname][i]
    toolbar.addtext(itname,ittxt,"",282,false,true)
    if ittxt == currit then toolbar.selected(itname, false, true) end
    toolbar.cmds_n[itname]= combo_clicked
  end
  toolbar.popup(toolbar.COMBO_POPUP,true,btname,35,combo_width[btname]-2)
end

function toolbar.cmd_combo(name,func,tooltip,txtarray,txtval,width,bold)
  if idx == 0 then idx=1 end
  if width == 0 then width=300 end --configure this
  combo_data[name]= txtarray
  combo_width[name]= width
  if not txtval then txtval= txtarray[1] end
  combo_txt[name]= txtval
  toolbar.addtext(name,txtval,tooltip,width,true,true,bold) --show current value
  toolbar.cmds_n[name]= show_combo_list --pass the combo name when clicked
  combo_func[name]= func
end

function toolbar.set_combo_txt(name, txtval,dontset_toolbar)
  combo_txt[name]= txtval
  if not dontset_toolbar then toolbar.settext(name, txtval) end
end

events_connect("toolbar_clicked", function(buttonname,ntoolbar)
  if toolbar.cmds_n[buttonname] ~= nil then
    toolbar.cmds_n[buttonname](buttonname) --pass the name of the button
  elseif toolbar.cmds[buttonname] ~= nil then
    --is a config checkbox?
    if toolbar.cfgpnl_chkval ~= nil and toolbar.cfgpnl_chkval[buttonname] ~= nil then
      toolbar.cmds[buttonname](buttonname) --pass the name of the checkbox
    else
      toolbar.cmds[buttonname]()
    end
--  else ui.statusbar_text= buttonname.." clicked"
  end
end)

function toolbar.cmd_dclick(name,func)
  --connect to double click
  toolbar.cmds_d[ rm_namenum(name) ]= func
end

events_connect("toolbar_2clicked", function(buttonname,ntoolbar)
  local bfunc= rm_namenum(buttonname) --"name#num" --> "name"
  --pass the complete name of the button ("name#num")
  if toolbar.cmds_d[bfunc] ~= nil then return toolbar.cmds_d[bfunc](buttonname) end
end)

function toolbar.cmd_rclick(name,func)
  --open a context menu over this item
  toolbar.cmds_r[ rm_namenum(name) ]= func
end

events_connect("toolbar_Rclicked", function(buttonname,ntoolbar)
  local bfunc= rm_namenum(buttonname) --"name#num" --> "name"
  --pass the complete name of the button ("name#num")
  if toolbar.cmds_r[bfunc] ~= nil then return toolbar.cmds_r[bfunc](buttonname) end
end)

--checks/radios
function toolbar.clear_checks_vars()
  toolbar.cfgpnl_chkval={}
  toolbar.cfgpnl_chknotify={}
end

function toolbar.set_notify_on_change(name,func)
  toolbar.cfgpnl_chknotify[name]=func
end

function toolbar.set_check_val(name,checked,dontset_toolbar)
  toolbar.cfgpnl_chkval[name]= checked
  if not dontset_toolbar then toolbar.selected(name, checked) end
end

function toolbar.get_check_val(name)
  if toolbar.cfgpnl_chkval[name] then return true end
  return false
end

local function check_clicked(name)
  --toggle checkbox value
  toolbar.set_check_val(name, not toolbar.get_check_val(name))
  toolbar.config_change=true
  if toolbar.cfgpnl_chknotify[name] ~= nil then toolbar.cfgpnl_chknotify[name]() end
end

function toolbar.cmd_check(name,tooltip,checked)
  toolbar.cmd(name, check_clicked, tooltip, nil, nil, toolbar.TTBI_TB.CHECK_BASE)
  toolbar.selected(name, checked)
  toolbar.cfgpnl_chkval[name]=checked
end

local function radio_clicked(name,dontset_toolbar,dont_notify)
  --set new radio button value
  toolbar.cfgpnl_chkval[name]= true
  if not dontset_toolbar then toolbar.selected(name, true) end
  --reset the others (same rname in "rname:option-value")
  local rname=string.match(name, "(.-):.+$")
  if rname then
    local i=1
    while toolbar.cfgpnl_chkval[rname..':'..i] ~= nil do
      local rbn=rname..':'..i
      if name ~= rbn and toolbar.cfgpnl_chkval[rbn] then
        toolbar.cfgpnl_chkval[rbn]= false
        if not dontset_toolbar then toolbar.selected(rbn, false) end
      end
      i=i+1
    end
  end
  toolbar.config_change=true
  if (not dont_notify) and (toolbar.cfgpnl_chknotify[rname] ~= nil) then
    toolbar.cfgpnl_chknotify[rname]()
  end
end

function toolbar.cmd_radio(name,tooltip,checked)
  toolbar.cmd(name, radio_clicked, tooltip, nil, nil, toolbar.TTBI_TB.RADIO_BASE)
  toolbar.selected(name, checked)
  toolbar.cfgpnl_chkval[name]=checked
end

function toolbar.set_radio_val(name,val,dontset_toolbar,maxnum)
  if maxnum then --create all missing items
    local i=1
    while i <= maxnum do
      if toolbar.cfgpnl_chkval[name..':'..i] == nil then
        toolbar.cfgpnl_chkval[name..':'..i]=false
      end
      i=i+1
    end
  end
  radio_clicked(name..":"..val,dontset_toolbar,true)
end

function toolbar.get_radio_val(name,maxnum)
  local i=1
  if maxnum then
    while i <= maxnum do
      if toolbar.cfgpnl_chkval[name..':'..i] then
        return i
      end
      i=i+1
    end
  else
    while toolbar.cfgpnl_chkval[name..':'..i] ~= nil do
      if toolbar.cfgpnl_chkval[name..':'..i] then
        return i
      end
      i=i+1
    end
  end
  return 0
end

function toolbar.top_right_resize_handle(rzname, wmin, func)  --add a resize handle
  toolbar.gotopos(0, 0)
  toolbar.addbutton(rzname,"Resize panel")
  toolbar.anchor(rzname, 25) --anchor to the right
  toolbar.setresize(rzname, true, wmin) --horizontal resize button
  toolbar.cmds[rzname]= func
  toolbar.setthemeicon(rzname, "transparent",       toolbar.TTBI_TB.IT_NORMAL)
  toolbar.setthemeicon(rzname, "resize-tr",         toolbar.TTBI_TB.BACKGROUND)
  toolbar.setthemeicon(rzname, "resize-tr-hilight", toolbar.TTBI_TB.IT_HILIGHT)
  toolbar.setthemeicon(rzname, "resize-tr-hilight", toolbar.TTBI_TB.IT_HIPRESSED)
end

function toolbar.set_expand_icon(cmd,icon)
  toolbar.setthemeicon(cmd, icon, toolbar.TTBI_TB.IT_NORMAL)
  toolbar.setthemeicon(cmd, icon.."-hilight", toolbar.TTBI_TB.IT_HILIGHT)
  toolbar.setthemeicon(cmd, icon.."-hilight", toolbar.TTBI_TB.IT_HIPRESSED)
end

---- LIST ---
toolbar.listtb_y= 1
toolbar.listtb_x= 3
toolbar.list_cmdright= 18
toolbar.listright= 250

function toolbar.list_addbutton(name, tooltip, funct)
  toolbar.gotopos( 0, toolbar.listtb_y)
  toolbar.cmd(name, funct, tooltip or "", name, true)
  toolbar.list_cmdright= toolbar.list_cmdright + toolbar.cfg.butsize
  toolbar.anchor(name, toolbar.list_cmdright) --anchor to the right
end

function toolbar.list_addaction(action)
  toolbar.gotopos( 0, toolbar.listtb_y)
  toolbar.addaction(action)
  toolbar.list_cmdright= toolbar.list_cmdright + toolbar.cfg.butsize
  toolbar.anchor(action, toolbar.list_cmdright) --anchor to the right
end

local lbl_n= 0
function toolbar.list_addinfo(text,bold)
  --add a text to the list
  toolbar.gotopos(toolbar.listtb_x, toolbar.listtb_y)
  lbl_n= lbl_n+1
  local name= "_lbl_"..lbl_n
  toolbar.addlabel(text, "", toolbar.listright, true, bold, name)
  toolbar.listtb_y= toolbar.listtb_y + toolbar.cfg.butsize
  toolbar.list_cmdright= 18
  toolbar.anchor(name, toolbar.list_cmdright, true)
  toolbar.listtb_x= 3
  return name
end

function toolbar.list_add_txt_ico(name, text, tooltip, bold, click_fun, bicon, evenrow, indent, idlen, open_hi, lstwidth)
  if not idlen then idlen=0 end
  if idlen > 0 then indent= indent + 10 end --add a collapse icon
  local xtxt= indent
  if bicon then xtxt= indent + toolbar.cfg.barsize end
  toolbar.gotopos(3, toolbar.listtb_y)
  toolbar.addtext(name, text, tooltip, lstwidth, false, true, bold, xtxt, 0)
  if evenrow then toolbar.setbackcolor(name, toolbar.cfg.backcolor_erow,false,true) end
  toolbar.anchor(name, 10, true)
  if bicon then
    if open_hi > 0 then  --open/closed file highlight
      toolbar.adjust(toolbar.cfg.butsize+4,toolbar.cfg.butsize,3,3,4,4)
      toolbar.gotopos(3 + indent, toolbar.listtb_y)
      local iobut= "open-"..name
      toolbar.cmd(iobut, nil, "", (open_hi == 1) and "open-back" or "closed-back", true)
      toolbar.enable(iobut,false,false) --non-selectable image
      toolbar.adjust(toolbar.cfg.butsize,toolbar.cfg.butsize,3,3,4,4)
    end
    toolbar.gotopos(3 + indent, toolbar.listtb_y)
    local icbut= "ico-"..name
    toolbar.cmd(icbut, nil, "", bicon, true)
    toolbar.enable(icbut,false,false) --non-selectable image
  end
  toolbar.cmds_n[name]= click_fun
  if idlen > 0 then return true end --toolbar.list_add_collapse() must be called
  toolbar.listtb_y= toolbar.listtb_y + toolbar.cfg.butsize
end

function toolbar.list_add_collapse(name, click_fun, indent, hide_nrows, colla_tab)
  toolbar.gotopos( indent+3, toolbar.listtb_y)
  local exbut= "exp-"..name
  toolbar.cmd(exbut, click_fun, "", "list-colapse2", true)
  toolbar.set_expand_icon(exbut,"list-colapse2")
  toolbar.collapse(exbut, false, toolbar.cfg.butsize * hide_nrows, true)
  colla_tab[exbut]= false
  toolbar.listtb_y= toolbar.listtb_y + toolbar.cfg.butsize
end

function toolbar.list_add_separator()
  toolbar.gotopos(3, toolbar.listtb_y)
  toolbar.addspace()
  toolbar.listtb_y= toolbar.listtb_y + toolbar.cfg.butsize/2
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
    local eh= string.match(e, "^(.-):head")
    if eh then e=eh end --remove ":head" from extension
    local icon= toolbar.icon_ext[e]
    if icon then return toolbar.icon_ext_path..icon..".png" end
    if f == "makefile" then return toolbar.icon_ext_path.."text-x-makefile.png" end
    if f == "readme" then return toolbar.icon_ext_path.."text-x-readme.png" end
  end
  return toolbar.icon_ext_path.."text-plain.png"
end
