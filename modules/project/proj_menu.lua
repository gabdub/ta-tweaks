local _L = _L
local SEPARATOR = ""

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
  ls["closeall"][2]=            Proj.close_all_buffers
  ls["open_userhome"][2]=       Proj.qopen_user
  ls["open_textadepthome"][2]=  Proj.qopen_home
  ls["open_currentdir"][2]=     Proj.qopen_curdir
  ls["open_projectdir"][2]=     Proj.snapopen
  ls["show_documentation"][2]=  Proj.show_doc
  ls["next_buffer"][2]=         Proj.next_buffer
  ls["prev_buffer"][2]=         Proj.prev_buffer
  ls["switch_buffer"][2]=       Proj.switch_buffer
  ls["refresh_syntax"][2]=      Proj.refresh_hilight

  local function tpv_status()
    return (Proj.get_projectbuffer() and 0 or 8) --8=disabled
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
  actions.add("trim_trailingspaces", 'Trim trailing spaces',  Proj.trim_trailing_spaces)
  actions.add("new_project",         _L['_New'],              Proj.new_project)
  actions.add("open_project",        _L['_Open'],             Proj.open_project)
  actions.add("recent_project",      _L['Open _Recent...'],   Proj.open_recent_project)
  actions.add("close_project",       _L['_Close'],            Proj.close_project)
  actions.add("search_project",      'Project _Search',       Proj.search_in_files)
  actions.add("goto_tag",            'Goto _Tag',             Proj.goto_tag)
  actions.add("save_position",       'S_ave position',        Proj.store_current_pos)
  actions.add("next_position",       'Ne_xt position',        Proj.goto_next_pos)
  actions.add("prev_position",       '_Prev position',        Proj.goto_prev_pos)
  actions.add("close_others",        'Close Others',          Proj.close_others)
  actions.add("dont_close",          "Mark as don't close",   Proj.keep_thisbuffer)
  actions.add("onlykeepproj",        _L['Close All'],         Proj.onlykeep_projopen)
  actions.add("open_projsel",        _L['_Open'] .. ' file  [Return]', Proj.open_sel_file)
  actions.add("toggle_editproj",     _L['_Edit'] .. ' project', Proj.change_proj_ed_mode)
  --"_end_editproj" = "toggle_editproj" with different text menu
  actions.add("_end_editproj",       '_End edit',             Proj.change_proj_ed_mode)
  actions.add("toggle_viewproj",     '_Hide/show project',    Proj.toggle_projview, tpv_icon, tpv_status, tpv_text)
  actions.add("addthisfiles_proj",   '_Add this file',        Proj.add_this_file)
  actions.add("addallfiles_proj",    'Add all open _Files',   Proj.add_all_files)
  actions.add("adddirfiles_proj",    'Add files from _Dir',   Proj.add_dir_files)

  --add PROJECT menu (before Help)
  table.insert( actions.menubar, #actions.menubar,
    {title='_Project',
     {"new_project","open_project","recent_project","close_project",SEPARATOR,
      "search_project","goto_tag","save_position","next_position","prev_position",SEPARATOR,
      "addthisfiles_proj","addallfiles_proj","adddirfiles_proj"}
    })

  --add action at the end of the EDIT menu
  actions.menubar[2][#actions.menubar[2]+1]= {SEPARATOR,"trim_trailingspaces"}

  --replace tab context menu
  actions.tab_context_menu = {
    {"close","close_others","dont_close","onlykeepproj",SEPARATOR,
     "save","saveas",SEPARATOR,
     "reload"}
  }

  actions.free_accelerator({"ao","f4","sf4","cpgup","cpgdn","apgup","apgdn","cO","caP"})
  actions.accelerators["toggle_editproj"]="f4"
  actions.accelerators["_end_editproj"]="f4" --(alias)
  actions.accelerators["toggle_viewproj"]="sf4"
  actions.accelerators["prev_buffer"]="cpgup"
  actions.accelerators["next_buffer"]="cpgdn"
  actions.accelerators["open_projectdir"]="cO"
  actions.accelerators["open_textadepthome"]="caP"
end
keys.ao = Proj.open_cursor_file
keys['apgup'] = Proj.first_buffer
keys['apgdn'] = Proj.last_buffer
