-- Control+F4 = RESET textadept
keys.cf4 = reset

if not CURSES then ui.set_theme('ggg') end

require('util')
require('export')
require('project')
require('goto_nearest')
require('ctrl_tab_mru')
require('quicktype')

--cf5 "List commands in a new buffer"
if actions then
  actions.add("dump_cmds", "Dump commands", function() actions.select_command(true) end, "cf5")

--f6 "svn cat"
  actions.add("svn_changes", "SVN: compare current buffer to HEAD version", function()
    local orgbuf= buffer
    if orgbuf._is_svn then
      orgbuf._is_svn= nil
      --close right file (svn HEAD)
      Proj.goto_filesview(false,true)
      Proj.close_buffer()
      Proj.goto_filesview()
      Util.goto_buffer(orgbuf)
      return
    end
    local orgfile= buffer.filename
    if orgfile then
      --convert filename to svn url
      local url= Proj.get_svn_url(orgfile)
      if url then
        buffer._is_svn= true
        local enc= buffer.encoding     --keep encoding
        local lex= buffer:get_lexer()  --keep lexer
        --new buffer
        actions.run("new")
        local cmd= "svn cat "..url
        local p = assert(spawn(cmd))
        p:close()
        buffer:set_text((p:read('*a') or ''):iconv('UTF-8', enc))
        if enc ~= 'UTF-8' then buffer:set_encoding(enc) end
        buffer:set_lexer(lex)
        buffer:set_save_point()
        buffer._is_svn= true
        --show in the right panel
        Proj.toggle_showin_rightpanel()
        Proj.goto_filesview()
        Util.goto_buffer(orgbuf)
        --compare files
        Proj.diff_start()
      end
    end
  end, "f6")
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
