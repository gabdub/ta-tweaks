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
  if toolbar then
    --show vertical toolbar only in html files
    toolbar.seltoolbar(1)
    toolbar.show(lang == 'html')
    toolbar.seltoolbar(0)
  end
end)

local function enc_html_html()
  type_before_after('<html>\n', '\n\n</html>\n')
end
local function enc_html_para()
  type_before_after('<p>', '</p>\n')
end
local function enc_html_bold()
  type_before_after('<b>', '</b>')
end
local function enc_html_italic()
  type_before_after('<i>', '</i>')
end
local function enc_html_underline()
  type_before_after('<u>', '</u>')
end
local function enc_html_ul()
  type_before_after('<ul>\n', '</ul>\n')
end
local function enc_html_li()
  type_before_after('<li>', '</li>\n')
end

if toolbar then
  require('toolbar')

  --load toolbar theme from USERHOME
  toolbar.set_theme("bar-sm-light")
  --toolbar.set_theme("bar-ff-dark")
  --toolbar.set_theme("bar-th-dark")
  --toolbar.set_theme("bar-ch-dark")

  --change theme defaults here
  --toolbar.tabwithclose=true
  --toolbar.tabxmargin=0

  --create the toolbar (tabpos, nvertcols, stbar)
  --tabpos=0: 1 row, use default tabs
  --tabpos=1: 1 row, tabs & buttons in the same line
  --tabpos=2: 2 rows, tabs at the top (horizonal only)
  --tabpos=3: 2 rows, tabs at the bottom (horizonal only)
  --nvertcols= 0..2 = number of columns in vertical toolbar
  --stbar=0: use default status bar
  --stbar=1: use toolbar's status bar
  toolbar.create(1,1,1)

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
  toolbar.cmd("gnome-app-install-star", textadept.bookmarks.toggle, "Toggle bookmark [Ctrl+F2]" )
  toolbar.addspace()
  --toolbar.newrow()
  toolbar.cmd("dialog-ok",              Proj.trim_trailing_spaces, "Trim trailing spaces")

  toolbar.seltoolbar(1)
  toolbar.cmd("go-home",                enc_html_html,           "HTML block")
  toolbar.cmd("edit-select-all",        enc_html_para,           "HTML paragraph")
  toolbar.cmd("format-text-bold",       enc_html_bold,           "HTML bold text")
  toolbar.cmd("format-text-italic",     enc_html_italic,         "HTML italic text")
  toolbar.cmd("format-text-underline",  enc_html_underline,      "HTML underline text")
  toolbar.cmd("view-list-details-symbolic",enc_html_ul,          "HTML unordered list")
  toolbar.cmd("view-list-compact-symbolic",enc_html_li,          "HTML list item")

  --toolbar ready, show it
  toolbar.ready()
end
