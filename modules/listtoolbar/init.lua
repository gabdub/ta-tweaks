-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

if toolbar then
  local function list_clear()
    --remove all items
    toolbar.tag_count= 0
    toolbar.tag_listedfile= ""
    toolbar.sel_left_bar()
    toolbar.new(toolbar.listwidth, toolbar.cfg.butsize, toolbar.cfg.imgsize, 1, toolbar.themepath)
    --buttons group: fixed width=300 / align top + height=use buttons + vertical scroll
    toolbar.addgroup(0, 27, toolbar.listwidth, 0)
    --add/change some images
    toolbar.seticon("TOOLBAR", "ttb-cback", 0, true) --background
    toolbar.seticon("TOOLBAR", "ttb-csep", 1, true) --separator
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

  local function list_addinfo(text,bold)
    --add a text to the list
    toolbar.addlabel(text, "", toolbar.listwidth, true, bold)
  end

  local function gototag(cmd)
    local linenum= tonumber(string.match(cmd,".-#(.*)"))
    Util.goto_line(buffer, linenum-1)
  end

  local function list_addtag(name,line)
    --add an item to the list
    local gt= "gotag#"..line
    toolbar.addtext(gt, name, "") --, toolbar.listwidth-2)
    toolbar.cmds_n[gt]= gototag
    toolbar.tag_count=toolbar.tag_count+1
  end

  local function load_ctags()
    --ignore project views
    if (buffer._project_select or buffer._type == Proj.PRJT_SEARCH) then return end
    local bname= buffer.filename
    if bname == nil then return end
    list_clear()
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
    list_addinfo(bname:match('[^/\\]+$'), true) -- filename only
    toolbar.addspace()
    local patt = '^([_%a]+)\t(%S+)\t(.-);"\t?(.*)$'
    for i = 1, #tag_files do
      local dir = tag_files[i]:match('^.+[/\\]')
      local f = io.open(tag_files[i])
      for line in f:lines() do
        local tag, file, linenum, ext_fields = line:match(patt)
        if tag then
          if not file:find('^%a?:?[/\\]') then file = dir..file end
          if linenum:find('^/') then linenum = linenum:match('^/^(.+)$/$') end
          --only show current file
          if (file == bname) and linenum then list_addtag(tag, linenum) end
        end
      end
      f:close()
    end
    if toolbar.tag_count == 0 then list_addinfo('No CTAGS found in this file') end
  end

  function toolbar.list_toolbar_onoff()
    --if the current view is a project view, goto left/only files view. if not, keep the current view
    Proj.getout_projview()
    if toolbar.list_tb == true then
      toolbar.list_tb= false
    else
      toolbar.list_tb= true
    end
    toolbar.sel_left_bar()
    if toolbar.list_tb then load_ctags() end
    toolbar.show(toolbar.list_tb)
    --check menuitem
    if toolbar.idviewlisttb then actions.setmenustatus(toolbar.idviewlisttb, (toolbar.list_tb and 1 or 2)) end
    if toolbar then toolbar.setcfg_from_buff_checks() end --update config panel
    if actions then actions.updateaction("toggle_viewlisttb") end
  end

end
