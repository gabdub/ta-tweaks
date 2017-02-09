--if not CURSES then ui.set_theme('base16-tomorrow-dark') end
if not CURSES then ui.set_theme('ggg') end

TA_MAYOR_VER= tonumber(_RELEASE:match('^Textadept (.+)%..+$'))

-- Control+F4 = RESET textadept
keys.cf4 = reset

function Winfo(msg,info)
  ui.dialogs.msgbox{
    title = 'Information',
    text = msg,
    informative_text = info,
    icon = 'gtk-dialog-info', button1 = _L['_OK']
  }
end

function my_goto_view(view)
  if TA_MAYOR_VER < 9 then
    ui.goto_view(view)
  else
    ui.goto_view(_VIEWS[view])
  end
end

--goto line= 0...
function my_goto_line(p_buffer,line)
  p_buffer:ensure_visible_enforce_policy(line)
  p_buffer:goto_line(line)
end

--https://foicica.com/wiki/export
export = require('export')
--export.browser = 'chromium-browser'

require('project')
require('goto_nearest')
require('ctrl_tab_mru')
require('quicktype')

--cf5 "List commands in a new buffer"
if actions then
  actions.add("dump_cmds", "Dump commands", function() actions.select_command(true) end, "cf5")
end

textadept.file_types.extensions.mas = 'mas'
textadept.editing.comment_string.ansi_c = '//'

if toolbar then
  require('toolbar')
  require('htmltoolbar')

  --set the configured theme
  toolbar.set_theme_from_config()

  --change theme defaults here
  --toolbar.back[2]="ttb-back2-same"
  --toolbar.back[2]="ttb-back2-down"

  --create the configured toolbars
  toolbar.create_from_config()

  --add some buttons
  if Proj then
    toolbar.addaction("toggle_viewproj")
    toolbar.addspace(4,true)
    toolbar.addaction("prev_position")
    toolbar.addaction("next_position")
    toolbar.addspace()
    toolbar.addaction("new")
  end

  toolbar.addaction("save")
  toolbar.addaction("saveas")
  toolbar.addspace()

  toolbar.addaction("toggle_bookmark")

  toolbar.addaction("toggle_macrorec")
  toolbar.addaction("play_macrorec")

  if Proj then toolbar.addaction("trim_trailingspaces") end

  local function showpopup()
    toolbar.show_popup("window-new",33)
  end
  toolbar.cmd("window-new", showpopup, "TEST show popup")
  toolbar.create_popup()

  --toolbars ready, show them
  toolbar.ready()
end
