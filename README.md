# ta-tweaks
___This is a collection of my Textadept tweaks___:

___Textadept___ is a fast, minimalist, and remarkably extensible cross-platform text editor: http://foicica.com/textadept/

  __goto_nearest.lua__ (based on http://foicica.com/wiki/goto-nearest-occurrence): this module adds the following bindings:
  * __F3__ goto nearest occurrence FORWARD
  * __CTRL+F3__: goto nearest occurrence BACKWARD
  * __ALT+F3__: goto nearest occurrence CHOOSE SEARCH OPTIONS
  * __SHIFT+F3__: ASK + goto nearest occurrence FORWARD
  * __CTRL+SHIFT+F3__: goto nearest occurrence TOGGLE SEARCH OPTIONS (soft <-> strict)
  * __SHIFT+ALT+F__: Search for text in all project files (requires project.lua)

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

* __CTRL+TAB__: goto next buffer using a MRU list
* __CTRL+SHIFT+TAB__: goto previous buffer

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

* __F4__: _(in project view)_ Toggle project file mode (edit / select)
* __F4__: _(in a regular file)_ Go to project view
* __SHIFT+F4__: Show/Hide project view
* __F5__: _(in project view)_ Refresh syntax highlighting + project folding
* __CTRL+H__: _(in project view)_ Show the complete path of the file in the selected row
* __CTRL+SHIFT+O__: Snapopen project files
* __F11__: Search for a word in the project CTAG file (save current position)
* __SHIFT+F11__: Navigate to previous position
* __SHIFT+F12__: Navigate to next position
* __CONTROL+F11__: Store current position
* __CONTROL+F12__: Clear all positions
* __SHIFT+ALT+F__: Search for text in all project files
* __ESC__: Close search view, then, moves between project and files view
* __CONTROL+PgUp__: Previous buffer
* __CONTROL+PgDn__: Next buffer

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
* RUN commands from the project (add a command to the project an run it with a double click or enter)
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
This code adds a toolbar to textadept (__compiling is required__):

The "toolbar" object is added to textadept with the following functions:

* toolbar._new(barsize,buttonsize,imgsize,toolbar-num(int) or isvertical(bool),[imgpath])_ creates an empty toolbar with square buttons (_toolbar-num_ = 0/false:top, 1/true:vertical, 2:status-bar)
* toolbar._adjust(bwidth,bheight,xmargin,ymargin,xoff,yoff)_ fine tune some parameters
* toolbar._seltoolbar(toolbar-num(int) or isvertical(bool))_ select which toolbar to edit
* toolbar._addbutton(button-name,tooltiptext)_ add a graphic button to the current edited toolbar (icon=button-name)
* toolbar._addtext(button-name,text,tooltiptext,W)_ add a text button or text (button-name="") to the current edited toolbar. width: W=0:use text width, >0:fix width
* toolbar._addspace([space],[hidebar])_ add some space (separator) to the current edited toolbar
* toolbar._gotopos([dx])_ change next button position: new row/column + dx pixels in the current edited toolbar
* toolbar._gotopos(x,y)_ change next button position to x,y (in pixels) in the current edited toolbar
* toolbar._show(show)_ show/hide the current edited toolbar
* toolbar._enable(button-name,isenabled,[onlyinthistoolbar])_ enable/disable a button given its name
* toolbar._seticon(button-name,icon,[nicon],[onlyinthistoolbar])_ set/change a button's icon (nicon: 0=normal/separator,1:disabled,2:hilighted,3:pressed)
* toolbar._seticon("TOOLBAR",icon,[nicon],[onlyinthistoolbar])_ set/change a global toolbar's icon (nicon: 0=background,1:separator,2:hilighted,3:pressed,
  4=tabs background, 5-6-7=normal-tab, 8-9-10=disabled-tab, 11-12-13=hilighted tab, 14-15-16=active tab,
  17-19=tab-scroll-left, 18-20=tab-scroll-right, 21-22=close tab, 23=tab changed,
  24-25-26=hilighted text button, 27-28-29=hilight as pressed text button)
* toolbar._settooltip(button-name,tooltip,[onlyinthistoolbar])_ change a button's tooltip
* toolbar._settext(button-name,text,[tooltip],[onlyinthistoolbar])_ change a text button's text (and tooltip)
* toolbar._textfont(fontsize,fontyoffset,NORMcol,GRAYcol)_ change default text buttons font size and colors in the current edited toolbar
* toolbar._addtabs(xmargin,xsep,withclose,mod-show,fontsz,fontyoffset)_ show tabs in the current edited toolbar
* toolbar._tabfontcolor(NORMcol,HIcol,ACTIVEcol,MODIFcol,GRAYcol)_ change default tab font color in the current edited toolbar
* toolbar._settab(num,tab-text,tooltiptext)_ set tab _num_ text and tooltip in the current edited toolbar
* toolbar._deletetab(num)_ delete tab _num_ from the current edited toolbar
* toolbar._activatetab(num)_ activate (selects) tab _num_ in the current edited toolbar
* toolbar._enabletab(num,enabled)_ enable/disable tab _num_ in the current edited toolbar
* toolbar._modifiedtab(num,changed)_ show/hide change indicator in tab _num_ in the current edited toolbar
* toolbar._hidetab(num,hide)_ show/hide tab _num_ in the current edited toolbar
* toolbar._tabwidth(num,W,minwidth,maxwidth)_ control tab _num_ width: W=0:use text width, >0:fix width, <0:porcent; 0 or minimum; 0 or maximum
* toolbar._tabwidth(num,text)_ set tab _num_ width using the given text
* toolbar._gototab(pos)_ generate a click in tab _pos_: -1=prev, 1=next, 0=first, 2=last

Instead of calling some of this functions directly is better to use theming and __requiere('toolbar')__
(see some examples below)

__Usage:__

* copy src/tatoolbar.c in Textadept/src folder
* edit the current Textadept/src/textadept.c adding the lines indicated in src/textadept.c that contains "USE_TA_TOOLBAR"
* optionaly copy also the lines that contains "UNUSED()" to supress some warnings
* compile Textadept
* copy themes files in user's textadept folder (~/.textadept/toolbar) or choose one ZIP with icons from
  (tatoolbar/images) and copy the icons to "Textadept/core/images/bar/" folder
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
  function toolbar.textcmd(text,func,tooltip)
    toolbar.addtext(text,text,tooltip)
    toolbar[text]= func
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
  toolbar.addtext("", "Buttons:","") --pasive text
  toolbar.textcmd("reload",   io.reload_file,  "Reload buffer") --text button
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

* one row is not enought?

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

# tabs & theming

__Theming Features:__

* Allows to have the same look and feel in different operating systems and match exactly the colors used in the editor
* You can choose from different predefined themes or build your own (just copy one and edit it)

__Tabs Features:__

* 4 tab-states: normal, hilight on over, active and disabled
* 3 images define each tab-state: left + middle (variable width) + right
* each tab-state can have a different text color
* tab show/hide control
* tab tooltip
* 3 width options: text length, fixed width and expanded (with optional minimum and maximum width)
* 3 options to show file modification: change text, show an image, change text color
* option to show a close button in every tab with hilight on over
* option to close a tab with double click
* option to rearrange tabs by dragging
* can have buttons on the left side
* scroll bar buttons are shown when needed (mouse wheel can be used to scroll tabs)
* every horizontal toolbar can have _one_ tab group (status-bar is actually a tab group)
* font size and y-position adjustment

__Some examples using tabs and themes:__

**theme: bar-sm-light**

![theme bar-sm-light](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win1.png "theme bar-sm-light")

**theme: bar-th-dark**

![theme bar-th-dark](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win2.png "theme bar-th-dark")

**Two rows (tabs at the bottom)**

![Two rows (tabs at the bottom)](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win3.png "Two rows (tabs at the bottom)")

**Two rows (tabs at the top) and some tweaks**

![Two rows (tabs at the top)](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win4.png "Two rows (tabs at the top)")

**theme: bar-sm-light**

![theme bar-sm-light](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win6.png "theme bar-sm-light")

**theme: bar-th-dark**

![theme bar-th-dark](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win7.png "theme bar-th-dark")

**theme: bar-th-dark with other background**

![theme bar-th-dark](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win8.png "theme bar-th-dark")

**theme: bar-ch-dark**

![theme bar-ch-dark](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win11.png "theme bar-ch-dark")

**mixed horizontal & vertical**

![mixed horizontal & vertical](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win5.png "mixed horizontal & vertical")


# status bar

__Features:__
* Use the same theme as the toolbar
* First field (ui.statusbartext) with tooltip support to allow read texts partially shown
* click over a field to: goto line, select lexer, select EOL mode, select indentation and select encoding

**default status-bar**

![status bar](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win9.png "status bar")

**status-bar with buttons**

![status bar with buttons](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win10.png "status bar with buttons")
