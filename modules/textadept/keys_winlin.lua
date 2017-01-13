local keys = keys

-- Movement commands.
if CURSES then
  keys['c^'] = function() buffer.selection_mode = 0 end
  keys['c]'] = buffer.swap_main_anchor_caret
  keys.cf, keys.cb = buffer.char_right, buffer.char_left
  keys.cn, keys.cp = buffer.line_down, buffer.line_up
  keys.ca, keys.ce = buffer.vc_home, buffer.line_end
  keys.mA, keys.mE = buffer.vc_home_extend, buffer.line_end_extend
  keys.mU, keys.mD = buffer.page_up_extend, buffer.page_down_extend
  keys.cma, keys.cme = buffer.document_start, buffer.document_end
  keys.cd, keys.md = buffer.clear, keys.mdel
  keys.ck = function()
    buffer:line_end_extend()
    buffer:cut()
  end
end

if CURSES then
  -- UTF-8 input.
  keys.utf8_input = {
    ['\n'] = function()
      return ui.command_entry.finish_mode(function(code)
        buffer:add_text(utf8.char(tonumber(code, 16)))
      end)
    end
  }
  keys['mu'] = function()
    ui.command_entry.enter_mode('utf8_input')
  end
end

local default_accelerators= {
--FILE                      WIN/LINUX      CURSES
  "new",                    "cn",          "cmn",
  "open",                   "co",          "co",
  "recent",                 "cao",         "cmo",
  "reload",                 "cO",          "mo",
  "save",                   "cs",          "cs",
  "saveas",                 "cS",          "cms",
--"saveall",                "",            "",
  "close",                  "cw",          "cw",
  "closeall",               "cW",          "cmw",
--"session_load",           "",            "",
--"session_save",           "",            "",
  "quit",                   "cq",          "cq",

--EDIT
  "undo",                   "cz",          {"cz","mz"}, --^Z suspends in some terminals
  "redo",                   {"cy","cZ"},   {"cy","mZ"},
  "cut",                    "cx",          "cx",
  "copy",                   "cc",          "cc",
  "paste",                  "cv",          "cv",
  "duplicate_line",         "cd",          "",
  "delete_char",            "del",         "del",
  "delete_word",            "adel",        "mdel",
  "selectall",              "ca",          "ma",
  "match_brace",            "cm",          "mm",
  "complete_word",          "c\n",         "cmj", --CURSES: Win32:c\n + LINUX:cmj
  "highlight_word",         "caH",         "",
  "toggle_comment",         "c/",          "m/",
  "transpose_chars",        "ct",          "ct",
  "join_lines",             "cJ",          "mj",
  "filterthrough",          "c|",          "c\\",
  "sel_matchbrace",         "cM",          "mM",
  "sel_betweenxmltag",      "c<",          "m<",
  "sel_xmltag",             "c>",          "",
  "sel_singlequotes",       "c'",          "m'",
  "sel_doublequotes",       'c"',          'm"',
  "sel_parentheses",        "c(",          "m(",
  "sel_brackets",           "c[",          "m[",
  "sel_braces",             "c{",          "m{",
  "sel_word",               "cD",          "mW",
  "sel_line",               "cN",          "mN",
  "sel_paragraph",          "cP",          "mP",
  "upper_sel",              "cau",         "cmu",
  "lower_sel",              "caU",         "cml",
  "enclose_xmltags",        "a<",          "m>",
  "enclose_xmltag",         "a>",          "",
  "enclose_singlequotes",   "a'",          "",
  "enclose_doublequotes",   'a"',          '',
  "enclose_parentheses",    "a(",          "m)",
  "enclose_brackets",       "a[",          "m]",
  "enclose_braces",         "a{",          "m}",
  "moveup_sellines",        "csup",        "csup",
  "movedown_sellines",      "csdown",      "csdown",

--SEARCH
  "find",                   "cf",          {"mf","mF"}, --mf is used by some GUI terminals
  "find_next",              {"f3","cg"},   "mg",
  "find_prev",              {"sf3","cG"},  "mG",
  "replace",                "car",         "mr",
  "replaceall",             "caR",         "mR",
-- Find Next is   "an" when find pane is focused in GUI
-- Find Prev is   "ap" when find pane is focused in GUI
-- Replace is     "ar" when find pane is focused in GUI
-- Replace All is "aa" when find pane is focused in GUI
  "find_increment",         "caf",          "cmf",
  "find_infiles",           "cF",           "",
  "next_filefound",         "cag",          "",
  "prev_filefound",         "caG",          "",
  "goto_line",              "cj",           "cj",

--TOOLS
  "toggle_commandentry",    "ce",           "mc",
  "run_command",            "cE",           "mC",
  "run",                    "cr",           "cr",
  "compile",                "cR",           "cmr",
  "set_runargs",            "cB",           "cmb",
  "build",                  "cA",           "",
  "stop_run",               "cX",           "cmx",
  "next_error",             "cae",          "mx",
  "prev_error",             "caE",          "mX",
  "toggle_bookmark",        "cf2",          "f1",
  "clear_bookmarks",        "csf2",         "f6",
  "next_bookmark",          "f2",           "f2",
  "prev_bookmark",          "sf2",          "f3",
  "goto_bookmark",          "af2",          "f4",
  "open_userhome",          "cu",           "cu",
--"open_textadepthome",     "",             "",
  "open_currentdir",        "caO",          "mO",
  "open_projectdir",        "caP",          "cmp",
  "insert_snippet",         "ck",           "mk",
  "expand_snippet",         "\t",           "\t",
  "prev_snipplaceholder",   "s\t",          "s\t",
  "cancel_snippet",         "cK",           "mK",
  "complete_symbol",        "c ",           "c@", --CURSES: Win32:"c " + LINUX:c@
  "show_documentation",     "ch",           {"mh","mH"}, --mh is used by some GUI terminals
  "show_style",             "ci",           "mI",

--BUFFER
  "next_buffer",            "c\t",          "mn",
  "prev_buffer",            "cs\t",         "mp",
  "switch_buffer",          "cb",           {"mb","mB"}, --mb is used by some GUI terminals
--"set_tab_2",              "",             "",
--"set_tab_3",              "",             "",
--"set_tab_4",              "",             "",
--"set_tab_8",              "",             "",
  "toggle_usetabs",         "caT",          {"mt","mT"}, --mt is used by some GUI terminals
  "convert_indentation",    "cai",          "mi",
--"set_eol_crlf",           "",             "",
--"set_eol_lf",             "",             "",
--"set_enc_utf8",           "",             "",
--"set_enc_ascii",          "",             "",
--"set_enc_8859",           "",             "",
--"set_enc_utf16",          "",             "",
  "toggle_view_oel",        "ca\n",         "",
  "toggle_view_wrap",       "ca\\",         "",
  "toggle_view_ws",         "caS",          "",
  "select_lexer",           "cL",           "mL",
  "refresh_syntax",         "f5",           {"f5","cl"},

--VIEW
  "next_view",              "can",          {"++","cmv","n"},   --cmv n
  "prev_view",              "cap",          {"++","cmv","p"},   --cmv p
  "split_view_h",           {"cas", "cah"}, {"++","cmv","s","cmv","h"}, --cmv s / cmv h
  "split_view_v",           "cav",          {"++","cmv","v"},   --cmv v
  "unsplit_view",           "caw",          {"++","cmv","w"},   --cmv w
  "unsplit_allviews",       "caW",          {"++","cmv","W"},   --cmv W
  "grow_view",              {"ca+","ca="},  {"++","cmv","+","cmv","="}, --cmv + / cmv =
  "shrink_view",            "ca-",          {"++","cmv","-"},   --cmv -
  "toggle_fold",            "c*",           "m*",
  "toggle_view_indguides",  "caI",          "",
  "toggle_virtualspace",    "caV",          "",
  "zoom_in",                "c=",           "m=",
  "zoom_out",               "c-",           "m-",
  "reset_zoom",             "c0",           "m0",

--HELP
  "show_manual",            "f1",           "",
  "show_luadoc",            "sf1",          "",
--"about",                  "",             "",
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

--complete_word=   CURSES: Win32: c\n + LINUX:cmj
--complete_symbol= CURSES: Win32:"c " + LINUX:c@
if CURSES and WIN32 then
  actions.accelerators["complete_word"]=   "c\n"
  actions.accelerators["complete_symbol"]= "c "
end
