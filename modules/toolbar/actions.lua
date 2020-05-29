-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
local default_icons= {
--FILE
  "new",                    "document-new",
  "open",                   "document-open",
  "recent",                 "document-open-recent",
  "reload",                 "system-restart-panel",
  "save",                   "document-save",
  "saveas",                 "document-save-as",
--"saveall",                "",
--"close",                  "",
--"closeall",               "",
--"session_load",           "",
--"session_save",           "",
  "quit",                   "system-shutdown-panel",

--EDIT
  "undo",                   "edit-undo",
  "redo",                   "edit-redo",
  "cut",                    "edit-cut",
  "copy",                   "edit-copy",
  "paste",                  "edit-paste",
  "duplicate_line",         "lpi-translate",
  "delete_char",            "edit-clear",
--"delete_word",            "",
--"delete_line",            "",
  "selectall",              "edit-select-all",
--"match_brace",            "",
  "complete_word",          "format-text-direction-ltr",
--"highlight_word",         "",
--"toggle_comment",         "",
--"transpose_chars",        "",
--"join_lines",             "",
--"filterthrough",          "",
--"sel_matchbrace",         "",
--"sel_betweenxmltag",      "",
--"sel_xmltag",             "",
--"sel_singlequotes",       "",
--"sel_doublequotes",       "",
--"sel_parentheses",        "",
--"sel_brackets",           "",
--"sel_braces",             "",
--"sel_word",               "",
--"sel_line",               "",
--"sel_paragraph",          "",
--"upper_sel",              "",
--"lower_sel",              "",
--"enclose_xmltags",        "",
--"enclose_xmltag",         "",
--"enclose_singlequotes",   "",
--"enclose_doublequotes",   "",
--"enclose_parentheses",    "",
--"enclose_brackets",       "",
--"enclose_braces",         "",
  "moveup_sellines",        "go-up",
  "movedown_sellines",      "go-down",

--SEARCH
  "find",                   "edit-find",
--"find_next",              "",
--"find_prev",              "",
  "replace",                "edit-find-replace",
--"replaceall",             "",
--"find_increment",         "",
--"find_infiles",           "",
--"next_filefound",         "",
--"prev_filefound",         "",
  "goto_line",              "go-jump",

--TOOLS
  "toggle_commandentry",    "lpi-bug",
  "run_command",            "system-search",
  "run",                    "media-playback-start",
  "compile",                "package-reinstall",
  "set_runargs",            "system-run",
  "build",                  "package-upgrade",
  "stop_run",               "process-stop",
  "next_error",             "media-skip-forward",
  "prev_error",             "media-skip-backward",
  "toggle_bookmark",        "gnome-app-install-star",
--"clear_bookmarks",        "",
--"next_bookmark",          "",
--"prev_bookmark",          "",
--"goto_bookmark",          "",
--"open_userhome",          "",
--"open_textadepthome",     "",
--"open_currentdir",        "",
--"open_projectdir",        "",
  "insert_snippet",         "insert-text",
--"expand_snippet",         "",
--"prev_snipplaceholder",   "",
--"cancel_snippet",         "",
  "complete_symbol",        "gtk-edit",
--"show_documentation",     "",
--"show_style",             "",

--BUFFER
--"next_buffer",            "",
--"prev_buffer",            "",
--"switch_buffer",          "",
--"set_tab_2",              "",
--"set_tab_3",              "",
--"set_tab_4",              "",
--"set_tab_8",              "",
--"toggle_usetabs",         "",
--"convert_indentation",    "",
--"set_eol_crlf",           "",
--"set_eol_lf",             "",
--"set_enc_utf8",           "",
--"set_enc_ascii",          "",
--"set_enc_8859",           "",
--"set_enc_utf16",          "",
--"toggle_view_oel",        "",
--"toggle_view_wrap",       "",
--"toggle_view_ws",         "",
--"select_lexer",           "",
  "refresh_syntax",         "view-refresh",

--VIEW
--"next_view",              "",
--"prev_view",              "",
--"split_view_h",           "",
--"split_view_v",           "",
--"unsplit_view",           "",
--"unsplit_allviews",       "",
  "grow_view",              "view-fullscreen",
  "shrink_view",            "view-restore",
--"toggle_fold",            "",
--"toggle_view_indguides",  "",
--"toggle_virtualspace",    "",
  "zoom_in",                "zoom-in",
  "zoom_out",               "zoom-out",
  "reset_zoom",             "zoom-original",

--HELP
  "show_manual",            "help-contents",
  "show_luadoc",            "lpi-help",
  "about",                  "help-about"
}

local function load_icons()
  for i=1, #default_icons, 2 do
    actions.icons[default_icons[i]]=default_icons[i+1]
  end
end
load_icons()

function actions.gettooltip(action)
  local text=""
  local bt= actions.buttontext[action]
  if bt then
    if type(bt)=='function' then text= bt() else text=bt end
  else
    --no buttontext, see actions.list
    bt= actions.list[action]
    if bt then  --use button text from menu
      if #bt < 3 then --no button-text, generate it from menu text
        bt[3]= bt[1]:gsub('_([^_])', '%1')
      end
      text= bt[3]
    end
  end
  --add the accelerator (if any)
  local acc= actions.getaccelkeyname(action)
  if acc and acc ~= "" then text= text.." ["..acc.."]" end
  return text
end

local function updatestatus(action)
  local status= actions.status[action]
  if type(status) == 'function' then
    local st= status()
    --update toolbar
    toolbar.enable(action,((st & 8) == 0)) --(status & 8= disabled)
    --and menus
    actions.setmenustatus( actions.id_fromaction[action], st)
  end
end

--add and action button to the toolbar
function toolbar.addaction(action,passname)
  local runact= function() return actions.run({action}) end
  local tooltip= actions.gettooltip(action)
  local icon= actions.icons[action]
  if type(icon) == 'function' then icon=icon() end
  toolbar.cmd(action,runact,tooltip,icon,passname)
  updatestatus(action)
end

--update dynamic parts of action button: status, icon, tooltip
function actions.updateaction(action)
  local bt= actions.buttontext[action]
  if type(bt)=='function' then --dynamic tooltip?
    toolbar.settooltip(action, actions.gettooltip(action)) --update
  end
  local icon= actions.icons[action]
  if type(icon) == 'function' then --dynamic icon?
    toolbar.setthemeicon(action, icon()) --update
  end
  updatestatus(action)
end
