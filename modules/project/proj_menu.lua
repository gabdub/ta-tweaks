-- Copyright 2016-2017 Gabriel Dubatti. See LICENSE.
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
  ls["open_projectdir"][2]=     Proj.snapopen
  ls["show_documentation"][2]=  Proj.show_doc
  ls["next_buffer"][2]=         Proj.next_buffer
  ls["prev_buffer"][2]=         Proj.prev_buffer
  ls["switch_buffer"][2]=       Proj.switch_buffer
  ls["refresh_syntax"][2]=      Proj.refresh_hilight

  actions.free_accelerator({"cpgup","cpgdn","cO","caP"})
  actions.accelerators["prev_buffer"]="cpgup"
  actions.accelerators["next_buffer"]="cpgdn"
  actions.accelerators["open_projectdir"]="cO"
  actions.accelerators["open_textadepthome"]="caP"

  --"toggle_viewproj" = '_Hide/show project'
  local function tpv_status()
    return (Proj.get_projectbuffer() and (Proj.is_visible == 0 and 2 or 1) or 10) --1=checked 2=unchecked 8=disabled
  end
  local function tpv_icon()
    local ena= Proj.get_projectbuffer()
    if ena then
      if Proj.is_visible == 0 then      --0:hidden
        return "ttb-proj-c"
      end
      if Proj.is_visible == 2 then      --2:shown in edit mode
        return "ttb-proj-e"
      end
    end
    return "ttb-proj-o"  --1:shown in selection mode (or disabled)
  end
  local function tpv_text()
    local ena= Proj.get_projectbuffer()
    if ena then
      if Proj.is_visible == 0 then      --0:hidden
        return "Show project"
      end
      if Proj.is_visible == 2 then      --2:shown in edit mode
        return "End edit mode"
      end
      return "Hide project"  --1:shown in selection mode
    end
    return "No project is open"  --disabled
  end

  --add new PROJECT actions
  actions.add("trim_trailingspaces", 'Trim trailing spaces',  Proj.trim_trailing_spaces, nil, "dialog-ok")
  actions.add("remove_tabs",         'Convert all tabs into spaces', Proj.remove_tabs)

  actions.add("new_project",         _L['_New'],              Proj.new_project)
  actions.add("open_project",        _L['_Open'],             Proj.open_project)
  actions.add("recent_project",      _L['Open _Recent...'],   Proj.open_recent_project)
  actions.add("close_project",       _L['_Close'],            Proj.close_project)
  actions.add("search_project",      'Project _Search',       Proj.search_in_files, "aF")
  actions.add("search_sel_dir",      'Search in selected dir', Proj.search_in_sel_dir)
  actions.add("search_sel_file",     'Search in selected file', Proj.search_in_sel_file)
  actions.add("close_others",        'Close Others',          Proj.close_others)
  actions.add("dont_close",          "Mark as don't close",   Proj.toggle_keep_thisbuffer, nil, nil, Proj.keepthisbuff_status) --check
  actions.add("showin_rightpanel",   "Show file in the right panel", Proj.toggle_showin_rightpanel, nil, nil, Proj.showin_rightpanel_status) --check
  --actions.add("onlykeepproj",      _L['Close All'],         Proj.onlykeep_projopen) --"closeall"="onlykeepproj"
  actions.add("open_projsel",        _L['_Open'] .. ' file  [Return]', Proj.open_sel_file)

  actions.add("toggle_editproj",     _L['_Edit'] .. ' project', Proj.toggle_editproj, "f4")
  --"_end_editproj" = "toggle_editproj" with different text menu
  actions.add("_end_editproj",       '_End edit',             Proj.toggle_editproj)
  actions.accelerators["_end_editproj"]="f4" --(alias)

  actions.add("toggle_viewproj",     'Sho_w project',         Proj.toggle_projview, "sf4", tpv_icon, tpv_status, tpv_text)
  actions.add("addthisfiles_proj",   '_Add this file',        Proj.add_this_file)
  actions.add("addallfiles_proj",    'Add all open _Files',   Proj.add_all_files)
  actions.add("adddirfiles_proj",    'Add files from _Dir',   Proj.add_dir_files)

  actions.add("open_selfile",        '_Open the selected/companion file',Proj.open_selfile,"ao" )
  actions.add("first_buffer",        'First buffer',          Proj.first_buffer, "apgup")
  actions.add("last_buffer",         'Last buffer',           Proj.last_buffer,  "apgdn")
  actions.add("clear_search",        'Clear search results',  Proj.clear_search)

  --add actions defined in "proj_ctags"
  actions.add("goto_tag",            'Goto _Tag',             Proj.goto_tag,          "f11" )
  actions.add("save_position",       'S_ave position',        Proj.store_current_pos, "cf11")
  actions.add("prev_position",       '_Prev position',        Proj.goto_prev_pos,     "sf11", "go-previous", Proj.goprev_status)
  actions.add("next_position",       'Ne_xt position',        Proj.goto_next_pos,     "sf12", "go-next", Proj.gonext_status)
  actions.add("clear_position",      'C_lear positions',      Proj.clear_pos_table,   "cf12")

  --add actions defined in "proj_diff"
  actions.add("toggle_filediff", "Start/stop file diff", Proj.diff_start, "f8", "edit-copy")

  actions.add("vc_changes", "SVN/GIT: compare to HEAD", Proj.vc_changes, "f6", "document-properties", Proj.vc_changes_status)

  actions.add("show_filevcinfo", "SVN/GIT: show file info", Proj.show_filevcinfo)

  --add PROJECT menu (before Help)
  table.insert( actions.menubar, #actions.menubar,
    {title='_Project',
     {"new_project","open_project","recent_project","close_project",SEPARATOR,
      "search_project","goto_tag","vc_changes","show_filevcinfo",SEPARATOR,
      "save_position","next_position","prev_position","clear_position",SEPARATOR,
      "addthisfiles_proj","addallfiles_proj","adddirfiles_proj"}
    })

  --add TRIM_TRAILINGSPACES / REMOVE_TABS at the end of the EDIT menu
  local m_ed= actions.getmenu_fromtitle(_L['_Edit'])
  if m_ed then m_ed[#m_ed+1]= {SEPARATOR,"trim_trailingspaces", "remove_tabs"} end

  --add OPEN_SELFILE at the end of the QUICK-OPEN submenu
  local m_qo= actions.getmenu_fromtitle(_L['Quick _Open'])
  if m_qo then m_qo[#m_qo+1]= {SEPARATOR,"open_selfile"} end

  --add FIRST/LAST BUFFER at the top of the BUFFER menu
  local med= actions.getmenu_fromtitle(_L['_Buffer'])
  if med then
    local m1=med[1]
    table.insert(m1, 1, "first_buffer")
    table.insert(m1, 2, "last_buffer")
  end

  --add VIEWPROJECT at the end of the VIEW menu
  local m_vi= actions.getmenu_fromtitle(_L['_View'])
  if m_vi then m_vi[#m_vi+1]= {SEPARATOR,"toggle_viewproj"} end

  ----------------- CONTEXT MENUS -------------------
  --replace tab context menu
  actions.tab_context_menu = {
    {"close","close_others","dont_close","closeall",SEPARATOR,
     "save","saveas",SEPARATOR,
     "showin_rightpanel",SEPARATOR,
     "reload"}
  }

  --right-click context menus
  local proj_context_menu = {
    { --#1 project in SELECTION mode
      {"open_projsel","open_projectdir",SEPARATOR,
         "toggle_editproj","toggle_viewproj",SEPARATOR,
         "adddirfiles_proj",SEPARATOR,
         "show_documentation", "search_project","search_sel_dir","search_sel_file"}
    },
    { --#2 project in EDIT mode
      {"undo","redo",SEPARATOR,
       "cut","copy","paste","paste_special","delete_char",SEPARATOR,
       "selectall",SEPARATOR,
       "_end_editproj"}
    },
    { --#3 regular file
      {"undo","redo",SEPARATOR,
       "cut","copy","paste","paste_special","delete_char",SEPARATOR,
       "selectall"
      },
      {
        title = '_Project',
        {"addthisfiles_proj","addallfiles_proj","adddirfiles_proj",SEPARATOR,
         "search_project","goto_tag","vc_changes","show_filevcinfo",SEPARATOR,
         "save_position","next_position","prev_position",SEPARATOR,
         "toggle_viewproj"}
      },
      {SEPARATOR,"showin_rightpanel"}
    },
    { --#4 search view
      {"copy", "selectall", "clear_search"}
    }
  }

  --init desired project context menu
  local ctxmenus= {}
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
