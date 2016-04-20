# ta-tweaks
___This is a collection of my Textadept tweaks___:

___Textadept___ is a fast, minimalist, and remarkably extensible cross-platform text editor: http://foicica.com/textadept/

  __goto_nearest.lua__ (based on http://foicica.com/wiki/goto-nearest-occurrence): this module adds the following bindings:
  
    * F3              goto nearest occurrence FORWARD
    * CTRL+F3:        goto nearest occurrence BACKWARD
    * ALT+F3:         goto nearest occurrence CHOOSE SEARCH OPTIONS
    * SHIFT+F3:       ASK + goto nearest occurrence FORWARD
    * CTRL+SHIFT+F3:  goto nearest occurrence TOGGLE SEARCH OPTIONS (soft <-> strict)
    * SHIFT+ALT+F     Search for text in all project files (see project.lua)
      
__Features:__
* Quick search of the selected text (if not text is selected, repeat last search)
* All the buffers use the same 'last searched text' and search options
* Based on Ultra-Edit editor F3 search key
* Four search options:
 * 'Word:no + Ignore case (soft match)'
 * 'Word:no + Match case'
 * 'Word:yes + Ignore case'
 * 'Word:yes + Match case (strict match)'

__Usage:__
Copy  _goto_nearest.lua_ to your __~/.textadept/__ folder and add the following to your personal _init.lua_ file:
```lua
require('goto_nearest')
```
_Optional:_
```lua
--replace CTRL+F with SHIFT+F3
keys.cf =  keys.sf3
```

  __ctrl_tab_mru.lua__ : this module adds the following bindings:
  
    * CTRL+TAB:        goto next buffer using a MRU list
    * CTRL+SHIFT+TAB:  goto previous buffer
      
__Features:__
* Implements a more standard way to handle CTRL+TAB and CTRL+SHIFT+TAB
* It travels the buffers in Most Recent Use order
* Allows to choose any file by holding the control key down and pressing the TAB or shift+TAB keys several times before releasing the control key
* Ignores project files (_project.lua_)

__Usage:__
Copy  _ctrl_tab_mru.lua_ to your __~/.textadept/__ folder and add the following to your personal _init.lua_ file:
```lua
require('ctrl_tab_mru')
```

  __project.lua__ : this module adds the following bindings:
  
    * F4:        (in project view) Toggle project file mode (edit / select)
                 (in a regular file) Go to project view
    * F5:        (in project view) Refresh syntax highlighting + project folding
    * CTRL+H:    (in project view) Show the complete path of the file in the selected row
    * CTRL+SHIFT+O:  Snapopen project files
    * F11:       search for a word in the project CTAG file (save current position)
    * SHIFT+F11: navigate to previous position
    * CONTROL+F11: navigate to next position
      
__Features:__
* Allow to group files in projects
* Use a simple text format (see _proj_data.lua_)
* One view is used to show the project files as a vertical list (read only)
* Double click opens the file
* The current file is hilited
* Main and context submenu
* F4 enter/exit the edit mode
* Search in project files (the results are shown in another view with hilite)
* Recent project list
* Menues to create new projects and add files to the project (the current file, all open files or all files from a directory)
* CTAG file search (add a text file to the project and mark it as a CTAG file) (use the RUN command to update the file)
* RUN commands from the project (add a command to the project an run it with a double clic or enter)
* RUN command parameter __%{projfiles}__ is replaced with a temporary filename tha includes the list of all project files
* RUN command parameter __%{projfiles.ext1.ext2...}__ only project files with the given extensions are included
* Select more than one file or command to open/run several at once

__Usage:__
Copy  _project.lua_, _proj_ui.lua_, _proj_cmd.lua_, _proj_ctags.lua_, _proj_data.lua_ and the folders _themes_ and _lexers_ to your __~/.textadept/__ folder and add the following to your personal _init.lua_ file (or use the provided _init.lua_ file as an example):
```lua
require('project')
```
**SELECT Mode**
![select mode](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/ta_proj_sel.png "Project in select mode")

**EDIT Mode**
![edit mode](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/ta_proj_edit.png "Project in edit mode")

**Project File Search**
![file search](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/ta_search.png "Search text in Project files")
