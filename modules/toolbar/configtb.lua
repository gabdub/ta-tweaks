toolbar.CONFIG_FILE = _USERHOME..'/toolbar_config'
toolbar.cfgpnl_chkval={}
toolbar.cfgpnl_chknotify={}
toolbar.cfgpnl_lexer_indent={}
toolbar.cfgpnl_colors={}
toolbar.cfgpnl_savelst={}
toolbar.config_saveon=false
toolbar.config_change=false

function toolbar.toggle_showconfig()
  --toggle shown state
  if toolbar.config_toolbar_shown then
    toolbar.config_toolbar_shown= false
    -- Save configuration changes
    toolbar.save_config()
  else
    toolbar.config_toolbar_shown= true
    --update current buffer config
    toolbar.set_buffer_cfg()
  end
  --update icon/menu
  actions.updateaction("toggle_viewcfgpanel")
  toolbar.sel_config_bar()
  toolbar.show(toolbar.config_toolbar_shown)
end

function toolbar.hide_config()
  if toolbar.config_toolbar_shown then
    toolbar.toggle_showconfig()
    return true
  end
  return false
end

--show config panel / next config tab
function toolbar.next_configtab()
  if not toolbar.config_toolbar_shown then
    toolbar.toggle_showconfig()
    return
  end
  toolbar.sel_config_bar()
  toolbar.gototab(1)
end

--show config panel / prev config tab
function toolbar.prev_configtab()
  if not toolbar.config_toolbar_shown then
    toolbar.toggle_showconfig()
    return
  end
  toolbar.sel_config_bar()
  toolbar.gototab(-1)
end

--show/hide buffer config panel
function toolbar.toggle_buffer_configtab()
  if (not toolbar.config_toolbar_shown) or toolbar.cfgpnl_curgroup == toolbar.buff_panel then
    toolbar.toggle_showconfig() --show/hide
  end
  if toolbar.config_toolbar_shown and toolbar.cfgpnl_curgroup ~= toolbar.buff_panel then
    toolbar.config_tab_click(toolbar.buff_panel) --activate buffer panel
  end
end

--add a button to show/hide the config panel
function toolbar.add_showconfig_button()
  --add tab group if pending
  toolbar.addpending()
  --add a group of buttons after tabs
  toolbar.addrightgroup()
  --toolbar.cmd("showconfig", toolbar.toggle_showconfig, "Show configuration panel [F9]", "visualization")
  toolbar.addaction("toggle_viewcfgpanel")
end

function toolbar.config_tab_click(ntab)
  toolbar.sel_config_bar()
  toolbar.activatetab(ntab)
  toolbar.settext("cfgtit", toolbar.cfgpnl_tit[ntab], "", true)
  if toolbar.cfgpnl_group[ntab] > 0 then
    toolbar.sel_toolbar_n(3,toolbar.cfgpnl_group[toolbar.cfgpnl_curgroup])
    toolbar.showgroup(false)
    toolbar.sel_toolbar_n(3,toolbar.cfgpnl_group[ntab])
    toolbar.showgroup(true)
    toolbar.cfgpnl_curgroup= ntab
  end
end

--create the "vertical right (config)" panel
local function add_config_start(startgroup)
  toolbar.cfgpnl_tit={}
  toolbar.cfgpnl_group={}
  toolbar.cfgpnl_curgroup= startgroup
  toolbar.cfgpnl_chkval={}
  toolbar.cfgpnl_chknotify={}
  toolbar.cfgpnl_colors={}
  toolbar.cfgpnl_savelst={}
  toolbar.config_saveon=true  --save config options by default

  toolbar.new(toolbar.cfgpnl_width, 24, 16, 3, toolbar.themepath)
  toolbar.current_toolbar= 3
  toolbar.current_tb_group= 0
  toolbar.seticon("TOOLBAR", "ttb-cback", 0, true)  --vertical back

  --config title: width=expand / height=27
  toolbar.addgroup(7, 0, 0, 27)
  toolbar.seticon("GROUP", "ttb-cback2", 0, true)
  toolbar.textfont(toolbar.textfont_sz+4, toolbar.textfont_yoffset, toolbar.textcolor_normal, toolbar.textcolor_grayed)
  toolbar.addlabel("", "", toolbar.cfgpnl_width, false, false, "cfgtit")  --group title (set later)

  toolbar.tabwithclose=false
  toolbar.tabwidthmode=0
  toolbar.tabwidthmin=0
  toolbar.img[1]= "ttb-csep"
  toolbar.img[4]= "ttb-ctab-back"
  toolbar.img[31]= "ttb-back-no1"
  toolbar.img[32]= "ttb-back-no2"
  toolbar.img[33]= "ttb-back-no3"
  if toolbar.img[7]  == "" then toolbar.img[7]=  "ttb-ntab3nc" end
  if toolbar.img[10] == "" then toolbar.img[10]= "ttb-dtab3nc" end
  if toolbar.img[13] == "" then toolbar.img[13]= "ttb-htab3nc" end
  if toolbar.img[16] == "" then toolbar.img[16]= "ttb-atab3nc" end
  for i, img in ipairs(toolbar.img) do
    if img ~= "" then toolbar.seticon("TOOLBAR", img, i, true) end
  end
  toolbar.add_tabs_here(3)

  toolbar.seticon("GROUP", toolbar.back[1], 0, true)  --horizontal back x 1row
end

local function add_config_tabgroup(name,title,ngrp)
  local n=#toolbar.cfgpnl_tit+1
  if ngrp == nil then ngrp=n+1 end
  toolbar.cfgpnl_tit[n]=title
  toolbar.cfgpnl_group[n]=ngrp
  toolbar.settab(n, name, "")
  --create a group for each tab to hide its controls
  local hidegrp=(n ~= toolbar.cfgpnl_curgroup) --only one tab group is visible at a time
  toolbar.addgroup(7,24,0,0,hidegrp) --show v-scroll when needed
  toolbar.adjust(48,24,2,1,3,3)
  toolbar.textfont(toolbar.textfont_sz, toolbar.textfont_yoffset, toolbar.textcolor_normal, toolbar.textcolor_grayed)
  if n == toolbar.cfgpnl_curgroup then
    toolbar.settext("cfgtit", title, "", true)
    toolbar.activatetab(toolbar.cfgpnl_curgroup)
  end
  toolbar.cfgpnl_y= toolbar.cfgpnl_ymargin
  --toolbar.seticon("GROUP", "ttb-cback2", 0, true)
  if toolbar.config_saveon then --save as a comment in the config file
    toolbar.cfgpnl_savelst[#toolbar.cfgpnl_savelst+1]=";===[ "..name.." ]==="
  end
  return n
end

local function pnly_add( val )
  toolbar.cfgpnl_y= toolbar.cfgpnl_y + val
end

local function pnly_newrow()
  toolbar.cfgpnl_y= toolbar.cfgpnl_y + toolbar.cfgpnl_rheight
end

local function add_config_separator()
  toolbar.gotopos(0, toolbar.cfgpnl_y+2)
  toolbar.addspace()
  --add extra separation (1/2 row)
  pnly_add(toolbar.cfgpnl_rheight/2)
end

local function add_config_label(text,extrasep,notbold)
  if extrasep then
    add_config_separator()
  end
  toolbar.gotopos(toolbar.cfgpnl_xmargin, toolbar.cfgpnl_y)
  toolbar.addlabel(text, "", toolbar.cfgpnl_width-toolbar.cfgpnl_xtext*2,true,not notbold)
  pnly_newrow()
  if toolbar.config_saveon then --save as a comment in the config file
    toolbar.cfgpnl_savelst[#toolbar.cfgpnl_savelst+1]=";"..text
  end
end

local function set_notify_on_change(name,func)
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

local function add_config_check(name,text,tooltip,val,notify)
  if val == nil then val=false end
  --text
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.addlabel(text, tooltip, toolbar.cfgpnl_xcontrol-toolbar.cfgpnl_xtext,true)
  --checkbox
  toolbar.gotopos(toolbar.cfgpnl_xcontrol, toolbar.cfgpnl_y)
  toolbar.cmd(name, check_clicked, tooltip, (val and "check1" or "check0"))
  toolbar.setthemeicon(name, "check-hi", 2)
  toolbar.setthemeicon(name, "check-pr", 3)
  pnly_newrow()
  toolbar.cfgpnl_chkval[name]=val
  if toolbar.config_saveon then --save this check in the config file
    toolbar.cfgpnl_savelst[#toolbar.cfgpnl_savelst+1]=name
  end
  if notify ~= nil then
    set_notify_on_change(name, notify)
  end
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

local function rgb_2_bgr(col)
  return ((col >> 16) & 0xFF) | (col & 0x00FF00) | ((col << 16) & 0xFF0000)
end

--string color in 0xBBGGRR order
function toolbar.get_colorprop_val(prop)
  local col= toolbar.cfgpnl_colors[prop]
  if col == nil then col= '0x000000' end
  return col
end

--int color in 0xRRGGBB order
local function get_rgbcolor_prop(prop)
  local propval= toolbar.get_colorprop_val(prop)
  local v= string.match(propval,"0x(.*)")
  if v then propval= v end
  return rgb_2_bgr(tonumber(propval,16))
end

--string color in 0xBBGGRR order
function toolbar.set_colorprop_val(prop,color,dontset_toolbar)
  toolbar.cfgpnl_colors[prop]= color
  if not dontset_toolbar then
    toolbar.setbackcolor(prop,get_rgbcolor_prop(prop)) --update button background
  end
end

 --int color in 0xRRGGBB order
local function set_rgbcolor_prop(prop,rgb)
  toolbar.config_change=true
  toolbar.set_colorprop_val(prop, string.format('0x%06X', rgb_2_bgr(rgb)))
end

local function changeprop_clicked(name)
  toolbar.edit_color_prop=name
  toolbar.edit_curgroup= toolbar.cfgpnl_curgroup
  toolbar.enable("picker_ok", true)
  toolbar.enable("picker_cancel", true)
  toolbar.settext("edproptit", "Edit property:", "", true)
  toolbar.settext("edproptxt", name, "", true)
  local oldcolor= get_rgbcolor_prop(name)
  toolbar.setbackcolor("CPICKER", oldcolor )
  toolbar.setbackcolor("oldcolor", oldcolor, true)
  if toolbar.cfgpnl_curgroup ~= toolbar.picker_panel then
    toolbar.config_tab_click(toolbar.picker_panel) --activate picker panel
  end
end

local function add_cfg_prop(propname, x, tooltip)
  if propname ~= "" then
    local prop= "color."..propname
    toolbar.gotopos(x, toolbar.cfgpnl_y)
    toolbar.cmd(prop, changeprop_clicked, tooltip, "colorn", true)
    toolbar.setbackcolor(prop, get_rgbcolor_prop(prop), true)
    toolbar.setthemeicon(prop, "colorh", 2)
    toolbar.setthemeicon(prop, "colorp", 3)
    if toolbar.config_saveon then --save this color property in the config file
      toolbar.cfgpnl_savelst[#toolbar.cfgpnl_savelst+1]=prop
    end
  end
end

local function add_config_color(text, foreprop, backprop, tooltip, extraprop)
  if tooltip == nil then tooltip="" end
  --text
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.addlabel(text, tooltip, toolbar.cfgpnl_xcontrol2-toolbar.cfgpnl_xtext, true)
  --change color buttons
  if extraprop then add_cfg_prop(extraprop, toolbar.cfgpnl_xcontrol3, tooltip) end
  if foreprop  then add_cfg_prop(foreprop,  toolbar.cfgpnl_xcontrol2, tooltip) end
  if backprop  then add_cfg_prop(backprop,  toolbar.cfgpnl_xcontrol,  tooltip) end
  pnly_newrow()
end

local function colorpreset_clicked(name)
  local color= tonumber(string.match(name,"preset(.*)"))
  toolbar.setbackcolor("CPICKER", color)
end

local function add_color_preset( n, color, bkcolor )
  if not bkcolor then bkcolor=color end
  toolbar.gotopos(290, toolbar.cfgpnl_y)
  local name= "preset"..color
  toolbar.cmd(name, colorpreset_clicked, "", "", true)
  toolbar.setbackcolor(name, bkcolor, true)
  toolbar.setthemeicon(name, "colorh", 2)
  toolbar.setthemeicon(name, "colorp", 3)
  pnly_add(31)
end

local function picker_clicked()
  --ui.statusbar_text= "picker clicked"
end

local function add_config_colorpicker()
  toolbar.adjust(250,242,2,1,3,3)
  toolbar.gotopos(20, toolbar.cfgpnl_y)
  toolbar.cmd("picker", picker_clicked, "", "")
  toolbar.setbackcolor("picker", -2, true)  --COLOR PICKER=-2
  local ynext= toolbar.cfgpnl_y + 250
  toolbar.adjust(48,24,2,1,3,3)
  add_color_preset(1,0xff0000,-4) --shows RED   value (scroll wheel to edit)
  add_color_preset(2,0xffff00)
  add_color_preset(3,0x00ff00,-5) --shows GREEN value (scroll wheel to edit)
  add_color_preset(4,0x00ffff)
  add_color_preset(5,0x0000ff,-6) --shows BLUE  value (scroll wheel to edit)
  add_color_preset(6,0xff00ff)
  add_color_preset(7,0x000000)
  add_color_preset(8,0xffffff)
  toolbar.cfgpnl_y= ynext
end

local function _add_config_radio(name,text,tooltip,checked)
  if checked == nil then checked=false end
  if tooltip == nil then tooltip="" end
  --text
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.addlabel(text, tooltip, toolbar.cfgpnl_xcontrol-toolbar.cfgpnl_xtext, true)
  --radio button
  toolbar.gotopos(toolbar.cfgpnl_xcontrol, toolbar.cfgpnl_y)
  toolbar.cmd(name, radio_clicked, tooltip, (checked and "radio1" or "radio0"))
  toolbar.setthemeicon(name, "radio-hi", 2)
  toolbar.setthemeicon(name, "radio-pr", 3)
  pnly_newrow()
  toolbar.cfgpnl_chkval[name]=checked
end

--start a new radio button: name="rname:num" or "rname" (num=1)
local function add_config_radio(name,text,tooltip,checked)
  local rname,rnum= string.match(name, "(.-):(.+)$")
  if rname then
    toolbar.last_rname= rname
    toolbar.last_rnum= tonumber(rnum)
  else
    toolbar.last_rname= name
    toolbar.last_rnum= 1
    name= name..":1"
  end
  _add_config_radio(name,text,tooltip,checked)
  if toolbar.config_saveon and toolbar.last_rnum == 1 then --save this radio in the config file
    toolbar.cfgpnl_savelst[#toolbar.cfgpnl_savelst+1]=name
  end
end

local function cont_config_radio(text,tooltip,checked)
  toolbar.last_rnum= toolbar.last_rnum+1
  _add_config_radio(toolbar.last_rname..":"..toolbar.last_rnum,text,tooltip,checked)
end

local function confirm_color_overwrite(title,dontask)
  return dontask or (ui.dialogs.msgbox{
      title = title,
      text = 'All colors will be overwritten',
      informative_text = 'Do you want to proceed?',
      icon = 'gtk-dialog-question', button1 = _L['_OK'], button2 = _L['_Cancel']
    } == 1)
end

local function load_colors_from_theme(dontask)
  local rname,rnum
  if confirm_color_overwrite("Get theme's colors", dontask) then
    local f = io.open(toolbar.themepath.."colors.cfg", 'rb')
    if f then
      for line in f:lines() do
        rname,rnum= string.match(line, "([^;]-):(.+)$")
        if rname then
          if string.match(rname,'color%..*') then
            toolbar.set_colorprop_val(rname,rnum)
          end
        end
      end
      f:close()
      toolbar.save_colors_reset() --apply now
    end
  end
end

local function save_theme_colors(dontask)
  if confirm_color_overwrite("Save this colors as theme's default", dontask) then
    local f = io.open(toolbar.themepath.."colors.cfg", 'wb')
    if f then
      local savedata = {}
      local n=1
      for _,optname in ipairs(toolbar.cfgpnl_savelst) do
        local cname= string.match(optname, "color%.(.+)$")
        if cname then --only save color properties: color.name
          savedata[n] = optname..":"..toolbar.get_colorprop_val(optname)
          n=n+1
        end
      end
      f:write(table.concat(savedata, '\n'))
      f:close()
    end
  end
end

local function reload_theme()
  --Reset to apply the changes
  toolbar.save_config()
  buffer.reopen_config_panel= toolbar.cfgpnl_curgroup
  reset()
end

local function save_colors_in_TAtheme()
  local f = io.open(_USERHOME..'/themes/colors.lua', 'wb')
  if f then
    local savedata = {}
    local n=1
    savedata[n] = "local p= buffer.property"
    for _,optname in ipairs(toolbar.cfgpnl_savelst) do
      local cname= string.match(optname, "color%.(.+)$")
      if cname then --only save color properties: color.name
        n=n+1
        savedata[n] = "p['"..optname.."']="..toolbar.get_colorprop_val(optname)
      end
    end
    f:write(table.concat(savedata, '\n'))
    f:close()
  end
end

function toolbar.save_colors_reset()
  save_colors_in_TAtheme()
  reload_theme()
end

local function reload_colors(dontask)
  local rname,rnum
  if confirm_color_overwrite("Reload current colors", dontask) then
    local f = io.open(_USERHOME..'/themes/colors.lua', 'rb')
    if f then
      for line in f:lines() do
        rname,rnum= string.match(line, ".-'(color%..-)'%]=(.+)$")
        if rname and rnum then
          toolbar.set_colorprop_val(rname,rnum)
        end
      end
      f:close()
    end
  end
end

local base0X_prop= {
['0']= {'text_back', 'selection_fore', 'linenum_back'},
['1']= {'curr_line_back', 'prj_sel_bar'},
['2']= {'text_fore', 'selection_back', 'operator'},
['3']= {'indentguide'},
['4']= {'markers,comment'},
['5']= {'calltips_fore', 'linenum_fore', 'markers_sel', 'prj_open_mark'},
['6']= {'prj_sel_bar_nof'},
['7']= {'caret', 'calltips_back'},
['8']= {'error', 'variable', 'red'},
['9']= {'constant', 'number', 'type'},
['A']= {'class', 'label', 'preprocessor', 'warning'},
['B']= {'string', 'green'},
['C']= {'regex', 'brace_ok'},
['D']= {'bookmark'},
['E']= {'function', 'keyword'},
['F']= {'hilight', 'placeholder', 'find', 'embedded'}
}

local function import_color_scheme()
  local rname,rnum
  if confirm_color_overwrite("Import a color scheme file", dontask) then
    local scheme= ui.dialogs.fileselect{
      title = 'Open scheme file',
      with_directory = _USERHOME..'/themes',
      width = CURSES and ui.size[1] - 2 or nil,
      with_extension = {'yml'}, select_multiple = false }
    if scheme then
      local f = io.open(scheme, 'rb')
      if f then
        for line in f:lines() do --format: base0B: "33ff00"
          basen,rr,gg,bb= string.match(line, '^base0(%x).-%"(%x%x)(%x%x)(%x%x)%"')
          if basen and rr and gg and bb then
            bgr= "0x"..bb..gg..rr
            local props=base0X_prop[basen]
            for _,p in ipairs(props) do
              toolbar.set_colorprop_val("color."..p,bgr)
            end
          end
        end
        f:close()
      end
      toolbar.save_colors_reset() --apply now
    end
  end
end

function toolbar.save_config()
  if toolbar.config_change then
    local f = io.open(toolbar.CONFIG_FILE, 'wb')
    if f then
      local savedata = {}
      for _,optname in ipairs(toolbar.cfgpnl_savelst) do
        local n=#savedata + 1
        if string.match(optname, ";.*$") then
          savedata[n] = optname --save comments
        else
          local rname= string.match(optname, "(.-):.+$")
          if rname then
            --radio: name:index
            savedata[n] = rname..":"..toolbar.get_radio_val(rname)
          else
            local cname= string.match(optname, "color%.(.+)$")
            if cname then
              --color property: color.name
              savedata[n] = optname..':'..toolbar.get_colorprop_val(optname)
            else
              --check: name=true/false
              savedata[n] = optname..(toolbar.get_check_val(optname) and ':true' or ':false')
            end
          end
        end
      end
      savedata[#savedata+1] = ";==========="
      savedata[#savedata+1] = "LEXER:INDENT"
      for optname,val in pairs(toolbar.cfgpnl_lexer_indent) do
        savedata[#savedata+1] = optname..":"..val
      end
      f:write(table.concat(savedata, '\n'))
      f:close()
    end
    toolbar.config_change= false
  end
end

function toolbar.load_config(dontset_toolbar)
  local colors= false
  if dontset_toolbar == nil then dontset_toolbar=false end
  toolbar.cfgpnl_lexer_indent={}
  local readlexer= false
  local rname,rnum
  local f = io.open(toolbar.CONFIG_FILE, 'rb')
  if f then
    for line in f:lines() do
      rname,rnum= string.match(line, "([^;]-):(.+)$")
      if rname then
        if readlexer then
          toolbar.cfgpnl_lexer_indent[rname]=rnum
        elseif rname == "LEXER" and rnum == "INDENT" then
          readlexer=true
        else
          if rnum == 'true' then
            toolbar.set_check_val(rname,true,dontset_toolbar)
          elseif rnum == 'false' then
            toolbar.set_check_val(rname,false,dontset_toolbar)
          else
            if string.match(rname,'color%..*') then
              toolbar.set_colorprop_val(rname,rnum,dontset_toolbar)
              colors=true
            else
              toolbar.set_radio_val(rname,rnum,dontset_toolbar)
            end
          end
        end
      end
    end
    f:close()
  end
  toolbar.config_change= false
  if not colors and not dontset_toolbar and toolbar.themepath then --no colors in config, use theme default
    load_colors_from_theme(true)
  end
end

--on init load the configuration file but don't set the toolbar yet
--events.connect(events.INITIALIZED, function() toolbar.load_config(true) end)
-- Save configuration changes on quit
events.connect(events.QUIT, function() toolbar.save_config() end, 1)

local function get_lexer()
  local GETLEXERLANGUAGE= _SCINTILLA.properties.lexer_language[1]
  return buffer:private_lexer_call(GETLEXERLANGUAGE):match('^[^/]+')
end

local function get_lexer_cfg(lexer)
  if toolbar.cfgpnl_lexer_indent[lexer] ~= nil then return toolbar.cfgpnl_lexer_indent[lexer] end
  --no lexer val set, try "text"
  if toolbar.cfgpnl_lexer_indent["text"] ~= nil then return toolbar.cfgpnl_lexer_indent["text"] end
  --no "text" val set, use global default
  return "s4"
end

local function get_lexer_ind_use_tabs(lexer)
  local ind= get_lexer_cfg(lexer)
  if string.match(ind,"s") then return false end
  return true
end

local function get_lexer_ind_width(lexer)
  local ind= get_lexer_cfg(lexer)
  return string.match(ind,"[st](.-)$")
end

local function set_lexer_cfg()
  --Use current settings as Lexer default
  local lexer= get_lexer()
  local indent=string.format('%s%d', buffer.use_tabs and 't' or 's', buffer.tab_width)
  toolbar.cfgpnl_lexer_indent[lexer]=indent
  toolbar.config_change=true
end

function toolbar.set_buffer_cfg()
  toolbar.set_radio_val("bfindent", (buffer._cfg_bfindent ~= nil and buffer._cfg_bfindent or 1))
  toolbar.set_radio_val("bfusetab", (buffer._cfg_bfusetab ~= nil and buffer._cfg_bfusetab or 1))
  local em=1
  if buffer._cfg_bfeol ~= nil then  em= buffer._cfg_bfeol
  elseif buffer.eol_mode == buffer.EOL_LF then em=2 end
  toolbar.set_radio_val("bfeol", em)
  toolbar.set_check_val("tbshoweol",buffer.view_eol)
  toolbar.set_check_val("tbshowws", (buffer.view_ws == buffer.WS_VISIBLEALWAYS))
  toolbar.set_check_val("tbwrap", (buffer.wrap_mode == buffer.WRAP_WHITESPACE))
  if toolbar.html_toolbar_onoff ~= nil then
    toolbar.set_check_val("tbshowhtml", buffer.html_toolbar_on)
  end
  toolbar.set_check_val("tbshowguid", (buffer.indentation_guides == buffer.IV_LOOKBOTH))
  toolbar.set_check_val("tbvirtspc", (buffer.virtual_space_options == buffer.VS_USERACCESSIBLE))
end

--only update when the config is open
function update_buffer_cfg()
  if toolbar.config_toolbar_shown then toolbar.set_buffer_cfg() end
  --update ALL actions in menus
  actions.update_menuitems()
end

events.connect(events.BUFFER_AFTER_SWITCH, update_buffer_cfg)
events.connect(events.VIEW_AFTER_SWITCH,   update_buffer_cfg)
events.connect(events.BUFFER_NEW,          update_buffer_cfg)
events.connect(events.FILE_OPENED,         update_buffer_cfg)

local function set_buffer_indent_as_cfg(updateui)
  --indentation width
  local iw= buffer._cfg_bfindent
  if iw == 2 then       buffer.tab_width= 2
  elseif iw == 3 then   buffer.tab_width= 3
  elseif iw == 4 then   buffer.tab_width= 4
  elseif iw == 5 then   buffer.tab_width= 8
  else                  buffer.tab_width= get_lexer_ind_width(get_lexer())   end
  --indentation char
  local ut= buffer._cfg_bfusetab
  if ut == 2 then       buffer.use_tabs= false
  elseif ut == 3 then   buffer.use_tabs= true
  else                  buffer.use_tabs= get_lexer_ind_use_tabs(get_lexer()) end
  --update UI
  if updateui then events.emit(events.UPDATE_UI) end
  --update TAB actions
  actions.updateaction("set_tab_2")
  actions.updateaction("set_tab_3")
  actions.updateaction("set_tab_4")
  actions.updateaction("set_tab_8")
  actions.updateaction("toggle_usetabs")
end

events.connect(events.LEXER_LOADED, set_buffer_indent_as_cfg)

function toolbar.setcfg_from_tabwidth()
  if buffer.tab_width == 2 then buffer._cfg_bfindent= 2
  elseif buffer.tab_width == 3 then buffer._cfg_bfindent= 3
  elseif buffer.tab_width == 4 then buffer._cfg_bfindent= 4
  elseif buffer.tab_width == 8 then buffer._cfg_bfindent= 5
  else buffer._cfg_bfindent= 1 end
  update_buffer_cfg()
end

function toolbar.setcfg_from_usetabs()
  if buffer.use_tabs then buffer._cfg_bfusetab= 3
  else buffer._cfg_bfusetab= 2 end
  update_buffer_cfg()
end

local function buf_indent_change()
  buffer._cfg_bfindent= toolbar.get_radio_val("bfindent")
  buffer._cfg_bfusetab= toolbar.get_radio_val("bfusetab")
  set_buffer_indent_as_cfg(true)
end

local function buf_eolmode_change()
  buffer._cfg_bfeol= toolbar.get_radio_val("bfeol")
  --EOL mode
  local neweol= buffer.EOL_CRLF
  if buffer._cfg_bfeol == 2 then neweol= buffer.EOL_LF end
  if neweol ~= buffer.eol_mode then
    --EOL mode changed, update buffer
    buffer.eol_mode= neweol
    buffer:convert_eols(neweol)
    --update UI
    events.emit(events.UPDATE_UI)
  end
  --update EOL actions
  actions.updateaction("set_eol_crlf")
  actions.updateaction("set_eol_lf")
end

function toolbar.setcfg_from_eolmode()
  if buffer.eol_mode == buffer.EOL_LF then buffer._cfg_bfeol= 2
  else buffer._cfg_bfeol= 1 end
  update_buffer_cfg()
end

local function buf_vieweol_change()
  buffer.view_eol= toolbar.get_check_val("tbshoweol")
  actions.updateaction("toggle_view_oel")
end
local function buf_viewws_change()
  buffer.view_ws= toolbar.get_check_val("tbshowws") and buffer.WS_VISIBLEALWAYS or 0
  actions.updateaction("toggle_view_ws")
end
local function buf_wrapmode_change()
  buffer.wrap_mode = toolbar.get_check_val("tbwrap") and buffer.WRAP_WHITESPACE or 0
  actions.updateaction("toggle_view_wrap")
end

function toolbar.setcfg_from_view_checks()
  update_buffer_cfg()
end

function toolbar.setcfg_from_buff_checks()
  if toolbar.html_toolbar_onoff ~= nil then
    toolbar.set_check_val("tbshowhtml", buffer.html_toolbar_on)
  end
end

local function view_guides_change()
  buffer.indentation_guides = toolbar.get_check_val("tbshowguid") and buffer.IV_LOOKBOTH or 0
  actions.updateaction("toggle_view_indguides")
end
local function view_virtspace_change()
  buffer.virtual_space_options = toolbar.get_check_val("tbvirtspc") and buffer.VS_USERACCESSIBLE or 0
  actions.updateaction("toggle_virtualspace")
end

local tatoobarweb= "https://github.com/gabdub/ta-tweaks"
local function open_tatoolbar_web()
  local cmd = (WIN32 and 'start ""') or (OSX and 'open') or 'xdg-open'
  spawn(string.format('%s "%s"', cmd, tatoobarweb))
end

local function add_buffer_cfg_panel()
  toolbar.config_saveon=false --don't save the config options of this panel
  toolbar.buff_panel= add_config_tabgroup("Buffer", "Buffer configuration")

  add_config_label("VIEW OPTIONS")
  add_config_label("Buffer")
  add_config_check("tbshoweol", "View EOL", "", false, buf_vieweol_change)
  add_config_check("tbwrap", "Wrap mode", "", false, buf_wrapmode_change)
  add_config_check("tbshowws", "View Whitespace", "", false, buf_viewws_change)
  if toolbar.html_toolbar_onoff ~= nil then
    add_config_check("tbshowhtml", "Show HTML toolbar", "", false, toolbar.html_toolbar_onoff)
  end
  add_config_label("View")
  add_config_check("tbshowguid", "Show Indent Guides", "", false, view_guides_change)
  add_config_check("tbvirtspc", "Virtual Space", "", false, view_virtspace_change)

  add_config_label("EOL MODE",true)
  if WIN32 then
    add_config_radio("bfeol", "CR+LF (OS default)")
    cont_config_radio("LF")
  else
    add_config_radio("bfeol", "CR+LF")
    cont_config_radio("LF (OS default)")
  end
  set_notify_on_change("bfeol",buf_eolmode_change)

  add_config_label("INDENTATION",true)
  add_config_label("Tab width")
  add_config_radio("bfindent", "Use Lexer default")
  cont_config_radio("Tab width: 2")
  cont_config_radio("Tab width: 3")
  cont_config_radio("Tab width: 4")
  cont_config_radio("Tab width: 8")
  set_notify_on_change("bfindent",buf_indent_change)

  add_config_label("Spaces/tabs")
  add_config_radio("bfusetab", "Use Lexer default")
  cont_config_radio("Spaces")
  cont_config_radio("Tabs")
  set_notify_on_change("bfusetab",buf_indent_change)

  add_config_separator()
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmdtext("Set as Lexer default", set_lexer_cfg, "Use current settings as Lexer default", "setlexercfg")
  toolbar.gotopos(toolbar.cfgpnl_xtext+(toolbar.cfgpnl_width/2), toolbar.cfgpnl_y)
  toolbar.cmdtext("Convert indentation", textadept.editing.convert_indentation, "Adjust current buffer indentation", "setindentation")
  pnly_add(21)
  add_config_separator()

  --show current buffer settings
  toolbar.set_buffer_cfg()
end

local function add_toolbar_cfg_panel()
  toolbar.config_saveon=true --save the config options of this panel
  toolbar.toolbar_panel= add_config_tabgroup("Toolbar", "Toolbar configuration")

  add_config_label("THEME")
  add_config_radio("tbtheme", "bar-sm-light", "Light theme with small tabs", true)
  cont_config_radio( "bar-th-dark", "Dark theme with rounded tabs")
  cont_config_radio( "bar-ch-dark", "Dark theme with triangular tabs")

  add_config_label("TABS",true)
  add_config_label("Tabs position")
  add_config_radio("tbtabs", "Off", "Use default system tabs", true)
  cont_config_radio("Same row", "Tabs and buttons in the same row")
  cont_config_radio("Top row", "Tabs over buttons")
  cont_config_radio("Bottom row", "Tabs under buttons")

  add_config_label("Show close button")
  add_config_radio("tbtabclose", "Hide")
  cont_config_radio("Show")
  cont_config_radio("Let the Theme choose", "", true)

  add_config_label("Close with double click")
  add_config_radio("tbtab2clickclose", "No")
  cont_config_radio("Yes")
  cont_config_radio("Let the Theme choose", "", true)

  add_config_label("STATUS BAR",true)
  add_config_check("tbshowstatbar", "Use toolbar status bar", "", true)

  add_config_label("VERTICAL BAR",true)
  add_config_radio("tbvertbar", "1 Column", "", true)
  cont_config_radio("2 Columns")
  if toolbar.add_html_toolbar == nil then
    --NO HTML quicktype toolbar, add "HIDE" option
    cont_config_radio("Hide")
  end
  toolbar.config_saveon=false --end of config save options of this panel

  add_config_separator()
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmdtext("Apply changes", reload_theme, "Reset to apply the changes", "reload1")
  pnly_add(21)
  add_config_separator()

  pnly_newrow()
  add_config_label("About ta-toolbar", true)
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.addlabel("Version: "..toolbar.getversion(), "", toolbar.cfgpnl_width-toolbar.cfgpnl_xtext*2,true,false)
  toolbar.gotopos(toolbar.cfgpnl_xcontrol2, toolbar.cfgpnl_y)
  toolbar.cmdtext("@ github", open_tatoolbar_web, "Visit "..tatoobarweb, "openttbweb")
  pnly_add(21)
  add_config_separator()
end

local function add_config_label3(tit, tit1, tit2, extrasep)
  if extrasep then
    add_config_separator()
  end
  toolbar.gotopos(toolbar.cfgpnl_xcontrol2, toolbar.cfgpnl_y)
  toolbar.addlabel(tit1, "", toolbar.cfgpnl_xcontrol-toolbar.cfgpnl_xcontrol2,true)
  toolbar.gotopos(toolbar.cfgpnl_xcontrol, toolbar.cfgpnl_y)
  toolbar.addlabel(tit2, "", toolbar.cfgpnl_width-toolbar.cfgpnl_xcontrol2,true)
  add_config_label(tit)
end

local function add_colors_cfg_panel()
  toolbar.config_saveon=true --save the config options of this panel
  toolbar.colors_panel= add_config_tabgroup("Color", "Color configuration")

  add_config_label3("Editor", "Fore", "Back")
  add_config_color("Default text", "text_fore", "text_back")
  add_config_color("Caret & current line back", "caret", "curr_line_back")
  add_config_color("Selection", "selection_fore", "selection_back")
  add_config_color("Highlight", "", "hilight")
  add_config_color("Placeholder", "", "placeholder")
  add_config_color("Find", "", "find")
  add_config_color("Call Tips", "calltips_fore","calltips_back")
  add_config_color("Line number", "linenum_fore","linenum_back")
  add_config_color("Markers (folding)", "", "markers")
  add_config_color("Marker selected", "", "markers_sel")
  add_config_color("Bookmarks", "", "bookmark")
  add_config_color("Warnings", "", "warning")
  add_config_color("Errors", "", "error")
  add_config_color("Indent guide", "indentguide", "")

  add_config_label3("Project", "Unfocus", "Focus", true)
  add_config_color("Selection bar", "prj_sel_bar_nof", "prj_sel_bar")
  add_config_color("Open file mark", "prj_open_mark")

  add_config_label3("Syntax highlighting", "Fore", "", true)
  add_config_color("Comment", "comment")
  add_config_color("Variable", "variable")
  add_config_color("Constant", "constant")
  add_config_color("Number", "number")
  add_config_color("Type", "type")
  add_config_color("Class", "class")
  add_config_color("Label", "label")
  add_config_color("Pre-processor", "preprocessor")
  add_config_color("String", "string")
  add_config_color("Regular expression", "regex")
  add_config_color("Matched brace", "brace_ok")
  add_config_color("Function", "function")
  add_config_color("Keyword", "keyword")
  add_config_color("Embedded", "embedded")
  add_config_color("Operator", "operator")

  add_config_label3("Diff Lexer", "Del (-)", "Add (+)", true)
  add_config_color("Changes", "red", "green", "", "yellow")

  add_config_separator()
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmdtext("Apply changes", toolbar.save_colors_reset, "Accept the changes", "reload2")
  toolbar.gotopos(toolbar.cfgpnl_width/2, toolbar.cfgpnl_y)
  toolbar.cmdtext("Discard changes", reload_colors, "Reload current colors", "reload3")
  pnly_add(21)
  add_config_separator()
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmdtext("Restore theme's palette", load_colors_from_theme, "Set default colors from theme", "getthemecolors")
  pnly_add(30)
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmdtext("Save as theme's palette", save_theme_colors, "Save this colors as theme's default", "savethemecolors")
  pnly_add(30)
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmdtext("Import a base-16 file (scheme.yml)", import_color_scheme, "Import a color scheme file (github: chriskempson/base16-builder)", "impscheme")
  pnly_add(21)
  add_config_separator()
end

local function picker_cancel()
  if toolbar.edit_curgroup and toolbar.cfgpnl_curgroup ~= toolbar.edit_curgroup then
    toolbar.config_tab_click(toolbar.edit_curgroup) --return to original panel
  end
  toolbar.edit_curgroup= nil --end edit
  toolbar.enable("picker_ok", false)
  toolbar.enable("picker_cancel", false)
  toolbar.settext("edproptit", "", "", true)
  toolbar.settext("edproptxt", "", "", true)
end

local function picker_ok()
  if toolbar.edit_curgroup ~= nil then
    set_rgbcolor_prop(toolbar.edit_color_prop, toolbar.getpickcolor())
  end
  picker_cancel()
end

local function oldcolor_clicked()
  toolbar.setbackcolor("CPICKER", get_rgbcolor_prop(toolbar.edit_color_prop))
end

local function picker_type(toclipboard)
  local col= toolbar.getpickcolor() --RGB
  if toolbar.get_radio_val("ctypeorder") == 2 then
    col=rgb_2_bgr(col)
  end
  local scol
  if toolbar.get_radio_val("ctypeformat") == 3 then
    scol=string.format('%d', col) --decimal
  else
    scol=string.format('%06X', col) --hex
    if toolbar.get_radio_val("ctypeformat") == 1 then
      scol="0x"..scol
    else
      scol="#"..scol
    end
  end
  if toclipboard then
    buffer:copy_text(scol)
  else
    buffer.add_text(buffer, scol)
  end
end

local function picker_copy()
  picker_type(true)
end

--remove blanks and CR/LF
local function str_trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function picker_get(fromclipboard)
  local text
  if fromclipboard then
    text= str_trim(ui.clipboard_text)
  else
    local s, e = buffer.selection_start, buffer.selection_end
    if s == e then
      s, e = buffer:word_start_position(s), buffer:word_end_position(s)
    end
    text= str_trim(buffer:text_range(s, e))
  end
  if text and text ~= "" then
    local hex= false
    local v= string.match(text,"0x(%x+)")
    if v then
      text=v
      hex= true
    else
      v= string.match(text,"#(%x+)")
      if v then
        text=v
        hex= true
      else
        v= string.match(text,"^(%x+)$")
      end
    end
    if v then
      if not hex and v == string.match(text,"^(%d+)$") then
        --all digits are decimal, use radio to decide
        if toolbar.get_radio_val("ctypeformat") ~= 3 then
          hex= true --not decimal
        end
      end
      local color
      if hex then color=tonumber(v,16) else color=tonumber(v) end
      if toolbar.get_radio_val("ctypeorder") == 2 then
        color=rgb_2_bgr(color) --convert from BGR to RGB
      end
      toolbar.setbackcolor("CPICKER", color)
      ui.statusbar_text= 'imported color= '..v
      return
    end
    if string.len(text) > 30 then
      text= string.sub(text,1,30).."..."
    end
    ui.statusbar_text= 'Invalid color format, text='..text
  else
    ui.statusbar_text= 'Empty text'
  end
end

local function picker_paste()
  picker_get(true)
end

local function add_picker_cfg_panel()
  toolbar.config_saveon=false --don't save the config options of this part of the panel
  toolbar.picker_panel= add_config_tabgroup("Picker", "Color picker")

  add_config_label("HSV")
  add_config_colorpicker()

  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmd("choosencolor", picker_clicked, "")
  toolbar.setbackcolor("choosencolor", -3, true)  --CHOSEN COLOR=-3
  toolbar.setthemeicon("choosencolor", "colorh", 2)
  toolbar.setthemeicon("choosencolor", "colorp", 3)

  toolbar.gotopos(toolbar.cfgpnl_width/2, toolbar.cfgpnl_y)
  toolbar.cmd("oldcolor", oldcolor_clicked, "")
  toolbar.edit_color_prop= "color.text_back"
  toolbar.setbackcolor("oldcolor", 0, true) --set later
  toolbar.setthemeicon("oldcolor", "colorh", 2)
  toolbar.setthemeicon("oldcolor", "colorp", 3)
  pnly_add(30)

  toolbar.gotopos(toolbar.cfgpnl_xtext-4, toolbar.cfgpnl_y)
  toolbar.addlabel("", "", 0, true, false, "edproptit")
  toolbar.gotopos(toolbar.cfgpnl_width/2-4, toolbar.cfgpnl_y)
  toolbar.addlabel("", "", toolbar.cfgpnl_width, true, true, "edproptxt")  --edited prop (set later)
  pnly_newrow()

  add_config_separator()
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmdtext("Change", picker_ok, "Accept the new color", "picker_ok")
  toolbar.gotopos(toolbar.cfgpnl_width/2, toolbar.cfgpnl_y)
  toolbar.cmdtext("Cancel", picker_cancel, "Keep the old color", "picker_cancel")
  pnly_add(21)
  add_config_separator()
  picker_cancel()

  pnly_add(10)
  toolbar.config_saveon=true --save the config options of this part of the panel
  add_config_label("TYPER")
  add_config_label("Order")
  add_config_radio("ctypeorder", "RRGGBB", "", true)
  cont_config_radio("BBGGRR")
  add_config_label("Format")
  add_config_radio("ctypeformat", "0xhhhhhh", "", true)
  cont_config_radio("#hhhhhh")
  cont_config_radio("decimal")

  add_config_separator()
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmdtext("Type", picker_type, "Type the selected color", "picker_type")
  toolbar.gotopos(toolbar.cfgpnl_width/2, toolbar.cfgpnl_y)
  toolbar.cmdtext("Copy", picker_copy, "Copy the selected color to the clipboard", "picker_copy")
  pnly_add(21)
  add_config_separator()

  pnly_add(10)
  add_config_label("IMPORT")
  add_config_separator()
  toolbar.gotopos(toolbar.cfgpnl_xtext, toolbar.cfgpnl_y)
  toolbar.cmdtext("From text", picker_get, "Import from the selected text", "picker_get")
  toolbar.gotopos(toolbar.cfgpnl_width/2, toolbar.cfgpnl_y)
  toolbar.cmdtext("From clipboard", picker_paste, "Import from the clipboard", "picker_paste")
  pnly_add(21)
  add_config_separator()
end

function toolbar.add_config_panel()
  --create the "vertical right (config)" panel
  add_config_start( (buffer.reopen_config_panel or 1) ) --start panel

  add_buffer_cfg_panel()  --BUFFER
  add_toolbar_cfg_panel() --TOOLBAR
  add_colors_cfg_panel()  --COLORS
  add_picker_cfg_panel()  --COLOR PICKER

  --load config settings / set toolbar controls
  toolbar.load_config()
  toolbar.setbackcolor("oldcolor", get_rgbcolor_prop(toolbar.edit_color_prop), true)

  --check: hide toolbar + htmltoolbar => force 1 row
  if toolbar.get_radio_val("tbvertbar") == 3 and toolbar.add_html_toolbar ~= nil then
    toolbar.set_radio_val("tbvertbar",1)
  end

  --hide the config panel
  toolbar.show(false)
  if buffer.reopen_config_panel then
    --reopen it after theme apply
    buffer.reopen_config_panel= nil
    toolbar.toggle_showconfig()
  end
end

--------------------------------------------------------------
-- F9            show config panel / next config tab
-- SHIFT+F9      show config panel / prev config tab
actions.add("next_cfgpanel", 'Open config panel / goto next tab',     toolbar.next_configtab, "f9")
actions.add("prev_cfgpanel", 'Open config panel / goto previous tab', toolbar.prev_configtab, "sf9")

--"toggle_viewcfgpanel" = 'Hide/show Config panel'
local function tcv_status()
  return (toolbar.config_toolbar_shown and 1 or 2) --check
end
local function tcv_icon()
  if toolbar.config_toolbar_shown then
    return "ttb-proj-c"
  end
  return "visualization"
end
local function tcv_text()
  if toolbar.config_toolbar_shown then
    return "Hide configuration panel"
  end
  return "Show configuration panel"
end
actions.add("toggle_viewcfgpanel", 'Sh_ow Config panel', toolbar.toggle_showconfig, "f10", tcv_icon, tcv_status, tcv_text)

--add VIEWCONFIGPANEL at the end of the VIEW menu
local m_vi= actions.getmenu_fromtitle(_L['_View'])
if m_vi then
  local m=m_vi[#m_vi]
  m[#m+1]= "toggle_viewcfgpanel"
end
