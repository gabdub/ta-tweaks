-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
if toolbar then
  local Util = Util
  require('toolbar.constants')
  if actions then require('toolbar.actions') end
  require('toolbar.minimap')
  require('toolbar.controls')
  require('toolbar.configtb') --config panel on toolbar #3
  require('toolbar.dialogs')

  local events, events_connect = events, events.connect
  toolbar.tabpos= 0

  toolbar.keyflags= 0 --key modifiers for current toolbar event (toolbar.KEYFLAGS.xxx)

  --select a toolbar as current
  function toolbar.sel_toolbar_n(ntb, ngrp, emptygrp)
    if ngrp == nil then ngrp = 0 end
    if toolbar.current_toolbar ~= ntb or toolbar.current_tb_group ~= ngrp or emptygrp then
      toolbar.current_toolbar= ntb
      toolbar.current_tb_group= ngrp
      toolbar.seltoolbar(ntb,ngrp,emptygrp)
    end
  end
  --select a toolbar by name
  function toolbar.sel_top_bar(ngrp, emptygrp)
    toolbar.sel_toolbar_n(toolbar.TOP_TOOLBAR, ngrp, emptygrp)
  end
  function toolbar.sel_left_bar(ngrp, emptygrp)
    toolbar.sel_toolbar_n(toolbar.LEFT_TOOLBAR, ngrp, emptygrp)
  end
  function toolbar.sel_stat_bar(ngrp, emptygrp)
    toolbar.sel_toolbar_n(toolbar.STAT_TOOLBAR, ngrp, emptygrp)
  end
  function toolbar.sel_config_bar(ngrp, emptygrp)
    toolbar.sel_toolbar_n(toolbar.RIGHT_TOOLBAR, ngrp, emptygrp)
  end
  function toolbar.sel_minimap(ngrp)
    toolbar.sel_toolbar_n(toolbar.MINIMAP_TOOLBAR)
  end
  function toolbar.sel_hscroll(ngrp)
    toolbar.sel_toolbar_n(toolbar.H_SCROLL_TOOLBAR)
  end
  function toolbar.sel_results_bar(ngrp, emptygrp)
    toolbar.sel_toolbar_n(toolbar.RESULTS_TOOLBAR, ngrp, emptygrp)
  end
  function toolbar.sel_combo_popup(ngrp, emptygrp)
    toolbar.sel_toolbar_n(toolbar.COMBO_POPUP, ngrp, emptygrp)
  end
  function toolbar.sel_dialog_popup(ngrp, emptygrp)
    toolbar.sel_toolbar_n(toolbar.DIALOG_POPUP, ngrp, emptygrp)
  end

  function toolbar.setthemeicon(name,icon,num)
    --set button icon, get icon from theme's icons folder
    toolbar.seticon(name,toolbar.iconspath..icon..".png",num or toolbar.TTBI_TB.IT_NORMAL)
  end

  function toolbar.isbufhide(buf)
    --hide all project buffers (but not projects in edit mode)
    if Proj then return Proj.isHiddenTabBuf(buf) end
    --show all other buffers
    return false
  end

  --select the top toolbar and return the tab number of a buffer
  local function getntabbuff(buf)
    --tabs are in the top bar
    toolbar.sel_top_bar()
    if buf._buffnum == nil then
      --assign a unique number to each buffer
      buf._buffnum= toolbar.buffnum
      toolbar.buffnum= toolbar.buffnum+1
      toolbar.buffers[_BUFFERS[buf]]= buf._buffnum
    elseif buf._buffnum >= toolbar.buffnum then toolbar.buffnum= buf._buffnum+1 end --restore toolbar.buffnum after reset
    return buf._buffnum
  end

  local function set_chg_tabbuf(buf)
    if buf == nil then
      --update current tab
      buf= buffer
    end
    --select the top toolbar and get the tab number of the buffer
    local ntab= getntabbuff(buf)
    --update tab text
    local filename = buf.filename or buf._type or Util.UNTITLED_TEXT
    local tabtext= string.match(filename, ".-([^\\/]*)$")
    --update modified indicator in tab
    if toolbar.cfg.tabmodified == 0 and buf.modify then tabtext= tabtext .. "*" end --modified: change tab text
    if buf._right_side then
      tabtext= ">"..tabtext
    end
    local tooltip= buf.filename
    if tooltip then
      if buf.mod_time then tooltip= tooltip.."\n"..os.date('%c', buf.mod_time) end
    else
      tooltip= filename
    end
    toolbar.settab(ntab, tabtext:iconv('UTF-8',_CHARSET), tooltip:iconv('UTF-8',_CHARSET))
    toolbar.hidetab(ntab, toolbar.isbufhide(buf))
    if toolbar.cfg.tabmodified ~= 0 then toolbar.modifiedtab(ntab, buf.modify) end --modified: change tab color/img
  end

  function toolbar.update_all_modified()
    for i, buf in ipairs(_BUFFERS) do
      set_chg_tabbuf(buf)
    end
  end

  --select a buffer's tab
  function toolbar.seltabbuf(buf)
    --select the top toolbar and get the tab number of the buffer
    local ntab= getntabbuff(buf)
    --force visible state 'before' activate the tab
    toolbar.hidetab(ntab, toolbar.isbufhide(buf))
    toolbar.currenttab= ntab
    toolbar.activatetab(ntab)
    set_chg_tabbuf(buf)
  end

  --select the top toolbar and get the buffer number of a tab
  function toolbar.gettabnbuff(ntab)
    --tabs are in the top bar
    toolbar.sel_top_bar()
    for i=1,#_BUFFERS do
      if toolbar.buffers[i] == ntab then return i end
    end
    return 0 --not found
  end

  events_connect(events.SAVE_POINT_REACHED, set_chg_tabbuf)
  events_connect(events.SAVE_POINT_LEFT, set_chg_tabbuf)

  function toolbar.selecttab(ntab)
    --select the top toolbar and get the buffer number of a tab
    local nb= toolbar.gettabnbuff(ntab)
    if nb > 0 then
      local buf= _BUFFERS[nb]
      toolbar.seltabbuf(buf)
      --check if a view change is needed
      if Proj and Proj.tab_changeView(buf) then return end
      Util.goto_buffer(buf)
    end
  end

  local function update_statusbar()
    events.emit(events.UPDATE_UI, buffer.UPDATE_CONTENT) -- for updating statusbar
  end

  local function lexer_selected(lex_sel)
    buffer:set_lexer(lex_sel)
    update_statusbar()
    toolbar.update_lexerdefaults() --update config panel
  end

  function toolbar.select_lexer()
    local lexers = {}
    local LEXERS = _SCINTILLA.properties.lexer_language[1]
    for name in buffer:private_lexer_call(LEXERS):gmatch('[^\n]+') do lexers[#lexers + 1] = name end
    toolbar.small_chooser(_L['Select Lexer'], buffer:get_lexer(), lexer_selected, lexers, "T2_TAB#4",
      toolbar.ANCHOR.HCENTER, 250, 300, "LEXER")
  end

  local function eol_selected(eol_sel)
    local mode= string.match(eol_sel,'%+') and buffer.EOL_CRLF or buffer.EOL_LF
    buffer.eol_mode = mode
    buffer:convert_eols(mode)
    update_statusbar()
    toolbar.setcfg_from_eolmode() --update config panel
  end

  local function change_eol()
    local eol_list
    if WIN32 then eol_list= {"CR+LF (OS default)","LF"} else eol_list= {"CR+LF","LF (OS default)"} end
    toolbar.small_chooser("Select EOL", eol_list[buffer.eol_mode == buffer.EOL_CRLF and 1 or 2], eol_selected, eol_list, "T2_TAB#5",
      toolbar.ANCHOR.HCENTER, 210, 110, "dialog-apply")
  end

  local function enc_selected(enc_sel)
    buffer:set_encoding(enc_sel)
    update_statusbar()
    if actions then
      actions.updateaction("set_enc_utf8")
      actions.updateaction("set_enc_ascii")
      actions.updateaction("set_enc_1252")
      actions.updateaction("set_enc_8859")
      actions.updateaction("set_enc_utf16")
    end
  end

  local function change_encoding()
    local enc_list= {'UTF-8','ASCII','CP1252','ISO-8859-1','UTF-16LE'}
    toolbar.small_chooser("Select buffer enconding", buffer.encoding, enc_selected, enc_list, "T2_TAB#7",
      toolbar.ANCHOR.HCENTER, 210, 185, "insert-text")
  end

  local function go_line_col(line, col)
    if line and col then
      line= math.floor(line)
      col= math.floor(col)
      buffer:ensure_visible_enforce_policy(line)
      local pos = buffer:find_column(line, col)
      buffer:goto_pos(pos)
    end
  end
  local function gotoline_selected(linenum)
    go_line_col(tonumber(linenum), 1)
  end
  local function gotocol_selected(colnum)
    local line = buffer:line_from_position(buffer.current_pos)
    go_line_col(line, tonumber(colnum))
  end

  events_connect("toolbar_tabclicked", function(ntab,ntoolbar,ntabgroup,keyflags)
    toolbar.keyflags= keyflags
    --ui.statusbar_text= "tab "..ntab.." clicked"
    if ntoolbar == toolbar.TOP_TOOLBAR then
      --tab bar click
      toolbar.selecttab(ntab)
    elseif ntoolbar == toolbar.STAT_TOOLBAR then
      --status bar click
      if ntab == 1 then --info
        if toolbar.results_onoff then toolbar.results_onoff() end --show/hide result toolbar
      elseif ntab == 2 then --Line
        if Proj then Proj.store_current_pos(true) end
        toolbar.small_edit("Goto line", "", "Line number", gotoline_selected, "T2_TAB#2", toolbar.ANCHOR.HCENTER, 200, 59, "go-jump")
      elseif ntab == 3 then --Col
        if Proj then Proj.store_current_pos(true) end
        toolbar.small_edit("Goto Column", "", "Column number", gotocol_selected, "T2_TAB#3", toolbar.ANCHOR.HCENTER, 200, 59, "go-jump")
      elseif ntab == 4 then --lexer
        --textadept.file_types.select_lexer()
        toolbar.select_lexer()
      elseif ntab == 5 then --eol
        change_eol()
      elseif ntab == 6 then --indent
        toolbar.toggle_buffer_configtab()
      elseif ntab == 7 then --encoding
        change_encoding()
      end
    elseif ntoolbar == toolbar.RIGHT_TOOLBAR then
      --config panel
      toolbar.config_tab_click(ntab)
    end
  end)

  events_connect("toolbar_tabRclicked", function(ntab,ntoolbar,ntabgroup,keyflags)
    toolbar.keyflags= keyflags
    --ui.statusbar_text= "tab "..ntab.." R clicked"
    if ntoolbar == toolbar.TOP_TOOLBAR then
      toolbar.selecttab(ntab)
      return true --open context menu
    end
  end)

  events_connect("toolbar_tab2clicked", function(ntab,ntoolbar,ntabgroup,keyflags)
    toolbar.keyflags= keyflags
    --double click tab: close current buffer
    --ui.statusbar_text= "tab "..ntab.." 2 clicked"
    if ntoolbar == 0 and toolbar.cfg.tab2clickclose then
      if Proj then Proj.close_buffer() else buffer:close() end
    end
  end)

  events_connect("toolbar_tabclose", function(ntab,ntoolbar,ntabgroup,keyflags)
    toolbar.keyflags= keyflags
    --close tab button clicked: close current buffer
    --ui.statusbar_text= "tab "..ntab.." close clicked"
    if ntoolbar == 0 then
      if Proj then Proj.close_buffer() else buffer:close() end
    end
  end)

  events_connect(events.FILE_OPENED, function()
    --select the top toolbar and get the tab number of the buffer
    local ntab= getntabbuff(buffer)
    local filename = buffer.filename or buffer._type or Util.UNTITLED_TEXT
    toolbar.settab(ntab, string.match(filename, ".-([^\\/]*)$"), filename)
    toolbar.seltabbuf(buffer)
  end)

  events_connect(events.BUFFER_NEW, function()
    if _BUFFERS[buffer] > 0 then --ignore command line TA
      --select the top toolbar and get the tab number of the buffer
      local ntab= getntabbuff(buffer)
      local filename= Util.UNTITLED_TEXT
      toolbar.settab(ntab, filename, filename)
      toolbar.seltabbuf(buffer)
    end
  end)

  events_connect(events.BUFFER_DELETED, function()
    --TA doesn't inform which buffer was deleted so,
    --check the tab list to find out
    --tabs are in the top bar
    toolbar.sel_top_bar()
    if #toolbar.buffers == #_BUFFERS+1 then
      local deleted= false
      for i=1, #_BUFFERS do
        if toolbar.buffers[i] ~= _BUFFERS[i]._buffnum then
          toolbar.deletetab(toolbar.buffers[i])
          deleted= true
          break
        end
      end
      if not deleted then --delete the last one
        toolbar.deletetab(toolbar.buffers[#toolbar.buffers])
      end
      --rebuild the buffers list
      toolbar.buffers={}
      for i=1,#_BUFFERS do
        toolbar.buffers[i]= _BUFFERS[i]._buffnum
      end
    else
      ui.statusbar_text= "ERROR, toolbar N="..#toolbar.buffers.." buffers N="..#_BUFFERS
    end
    --select current buffer's tab
    toolbar.seltabbuf(buffer)
  end)

  events_connect(events.BUFFER_AFTER_SWITCH, function()
    toolbar.seltabbuf(buffer)
  end)

  events_connect(events.VIEW_AFTER_SWITCH, function()
    toolbar.seltabbuf(buffer)
  end)

  local function getCfgNum(line, field)
    if line:find('^'..field..':') then
      toolbar[field]= tonumber(line:match('^'..field..':(.+)$'))
      return true
    end
    return false
  end

  local function getCfgBool(line, field)
    if line:find('^'..field..':t') then
      toolbar[field]= true
      return true
    end
    if line:find('^'..field..':f') then
      toolbar[field]= false
      return true
    end
    return false
  end

  --define config fields
  local function tbconfig_int(var, defval)
    local ci= Util.cfg_int
    if type(defval) == "table" then ci= Util.cfg_int2 + #defval -2 end
    Util.add_config_field(toolbar.cfg, var, ci, defval)
  end
  local function tbconfig_color(var, defval)
    Util.add_config_field(toolbar.cfg, var, Util.cfg_hex, defval)
  end
  local function tbconfig_bool(var, defval)
    Util.add_config_field(toolbar.cfg, var, Util.cfg_bool, defval)
  end
  local function tbconfig_str(var, defval)
    Util.add_config_field(toolbar.cfg, var, Util.cfg_str, defval)
  end
  local function tbconfig_imgs(var, maxidx)
    Util.add_config_field(toolbar.cfg, var, Util.cfg_str, "", maxidx)
  end
  --config images
  local function load_multipart_img()
    --already loaded?
    if toolbar.multipartimgs and toolbar.multipartimgs[0] == toolbar.themepath then return end
    toolbar.multipartimgs= {}
    toolbar.multipartimgs[0]= toolbar.themepath --save theme path
    for fname in lfs.dir(toolbar.themepath) do
      local baseimg= string.match(fname, "(.-)__[LRTBWH0123456789]+%.png$")
      if baseimg then toolbar.multipartimgs[baseimg]= string.match(fname, "(.-)%.png$") end
    end
  end
  --add the multipart img suffix
  function toolbar.themed_multipart_img(img)
    load_multipart_img()
    return toolbar.multipartimgs[img] or img
  end

  function toolbar.themed_icon(name,icon,nicon)
    --change image only in this toolbar
    toolbar.seticon(name,toolbar.themed_multipart_img(icon),nicon or toolbar.TTBI_TB.IT_NORMAL,true)
  end

  function toolbar.get_img(idx)
    return toolbar.cfg[ "toolbar_img#"..idx ]
  end
  function toolbar.set_img(idx, newimg, onlyifempty)
    if onlyifempty and toolbar.get_img(idx) ~= "" then return end
    toolbar.cfg[ "toolbar_img#"..idx ]= newimg
  end
  function toolbar.get_img_count()
    return toolbar.cfg[toolbar.cfg[0]["toolbar_img#1"]][4]
  end
  function toolbar.get_backimg(idx)
    return toolbar.cfg[ "toolbar_back#"..idx ]
  end
  function toolbar.set_backimg(idx, newimg, onlyifempty)
    if onlyifempty and toolbar.get_backimg(idx) ~= "" then return end
    toolbar.cfg[ "toolbar_back#"..idx ]= newimg
  end
  function toolbar.get_backimg_count()
    return toolbar.cfg[toolbar.cfg[0]["toolbar_back#1"]][4]
  end
  --get adjust settings (idx=1..6)
  local function tbconfig_getadj(idx)
    local vadj= toolbar.cfg.toolbar_adj[idx]
    --bwidth(idx=1) / bheight(idx=2): 0=use "butsize"
    if vadj <= 0 and idx <= 2 then vadj= toolbar.cfg.butsize end
    return vadj
  end
  local function tbconfig_is_adjset()
    return (toolbar.cfg.toolbar_adj[1] >= 0) --(-1 not used)
  end

  function toolbar.set_defaults()
    --set toolbar defaults
    toolbar.buffnum= 1  --assign a unique number to each buffer
    toolbar.buffers= {} --list of buffnum in use
    toolbar.themepath= _USERHOME.."/toolbar/bar-sm-light/"
    toolbar.iconspath= _USERHOME.."/toolbar/icons/light/"
    toolbar.tb0= true --only show toolbar 0 (horizontal)
    toolbar.tb1= false
    toolbar.statbar= 0 --0:use default statusbar 1:create 2:already created
    toolbar.html_tb=false --html toolbar on/off
    toolbar.list_tb=false --list toolbar on/off
    toolbar.results_tb=false --results toolbar on/off
    --config panel
    toolbar.cfgpnl_width=350
    toolbar.cfgpnl_ymargin=3
    toolbar.cfgpnl_xmargin=3
    toolbar.cfgpnl_xtext=30
    toolbar.cfgpnl_xcontrol3=170
    toolbar.cfgpnl_xcontrol2=230
    toolbar.cfgpnl_xcontrol=290
    toolbar.cfgpnl_rheight=24

    --toolbar config
    toolbar.cfg= {}
    --toolbar images
    tbconfig_imgs(  "toolbar_img",      toolbar.TTBI_TB.N) --toolbar_img#1..#N
    tbconfig_imgs(  "toolbar_back",     5) --toolbar_back#1..#5
    --icons theme
    tbconfig_str(   "icons",            "light")
    --adjust
    tbconfig_int(   "toolbar_adj",      {-1, 0, 2, 1, 4, 4}) --0=use "butsize" (-1 not used)

    tbconfig_int(   "barsize",          27)
    tbconfig_int(   "butsize",          24)
    tbconfig_int(   "imgsize",          16)
    tbconfig_int(   "newrowoff",        3)
    tbconfig_int(   "textfont_sz",      12)
    tbconfig_int(   "textfont_yoffset", 0)
    tbconfig_color( "textcolor_normal", 0x101010)
    tbconfig_color( "textcolor_grayed", 0x808080)
    tbconfig_color( "backcolor_erow",   -1) --even rows background color (-1:don't change it)
    tbconfig_color( "backcolor_hi",     -1) --highlight row color (-1:don't change it)
    --tabs
    tbconfig_int(   "tabxmargin",       5)
    tbconfig_int(   "tabxsep",          -1)
    tbconfig_bool(  "tabwithclose",     false)
    tbconfig_bool(  "tab2clickclose",   true)
    tbconfig_int(   "tabmodified",      0)
    tbconfig_int(   "tabfont_sz",       0)
    tbconfig_int(   "tabfont_yoffset",  0)
    tbconfig_color( "tabcolor_normal",  0x000000)
    tbconfig_color( "tabcolor_hilight", 0x000000)
    tbconfig_color( "tabcolor_active",  0x000000)
    tbconfig_color( "tabcolor_modif",   0x800000)
    tbconfig_color( "tabcolor_grayed",  0x808080)
    tbconfig_int(   "tabwidthmode",     0) --0=text >0=fixed <0=expand
    tbconfig_int(   "tabwidthmin",      0)
    tbconfig_int(   "tabwidthmax",      0)
    --status bar
    tbconfig_int(   "statsize",         20)
    tbconfig_int(   "statbutsize",      20)
    tbconfig_int(   "statimgsize",      16)
    tbconfig_int(   "statxmargin",      -3)
    tbconfig_int(   "statxsep",         -1)
    tbconfig_int(   "statfont_sz",      12)
    tbconfig_int(   "statfont_yoffset", -2)
    tbconfig_color( "statcolor_normal", 0x202020)
    tbconfig_color( "statcolor_hilight",0x000000)
    --pop-ups
    tbconfig_color( "popup_back",       0xFFFFFF)
  end

  function toolbar.set_theme(theme)
    toolbar.themepath= _USERHOME.."/toolbar/"..theme.."/"
    Util.load_config_file(toolbar.cfg, toolbar.themepath.."toolbar.cfg")
    toolbar.iconspath= _USERHOME.."/toolbar/icons/"..toolbar.cfg.icons.."/"
  end

  function toolbar.add_tabs_here(extrah, tabwithclose, tabwidthmode, tabwidthmin)
    local xcontrol=4 --x-expanded: use all available space
    if toolbar.tabpos > 1 then
      xcontrol=5 --x-expanded + left align (new row)
    end
    if not extrah then extrah=0 end
    if tabwithclose == nil then tabwithclose= toolbar.cfg.tabwithclose end
    if tabwidthmode == nil then tabwidthmode= toolbar.cfg.tabwidthmode end
    if tabwidthmin  == nil then tabwidthmin=  toolbar.cfg.tabwidthmin  end
    --toolbar.addtabs(xmargin,xsep,withclose,modified(1=img,2=color),fontsz,fontyoffset,[tab-drag],[xcontrol],[height],[font-num])
    toolbar.addtabs(toolbar.cfg.tabxmargin, toolbar.cfg.tabxsep, tabwithclose, toolbar.cfg.tabmodified,
        toolbar.cfg.tabfont_sz+toolbar.font_tabs_extrasz, toolbar.cfg.tabfont_yoffset,true,xcontrol,toolbar.cfg.barsize+extrah,toolbar.font_tabs) --enable drag support

    --toolbar.tabfontcolor(NORMcol,HIcol,ACTIVEcol,MODIFcol,GRAYcol)
    toolbar.tabfontcolor(toolbar.cfg.tabcolor_normal, toolbar.cfg.tabcolor_hilight, toolbar.cfg.tabcolor_active,
        toolbar.cfg.tabcolor_modif, toolbar.cfg.tabcolor_grayed)

    --tabwidthmode: 0=text >0=fixed <0=expand
    toolbar.tabwidth(0, tabwidthmode, tabwidthmin, toolbar.cfg.tabwidthmax)
  end

  --put next buttons in a new row/column
  function toolbar.newrow(yoff)
    toolbar.gotopos(toolbar.cfg.newrowoff + (yoff or 0)) --new row
  end

  local function check_tab_img(idx, withclose, defimg)
    local img= toolbar.get_img(idx)
    if img ~= "" then
      --remove "-close" from current if set
      local baseimg= string.match(img, "(.-)-close$")
      if baseimg then img=baseimg end
    else
      img= defimg --not set, use default
    end
    --add "-close" when needed
    if withclose then img= img.. "-close" end
    toolbar.set_img(idx, img)
  end

  function toolbar.add_close_tabimg(withclose)
    check_tab_img(toolbar.TTBI_TB.TAB_NORMAL,   withclose, "ttb-tab-normal")
    check_tab_img(toolbar.TTBI_TB.TAB_DISABLED, withclose, "ttb-tab-disabled")
    check_tab_img(toolbar.TTBI_TB.TAB_HILIGHT,  withclose, "ttb-tab-hilight")
    check_tab_img(toolbar.TTBI_TB.TAB_ACTIVE,   withclose, "ttb-tab-active")
  end

  --create the toolbar (tabpos, nvertcols)
  --tabpos=0: 1 row, use default tabs
  --tabpos=1: 1 row, tabs & buttons in the same line
  --tabpos=2: 2 rows, tabs at the top
  --tabpos=3: 2 rows, tabs at the bottom
  --nvertcols= 0..2 = number of columns in vertical toolbar
  --stbar=0: use default
  --stbar=1: use tatoolbar
  --configpanel==true: add a button to show config panel and create the config panel
  function toolbar.create(tabpos, nvertcols, stbar, configpanel)
    toolbar.current_toolbar=-1
    toolbar.tabpos= tabpos
    ui.tabs= (tabpos == 0)  --hide regular tabbar if needed
    toolbar.statbar= stbar
    toolbar.configpanel=configpanel

    --tabs to show
    if not nvertcols then nvertcols= 0 end
    toolbar.tb1= (nvertcols > 0)    --vertical
    toolbar.tb0= ((tabpos > 0) or (nvertcols==0)) --horizontal

    local bsz0= toolbar.cfg.barsize
    local butth= bsz0
    if tabpos >= 2 then
      bsz0= bsz0*2 +1 --two rows
      butth= butth+1
    end
    local bsz1= toolbar.cfg.barsize
    if nvertcols > 1 then
      bsz1= bsz1*2 +1 --two rows
    end

    --create toolbar: barsize,buttonsize,imgsize,[numtoolbar/isvertical],[imgpath]
    if toolbar.tb0 then   --create the horizontal toolbar
      toolbar.sel_top_bar()
      toolbar.new(bsz0, toolbar.cfg.butsize, toolbar.cfg.imgsize, toolbar.TOP_TOOLBAR, toolbar.themepath)
      toolbar.current_toolbar= 0
      toolbar.current_tb_group= 0
      --choose the right tab image
      toolbar.add_close_tabimg(toolbar.cfg.tabwithclose)
      --add/change some images
      for i=1, toolbar.get_img_count() do
        local img= toolbar.get_img(i)
        if img ~= "" then toolbar.themed_icon(toolbar.globalicon, img, i) end
      end
      if tabpos == 1 then --horizontal back x 1row
        toolbar.themed_icon(toolbar.globalicon, toolbar.get_backimg(1), toolbar.TTBI_TB.BACKGROUND)
      elseif tabpos > 1 then --horizontal back x 2rows
        toolbar.themed_icon(toolbar.globalicon, toolbar.get_backimg(2), toolbar.TTBI_TB.BACKGROUND)
      end
      if tabpos == 2 then
        --2 rows, tabs at the top
        toolbar.add_tabs_here(1)
        --put buttons in another group
        butth= toolbar.cfg.barsize
      end
      --buttons group: align left + width=use buttons / fixed height=butth
      toolbar.addgroup(toolbar.GRPC.FIRST|toolbar.GRPC.ITEMSIZE, 0, 0, butth)
      if tbconfig_is_adjset() then
        --bwidth,bheight,xmargin,ymargin,xoff,yoff
        toolbar.adjust(tbconfig_getadj(1),tbconfig_getadj(2),tbconfig_getadj(3),tbconfig_getadj(4),tbconfig_getadj(5),tbconfig_getadj(6))
      end
      toolbar.setdefaulttextfont()
    else
      --hide the horizonatal (top) toolbar
      toolbar.sel_top_bar()
      toolbar.show(false)
    end

    --create toolbar: barsize,buttonsize,imgsize,[numtoolbar/isvertical],[imgpath]
    if toolbar.tb1 then   --create the vertical toolbar
      toolbar.sel_left_bar()
      toolbar.new(bsz1, toolbar.cfg.butsize, toolbar.cfg.imgsize, toolbar.LEFT_TOOLBAR, toolbar.themepath)
      toolbar.current_toolbar= 1
      toolbar.current_tb_group= 0
      --buttons group: align top + height=use buttons / fixed width
      toolbar.addgroup(0, toolbar.GRPC.FIRST|toolbar.GRPC.ITEMSIZE, toolbar.cfg.barsize, 0)
      if tbconfig_is_adjset() then
        --bwidth,bheight,xmargin,ymargin,xoff,yoff
        toolbar.adjust(tbconfig_getadj(1),tbconfig_getadj(2),tbconfig_getadj(3),tbconfig_getadj(4),tbconfig_getadj(5),tbconfig_getadj(6))
      end
      --add/change some images
      for i=1, toolbar.get_img_count() do
        local img= toolbar.get_img(i)
        if img ~= "" then toolbar.themed_icon(toolbar.globalicon, img, i) end
      end
      if nvertcols < 2 then --vertical back x 1col
        toolbar.themed_icon(toolbar.globalicon, toolbar.get_backimg(3), toolbar.TTBI_TB.BACKGROUND)
      else --vertical back x 2cols
        toolbar.themed_icon(toolbar.globalicon, toolbar.get_backimg(4), toolbar.TTBI_TB.BACKGROUND)
      end
      toolbar.setdefaulttextfont()
      toolbar.show(true)
    else
      --hide the vertical (left) toolbar
      toolbar.sel_left_bar()
      toolbar.show(false)
    end
    if toolbar.tb0 then
      --add buttons in the horizontal (top) toolbar
      toolbar.sel_top_bar()
    end
    --call addpending() later
    toolbar._pending= true
  end

  --add tabs to top toolbar if pending
  function toolbar.addpending()
    toolbar.sel_top_bar()
    if toolbar._pending then
      toolbar._pending= false
      --1 row, tabs in the same line or 2 rows, tabs at the bottom
      if toolbar.tabpos == 1 or toolbar.tabpos == 3 then
        toolbar.add_tabs_here()
      end
      toolbar.show(toolbar.tb0)  --show the horizontal toolbar
    end
  end

  function toolbar.addrightgroup()
    --buttons group: align right + width=use buttons / fixed height=butth
    toolbar.addgroup(toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE, 0, 0, toolbar.cfg.barsize)
    if tbconfig_is_adjset() then
      --bwidth,bheight,xmargin,ymargin,xoff,yoff
      toolbar.adjust(tbconfig_getadj(1),tbconfig_getadj(2),0,tbconfig_getadj(4),tbconfig_getadj(5),tbconfig_getadj(6))
    end
  end

  function toolbar.create_statusbar()
    toolbar.sel_stat_bar()
    toolbar.new(toolbar.cfg.statsize, toolbar.cfg.statbutsize, toolbar.cfg.statimgsize, toolbar.STAT_TOOLBAR, toolbar.themepath)
    toolbar.current_toolbar= 2
    toolbar.current_tb_group= 0
    local bki= toolbar.get_backimg(5)
    toolbar.themed_icon(toolbar.globalicon, bki, toolbar.TTBI_TB.TAB_NORMAL)
    toolbar.themed_icon(toolbar.globalicon, bki, toolbar.TTBI_TB.TAB_DISABLED)
    toolbar.themed_icon(toolbar.globalicon, bki, toolbar.TTBI_TB.TAB_HILIGHT)
    toolbar.themed_icon(toolbar.globalicon, bki, toolbar.TTBI_TB.TAB_ACTIVE)
    toolbar.setdefaulttextfont()
    toolbar.statbar= 2 --created
  end

  function toolbar.shw_statusbar()
    if toolbar.statbar == 1 then
      --use tatoolbar's status bar
      toolbar.create_statusbar()
    end
    toolbar.sel_stat_bar()
    if toolbar.statbar == 2 then
      --toolbar.addtabs(xmargin,xsep,withclose,modified(1=img,2=color),fontsz,fontyoffset,[tab-drag],[xcontrol],[height],[font-num])
      toolbar.addtabs(toolbar.cfg.statxmargin, toolbar.cfg.statxsep, false, 0,
        toolbar.cfg.statfont_sz+toolbar.font_status_extrasz, toolbar.cfg.statfont_yoffset, false, 4, toolbar.cfg.statsize, toolbar.font_status) --x-expanded
      toolbar.tabfontcolor( toolbar.cfg.statcolor_normal, toolbar.cfg.statcolor_hilight, toolbar.cfg.tabcolor_active,
        toolbar.cfg.tabcolor_modif, toolbar.cfg.statcolor_normal ) --grayed= normal
      --statusbar has 7 sections: 1=text, 2=line, 3=col, 4=lexer, 5=eol, 6=indent, 7=encoding
      --change the order of enconding and indentation so that a click in the last section (indent) opens the config panel
      local statorder= {1,2,3,4,5,7,6}
      for i=1, 7 do
        toolbar.settab(statorder[i],"", "")  --create the status panels
      end
      toolbar.tabwidth(1,-1, 150) --expand this section, min width= 150
      --NOTE: using variable width in fields 2..7 in "WIN32" breaks the UI!!
      -- this fields are updated from the UPDATE-UI event and
      -- calling gdk_cairo_create in this context (to get the text extension) freeze the UI for a second
      -- and breaks the editor update mecanism (this works fine under LINUX, though)
      -- so, fixed width is used for these fields.
      toolbar.tabwidth(2, _L['Line:'].." 99999/99999")
      local s="actionscript"  --same width = looks better
      toolbar.tabwidth(3,s) --"Col: 999"
      toolbar.tabwidth(4,s) --"actionscript"
      toolbar.tabwidth(5,s) --"CRLF"
      s= "Tabuladores: 8" --Spanish translation is longer
      toolbar.tabwidth(6,s) --"Spaces: 8"
      toolbar.tabwidth(7,s) --"ISO-8859-1"
      toolbar.show(true)
    else
      --use the default status bar
      toolbar.show(false)
    end
  end

  --toolbar ready, show it
  function toolbar.ready()
    --add HTML quicktype toolbar if required
    if toolbar.add_html_toolbar ~= nil then toolbar.add_html_toolbar() else toolbar.sel_left_bar() end
    if toolbar.configpanel then
      --add a button to show/hide the config panel
      toolbar.add_showconfig_button()
    end
    toolbar.addpending()
    --show status bar if enabled
    toolbar.shw_statusbar()
    toolbar.sel_top_bar()
    if toolbar.configpanel then
      --create the config panel
      toolbar.add_config_panel()
    end
  end

  events_connect(events.INITIALIZED, function()
    if toolbar.tabpos > 0 then
      toolbar.sel_top_bar()
      --load existing buffers in tab-bar
      toolbar.buffers={}
      if #_BUFFERS > 0 then
        for i, buf in ipairs(_BUFFERS) do
          set_chg_tabbuf(buf)
          toolbar.buffers[i]= _BUFFERS[i]._buffnum
        end
      end
      toolbar.seltabbuf(buffer)  --select current buffer
    end
  end)

  --set the configured theme
  function toolbar.set_theme_from_config()
    --read the configuration file
    toolbar.load_config(true)
    local theme= toolbar.get_combo_txt("cbo.theme") or "bar-sm-light"
    toolbar.set_theme(theme)

    if toolbar.font_support() then
      --change editor font
      local nfont= toolbar.get_cfg_font_num("font.editor")
      local extrasz= toolbar.get_cfg_font_extrasize("font.editor")
      if nfont > 0 then
        local font= toolbar.get_font_name(nfont)
        for _, buff in ipairs(_BUFFERS) do buff.property['font']= font end
      end
      if extrasz ~= 0 then
        extrasz= extrasz + buffer.property['fontsize']
        for _, buff in ipairs(_BUFFERS) do buff.property['fontsize']=extrasz end
      end
      --load toolbar fonts
      toolbar.font_toolbars= toolbar.get_cfg_font_num("font.toolbars")
      toolbar.font_toolbars_extrasz= toolbar.get_cfg_font_extrasize("font.toolbars")
      toolbar.font_tabs= toolbar.get_cfg_font_num("font.tabs")
      toolbar.font_tabs_extrasz= toolbar.get_cfg_font_extrasize("font.tabs")
      toolbar.font_status= toolbar.get_cfg_font_num("font.status")
      toolbar.font_status_extrasz= toolbar.get_cfg_font_extrasize("font.status")
    else
      toolbar.font_toolbars= 0
      toolbar.font_toolbars_extrasz= 0
      toolbar.font_tabs= 0
      toolbar.font_tabs_extrasz= 0
      toolbar.font_status= 0
      toolbar.font_status_extrasz= 0
    end
  end

  --create the configured toolbars
  function toolbar.create_from_config()
    local tabclose= toolbar.get_radio_val("tbtabclose",3)
    if tabclose == 1 then toolbar.cfg.tabwithclose=false
    elseif tabclose == 2 then toolbar.cfg.tabwithclose=true end

    tabclose= toolbar.get_radio_val("tbtab2clickclose",3)
    if tabclose == 1 then toolbar.cfg.tab2clickclose=false
    elseif tabclose == 2 then toolbar.cfg.tab2clickclose=true end

    --create the toolbars (tabpos, nvertcols, stbar, configpanel)
    --tabpos=0: 1 row, use default tabs
    --tabpos=1: 1 row, tabs & buttons in the same line
    --tabpos=2: 2 rows, tabs at the top
    --tabpos=3: 2 rows, tabs at the bottom
    local tabpos= toolbar.get_radio_val("tbtabs",4) -1
    if tabpos < 0 then tabpos= 1 end
    --nvertcols= 0..2 = number of columns in vertical toolbar
    local nvertcols= toolbar.get_radio_val("tbvertbar", 3)
    if nvertcols < 1 then nvertcols=1 end --default= 1 row
    if nvertcols == 3 then --hide (only if htmltoolbar is not used)
      if toolbar.add_html_toolbar == nil then nvertcols=0 else nvertcols=1 end
    end
    --stbar=0: use default status bar
    --stbar=1: use toolbar's status bar
    local statbar= (toolbar.get_check_val("tbshowstatbar") and 1 or 0)
    --configpanel==true: add a button to show config panel and create the config panel
    toolbar.create(tabpos,nvertcols,statbar,true)
    --hide vertical scrollbar
    toolbar.tbshowminimap= toolbar.get_check_val("tbshowminimap")
    toolbar.tbhidemmapcfg= toolbar.get_check_val("tbhidemmapcfg")
    toolbar.tbreplvscroll= toolbar.get_check_val("tbreplvscroll")
    toolbar.tbreplhscroll= toolbar.get_check_val("tbreplhscroll")

    --create "results" toolbar
    if toolbar.createresultstb then toolbar.createresultstb() end
    --create "lists" toolbar (add buttons to top_bar to select the lists)
    if toolbar.createlisttb then toolbar.createlisttb() end
  end

  toolbar.set_defaults()
end
