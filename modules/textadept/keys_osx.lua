-- Copyright 2016-2022 Gabriel Dubatti. See LICENSE.
-- Mac OSX key bindings.
--
-- Unassigned keys (~ denotes keys reserved by the operating system):
-- m:       C        ~H I JkK  ~M    p  ~    tT   V    yY  _   ) ] }   +   ~~\n
-- c:      cC D    gG H   J K L    oO  qQ            xXyYzZ_   ) ] }  *  /
-- cm: aAbBcC~D   F  ~HiIjJkKlL~MnN  p q~rRsStTuUvVwWxXyYzZ_"'()[]{}<>*+-/=\t\n
--
-- c = 'ctrl' (Control ^)
-- a = 'alt' (Alt/option ⌥)
-- m = 'cmd' (Command ⌘)
-- s = 'shift' (Shift ⇧)
-- Command, Option, Shift, and 'a' = 'alt+cmd+A'
-- Command, Shift, and '\t' = 'cmd+shift+\t'
--
-- Curses key bindings.
--
-- Key bindings available depend on your implementation of curses.
--
-- For ncurses (Linux, Mac OSX, BSD):
--   * The only Control keys recognized are 'ctrl+a'-'ctrl+z', 'ctrl+ ',
--     'ctrl+\\', 'ctrl+]', 'ctrl+^', and 'ctrl+_'.
--   * Control+Shift and Control+Meta+Shift keys are not recognized.
--   * Modifiers for function keys F1-F12 are not recognized.
-- For pdcurses (Win32):
--   * Many Control+Symbol keys are not recognized, but most
--     Control+Shift+Symbol keys are.
--   * Ctrl+Meta+Symbol keys are not recognized.
--
-- Unassigned keys (~ denotes keys reserved by the operating system):
-- c:        g~~  l~            ~
-- cm:   cd  g~~ k ~   q  t    yz
-- m:          e          J            qQ  sS    vVw   yY  _          +
-- Note: m[befhstv] may be used by Linux/BSD GUI terminals for menu access.
--
-- c = 'ctrl' (Control ^)
-- m = 'meta' (Alt)
-- s = 'shift' (Shift ⇧)
-- Control, Meta, and 'a' = 'ctrl+meta+a'
local keys = keys

local default_accelerators= {
--FILE                      GUI             CURSES
  "new",                    "cmd+n",        "ctrl+meta+n",
  "open",                   "cmd+o",        "ctrl+o",
  "recent",                 "ctrl+cmd+o",   "ctrl+meta+o",
  "reload",                 "cmd+O",        "meta+o",
  "save",                   "cmd+s",        "ctrl+s",
  "saveas",                 "cmd+S",        "ctrl+meta+s",
--"saveall",                "",             "",
  "close",                  "cmd+w",        "ctrl+w",
  "closeall",               "cmd+W",        "ctrl+meta+w",
--"session_load",           "",             "",
--"session_save",           "",             "",
  "quit",                   "cmd+q",        "ctrl+q",

--EDIT
  "undo",                   "cmd+z",        {"ctrl+z","meta+z"}, --^Z suspends in some terminals
  "redo",                   "cmd+Z",        {"ctrl+y","meta+Z"},
  "cut",                    "cmd+x",        "ctrl+x",
  "copy",                   "cmd+c",        "ctrl+c",
  "paste",                  "cmd+v",        "ctrl+v",
  "paste_reindent",         "cmd+V",        "ctrl+V",
  "duplicate_line",         "cmd+d",        "",
  "delete_char",            {"del", "ctrl+d"}, {"del", "ctrl+d"},
  "delete_word",            "ctrl+del",     {"meta+del", "meta+d"},
--"delete_line",            "ctrl+l",       "ctrl+l",
  "selectall",              "cmd+a",        "meta+a",
  "match_brace",            "ctrl+m",       "meta+m",
  "complete_word",          "ctrl+esc",     {'ctrl+meta+j', 'ctrl+\n'},
--"highlight_word",         "ctrl+alt+H",   "", --removed from TA11 menu
  "toggle_comment",         "ctrl+/",       "meta+/",
  "transpose_chars",        "ctrl+t",       "ctrl+t",
  "join_lines",             "ctrl+J",       "meta+j",
  "filterthrough",          "cmd+|",        "ctrl+\\",
  "sel_matchbrace",         "ctrl+M",       "meta+M",
  "sel_betweenxmltag",      "cmd+<",        "meta+<",
  "sel_xmltag",             "cmd+>",        "",
  "sel_word",               "cmd+D",        "meta+W",
  "sel_line",               "cmd+N",        "meta+N",
  "sel_paragraph",          "cmd+P",        "meta+P",
  "upper_sel",              "ctrl+u",       "ctrl+meta+u",
  "lower_sel",              "ctrl+U",       "ctrl+meta+l",
  "enclose_xmltags",        "ctrl+<",       "meta+>",
  "enclose_xmltag",         "ctrl+>",       "",
  "enclose_singlequotes",   "ctrl+'",       "",
  "enclose_doublequotes",   'ctrl+"',       "",
  "enclose_parentheses",    "ctrl+(",       "meta+)",
  "enclose_brackets",       "ctrl+[",       "meta+]",
  "enclose_braces",         "ctrl+{",       "meta+}",
  "moveup_sellines",        "ctrl+shift+up", "ctrl+shift+up",
  "movedown_sellines",      "ctrl+shift+down", "ctrl+shift+down",

--SEARCH
  "find",                   "cmd+f",        {"meta+f","meta+F"},
  "find_next",              "cmd+g",        "meta+g",
  "find_prev",              "cmd+G",        "meta+G",
  "replace",                "ctrl+r",       "meta+r",
  "replaceall",             "ctrl+R",       "meta+R",
-- Find Next is   "an" when find pane is focused in GUI
-- Find Prev is   "ap" when find pane is focused in GUI
-- Replace is     "ar" when find pane is focused in GUI
-- Replace All is "aa" when find pane is focused in GUI
  "find_increment",         "ctrl+cmd+f",   "ctrl+meta+f",
--"find_infiles",           "cmd+F",        "",
  "find_replace",           "cmd+F",        "",
  "next_filefound",         "ctrl+cmd+g",   "",
  "prev_filefound",         "ctrl+cmd+G",   "",
  "goto_line",              "cmd+j",        "ctrl+j",

--TOOLS
  "toggle_commandentry",    "cmd+e",        "meta+c",
  "run_command",            "cmd+E",        "meta+C",
  "run",                    "cmd+r",        "ctrl+r",
  "compile",                "cmd+R",        "ctrl+meta+r",
  "set_runargs",            "cmd+A",        "",
  "build",                  "cmd+B",        "ctrl+meta+b",
  "stop_run",               "cmd+X",        "ctrl+meta+x",
  "next_error",             "ctrl+cmd+e",   "meta+x",
  "prev_error",             "ctrl+cmd+E",   "meta+X",
  "toggle_bookmark",        "cmd+f2",       "f1",
  "clear_bookmarks",        "cmd+shift+f2", "f6",
  "next_bookmark",          "f2",           "f2",
  "prev_bookmark",          "shift+f2",     "f3",
  "goto_bookmark",          "alt+f2",       "f4",
  "open_userhome",          "cmd+u",        "ctrl+u",
--"open_textadepthome",     "",             "",
  "open_currentdir",        "ctrl+cmd+O",   "meta+O",
  "quick_open_projectdir",  "ctrl+cmd+P",   "ctrl+meta+p",
  "snippet_select",         "shift+alt+\t", "meta+K",
  "tab_key",                "\t",           "\t",
  "shift_tab_key",          "shift+\t",     "shift+\t",
  "expand_snippet",         "\t",           "\t",
  "prev_snipplaceholder",   "shift+\t",     "shift+\t",
  "cancel_snippet",         "esc",          "esc",
  "complete_trigger",       "alt+k",        "meta+k",

  "complete_symbol",        "alt+esc",      "ctrl+ ",
  "show_documentation",     "ctrl+h",       {"meta+h","meta+H"},
  "show_style",             "cmd+i",        "meta+I",

--BUFFER
  "next_buffer",            "ctrl+\t",      "meta+n",
  "prev_buffer",            "ctrl+shift+\t", "meta+p",
  "switch_buffer",          "cmd+b",        {"meta+b","meta+B"},
--"set_tab_2",              "",             "",
--"set_tab_3",              "",             "",
--"set_tab_4",              "",             "",
--"set_tab_8",              "",             "",
  "toggle_usetabs",         "ctrl+T",       {"meta+t","meta+T"},
  "convert_indentation",    "ctrl+i",       "meta+i",
--"set_eol_crlf",           "",             "",
--"set_eol_lf",             "",             "",
--"set_enc_utf8",           "",             "",
--"set_enc_ascii",          "",             "",
--"set_enc_8859",           "",             "",
--"set_enc_utf16",          "",             "",
  "toggle_view_oel",        "ctrl+\n",      "",
  "toggle_view_wrap",       "ctrl+\\",      "",
  "toggle_view_ws",         "ctrl+S",       "",
  "select_lexer",           "cmd+L",        "meta+L",
--"refresh_syntax",         "f5",           "f5",

--VIEW
  "next_view",              "ctrl+alt+\t",  "",
  "prev_view",              "ctrl+alt+shift+\t", "",
  "split_view_h",           "ctrl+s",       "",
  "split_view_v",           "ctrl+v",       "",
  "unsplit_view",           "ctrl+w",       "",
  "unsplit_allviews",       "ctrl+W",       "",
  "grow_view",              {"ctrl++","ctrl+="},  "",
  "shrink_view",            "ctrl+-",       "",
  "toggle_fold",            "cmd+*",        "meta+*",
  "toggle_view_indguides",  "ctrl+I",       "",
  "toggle_virtualspace",    "ctrl+V",       "",
  "zoom_in",                "cmd+=",        "",
  "zoom_out",               "cmd+-",        "",
  "reset_zoom",             "cmd+0",        "",

--HELP
  "show_manual",            "f1",           "",
  "show_luadoc",            "shift+f1",     "",
--"about",                  "",             ""

--MOVE CURSOR
  "down",                   {'down', 'ctrl+n'}, {'down', 'ctrl+n'},
  "up",                     {'up',   'ctrl+p'}, {'up',   'ctrl+p'},
  "left",                   {'left', 'ctrl+b'}, {'left', 'ctrl+b'},
  "right",                  {'right','ctrl+f'}, {'right','ctrl+f'},
  "word_left",              {'alt+left', 'ctrl+cmd+b'}, "ctrl+left",
  "word_right",             {'alt+right','ctrl+cmd+f'}, "ctrl+right",
  "home",                   {'cmd+left', 'ctrl+a'}, {'home','ctrl+a'},
  "end",                    {'cmd+right','ctrl+e'}, {'end', 'ctrl+e'},
--vertical_center_caret
  "page_up",                "pgup",         "pgup",
  "page_down",              "pgdn",         "pgdn",
  "doc_start",              "ctrl+home",    "ctrl+meta+a",
  "doc_end",                "ctrl+end",     "ctrl+meta+e",
--SELECTION
  "sel_down",               {'shift+down', 'ctrl+N'}, "shift+down",
  "sel_up",                 {'shift+up',   'ctrl+P'}, "shift+up",
  "sel_left",               {'shift+left', 'ctrl+B'}, "shift+left",
  "sel_right",              {'shift+right','ctrl+F'}, "shift+right",
  "sel_word_left",          {'ctrl+shift+left', 'ctrl+cmd+B'}, "ctrl+shift+left",
  "sel_word_right",         {'ctrl+shift+right','ctrl+cmd+F'}, "ctrl+shift+right",
  "sel_home",               {'cmd+shift+left', 'ctrl+A'}, "meta+A",
  "sel_end",                {'cmd+shift+right','ctrl+E'}, 'meta+E',
  "sel_page_up",            "shift+pgup",   "meta+U",
  "sel_page_down",          "shift+pgdn",   "meta+D",
  "sel_doc_start",          "ctrl+shift+home", "ctrl+shift+home",
  "sel_doc_end",            "ctrl+shift+end",  "ctrl+shift+end",
--RECTANGULAR SELECTION
  "rsel_left",              "alt+shift+left", "alt+shift+left",
  "rsel_right",             "alt+shift+right","alt+shift+right",
  "rsel_up",                "alt+shift+up",   "alt+shift+up",
  "rsel_down",              "alt+shift+down", "alt+shift+down",
  "rsel_home",              "alt+shift+home", "alt+shift+home",
  "rsel_end",               "alt+shift+end",  "alt+shift+end",
  "rsel_page_up",           "alt+shift+pgup", "alt+shift+pgup",
  "rsel_page_down",         "alt+shift+pgdn", "alt+shift+pgdn",
--DELETE
--del-eol 'ctrl+k'
  "del_word_right",         "cmd+del",      "ctrl+del",
--del-line-right            'cmd+shift+del' 'ctrl+shift+del'
  "del_back",               "\b",           {'\b', 'ctrl+h'},
  "del_word_left",          "cmd+\b",       "",
--del_line_left 'cmd+shift+\b'
  "del",                    "del",          "del",
--buffer.selection_mode = 0  "",            'ctrl+^',
--buffer.swap_main_anchor_caret "",         'ctrl+]',
}

local function load_accel_list(lst)
  --load the accelerators for this OS
  local col= CURSES and 2 or 1
  for i=1, #lst, 3 do
    local act=lst[i]
    local key=lst[i+col]
    actions.accelerators[act]=key
  end
end

actions.accelerators = {}
load_accel_list(default_accelerators)

if CURSES then
  keys['ctrl+^'] = function() buffer.selection_mode = 0 end
  keys['ctrl+]'] = buffer.swap_main_anchor_caret
end

keys['ctrl+k'] = function()
  buffer:line_end_extend()
  if not buffer.selection_empty then buffer:cut() else buffer:clear() end
end
keys['ctrl+l'] = view.vertical_center_caret

keys[ CURSES and 'meta+u' or 'cmd+U'] = function()
  ui.command_entry.run(function(code)
    buffer:add_text(utf8.char(tonumber(code, 16)))
  end)
end

-- GTK-OSX reports Fn-key as a single keycode which confuses Scintilla. Do
-- not propagate it.
keys.fn = function() return true end
