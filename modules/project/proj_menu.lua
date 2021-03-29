-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
local _L = _L
local SEPARATOR = ""
local Proj = Proj
local Util = Util

--------------------------------------------------------------
-- Control+W=         close buffer
-- Control+Shift+W=   close all buffers
-- Control+H=         show project current row properties
-- Control+O =        open file
-- Alt+O =            open file using the selected text or the text under the cursor
--                    or change buffer extension {c,cpp} <--> {h,hpp} or ask
-- Control+Alt+O =    open recent file
-- Control+N=         new buffer
-- Control+Shift+O =  project snap open
-- Control+Shift+Alt+O = open current directory
-- Control+U =        quick open user folder
-- F4 =               toggle project between selection and EDIT modes
-- SHIFT+F4 =         toggle project visibility
-- F5 =               refresh syntax highlighting + project folding
-- Control+B=         switch buffer
-- Control+PgUp=      previous buffer
-- Control+PgDn=      next buffer
--------------------------------------------------------------
if actions then
  --use the project friendly version of some actions
  local ls=actions.list
  ls["new"][2]=                 Proj.new_file
  ls["open"][2]=                Proj.open_file
  ls["recent"][2]=              Proj.open_recent_file
  ls["close"][2]=               Proj.close_buffer
  ls["closeall"][2]=            Proj.onlykeep_projopen --Proj.close_all_buffers
  ls["open_userhome"][2]=       Proj.qopen_user
  ls["open_textadepthome"][2]=  Proj.qopen_home
  ls["open_currentdir"][2]=     Proj.qopen_curdir
  ls["quick_open_projectdir"][2]= Proj.quick_open
  ls["show_documentation"][2]=  Proj.show_doc
  ls["next_buffer"][2]=         Proj.next_buffer
  ls["prev_buffer"][2]=         Proj.prev_buffer
  ls["switch_buffer"][2]=       Proj.switch_buffer
--ls["refresh_syntax"][2]=      Proj.refresh_hilight

  actions.free_accelerator({ Util.KEY_CTRL.."pgup", Util.KEY_CTRL.."pgdn", Util.KEY_CTRL.."O", Util.KEY_CTRL..Util.KEY_ALT.."P"})
  actions.accelerators["prev_buffer"]= Util.KEY_CTRL.."pgup"
  actions.accelerators["next_buffer"]= Util.KEY_CTRL.."pgdn"
  actions.accelerators["quick_open_projectdir"]= Util.KEY_CTRL.."O"
  actions.accelerators["open_textadepthome"]= Util.KEY_CTRL..Util.KEY_ALT.."P"

  --"toggle_viewproj" = '_Hide/show project'
  local function tpv_status()
    return Proj.data.is_open and (Proj.data.show_mode == Proj.SM_HIDDEN and 2 or 1) or 10 --1=checked 2=unchecked 8=disabled
  end
  local function tpv_icon()
    if Proj.data.is_open then
      if Proj.data.show_mode == Proj.SM_HIDDEN then return "ttb-proj-c" end --hidden
      if Proj.data.show_mode == Proj.SM_EDIT   then return "ttb-proj-e" end --edit mode
    end
    return "ttb-proj-o"  --selection mode (or disabled)
  end
  local function tpv_text()
    if Proj.data.is_open then
      if Proj.data.show_mode == Proj.SM_HIDDEN then return "Show project"  end --hidden
      if Proj.data.show_mode == Proj.SM_EDIT   then return "End edit mode" end --edit mode
      return "Hide project"  --selection mode
    end
    return "No project is open"  --disabled
  end

  local function edp_status()
    return Proj.data.is_open and (Proj.data.show_mode == Proj.SM_EDIT and 1 or 2) or 10 --1=checked 2=unchecked 8=disabled
  end

  local function closeprj_status()
    return Proj.data.is_open and 0 or 8 --0=normal 8=disabled
  end

  --add new PROJECT actions
  actions.add("trim_trailingspaces", 'Trim trailing spaces',  Proj.trim_trailing_spaces, nil, "dialog-ok")
  actions.add("remove_tabs",         'Convert all tabs into spaces', Proj.remove_tabs)

  actions.add("new_project",         _L['New'],              Proj.new_project, nil, "list-add", nil, "New Project")
  actions.add("open_project",        _L['Open'],             Proj.open_project, nil, "document-open", nil, "Open Project")
  actions.add("recent_project",      _L['Open Recent...'],   Proj.open_recent_project)
  actions.add("close_project",       _L['Close'],            Proj.close_project, nil, "system-log-out", closeprj_status, "Close project")
  actions.add("search_project",      'Project _Search',       Proj.search_in_files, Util.KEY_ALT.."F")
  actions.add("search_sel_dir",      'Search in selected dir', Proj.search_in_sel_dir)
  actions.add("search_sel_file",     'Search in selected file', Proj.search_in_sel_file)
  actions.add("close_others",        'Close Others',          Proj.close_others)
  actions.add("dont_close",          "Mark as don't close",   Proj.toggle_keep_thisbuffer, nil, nil, Proj.keepthisbuff_status) --check
  actions.add("showin_rightpanel",   "Show file in the right panel", Proj.toggle_showin_rightpanel, nil, nil, Proj.showin_rightpanel_status) --check
  actions.add("open_projsel",        _L['Open'] .. ' file  [Return]', Proj.open_sel_file)

  actions.add("toggle_editproj",     Util.EDITMENU_TEXT .. ' project', Proj.toggle_editproj, "f4", "ttb-proj-e", edp_status)
  --"_end_editproj" = "toggle_editproj" with different text menu
  actions.add("_end_editproj",       '_End edit',             Proj.toggle_editproj)
  actions.accelerators["_end_editproj"]="f4" --(alias)

  actions.add("toggle_viewproj",   'Sho_w project',         Proj.toggle_projview, Util.KEY_SHIFT.."f4", tpv_icon, tpv_status, tpv_text)
  actions.add("addcurrentfile_proj", '_Add current file',     Proj.add_current_file)
  actions.add("addallfiles_proj",    'Add all open _Files',   Proj.add_all_files)
  actions.add("adddirfiles_proj",    'Add files from _Dir',   Proj.add_dir_files)

  actions.add("open_selfile",        '_Open the selected/companion file',Proj.open_selfile, Util.KEY_ALT.."o" )
  actions.add("first_buffer",        'First buffer',          Proj.first_buffer, Util.KEY_ALT.."pgup")
  actions.add("last_buffer",         'Last buffer',           Proj.last_buffer,  Util.KEY_ALT.."pgdn")
  actions.add("clear_search",        'Clear search results',  Proj.clear_search, Util.KEY_ALT.."f10")

  --add actions defined in "proj_ctags"
  actions.add("goto_tag",            'Goto _Tag',             Proj.goto_tag,          "f11" )
  actions.add("save_position",       'S_ave position',        Proj.store_current_pos, Util.KEY_CTRL.."f11")
  actions.add("prev_position",       '_Prev position',        Proj.goto_prev_pos,     Util.KEY_SHIFT.."f11", "go-previous", Proj.goprev_status)
  actions.add("next_position",       'Ne_xt position',        Proj.goto_next_pos,     Util.KEY_SHIFT.."f12", "go-next", Proj.gonext_status)
  actions.add("clear_position",      'C_lear positions',      Proj.clear_pos_table,   Util.KEY_CTRL.."f12")

  --add actions defined in "proj_diff"
  actions.add("toggle_filediff", "Compare panels", Proj.diff_start, "f8", "edit-copy", Proj.compare_status)

  actions.add("vc_changes", "VC: compare to HEAD", Proj.vc_changes, Util.KEY_CTRL.."f5", "document-properties", Proj.vc_changes_status)

  actions.add("show_filevcinfo", "VC: show file info", Proj.show_filevcinfo, Util.KEY_SHIFT.."f5")

  actions.add("vc_controlpanel", "VC: control panel", Proj.reopen_vcs_control_panel, Util.KEY_ALT.."f5", "document-open", Proj.vc_controlpanel_status)

  --add PROJECT menu (before Help)
  table.insert( actions.menubar, #actions.menubar,
    {title = Util.PROJECTMENU_TEXT,
     {"new_project","open_project","recent_project","close_project","toggle_editproj",SEPARATOR,
      "search_project","goto_tag","toggle_filediff","vc_changes","show_filevcinfo","vc_controlpanel",SEPARATOR,
      "save_position","next_position","prev_position","clear_position",SEPARATOR,
      "addcurrentfile_proj","addallfiles_proj","adddirfiles_proj"}
    })

  --add TRIM_TRAILINGSPACES / REMOVE_TABS at the end of the EDIT menu
  local m_ed= actions.getmenu_fromtitle(Util.EDITMENU_TEXT)
  if m_ed then m_ed[#m_ed+1]= {SEPARATOR,"trim_trailingspaces", "remove_tabs"} end

  --add OPEN_SELFILE at the end of the QUICK-OPEN submenu
  local m_qo= actions.getmenu_fromtitle(_L['Quick _Open'])
  if m_qo then m_qo[#m_qo+1]= {SEPARATOR,"open_selfile"} end

  --add FIRST/LAST BUFFER at the top of the BUFFER menu
  local med= actions.getmenu_fromtitle(Util.BUFFERMENU_TEXT)
  if med then
    local m1=med[1]
    table.insert(m1, 1, "first_buffer")
    table.insert(m1, 2, "last_buffer")
  end

  --add VIEWPROJECT at the end of the VIEW menu
  local m_vi= actions.getmenu_fromtitle(Util.VIEWMENU_TEXT)
  if m_vi then
    m_vi[#m_vi+1]= {SEPARATOR}
    if not USE_LISTS_PANEL then m_vi[#m_vi+1]= {"toggle_viewproj"} end --only for project in BUFFER mode
  end

  ----------------- CONTEXT MENUS -------------------
  --replace tab context menu
  actions.tab_context_menu = {
    {"close","close_others","dont_close","closeall",SEPARATOR,
     "save","saveas",SEPARATOR,
     "showin_rightpanel",SEPARATOR,
     "reload","copyfilename"}
  }

  --right-click context menus
  local proj_context_menu
  if USE_LISTS_PANEL then   --project in PANEL
    proj_context_menu = {
      { --#1 project in SELECTION mode (not used)
        {SEPARATOR}
      },
      { --#2 project in EDIT mode (not used)
        {SEPARATOR}
      },
      { --#3 regular file
        {"undo","redo",SEPARATOR,
         "cut","copy","paste","delete_char","copyfilename",SEPARATOR,
         "selectall"
        },
        {
          title = Util.PROJECTMENU_TEXT,
          {"addcurrentfile_proj","addallfiles_proj","adddirfiles_proj",SEPARATOR,
           "search_project","goto_tag","toggle_filediff","vc_changes","show_filevcinfo","vc_controlpanel",SEPARATOR,
           "save_position","next_position","prev_position"}
        },
        {SEPARATOR,"showin_rightpanel"}
      },
      { --#4 search view
        {"copy", "selectall", "clear_search"}
      }
    }
  else  --project in BUFFER
    proj_context_menu = {
      { --#1 project in SELECTION mode
        {"open_projsel","quick_open_projectdir",SEPARATOR,
           "toggle_editproj","toggle_viewproj","copyfilename",SEPARATOR,
           "adddirfiles_proj",SEPARATOR,
           "show_documentation", "search_project","search_sel_dir","search_sel_file"}
      },
      { --#2 project in EDIT mode
        {"undo","redo",SEPARATOR,
         "cut","copy","paste","delete_char","copyfilename",SEPARATOR,
         "selectall",SEPARATOR,
         "_end_editproj"}
      },
      { --#3 regular file
        {"undo","redo",SEPARATOR,
         "cut","copy","paste","delete_char","copyfilename",SEPARATOR,
         "selectall"
        },
        {
          title = Util.PROJECTMENU_TEXT,
          {"addcurrentfile_proj","addallfiles_proj","adddirfiles_proj",SEPARATOR,
           "search_project","goto_tag","toggle_filediff","vc_changes","show_filevcinfo","vc_controlpanel",SEPARATOR,
           "save_position","next_position","prev_position",SEPARATOR,
           "toggle_viewproj"}
        },
        {SEPARATOR,"showin_rightpanel"}
      },
      { --#4 search view
        {"copy", "selectall", "clear_search"}
      }
    }
  end

  --init desired project context menu
  local ctxmenus= {}
  --Proj.cmenu_num= number of the current context menu

  --CURSES or the menu is already set, don't change the context menu
  local function proj_context_menu_init(num)
    if CURSES or Proj.cmenu_num == num then return end
    Proj.cmenu_num= num
    if #ctxmenus == 0 then
      --first time here, create all the project context menus
      for i=1,#proj_context_menu do
        ctxmenus[i]= create_uimenu_fromactions(proj_context_menu[i])
      end
    end
    ui.context_menu = ctxmenus[num]
  end

  -- set project context menu in SELECTION mode --
  function Proj.set_contextm_sel() proj_context_menu_init(1) end
  -- set project context menu in EDIT mode --
  function Proj.set_contextm_edit() proj_context_menu_init(2) end
  -- set project context menu for a regular file --
  function Proj.set_contextm_file() proj_context_menu_init(3) end
  -- set project context menu for search view --
  function Proj.set_contextm_search() proj_context_menu_init(4) end
end
