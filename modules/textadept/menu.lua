-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
actions= {}

local _L = _L
local SEPARATOR = ""

if Util == nil then
  Util = {}
  Util.TA_MAYOR_VER= tonumber(_RELEASE:match('^Textadept (.+)%..+$'))
  Util.LINE_BASE= (Util.TA_MAYOR_VER < 11) and 0 or 1
end

if Util.TA_MAYOR_VER < 11 then
  Util.OK_TEXT= _L['_OK']
  Util.CANCEL_TEXT= _L['_Cancel']
  Util.FILEMENU_TEXT= _L['_File']
  Util.EDITMENU_TEXT= _L['_Edit']
  Util.SELECTMENU_TEXT= _L['_Select']
  Util.SELECTIONMENU_TEXT= _L['Selectio_n']
  Util.SEARCHMENU_TEXT= _L['_Search']
  Util.TOOLSMENU_TEXT= _L['_Tools']
  Util.BOOKMARKMENU_TEXT= _L['_Bookmark']
  Util.QUICKOPENMENU_TEXT= _L['Quick _Open']
  Util.SNIPPETSMENU_TEXT= _L['_Snippets']
  Util.MACROMENU_TEXT= '_Macro'
  Util.BUFFERMENU_TEXT= _L['_Buffer']
  Util.INDENTATIONMENU_TEXT= _L['_Indentation']
  Util.EOLMODEMENU_TEXT= _L['_EOL Mode']
  Util.ENCODINGMENU_TEXT= _L['E_ncoding']
  Util.VIEWMENU_TEXT= _L['_View']
  Util.PROJECTMENU_TEXT= '_Project'
  Util.HELPMENU_TEXT= _L['_Help']
else
  Util.OK_TEXT= _L['OK']
  Util.CANCEL_TEXT= _L['Cancel']
  Util.FILEMENU_TEXT= _L['File']
  Util.EDITMENU_TEXT= _L['Edit']
  Util.SELECTMENU_TEXT= _L['Select']
  Util.SELECTIONMENU_TEXT= _L['Selection']
  Util.SEARCHMENU_TEXT= _L['Search']
  Util.TOOLSMENU_TEXT= _L['Tools']
  Util.BOOKMARKMENU_TEXT= _L['Bookmark']
  Util.QUICKOPENMENU_TEXT= _L['Quick Open']
  Util.SNIPPETSMENU_TEXT= _L['Snippets']
  Util.MACROMENU_TEXT= '_Macro'
  Util.BUFFERMENU_TEXT= _L['Buffer']
  Util.INDENTATIONMENU_TEXT= _L['Indentation']
  Util.EOLMODEMENU_TEXT= _L['EOL Mode']
  Util.ENCODINGMENU_TEXT= _L['Encoding']
  Util.VIEWMENU_TEXT= _L['View']
  Util.PROJECTMENU_TEXT= '_Project'
  Util.HELPMENU_TEXT= _L['Help']
end

function refresh_syntax()
  if Util.TA_MAYOR_VER < 11 then
    buffer:colourise(Util.LINE_BASE, -1)
  else
    buffer:colorize(Util.LINE_BASE, -1)
  end
end

-- Commonly used functions in menu commands.
local sel_enc = textadept.editing.select_enclosed
local enc = textadept.editing.enclose
local function set_indentation(i)
  buffer.tab_width = i
  events.emit(events.UPDATE_UI,0) -- for updating statusbar
  if toolbar then toolbar.setcfg_from_tabwidth() end --update config panel
end
local function set_eol_mode(mode)
  buffer.eol_mode = mode
  buffer:convert_eols(mode)
  events.emit(events.UPDATE_UI,0) -- for updating statusbar
  if toolbar then toolbar.setcfg_from_eolmode() end --update config panel
end
local function set_encoding(encoding)
  buffer:set_encoding(encoding)
  events.emit(events.UPDATE_UI,0) -- for updating statusbar
end

local function tab_key()
  if Util.TA_MAYOR_VER < 11 then --TA10
    if textadept.snippets._insert() == nil then return end
  else --TA11
    if textadept.snippets.insert() == nil then return end
  end
  buffer.tab()
end

local function shift_tab_key()
  if Util.TA_MAYOR_VER < 11 then --TA10
    if textadept.snippets._previous() == nil then return end
  else --TA11
    if textadept.snippets.previous() == nil then return end
  end
  buffer.back_tab()
end
--action's icon (string or function that returns a string) (index = action)
actions.icons= {}

--status() nil or 0=enabled, 1=checked, 2=unchecked, 3=radio-checked, 4=radio-unchecked, +8=disabled +16=first-radio
actions.status= {
  --checks
  ["toggle_view_oel"]=  function() return (buffer.view_eol and 1 or 2) end,
  ["toggle_view_wrap"]= function() return (buffer.wrap_mode == buffer.WRAP_WHITESPACE and 1 or 2) end,
  ["toggle_view_ws"]=   function() return (buffer.view_ws == buffer.WS_VISIBLEALWAYS and 1 or 2) end,
  ["toggle_usetabs"]=   function() return (buffer.use_tabs and 1 or 2) end,
  ["toggle_view_indguides"]= function() return(buffer.indentation_guides == buffer.IV_LOOKBOTH and 1 or 2) end,
  ["toggle_virtualspace"]= function() return(buffer.virtual_space_options == buffer.VS_USERACCESSIBLE and 1 or 2) end,

  --radios
  ["set_tab_2"]= function() return(buffer.tab_width == 2 and 19 or 20) end, --first-radio
  ["set_tab_3"]= function() return(buffer.tab_width == 3 and 3 or 4) end,
  ["set_tab_4"]= function() return(buffer.tab_width == 4 and 3 or 4) end,
  ["set_tab_8"]= function() return(buffer.tab_width == 8 and 3 or 4) end,
  ["set_tab_12"]=function() return(buffer.tab_width == 12 and 3 or 4) end,
  ["set_tab_16"]=function() return(buffer.tab_width == 16 and 3 or 4) end,

  ["set_eol_crlf"]= function() return(buffer.eol_mode == buffer.EOL_CRLF and 19 or 20) end, --first-radio
  ["set_eol_lf"]=   function() return(buffer.eol_mode == buffer.EOL_LF   and 3 or 4) end,

  ["set_enc_utf8"]=  function() return(buffer.encoding == 'UTF-8'      and 19 or 20) end, --first-radio
  ["set_enc_ascii"]= function() return(buffer.encoding == 'ASCII'      and 3 or 4) end,
  ["set_enc_1252"]=  function() return(buffer.encoding == 'CP1252'     and 3 or 4) end,
  ["set_enc_8859"]=  function() return(buffer.encoding == 'ISO-8859-1' and 3 or 4) end,
  ["set_enc_utf16"]= function() return(buffer.encoding == 'UTF-16LE'   and 3 or 4) end,
}

--list of actions used in menus that requiere status update
actions.usedwithstatus= {}

--action's button text (string or function that returns a string) (index = action)
--nil = use menu text without "_"
actions.buttontext= {}

if Util.TA_MAYOR_VER < 11 then
-- [TA VERSION 10] ---
actions.list = {
  --["action_object"]={"menu-text", exec(), ["button text"]}
--FILE
  ["new"]=                  {_L['_New'], buffer.new},
  ["open"]=                 {_L['_Open'], io.open_file},
  ["recent"]=               {_L['Open _Recent...'], io.open_recent_file},
  ["reload"]=               {_L['Re_load'], io.reload_file},
  ["save"]=                 {_L['_Save'], io.save_file},
  ["saveas"]=               {_L['Save _As'], io.save_file_as},
  ["saveall"]=              {_L['Save All'], io.save_all_files},
  ["close"]=                {_L['_Close'], io.close_buffer},
  ["closeall"]=             {_L['Close All'], io.close_all_buffers},
  ["session_load"]=         {_L['Loa_d Session...'], textadept.session.load},
  ["session_save"]=         {_L['Sav_e Session...'], textadept.session.save},
  ["quit"]=                 {_L['_Quit'], quit},

--EDIT
  ["undo"]=                 {_L['_Undo'], buffer.undo},
  ["redo"]=                 {_L['_Redo'], buffer.redo},
  ["cut"]=                  {_L['Cu_t'], buffer.cut},
  ["copy"]=                 {_L['_Copy'], buffer.copy},
  ["copyfilename"]=         {_L['_Copy']..' filename', function () buffer:copy_text( buffer.filename or "") end},
  ["paste"]=                {_L['_Paste'], buffer.paste},
  ["paste_reindent"]=       {'paste _Reindent', function () if textadept.editing.paste_reindent then textadept.editing.paste_reindent() end end},
  ["duplicate_line"]=       {_L['Duplicate _Line'], buffer.line_duplicate},
  ["delete_char"]=          {_L['_Delete'], buffer.clear},
  ["delete_word"]=          {_L['D_elete Word'], function()
      textadept.editing.select_word()
      buffer:delete_back()
    end},
  ["delete_line"]=          {'Delete line', buffer.line_delete},
  ["selectall"]=            {_L['Select _All'], buffer.select_all},
  ["match_brace"]=          {_L['_Match Brace'], function()
      local match_pos = buffer:brace_match(buffer.current_pos, 0)
      if match_pos ~= -1 then buffer:goto_pos(match_pos) end
    end},
  ["complete_word"]=        {_L['Complete _Word'], function()
      textadept.editing.autocomplete('word')
    end},
  ["highlight_word"]=       {_L['_Highlight Word'], textadept.editing.highlight_word},
  ["toggle_comment"]=       {_L['Toggle _Block Comment'], textadept.editing.block_comment},
  ["transpose_chars"]=      {_L['T_ranspose Characters'], textadept.editing.transpose_chars},
  ["join_lines"]=           {_L['_Join Lines'], textadept.editing.join_lines},
  ["filterthrough"]=        {_L['_Filter Through'], function()
      if ui.command_entry.run then
        ui.command_entry.run(textadept.editing.filter_through, 'bash')
      else
        ui.command_entry.enter_mode('filter_through', 'bash') --TA10.6
      end
    end},

--EDIT + SELECT
  ["sel_matchbrace"]=       {_L['Select between _Matching Delimiters'], sel_enc },
  ["sel_betweenxmltag"]=    {_L['Select between _XML Tags'], function() sel_enc('>', '<') end},
  ["sel_xmltag"]=           {_L['Select in XML _Tag'], function() sel_enc('<', '>') end},
  ["sel_word"]=             {_L['Select _Word'], textadept.editing.select_word},
  ["sel_line"]=             {_L['Select _Line'], textadept.editing.select_line},
  ["sel_paragraph"]=        {_L['Select Para_graph'], textadept.editing.select_paragraph},

--EDIT + SELECTION
  ["upper_sel"]=            {_L['_Upper Case Selection'], buffer.upper_case},
  ["lower_sel"]=            {_L['_Lower Case Selection'], buffer.lower_case},
  ["enclose_xmltags"]=      {_L['Enclose as _XML Tags'], function()
      buffer:begin_undo_action()
      enc('<', '>')
      local s, e = buffer.current_pos, buffer.current_pos
      while buffer.char_at[s - 1] ~= 60 do s = s - 1 end -- '<'
      buffer:insert_text(-1, '</' .. buffer:text_range(s, e))
      buffer:end_undo_action()
    end},
  ["enclose_xmltag"]=       {_L['Enclose as Single XML _Tag'], function() enc('<', ' />') end},
  ["enclose_singlequotes"]= {_L['Enclose in Single _Quotes'], function() enc("'", "'") end},
  ["enclose_doublequotes"]= {_L['Enclose in _Double Quotes'], function() enc('"', '"') end},
  ["enclose_parentheses"]=  {_L['Enclose in _Parentheses'], function() enc('(', ')') end},
  ["enclose_brackets"]=     {_L['Enclose in _Brackets'], function() enc('[', ']') end},
  ["enclose_braces"]=       {_L['Enclose in B_races'], function() enc('{', '}') end},
  ["moveup_sellines"]=      {_L['_Move Selected Lines Up'], buffer.move_selected_lines_up},
  ["movedown_sellines"]=    {_L['Move Selected Lines Do_wn'], buffer.move_selected_lines_down},

--SEARCH
  ["find"]=                 {_L['_Find'], function()
      ui.find.in_files = false
      ui.find.focus()
    end},
  ["find_next"]=            {_L['Find _Next'], ui.find.find_next},
  ["find_prev"]=            {_L['Find _Previous'], ui.find.find_prev},
  ["replace"]=              {_L['_Replace'], ui.find.replace},
  ["replaceall"]=           {_L['Replace _All'], ui.find.replace_all},
  ["find_increment"]=       {_L['Find _Incremental'], ui.find.find_incremental},
  ["find_infiles"]=         {_L['Find in Fi_les'], function()
      ui.find.in_files = true
      ui.find.focus()
    end},
  ["find_replace"]=         {_L['_Replace'], function()
      ui.find.in_files = false
      ui.find.focus()
    end},
  ["next_filefound"]=       {_L['Goto Nex_t File Found'], function()
      ui.find.goto_file_found(false, true)
    end},
  ["prev_filefound"]=       {_L['Goto Previou_s File Found'], function()
      ui.find.goto_file_found(false, false)
    end},
  ["goto_line"]=            {_L['_Jump to'], textadept.editing.goto_line},

--TOOLS
  ["toggle_commandentry"]=  {_L['Command _Entry'], function()
      if ui.command_entry.run then ui.command_entry.run()
      else ui.command_entry.enter_mode('lua_command', 'lua') end --TA10.6
    end},
  ["run_command"]=          {_L['Select Co_mmand'], function() actions.select_command() end},
  ["run"]=                  {_L['_Run'], textadept.run.run},
  ["compile"]=              {_L['_Compile'], textadept.run.compile},
  ["set_runargs"]=          {_L['Set _Arguments...'], function()
      if not buffer.filename then return end
      local run_commands = textadept.run.run_commands
      local compile_commands = textadept.run.compile_commands
      local base_commands, utf8_args = {}, {}
      for i, commands in ipairs{run_commands, compile_commands} do
        -- Compare the base run/compile command with the one for the current
        -- file. The difference is any additional arguments set previously.
        base_commands[i] = commands[buffer.filename:match('[^.]+$')] or
                           commands[buffer:get_lexer()] or ''
        local current_command = commands[buffer.filename] or ''
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
        commands[buffer.filename] = string.format('%s %s', base_commands[i],
          utf8_args[i]:iconv(_CHARSET, 'UTF-8'))
      end
    end},
  ["build"]=                {_L['Buil_d'], textadept.run.build},
  ["stop_run"]=             {_L['S_top'], textadept.run.stop},
  ["next_error"]=           {_L['_Next Error'], function() textadept.run.goto_error(false, true) end},
  ["prev_error"]=           {_L['_Previous Error'], function()
      textadept.run.goto_error(false, false)
    end},
  ["complete_symbol"]=      {_L['_Complete Symbol'], function()
      textadept.editing.autocomplete(buffer:get_lexer(true))
    end},
  ["show_documentation"]=   {_L['Show _Documentation'], textadept.editing.show_documentation},
  ["show_style"]=           {_L['Show St_yle'], function()
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
    end},

--TOOLS + BOOKMARK
  ["toggle_bookmark"]=      {_L['_Toggle Bookmark'], textadept.bookmarks.toggle},
  ["clear_bookmarks"]=      {_L['_Clear Bookmarks'], textadept.bookmarks.clear},
  ["next_bookmark"]=        {_L['_Next Bookmark'], function()
      textadept.bookmarks.goto_mark(true)
    end},
  ["prev_bookmark"]=        {_L['_Previous Bookmark'], function()
      textadept.bookmarks.goto_mark(false)
    end},
  ["goto_bookmark"]=        {_L['_Goto Bookmark...'], textadept.bookmarks.goto_mark},

--TOOLS + QUICK OPEN
  ["open_userhome"]=        {_L['Quickly Open _User Home'], function() io.quick_open(_USERHOME) end},
  ["open_textadepthome"]=   {_L['Quickly Open _Textadept Home'], function() io.quick_open(_HOME) end},
  ["open_currentdir"]=      {_L['Quickly Open _Current Directory'], function()
        if buffer.filename then
          io.quick_open(buffer.filename:match('^(.+)[/\\]'))
        end
      end},
  ["quick_open_projectdir"]= {_L['Quickly Open Current _Project'], io.quick_open},

--TOOLS + SNIPPETS
  ["snippet_select"]=       {_L['_Insert Snippet...'], textadept.snippets._select },
  ["expand_snippet"]=       {_L['_Expand Snippet/Next Placeholder'], textadept.snippets._insert },
  ["prev_snipplaceholder"]= {_L['_Previous Snippet Placeholder'], textadept.snippets._previous },
  ["cancel_snippet"]=       {_L['_Cancel Snippet'], textadept.snippets._cancel_current },

--BUFFER
  ["next_buffer"]=          {_L['_Next Buffer'], function() view:goto_buffer(1) end},
  ["prev_buffer"]=          {_L['_Previous Buffer'], function() view:goto_buffer(-1) end},
  ["switch_buffer"]=        {_L['_Switch to Buffer...'], ui.switch_buffer},
  ["toggle_view_oel"]=      {_L['Toggle View _EOL'], function() --check
      buffer.view_eol = not buffer.view_eol
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["toggle_view_wrap"]=     {_L['Toggle _Wrap Mode'], function() --check
      local first_visible_line = buffer.first_visible_line
      local display_line = buffer:visible_from_doc_line(first_visible_line)
      buffer.wrap_mode = buffer.wrap_mode == 0 and buffer.WRAP_WHITESPACE or 0
      buffer:line_scroll(0, first_visible_line - display_line)
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["toggle_view_ws"]=       {_L['Toggle View White_space'], function() --check
      buffer.view_ws = buffer.view_ws == 0 and buffer.WS_VISIBLEALWAYS or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["select_lexer"]=         {_L['Select _Lexer...'], function()
      textadept.file_types.select_lexer()
      if toolbar then toolbar.update_lexerdefaults() end --update config panel
    end},
--["refresh_syntax"]=       {_L['_Refresh Syntax Highlighting'], refresh_syntax},

--BUFFER + INDENTATION
  ["set_tab_2"]=            {_L['Tab width: _2'], function() set_indentation(2) end}, --radio group
  ["set_tab_3"]=            {_L['Tab width: _3'], function() set_indentation(3) end}, --radio
  ["set_tab_4"]=            {_L['Tab width: _4'], function() set_indentation(4) end}, --radio
  ["set_tab_8"]=            {_L['Tab width: _8'], function() set_indentation(8) end}, --radio
  ["set_tab_12"]=           {'Tab width: _12',function() set_indentation(12) end}, --radio
  ["set_tab_16"]=           {'Tab width: 1_6',function() set_indentation(16) end}, --radio
  ["toggle_usetabs"]=       {_L['_Toggle Use Tabs'], function() --check
      buffer.use_tabs = not buffer.use_tabs
      events.emit(events.UPDATE_UI,0) -- for updating statusbar
      if toolbar then toolbar.setcfg_from_usetabs() end --update config panel
    end},
  ["convert_indentation"]=  {_L['_Convert Indentation'], textadept.editing.convert_indentation},

--BUFFER + EOL MODE
  ["set_eol_crlf"]=         {_L['CRLF'], function() set_eol_mode(buffer.EOL_CRLF) end},         --radio group
  ["set_eol_lf"]=           {_L['LF'], function() set_eol_mode(buffer.EOL_LF) end},             --radio

--BUFFER + ENCODING
  ["set_enc_utf8"]=         {_L['_UTF-8 Encoding'], function() set_encoding('UTF-8') end},            --radio group
  ["set_enc_ascii"]=        {_L['_ASCII Encoding'], function() set_encoding('ASCII') end},            --radio
  ["set_enc_8859"]=         {'_ISO-8859-1 Encoding',function() set_encoding('ISO-8859-1') end},  --radio
  ["set_enc_1252"]=         {_L['_CP-1252 Encoding'], function() set_encoding('CP1252') end},  --radio
  ["set_enc_utf16"]=        {_L['UTF-1_6 Encoding'], function() set_encoding('UTF-16LE') end},        --radio

--VIEW
  ["next_view"]=            {_L['_Next View'], function() ui.goto_view(1) end},
  ["prev_view"]=            {_L['_Previous View'], function() ui.goto_view(-1) end},
  ["split_view_h"]=         {_L['Split View _Horizontal'], function() view:split() end},
  ["split_view_v"]=         {_L['Split View _Vertical'], function() view:split(true) end},
  ["unsplit_view"]=         {_L['_Unsplit View'], function() view:unsplit() end},
  ["unsplit_allviews"]=     {_L['Unsplit _All Views'], function() while view:unsplit() do end end},
  ["grow_view"]=            {_L['_Grow View'], function()
      if view.size then view.size = view.size + buffer:text_height(0) end
    end},
  ["shrink_view"]=          {_L['Shrin_k View'], function()
      if view.size then view.size = view.size - buffer:text_height(0) end
    end},
  ["toggle_fold"]=          {_L['Toggle Current _Fold'], function()
      buffer:toggle_fold(buffer:line_from_position(buffer.current_pos))
    end},
  ["toggle_view_indguides"]={_L['Toggle Show In_dent Guides'], function() --check
      local off = buffer.indentation_guides == 0
      buffer.indentation_guides = off and buffer.IV_LOOKBOTH or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["toggle_virtualspace"]=  {_L['Toggle _Virtual Space'], function() --check
      local off = buffer.virtual_space_options == 0
      buffer.virtual_space_options = off and buffer.VS_USERACCESSIBLE or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["zoom_in"]=              {_L['Zoom _In'], buffer.zoom_in},
  ["zoom_out"]=             {_L['Zoom _Out'], buffer.zoom_out},
  ["reset_zoom"]=           {_L['_Reset Zoom'], function() buffer.zoom = 0 end},

--HELP
  ["show_manual"]=          {_L['Show _Manual'], function() Util.os_open_page(_HOME..'/doc/manual.html') end},
  ["show_luadoc"]=          {_L['Show _LuaDoc'], function() Util.os_open_page(_HOME..'/doc/api.html') end},
  ["about"]=                {_L['_About'], function()
      ui.dialogs.msgbox({
        title = 'Textadept', text = _RELEASE, informative_text = _COPYRIGHT,
        icon_file = _HOME..'/core/images/ta_64x64.png'
      })
    end},

--MOVE CURSOR
  ["left"]=                 {'Move cursor: left',       buffer.char_left},
  ["right"]=                {'Move cursor: right',      buffer.char_right},
  ["up"]=                   {'Move cursor: up',         buffer.line_up},
  ["down"]=                 {'Move cursor: down',       buffer.line_down},
  ["home"]=                 {'Move cursor: home',       buffer.vc_home},
  ["end"]=                  {'Move cursor: end',        buffer.line_end},
  ["word_left"]=            {'Move cursor: word left',  buffer.word_left},
  ["word_right"]=           {'Move cursor: word right', buffer.word_right},
  ["tab"]=                  {'Tab/Indent',              buffer.tab},
  ["back_tab"]=             {'Shift+Tab/Unindent',      buffer.back_tab},
  ["tab_key"]=              {'Tab/Indent/Expand Snippet/Next Placeholder',           tab_key},
  ["shift_tab_key"]=        {'Shift+Tab/Unindent/Previous snippet placeholder',      shift_tab_key},
  ["doc_start"]=            {'Move cursor: document start', buffer.document_start},
  ["doc_end"]=              {'Move cursor: document end', buffer.document_end},
  ["page_up"]=              {'Move cursor: page up',    buffer.page_up},
  ["page_down"]=            {'Move cursor: page down',  buffer.page_down},
--SELECTION
  ["sel_left"]=             {'Extend selection: left',          buffer.char_left_extend},
  ["sel_right"]=            {'Extend selection: right',         buffer.char_right_extend},
  ["sel_up"]=               {'Extend selection: up',            buffer.line_up_extend},
  ["sel_down"]=             {'Extend selection: down',          buffer.line_down_extend},
  ["sel_home"]=             {'Extend selection: home',          buffer.vc_home_extend},
  ["sel_end"]=              {'Extend selection: end',           buffer.line_end_extend},
  ["sel_word_left"]=        {'Extend selection: word left',     buffer.word_left_extend},
  ["sel_word_right"]=       {'Extend selection: word right',    buffer.word_right_extend},
  ["sel_doc_start"]=        {'Extend selection: document start',buffer.document_start_extend},
  ["sel_doc_end"]=          {'Extend selection: document end',  buffer.document_end_extend},
  ["sel_page_up"]=          {'Extend selection: page up',       buffer.page_up_extend},
  ["sel_page_down"]=        {'Extend selection: page down',     buffer.page_down_extend},
--RECTANGULAR SELECTION
  ["rsel_left"]=            {'Extend rect selection: left',     buffer.char_left_rect_extend},
  ["rsel_right"]=           {'Extend rect selection: right',    buffer.char_right_rect_extend},
  ["rsel_up"]=              {'Extend rect selection: up',       buffer.line_up_rect_extend},
  ["rsel_down"]=            {'Extend rect selection: down',     buffer.line_down_rect_extend},
  ["rsel_home"]=            {'Extend rect selection: home',     buffer.vc_home_rect_extend},
  ["rsel_end"]=             {'Extend rect selection: end',      buffer.line_end_rect_extend},
  ["rsel_page_up"]=         {'Extend rect selection: page up',  buffer.page_up_rect_extend},
  ["rsel_page_down"]=       {'Extend rect selection: page down',buffer.page_down_rect_extend},
--DELETE
  ["del_back"]=             {'Delete: back char',       buffer.delete_back},
  ["del"]=                  {'Delete: char',            buffer.clear},
  ["del_word_left"]=        {'Delete: word left',       buffer.del_word_left},
  ["del_word_right"]=       {'Delete: word right',      buffer.del_word_right},
}

else
-- [TA VERSION 11] ---
actions.list = {
  --["action_object"]={"menu-text", exec(), ["button text"]}
--FILE
  ["new"]=                  {_L['New'], buffer.new},
  ["open"]=                 {_L['Open'], io.open_file},
  ["recent"]=               {_L['Open Recent...'], io.open_recent_file},
  ["reload"]=               {_L['Reload'], function () buffer:reload() end},
  ["save"]=                 {_L['Save'], function () buffer:save() end},
  ["saveas"]=               {_L['Save As'], function () io.save_file_as() end},
  ["saveall"]=              {_L['Save All'], io.save_all_files},
  ["close"]=                {_L['Close'], function () buffer:close() end},
  ["closeall"]=             {_L['Close All'], io.close_all_buffers},
  ["session_load"]=         {_L['Load Session...'], textadept.session.load},
  ["session_save"]=         {_L['Save Session...'], textadept.session.save},
  ["quit"]=                 {_L['Quit'], quit},

--EDIT
  ["undo"]=                 {_L['Undo'], buffer.undo},
  ["redo"]=                 {_L['Redo'], buffer.redo},
  ["cut"]=                  {_L['Cut'], buffer.cut},
  ["copy"]=                 {_L['Copy'], buffer.copy},
  ["copyfilename"]=         {_L['Copy']..' filename', function () buffer:copy_text( buffer.filename or "") end},
  ["paste"]=                {_L['Paste'], buffer.paste},
  ["paste_reindent"]=       {'paste Reindent', function () if textadept.editing.paste_reindent then textadept.editing.paste_reindent() end end},
  ["duplicate_line"]=       {_L['Duplicate Line'], buffer.line_duplicate},
  ["delete_char"]=          {_L['Delete'], buffer.clear},
  ["delete_word"]=          {_L['Delete Word'], function()
      textadept.editing.select_word()
      buffer:delete_back()
    end},
  ["delete_line"]=          {'Delete line', buffer.line_delete},
  ["selectall"]=            {_L['Select All'], buffer.select_all},
  ["match_brace"]=          {_L['Match Brace'], function()
      local match_pos = buffer:brace_match(buffer.current_pos, 0)
      if match_pos ~= -1 then buffer:goto_pos(match_pos) end
    end},
  ["complete_word"]=        {_L['Complete Word'], function()
      textadept.editing.autocomplete('word')
    end},
  --["highlight_word"]=       {'Highlight Word', textadept.editing.highlight_word}, --removed from TA11 menu
  ["toggle_comment"]=       {_L['Toggle Block Comment'], textadept.editing.toggle_comment},
  ["transpose_chars"]=      {_L['Transpose Characters'], textadept.editing.transpose_chars},
  ["join_lines"]=           {_L['Join Lines'], textadept.editing.join_lines},
  ["filterthrough"]=        {_L['Filter Through'], function() ui.command_entry.run(textadept.editing.filter_through, 'bash') end},

--EDIT + SELECT
  ["sel_matchbrace"]=       {_L['Select between Matching Delimiters'], sel_enc},
  ["sel_betweenxmltag"]=    {_L['Select between XML Tags'], function() sel_enc('>', '<') end},
  ["sel_xmltag"]=           {_L['Select in XML Tag'], function() sel_enc('<', '>') end},
  ["sel_word"]=             {_L['Select Word'], textadept.editing.select_word},
  ["sel_line"]=             {_L['Select Line'], textadept.editing.select_line},
  ["sel_paragraph"]=        {_L['Select Paragraph'], textadept.editing.select_paragraph},

--EDIT + SELECTION
  ["upper_sel"]=            {_L['Upper Case Selection'], buffer.upper_case},
  ["lower_sel"]=            {_L['Lower Case Selection'], buffer.lower_case},
  ["enclose_xmltags"]=      {_L['Enclose as XML Tags'], function()
      buffer:begin_undo_action()
      enc('<', '>')
      local s, e = buffer.current_pos, buffer.current_pos
      while buffer.char_at[s - 1] ~= 60 do s = s - 1 end -- '<'
      buffer:insert_text(-1, '</' .. buffer:text_range(s, e))
      buffer:end_undo_action()
    end},
  ["enclose_xmltag"]=       {_L['Enclose as Single XML Tag'], function() enc('<', ' />') end},
  ["enclose_singlequotes"]= {_L['Enclose in Single Quotes'], function() enc("'", "'") end},
  ["enclose_doublequotes"]= {_L['Enclose in Double Quotes'], function() enc('"', '"') end},
  ["enclose_parentheses"]=  {_L['Enclose in Parentheses'], function() enc('(', ')') end},
  ["enclose_brackets"]=     {_L['Enclose in Brackets'], function() enc('[', ']') end},
  ["enclose_braces"]=       {_L['Enclose in Braces'], function() enc('{', '}') end},
  ["moveup_sellines"]=      {_L['Move Selected Lines Up'], buffer.move_selected_lines_up},
  ["movedown_sellines"]=    {_L['Move Selected Lines Down'], buffer.move_selected_lines_down},

--SEARCH
  ["find"]=                 {_L['Find'], function()
      ui.find.focus{in_files = false, incremental = false}
    end},
  ["find_next"]=            {_L['Find Next'], ui.find.find_next},
  ["find_prev"]=            {_L['Find Previous'], ui.find.find_prev},
  ["replace"]=              {_L['Replace'], ui.find.replace},
  ["replaceall"]=           {_L['Replace All'], ui.find.replace_all},
  ["find_increment"]=       {_L['Find Incremental'], function()
      ui.find.focus{in_files = false, incremental = true}
    end},
  ["find_infiles"]=         {_L['Find in Files'], function()
      ui.find.focus{in_files = true, incremental = false}
    end},
  ["find_replace"]=         {_L['Replace'], function()
      ui.find.in_files = false
      ui.find.focus()
    end},
  ["next_filefound"]=       {_L['Goto Next File Found'], function()
      ui.find.goto_file_found(false, true)
    end},
  ["prev_filefound"]=       {_L['Goto Previous File Found'], function()
      ui.find.goto_file_found(false, false)
    end},
  ["goto_line"]=            {_L['Jump to'], textadept.editing.goto_line},

--TOOLS
  ["toggle_commandentry"]=  {_L['Command Entry'], function()
      if ui.command_entry.run then ui.command_entry.run()
      else ui.command_entry.enter_mode('lua_command', 'lua') end --TA10.6
    end},
  ["run_command"]=          {_L['Select Command'], function() actions.select_command() end},
  ["run"]=                  {_L['Run'], textadept.run.run},
  ["compile"]=              {_L['Compile'], textadept.run.compile},
  ["set_runargs"]=          {_L['Set Arguments...'], function()
      if not buffer.filename then return end
      local run_commands = textadept.run.run_commands
      local compile_commands = textadept.run.compile_commands
      local base_commands, utf8_args = {}, {}
      for i, commands in ipairs{run_commands, compile_commands} do
        -- Compare the base run/compile command with the one for the current
        -- file. The difference is any additional arguments set previously.
        base_commands[i] = commands[buffer.filename:match('[^.]+$')] or
                           commands[buffer:get_lexer()] or ''
        local current_command = commands[buffer.filename] or ''
        local args = current_command:sub(#base_commands[i] + 2)
        utf8_args[i] = args:iconv('UTF-8', _CHARSET)
      end
      local button, utf8_args = ui.dialogs.inputbox{
        title = _L['Set Arguments...']:gsub('_', ''), informative_text = {
          _L['Command line arguments'], _L['For Run:'], _L['For Compile:']
        }, text = utf8_args, width = not CURSES and 400 or nil
      }
      if button ~= 1 then return end
      for i, commands in ipairs{run_commands, compile_commands} do
        -- Add the additional arguments to the base run/compile command and set
        -- the new command to be the one used for the current file.
        commands[buffer.filename] = string.format('%s %s', base_commands[i],
          utf8_args[i]:iconv(_CHARSET, 'UTF-8'))
      end
    end},
  ["build"]=                {_L['Build'], textadept.run.build},
  ["stop_run"]=             {_L['Stop'], textadept.run.stop},
  ["next_error"]=           {_L['Next Error'], function() textadept.run.goto_error(false, true) end},
  ["prev_error"]=           {_L['Previous Error'], function()
      textadept.run.goto_error(false, false)
    end},
  ["complete_symbol"]=      {_L['Complete Symbol'], function()
      textadept.editing.autocomplete(buffer:get_lexer(true))
    end},
  ["show_documentation"]=   {_L['Show Documentation'], textadept.editing.show_documentation},
  ["show_style"]=           {_L['Show Style'], function()
      local char = buffer:text_range(buffer.current_pos,
                                     buffer:position_after(buffer.current_pos))
      if char == '' then return end -- end of buffer
      local bytes = string.rep(' 0x%X', #char):format(char:byte(1, #char))
      local style = buffer.style_at[buffer.current_pos]
      local text = string.format(
        "'%s' (U+%04X:%s)\n%s %s\n%s %s (%d)", char, utf8.codepoint(char),
        bytes, _L['Lexer'], buffer:get_lexer(true), _L['Style'],
        buffer:name_of_style(style), style)
      buffer:call_tip_show(buffer.current_pos, text)
    end},

--TOOLS + BOOKMARK
  ["toggle_bookmark"]=      {_L['Toggle Bookmark'], textadept.bookmarks.toggle},
  ["clear_bookmarks"]=      {_L['Clear Bookmarks'], textadept.bookmarks.clear},
  ["next_bookmark"]=        {_L['Next Bookmark'], function()
      textadept.bookmarks.goto_mark(true)
    end},
  ["prev_bookmark"]=        {_L['Previous Bookmark'], function()
      textadept.bookmarks.goto_mark(false)
    end},
  ["goto_bookmark"]=        {_L['Goto Bookmark...'], textadept.bookmarks.goto_mark},

--TOOLS + QUICK OPEN
  ["open_userhome"]=        {_L['Quickly Open User Home'], function() io.quick_open(_USERHOME) end},
  ["open_textadepthome"]=   {_L['Quickly Open Textadept Home'], function() io.quick_open(_HOME) end},
  ["open_currentdir"]=      {_L['Quickly Open Current Directory'], function()
        if buffer.filename then
          io.quick_open(buffer.filename:match('^(.+)[/\\]'))
        end
      end},
  ["quick_open_projectdir"]= {_L['Quickly Open Current Project'], io.quick_open},

--TOOLS + SNIPPETS
  ["snippet_select"]=       {_L['Insert Snippet...'], textadept.snippets.select},
  ["expand_snippet"]=       {_L['Expand Snippet/Next Placeholder'], textadept.snippets.insert},
  ["prev_snipplaceholder"]= {_L['Previous Snippet Placeholder'], textadept.snippets.previous},
  ["cancel_snippet"]=       {_L['Cancel Snippet'], textadept.snippets.cancel_current},
  ["complete_trigger"]=     {_L['Complete Trigger Word'], function() textadept.editing.autocomplete('snippets') end},

--BUFFER
  ["next_buffer"]=          {_L['Next Buffer'], function() view:goto_buffer(1) end},
  ["prev_buffer"]=          {_L['Previous Buffer'], function() view:goto_buffer(-1) end},
  ["switch_buffer"]=        {_L['Switch to Buffer...'], ui.switch_buffer},
  ["toggle_view_oel"]=      {'Toggle View EOL', function() --check
      buffer.view_eol = not buffer.view_eol
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["toggle_view_wrap"]=     {_L['Toggle Wrap Mode'], function() --check
      local first_visible_line = buffer.first_visible_line
      local display_line = buffer:visible_from_doc_line(first_visible_line)
      buffer.wrap_mode = buffer.wrap_mode == 0 and buffer.WRAP_WHITESPACE or 0
      buffer:line_scroll(0, first_visible_line - display_line)
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["toggle_view_ws"]=       {_L['Toggle View Whitespace'], function() --check
      buffer.view_ws = buffer.view_ws == 0 and buffer.WS_VISIBLEALWAYS or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["select_lexer"]=         {_L['Select Lexer...'], function()
      textadept.file_types.select_lexer()
      if toolbar then toolbar.update_lexerdefaults() end --update config panel
    end},
--["refresh_syntax"]=       {_L['Refresh Syntax Highlighting'], refresh_syntax},

--BUFFER + INDENTATION
  ["set_tab_2"]=            {_L['Tab width: 2'], function() set_indentation(2) end}, --radio group
  ["set_tab_3"]=            {_L['Tab width: 3'], function() set_indentation(3) end}, --radio
  ["set_tab_4"]=            {_L['Tab width: 4'], function() set_indentation(4) end}, --radio
  ["set_tab_8"]=            {_L['Tab width: 8'], function() set_indentation(8) end}, --radio
  ["set_tab_12"]=           {'Tab width: _12',function() set_indentation(12) end}, --radio
  ["set_tab_16"]=           {'Tab width: 1_6',function() set_indentation(16) end}, --radio
  ["toggle_usetabs"]=       {_L['Toggle Use Tabs'], function() --check
      buffer.use_tabs = not buffer.use_tabs
      events.emit(events.UPDATE_UI,0) -- for updating statusbar
      if toolbar then toolbar.setcfg_from_usetabs() end --update config panel
    end},
  ["convert_indentation"]=  {_L['Convert Indentation'], textadept.editing.convert_indentation},

--BUFFER + EOL MODE
  ["set_eol_crlf"]=         {_L['CRLF'], function() set_eol_mode(buffer.EOL_CRLF) end},         --radio group
  ["set_eol_lf"]=           {_L['LF'], function() set_eol_mode(buffer.EOL_LF) end},             --radio

--BUFFER + ENCODING
  ["set_enc_utf8"]=         {_L['UTF-8 Encoding'], function() set_encoding('UTF-8') end},            --radio group
  ["set_enc_ascii"]=        {_L['ASCII Encoding'], function() set_encoding('ASCII') end},            --radio
  ["set_enc_8859"]=         {'_ISO-8859-1 Encoding',function() set_encoding('ISO-8859-1') end},  --radio
  ["set_enc_1252"]=         {_L['CP-1252 Encoding'], function() set_encoding('CP1252') end},  --radio
  ["set_enc_utf16"]=        {_L['UTF-16 Encoding'], function() set_encoding('UTF-16LE') end},        --radio

--VIEW
  ["next_view"]=            {_L['Next View'], function() ui.goto_view(1) end},
  ["prev_view"]=            {_L['Previous View'], function() ui.goto_view(-1) end},
  ["split_view_h"]=         {_L['Split View Horizontal'], function() view:split() end},
  ["split_view_v"]=         {_L['Split View Vertical'], function() view:split(true) end},
  ["unsplit_view"]=         {_L['Unsplit View'], function() view:unsplit() end},
  ["unsplit_allviews"]=     {_L['Unsplit All Views'], function() while view:unsplit() do end end},
  ["grow_view"]=            {_L['Grow View'], function()
      if view.size then view.size = view.size + buffer:text_height(1) end
    end},
  ["shrink_view"]=          {_L['Shrink View'], function()
      if view.size then view.size = view.size - buffer:text_height(1) end
    end},
  ["toggle_fold"]=          {_L['Toggle Current Fold'], function()
      buffer:toggle_fold(buffer:line_from_position(buffer.current_pos))
    end},
  ["toggle_view_indguides"]={_L['Toggle Show Indent Guides'], function() --check
      local off = buffer.indentation_guides == 0
      buffer.indentation_guides = off and buffer.IV_LOOKBOTH or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["toggle_virtualspace"]=  {_L['Toggle Virtual Space'], function() --check
      local off = buffer.virtual_space_options == 0
      buffer.virtual_space_options = off and buffer.VS_USERACCESSIBLE or 0
      if toolbar then toolbar.setcfg_from_view_checks() end --update config panel
    end},
  ["zoom_in"]=              {_L['Zoom In'], buffer.zoom_in},
  ["zoom_out"]=             {_L['Zoom Out'], buffer.zoom_out},
  ["reset_zoom"]=           {_L['Reset Zoom'], function() buffer.zoom = 0 end},

--HELP
  ["show_manual"]=          {_L['Show Manual'], function() Util.os_open_page(_HOME .. '/docs/manual.html') end},
  ["show_luadoc"]=          {_L['Show LuaDoc'], function() Util.os_open_page(_HOME .. '/docs/api.html') end},
  ["about"]=                {_L['About'], function()
      ui.dialogs.msgbox{
        title = 'Textadept', text = _RELEASE, informative_text = _COPYRIGHT,
        icon_file = _HOME .. '/core/images/ta_64x64.png'
      }
    end},

--MOVE CURSOR
  ["left"]=                 {'Move cursor: left',       buffer.char_left},
  ["right"]=                {'Move cursor: right',      buffer.char_right},
  ["up"]=                   {'Move cursor: up',         buffer.line_up},
  ["down"]=                 {'Move cursor: down',       buffer.line_down},
  ["home"]=                 {'Move cursor: home',       buffer.vc_home},
  ["end"]=                  {'Move cursor: end',        buffer.line_end},
  ["word_left"]=            {'Move cursor: word left',  buffer.word_left},
  ["word_right"]=           {'Move cursor: word right', buffer.word_right},
  ["tab"]=                  {'Tab/Indent',              buffer.tab},
  ["back_tab"]=             {'Shift+Tab/Unindent',      buffer.back_tab},
  ["tab_key"]=              {'Tab/Indent/Expand Snippet/Next Placeholder',           tab_key},
  ["shift_tab_key"]=        {'Shift+Tab/Unindent/Previous snippet placeholder',      shift_tab_key},
  ["doc_start"]=            {'Move cursor: document start', buffer.document_start},
  ["doc_end"]=              {'Move cursor: document end', buffer.document_end},
  ["page_up"]=              {'Move cursor: page up',    buffer.page_up},
  ["page_down"]=            {'Move cursor: page down',  buffer.page_down},
--SELECTION
  ["sel_left"]=             {'Extend selection: left',          buffer.char_left_extend},
  ["sel_right"]=            {'Extend selection: right',         buffer.char_right_extend},
  ["sel_up"]=               {'Extend selection: up',            buffer.line_up_extend},
  ["sel_down"]=             {'Extend selection: down',          buffer.line_down_extend},
  ["sel_home"]=             {'Extend selection: home',          buffer.vc_home_extend},
  ["sel_end"]=              {'Extend selection: end',           buffer.line_end_extend},
  ["sel_word_left"]=        {'Extend selection: word left',     buffer.word_left_extend},
  ["sel_word_right"]=       {'Extend selection: word right',    buffer.word_right_extend},
  ["sel_doc_start"]=        {'Extend selection: document start',buffer.document_start_extend},
  ["sel_doc_end"]=          {'Extend selection: document end',  buffer.document_end_extend},
  ["sel_page_up"]=          {'Extend selection: page up',       buffer.page_up_extend},
  ["sel_page_down"]=        {'Extend selection: page down',     buffer.page_down_extend},
--RECTANGULAR SELECTION
  ["rsel_left"]=            {'Extend rect selection: left',     buffer.char_left_rect_extend},
  ["rsel_right"]=           {'Extend rect selection: right',    buffer.char_right_rect_extend},
  ["rsel_up"]=              {'Extend rect selection: up',       buffer.line_up_rect_extend},
  ["rsel_down"]=            {'Extend rect selection: down',     buffer.line_down_rect_extend},
  ["rsel_home"]=            {'Extend rect selection: home',     buffer.vc_home_rect_extend},
  ["rsel_end"]=             {'Extend rect selection: end',      buffer.line_end_rect_extend},
  ["rsel_page_up"]=         {'Extend rect selection: page up',  buffer.page_up_rect_extend},
  ["rsel_page_down"]=       {'Extend rect selection: page down',buffer.page_down_rect_extend},
--DELETE
  ["del_back"]=             {'Delete: back char',       buffer.delete_back},
  ["del"]=                  {'Delete: char',            buffer.clear},
  ["del_word_left"]=        {'Delete: word left',       buffer.del_word_left},
  ["del_word_right"]=       {'Delete: word right',      buffer.del_word_right},
}
end

---
-- The main menubar
---
actions.menubar = {
  {
    title = Util.FILEMENU_TEXT,
    {"new","open","recent","reload","save","saveas","saveall",SEPARATOR,
     "close","closeall",SEPARATOR,
     "session_load","session_save",SEPARATOR,
     "quit"}
  },
  {
    title = Util.EDITMENU_TEXT,
    {"undo","redo",SEPARATOR,
     "cut","copy","paste","duplicate_line","delete_char","delete_word","delete_line","selectall","copyfilename",SEPARATOR,
     "match_brace","complete_word","toggle_comment","transpose_chars",
     "join_lines","filterthrough"},
    {
      title = Util.SELECTMENU_TEXT,
      {"sel_matchbrace","sel_betweenxmltag","sel_xmltag","sel_word","sel_line","sel_paragraph"} --TA10
    },
    {
      title = Util.SELECTIONMENU_TEXT,
      {"upper_sel","lower_sel",SEPARATOR,
       "enclose_xmltags","enclose_xmltag","enclose_singlequotes","enclose_doublequotes",
       "enclose_parentheses","enclose_brackets","enclose_braces",SEPARATOR,
       "moveup_sellines","movedown_sellines"},
    }
  },
  {
    title = Util.SEARCHMENU_TEXT,
    {"find","find_next","find_prev","replace","replaceall","find_increment",SEPARATOR,
     "find_infiles","next_filefound","prev_filefound",SEPARATOR,
     "goto_line"}
  },
  {
    title = Util.TOOLSMENU_TEXT,
    {"toggle_commandentry","run_command",SEPARATOR,
     "run","compile","set_runargs","build","stop_run","next_error","prev_error",SEPARATOR},
    {
      title = Util.BOOKMARKMENU_TEXT,
      {"toggle_bookmark","clear_bookmarks","next_bookmark","prev_bookmark","goto_bookmark"}
    },
    {
      title = Util.QUICKOPENMENU_TEXT,
      {"open_userhome","open_textadepthome","open_currentdir","quick_open_projectdir"}
    },
    {
      title = Util.SNIPPETSMENU_TEXT,
      {"snippet_select","expand_snippet","prev_snipplaceholder","cancel_snippet"}
    },
    {
      title = Util.MACROMENU_TEXT,
      {"toggle_macrorec","load_macrorec",SEPARATOR,
      "play_macrorec","dump_macrorec","save_macrorec"}
    },
    {SEPARATOR,"complete_symbol","show_documentation","show_style"}
  },
  {
    title = Util.BUFFERMENU_TEXT,
    {"next_buffer","prev_buffer","switch_buffer",SEPARATOR},
    {
      title = Util.INDENTATIONMENU_TEXT,
      {"set_tab_2","set_tab_3","set_tab_4","set_tab_8","set_tab_12","set_tab_16",SEPARATOR,
       "toggle_usetabs","convert_indentation"}
    },
    {
      title = Util.EOLMODEMENU_TEXT,
      {"set_eol_crlf","set_eol_lf"}
    },
    {
      title = Util.ENCODINGMENU_TEXT,
      {"set_enc_utf8","set_enc_ascii","set_enc_1252","set_enc_8859","set_enc_utf16"}
    },
    {SEPARATOR,"toggle_view_oel","toggle_view_wrap","toggle_view_ws",SEPARATOR,
     "select_lexer"}
  },
  {
    title = Util.VIEWMENU_TEXT,
    {"next_view","prev_view",SEPARATOR,
     "split_view_h","split_view_v","unsplit_view","unsplit_allviews","grow_view","shrink_view",SEPARATOR,
     "toggle_fold",SEPARATOR,
     "toggle_view_indguides","toggle_virtualspace",SEPARATOR,
     "zoom_in","zoom_out","reset_zoom",SEPARATOR,
     "showin_rightpanel"}
  },
  {
    title = Util.HELPMENU_TEXT,
    {"show_manual","show_luadoc",SEPARATOR,
     "about"}
  }
}


---
-- The right-click context menu
---
actions.context_menu = {
  {"undo","redo",SEPARATOR,
   "cut","copy","paste","delete_char","copyfilename",SEPARATOR,
   "selectall"}
}

---
-- The tabbar context menu
---
actions.tab_context_menu = {
  {"close",SEPARATOR,
   "save","saveas",SEPARATOR,
   "reload","copyfilename"}
}

function actions.getmenu_fromtitle(tit)
  for i=1,#actions.menubar do
    local menu= actions.menubar[i]
    if menu.title == tit then return menu end
    if type(menu) == 'table' then
      --submenu (only one level checked)
      for j=1,#menu do
        if menu[j].title == tit then return menu[j] end
      end
    end
  end
  return nil
end

function actions.appendtomenu_fromtitle(action, tit)
  local menu= actions.getmenu_fromtitle(tit)  --locate menu
  if menu then
    local mit= menu[#menu]  --append the action to the end
    mit[#mit+1]= action
  end
end

--list of actions (index= ID)
actions.action_fromid = {}
--list of actions (index= action)
actions.id_fromaction = {}

local function load_action_lists()
  actions.action_fromid = {}
  actions.id_fromaction = {}
  actions.icons= {}
  actions.buttontext= {}
  local id= 1
  for acc,_ in pairs(actions.list) do
    actions.action_fromid[id]= acc
    actions.id_fromaction[acc]= id
    id=id+1
  end
end
load_action_lists()

---
-- Prompts the user to select a menu command to run.
-- @name select_command
function actions.select_command(infile)
  local items, commands, actioninmenu = {}, {}, {}

  local function build_command_tables(menu)
    for i = 1, #menu do
      local mit= menu[i]
      if mit.title then --submenu
        build_command_tables(mit)
      else
        for j = 1, #mit do
          k= mit[j]
          if k ~= SEPARATOR then
            local v= actions.list[k]
            if v ~= nil then
              actioninmenu[k]= true
              local label = menu.title and menu.title..': '..v[1] or v[1]
              items[#items + 1] = label:gsub('_([^_])', '%1')
              items[#items + 1] = k
              items[#items + 1] = actions.getaccelkeyname(k)
              commands[#commands + 1]= k
            end
          end
        end
      end
    end
  end
  --add actions used in menus
  build_command_tables(actions.menubar)

  --add actions not used in menus
  for k,v in pairs(actions.list) do
    if not actioninmenu[k] then
      local label = v[1]
      items[#items + 1] = label:gsub('_([^_])', '%1')
      items[#items + 1] = k
      items[#items + 1] = actions.getaccelkeyname(k)
      commands[#commands + 1]= k
    end
  end

  if infile then
    actions.run("new")  --new buffer
    for i=1,#items,3 do
      local ln=string.format("%-60s %-25s %s\n", items[i], items[i+1], items[i+2])
      buffer:append_text(ln)
    end
  else
    local button, i = ui.dialogs.filteredlist{
      title = _L['Run Command'], columns = {_L['Command'], "Action", _L['Key Binding']},
      items = items, width = CURSES and ui.size[1] - 2 or 800,
      button1 = _L['Run Command'], button2 = Util.CANCEL_TEXT
    }
    if button == 1 and i then actions.run(commands[i]) end
  end
end

local function gen_menu_table(menu)
  local gtkmenu = {}
  gtkmenu.title = menu.title
  for i = 1, #menu do
    local mit= menu[i]
    if mit.title then --submenu
      gtkmenu[#gtkmenu + 1] = gen_menu_table(mit)
    else
      for j = 1, #mit do
        k= mit[j]
        local label= ""
        local menu_id= 0
        local key= 0
        local mods= 0
        if k ~= SEPARATOR then
          local v= actions.list[k]
          if v ~= nil then
            label = v[1]
            local lb=label:match('(.-) %[Return]')
            if lb then
              label= lb
              key= 0xFF0D
            else
              key, mods = actions.get_gdkkey(k)
            end
            menu_id= actions.id_fromaction[k]
          end
        end
        local st= actions.status[k]
        if st and toolbar then --toolbar allows to show checks, radio and disable items
          actions.usedwithstatus[k]= menu_id
          local status= st() & (7+16) --ignore disable flag (8)
          if status == 1 or status == 2 then
            label= "\t"..label --add check mark to menuitem
          elseif (status & 16) > 0 then
            label= "\b"..label --add radio-button to menuitem (group's first)
          elseif status == 3 or status == 4 then
            label= "\n"..label --add radio-button to menuitem (same group)
          end
        end
        gtkmenu[#gtkmenu + 1] = {label, menu_id, key, mods}
      end
    end
  end
  return gtkmenu
end

function create_uimenu_fromactions(acts)
  local m= ui.menu(gen_menu_table(acts))
  actions.update_menuitems()
  return m
end

local function load_app_menus()
  local _menubar = {}
  for i = 1, #actions.menubar do
    _menubar[#_menubar + 1] = create_uimenu_fromactions(actions.menubar[i])
  end
  ui.menubar = _menubar
  actions.def_context_menu = create_uimenu_fromactions(actions.context_menu)
  ui.context_menu= actions.def_context_menu
  ui.tab_context_menu = create_uimenu_fromactions(actions.tab_context_menu)
  --update actions in menus (gray/check/radio all menuitems)
  actions.update_menuitems()
end
events.connect(events.INITIALIZED, load_app_menus)

-- Performs the appropriate action when clicking a menu item.
events.connect(events.MENU_CLICKED, function(menu_id)
  if not actions.ignoreclickevent then actions.run(menu_id) end
end)

function actions.setmenustatus(menuid, status)
  if toolbar then
    actions.ignoreclickevent= true  --ignore menu click events while updating
    toolbar.menustatus(menuid, status)
    actions.ignoreclickevent= false
  end
end

--update all the actions used in menus
function actions.update_menuitems()
  if toolbar then
    actions.ignoreclickevent= true  --ignore menu click events while updating
    for action,menu_id in pairs(actions.usedwithstatus) do
      toolbar.menustatus(menu_id, actions.status[action]() )
    end
    actions.ignoreclickevent= false
  end
end
