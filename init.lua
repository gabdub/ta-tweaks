-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
-- code adjusted for TA 10 and 11

--NOTE: to prevent Kubuntu 20.04.1 from closing at random: comment line 74 in modules/textadept/file_types.lua
--(buffer:colorize(1, buffer:position_from_line(last_line + 1)) -- refresh)
--The issue looks like an implementation bug of GTK on plasma

if toolbar then
  USE_LISTS_PANEL= true   --true:show project lists in the left toolbar;   false= use a buffer
  USE_RESULTS_PANEL= true --true:show results lists in the bottom toolbar; false= use a buffer
end

plugs= {} --add here functions from interfaces (e.g. project/results lists)

TA_THEME= 'ggg'

require('util')
--require('log')
if not CURSES then
  if Util.TA_MAYOR_VER < 11 then
    for _, buff in ipairs(_BUFFERS) do buff:set_theme(TA_THEME) end
  else
    for _, vw in ipairs(_VIEWS) do vw:set_theme(TA_THEME) end
  end
end
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

  toolbar.addaction("new")
  toolbar.addaction("save")
  toolbar.addaction("saveas")
  toolbar.addspace()

  toolbar.addaction("toggle_bookmark")

  toolbar.addaction("toggle_macrorec")
  toolbar.addaction("play_macrorec")

  if Proj then toolbar.addaction("trim_trailingspaces") end

  --popup TEST
  toolbar.cmd("window-new", toolbar.show_popup_center, "TEST show popup")

  -- minimap/scrollbar (right internal toolbar)
  toolbar.minimap_setup()

  --toolbars are ready to show
  toolbar.ready()
end

--reload changed files without prompting
events.connect(events.FILE_CHANGED, function()
  Util.reload_file()
  return false
end,1)
