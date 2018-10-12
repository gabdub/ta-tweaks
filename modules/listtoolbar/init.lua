-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

if toolbar then
  toolbar.listtb_hide_p= false

  local function list_clear()
    --remove all items
    toolbar.tag_count= 0
    toolbar.tag_listedfile= ""
    toolbar.sel_left_bar()
    toolbar.new(toolbar.listwidth, toolbar.cfg.butsize, toolbar.cfg.imgsize, 1, toolbar.themepath)
    --buttons group: fixed width=300 / align top + height=use buttons + vertical scroll
    toolbar.addgroup(0, 27, toolbar.listwidth, 0)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    --add/change some images
    toolbar.seticon("TOOLBAR", "ttb-cback", 0, true) --background
    toolbar.seticon("TOOLBAR", "ttb-csep", 1, true) --separator
    toolbar.listtb_y= 3
    toolbar.listright= toolbar.listwidth
  end

  function toolbar.createlisttb()
    list_clear()
    if actions then
      toolbar.idviewlisttb= actions.add("toggle_viewlisttb", 'Show LIST Tool_Bar', toolbar.list_toolbar_onoff, "sf10", nil, function()
        return (toolbar.list_tb and 1 or 2) end) --check
      local med= actions.getmenu_fromtitle(_L['_View'])
      if med then
        local m=med[#med]
        m[#m+1]= "toggle_viewlisttb"
      end
    end
    toolbar.list_tb= false --hide for now...
    toolbar.show(false)

    toolbar.sel_top_bar()
  end

  local function list_addbutton(name, tooltip, funct)
    toolbar.listright= toolbar.listright - toolbar.cfg.butsize
    toolbar.gotopos( toolbar.listright, toolbar.listtb_y)
    toolbar.cmd(name, funct, tooltip or "", name, true)
  end

  local function list_addinfo(text,bold)
    --add a text to the list
    toolbar.gotopos( 3, toolbar.listtb_y)
    toolbar.addlabel(text, "", toolbar.listright, true, bold)
    toolbar.listtb_y= toolbar.listtb_y + toolbar.cfg.barsize
    toolbar.listright= toolbar.listwidth
  end

  local function gototag(cmd)
    Proj.getout_projview()
    local linenum= tonumber(string.match(cmd,".-#(.*)"))
    Util.goto_line(buffer, linenum-1)
  end

  local function list_addtag(name,line)
    --add an item to the list
    local gt= "gotag#"..line
    toolbar.gotopos( 3, toolbar.listtb_y)
    toolbar.addtext(gt, name, "") --, toolbar.listwidth-2)
    toolbar.cmds_n[gt]= gototag
    toolbar.tag_count=toolbar.tag_count+1
    toolbar.listtb_y= toolbar.listtb_y + toolbar.cfg.barsize
  end

  local function list_addseparator()
    toolbar.gotopos( 3, toolbar.listtb_y)
    toolbar.addspace()
    toolbar.listtb_y= toolbar.listtb_y + 14
  end

  local function load_ctags()
    --ignore project views
    if Proj and (buffer._project_select or buffer._type == Proj.PRJT_SEARCH) then return end
    list_clear()
    local bname= buffer.filename
    if bname == nil then return end
    if Proj == nil then
      list_addinfo('No project module found')
      return
    end
    local p_buffer = Proj.get_projectbuffer(true)
    if p_buffer == nil then
      list_addinfo('No project found')
      return
    end
    local tag_files = {}
    if p_buffer.proj_files ~= nil then
      for row= 1, #p_buffer.proj_files do
        local ftype= p_buffer.proj_filestype[row]
        if ftype == Proj.PRJF_CTAG then
          tag_files[ #tag_files+1 ]= p_buffer.proj_files[row]
        end
      end
    end
    if #tag_files < 1 then
      list_addinfo('No CTAGS files found in project')
      return
    end
    toolbar.tag_listedfile= bname
    local fname= bname:match('[^/\\]+$') -- filename only
    list_addbutton("window-close", "Close list [Shift+F10]", toolbar.list_toolbar_onoff)
    list_addbutton("view-refresh", "Reload list", toolbar.list_toolbar_reload)
    list_addinfo(fname, true)
    list_addseparator()
    for i = 1, #tag_files do
      local dir = tag_files[i]:match('^.+[/\\]')
      local f = io.open(tag_files[i])
      for line in f:lines() do
        local tag, file, linenum, ext_fields = line:match('^([_.%w]-)\t(.-)\t(.-);"\t?(.*)$')
        if tag and (file == bname) then --only show current file
          local extra
          if ext_fields:find('.-\t.+') then ext_fields,extra=ext_fields:match('(.-)\t(.+)') end
          if ext_fields == "f" then tag= tag.." ( )"
          elseif ext_fields == "d" then tag= "# "..tag
          elseif ext_fields == "s" then tag= "struct "..tag
          elseif ext_fields == "m" and extra then tag= extra.."."..tag end
          if not file:find('^%a?:?[/\\]') then file = dir..file end
          if linenum:find('^/') then linenum = linenum:match('^/^(.+)$/$') end
          if linenum then list_addtag(tag, linenum) end
        end
      end
      f:close()
    end
    if toolbar.tag_count == 0 then list_addinfo('No CTAGS found in this file') end
  end

  function toolbar.list_toolbar_update()
    if toolbar.list_tb then load_ctags() end
  end

  function toolbar.list_toolbar_reload()
    if toolbar.list_tb then
      local cmd
      --locate project RUN command that updates TAGS (ctags)
      if Proj then
        local p_buffer = Proj.get_projectbuffer(false)
        if p_buffer and p_buffer.proj_filestype then
          for r=1, #p_buffer.proj_filestype do
            if p_buffer.proj_filestype[r] == Proj.PRJF_RUN then
              if p_buffer.proj_files[r]:match('ctags') then
                cmd= p_buffer.proj_files[r]
                break
              end
            end
          end
        end
      end
      if cmd then Proj.run_command(cmd) else load_ctags() end
    end
  end

  function toolbar.list_toolbar_onoff()
    --if the current view is a project view, goto left/only files view. if not, keep the current view
    if toolbar.list_tb == true then
      toolbar.list_tb= false
    else
      toolbar.list_tb= true
    end
    if Proj then
      Proj.getout_projview()
      local washidebylist= toolbar.listtb_hide_p
      toolbar.listtb_hide_p= false
      if toolbar.get_check_val("tblist_hideprj") then
        if Proj.isin_editmode() then Proj.show_hide_projview() end --end edit mode
        if (Proj.is_visible > 0) and toolbar.list_tb then
          toolbar.listtb_hide_p= true
          Proj.show_hide_projview()
        elseif washidebylist and (Proj.is_visible == 0) and (not toolbar.list_tb) then
          Proj.show_hide_projview()
        end
      end
    end
    toolbar.sel_left_bar()
    toolbar.list_toolbar_update()
    toolbar.show(toolbar.list_tb)
    --check menuitem
    if toolbar.idviewlisttb then actions.setmenustatus(toolbar.idviewlisttb, (toolbar.list_tb and 1 or 2)) end
    if toolbar then toolbar.setcfg_from_buff_checks() end --update config panel
    if actions then actions.updateaction("toggle_viewlisttb") end
  end
  events.connect(events.BUFFER_AFTER_SWITCH,  toolbar.list_toolbar_update)
  events.connect(events.VIEW_AFTER_SWITCH,    toolbar.list_toolbar_update)
  events.connect(events.BUFFER_NEW,           toolbar.list_toolbar_update)
end
