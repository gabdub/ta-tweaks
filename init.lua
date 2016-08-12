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
