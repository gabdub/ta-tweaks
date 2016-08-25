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

textadept.file_types.extensions.mas = 'mas'

events.connect(events.LEXER_LOADED, function(lang)
  if lang == 'vala' then
    buffer.tab_width = 4
    buffer.use_tabs = false
  elseif lang == 'lua' then
    buffer.tab_width = 2
    buffer.use_tabs = false
  else
    buffer.tab_width = 4
    buffer.use_tabs = true
  end
end)

if toolbar then
  function toolbar.cmd(name,func,tooltip)
    toolbar.addbutton(name,tooltip)
    toolbar[name]= func
  end

  events.connect("toolbar_clicked", function(button)
    if toolbar[button] ~= nil then
      toolbar[button]()
    else
      ui.statusbar_text= button.." clicked"
    end
  end)

  --create toolbar: barsize,buttonsize,imgsize,[isvertical],[imgpath]
  toolbar.new(27, 24, 16)--, false, "/home/gabriel/Descargas/PROG/textadept_9_NIGHTLY/core/images/bar2/")
  --toolbar.adjust(26, 24, 2, 1, 4, 4); --bwidth,bheight,xmargin,ymargin,xoff,yoff
  toolbar.seticon("TOOLBAR", "ttb-back")

  toolbar.cmd("go-previous",            Proj.goto_prev_pos,  "Previous position [Shift+F11]")
  toolbar.cmd("go-next",                Proj.goto_next_pos,  "Next position [Shift+F12]")
  Proj.update_go_toolbar()
  toolbar.addspace()

  toolbar.cmd("document-new",           buffer.new,          "New [Ctrl+N]")
  --toolbar.gotopos(3); --new row
  toolbar.cmd("document-save",          io.save_file,        "Save [Ctrl+S]")
  toolbar.cmd("document-save-as",       io.save_file_as,     "Save as [Ctrl+Shift+S]")
  toolbar.addspace()
  toolbar.cmd("gnome-app-install-star", textadept.bookmarks.toggle, "Toggle bookmark [Ctrl+F2]" )
  toolbar.show(true)
end

------------------- tab-double-click close buffer ---------------
--events.connect(events.TAB_DOUBLE_CLICK, function() Proj.close_buffer() end)

--macro recording / playback from: https://github.com/shitpoet/ta-macro
--local macro = require('ta-macro')
--keys.cr = macro.record
--keys.cR = macro.finish
--keys.ar = macro.replay

--------------------------------------------------------------
-- Control+F =    Shift+F3
-- Control+G =    goto-line
-- Control+F4 =   RESET textadept
keys.cf = keys.sf3
keys.cg = textadept.editing.goto_line
keys.cf4 = reset
