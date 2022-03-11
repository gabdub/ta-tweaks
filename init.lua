-- Copyright 2016-2022 Gabriel Dubatti. See LICENSE.
-- code adjusted for TA 11

if toolbar then
  USE_LISTS_PANEL= true   --true:show project lists in the left toolbar;   false= use a buffer
  USE_RESULTS_PANEL= true --true:show results lists in the bottom toolbar; false= use a buffer
  USE_FILE_CHOOSER= true  --true:use file chooser toolbar dialogs;         false= use TA dialogs: ui.dialogs / io.quick_open
end

plugs= {} --add here functions from interfaces (e.g. project/results lists)
---- LISTS INTERFACE ------------------------
function plugs.init_projectview() end
function plugs.check_lost_focus(buff) end
function plugs.goto_projectview() return false end
function plugs.projmode_select() end
function plugs.projmode_edit() end
function plugs.update_after_switch() end
function plugs.change_proj_ed_mode() end
function plugs.track_this_file() end
function plugs.proj_refresh_hilight() end
function plugs.open_project() end
function plugs.close_project(keepviews) end
function plugs.get_prj_currow() return nil end
function plugs.open_sel_file() end
function plugs.buffer_deleted() end
function plugs.update_proj_buffer(reload) end
---- RESULTS INTERFACE ----------------------
function plugs.init_searchview() end
function plugs.goto_searchview() return false end
function plugs.close_results(viewclosed) end
function plugs.clear_results() end
---- SEARCH RESULTS INTERFACE ---------------
function plugs.search_result_start(s_txt, s_filter) end
function plugs.search_result_info(s_txt, iserror) end
function plugs.search_result_in_file(shortname, fname, nfiles) end
function plugs.search_result_found(fname, nlin, txt, s_start, s_end) end
function plugs.search_result_end() end
function plugs.doble_click_searchview() end
---- COMPARE FILE RESULTS INTERFACE ---------
function plugs.compare_file_result(n1, buffer1, r1, n2, buffer2, r2, n3, rm) end
---------------------------------------------

TA_THEME= 'ggg'

require('util')

local snippath= _USERHOME..'/snippets'
if Util.dir_exists(snippath) then table.insert(textadept.snippets.paths, snippath) end

--require('log')
if not CURSES and Util.TA_MAYOR_VER >= 11 then  --check: NO CURSES / TA11 or above
  for _, vw in ipairs(_VIEWS) do vw:set_theme(TA_THEME) end

  -- Control+F4 = RESET textadept
  keys[Util.KEY_CTRL.."f4"] = reset

  require('export')
  require('project')
  require('goto_nearest')
  require('ctrl_tab_mru')
  require('quicktype')

  --ctrl+f5 "List commands in a new buffer"
  --if actions then
  --  actions.add("dump_cmds", "Dump commands", function() actions.select_command(true) end, Util.KEY_CTRL.."f5")
  --end

  textadept.file_types.extensions.MAS = 'mas'
  textadept.file_types.extensions.mas = 'mas'
  textadept.file_types.extensions.inc = 'mas'
  textadept.file_types.extensions.INC = 'mas'
  textadept.editing.comment_string.ansi_c = '//'
  textadept.editing.comment_string.asm = ';'

  textadept.editing.highlight_words= textadept.editing.HIGHLIGHT_SELECTED

  keys.KEYSYMS[0xFF8D] = '\n' --keypad Enter = normal Enter

  if toolbar then
    require('toolbar')

    --if not USE_LISTS_PANEL then require('htmltoolbar') end

    if Proj then
      if USE_LISTS_PANEL then --show project lists in the left toolbar
        require('listtoolbar')
        require('listtoolbar.recentprojlist')
        require('listtoolbar.projlist')
        require('listtoolbar.ctaglist')
        require('listtoolbar.filebrowser')
      end
      if USE_RESULTS_PANEL then --show results lists in the bottom toolbar
        require('results')
        require('results.printresults')
        require('results.searchresults')
      end
    end

    --set the configured theme
    toolbar.set_theme_from_config()

    --change theme defaults here
    --toolbar.set_backimg(2, "ttb-back2-same")

    --create the configured toolbars
    toolbar.create_from_config()

    --add some buttons
    if Proj then
      if not USE_LISTS_PANEL then
        toolbar.addaction("toggle_viewproj")
        toolbar.addspace(4,true)
      end
      toolbar.addaction("prev_position")
      toolbar.addaction("next_position")
      toolbar.addspace()
    end

    toolbar.addaction("new_open")     --new / open / recent
    toolbar.addaction("save_saveas")  --save / save-as / save-all
    toolbar.addspace()
    --toolbar.addaction("find_dialog") --not ready

    toolbar.addaction("toggle_bookmark")

    toolbar.addaction("toggle_macrorec")
    toolbar.addaction("play_macrorec")

    if Proj then toolbar.addaction("trim_trailingspaces") end

    -- minimap/scrollbar (right internal toolbar)
    toolbar.minimap_setup()

    --toolbars are ready to show
    toolbar.ready()
  end

  --reload changed files without prompting
  events.connect(events.FILE_CHANGED, function()
    buffer:reload()
    return false
  end,1)
end