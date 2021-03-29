-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
-- Windows and Linux key bindings.
--
-- Unassigned keys (~ denotes keys reserved by the operating system):
-- c:       C         H I            p  Q     T ~ V     Y  _   ) ] }   +
-- a:  aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ_   ) ] }  *+-/=\n\s
-- ca: aAbBcCdD   F   H  jJkKlLmM N    qQ    t       xXy zZ_"'()[]{}<>*  /   \s
--
-- c = 'ctrl' (Control ^)
-- a = 'alt' (Alt)
-- s = 'shift' (Shift ⇧)
-- Control, Alt, Shift, and 'a' = 'ctrl+alt+A'
-- Control, Shift, and '\t' = 'ctrl+shift+\t'
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

default_accelerators= {
--FILE                      GUI             CURSES
  "new",                    "ctrl+n",       "ctrl+meta+n",
  "open",                   "ctrl+o",       "ctrl+o",
  "recent",                 "ctrl+alt+o",   "ctrl+meta+o",
  "reload",                 "ctrl+O",       "meta+o",
  "save",                   "ctrl+s",       "ctrl+s",
  "saveas",                 "ctrl+S",       "ctrl+meta+s",
--"saveall",                "",             "",
  "close",                  "ctrl+w",       "ctrl+w",
  "closeall",               "ctrl+W",       "ctrl+meta+w",
--"session_load",           "",             "",
--"session_save",           "",             "",
  "quit",                   "ctrl+q",       "ctrl+q",

--EDIT
  "undo",                   "ctrl+z",       {"ctrl+z","meta+z"}, --^Z suspends in some terminals
  "redo",                   {"ctrl+y","ctrl+Z"}, {"ctrl+y","meta+Z"},
  "cut",                    "ctrl+x",       "ctrl+x",
  "copy",                   "ctrl+c",       "ctrl+c",
  "paste",                  "ctrl+v",       "ctrl+v",
  "paste_reindent",         "ctrl+V",       "ctrl+V",
  "duplicate_line",         "ctrl+d",       "",
  "delete_char",            "del",          {"del", "ctrl+d"},
  "delete_word",            "alt+del",      {'meta+del', 'meta+d'},
  "delete_line",            "ctrl+l",       "ctrl+l",
  "selectall",              "ctrl+a",       "meta+a",
  "match_brace",            "ctrl+m",       "meta+m",
  "complete_word",          "ctrl+\n",      {'ctrl+meta+j', 'ctrl+\n'},
--"highlight_word",         "ctrl+alt+H",   "", --removed from TA11 menu
  "toggle_comment",         "ctrl+/",       "meta+/",
  "transpose_chars",        "ctrl+t",       "ctrl+t",
  "join_lines",             "ctrl+J",       "meta+j",
  "filterthrough",          "ctrl+|",       "ctrl+\\",
  "sel_matchbrace",         "ctrl+M",       "meta+M",
  "sel_betweenxmltag",      "ctrl+<",       "meta+<",
  "sel_xmltag",             "ctrl+>",       "",
  "sel_word",               "ctrl+D",       "meta+W",
  "sel_line",               "ctrl+N",       "meta+N",
  "sel_paragraph",          "ctrl+P",       "meta+P",
  "upper_sel",              "ctrl+alt+u",   "ctrl+meta+u",
  "lower_sel",              "ctrl+alt+U",   "ctrl+meta+l",
  "enclose_xmltags",        "alt+<",        "meta+>",
  "enclose_xmltag",         "alt+>",        "",
  "enclose_singlequotes",   "alt+'",        "",
  "enclose_doublequotes",   'alt+"',        "",
  "enclose_parentheses",    "alt+(",        "meta+)",
  "enclose_brackets",       "alt+[",        "meta+]",
  "enclose_braces",         "alt+{",        "meta+}",
  "moveup_sellines",        "ctrl+shift+up", "ctrl+shift+up",
  "movedown_sellines",      "ctrl+shift+down", "ctrl+shift+down",

--SEARCH
  "find",                   "ctrl+f",       {"meta+f","meta+F"},
  "find_next",              {"f3","ctrl+g"}, "meta+g",
  "find_prev",              {"shift+f3","ctrl+G"}, "meta+G",
  "replace",                "ctrl+alt+r",   "meta+r",
  "replaceall",             "ctrl+alt+R",   "meta+R",
-- Find Next is   "an" when find pane is focused in GUI
-- Find Prev is   "ap" when find pane is focused in GUI
-- Replace is     "ar" when find pane is focused in GUI
-- Replace All is "aa" when find pane is focused in GUI
  "find_increment",         "ctrl+alt+f",   "ctrl+meta+f",
--"find_infiles",           "ctrl+F",       "",
  "find_replace",           "ctrl+F",       "",
  "next_filefound",         "ctrl+alt+g",   "",
  "prev_filefound",         "ctrl+alt+G",   "",
  "goto_line",              "ctrl+j",       "ctrl+j",

--TOOLS
  "toggle_commandentry",    "ctrl+e",       "meta+c",
  "run_command",            "ctrl+E",       "meta+C",
  "run",                    "ctrl+r",       "ctrl+r",
  "compile",                "ctrl+R",       "ctrl+meta+r",
  "set_runargs",            "ctrl+A",       "",
  "build",                  "ctrl+B",       "ctrl+meta+b",
  "stop_run",               "ctrl+X",       "ctrl+meta+x",
  "next_error",             "ctrl+alt+e",   "meta+x",
  "prev_error",             "ctrl+alt+E",   "meta+X",
  "toggle_bookmark",        "ctrl+f2",      "f1",
  "clear_bookmarks",        "ctrl+shift+f2","f6",
  "next_bookmark",          "f2",           "f2",
  "prev_bookmark",          "shift+f2",     "f3",
  "goto_bookmark",          "alt+f2",       "f4",
  "open_userhome",          "ctrl+u",       "ctrl+u",
--"open_textadepthome",     "",             "",
  "open_currentdir",        "ctrl+alt+O",   "meta+O",
  "quick_open_projectdir",  "ctrl+alt+P",   "ctrl+meta+p",
  "snippet_select",         "ctrl+K",       "meta+K",
  "tab_key",                "\t",           "\t",        --textadept.snippets.insert or TAB
  "shift_tab_key",          "shift+\t",     "shift+\t",  --textadept.snippets.previous or shift+TAB
  "cancel_snippet",         "esc",          "esc",
  "complete_trigger",       "ctrl+k",       "meta+k",
  "complete_symbol",        "ctrl+ ",       "ctrl+ ",
  "show_documentation",     "ctrl+h",       {"meta+h","meta+H"},
  "show_style",             "ctrl+i",       "meta+I",

--BUFFER
  "next_buffer",            "ctrl+\t",      "meta+n",
  "prev_buffer",            "ctrl+shift+\t", "meta+p",
  "switch_buffer",          "ctrl+b",       {"meta+b","meta+B"}, --mb is used by some GUI terminals
--"set_tab_2",              "",             "",
--"set_tab_3",              "",             "",
--"set_tab_4",              "",             "",
--"set_tab_8",              "",             "",
  "toggle_usetabs",         "ctrl+alt+T",   {"meta+t","meta+T"}, --mt is used by some GUI terminals
  "convert_indentation",    "ctrl+alt+i",   "meta+i",
--"set_eol_crlf",           "",             "",
--"set_eol_lf",             "",             "",
--"set_enc_utf8",           "",             "",
--"set_enc_ascii",          "",             "",
--"set_enc_8859",           "",             "",
--"set_enc_utf16",          "",             "",
  "toggle_view_oel",        "ctrl+alt+\n",  "",
  "toggle_view_wrap",       "ctrl+alt+\\",  "",
  "toggle_view_ws",         "ctrl+alt+S",   "",
  "select_lexer",           "ctrl+L",       "meta+L",
--"refresh_syntax",         "f5",           "f5",

--VIEW
  "next_view",              "ctrl+alt+n",   "",
  "prev_view",              "ctrl+alt+p",   "",
  "split_view_h",           {"ctrl+alt+s",  "ctrl+alt+h"}, "",
  "split_view_v",           "ctrl+alt+v",   "",
  "unsplit_view",           "ctrl+alt+w",   "",
  "unsplit_allviews",       "ctrl+alt+W",   "",
  "grow_view",              {"ctrl+alt++","ctrl+alt+="}, "",
  "shrink_view",            "ctrl+alt+-",   "",
  "toggle_fold",            "ctrl+*",       "meta+*",
  "toggle_view_indguides",  "ctrl+alt+I",   "",
  "toggle_virtualspace",    "ctrl+alt+V",   "",
  "zoom_in",                "ctrl+=",       "",
  "zoom_out",               "ctrl+-",       "",
  "reset_zoom",             "ctrl+0",       "",

--HELP
  "show_manual",            "f1",           "",
  "show_luadoc",            "shift+f1",     "",
--"about",                  "",             "",

--MOVE CURSOR
  "down",                   "down",         {'down',  'ctrl+n'},
  "up",                     "up",           {'up',    'ctrl+p'},
  "left",                   "left",         {'left',  'ctrl+b'},
  "right",                  "right",        {'right', 'ctrl+f'},
  "word_left",              "ctrl+left",    "ctrl+left",
  "word_right",             "ctrl+right",   "ctrl+right",
  "home",                   "home",         {'home', 'ctrl+a'},
  "end",                    "end",          {'end',  'ctrl+e'},
 --vertical_center_caret
  "page_up",                "pgup",         "pgup",
  "page_down",              "pgdn",         "pgdn",
  "doc_start",              "ctrl+home",    "ctrl+meta+a",
  "doc_end",                "ctrl+end",     "ctrl+meta+e",
--SELECTION
  "sel_down",               "shift+down",   "shift+down",
  "sel_up",                 "shift+up",     "shift+up",
  "sel_left",               "shift+left",   "shift+left",
  "sel_right",              'shift+right',  "shift+right",
  "sel_word_left",          "ctrl+shift+left", "ctrl+shift+left",
  "sel_word_right",         "ctrl+shift+right","ctrl+shift+right",
  "sel_home",               "shift+home",   "meta+A",
  "sel_end",                "shift+end",    "meta+E",
  "sel_page_up",            "shift+pgup",   "meta+U",
  "sel_page_down",          "shift+pgdn",   "meta+D",
  "sel_doc_start",          "ctrl+shift+home","ctrl+shift+home",
  "sel_doc_end",            "ctrl+shift+end", "ctrl+shift+end",
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
  "del_word_right",         "ctrl+del",     "ctrl+del",
--del-line-right            'ctrl+shift+del', 'ctrl+shift+del',
  "del",                    "del",          {'\b', 'ctrl+h'},
  "del_word_left",          "ctrl+\b",      "",
--del_line_left 'ctrl+shift+\b'
  "del_back",               "\b",           "\b",
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

-- Movement commands.
if CURSES then
  keys['ctrl+^'] = function() buffer.selection_mode = 0 end
  keys['ctrl+]'] = buffer.swap_main_anchor_caret

  keys['ctrl+k'] = function()
    buffer:line_end_extend()
    if not buffer.selection_empty then buffer:cut() else buffer:clear() end
  end
  keys['meta+u'] = function()
    ui.command_entry.run(function(code)
      buffer:add_text(utf8.char(tonumber(code, 16)))
    end)
  end
end
