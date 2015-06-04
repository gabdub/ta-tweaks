------- PROJECT -------
-- Project vars:
--  Proj.view_n     = number of the preferred view for the project
--  Proj.files_vn   = number of the preferred view for opening files
--
--  Proj.cmenu_num  = number of the current context menu
--                1 = project in SELECTION mode
--                2 = project in EDIT mode
--                3 = regular file
--  Proj.cmenu_idx  = 'Project' submenu position in the context menu
--
--  Proj.updating_ui= number of ui updates in progress (ignore some events if > 0)
------------------------
Proj = {}
Proj.updating_ui = 0

require('proj_data')
require('proj_cmd')
require('proj_ui')