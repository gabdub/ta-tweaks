--if not CURSES then ui.set_theme('base16-tomorrow-dark') end
if not CURSES then ui.set_theme('ggg') end

TA_MAYOR_VER= tonumber(_RELEASE:match('^Textadept (.+)%..+$'))

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

require('project')
require('goto_nearest')
require('ctrl_tab_mru')

require('quicktype')

textadept.file_types.extensions.mas = 'mas'

events.connect(events.LEXER_LOADED, function(lang)
  if lang == 'vala' then
    buffer.tab_width = 4
    buffer.use_tabs = false
  elseif lang == 'lua' or lang == 'text' then
    buffer.tab_width = 2
    buffer.use_tabs = false
  else
    buffer.tab_width = 2
    buffer.use_tabs = false
  end
end)

if toolbar then
  require('toolbar')

  ui.tabs= false  --hide regular tabbar

  --load toolbar theme from USERHOME
  --toolbar.set_theme("bar-sm-light")
  --toolbar.set_theme("bar-ff-dark")
  toolbar.set_theme("bar-th-dark")
  --toolbar.barsize=toolbar.barsize*2
  toolbar.tabxmargin=0

  --change theme defaults here
  --toolbar.tabwithclose= true
  toolbar.img[1]="ttb-back2"

  toolbar.create()  --create the toolbar

  toolbar.add_tabs_here()
  toolbar.gotopos(5) --new row

  --add some buttons
  toolbar.cmd("go-previous",            Proj.goto_prev_pos,  "Previous position [Shift+F11]")
  toolbar.cmd("go-next",                Proj.goto_next_pos,  "Next position [Shift+F12]")
  Proj.update_go_toolbar()
  toolbar.addspace()

  toolbar.cmd("document-new",           buffer.new,          "New [Ctrl+N]")
  toolbar.cmd("document-save",          io.save_file,        "Save [Ctrl+S]")
  toolbar.cmd("document-save-as",       io.save_file_as,     "Save as [Ctrl+Shift+S]")
  toolbar.addspace()
  toolbar.cmd("gnome-app-install-star", textadept.bookmarks.toggle, "Toggle bookmark [Ctrl+F2]" )
  toolbar.addspace()
  toolbar.cmd("dialog-ok",              Proj.trim_trailing_spaces, "Trim trailing spaces")

  --toolbar.gotopos(3) --new row

  --show tabs in the toolbar
  --toolbar.add_tabs_here()

  toolbar.show(true)  --show toolbar

  toolbar.update_all_tabs()   --load existing buffers in tab-bar
  toolbar.seltab(_BUFFERS[buffer])  --select current buffer
end
