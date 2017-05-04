-- Copyright 2016-2017 Gabriel Dubatti. See LICENSE.
------------ OSX ------------
-- GUI key bindings
--
-- Unassigned keys (~ denotes keys reserved by the operating system):
-- m:       C        ~  I JkK  ~M    p  ~    tT   V    yY  _   ) ] }   +   ~~\n
-- c:      cC D    gG H  J K L    oO  qQ             xXyYzZ_   ) ] }  *  /
-- cm: aAbBcC~D   F  ~HiIjJkKlL~MnN  p q~rRsStTuUvVwWxXyYzZ_"'()[]{}<>*+-/=\t\n
--
-- CTRL = 'c' (Control ^)
-- ALT = 'a' (Alt/option ⌥)
-- META = 'm' (Command ⌘)
-- SHIFT = 's' (Shift ⇧)
-- ADD = ''
-- Command, Option, Shift, and 'a' = 'amA'
-- Command, Shift, and '\t' = 'ms\t'
--
-- CURSES key bindings
--
-- Key bindings available depend on your implementation of curses.
--
-- For ncurses (Linux, Mac OSX, BSD):
--   * The only Control keys recognized are 'ca'-'cz', 'c@', 'c\\', 'c]', 'c^',
--     and 'c_'.
--   * Control+Shift and Control+Meta+Shift keys are not recognized.
--   * Modifiers for function keys F1-F12 are not recognized.
--
-- Unassigned keys (~ denotes keys reserved by the operating system):
-- c:        g~~   ~            ~
-- cm:   cd  g~~ k ~   q  t    yz
-- m:          e          J            qQ  sS    vVw   yY  _          +
-- Note: m[befhstv] may be used by Linux/BSD GUI terminals for menu access.
--
-- CTRL = 'c' (Control ^)
-- ALT = [unused]
-- META = 'm' (Alt)
-- SHIFT = 's' (Shift ⇧)
local keys = keys

local default_accelerators= {
--FILE                      GUI             CURSES
  "new",                    "mn",           "mn",
  "open",                   "mo",           "mo",
  "recent",                 "cmo",          "cmo",
  "reload",                 "mO",           "mO",
  "save",                   "ms",           "ms",
  "saveas",                 "mS",           "mS",
--"saveall",                "",             "",
  "close",                  "mw",           "mw",
  "closeall",               "mW",           "mW",
--"session_load",           "",             "",
--"session_save",           "",             "",
  "quit",                   "mq",           "mq",

--EDIT
  "undo",                   "mz",           "mz",
  "redo",                   "mZ",           "mZ",
  "cut",                    "mx",           "mx",
  "copy",                   "mc",           "mc",
  "paste",                  "mv",           "mv",
  "duplicate_line",         "md",           "",
  "delete_char",            "del",          "del",
  "delete_word",            "cdel",         "cdel",
  "selectall",              "ma",           "ma",
  "match_brace",            "cm",           "mm",
  "complete_word",          "cesc",         "cesc",
  "highlight_word",         "mH",           "",
  "toggle_comment",         "m/",           "m/",
  "transpose_chars",        "ct",           "ct",
  "join_lines",             "cj",           "cj",
  "filterthrough",          "m|",           "m|",
  "sel_matchbrace",         "cM",           "mM",
  "sel_betweenxmltag",      "m<",           "m<",
  "sel_xmltag",             "m>",           "",
  "sel_singlequotes",       "m'",           "m'",
  "sel_doublequotes",       'm"',           'm"',
  "sel_parentheses",        "m(",           "m(",
  "sel_brackets",           "m[",           "m[",
  "sel_braces",             "m{",           "m{",
  "sel_word",               "mD",           "mD",
  "sel_line",               "mN",           "mN",
  "sel_paragraph",          "mP",           "mP",
  "upper_sel",              "cu",           "cu",
  "lower_sel",              "cU",           "cU",
  "enclose_xmltags",        "c<",           "c<",
  "enclose_xmltag",         "c>",           "",
  "enclose_singlequotes",   "c'",           "",
  "enclose_doublequotes",   'c"',           '',
  "enclose_parentheses",    "c(",           "c)",
  "enclose_brackets",       "c[",           "c]",
  "enclose_braces",         "c{",           "c}",
  "moveup_sellines",        "csup",         "csup",
  "movedown_sellines",      "csdown",       "csdown",

--SEARCH
  "find",                   "mf",           {"mf","mF"}, --mf is used by some GUI terminals
  "find_next",              "mg",           "mg",
  "find_prev",              "mG",           "mG",
  "replace",                "cr",           "cr",
  "replaceall",             "cR",           "cR",
-- Find Next is   "an" when find pane is focused in GUI
-- Find Prev is   "ap" when find pane is focused in GUI
-- Replace is     "ar" when find pane is focused in GUI
-- Replace All is "aa" when find pane is focused in GUI
  "find_increment",         "cmf",          "cmf",
  "find_infiles",           "mF",           "",
  "next_filefound",         "cmg",          "",
  "prev_filefound",         "cmG",          "",
  "goto_line",              "mj",           "mj",

--TOOLS
  "toggle_commandentry",    "me",           "me",
  "run_command",            "mE",           "mE",
  "run",                    "mr",           "mr",
  "compile",                "mR",           "mR",
  "set_runargs",            "mB",           "mB",
  "build",                  "mA",           "",
  "stop_run",               "mX",           "mX",
  "next_error",             "cme",          "cme",
  "prev_error",             "cmE",          "cmE",
  "toggle_bookmark",        "mf2",          "mf2",
  "clear_bookmarks",        "msf2",         "msf2",
  "next_bookmark",          "f2",           "f2",
  "prev_bookmark",          "sf2",          "f3",
  "goto_bookmark",          "af2",          "f4",
  "open_userhome",          "mu",           "mu",
--"open_textadepthome",     "",             "",
  "open_currentdir",        "cmO",          "cmO",
  "open_projectdir",        "cmP",          "cmP",
  "insert_snippet",         "a\t",          "m\t",
  "expand_snippet",         "\t",           "\t",
  "prev_snipplaceholder",   "s\t",          "s\t",
  "cancel_snippet",         "as\t",         "mK",
  "complete_symbol",        "aesc",         "mesc",
  "show_documentation",     "ch",           {"mh","mH"}, --mh is used by some GUI terminals
  "show_style",             "mi",           "mi",

--BUFFER
  "next_buffer",            "c\t",          "mn",
  "prev_buffer",            "cs\t",         "mp",
  "switch_buffer",          "mb",           {"mb","mB"}, --mb is used by some GUI terminals
--"set_tab_2",              "",             "",
--"set_tab_3",              "",             "",
--"set_tab_4",              "",             "",
--"set_tab_8",              "",             "",
  "toggle_usetabs",         "cT",           {"cT","mT"}, --mt is used by some GUI terminals
  "convert_indentation",    "ci",           "ci",
--"set_eol_crlf",           "",             "",
--"set_eol_lf",             "",             "",
--"set_enc_utf8",           "",             "",
--"set_enc_ascii",          "",             "",
--"set_enc_8859",           "",             "",
--"set_enc_utf16",          "",             "",
  "toggle_view_oel",        "c\n",          "",
  "toggle_view_wrap",       "c\\",          "",
  "toggle_view_ws",         "cS",           "",
  "select_lexer",           "mL",           "mL",
  "refresh_syntax",         "f5",           {"f5","cl"},

--VIEW
  "next_view",              "ca\t",         {"++","cmv","n"},   --cmv n
  "prev_view",              "cas\t",        {"++","cmv","p"},   --cmv p
  "split_view_h",           "cs",           {"++","cmv","s"},   --cmv s
  "split_view_v",           "cv",           {"++","cmv","v"},   --cmv v
  "unsplit_view",           "cw",           {"++","cmv","w"},   --cmv w
  "unsplit_allviews",       "cW",           {"++","cmv","W"},   --cmv W
  "grow_view",              {"c+","c="},    {"++","cmv","+","cmv","="}, --cmv + / cmv =
  "shrink_view",            "c-",           {"++","cmv","-"},   --cmv -
  "toggle_fold",            "m*",           "m*",
  "toggle_view_indguides",  "cI",           "",
  "toggle_virtualspace",    "cV",           "",
  "zoom_in",                "m=",           "m=",
  "zoom_out",               "m-",           "m-",
  "reset_zoom",             "m0",           "m0",

--HELP
  "show_manual",            "f1",           "",
  "show_luadoc",            "sf1",          ""
--"about",                  "",             ""
}

local function load_accel_lists()
  actions.accelerators = {}
  --load the accelerators for this OS
  local col= CURSES and 2 or 1
  for i=1, #default_accelerators, 3 do
    local act=default_accelerators[i]
    local key=default_accelerators[i+col]
    actions.accelerators[act]=key
  end
end
load_accel_lists()

-- Movement commands.
keys.cf, keys.cF = buffer.char_right, buffer.char_right_extend
keys.cmf, keys.cmF = buffer.word_right, buffer.word_right_extend
keys.cb, keys.cB = buffer.char_left, buffer.char_left_extend
keys.cmb, keys.cmB = buffer.word_left, buffer.word_left_extend
keys.cn, keys.cN = buffer.line_down, buffer.line_down_extend
keys.cp, keys.cP = buffer.line_up, buffer.line_up_extend
keys.ca, keys.cA = buffer.vc_home, buffer.vc_home_extend
keys.ce, keys.cE = buffer.line_end, buffer.line_end_extend
keys.aright, keys.aleft = buffer.word_right, buffer.word_left
keys.cd = buffer.clear
keys.ck = function()
  buffer:line_end_extend()
  buffer:cut()
end
keys.cl = buffer.vertical_centre_caret
-- GTK-OSX reports Fn-key as a single keycode which confuses Scintilla. Do
-- not propagate it.
keys.fn = function() return true end

-- UTF-8 input.
keys.utf8_input = {
  ['\n'] = function()
    return ui.command_entry.finish_mode(function(code)
      buffer:add_text(utf8.char(tonumber(code, 16)))
    end)
  end
}
keys['mU'] = function()
  ui.command_entry.enter_mode('utf8_input')
end
