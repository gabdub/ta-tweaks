--if not CURSES then ui.set_theme('base16-tomorrow-dark') end
if not CURSES then ui.set_theme('ggg') end

TA_MAYOR_VER= tonumber(_RELEASE:match('^Textadept (.+)%..+$'))

-- Control+F4 = RESET textadept
keys.cf4 = reset

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
    toolbar.cmd("tog-projview", Proj.toggle_projview,"Hide project [Shift+F4]", "ttb-proj-o")
    toolbar.addspace(4,true)
    toolbar.cmd("go-previous",  Proj.goto_prev_pos,  "Previous position [Shift+F11]")
    toolbar.cmd("go-next",      Proj.goto_next_pos,  "Next position [Shift+F12]")
    Proj.update_go_toolbar()
    toolbar.addspace()
    toolbar.cmd("document-new",     Proj.new_file,   "New [Ctrl+N]")
  end

  toolbar.cmd("document-save",    io.save_file,    "Save [Ctrl+S]")
  toolbar.cmd("document-save-as", io.save_file_as, "Save as [Ctrl+Shift+S]")
  toolbar.addspace()

  toolbar.cmd("tog-book", textadept.bookmarks.toggle, "Toggle bookmark [Ctrl+F2]", "gnome-app-install-star" )

  if Proj then toolbar.cmd("trimsp", Proj.trim_trailing_spaces, "Trim trailing spaces","dialog-ok")  end

  local function showpopup()
    toolbar.show_popup("window-new",33)
  end
  toolbar.cmd("window-new", showpopup, "TEST show popup")
  toolbar.create_popup()

  --toolbars ready, show them
  toolbar.ready()
end
