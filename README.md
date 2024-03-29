# ta-tweaks

This is a collection of my Textadept tweaks.

Textadept is a fast, minimalist, and remarkably extensible cross-platform text editor: https://orbitalquark.github.io/textadept/

**Important notes: 11.4 is the last supported version. Tatoolbar popups don't work in Wayland.**

***

# Module list:

* [actions](https://github.com/gabdub/ta-tweaks/wiki/actions) module unify function calling from menus, keyboard accelerators and toolbar buttons / control the state of menus and toolbar buttons: checked, radio-checked and disabled / can be macro recorded, played and saved / allow to change toolbar buttons text and icon dynamically
* [ctrl_tab_mru](https://github.com/gabdub/ta-tweaks/wiki/ctrl_tab_mru-module) module implements a more standard way to handle CTRL+TAB and CTRL+SHIFT+TAB
* [goto_nearest](https://github.com/gabdub/ta-tweaks/wiki/goto_nearest-module) module allows quick search of the selected text. All the buffers use the same 'last searched text' and search options (based on Ultra-Edit editor's F3)
* [quicktype](https://github.com/gabdub/ta-tweaks/wiki/quicktype-module) module types some C snippets that I frequently use + Multiline typer + Goto previous/next lua function/C-block begin/end + Buffer sort
* [project](https://github.com/gabdub/ta-tweaks/wiki/project-module) module allows to group files in projects. One view/panel is used to show the project files as a vertical list. It allows to search into project files (the results are shown in another view/panel),
  CTAG file search and RUN commands from the project tree view. VC: SVN/GIT/FOLDER: multiple repositories per project, compare file to HEAD/FOLDER and basic VC control panel. The project and the search results can be shown using a buffer or a toolbar panel.

![Project](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tatoolbar_off.png "Project without ta-toolbar")

***

# tatoolbar
This code adds toolbars to textadept, allows to gray and check menu items and adds functions to
compare files and strings (__compiling is required__ / download from [releases](https://github.com/gabdub/ta-tweaks/releases) ):

Each toolbar can be used in many different ways. Check the default implementation in: [tatoolbar](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar)

![ta-toolbar](https://github.com/gabdub/ta-tweaks/blob/master/screencapt/tatoolbar_on.png "ta-toolbar demo")

_Notes_

* (1) themed tabs in the same row or in a different row than the graphical buttons
* (2) panel lists (last projects / project / c-tag browser / file browser)
* (3) results panels (console output / search results)
* (4) quick open files dialog
* (5) scroll bar with marks
* (6) status bar with click actions
* (7) compact list selectors (lexer / buffer encoding)
* (8) configuration panel: buffer / toolbar / color / color picker / fonts

Tatoolbar also allows to gray and check menu items:

![Menu changes](https://github.com/gabdub/ta-tweaks/wiki/img/ttbmenu.png "Menu changes")

and compare files + show a MINIMAP (mostly a scroll bar with markers for now):

![filediff](https://github.com/gabdub/ta-tweaks/wiki/img/filediff.png "File diff")

check the wiki:
* [tatoolbar](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar)
* [configuration panel](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar---configuration-panel)
* [status bar](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar---status-bar)
* [tabs & theming](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar---tabs-&-theming)
* [left panel](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar---left-panel)
* [results panel](https://github.com/gabdub/ta-tweaks/wiki/tatoolbar---results-panel)
