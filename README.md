# ta-tweaks

This is a collection of my Textadept tweaks.

Textadept is a fast, minimalist, and remarkably extensible cross-platform text editor: http://foicica.com/textadept/

***

# Module list:

* [ctrl_tab_mru](https://github.com/gabdub/ta-tweaks/wiki/ctrl_tab_mru-module) module implements a more standard way to handle CTRL+TAB and CTRL+SHIFT+TAB
* [goto_nearest](https://github.com/gabdub/ta-tweaks/wiki/goto_nearest-module) module allows quick search of the selected text. All the buffers use the same 'last searched text' and search options (based on Ultra-Edit editor's F3)
* [quicktype](https://github.com/gabdub/ta-tweaks/wiki/quicktype-module) module types some C snippets that I frequently use + Multiline typer + Goto previous/next lua function/C-block begin/end
* [project](https://github.com/gabdub/ta-tweaks/wiki/project-module) module allows to group files in projects. One view is used to show the project files as a vertical list. It allows to search into project files (the results are shown in another view),
  CTAG file search and RUN commands from the project tree view. ![file search](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/ta_search.png "Search text in Project files")

***

# tatoolbar
This code adds some toolbars to textadept (__compiling is required__):

Each toolbar can be used as you wish but the default implementation is as follows:
* #0: The horizontal top toolbar is used to show buttons and tabs
* #1: The vertical left toolbar is used to show buttons
* #2: The horizontal bottom toolbar is used as a status bar replacement
* #3: The vertical right toolbar is used as a configuration panel
* #4: Pop-up toolbar

![4 toolbars in action](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tab-win12.png "4 toolbars in action")

Tatoolbar also allows to gray and check menu items:

![Menu changes](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/ttbmenu.png "Menu changes")

check the wiki:
* [tatoolbar](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar)
* [configuration panel](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar---configuration-panel)
* [status bar](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar---status-bar)
* [tabs & theming](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar---tabs-&-theming)
