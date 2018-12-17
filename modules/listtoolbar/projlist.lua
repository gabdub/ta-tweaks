-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

if toolbar then
  local titgrp, itemsgrp, itselected

  local function clear_selected()
    if itselected then
      toolbar.selected(itselected,false,false)
      itselected= nil
    end
  end

  local function sel_file(cmd) --click= select
    local linenum= toolbar.getnum_cmd(cmd)
    if linenum then
      clear_selected()
      itselected= cmd
      toolbar.selected(cmd,false,true)
      toolbar.ensurevisible(cmd,true)
    end
    return linenum
  end

  local function sel_file_num(linenum)
    local p_buffer = Proj.get_projectbuffer(true)
    if p_buffer == nil or p_buffer.proj_files == nil then return end
    if not linenum then linenum=1 end
    if linenum > #p_buffer.proj_files then linenum=#p_buffer.proj_files end
    if linenum > 0 then sel_file("gofile#"..linenum) end
  end

  local function gofile_rclick(cmd) --right click
    if sel_file(cmd) then
--      ui.context_menu= create_uimenu_fromactions(recentproj_context_menu)
--      return true --open context menu
    end
  end

  local function gofile_dclick(cmd) --double click
    local p_buffer = Proj.get_projectbuffer(true)
    if p_buffer == nil or p_buffer.proj_files == nil then return end
    local linenum= sel_file(cmd)
    if linenum then
      local cmd=p_buffer.proj_files[linenum]
      local ft= p_buffer.proj_filestype[linenum]
      if ft == Proj.PRJF_RUN then
        Proj.run_command(cmd)
      else
        Proj.go_file(cmd)
      end
    end
  end

  local function list_clear()
    --remove all items
    toolbar.listright= toolbar.listwidth-3
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
    toolbar.sel_left_bar(titgrp,true) --empty title group
  end

  local function load_proj()
    local linenum= toolbar.getnum_cmd(itselected)
    list_clear()
    toolbar.listtb_y= 1
    --toolbar.list_addaction("open_project")
    --toolbar.list_addaction("new_project")
    if (not Proj) then
      toolbar.list_addinfo('Project module not installed', true)
      return
    end
    local p_buffer = Proj.get_projectbuffer(true)
    if p_buffer == nil or p_buffer.proj_files == nil then
      toolbar.list_addinfo('No project found', true)
      return
    end
    toolbar.list_addinfo('Project', true)

    toolbar.sel_left_bar(itemsgrp)
    if #p_buffer.proj_files < 1 then
      toolbar.listtb_y= 3
      toolbar.list_addinfo('The project is empty')
    else
      local y= 3
      for i=1, #p_buffer.proj_files do
        local fname= Util.getfilename(p_buffer.proj_files[i],true)
        if fname ~= "" then
          local name= "gofile#"..i
          toolbar.gotopos( 3, y)
          local isopen= false   --TODO: bold opened files
          toolbar.addtext(name, fname, p_buffer.proj_files[i], toolbar.listwidth-13, false, true, isopen, toolbar.cfg.barsize, 0)
          toolbar.gotopos( 3, y)
          local bicon= "document-export"
          local ft= p_buffer.proj_filestype[i]
          if ft == Proj.PRJF_CTAG then
            bicon= "t_type"
          elseif ft == Proj.PRJF_RUN then
            bicon= "lpi-bug"
          end
          toolbar.cmd("ico-"..name, sel_file, "", bicon, true)
          toolbar.cmds_n[name]= sel_file
          y= y + toolbar.cfg.butsize
        end
      end
      sel_file_num(linenum)
    end
  end

  local function proj_create()
    --title group: fixed width=300 / align top + fixed height
    titgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 0, 0, toolbar.cfg.barsize, true)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
    toolbar.themed_icon(toolbar.groupicon, "cfg-back2", toolbar.TTBI_TB.BACKGROUND)
    --items group: fixed width=300 / height=use buttons + vertical scroll
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)

    list_clear()
    toolbar.cmd_rclick("gofile",gofile_rclick)
    toolbar.cmd_dclick("gofile",gofile_dclick)
  end

  local function proj_notify(switching)
    if not switching then load_proj() end
  end

  local function proj_showlist(show)
    --show/hide list items
    toolbar.sel_left_bar(titgrp)
    toolbar.showgroup(show)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  toolbar.registerlisttb("projlist", "Project", "document-properties", proj_create, proj_notify, proj_showlist)
end

