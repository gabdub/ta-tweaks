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

  --load toolbar theme from USERHOME
  toolbar.set_theme("bar-sm-light")
  --toolbar.set_theme("bar-ff-dark")
  --toolbar.set_theme("bar-th-dark")

  --change theme defaults here
  --toolbar.tabwithclose= true
  --toolbar.tabxmargin=0

  --create the toolbar (tabpos, nvertcols)
  --tabpos=0: 1 row, use default tabs
  --tabpos=1: 1 row, tabs & buttons in the same line
  --tabpos=2: 2 rows, tabs at the top (horizonal only)
  --tabpos=3: 2 rows, tabs at the bottom (horizonal only)
  --nvertcols= 0..2 = number of columns in vertical toolbar
  toolbar.create(1)

  --toolbar.seltoolbar(1)
  --add some buttons
  toolbar.cmd("tog-projview",           Proj.toggle_projview,"Hide project [Shift+F4]", "ttb-proj-o")

  toolbar.cmd("go-previous",            Proj.goto_prev_pos,  "Previous position [Shift+F11]")
  toolbar.cmd("go-next",                Proj.goto_next_pos,  "Next position [Shift+F12]")
  Proj.update_go_toolbar()
  toolbar.addspace()

  toolbar.cmd("document-new",           buffer.new,          "New [Ctrl+N]")
  toolbar.cmd("document-save",          io.save_file,        "Save [Ctrl+S]")
  toolbar.cmd("document-save-as",       io.save_file_as,     "Save as [Ctrl+Shift+S]")
  toolbar.addspace()
  --toolbar.seltoolbar(1)
  toolbar.cmd("gnome-app-install-star", textadept.bookmarks.toggle, "Toggle bookmark [Ctrl+F2]" )
  toolbar.addspace()
  --toolbar.newrow()
  toolbar.cmd("dialog-ok",              Proj.trim_trailing_spaces, "Trim trailing spaces")

  --status bar
  toolbar.new(24, 24, 16, 2, toolbar.themepath)
  toolbar.seticon("TOOLBAR", toolbar.back[1], 0, true)
  toolbar.cmd("tog-projview",           Proj.toggle_projview,"Hide project [Shift+F4]", "ttb-proj-o")
  --toolbar.cmd("dialog-ok", Proj.trim_trailing_spaces, "Trim trailing spaces")
  toolbar.addtabs(2,2,false,0, 12, 0)
  toolbar.settab(-1,"status", "status")
  --toolbar.enabletab(-1,false)
  toolbar.tabwidth(-1,-75)
  toolbar.settab(-2,"Line:86/92  Col:32  lua  LF  Spaces:2  UTF-8", "info")
  toolbar.tabwidth(-2,-25,200)
  toolbar.show(true)

  --toolbar ready, show it
  toolbar.ready()
end
