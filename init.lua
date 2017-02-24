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

--require('file_diff')

--cf5 "List commands in a new buffer"
if actions then
  actions.add("dump_cmds", "Dump commands", function() actions.select_command(true) end, "cf5")

  actions.add("sdiff_test", "String diff TEST", function()
    actions.run("new")  --new buffer
    local s1= "televisor sorpresa"
    local s2= "string sor de prueba sorteo"
    buffer:append_text(s1.." => "..s2.."\n")
    local r= filediff.strdiff( s1, s2 )
    for i=1,#r,3 do
      buffer:append_text("F"..r[i].." = "..r[i+1].." - "..r[i+2].."\n")
    end
    buffer:append_text(s2.." => "..s1.."\n")
    r= filediff.strdiff( s2, s1 )
    for i=1,#r,3 do
      buffer:append_text("F"..r[i].." = "..r[i+1].." - "..r[i+2].."\n")
    end
  end, "f6")
  actions.add("fdiff_old", "Load current file buffer as the OLD version", function()
    filediff.setfile(2, buffer:get_text())
  end, "sf6")
  actions.add("fdiff_new", "Load current file buffer as the NEW version", function()
    filediff.setfile(1, buffer:get_text())
  end, "cf6")
  actions.add("fdiff_test", "File diff TEST", function()
    actions.run("new")  --new buffer
    local r= filediff.getdiff( 1, 1 )
    buffer:append_text("--ONLY IN NEW FILE (+)--\n")
    for i=1,#r,2 do
      buffer:append_text("F1 L "..r[i].." - "..r[i+1].."\n")
    end
    r= filediff.getdiff( 2, 1 )
    buffer:append_text("--ONLY IN OLD FILE (-)--\n")
    for i=1,#r,2 do
      buffer:append_text("F2 L "..r[i].." - "..r[i+1].."\n")
    end
    r= filediff.getdiff( 1, 3 )
    buffer:append_text("--ADD BLANKS LINES NEW--\n")
    for i=1,#r,2 do
      buffer:append_text("F1 L "..r[i].." n= "..r[i+1].."\n")
    end
    r= filediff.getdiff( 2, 3 )
    buffer:append_text("--ADD BLANKS LINES OLD--\n")
    for i=1,#r,2 do
      buffer:append_text("F2 L "..r[i].." n= "..r[i+1].."\n")
    end
    r= filediff.getdiff( 1, 2 )
    buffer:append_text("--ONE LINE CHANGES--\n")
    for i=1,#r,2 do
      buffer:append_text("F1 L "..r[i].." <-> F2 L"..r[i+1].."\n")
    end
    r= filediff.getdiff( 1, 4 )
    buffer:append_text("--TEXT CHANGES INSIDE ONE LINE--\n")
    for i=1,#r,3 do
      buffer:append_text("F"..r[i].." pos= "..r[i+1].." n= "..r[i+2].."\n")
    end
  end, "af6")
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
