--TA legacy code (check)--
local keys, OSX, GUI, CURSES = keys, OSX, not CURSES, CURSES

-- Movement commands.
if OSX then
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
elseif CURSES then
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

-- Modes.
keys.filter_through = {
  ['\n'] = function()
    return ui.command_entry.finish_mode(textadept.editing.filter_through)
  end,
}
keys.find_incremental = {
  ['\n'] = function()
    ui.find.find_entry_text = ui.command_entry:get_text() -- save
    ui.find.find_incremental(ui.command_entry:get_text(), true, true)
  end,
  ['cr'] = function()
    ui.find.find_incremental(ui.command_entry:get_text(), false, true)
  end,
  ['\b'] = function()
    local e = ui.command_entry:position_before(ui.command_entry.length)
    ui.find.find_incremental(ui.command_entry:text_range(0, e), true)
    return false -- propagate
  end
}
-- Add the character for any key pressed without modifiers to incremental find.
setmetatable(keys.find_incremental, {__index = function(_, k)
               if #k > 1 and k:find('^[cams]*.+$') then return end
               ui.find.find_incremental(ui.command_entry:get_text()..k, true)
             end})
-- Show documentation for symbols in the Lua command entry.
keys.lua_command[GUI and 'ch' or 'mh'] = function()
  -- Temporarily change _G.buffer since ui.command_entry is the "active" buffer.
  local orig_buffer = _G.buffer
  _G.buffer = ui.command_entry
  textadept.editing.show_documentation()
  _G.buffer = orig_buffer
end
if OSX or CURSES then
  -- UTF-8 input.
  keys.utf8_input = {
    ['\n'] = function()
      return ui.command_entry.finish_mode(function(code)
        buffer:add_text(utf8.char(tonumber(code, 16)))
      end)
    end
  }
  keys[OSX and 'mU' or 'mu'] = function()
    ui.command_entry.enter_mode('utf8_input')
  end
end
------------------------------------------------
--list of accelerators (index= action)
actions.accelerators = {}

local default_accelerators= {
--FILE                      WIN/LINUX   OSX         CURSES
  "new",                    "cn",       "mn",       "cmn",
  "open",                   "co",       "mo",       "co",
  "recent",                 "cao",      "cmo",      "cmo",
  "reload",                 "cO",       "mO",       "mo",
  "save",                   "cs",       "ms",       "cs",
  "saveas",                 "cS",       "mS",       "cmS",
--"saveall",                "",         "",         "",
  "close",                  "cw",       "mw",       "cw",
  "closeall",               "cW",       "mW",       "cmW",
--"session_load",           "",         "",         "",
--"session_save",           "",         "",         "",
  "quit",                   "cq",       "mq",       "cq",

--EDIT
  "undo",                   "cz",       "mz",       {"cz","mz"}, --^Z suspends in some terminals
  "redo",                   {"cy","cZ"},"my",       {"cy","cZ"},
  "cut",                    "cx",       "mx",       "cx",
  "copy",                   "cc",       "mc",       "cc",
  "paste",                  "cv",       "mv",       "cv",
  "duplicate_line",         "cd",       "md",       "",
  "delete_char",            "del",      "del",      "del",
  "delete_word",            "adel",     "cdel",     "mdel",
  "selectall",              "ca",       "ma",       "ca",
  "match_brace",            "cm",       "cm",       "mm",
  "complete_word",          "c\n",      "cesc",     "c\n", --curses + Win32:c\n + LINUX:cmj
  "highlight_word",         "caH",      "mH",       "",
  "toggle_comment",         "c/",       "m/",       "m/",
  "transpose_chars",        "ct",       "ct",       "ct",
  "join_lines",             "cJ",       "cj",       "mj",
  "filterthrough",          "c|",       "c\\",      "m|",
  "sel_matchbrace",         "cM",       "cM",       "mM",
  "sel_betweenxmltag",      "c<",       "m<",       "m<",
  "sel_xmltag",             "c>",       "m>",       "",
  "sel_singlequotes",       "c'",       "m'",       "m'",
  "sel_doublequotes",       'c"',       'm"',       'm"',
  "sel_parentheses",        "c(",       "m(",       "m(",
  "sel_brackets",           "c[",       "m[",       "m[",
  "sel_braces",             "c{",       "m{",       "m{",
  "sel_word",               "cD",       "mD",       "mW",
  "sel_line",               "cN",       "mN",       "mN",
  "sel_paragraph",          "cP",       "mP",       "mP",
  "upper_sel",              "cau",      "cu",       "cmu",
  "lower_sel",              "caU",      "cU",       "cml",
  "enclose_xmltags",        "a<",       "c<",       "m>",
  "enclose_xmltag",         "a>",       "c>",       "",
  "enclose_singlequotes",   "a'",       "c'",       "",
  "enclose_doublequotes",   'a"',       'c"',       '',
  "enclose_parentheses",    "a(",       "c(",       "m)",
  "enclose_brackets",       "a[",       "c[",       "m]",
  "enclose_braces",         "a{",       "c{",       "m}",
  "moveup_sellines",        "csup",     "csup",     "csup",
  "movedown_sellines",      "csdown",   "csdown",   "csdown",

--SEARCH
  "find",                   "cf",       "mf",       {"mf","mF"}, --mf is used by some GUI terminals
  "find_next",              {"f3","cg"},"mg",       "mg",
  "find_prev",              {"sf3","cG"},"mG",      "mG",
  "replace",                "car",      "cr",       "mr",
  "replaceall",             "caR",      "cR",       "mR",
-- Find Next is   "an" when find pane is focused in GUI
-- Find Prev is   "ap" when find pane is focused in GUI
-- Replace is     "ar" when find pane is focused in GUI
-- Replace All is "aa" when find pane is focused in GUI
  "find_increment",         "caf",      "cmf",      "cmf",
  "find_infiles",           "cF",       "mF",       "",
  "next_filefound",         "cag",      "cmg",      "",
  "prev_filefound",         "caG",      "cmG",      "",
  "goto_line",              "cj",       "mj",       "mj",

--TOOLS
  "toggle_commandentry",    "ce",       "me",       "mc",
  "run_command",            "cE",       "mE",       "mC",
  "run",                    "cr",       "mr",       "cr",
  "compile",                "cR",       "mR",       "cmr",
  "set_runargs",            "cB",       "mB",       "cmb",
  "build",                  "cA",       "mA",       "",
  "stop_run",               "cX",       "mX",       "cmx",
  "next_error",             "cae",      "cme",      "mx",
  "prev_error",             "caE",      "cmE",      "mX",
  "toggle_bookmark",        "cf2",      "mf2",      "f1",
  "clear_bookmarks",        "csf2",     "msf2",     "f6",
  "next_bookmark",          "f2",       "f2",       "f2",
  "prev_bookmark",          "sf2",      "sf2",      "f3",
  "goto_bookmark",          "af2",      "af2",      "f4",
  "open_userhome",          "cu",       "mu",       "mu",
--"open_textadepthome",     "",         "",         "",
  "open_currentdir",        "caO",      "cmO",      "mO",
  "open_projectdir",        "caP",      "cmP",      "cmp",
  "insert_snippet",         "ck",       "a\t",      "mk",
  "expand_snippet",         "\t",       "\t",       "\t",
  "prev_snipplaceholder",   "s\t",      "s\t",      "s\t",
  "cancel_snippet",         "cK",       "as\t",     "mK",
  "complete_symbol",        "c ",       "aesc",     "c@",
  "show_documentation",     "ch",       "mh",       {"mh","mH"}, --mh is used by some GUI terminals
  "show_style",             "ci",       "mi",       "mI",

--BUFFER
  "next_buffer",            "c\t",      "c\t",      "mn",
  "prev_buffer",            "cs\t",     "cs\t",     "mp",
  "switch_buffer",          "cb",       "mb",       {"mb","mB"}, --mb is used by some GUI terminals
--"set_tab_2",              "",         "",         "",
--"set_tab_3",              "",         "",         "",
--"set_tab_4",              "",         "",         "",
--"set_tab_8",              "",         "",         "",
  "toggle_usetabs",         "caT",      "cT",       {"mt","mT"}, --mt is used by some GUI terminals
  "convert_indentation",    "cai",      "ci",       "mi",
--"set_eol_crlf",           "",         "",         "",
--"set_eol_lf",             "",         "",         "",
--"set_enc_utf8",           "",         "",         "",
--"set_enc_ascii",          "",         "",         "",
--"set_enc_8859",           "",         "",         "",
--"set_enc_utf16",          "",         "",         "",
  "toggle_view_oel",        "ca\n",     "c\n",      "c\n",
  "toggle_view_wrap",       "ca\\",     "c\\",      "c\\",
  "toggle_view_ws",         "caS",      "cS",       "cS",
  "select_lexer",           "cL",       "mL",       "mL",
  "refresh_syntax",         "f5",       "f5",       {"f5","cl"},

--VIEW
  "next_view",              "can",      "ca\t",     {"++","cmv","n"},   --cmv n
  "prev_view",              "cap",      "cas\t",    {"++","cmv","p"},   --cmv p
  "split_view_h",           "cas",      "cs",       {"++","cmv","s"},   --cmv s
  "split_view_v",           "cav",      "cv",       {"++","cmv","v"},   --cmv v
  "unsplit_view",           "caw",      "cw",       {"++","cmv","w"},   --cmv w
  "unsplit_allviews",       "caW",      "cW",       {"++","cmv","W"},   --cmv W
  "grow_view",              {"ca+","ca="},{"c+","c="},{"++","cmv","+","cmv","="}, --cmv + / cmv =
  "shrink_view",            "ca-",      "c-",       {"++","cmv","-"},   --cmv -
  "toggle_fold",            "c*",       "m*",       "m*",
  "toggle_view_indguides",  "caI",      "cI",       "",
  "toggle_virtualspace",    "caV",      "cV",       "",
  "zoom_in",                "c=",       "m=",       "m=",
  "zoom_out",               "c-",       "m-",       "m-",
  "reset_zoom",             "c0",       "m0",       "m0",

--HELP
  "show_manual",            "f1",       "f1",       "f1",
  "show_luadoc",            "sf1",      "sf1",      "sf1",
--"about",                  "",         "",         "",
}

local function load_accel_lists()
  actions.accelerators = {}
  --load the accelerators for this OS
  local col= not CURSES and (OSX and 2 or 1) or 3
  for i=1, #default_accelerators, 4 do
    local act=default_accelerators[i]
    local key=default_accelerators[i+col]
    actions.accelerators[act]=key
  end
end
load_accel_lists()

--don't use this accelerators
function actions.free_accelerator(klist)
  local function freeacc(key)
    for act,k in pairs(actions.accelerators) do
      if type(k) == 'table' then
        --multiple key options
        for i=1,#k do
          if k[i] == key then
            --remove this option
            if #k == 1 then --only 1
              actions.accelerators[act]=nil
              return
            end
            if #k == 2 then --1 left (1),2->2 or 1,(2)->1
              actions.accelerators[act]=k[3-i]
              return
            end
            --2 or more options left
            if i < #k then
              k[i]= k[#k]
            end
            k[#k]= nil
            return
          end
        end
      else
        if k == key then
          actions.accelerators[act]=nil
          return
        end
      end
    end
  end
  if type(klist) == 'table' then
    for i=1, #klist do
      freeacc(klist[i])
    end
  else
    freeacc(klist)
  end
end

local function key_name(kcode)
  local mods, key = kcode:match('^([cams]*)(.+)$')
  local mname = (mods:find('m') and (OSX and "Meta+" or "Alt+") or "") ..
                (mods:find('c') and "Ctrl+" or "") ..
                (mods:find('a') and "Alt+" or "") ..
                (mods:find('s') and "Shift+" or "")
  local ku=string.upper(key)
  local lu=string.lower(key)
  if ku == lu then --only symbols and numbers
    if ku == " " then ku= "Space"
    elseif ku == "\t" then ku= "Tab"
    elseif ku == "\n" then ku= "Return"
    else ku= "["..ku.."]" end
  elseif ku == key then
    mname= mname.."Shift+" --upper case letter: add shift
  end
  return mname..ku
end

function actions.getaccelkeyname(action)
  local k= actions.accelerators[action]
  if k then
    if type(k) == 'table' then
      if k[1] == "++" then
        return key_name(k[2]).." "..key_name(k[3])
      end
      k= k[1]
    end
    return key_name(k)
  end
  return ""
end

-- Returns the GDK integer keycode and modifier mask for a key sequence.
-- This is used for creating menu accelerators.
function actions.get_gdkkey(action)
  local key_seq= actions.accelerators[action]
  if not key_seq then return nil end
  if type(key_seq) == 'table' then
    if key_seq[1] == "++" then
      --don't show dual level keys in menus
      return nil
    end
    --more than one option, show the first in menus
    key_seq= key_seq[1]
  end
  local mods, key = key_seq:match('^([cams]*)(.+)$')
  if not mods or not key then return nil end
  local modifiers = ((mods:find('s') or key:lower() ~= key) and 1 or 0) +
                    (mods:find('c') and 4 or 0) + (mods:find('a') and 8 or 0) +
                    (mods:find('m') and 0x10000000 or 0)
  local code = string.byte(key)
  if #key > 1 or code < 32 then
    for i, s in pairs(keys.KEYSYMS) do
      if s == key and i > 0xFE20 then code = i break end
    end
  end
  return code, modifiers
end

--set accelerator keys
local function setacceleratorskeys()
  for acc,k in pairs(actions.accelerators) do
    if type(k) == 'table' then
      if k[1] == "++" then
        --TO DO: set dual level keys
        --return key_name(k[2]).." "..key_name(k[3])
      else
        --more than one accelerator for the same action
        for i=1, #k do
          keys[k[i]]=actions.list[acc][2]
        end
      end
    else
      keys[k]=actions.list[acc][2]
    end
  end
end

events.connect(events.INITIALIZED, setacceleratorskeys)

return M