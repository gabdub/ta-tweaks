if toolbar then
  local events, events_connect = events, events.connect
  local tbglobalicon="TOOLBAR"
  toolbar.cmds={}

  --define a toolbar button
  function toolbar.cmd(name,func,tooltip,icon)
    toolbar.addbutton(name,tooltip)
    toolbar.cmds[name]= func
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

  function toolbar.setthemeicon(name,icon)
    --set button icon, get icon from theme's icons folder
    toolbar.seticon(name,toolbar.iconspath..icon..".png")
  end

  function toolbar.isbufhide(buf)
    return toolbar.hideproject and (buf._project_select or buf._type == Proj.PRJT_SEARCH)
  end

  local function getntabbuff(buf)
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
    local tooltip= buf.filename
    if tooltip then
      if buf.mod_time then tooltip= tooltip.."\n"..os.date('%c', buf.mod_time) end
    else
      tooltip= filename
    end
    toolbar.settab(ntab, tabtext, tooltip)
    toolbar.hidetab(ntab, toolbar.isbufhide(buf))
  end

  --select a buffer's tab
  function toolbar.seltabbuf(buf)
    local ntab= getntabbuff(buf)
    --force visible state 'before' activate the tab
    toolbar.hidetab(ntab, toolbar.isbufhide(buf))
    toolbar.currenttab= ntab
    toolbar.activatetab(ntab)
    set_chg_tabbuf(buf)
  end

  --get the buffer number of a tab
  function toolbar.gettabnbuff(ntab)
    for i=1,#_BUFFERS do
      if toolbar.buffers[i] == ntab then return i end
    end
    return 0 --not found
  end

  events_connect("toolbar_clicked", function(buttonname,ntoolbar)
    if toolbar.cmds[buttonname] ~= nil then
      toolbar.cmds[buttonname]()
    else
      ui.statusbar_text= buttonname.." clicked"
    end
  end)

  function toolbar.update_all_tabs()
    --load existing buffers in tab-bar
    if #_BUFFERS > 0 then
      --rebuild the buffers list
      toolbar.buffers={}
      for i, buf in ipairs(_BUFFERS) do
        buf._buffnum= nil --force: get a new tab buffnum
        set_chg_tabbuf(buf)
        toolbar.buffers[i]= _BUFFERS[i]._buffnum
      end
    end
  end

  events_connect(events.SAVE_POINT_REACHED, set_chg_tabbuf)
  events_connect(events.SAVE_POINT_LEFT, set_chg_tabbuf)

  function toolbar.selecttab(ntab)
    local nb= toolbar.gettabnbuff(ntab)
    if nb > 0 then
      local buf= _BUFFERS[nb]
      toolbar.seltabbuf(buf)
      --check if a view change is needed
      if #_VIEWS > 1 then
        if buf._project_select ~= nil then
          --project buffer: force project view
          local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
          my_goto_view(projv)
        elseif buf._type == Proj.PRJT_SEARCH then
          --project search
          if Proj.search_vn ~= nil then
            my_goto_view(Proj.search_vn)
          else
            --activate search view
            Proj.goto_searchview()
            Proj.search_vn= _VIEWS[view]
          end
        else
          --normal file: check we are not in project view
          Proj.goto_filesview() --change to files view if needed
          if TA_MAYOR_VER < 9 then
            view.goto_buffer(view, _BUFFERS[buf], false)
          else
            view.goto_buffer(view, buf)
          end
        end
      end
    end
  end

  local function choose_menu_opt(submenu,cant)
    local menu= textadept.menu.menubar[_L['_Buffer']]
    local sm= menu[submenu]
    local options= {}
    for i=1,cant do
      options[i]= string.gsub( sm[i][1], "_", "" )
    end
    local button, i = ui.dialogs.filteredlist{
      title = "Select " .. string.gsub(submenu, "_", "" ),
      columns = _L['Name'],
      items = options }
    if button == 1 and i then
      local cmd= sm[i][2]
      if cmd then cmd() end
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
        textadept.editing.goto_line()
      elseif ntab == 4 then --lexer
        textadept.file_types.select_lexer()
      elseif ntab == 5 then --eol
        choose_menu_opt(_L['_EOL Mode'],2)
      elseif ntab == 6 then --indent
        choose_menu_opt(_L['_Indentation'],6)
      elseif ntab == 7 then --encoding
        choose_menu_opt(_L['E_ncoding'],5)
      end
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
      Proj.close_buffer()
    end
  end)

  events_connect("toolbar_tabclose", function(ntab,ntoolbar)
    --close tab button clicked: close current buffer
    --ui.statusbar_text= "tab "..ntab.." close clicked"
    if ntoolbar == 0 then
      Proj.close_buffer()
    end
  end)

  events_connect(events.FILE_OPENED, function()
    local ntab= getntabbuff(buffer)
    local filename = buffer.filename or buffer._type or _L['Untitled']
    toolbar.settab(ntab, string.match(filename, ".-([^\\/]*)$"), filename)
    toolbar.seltabbuf(buffer)
  end)

  events_connect(events.BUFFER_NEW, function()
    if _BUFFERS[buffer] > 0 then --ignore TA start
      local ntab= getntabbuff(buffer)
      local filename = _L['Untitled']
      toolbar.settab(ntab, filename, filename)
      toolbar.seltabbuf(buffer)
    end
  end)

  events_connect(events.BUFFER_DELETED, function()
    --TA doesn't inform which buffer was deleted so,
    --check the tab list to find out
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
    --images
    toolbar.img= {}
    for i= 1, 29 do
      toolbar.img[i]= ""
    end
    toolbar.back= {}
    for i= 1, 5 do
      toolbar.back[i]= ""
    end
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
           getCfgNum( line, 'statcolor_hilight') then

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
  function toolbar.create(tabpos, nvertcols, stbar)
    toolbar.tabpos= tabpos
    ui.tabs= (tabpos == 0)  --hide regular tabbar if needed
    toolbar.statbar= stbar

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
        toolbar.adjust(toolbar.adj_bw, toolbar.adj_bh, toolbar.adj_xm, toolbar.adj_ym,
          toolbar.adj_xoff, toolbar.adj_yoff)
      end
      toolbar.textfont(toolbar.textfont_sz, toolbar.textfont_yoffset, toolbar.textcolor_normal, toolbar.textcolor_grayed)
    else
      --hide the horizontal toolbar
      toolbar.seltoolbar(0)
      toolbar.show(false)
    end

    --create toolbar: barsize,buttonsize,imgsize,[numtoolbar/isvertical],[imgpath]
    if toolbar.tb1 then   --create the vertical toolbar
      toolbar.new(bsz1, toolbar.butsize, toolbar.imgsize, 1, toolbar.themepath)
      --buttons group: align top + height=use buttons / fixed width
      toolbar.addgroup(0, 9, toolbar.barsize, 0)
      if toolbar.adj then
        --bwidth,bheight,xmargin,ymargin,xoff,yoff
        toolbar.adjust(toolbar.adj_bw, toolbar.adj_bh, toolbar.adj_xm, toolbar.adj_ym,
          toolbar.adj_xoff, toolbar.adj_yoff)
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
      if tabpos > 0 then
        toolbar.seltoolbar(0)
      end
    else
      --hide the vertical toolbar
      toolbar.seltoolbar(1)
      toolbar.show(false)
      --add buttons in the horizontal toolbar
      toolbar.seltoolbar(0)
    end
  end

  function toolbar.create_statusbar()
    toolbar.new(toolbar.statsize, toolbar.statbutsize, toolbar.statimgsize, 2, toolbar.themepath)
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
    toolbar.seltoolbar(2)
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
    toolbar.seltoolbar(0)
    if toolbar.tabpos == 1 then
      --1 row, tabs in the same line
      toolbar.add_tabs_here()
    elseif toolbar.tabpos == 3 then
      --2 rows, tabs at the bottom
      toolbar.add_tabs_here()
    end
    toolbar.show(toolbar.tb0)  --show the horizontal toolbar
    if toolbar.tabpos > 0 then
      --toolbar.tabwidth(0,0,50,200)  --set tab width mode:0=text -1=fill >0:width / min & max
      toolbar.update_all_tabs()   --load existing buffers in tab-bar
      toolbar.seltabbuf(buffer)  --select current buffer
    end
    --show status bar if enabled
    toolbar.shw_statusbar()
    toolbar.seltoolbar(0)
  end

  toolbar.set_defaults()
end
