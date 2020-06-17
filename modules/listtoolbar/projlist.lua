-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
--
-- This module implements the selection of project files using the "lists" toolbar
--
-- ** This module is used when USE_LISTS_PANEL is true **
--
if toolbar then
  local itemsgrp, itselected, currproj, projmod, first_row
  local prj_parse_ver= -1
  local collarow= {}
  local openfs= {}
  local Proj = Proj
  local data= Proj.data

  --right-click context menu
  local proj_context_menu = {
    {"open_projlistfile",
     "open_projectdir",SEPARATOR,
     "toggle_editproj","copyfilename",SEPARATOR,
     "adddirfiles_proj",SEPARATOR,
     --"show_documentation",
     "search_project",
     "search_projlist_dir","search_projlist_file"
    }
  }

  local function clear_selected()
    if itselected then
      toolbar.selected(itselected,false,false)
      itselected= nil
    end
  end

  local function sel_file(cmd) --click= select
    local rmexp= string.match(cmd,"exp%-(.*)")
    if rmexp then cmd=rmexp end
    local linenum= toolbar.getnum_cmd(cmd)
    if linenum then
      clear_selected()
      itselected= cmd
      toolbar.selected(cmd,false,true)
      toolbar.ensurevisible(cmd)
    end
    return linenum
  end

  local function sel_file_num(linenum)
    if not linenum then linenum=first_row end
    if linenum > #data.proj_files then linenum=#data.proj_files end
    if linenum > 0 then sel_file("gofile#"..linenum) end
  end

  local function gofile_rclick(cmd) --right click
    if sel_file(cmd) then
      ui.toolbar_context_menu= create_uimenu_fromactions(proj_context_menu)
      return true --open context menu
    end
  end

  local function gofile_dclick(cmd) --double click
    local linenum= sel_file(cmd)
    if linenum then
      local fn= data.proj_files[linenum]
      local ft= data.proj_filestype[linenum]
      if ft == Proj.PRJF_FILE or ft == Proj.PRJF_CTAG then
        Proj.go_file(fn)
      elseif ft == Proj.PRJF_RUN then
        Proj.run_command(fn)
      else
        local name= "exp-"..cmd
        local r= collarow[name]
        if r ~= nil then if r then expand_list(name) else collapse_list(name) end end
      end
    end
  end

  --ACTION: open selected file
  local function act_open_prjselfile()
    gofile_dclick(itselected)
  end

  local function search_prjlist(where)
    if Proj.ask_search_in_files then --goto_nearest module?
      local linenum= sel_file(itselected)
      if linenum then
        local find, case, word= Proj.ask_search_in_files(true)
        if find then Proj.find_in_files(linenum, find, case, word, true, where) end
      end
    else
      ui.statusbar_text= 'goto_nearest module not found'
    end
  end
    --ACTION: search in files from the selected folder
  local function act_search_in_sel_dir()
    search_prjlist(1)
  end
  --ACTION: search the selected file
  local function act_search_in_sel_file()
    search_prjlist(2)
  end
  actions.add("open_projlistfile",    'Open', act_open_prjselfile)
  actions.add("search_projlist_dir",  'Search in selected dir',  act_search_in_sel_dir)
  actions.add("search_projlist_file", 'Search in selected file', act_search_in_sel_file)

  local function list_clear()
    --remove all items
    toolbar.listright= toolbar.listwidth-3
    toolbar.sel_left_bar(itemsgrp,true) --empty items group
    collarow= {}
  end

  function expand_list(cmd)
    sel_file(cmd)
    toolbar.set_expand_icon(cmd,"list-colapse2")
    toolbar.cmds_n[cmd]= collapse_list
    toolbar.collapse(cmd, false)
    collarow[cmd]= false
  end

  function collapse_list(cmd)
    sel_file(cmd)
    toolbar.set_expand_icon(cmd,"list-expand2")
    toolbar.cmds_n[cmd]= expand_list
    toolbar.collapse(cmd, true)
    collarow[cmd]= true
  end

  function toolbar.load_proj_list()
    local rowcol= toolbar.cfg.backcolor_erow
    toolbar.list_init_title() --add a resize handle
    toolbar.list_addaction("close_project")
    if (not Proj) then
      toolbar.list_addinfo('The Project module is not installed')
      return
    end
    if not data.is_open then
      toolbar.list_addinfo('No open project', true)
      list_clear()
      return
    end
    if #data.proj_files < 1 then
      toolbar.list_addinfo('The project is empty', true)
      list_clear()
      return
    end

    first_row= 1
    local fname= data.proj_rowinfo[first_row][1]
    if fname == "" then fname= 'Project' else first_row=2 end
    toolbar.list_addinfo(fname, true)

    --Has the content of the project changed?
    if prj_parse_ver == data.parse_ver then return end
    --yes: update file list
    prj_parse_ver= data.parse_ver

    local linenum= toolbar.getnum_cmd(itselected)
    list_clear()

    toolbar.sel_left_bar(itemsgrp)
    toolbar.listtb_y= 3
    if first_row <= #data.proj_files then
      for i= first_row, #data.proj_files do
        local fname= data.proj_rowinfo[i][1]
        if fname == "" then
          toolbar.list_add_separator()
        else
          local idlen= data.proj_rowinfo[i][3] --indent-len
          local ind= (data.proj_rowinfo[i][2] or 0) * 12 --indentation
          local bicon= nil
          local tip= data.proj_files[i]
          local ft= data.proj_filestype[i]
          if ft == Proj.PRJF_FILE then
            bicon= toolbar.icon_fname(data.proj_files[i])
          elseif ft == Proj.PRJF_CTAG then
            bicon= "t_type"
            tip= "CTAG: "..tip
          elseif ft == Proj.PRJF_RUN then
            bicon= "lpi-bug"
            tip= "RUN: "..tip
          elseif ft == Proj.PRJF_VCS then
            bicon= "package-install"
            tip= Proj.get_vcs_info(i, "\n")
          end
          local name= "gofile#"..i
          if toolbar.list_add_txt_ico(name, fname, tip, (bicon==nil), sel_file, bicon, (i%2==1), ind, idlen, 2) then
            toolbar.list_add_collapse(name, collapse_list, ind, idlen, collarow)
          end
        end
      end
      --set project's default collapse items
      for i= #data.proj_fold_row, 1, -1 do
        collapse_list("exp-gofile#"..data.proj_fold_row[i] )
      end
      sel_file_num(linenum)
    end
  end

  local function track_file() --select the current buffer in the list
    if Proj.isRegularBuf(buffer) then
      --normal file: restore current line default settings
      local file= buffer.filename
      if file ~= nil then
        local row= Proj.get_file_row(file)
        if row then sel_file_num(row) end
      end
    end
  end

  local function mark_open_files()
    for k,v in pairs(openfs) do openfs[k]= false end
    for _, b in ipairs(_BUFFERS) do
      if b._project_select == nil and b._type == nil then
        local file= b.filename
        if file then
          local row= Proj.get_file_row(file)
          if row then
            local name= "open-gofile#"..row
            if not openfs[name] then toolbar.setthemeicon(name,"open-back") end
            openfs[name]= true
          end
        end
      end
    end
    for k,v in pairs(openfs) do
      if not v then
        toolbar.setthemeicon(k,"closed-back")
        openfs[k]= nil
      end
    end
  end

  local function proj_create_cb()
    --LSTSEL_CREATE_CB: create callback
    --items group: fixed width=300 / height=use buttons + vertical scroll
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)

    list_clear()
    toolbar.cmd_rclick("gofile",gofile_rclick)
    toolbar.cmd_dclick("gofile",gofile_dclick)
  end

  local function proj_update_cb(reload)
    --LSTSEL_UPDATE_CB: update callback (parameter: reload == FALSE for VIEW/BUFFER_AFTER_SWITCH)
    if reload then toolbar.load_proj_list() end
    track_file()
    mark_open_files()
  end

  local function proj_showlist_cb(show)
    --LSTSEL_SHOW_CB: the list has been shown/hidden (parameter: show)
    toolbar.sel_left_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  toolbar.registerlisttb("projlist", "Project", "document-properties", proj_create_cb, proj_update_cb, proj_showlist_cb)

  --------------- LISTS INTERFACE --------------
  function plugs.init_projectview()
    --check if a project was saved
    if toolbar.open_saved_prj ~= "" then Proj.open_project(toolbar.open_saved_prj) end
  end

  function plugs.check_lost_focus(buff)
  end

  function plugs.goto_projectview()
    return false --activate/create project view (not used with panels)
  end

  function plugs.projmode_select()
    --activate select mode
    if data.is_open then
      --locate and close the project buffer
      local fn = data.filename:iconv(_CHARSET, 'UTF-8')
      for _, buff in ipairs(_BUFFERS) do
        if buff.filename == fn then
          Util.goto_buffer(buff)
          Util.close_buffer()
          break
        end
      end
    end
  end

  function plugs.projmode_edit()
    --activate edit mode
    if data.is_open then Proj.go_file(data.filename) end --open the project in a buffer to edit it
  end

  function plugs.update_after_switch()
    Proj.show_default(buffer) --set current line default settings
    if buffer._type == Proj.PRJT_SEARCH then
      Proj.set_contextm_search()  --set search context menu
    else
      Proj.set_contextm_file() --set regular file context menu
      plugs.track_this_file() --try to select the current file in the project
    end
    if toolbar then
      buffer.v_scroll_bar= not toolbar.tbreplvscroll --minimap replace V scrollbar
    else
      buffer.v_scroll_bar= true
    end
  end

  function plugs.change_proj_ed_mode()
    --toggle project between selection and EDIT modes
    Proj.toggle_selectionmode()
  end

  function plugs.track_this_file()
  end

  function plugs.proj_refresh_hilight()
  end

  function plugs.open_project()
    --open the project file
    Proj.add_recentproject()  --add the project to the recent list
    Proj.selection_mode()     --parse the project and put it in SELECTION mode
    Proj.goto_filesview(Proj.FILEPANEL_LEFT)
    return true
  end

  function plugs.close_project(keepviews)
    Proj.closed_cleardata()
    if toolbar and toolbar.list_show_projects then toolbar.list_show_projects() end
    return true
  end

  function plugs.get_prj_currow()
    return sel_file(itselected)  --get the selected project row number
  end

  function plugs.open_sel_file() --not used
  end

  function plugs.buffer_deleted()
    --if the poject buffer was closed, return to selection mode
    if data.show_mode == Proj.SM_EDIT then
      --locate and close the project buffer
      local fn = data.filename:iconv(_CHARSET, 'UTF-8')
      for _, buff in ipairs(_BUFFERS) do
        if buff.filename == fn then
          return --still open, ignore
        end
      end
      --project buffer not found, return to selection mode
      data.show_mode= Proj.SM_SELECT
      Proj.update_projview_action() --update action: toggle_viewproj/toggle_editproj
    end
  end

  function plugs.update_proj_buffer(reload)
  end

end
