-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.
------- PROJECT -------
Proj = {}

local events, events_connect = events, events.connect

--project views
Proj.PRJV_DEFAULT =     0   -- default view (no active project)
Proj.PRJV_PROJECT =     1   -- project view
Proj.PRJV_FILES =       2   -- project files view
Proj.PRJV_SEARCH =      3   -- search results view
Proj.PRJV_FILES_2 =     4   -- files #2 (right side of vertical split)

--preferred view number for each view type
Proj.prefview = {
  [Proj.PRJV_DEFAULT] = 0,  -- default view (no active project)
  [Proj.PRJV_PROJECT] = 1,  -- project in view #1
  [Proj.PRJV_FILES]   = 2,  -- project files in view #2
  [Proj.PRJV_SEARCH]  = 3,  -- search results in view #3
  [Proj.PRJV_FILES_2] = 4,  -- files #2 (right side of vertical split) in view #4
}

--split control { adjust previous view size [%], vertical/horizontal split, view to split }
Proj.prefsplit = {
  [1] = { 0.20, true,  1 },  -- project files in view #2  (view #1 size = 20%, VERTICAL)
  [2] = { 0.75, false, 2 },  -- search results in view #3 (view #2 size = 75%, HORIZONTAL)
  [3] = { 0.50, true,  2 },  -- files #2 in view #4       (view #2 size = 50%, VERTICAL)
}

--project row/file types
Proj.PRJF_EMPTY =       0   -- not a file (could be an empty row or a file group)
Proj.PRJF_PATH  =       1   -- a path
Proj.PRJF_FILE  =       2   -- a regular file (could be opened and searched)
Proj.PRJF_CTAG  =       3   -- a CTAGS file (could be opened but searched only using TAG functions)
Proj.PRJF_RUN   =       4   -- a run command
Proj.PRJF_VCS   =       5   -- version control entry

--buffer types
Proj.PRJB_NORMAL =      0   -- a regular file
Proj.PRJB_FSEARCH =     1   -- a "search in project files" results
Proj.PRJB_PROJ_MIN =    2   -- start of project values
Proj.PRJB_PROJ_NEW =     2  -- a project file (not marked yet)
Proj.PRJB_PROJ_IDLE =    3  -- a project file (but not the working one)
Proj.PRJB_PROJ_SELECT =  4  -- a project file in "selection mode"
Proj.PRJB_PROJ_EDIT =    5  -- a project file in "edit mode"

--buffer "_type" constants
Proj.PRJT_SEARCH= '[Project search]'  --search results

require('project.proj_data')
require('project.proj_ui')
require('project.proj_cmd')
require('project.proj_ctags')
require('project.proj_diff')
require('project.proj_menu')

--- TA-EVENTS ---
events_connect(events.INITIALIZED,          Proj.EVinitialize)
events_connect(events.QUIT,                 Proj.EVquit, 1)
events_connect(events.RESET_BEFORE,         Proj.EVquit, 1)

events_connect(events.BUFFER_BEFORE_SWITCH, Proj.show_lost_focus)
events_connect(events.VIEW_BEFORE_SWITCH,   Proj.show_lost_focus)

events_connect(events.BUFFER_AFTER_SWITCH,  Proj.EVafter_switch)
events_connect(events.VIEW_AFTER_SWITCH,    Proj.EVafter_switch)

events_connect(events.VIEW_NEW,             Proj.EVview_new)
events_connect(events.BUFFER_NEW,           Proj.EVbuffer_new)
events_connect(events.BUFFER_DELETED,       Proj.EVbuffer_deleted)
events_connect(events.FILE_OPENED,          Proj.EVfile_opened)

events_connect(events.DOUBLE_CLICK,         Proj.EVdouble_click)
events_connect(events.KEYPRESS,             Proj.EVkeypress)
events_connect(events.UPDATE_UI,            Proj.EVupdate_ui)
events_connect(events.MODIFIED,             Proj.EVmodified)

-- replace Open uri(s) code (core/ui.lua)
events_connect(events.URI_DROPPED, function(utf8_uris)
  ui.goto_view(view) -- work around any view focus synchronization issues
  Proj.goto_filesview() --don't drop files in project views
  for utf8_uri in utf8_uris:gmatch('[^\r\n]+') do
    if utf8_uri:find('^file://') then
      local uri = utf8_uri:iconv(_CHARSET, 'UTF-8')
      uri = uri:match('^file://([^\r\n]+)'):gsub('%%(%x%x)', function(hex)
        return string.char(tonumber(hex, 16))
      end)
      -- In WIN32, ignore a leading '/', but not '//' (network path).
      if WIN32 and not uri:match('^//') then uri = uri:sub(2, -1) end
      local mode = lfs.attributes(uri, 'mode')
      if mode and mode ~= 'directory' then io.open_file(uri) end
    end
  end
  Proj.update_after_switch()
  return false
end,1)

------------------- tab-clicked event ---------------
--- when a tab is clicked, change the view if needed
--- (Textadept version >= 9)
---
---  * For Textadept version 8:
---    * add the following line to the function "t_tabchange()" in "textadept.c" @1828
---      lL_event(lua, "tab_clicked", LUA_TNUMBER, page_num + 1, -1);
---    * recompile textadept
---    * add "'tab_clicked'," to "ta_events = {}" in "events.lua" (to register the new event) @369
if Util.TA_MAYOR_VER >= 9 then
  events_connect(events.TAB_CLICKED,        Proj.EVtabclicked, 1)
end
