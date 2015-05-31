# ta-tweaks
___my textadept tweaks___:

  __goto_nearest.lua__ (based on http://foicica.com/wiki/goto-nearest-occurrence): this module adds the following bindings:
  
    * F3              goto nearest occurrence FORWARD
    * CTRL+F3:        goto nearest occurrence BACKWARD
    * ALT+F3:         goto nearest occurrence CHOOSE SEARCH OPTIONS
    * SHIFT+F3:       ASK + goto nearest occurrence FORWARD (could be used as a 'CTRL+F' replacement)
    * CTRL+SHIFT+F3:  goto nearest occurrence TOGGLE SEARCH OPTIONS (soft <-> strict)
      
__Features:__
* Quick search for selected text (if not text is selected, repeat last search)
* All the buffers use the same 'last searched text' and search options
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
