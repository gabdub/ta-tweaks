if toolbar then
  --define a toolbar button
  function toolbar.cmd(name,func,tooltip,icon)
    toolbar.addbutton(name,tooltip)
    toolbar[name]= func
    if icon == nil then
      icon= toolbar.iconspath..name..".png"
    end
    toolbar.seticon(name,icon)
  end

  local function set_chg_tab(ntab,buf)
    if buf == nil then
      --update current tab
      ntab= toolbar.currenttab
      buf= buffer
    end
    --if not toolbar.hideproject or (buf._project_select == nil and buf._type ~= Proj.PRJT_SEARCH) then
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
      toolbar.settab(ntab, tabtext, filename) --show image / change color
    --end
  end

  --select a toolbar tab
  function toolbar.seltab(ntab)
    toolbar.currenttab= ntab
    toolbar.activatetab(ntab)
    set_chg_tab()
  end

  events.connect("toolbar_clicked", function(button)
    if toolbar[button] ~= nil then
      toolbar[button]()
    else
      ui.statusbar_text= button.." clicked"
    end
  end)

  function toolbar.update_all_tabs()
    --load existing buffers in tab-bar
    if #_BUFFERS > 0 then
      for i, b in ipairs(_BUFFERS) do
        set_chg_tab(i,b)
      end
    end
  end

  events.connect(events.SAVE_POINT_REACHED, set_chg_tab)
  events.connect(events.SAVE_POINT_LEFT, set_chg_tab)

  events.connect("toolbar_tabclicked", function(ntab)
    --ui.statusbar_text= "tab "..ntab.." clicked"
    toolbar.seltab(ntab)
    --check if a view change is needed
    if #_VIEWS > 1 then
      if _BUFFERS[ntab]._project_select ~= nil then
        --project buffer: force project view
        local projv= Proj.prefview[Proj.PRJV_PROJECT] --preferred view for project
        my_goto_view(projv)
      elseif _BUFFERS[ntab]._type == Proj.PRJT_SEARCH then
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
          view.goto_buffer(view, ntab, false)
        else
          view.goto_buffer(view, _BUFFERS[ntab])
        end
      end
    end
  end)

  events.connect("toolbar_tab2clicked", function(ntab)
    --double click tab: close current buffer
    --ui.statusbar_text= "tab "..ntab.." 2 clicked"
    if toolbar.tab2clickclose then
      Proj.close_buffer()
    end
  end)

  events.connect("toolbar_tabclose", function(ntab)
    --close tab button clicked: close current buffer
    --ui.statusbar_text= "tab "..ntab.." close clicked"
    Proj.close_buffer()
  end)

  events.connect(events.FILE_OPENED, function()
    --if not toolbar.hideproject or (buffer._project_select == nil and buffer._type ~= Proj.PRJT_SEARCH) then
      local filename = buffer.filename or buffer._type or _L['Untitled']
      toolbar.settab(_BUFFERS[buffer], string.match(filename, ".-([^\\/]*)$"), filename)
      toolbar.seltab(_BUFFERS[buffer])
    --end
  end)

  events.connect(events.BUFFER_NEW, function()
    local ntab=_BUFFERS[buffer]
    if ntab > 0 then --ignore TA start
      --if not toolbar.hideproject or (buffer._project_select == nil and buffer._type ~= Proj.PRJT_SEARCH) then
        local filename = _L['Untitled']
        toolbar.settab(ntab, filename, filename)
        toolbar.seltab(ntab)
      --end
    end
  end)

  events.connect(events.BUFFER_DELETED, function()
    --TA doesn't inform which buffer was deleted so,
    --delete the first tab (all tab numbers are decremented) and update all tabs
    toolbar.deletetab(1)
    toolbar.update_all_tabs()
    toolbar.seltab(toolbar.currenttab) --keep last selection
  end)

  events.connect(events.BUFFER_AFTER_SWITCH, function()
    toolbar.seltab(_BUFFERS[buffer])
  end)

  events.connect(events.VIEW_AFTER_SWITCH, function()
    toolbar.seltab(_BUFFERS[buffer])
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
    --set defaults
    toolbar.themepath= _USERHOME.."/toolbar/bar-sm-light/"
    toolbar.iconspath= _USERHOME.."/toolbar/icons/light/"
    toolbar.tb0= true --only show toolbar 0 (horizontal)
    toolbar.tb1= false
    toolbar.barsize= 27
    toolbar.butsize= 24
    toolbar.imgsize= 16
    toolbar.newrowoff= 3
    toolbar.tabxmargin= 5
    toolbar.tabxsep= -1
    toolbar.tabwithclose= false
    toolbar.tab2clickclose= true
    toolbar.tabmodified= 0
    toolbar.tabfont_sz= 0
    toolbar.tabfont_yoffset= 0
    toolbar.tabcolor_normal= 0
    toolbar.tabcolor_hilight= 0
    toolbar.tabcolor_active= 0
    toolbar.tabcolor_modif= 0x800000
    toolbar.tabcolor_grayed= 0x808080
    toolbar.adj= false
    toolbar.adj_bw= 24
    toolbar.adj_bh= 24
    toolbar.adj_xm= 2
    toolbar.adj_ym= 1
    toolbar.adj_xoff= 4
    toolbar.adj_yoff= 4
    toolbar.hideproject= true
    toolbar.img= {}
    for i= 1, 14 do
      toolbar.img[i]= ""
    end
    toolbar.back= {}
    for i= 1, 4 do
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
           getCfgNum( line, 'tabcolor_grayed')  then

        elseif line:find('^toolbar_img:') then
          img, i = line:match('^toolbar_img:(.-),(.+)$')
          toolbar.img[tonumber(i)]= img

        elseif line:find('^toolbar_back:') then
          img, i = line:match('^toolbar_back:(.-),(.+)$')
          toolbar.back[tonumber(i)]= img

        elseif line:find('^icons:') then
          img = line:match('^icons:(.+)$')
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

  function toolbar.add_tabs_here()
    --toolbar.addtabs(xmargin,xsep,withclose,modified(1=img,2=color),fontsz,fontyoffset)
    toolbar.addtabs(toolbar.tabxmargin, toolbar.tabxsep, toolbar.tabwithclose, toolbar.tabmodified,
        toolbar.tabfont_sz, toolbar.tabfont_yoffset)

    --toolbar.tabfontcolor(NORMcol,HIcol,ACTIVEcol,MODIFcol,GRAYcol)
    toolbar.tabfontcolor( toolbar.tabcolor_normal, toolbar.tabcolor_hilight, toolbar.tabcolor_active,
        toolbar.tabcolor_modif, toolbar.tabcolor_grayed )
  end

  --put next buttons in a new row/column
  function toolbar.newrow(yoff)
    toolbar.gotopos(toolbar.newrowoff + (yoff or 0)) --new row
  end

  --create the toolbar (tabpos, nvertcols)
  --tabpos=0: 1 row, use default tabs
  --tabpos=1: 1 row, tabs & buttons in the same line
  --tabpos=2: 2 rows, tabs at the top (horizonal only)
  --tabpos=3: 2 rows, tabs at the bottom (horizonal only)
  --nvertcols= 0..2 = number of columns in vertical toolbar
  function toolbar.create(tabpos, nvertcols)
    toolbar.tabpos= tabpos
    ui.tabs= (tabpos == 0)  --hide regular tabbar if needed

    --tabs to show
    if not nvertcols then nvertcols= 0 end
    toolbar.tb1= (nvertcols > 0)    --vertical
    toolbar.tb0= ((tabpos > 0) or (nvertcols==0)) --horizontal

    local bsz0= toolbar.barsize
    if tabpos >= 2 then
      bsz0= bsz0*2 +1 --two rows
      toolbar.tabxmargin=0
    end
    local bsz1= toolbar.barsize
    if nvertcols > 1 then
      bsz1= bsz1*2 +1 --two rows
    end

    --create toolbar: barsize,buttonsize,imgsize,[numtoolbar/isvertical],[imgpath]
    if toolbar.tb0 then   --create the horizontal toolbar
      toolbar.new(bsz0, toolbar.butsize, toolbar.imgsize, 0, toolbar.themepath)
      if toolbar.adj then
        --bwidth,bheight,xmargin,ymargin,xoff,yoff
        toolbar.adjust(toolbar.adj_bw, toolbar.adj_bh, toolbar.adj_xm, toolbar.adj_ym,
          toolbar.adj_xoff, toolbar.adj_yoff)
      end
      --add/change some images
      for i, img in ipairs(toolbar.img) do
        if img ~= "" then toolbar.seticon("TOOLBAR", img, i) end
      end
      if tabpos == 1 then
        toolbar.seticon("TOOLBAR", toolbar.back[1], 0, true)  --horizontal back x 1row
      elseif tabpos > 1 then
        toolbar.seticon("TOOLBAR", toolbar.back[2], 0, true)  --horizontal back x 2rows
      end
      if tabpos == 2 then
        --2 rows, tabs at the top
        toolbar.add_tabs_here()
        toolbar.newrow(1)
      end
    else
      --hide the horizontal toolbar
      toolbar.seltoolbar(0)
      toolbar.show(false)
    end

    --create toolbar: barsize,buttonsize,imgsize,[numtoolbar/isvertical],[imgpath]
    if toolbar.tb1 then   --create the vertical toolbar
      toolbar.new(bsz1, toolbar.butsize, toolbar.imgsize, 1, toolbar.themepath)
      if toolbar.adj then
        --bwidth,bheight,xmargin,ymargin,xoff,yoff
        toolbar.adjust(toolbar.adj_bw, toolbar.adj_bh, toolbar.adj_xm, toolbar.adj_ym,
          toolbar.adj_xoff, toolbar.adj_yoff)
      end
      --add/change some images
      for i, img in ipairs(toolbar.img) do
        if img ~= "" then toolbar.seticon("TOOLBAR", img, i) end
      end
      if nvertcols < 2 then
        toolbar.seticon("TOOLBAR", toolbar.back[3], 0, true)  --vertical back x 1col
      else
        toolbar.seticon("TOOLBAR", toolbar.back[4], 0, true)  --vertical back x 2cols
      end
      --add buttons in the vertical toolbar
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

  --toolbar ready, show it
  function toolbar.ready()
    toolbar.seltoolbar(0)
    if toolbar.tabpos == 1 then
      --1 row, tabs in the same line
      toolbar.add_tabs_here()
    elseif toolbar.tabpos == 3 then
      --2 rows, tabs at the bottom
      toolbar.newrow(1)
      toolbar.add_tabs_here()
    end
    toolbar.show(toolbar.tb0)  --show the horizontal toolbar
    if toolbar.tabpos > 0 then
      toolbar.update_all_tabs()   --load existing buffers in tab-bar
      toolbar.seltab(_BUFFERS[buffer])  --select current buffer
    end
  end

  toolbar.set_defaults()
end
