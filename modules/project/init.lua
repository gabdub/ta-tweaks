-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
------- PROJECT -------
Proj = {}

local events, events_connect = events, events.connect

--project views
Proj.PRJV_DEFAULT =     0   -- default view (no active project)
Proj.PRJV_PROJECT =     1   -- project view
Proj.PRJV_FILES =       2   -- project files view
Proj.PRJV_SEARCH =      3   -- search results view
Proj.PRJV_FILES_2 =     4   -- files #2 (right side of vertical split)

-- PREFERRED VIEW number for each view type and
-- SPLIT CONTROL { adjust previous view size [%], vertical/horizontal split, view to split }
if USE_LISTS_PANEL then
  --show project in a toolbar panel
  if USE_RESULTS_PANEL then
    --show results in a toolbar panel     (PROJECT: PANEL    SEARCH: PANEL)
    Proj.prefview = {
      [Proj.PRJV_DEFAULT] = 0,  -- default view (no active project)
      [Proj.PRJV_PROJECT] = -1, -- project view REPLACED BY A PANEL
      [Proj.PRJV_FILES]   = 1,  -- project files in view #1
      [Proj.PRJV_SEARCH]  = -1, -- search results view REPLACED BY A PANEL
      [Proj.PRJV_FILES_2] = 2,  -- files #2 (right side of vertical split) in view #2
    }
    Proj.prefsplit = {
      [1] = { 0.50, true,  1 },  -- files #2 in view #2       (view #1 size = 50%, VERTICAL)
    }
  else
    --show results in a buffer            (PROJECT: PANEL    SEARCH: BUFFER)
    Proj.prefview = {
      [Proj.PRJV_DEFAULT] = 0,  -- default view (no active project)
      [Proj.PRJV_PROJECT] = -1, -- project view REPLACED BY A PANEL
      [Proj.PRJV_FILES]   = 1,  -- project files in view #1
      [Proj.PRJV_SEARCH]  = 2,  -- search results in view #2
      [Proj.PRJV_FILES_2] = 3,  -- files #2 (right side of vertical split) in view #3
    }
    Proj.prefsplit = {
      [1] = { 0.75, false, 1 },  -- search results in view #2 (view #1 size = 75%, HORIZONTAL)
      [2] = { 0.50, true,  1 },  -- files #2 in view #3       (view #1 size = 50%, VERTICAL)
    }
  end
else
  --show project in a buffer
  if USE_RESULTS_PANEL then
    --show results in a toolbar panel
    Proj.prefview = {
      [Proj.PRJV_DEFAULT] = 0,  -- default view (no active project)
      [Proj.PRJV_PROJECT] = 1,  -- project in view #1
      [Proj.PRJV_FILES]   = 2,  -- project files in view #2
      [Proj.PRJV_SEARCH]  = -1, -- search results view REPLACED BY A PANEL
      [Proj.PRJV_FILES_2] = 3,  -- files #2 (right side of vertical split) in view #4
    }
    Proj.prefsplit = {
      [1] = { 0.20, true,  1 },  -- project files in view #2  (view #1 size = 20%, VERTICAL)
      [2] = { 0.50, true,  2 },  -- files #2 in view #3       (view #2 size = 50%, VERTICAL)
    }
  else
    --show results in a buffer
    Proj.prefview = {
      [Proj.PRJV_DEFAULT] = 0,  -- default view (no active project)
      [Proj.PRJV_PROJECT] = 1,  -- project in view #1
      [Proj.PRJV_FILES]   = 2,  -- project files in view #2
      [Proj.PRJV_SEARCH]  = 3,  -- search results in view #3
      [Proj.PRJV_FILES_2] = 4,  -- files #2 (right side of vertical split) in view #4
    }
    Proj.prefsplit = {
      [1] = { 0.20, true,  1 },  -- project files in view #2  (view #1 size = 20%, VERTICAL)
      [2] = { 0.75, false, 2 },  -- search results in view #3 (view #2 size = 75%, HORIZONTAL)
      [3] = { 0.50, true,  2 },  -- files #2 in view #4       (view #2 size = 50%, VERTICAL)
    }
  end
end

--project row/file types
Proj.PRJF_EMPTY =       0   -- not a file (could be an empty row or a file group)
Proj.PRJF_PATH  =       1   -- a path
Proj.PRJF_FILE  =       2   -- a regular file (could be opened and searched)
Proj.PRJF_CTAG  =       3   -- a CTAGS file (could be opened but searched only using TAG functions)
Proj.PRJF_RUN   =       4   -- a run command
Proj.PRJF_VCS   =       5   -- version control entry

--buffer "_type" constants
Proj.PRJT_SEARCH= '[Project search]'  --search results

require('project.proj_data')
require('project.proj_ui')
require('project.proj_cmd')
require('project.proj_ctags')
require('project.proj_diff')
require('project.proj_menu')
if not USE_LISTS_PANEL   then require('project.proj_buffer')  end
if not USE_RESULTS_PANEL then require('project.proj_results') end

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

events_connect(events.TAB_CLICKED,          Proj.EVtabclicked, 1)

-- replace Open uri(s) code (core/ui.lua)
events_connect(events.URI_DROPPED,          Proj.drop_uri,1)
