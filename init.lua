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
    toolbar.show_html_toolbar(lang)
  end
end)

if toolbar then
  require('toolbar')
  require('htmltoolbar')

  --load toolbar theme from USERHOME
  toolbar.set_theme("bar-sm-light")
  --toolbar.set_theme("bar-th-dark")
  --toolbar.set_theme("bar-ch-dark")

  --change theme defaults here
  --toolbar.tabwithclose=true
  --toolbar.tabxmargin=1
  --toolbar.back[2]="ttb-back2-same"
  --toolbar.back[2]="ttb-back2-down"

  --create the toolbar (tabpos, nvertcols, stbar)
  --tabpos=0: 1 row, use default tabs
  --tabpos=1: 1 row, tabs & buttons in the same line
  --tabpos=2: 2 rows, tabs at the top
  --tabpos=3: 2 rows, tabs at the bottom
  --nvertcols= 0..2 = number of columns in vertical toolbar
  --stbar=0: use default status bar
  --stbar=1: use toolbar's status bar
  toolbar.create(1,1,1)

  --add some buttons
  if Proj then
    toolbar.cmd("tog-projview",           Proj.toggle_projview,"Hide project [Shift+F4]", "ttb-proj-o")
    toolbar.addspace(4,true)
    toolbar.cmd("go-previous",            Proj.goto_prev_pos,  "Previous position [Shift+F11]")
    toolbar.cmd("go-next",                Proj.goto_next_pos,  "Next position [Shift+F12]")
    Proj.update_go_toolbar()
    toolbar.addspace()
  end

  toolbar.cmd("document-new",           buffer.new,          "New [Ctrl+N]")
  toolbar.cmd("document-save",          io.save_file,        "Save [Ctrl+S]")
  toolbar.cmd("document-save-as",       io.save_file_as,     "Save as [Ctrl+Shift+S]")
  toolbar.addspace()

  toolbar.cmd("gnome-app-install-star", textadept.bookmarks.toggle, "Toggle bookmark [Ctrl+F2]" )
  if Proj then
    toolbar.cmd("dialog-ok",              Proj.trim_trailing_spaces, "Trim trailing spaces")
  end

  --HTML quicktype toolbar
  toolbar.add_html_toolbar()

  --add tab group if pending
  toolbar.addpending()
  --add a group of buttons after tabs
  toolbar.addrightgroup()
  --toolbar.cmd("new",           buffer.new,    "New [Ctrl+N]", "list-add")

  local function toggleconfig()
    local on
    if toolbar.config_toolbar_on then
      toolbar.config_toolbar_on= false
    else
      toolbar.config_toolbar_on= true
    end
    toolbar.seltoolbar(3)
    toolbar.show(toolbar.config_toolbar_on)
    toolbar.seltoolbar(0)
  end
  toolbar.cmd("cfg",           toggleconfig,  "Show configuration panel", "visualization")

  --toolbar ready, show it
  toolbar.ready()

  toolbar.cfgtabs={"Buffer", "View", "Project", "Editor", "Toolbar"}

  events.connect("toolbar_tabclicked", function(ntab,ntoolbar)
    if ntoolbar == 3 then
      toolbar.seltoolbar(3)
      toolbar.activatetab(ntab)
      toolbar.settext("cfgtit", toolbar.cfgtabs[ntab].." configuration", "", true)
      toolbar.seltoolbar(0)
    end
  end)

  --vertical right (config)
  toolbar.new(350, 24, 16, 3, toolbar.themepath)
  toolbar.seticon("TOOLBAR", "ttb-cback", 0, true)  --vertical back

  --config title: width=expand / height=27
  toolbar.addgroup(7, 0, 0, 27)
  toolbar.seticon("GROUP", "ttb-cback2", 0, true)
  toolbar.textfont(toolbar.textfont_sz+4, toolbar.textfont_yoffset, toolbar.statcolor_normal, toolbar.statcolor_normal)
  toolbar.addtext("cfgtit", toolbar.cfgtabs[1].." configuration", "", 350)
  toolbar.enable("cfgtit",false,true)

  toolbar.tabwithclose=false
  toolbar.tabwidthmode=0
  toolbar.tabwidthmin=0
  toolbar.add_tabs_here()
  if toolbar.img[4]  == "" then toolbar.img[4]=  "ttb-tab-back" end
  if toolbar.img[7]  == "" then toolbar.img[7]=  "ttb-ntab3nc" end
  if toolbar.img[10] == "" then toolbar.img[10]= "ttb-dtab3nc" end
  if toolbar.img[13] == "" then toolbar.img[13]= "ttb-htab3nc" end
  if toolbar.img[16] == "" then toolbar.img[16]= "ttb-atab3nc" end
  for i, img in ipairs(toolbar.img) do
    if img ~= "" then toolbar.seticon("GROUP", img, i, true) end
  end
  toolbar.seticon("GROUP", toolbar.back[1], 0, true)  --horizontal back x 1row
  toolbar.textfont(toolbar.textfont_sz, toolbar.textfont_yoffset, toolbar.textcolor_normal, toolbar.textcolor_grayed)
  for i,txt in ipairs(toolbar.cfgtabs) do
    toolbar.settab(i,txt, "")
  end
  toolbar.activatetab(1)

  toolbar.show(false)
  toolbar.seltoolbar(0)
end
