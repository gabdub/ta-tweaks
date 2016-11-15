local SEPARATOR = {''}

-- Commonly used functions in menu commands.
local sel_enc = textadept.editing.select_enclosed
local enc = textadept.editing.enclose
local function set_indentation(i)
  buffer.tab_width = i
  events.emit(events.UPDATE_UI) -- for updating statusbar
  if toolbar then toolbar.setcfg_from_tabwidth() end --update config panel
end
local function set_eol_mode(mode)
  buffer.eol_mode = mode
  buffer:convert_eols(mode)
  events.emit(events.UPDATE_UI) -- for updating statusbar
  if toolbar then toolbar.setcfg_from_eolmode() end --update config panel
end
local function set_encoding(encoding)
  buffer:set_encoding(encoding)
  events.emit(events.UPDATE_UI) -- for updating statusbar
end
local function open_page(url)
  local cmd = (WIN32 and 'start ""') or (OSX and 'open') or 'xdg-open'
  spawn(string.format('%s "%s"', cmd, not OSX and url or 'file://'..url))
end

local proj_menubar = {
  {
    title = _L['_File'],
    {_L['_New'], Proj.new_file},
    {_L['_Open'], Proj.open_file},
    {_L['Open _Recent...'], Proj.open_recent_file},
    {_L['Re_load'], io.reload_file},
    {_L['_Save'], io.save_file},
    {_L['Save _As'], io.save_file_as},
    {_L['Save All'], io.save_all_files},
    SEPARATOR,
    {_L['_Close'], Proj.close_buffer},
    {_L['Close All'], Proj.close_all_buffers},
    SEPARATOR,
    {_L['Loa_d Session...'], textadept.session.load},
    {_L['Sav_e Session...'], textadept.session.save},
    SEPARATOR,
    {_L['_Quit'], quit}
  },
  {
    title = _L['_Edit'],
    {_L['_Undo'], buffer.undo},
    {_L['_Redo'], buffer.redo},
    SEPARATOR,
    {_L['Cu_t'], buffer.cut},
    {_L['_Copy'], buffer.copy},
    {_L['_Paste'], buffer.paste},
    {_L['Duplicate _Line'], buffer.line_duplicate},
    {_L['_Delete'], buffer.clear},
    {_L['D_elete Word'], function()
      textadept.editing.select_word()
      buffer:delete_back()
    end},
    {_L['Select _All'], buffer.select_all},
    SEPARATOR,
    {_L['_Match Brace'], textadept.editing.match_brace},
    {_L['Complete _Word'], function()
      textadept.editing.autocomplete('word')
    end},
    {_L['_Highlight Word'], textadept.editing.highlight_word},
    {_L['Toggle _Block Comment'], textadept.editing.block_comment},
    {_L['T_ranspose Characters'], textadept.editing.transpose_chars},
    {_L['_Join Lines'], textadept.editing.join_lines},
    {_L['_Filter Through'], function()
      ui.command_entry.enter_mode('filter_through', 'bash')
    end},
    {
      title = _L['_Select'],
      {_L['Select to _Matching Brace'], function()
        textadept.editing.match_brace('select')
      end},
      {_L['Select between _XML Tags'], function() sel_enc('>', '<') end},
      {_L['Select in XML _Tag'], function() sel_enc('<', '>') end},
      {_L['Select in _Single Quotes'], function() sel_enc("'", "'") end},
      {_L['Select in _Double Quotes'], function() sel_enc('"', '"') end},
      {_L['Select in _Parentheses'], function() sel_enc('(', ')') end},
      {_L['Select in _Brackets'], function() sel_enc('[', ']') end},
      {_L['Select in B_races'], function() sel_enc('{', '}') end},
      {_L['Select _Word'], textadept.editing.select_word},
      {_L['Select _Line'], textadept.editing.select_line},
      {_L['Select Para_graph'], textadept.editing.select_paragraph}
    },
    {
      title = _L['Selectio_n'],
      {_L['_Upper Case Selection'], buffer.upper_case},
      {_L['_Lower Case Selection'], buffer.lower_case},
      SEPARATOR,
      {_L['Enclose as _XML Tags'], function()
        enc('<', '>')
        local pos = buffer.current_pos
        while buffer.char_at[pos - 1] ~= 60 do pos = pos - 1 end -- '<'
        buffer:insert_text(-1, '</'..buffer:text_range(pos, buffer.current_pos))
      end},
      {_L['Enclose as Single XML _Tag'], function() enc('<', ' />') end},
      {_L['Enclose in Single _Quotes'], function() enc("'", "'") end},
      {_L['Enclose in _Double Quotes'], function() enc('"', '"') end},
      {_L['Enclose in _Parentheses'], function() enc('(', ')') end},
      {_L['Enclose in _Brackets'], function() enc('[', ']') end},
      {_L['Enclose in B_races'], function() enc('{', '}') end},
      SEPARATOR,
      {_L['_Move Selected Lines Up'], buffer.move_selected_lines_up},
      {_L['Move Selected Lines Do_wn'], buffer.move_selected_lines_down}
    },
    SEPARATOR,
    {'Trim trailing spaces', Proj.trim_trailing_spaces}
  },
  {
    title = _L['_Search'],
    {_L['_Find'], function()
      ui.find.in_files = false
      ui.find.focus()
    end},
    {_L['Find _Next'], ui.find.find_next},
    {_L['Find _Previous'], ui.find.find_prev},
    {_L['_Replace'], ui.find.replace},
    {_L['Replace _All'], ui.find.replace_all},
    {_L['Find _Incremental'], ui.find.find_incremental},
    SEPARATOR,
    {_L['Find in Fi_les'], function()
      ui.find.in_files = true
      ui.find.focus()
    end},
    {_L['Goto Nex_t File Found'], function()
      ui.find.goto_file_found(false, true)
    end},
    {_L['Goto Previou_s File Found'], function()
      ui.find.goto_file_found(false, false)
    end},
    SEPARATOR,
    {_L['_Jump to'], textadept.editing.goto_line}
  },
  {
    title = _L['_Tools'],
    {_L['Command _Entry'], function()
      ui.command_entry.enter_mode('lua_command', 'lua')
    end},
    {_L['Select Co_mmand'], function() M.select_command() end},
    SEPARATOR,
    {_L['_Run'], textadept.run.run},
    {_L['_Compile'], textadept.run.compile},
    {_L['Set _Arguments...'], function()
      if not buffer.filename then return end
      local run_commands = textadept.run.run_commands
      local compile_commands = textadept.run.compile_commands
      local base_commands, utf8_args = {}, {}
      for i, commands in ipairs{run_commands, compile_commands} do
        -- Compare the base run/compile command with the one for the current
        -- file. The difference is any additional arguments set previously.
        base_commands[i] = commands[buffer.filename:match('[^.]+$')] or
                           commands[buffer:get_lexer()] or ''
        local current_command = (commands[buffer.filename] or '')
        local args = current_command:sub(#base_commands[i] + 2)
        utf8_args[i] = args:iconv('UTF-8', _CHARSET)
      end
      local button, utf8_args = ui.dialogs.inputbox{
        title = _L['Set _Arguments...']:gsub('_', ''), informative_text = {
          _L['Command line arguments'], _L['For Run:'], _L['For Compile:']
        }, text = utf8_args, width = not CURSES and 400 or nil
      }
      if button ~= 1 then return end
      for i, commands in ipairs{run_commands, compile_commands} do
        -- Add the additional arguments to the base run/compile command and set
        -- the new command to be the one used for the current file.
        commands[buffer.filename] = base_commands[i]..' '..
                                    utf8_args[i]:iconv(_CHARSET, 'UTF-8')
      end
    end},
    {_L['Buil_d'], textadept.run.build},
    {_L['S_top'], textadept.run.stop},
    {_L['_Next Error'], function() textadept.run.goto_error(false, true) end},
    {_L['_Previous Error'], function()
      textadept.run.goto_error(false, false)
    end},
    SEPARATOR,
    {
      title = _L['_Bookmark'],
      {_L['_Toggle Bookmark'], textadept.bookmarks.toggle},
      {_L['_Clear Bookmarks'], textadept.bookmarks.clear},
      {_L['_Next Bookmark'], function()
        textadept.bookmarks.goto_mark(true)
      end},
      {_L['_Previous Bookmark'], function()
        textadept.bookmarks.goto_mark(false)
      end},
      {_L['_Goto Bookmark...'], textadept.bookmarks.goto_mark},
    },
    {
      title = _L['Quick _Open'],
      {_L['Quickly Open _User Home'], Proj.qopen_user},
      {_L['Quickly Open _Textadept Home'], Proj.qopen_home},
      {_L['Quickly Open _Current Directory'], Proj.qopen_curdir},
      {_L['Quickly Open Current _Project'], Proj.snapopen},
    },
    {
      title = _L['_Snippets'],
      {_L['_Insert Snippet...'], textadept.snippets._select},
      {_L['_Expand Snippet/Next Placeholder'], textadept.snippets._insert},
      {_L['_Previous Snippet Placeholder'], textadept.snippets._previous},
      {_L['_Cancel Snippet'], textadept.snippets._cancel_current},
    },
    SEPARATOR,
    {_L['_Complete Symbol'], function()
      textadept.editing.autocomplete(buffer:get_lexer(true))
    end},
    {_L['Show _Documentation'], textadept.editing.show_documentation},
    {_L['Show St_yle'], function()
      local char = buffer:text_range(buffer.current_pos,
                                     buffer:position_after(buffer.current_pos))
      if char == '' then return end -- end of buffer
      local bytes = string.rep(' 0x%X', #char):format(char:byte(1, #char))
      local style = buffer.style_at[buffer.current_pos]
      local text = string.format("'%s' (U+%04X:%s)\n%s %s\n%s %s (%d)", char,
                                 utf8.codepoint(char), bytes, _L['Lexer'],
                                 buffer:get_lexer(true), _L['Style'],
                                 buffer.style_name[style], style)
      buffer:call_tip_show(buffer.current_pos, text)
    end}
  },
  {
    title = _L['_Buffer'],
    {_L['_Next Buffer'], Proj.next_buffer},
    {_L['_Previous Buffer'], Proj.prev_buffer},
    {_L['_Switch to Buffer...'], Proj.switch_buffer},
    SEPARATOR,
    {
      title = _L['_Indentation'],
      {_L['Tab width: _2'], function() set_indentation(2) end},
      {_L['Tab width: _3'], function() set_indentation(3) end},
      {_L['Tab width: _4'], function() set_indentation(4) end},
      {_L['Tab width: _8'], function() set_indentation(8) end},
      SEPARATOR,
      {_L['_Toggle Use Tabs'], function()
        buffer.use_tabs = not buffer.use_tabs
        events.emit(events.UPDATE_UI) -- for updating statusbar
        if toolbar then toolbar.setcfg_from_usetabs() end --update config panel
      end},
      {_L['_Convert Indentation'], textadept.editing.convert_indentation}
    },
    {
      title = _L['_EOL Mode'],
      {_L['CRLF'], function() set_eol_mode(buffer.EOL_CRLF) end},
      {_L['LF'], function() set_eol_mode(buffer.EOL_LF) end}
    },
    {
      title = _L['E_ncoding'],
      {_L['_UTF-8 Encoding'], function() set_encoding('UTF-8') end},
      {_L['_ASCII Encoding'], function() set_encoding('ASCII') end},
      {_L['_ISO-8859-1 Encoding'], function() set_encoding('ISO-8859-1') end},
      {_L['UTF-1_6 Encoding'], function() set_encoding('UTF-16LE') end}
    },
    SEPARATOR,
    {_L['Toggle View _EOL'], function()
      buffer.view_eol = not buffer.view_eol
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
    {_L['Toggle _Wrap Mode'], function()
      buffer.wrap_mode = buffer.wrap_mode == 0 and buffer.WRAP_WHITESPACE or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
    {_L['Toggle View White_space'], function()
      buffer.view_ws = buffer.view_ws == 0 and buffer.WS_VISIBLEALWAYS or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
    SEPARATOR,
    {_L['Select _Lexer...'], textadept.file_types.select_lexer},
    {_L['_Refresh Syntax Highlighting'], function() buffer:colourise(0, -1) end}
  },
  {
    title = _L['_View'],
    {_L['_Next View'], function() ui.goto_view(1) end},
    {_L['_Previous View'], function() ui.goto_view(-1) end},
    SEPARATOR,
    {_L['Split View _Horizontal'], function() view:split() end},
    {_L['Split View _Vertical'], function() view:split(true) end},
    {_L['_Unsplit View'], function() view:unsplit() end},
    {_L['Unsplit _All Views'], function() while view:unsplit() do end end},
    {_L['_Grow View'], function()
      if view.size then view.size = view.size + buffer:text_height(0) end
    end},
    {_L['Shrin_k View'], function()
      if view.size then view.size = view.size - buffer:text_height(0) end
    end},
    SEPARATOR,
    {_L['Toggle Current _Fold'], function()
      buffer:toggle_fold(buffer:line_from_position(buffer.current_pos))
    end},
    SEPARATOR,
    {_L['Toggle Show In_dent Guides'], function()
      local off = buffer.indentation_guides == 0
      buffer.indentation_guides = off and buffer.IV_LOOKBOTH or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
    {_L['Toggle _Virtual Space'], function()
      local off = buffer.virtual_space_options == 0
      buffer.virtual_space_options = off and buffer.VS_USERACCESSIBLE or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
    SEPARATOR,
    {_L['Zoom _In'], buffer.zoom_in},
    {_L['Zoom _Out'], buffer.zoom_out},
    {_L['_Reset Zoom'], function() buffer.zoom = 0 end}
  },
  {
    title='_Project',
    {_L['_New'],            Proj.new_project},
    {_L['_Open'],           Proj.open_project},
    {_L['Open _Recent...'], Proj.open_recent_project},
    {_L['_Close'],          Proj.close_project},
    SEPARATOR,
    {'Project _Search',     Proj.search_in_files },
    {'Goto _Tag',           Proj.goto_tag},
    {'S_ave position',      Proj.store_current_pos},
    {'_Prev position',      Proj.goto_prev_pos},
    {'Ne_xt position',      Proj.goto_next_pos},
  },
  {
    title = _L['_Help'],
    {_L['Show _Manual'], function() open_page(_HOME..'/doc/manual.html') end},
    {_L['Show _LuaDoc'], function() open_page(_HOME..'/doc/api.html') end},
    SEPARATOR,
    {_L['_About'], function()
      ui.dialogs.msgbox({
        title = 'Textadept', text = _RELEASE, informative_text = _COPYRIGHT,
        icon_file = _HOME..'/core/images/ta_64x64.png'
      })
    end}
  }
}

--replace some menu commands with the corresponding project version
function Proj.change_menu_cmds()
  local menu= textadept.menu.tab_context_menu
  table.insert(menu,2,{'Close Others', Proj.close_others})
  table.insert(menu,3,{"Mark as don't close", Proj.keep_thisbuffer})
  table.insert(menu,4,{_L['Close All'], Proj.onlykeep_projopen})

  if export then
    --Add a sub-menu for EXPORT
    local m_file = proj_menubar[1] --File
    table.insert(m_file, #m_file - 1, SEPARATOR) --before QUIT
    table.insert(m_file, #m_file - 1, {
      title = 'E_xport',
      {'Export to _HTML...', export.to_html}
    })
  end
  if toolbar.html_toolbar_onoff then
    --Add a menu-item for HTML toolbar
    local m_buff = proj_menubar[5] --Buffer
    table.insert(m_buff, #m_buff + 1, SEPARATOR)
    table.insert(m_buff, #m_buff + 1, {'View HTML Tool_Bar', toolbar.html_toolbar_onoff})
  end
  textadept.menu.menubar= proj_menubar --replace menu bar
end
