# ta-tweaks
___This is a collection of my Textadept tweaks___:

___Textadept___ is a fast, minimalist, and remarkably extensible cross-platform text editor: http://foicica.com/textadept/

  __goto_nearest.lua__ (based on http://foicica.com/wiki/goto-nearest-occurrence): this module adds the following bindings:

    * F3              goto nearest occurrence FORWARD
    * CTRL+F3:        goto nearest occurrence BACKWARD
    * ALT+F3:         goto nearest occurrence CHOOSE SEARCH OPTIONS
    * SHIFT+F3:       ASK + goto nearest occurrence FORWARD
    * CTRL+SHIFT+F3:  goto nearest occurrence TOGGLE SEARCH OPTIONS (soft <-> strict)
    * SHIFT+ALT+F     Search for text in all project files (requires project.lua)

__Features:__
* Textadept version 8 and 9 compatible
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
* Textadept version 8 and 9 compatible
* Implements a more standard way to handle CTRL+TAB and CTRL+SHIFT+TAB
* It travels the buffers in Most Recent Use order
* Allows to choose any file by holding the control key down and pressing the TAB or shift+TAB keys several times before releasing the control key
* Ignores project file and search results (_project.lua_)

__Usage:__
Copy  _ctrl_tab_mru.lua_ to your __~/.textadept/__ folder and add the following to your personal _init.lua_ file:
```lua
require('ctrl_tab_mru')
```

  __project.lua__ : this module adds the following bindings:

    * F4:     (in project view)   Toggle project file mode (edit / select)
              (in a regular file) Go to project view
    * F5:     (in project view)   Refresh syntax highlighting + project folding
    * CTRL+H: (in project view)   Show the complete path of the file in the selected row
    * CTRL+SHIFT+O: Snapopen project files
    * F11:       	Search for a word in the project CTAG file (save current position)
    * SHIFT+F11:    Navigate to previous position
    * SHIFT+F12:    Navigate to next position
	* CONTROL+F11:  Store current position
	* CONTROL+F12:  Clear all positions
	* SHIFT+ALT+F:  Search for text in all project files
	* ESC:		    Close search view, then, moves between project and files view
	* CONTROL+PgUp: Previous buffer
	* CONTROL+PgDn: Next buffer

__Features:__
* Textadept version 8 and 9 compatible
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
* RUN command parameter __%{projfiles}__ is replaced with a temporary filename that includes the list of all project files
* RUN command parameter __%{projfiles.ext1.ext2...}__ only project files with the given extensions are included
* Select more than one file or command to open/run several at once
* Edit menu: Trim trailing spaces

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

# tatoolbar
This code adds a toolbar to textadept (compiling is required):

The "toolbar" object is added to textadept with the following functions:

* toolbar._new(barsize,buttonsize,imgsize,[isvertical],[imgpath])_ creates an empty toolbar with square buttons
* toolbar._adjust(bwidth,bheight,xmargin,ymargin,xoff,yoff)_ fine tune some parameters
* toolbar._addbutton(button-name,tooltiptext)_ add some buttons
* toolbar._addspace([space],[hidebar])_ add some space (separator)
* toolbar._gotopos([dx])_ change next button position: new row/column + dx pixels
* toolbar._gotopos(x,y)_ change next button position to x,y (in pixels)
* toolbar._show(show)_ show/hide the toolbar
* toolbar._enable(button-name,isenabled)_ enable/disable a button given its name
* toolbar._seticon(button-name,icon,[nicon])_ set/change a button icon (nicon: 0=normal,1:grayed,2:hilight,3:pressed)
* toolbar._seticon("TOOLBAR",icon,[nicon])_ set/change a global toolbar icon (nicon: 0=background,2:hilight,3:pressed,4:separator)

__Usage:__

* copy src/tatoolbar.c in Textadept/src folder
* edit the current Textadept/src/textadept.c adding the lines indicated in src/textadept.c that contains "USE_TA_TOOLBAR"
* optionaly copy also the lines that contains "UNUSED()" to supress some warnings
* compile Textadept
* choose one ZIP with icons from (tatoolbar/images) and copy the icons to "Textadept/core/images/bar/" folder
  (you can choose another icon location and set the path when calling toolbar.new())
* to create an empty horizontal toolbar (with 16x16 images), add this code to your init file:
```
if toolbar then
  function toolbar.cmd(name,func,tooltip,icon)
    toolbar.addbutton(name,tooltip)
    toolbar[name]= func
    if icon then
      toolbar.seticon(name,icon)
    end
  end

  events.connect("toolbar_clicked", function(button)
    if toolbar[button] ~= nil then
      toolbar[button]()
    else
      ui.statusbar_text= button.." clicked"
    end
  end)

  --create toolbar: barsize= 27 pix, buttonsize= 24x24 pix, imgsize= 16x16 pix
  toolbar.new(27, 24, 16)
  --add buttons here
  toolbar.show(true)
end
```

* then add some buttons:

```
  toolbar.cmd("document-new", buffer.new,      "New [Ctrl+N]") --icon equals name, get from images path
  toolbar.cmd("save",         io.save_file,    "Save [Ctrl+S]", "document-save") --diferent icon name, get from images path
  toolbar.cmd("save-as",      io.save_file_as, "Save as [Ctrl+Shift+S]", "C:\\textadept\\textadept_NIGHTLY9\\core\\images\\bar-dark\\document-save-as.png")) --full path to the icon file
```

NOTE: the icon images __must be PNG__ files. If only the icon name is given, the toolbar uses the images path given in the toolbar.new() 5th parameter (or "Textadept/core/images/bar" if not) and adds the name and the ".png" extension.

* and some separators:

```
  toolbar.seticon("TOOLBAR","myseparator",4) --optionally change the default separator image
  toolbar.addspace() --add a half button separator with a vertical line in between
  toolbar.addspace(30) --set separator size
  toolbar.addspace(0,true) --don't show an image in the middle
```

* and code to enable/disable your buttons:

```
  if toolbar then
    toolbar.enable("go-previous", (jump_list.pos >= 1) )
    toolbar.enable("go-next", (jump_list.pos < #jump_list))
  end
```

* one row in not enought?

```
  toolbar.new(54, 24, 16) --create a bar with room for two rows
  toolbar.seticon("TOOLBAR", "ttb-back") --optinally add a background image (27 pix high) to draw lines at the end of every row 
  --define row #1 buttons
  toolbar.gotopos(3); --new row plus 3 pixels (since each rows is 27 pix and the buttons are 24 pix)
  --define row #2 buttons
```

__Some examples:__

**Vertical toolbar**
![vertical toolbar](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/vertical.png "Vertical toolbar")

**Horizontal toolbar**
![horizontal toolbar](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/horizontal.png "Horizontal toolbar, other theme")

**Dual row toolbar**
![dual row toolbar](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/horizontalx2.png "Horizontal toolbar, two rows")
