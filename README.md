# ta-tweaks
___This is a collection of my Textadept tweaks___:

___Textadept___ is a fast, minimalist, and remarkably extensible cross-platform text editor: http://foicica.com/textadept/

# goto_nearest module
(based on http://foicica.com/wiki/goto-nearest-occurrence) this module adds the following bindings:

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

Copy _goto_nearest_ module into __~/.textadept/modules__ and add the following to your personal _init.lua_ file:
```lua
require('goto_nearest')
```
_Optional:_
```lua
--replace CTRL+F with SHIFT+F3
keys.cf =  keys.sf3
```

#ctrl_tab_mru module
this module adds the following bindings:

* __CTRL+TAB__: goto next buffer using a MRU list
* __CTRL+SHIFT+TAB__: goto previous buffer

__Features:__

* Textadept version 8 and 9 compatible
* Implements a more standard way to handle CTRL+TAB and CTRL+SHIFT+TAB
* It travels the buffers in Most Recent Use order
* Allows to choose any file by holding the control key down and pressing the TAB or shift+TAB keys several times before releasing the control key
* Ignores project file and search results (_project.lua_)

__Usage:__

Copy _ctrl_tab_mru_ module into __~/.textadept/modules__ and add the following to your personal _init.lua_ file:
```lua
require('ctrl_tab_mru')
```

# project module
this module adds the following bindings:

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

Copy _project_ module into __~/.textadept/modules__ and the folders _themes_ and _lexers_ into __~/.textadept/__
and add the following to your personal _init.lua_ file (or use the provided _init.lua_ file as an example):
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
This code adds 4 toolbars to textadept (__compiling is required__):

Each toolbar can be used as you wish but the default implementation is as follows:
* #0: The horizontal top toolbar is used to shown buttons and tabs
* #1: The vertical left toolbar is used to shown buttons
* #2: The horizontal bottom toolbar is used as a status bar replacement
* #3: The vertical right toolbar is used as a configuration panel

![4 toolbars in action](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win12.png "4 toolbars in action")

The _toolbar_ object adds the following functions to **textadept**:

__toolbars__

* toolbar._new(barsize,buttonsize,imgsize,toolbar-num(int) or isvertical(bool),[imgpath])_ creates an empty toolbar with square buttons (_toolbar-num_ = 0/false:top, 1/true:vertical, 2:status-bar, 3:config-panel)
* toolbar._adjust(bwidth,bheight,xmargin,ymargin,xoff,yoff)_ allows to fine tune some parameters
* toolbar._show(show)_ shows/hides the current edited toolbar

__groups__

* toolbar._seltoolbar(toolbar-num(int) or isvertical(bool), [groupnum])_ selects which toolbar/group to edit
* toolbar._addgroup(xcontrol,ycontrol,width,height,[hidden])_ adds a buttons group to the current edited toolbar
  (x/y control: 0=allow groups before and after  1=no groups at the left/top  2=no groups at the right/bottom  3=exclusive row/col
  +4=expand  +8=use items size)
* toolbar._addtabs(xmargin,xsep,withclose,mod-show,fontsz,fontyoffset,[tab-dragging],[xcontrol],[height])_ shows tabs in the current edited toolbar
  (tabs use their own group. xcontrol: 0=allow groups before and after  1=no groups at the left  2=no groups at the right
  3=exclusive row  +4=expand  +8:use items size for width)
* toolbar._showgroup(show)_ shows/hides the current selected group

__buttons__

* toolbar._addbutton(button-name,tooltiptext)_ adds a graphic button to the current edited button-group (icon=button-name)
* toolbar._addtext(button-name,text,tooltiptext,W)_ adds a text button or text (button-name="") to the current edited button-group. width: W=0:use text width, >0:fix width
* toolbar._addlabel(text,tooltiptext,W,leftalign,bold,[lblname])_ adds a text label to the current edited button-group. width: W=0:use text width, >0:fix width.
  "lblname" is only required for changing the label text dinamically
* toolbar._addspace([space],[hidebar])_ adds some space (separator) to the current edited button-group
* toolbar._gotopos([dx])_ changes next button position: new row/column + dx pixels in the current edited button-group
* toolbar._gotopos(x,y)_ changes next button position to x,y (in pixels) in the current edited button-group
* toolbar._enable(button-name,isenabled,[onlyinthistoolbar])_ enables/disables a button given its name
* toolbar._seticon(button-name,icon,[nicon],[onlyinthistoolbar])_ sets/changes a button's icon (nicon: 0=normal/separator,1:disabled,2:hilighted,3:pressed)
* toolbar._seticon("GROUP"/"TOOLBAR",icon,[nicon],[onlyinthistoolbar])_ sets/changes a group or global toolbar's icon (nicon: 0=background,1:separator,2:hilighted,3:pressed,
  4=tabs background, 5-6-7=normal-tab, 8-9-10=disabled-tab, 11-12-13=hilighted tab, 14-15-16=active tab,
  17-19=tab-scroll-left, 18-20=tab-scroll-right, 21-22=close tab, 23=tab changed,
  24-25-26=hilighted text button, 27-28-29=hilight as pressed text button)
* toolbar._settooltip(button-name,tooltip,[onlyinthistoolbar])_ changes a button's tooltip
* toolbar._settext(button-name,text,[tooltip],[onlyinthistoolbar])_ changes a text button's text (and tooltip)
* toolbar._textfont(fontsize,fontyoffset,NORMcol,GRAYcol)_ changes the default text buttons font size and colors in the current edited toolbar

__tabs__

* toolbar._tabfontcolor(NORMcol,HIcol,ACTIVEcol,MODIFcol,GRAYcol)_ changes the default tabs font color in the current edited toolbar
* toolbar._settab(num,tab-text,tooltiptext)_ sets tab _num_ text and tooltip in the current edited toolbar
* toolbar._deletetab(num)_ deletes tab _num_ from the current edited toolbar
* toolbar._activatetab(num)_ activates (selects) tab _num_ in the current edited toolbar
* toolbar._enabletab(num,enabled)_ enables/disables tab _num_ in the current edited toolbar
* toolbar._modifiedtab(num,changed)_ shows/hides change indicator in tab _num_ in the current edited toolbar
* toolbar._hidetab(num,hide)_ shows/hides tab _num_ in the current edited toolbar
* toolbar._tabwidth(num,W,minwidth,maxwidth)_ sets tab _num_ width option: W=0:use text width, >0:fix width, <0:porcent; 0 or minimum; 0 or maximum
* toolbar._tabwidth(num,text)_ sets tab _num_ width using the given text
* toolbar._gototab(pos)_ generates a click in tab _pos_: -1=prev, 1=next, 0=first, 2=last

Instead of calling some of this functions directly, is better to use theming and __requiere('toolbar')__
(see some examples below)

__Usage:__

* copy src/tatoolbar.c and src/tatoolbar.h into Textadept/src folder
* edit the current Textadept/src/textadept.c file, adding the lines shown in src/textadept.c that contains "USE_TA_TOOLBAR"
* optionaly copy the lines that contains "UNUSED()" to supress some warnings when compiling on Win32
* Compile Textadept: https://foicica.com/textadept/manual.html#Compiling
* copy themes files in user's textadept folder (~/.textadept/toolbar) or choose some icons from (toolbar/icons)
  and copy them to "Textadept/core/images/bar/" folder (you can choose another icon location and set the path when calling toolbar.new())
* copy _toolbar_ module into __~/.textadept/modules__ for theming and easy of use
* optionaly copy _htmltoolbar_ module into __~/.textadept/modules__

__Basic use:__

* Create an empty horizontal toolbar (with 16x16 images), add this code to your init file:
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

* Add some buttons:

```
  toolbar.cmd("document-new", buffer.new,      "New [Ctrl+N]") --icon equals name, get from images path
  toolbar.cmd("save",         io.save_file,    "Save [Ctrl+S]", "document-save") --diferent icon name, get from images path
  toolbar.cmd("save-as",      io.save_file_as, "Save as [Ctrl+Shift+S]", "C:\\textadept\\textadept_NIGHTLY9\\core\\images\\bar-dark\\document-save-as.png")) --full path to the icon file
  toolbar.addtext("", "Buttons:","") --pasive text
  toolbar.textcmd("reload",   io.reload_file,  "Reload buffer") --text button
```

NOTE: the icon images __must be PNG__ files. If only the icon name is given, the toolbar uses the images path given in the toolbar.new() 5th parameter (or "Textadept/core/images/bar" if not) and adds the name and the ".png" extension.

* Add some separators:

```
  toolbar.seticon("TOOLBAR","myseparator",4) --optionally change the default separator image
  toolbar.addspace() --add a half button separator with a vertical line in between
  toolbar.addspace(30) --set separator size
  toolbar.addspace(0,true) --don't show an image in the middle
```

* Add code to enable/disable your buttons:

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

* It allows to have the same look and feel on different operating systems and exactly match the colors used in the editor
* You can choose between different predefined themes or create your own (just copy one and edit it)

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
* every horizontal toolbar can have more than one tab group (status-bar is actually a tab group)
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
* Click over a field to: goto line, goto line+column, select lexer from a list, open configuration panel to
  select EOL mode and indentation and select the current encoding from a list

**default status-bar**

![status bar](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win9.png "status bar")

**status-bar with buttons**

![status bar with buttons](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win10.png "status bar with buttons")


# configuration panel

The configuration panel allows you to configure options in groups organized in tabs. It's the easiest way to use __tatoolbar__.

![config panel](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win13.png "config panel")

The configuration settings are kept in __~/.textadept/toolbar_config__.

The user can add more panels and choose which options to save (comments are added automatically). For example:
```
;===[ Toolbar ]===
;THEME
tbtheme:2
;TABS
;Tabs position
tbtabs:2
;Show close button
tbtabclose:3
;Close with double click
tbtab2clickclose:3
;STATUS BAR
tbshowstatbar:true
;VERTICAL BAR
tbvertbar:1
;===========
LEXER:INDENT
ansi_c:s4
lua:s4
text:s2
```

The panel simplifies the creation of the toolbar because almost all the options are set from the tab "Toolbar":
```
if toolbar then
  require('toolbar')
  require('htmltoolbar')

  toolbar.set_theme_from_config() --set the configured theme

  --change theme defaults here
  --toolbar.back[2]="ttb-back2-same"
  --toolbar.back[2]="ttb-back2-down"

  toolbar.create_from_config()  --create the configured toolbars

  --add some buttons
  if Proj then
    toolbar.cmd("tog-projview", Proj.toggle_projview,"Hide project [Shift+F4]", "ttb-proj-o")
    toolbar.addspace(4,true)
    toolbar.cmd("go-previous",  Proj.goto_prev_pos,  "Previous position [Shift+F11]")
    toolbar.cmd("go-next",      Proj.goto_next_pos,  "Next position [Shift+F12]")
    Proj.update_go_toolbar()
    toolbar.addspace()
    toolbar.cmd("document-new", Proj.new_file,   "New [Ctrl+N]")
  end

  toolbar.cmd("document-save",    io.save_file,    "Save [Ctrl+S]")
  toolbar.cmd("document-save-as", io.save_file_as, "Save as [Ctrl+Shift+S]")
  toolbar.addspace()
  toolbar.cmd("tog-book", textadept.bookmarks.toggle, "Toggle bookmark [Ctrl+F2]", "gnome-app-install-star" )

  if Proj then toolbar.cmd("trimsp", Proj.trim_trailing_spaces, "Trim trailing spaces","dialog-ok")  end

  toolbar.ready() --toolbars ready, show them
end
```

