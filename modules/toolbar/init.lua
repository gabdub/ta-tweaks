-- Copyright 2016-2017 Gabriel Dubatti. See LICENSE.
if toolbar then
  local Util = Util
  if actions then
    require('toolbar.actions')
  end
  --config panel on toolbar #3
  require('toolbar.configtb')

  local events, events_connect = events, events.connect
  local tbglobalicon="TOOLBAR"
  toolbar.cmds={}
  toolbar.cmds_n={}

  --select a toolbar as current
  function toolbar.sel_toolbar_n(ntb, ngrp)
    if ngrp == nil then ngrp = 0 end
    if toolbar.current_toolbar ~= ntb or toolbar.current_tb_group ~= ngrp then
      toolbar.current_toolbar= ntb
      toolbar.current_tb_group= ngrp
      toolbar.seltoolbar(ntb,ngrp)
    end
  end
  --select a toolbar by name
  function toolbar.sel_top_bar()
    toolbar.sel_toolbar_n(0)
  end
  function toolbar.sel_left_bar()
    toolbar.sel_toolbar_n(1)
  end
  function toolbar.sel_stat_bar()
    toolbar.sel_toolbar_n(2)
  end
  function toolbar.sel_config_bar()
    toolbar.sel_toolbar_n(3)
  end

  --define a toolbar button
  function toolbar.cmd(name,func,tooltip,icon,passname)
    toolbar.addbutton(name,tooltip)
    if passname then toolbar.cmds_n[name]= func else toolbar.cmds[name]= func end
    if icon == nil then
      toolbar.setthemeicon(name,name) --no icon: use 'name' from theme
    elseif string.match(icon,"%.png") == nil then
      toolbar.setthemeicon(name,icon) --no ".png": use 'icon' from theme
    else
      toolbar.seticon(name,icon)  --"icon.png": use the given icon file
    end
  end

  function toolbar.cmdtext(text,func,tooltip,name,usebutsz)
    if not name then name=text end
    local w=0
    if usebutsz then w=toolbar.butsize end
    toolbar.addtext(name,text,tooltip,w)
    toolbar.cmds[name]= func
  end

  function toolbar.setthemeicon(name,icon,num)
    --set button icon, get icon from theme's icons folder
    toolbar.seticon(name,toolbar.iconspath..icon..".png",num)
  end

  function toolbar.isbufhide(buf)
    if Proj then  --Project module?
      return toolbar.hideproject and (buf._project_select or buf._type == Proj.PRJT_SEARCH)
    end
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
    end
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
    local filename = buf.filename or buf._type or _L['Untitled']
    local tabtext= string.match(filename, ".-([^\\/]*)$")
    --update modified indicator in tab
    if toolbar.tabmodified == 0 then
       --change tab text
      if buf.modify then tabtext= tabtext .. "*" end
    else
      toolbar.modifiedtab(ntab, buf.modify)
    end
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
    --toolbar.settab(ntab, tabtext, tooltip)
    toolbar.hidetab(ntab, toolbar.isbufhide(buf))
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

  events_connect(events.SAVE_POINT_REACHED, set_chg_tabbuf)
  events_connect(events.SAVE_POINT_LEFT, set_chg_tabbuf)

  function toolbar.selecttab(ntab)
    --select the top toolbar and get the buffer number of a tab
    local nb= toolbar.gettabnbuff(ntab)
    if nb > 0 then
      local buf= _BUFFERS[nb]
      toolbar.seltabbuf(buf)
      if Proj then  --Project module?
        --check if a view change is needed
        if #_VIEWS > 1 then
          if buf._project_select ~= nil then
            --project buffer: force project view
            local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
            Util.goto_view(projv)
            return
          end
          --search results?
          if buf._type == Proj.PRJT_SEARCH then Proj.goto_searchview() return end
          --normal file: check we are not in a project view
          --change to left/right files view if needed (without project: 1/2, with project: 2/4)
          Proj.goto_filesview(false, buf._right_side)
        end
      end
      Util.goto_buffer(buf)
    end
  end

  local function change_encoding()
    local options= {'UTF-8','ASCII','ISO-8859-1','UTF-16LE'}
    local button, i = ui.dialogs.filteredlist{
      title = "Select buffer enconding",
      columns = _L['Name'],
      items = options }
    if button == 1 and i then
      buffer:set_encoding(options[i])
      events.emit(events.UPDATE_UI) -- for updating statusbar
    end
  end

  events_connect("toolbar_tabclicked", function(ntab,ntoolbar)
    --ui.statusbar_text= "tab "..ntab.." clicked"
    if ntoolbar == 0 then
      --tab bar click
      toolbar.selecttab(ntab)
    elseif ntoolbar == 2 then
      --status bar click
      if ntab == 2 then --Line
        if goto_line_col then
          goto_line_col(false)
        else
          textadept.editing.goto_line()
        end
      elseif ntab == 3 then --Col
        if goto_line_col then
          goto_line_col(true)
        end
      elseif ntab == 4 then --lexer
        textadept.file_types.select_lexer()
      elseif ntab == 5 or ntab == 6 then --eol / indent
        toolbar.toggle_buffer_configtab()
      elseif ntab == 7 then --encoding
        change_encoding()
      end
    elseif ntoolbar == 3 then
      --config panel
      toolbar.config_tab_click(ntab)
    end
  end)

  events_connect("toolbar_tabRclicked", function(ntab,ntoolbar)
    if ntoolbar == 0 then
      toolbar.selecttab(ntab)
      return true --open context menu
    end
  end)

  events_connect("toolbar_tab2clicked", function(ntab,ntoolbar)
    --double click tab: close current buffer
    --ui.statusbar_text= "tab "..ntab.." 2 clicked"
    if ntoolbar == 0 and toolbar.tab2clickclose then
      if Proj then Proj.close_buffer() else io.close_buffer() end
    end
  end)

  events_connect("toolbar_tabclose", function(ntab,ntoolbar)
    --close tab button clicked: close current buffer
    --ui.statusbar_text= "tab "..ntab.." close clicked"
    if ntoolbar == 0 then
      if Proj then Proj.close_buffer() else io.close_buffer() end
    end
  end)

  events_connect(events.FILE_OPENED, function()
    --select the top toolbar and get the tab number of the buffer
    local ntab= getntabbuff(buffer)
    local filename = buffer.filename or buffer._type or _L['Untitled']
    toolbar.settab(ntab, string.match(filename, ".-([^\\/]*)$"), filename)
    toolbar.seltabbuf(buffer)
  end)

  events_connect(events.BUFFER_NEW, function()
    if _BUFFERS[buffer] > 0 then --ignore TA start
      --select the top toolbar and get the tab number of the buffer
      local ntab= getntabbuff(buffer)
      local filename = _L['Untitled']
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
    toolbar.barsize= 27
    toolbar.butsize= 24
    toolbar.imgsize= 16
    toolbar.newrowoff= 3
    toolbar.adj= false
    toolbar.adj_bw= 24
    toolbar.adj_bh= 24
    toolbar.adj_xm= 2
    toolbar.adj_ym= 1
    toolbar.adj_xoff= 4
    toolbar.adj_yoff= 4
    --text buttons
    toolbar.textfont_sz= 12
    toolbar.textfont_yoffset= 0
    toolbar.textcolor_normal= 0x101010
    toolbar.textcolor_grayed= 0x808080
    --tabs
    toolbar.hideproject= true --don't show project files in tabs
    toolbar.tabxmargin= 5
    toolbar.tabxsep= -1
    toolbar.tabwithclose= false
    toolbar.tab2clickclose= true
    toolbar.tabwidthmode= 0  --0=text >0=fixed <0=expand
    toolbar.tabwidthmin= 0
    toolbar.tabwidthmax= 0
    toolbar.tabmodified= 0
    toolbar.tabfont_sz= 0
    toolbar.tabfont_yoffset= 0
    toolbar.tabcolor_normal= 0
    toolbar.tabcolor_hilight= 0
    toolbar.tabcolor_active= 0
    toolbar.tabcolor_modif= 0x800000
    toolbar.tabcolor_grayed= 0x808080
    --status-bar
    toolbar.statsize= 20
    toolbar.statbutsize= 20
    toolbar.statimgsize= 16
    toolbar.statxmargin= -3
    toolbar.statxsep= -1
    toolbar.statfont_sz= 12
    toolbar.statfont_yoffset=-2
    toolbar.statcolor_normal= 0x202020
    toolbar.statcolor_hilight= 0
    toolbar.popup_back= 0x000000
    --images
    toolbar.img= {}
    for i= 1, 33 do
      toolbar.img[i]= ""
    end
    toolbar.back= {}
    for i= 1, 5 do
      toolbar.back[i]= ""
    end
    --config panel
    toolbar.cfgpnl_width=350
    toolbar.cfgpnl_ymargin=3
    toolbar.cfgpnl_xmargin=3
    toolbar.cfgpnl_xtext=30
    toolbar.cfgpnl_xcontrol3=170
    toolbar.cfgpnl_xcontrol2=230
    toolbar.cfgpnl_xcontrol=290
    toolbar.cfgpnl_rheight=24
  end

  function toolbar.set_theme(theme)
    toolbar.themepath= _USERHOME.."/toolbar/"..theme.."/"
    local f = io.open(toolbar.themepath.."toolbar.cfg", 'rb')
    local img,i
    if f then
      for line in f:lines() do
        --toolbar cfg--
        if getCfgNum( line, 'barsize')          or
           getCfgNum( line, 'butsize')          or
           getCfgNum( line, 'imgsize')          or
           getCfgNum( line, 'newrowoff')        or
           getCfgNum( line, 'textfont_sz')      or
           getCfgNum( line, 'textfont_yoffset') or
           getCfgNum( line, 'textcolor_normal') or
           getCfgNum( line, 'textcolor_grayed') or
        --tabs cfg--
           getCfgNum( line, 'tabxmargin')       or
           getCfgNum( line, 'tabxsep')          or
           getCfgBool(line, 'tabwithclose')     or
           getCfgBool(line, 'tab2clickclose')   or
           getCfgNum( line, 'tabmodified')      or
           getCfgNum( line, 'tabfont_sz')       or
           getCfgNum( line, 'tabfont_yoffset')  or
           getCfgNum( line, 'tabcolor_normal')  or
           getCfgNum( line, 'tabcolor_hilight') or
           getCfgNum( line, 'tabcolor_active')  or
           getCfgNum( line, 'tabcolor_modif')   or
           getCfgNum( line, 'tabcolor_grayed')  or
           getCfgNum( line, 'tabwidthmode')     or
           getCfgNum( line, 'tabwidthmin')      or
           getCfgNum( line, 'tabwidthmax')      or
           getCfgNum( line, 'statcolor_normal') or
           getCfgNum( line, 'statcolor_hilight') or
           getCfgNum( line, 'popup_back') then

        elseif line:find('^toolbar_img:') then
          img, i = line:match('^toolbar_img:(.-),(.+)$')
          toolbar.img[tonumber(i)]= img

        elseif line:find('^toolbar_back:') then
          img, i = line:match('^toolbar_back:(.-),(.+)$')
          toolbar.back[tonumber(i)]= img

        elseif line:find('^icons:') then
          img = line:match('^icons:(%S+)%s-$')
          toolbar.iconspath= _USERHOME.."/toolbar/icons/"..img.."/"

        elseif line:find('^toolbar_adj:') then
          bw,bh,xm,ym,xoff,yoff = line:match('^toolbar_adj:(.-),(.-),(.-),(.-),(.-),(.+)$')
          toolbar.adj_bw = tonumber(bw)
          toolbar.adj_bh = tonumber(bh)
          toolbar.adj_xm = tonumber(xm)
          toolbar.adj_ym = tonumber(ym)
          toolbar.adj_xoff = tonumber(xoff)
          toolbar.adj_yoff = tonumber(yoff)
          toolbar.adj= true
        end
      end
      f:close()
    end
  end

  function toolbar.add_tabs_here(extrah)
    local xcontrol=4 --x-expanded: use all available space
    if toolbar.tabpos > 1 then
      xcontrol=5 --x-expanded + left align (new row)
    end
    if not extrah then extrah=0 end
    --toolbar.addtabs(xmargin,xsep,withclose,modified(1=img,2=color),fontsz,fontyoffset,[tab-drag],[xcontrol],[height])
    toolbar.addtabs(toolbar.tabxmargin, toolbar.tabxsep, toolbar.tabwithclose, toolbar.tabmodified,
        toolbar.tabfont_sz, toolbar.tabfont_yoffset,true,xcontrol,toolbar.barsize+extrah) --enable drag support

    --toolbar.tabfontcolor(NORMcol,HIcol,ACTIVEcol,MODIFcol,GRAYcol)
    toolbar.tabfontcolor(toolbar.tabcolor_normal, toolbar.tabcolor_hilight, toolbar.tabcolor_active,
        toolbar.tabcolor_modif, toolbar.tabcolor_grayed)

    --tabwidthmode: 0=text >0=fixed <0=expand
    toolbar.tabwidth(0, toolbar.tabwidthmode, toolbar.tabwidthmin, toolbar.tabwidthmax)
  end

  --put next buttons in a new row/column
  function toolbar.newrow(yoff)
    toolbar.gotopos(toolbar.newrowoff + (yoff or 0)) --new row
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

    local bsz0= toolbar.barsize
    local butth= bsz0
    if tabpos >= 2 then
      bsz0= bsz0*2 +1 --two rows
      butth= butth+1
    end
    local bsz1= toolbar.barsize
    if nvertcols > 1 then
      bsz1= bsz1*2 +1 --two rows
    end

    --create toolbar: barsize,buttonsize,imgsize,[numtoolbar/isvertical],[imgpath]
    if toolbar.tb0 then   --create the horizontal toolbar
      toolbar.new(bsz0, toolbar.butsize, toolbar.imgsize, 0, toolbar.themepath)
      toolbar.current_toolbar= 0
      toolbar.current_tb_group= 0
      if not toolbar.tabwithclose then
        --no close button in tabs, use a shorter tab end (part #3)
        if toolbar.img[7]  == "" then toolbar.img[7]=  "ttb-ntab3nc" end
        if toolbar.img[10] == "" then toolbar.img[10]= "ttb-dtab3nc" end
        if toolbar.img[13] == "" then toolbar.img[13]= "ttb-htab3nc" end
        if toolbar.img[16] == "" then toolbar.img[16]= "ttb-atab3nc" end
      end
      --add/change some images
      for i, img in ipairs(toolbar.img) do
        if img ~= "" then toolbar.seticon(tbglobalicon, img, i) end
      end
      if tabpos == 1 then
        toolbar.seticon(tbglobalicon, toolbar.back[1], 0, true)  --horizontal back x 1row
      elseif tabpos > 1 then
        toolbar.seticon(tbglobalicon, toolbar.back[2], 0, true)  --horizontal back x 2rows
      end
      if tabpos == 2 then
        --2 rows, tabs at the top
        toolbar.add_tabs_here(1)
        --put buttons in another group
        butth= toolbar.barsize
      end
      --buttons group: align left + width=use buttons / fixed height=butth
      toolbar.addgroup(9, 0, 0, butth)
      if toolbar.adj then
        --bwidth,bheight,xmargin,ymargin,xoff,yoff
        toolbar.adjust(toolbar.adj_bw,toolbar.adj_bh,toolbar.adj_xm,toolbar.adj_ym,toolbar.adj_xoff,toolbar.adj_yoff)
      end
      toolbar.textfont(toolbar.textfont_sz, toolbar.textfont_yoffset, toolbar.textcolor_normal, toolbar.textcolor_grayed)
    else
      --hide the horizonatal (top) toolbar
      toolbar.sel_top_bar()
      toolbar.show(false)
    end

    --create toolbar: barsize,buttonsize,imgsize,[numtoolbar/isvertical],[imgpath]
    if toolbar.tb1 then   --create the vertical toolbar
      toolbar.new(bsz1, toolbar.butsize, toolbar.imgsize, 1, toolbar.themepath)
      toolbar.current_toolbar= 1
      toolbar.current_tb_group= 0
      --buttons group: align top + height=use buttons / fixed width
      toolbar.addgroup(0, 9, toolbar.barsize, 0)
      if toolbar.adj then
        --bwidth,bheight,xmargin,ymargin,xoff,yoff
        toolbar.adjust(toolbar.adj_bw,toolbar.adj_bh,toolbar.adj_xm,toolbar.adj_ym,toolbar.adj_xoff,toolbar.adj_yoff)
      end
      --add/change some images
      for i, img in ipairs(toolbar.img) do
        if img ~= "" then toolbar.seticon(tbglobalicon, img, i) end
      end
      if nvertcols < 2 then
        toolbar.seticon(tbglobalicon, toolbar.back[3], 0, true)  --vertical back x 1col
      else
        toolbar.seticon(tbglobalicon, toolbar.back[4], 0, true)  --vertical back x 2cols
      end
      toolbar.textfont(toolbar.textfont_sz, toolbar.textfont_yoffset, toolbar.textcolor_normal, toolbar.textcolor_grayed)
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
    toolbar.addgroup(10, 0, 0, toolbar.barsize)
    if toolbar.adj then
      --bwidth,bheight,xmargin,ymargin,xoff,yoff
      toolbar.adjust(toolbar.adj_bw,toolbar.adj_bh,0,toolbar.adj_ym,toolbar.adj_xoff,toolbar.adj_yoff)
    end
  end

  function toolbar.create_statusbar()
    toolbar.new(toolbar.statsize, toolbar.statbutsize, toolbar.statimgsize, 2, toolbar.themepath)
    toolbar.current_toolbar= 2
    toolbar.current_tb_group= 0
    toolbar.seticon(tbglobalicon, toolbar.back[5], 0, true)
    local i=5 --5=normal 8=disabled 11=hilight 14=active
    while i < 15 do
      toolbar.seticon(tbglobalicon, "stat-ntab1", i,   true)
      toolbar.seticon(tbglobalicon, "stat-ntab2", i+1, true)
      toolbar.seticon(tbglobalicon, "stat-ntab3", i+2, true)
      i=i+3
    end
    toolbar.textfont(toolbar.textfont_sz, toolbar.textfont_yoffset, toolbar.textcolor_normal, toolbar.textcolor_grayed)
    toolbar.statbar= 2 --created
  end

  function toolbar.shw_statusbar()
    if toolbar.statbar == 1 then
      --use tatoolbar's status bar
      toolbar.create_statusbar()
    end
    toolbar.sel_stat_bar()
    if toolbar.statbar == 2 then
      --toolbar.addtabs(xmargin,xsep,withclose,modified(1=img,2=color),fontsz,fontyoffset,[tab-drag],[xcontrol],[height])
      toolbar.addtabs(toolbar.statxmargin, toolbar.statxsep, false, 0,
        toolbar.statfont_sz, toolbar.statfont_yoffset, false, 4, toolbar.statsize) --x-expanded
      toolbar.tabfontcolor( toolbar.statcolor_normal, toolbar.statcolor_hilight, toolbar.tabcolor_active,
        toolbar.tabcolor_modif, toolbar.statcolor_normal ) --grayed= normal
      --statusbar has 7 sections: text, line, col, lexer, eol, indent, encoding
      for i=1, 7 do
        toolbar.settab(i,"", "")  --create the status panels
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
    if toolbar.add_html_toolbar ~= nil then
      --HTML quicktype toolbar
      toolbar.add_html_toolbar()
    end
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
    local theme= toolbar.get_radio_val("tbtheme",3)
    --load toolbar theme from USERHOME
    if theme == 2 then
      toolbar.set_theme("bar-th-dark")
    elseif theme == 3 then
      toolbar.set_theme("bar-ch-dark")
    else
      toolbar.set_theme("bar-sm-light") --default
    end
  end

  --create the configured toolbars
  function toolbar.create_from_config()
    local tabclose= toolbar.get_radio_val("tbtabclose",3)
    if tabclose == 1 then toolbar.tabwithclose=false
    elseif tabclose == 2 then toolbar.tabwithclose=true end

    tabclose= toolbar.get_radio_val("tbtab2clickclose",3)
    if tabclose == 1 then toolbar.tab2clickclose=false
    elseif tabclose == 2 then toolbar.tab2clickclose=true end

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
  end

  --create the popup toolbar
  local function closepopup()
    toolbar.popup(4,false) --hide popup
  end
  function toolbar.create_popup()
    toolbar.new(50, 24, 16, 4, toolbar.themepath)
    toolbar.addgroup(8,8,0,0)
    toolbar.adjust(24,24,3,3,4,4)
    toolbar.textfont(toolbar.textfont_sz, toolbar.textfont_yoffset, toolbar.textcolor_normal, toolbar.textcolor_grayed)
    --toolbar.seticon(tbglobalicon, "ttb-cback", 0, true)
    toolbar.setbackcolor(tbglobalicon,toolbar.popup_back,fase,true)
    toolbar.cmd("pop-close", closepopup, "TEST hide popup", "window-close")
    toolbar.cmd("tog-book2", function() textadept.bookmarks.toggle() closepopup() end, "Toggle bookmark [Ctrl+F2]", "gnome-app-install-star" )
    toolbar.cmdtext("New", closepopup, "", "n1")
    toolbar.cmdtext("Open", closepopup, "", "n2")
    toolbar.cmdtext("Open recent...", closepopup, "", "n3")
  end
  function toolbar.show_popup(btname,relpos)
    toolbar.popup(4,true,btname,relpos)
  end
  events_connect("popup_close", closepopup)

  toolbar.set_defaults()
end
