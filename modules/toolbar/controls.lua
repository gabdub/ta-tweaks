-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.
--functions to define common controls like buttons, combo-boxes, etc in the toolbars
local events, events_connect = events, events.connect
local tbglobalicon="TOOLBAR"

--buttons callback functions
toolbar.cmds={}     --functions without the name of the clicked button as an argument
toolbar.cmds_n={}   --functions with the name of the clicked button as an argument

--config panel values
toolbar.cfgpnl_chkval={}    --checks/radios value
toolbar.cfgpnl_chknotify={} --checks/radios callbacks

--define a graphical toolbar button
function toolbar.cmd(name,func,tooltip,icon,passname)
  toolbar.addbutton(name,tooltip)
  if passname then toolbar.cmds_n[name]= func else toolbar.cmds[name]= func end
  if icon == nil then
    toolbar.setthemeicon(name,name) --no icon: use 'name' from theme
  elseif string.match(icon,"%.png") == nil then
    toolbar.setthemeicon(name,icon) --no ".png": use 'icon' from theme
  else
    toolbar.seticon(name,icon,toolbar.TTBI_TB.NORMAL)  --"icon.png": use the given icon file
  end
end

--define a text toolbar button
function toolbar.cmdtext(text,func,tooltip,name,usebutsz,dropbt)
  if not name then name=text end
  local w=0
  if usebutsz then w=toolbar.cfg.butsize end
  toolbar.addtext(name,text,tooltip,w,dropbt)
  toolbar.cmds[name]= func
end

--define a combo-box using a pop-up toolbar
local combo_open= 0 --1:open 2:open + auto-close (timer running)
local function end_combo_open()
  if combo_open == 2 then combo_open= 0 end
  return false
end

local function closepopup(npop)
  toolbar.popup(npop,false) --hide popup
  if npop == 5 and combo_open == 1 then
    combo_open= 2 --auto-close
    timeout(1,end_combo_open)
  end
end
events_connect("popup_close", closepopup)

local function combo_clicked(btname)
  combo_open= 0
  closepopup(5)
  ui.statusbar_text= btname.." clicked"
end

local combo_data= {}
local combo_width= {}
local function show_combo_list(btname)
  if combo_open > 0 then
    combo_open= 0
    return
  end
  combo_open= 1
  toolbar.new(27, 24, 16, 5, toolbar.themepath)
  toolbar.addgroup(8,8,0,0)
  toolbar.adjust(24,27,3,3,0,0)
  toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
  toolbar.themed_icon(tbglobalicon, "ttb-combo", toolbar.TTBI_TB.NORMAL, true)
  for i=1,#combo_data[btname] do
    local itname= btname.."#"..i
    toolbar.addtext(itname,combo_data[btname][i],"",282)
    toolbar.cmds_n[itname]= combo_clicked
  end
  toolbar.adjust(24,27,0,0,0,0)
  toolbar.popup(5,true,btname,35,combo_width[btname]-2)
end

function toolbar.cmd_combo(name,func,tooltip,txtarray,idx,width)
  if idx == 0 then idx=1 end
  if width == 0 then width=300 end --configure this
  combo_data[name]= txtarray
  combo_width[name]= width
  toolbar.addtext(name,txtarray[idx],tooltip,width,true) --show current value
  toolbar.cmds_n[name]= show_combo_list --pass the combo name when clicked
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
  else
    ui.statusbar_text= buttonname.." clicked"
  end
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
  if checked then
    toolbar.cfgpnl_chkval[name]= true
    if not dontset_toolbar then toolbar.setthemeicon(name, "check1") end
  else
    toolbar.cfgpnl_chkval[name]= false
    if not dontset_toolbar then toolbar.setthemeicon(name, "check0") end
  end
end

function toolbar.get_check_val(name)
  if toolbar.cfgpnl_chkval[name] then
    return true
  end
  return false
end

local function check_clicked(name)
  --toggle checkbox value
  toolbar.set_check_val(name, not toolbar.get_check_val(name))
  toolbar.config_change=true
  if toolbar.cfgpnl_chknotify[name] ~= nil then
    toolbar.cfgpnl_chknotify[name]()
  end
end

function toolbar.cmd_check(name,tooltip,checked)
  toolbar.cmd(name, check_clicked, tooltip, (checked and "check1" or "check0"))
  toolbar.setthemeicon(name, "check-hi", toolbar.TTBI_TB.HILIGHT)
  toolbar.setthemeicon(name, "check-pr", toolbar.TTBI_TB.HIPRESSED)
  toolbar.cfgpnl_chkval[name]=checked
end

local function radio_clicked(name,dontset_toolbar,dont_notify)
  --set new radio button value
  toolbar.cfgpnl_chkval[name]= true
  if not dontset_toolbar then toolbar.setthemeicon(name, "radio1") end
  --reset the others (same rname in "rname:option-value")
  local rname=string.match(name, "(.-):.+$")
  if rname then
    local i=1
    while toolbar.cfgpnl_chkval[rname..':'..i] ~= nil do
      local rbn=rname..':'..i
      if name ~= rbn and toolbar.cfgpnl_chkval[rbn] then
        toolbar.cfgpnl_chkval[rbn]= false
        if not dontset_toolbar then toolbar.setthemeicon(rbn, "radio0") end
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
  toolbar.cmd(name, radio_clicked, tooltip, (checked and "radio1" or "radio0"))
  toolbar.setthemeicon(name, "radio-hi", toolbar.TTBI_TB.HILIGHT)
  toolbar.setthemeicon(name, "radio-pr", toolbar.TTBI_TB.HIPRESSED)
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
