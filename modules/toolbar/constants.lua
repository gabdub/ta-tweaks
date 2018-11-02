-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

toolbar.globalicon= "TOOLBAR"
toolbar.groupicon=  "GROUP"

toolbar.TOP_TOOLBAR=      0
toolbar.LEFT_TOOLBAR=     1
toolbar.STAT_TOOLBAR=     2
toolbar.RIGHT_TOOLBAR=    3
toolbar.MINIMAP_TOOLBAR=  4
toolbar.POPUP_TOOLBAR=    5
toolbar.NTOOLBARS=        6

local tbver= toolbar.getversion()
local oldicons= tbver:match("1.0.8")

if oldicons then
 toolbar.TTBI_TB = {
  BACKGROUND  = 0,  --toolbar
  IT_NORMAL   = 0,  --button
  SEPARATOR   = 1,  --toolbar
  IT_HILIGHT  = 2,  --button/toolbar
  IT_HIPRESSED= 3,  --button/toolbar
  TAB_BACK    = 4,  --tab background
  NTAB1       = 5,  --normal tab1
  NTAB2       = 6,  --normal tab2
  NTAB3       = 7,  --normal tab3
  DTAB1       = 8,  --disabled tab1
  DTAB2       = 9,  --disabled tab2
  DTAB3       = 10, --disabled tab3
  HTAB1       = 11, --highlight tab1
  HTAB2       = 12, --highlight tab2
  HTAB3       = 13, --highlight tab3
  ATAB1       = 14, --active tab1
  ATAB2       = 15, --active tab2
  ATAB3       = 16, --active tab3
  TAB_NSL     = 17, --tab scroll left
  TAB_NSR     = 18, --tab scroll right
  TAB_HSL     = 19, --tab scroll left
  TAB_HSR     = 20, --tab scroll right
  TAB_NCLOSE  = 21, --normal close button
  TAB_HCLOSE  = 22, --highlight close button
  TAB_CHANGED = 23, --changed indicator
  TXT_HIL1    = 24, --highlight text button1
  TXT_HIL2    = 25, --highlight text button2
  TXT_HIL3    = 26, --highlight text button3
  TXT_HPR1    = 27, --hi-pressed text button1
  TXT_HPR2    = 28, --hi-pressed text button2
  TXT_HPR3    = 29, --hi-pressed text button3
  HINORMAL    = 30, --normal button back
  TXT_NOR1    = 31, --normal text button1 back
  TXT_NOR2    = 32, --normal text button2 back
  TXT_NOR3    = 33, --normal text button3 back
  TXT_NOR4    = 34, --replace TTBI_TB_TXT_NOR3 (add a drop down button at the end)
  TXT_HIL4    = 35, --replace TTBI_TB_TXT_HIL3 (add a drop down button at the end)
  TXT_HPR4    = 36, --replace TTBI_TB_TXT_HPR3 (add a drop down button at the end)
  N           = 37
 }
else
 toolbar.TTBI_TB = {
--TTBI_TB_BACK_BASE       0
  BACKGROUND    = 0,    --item/toolbar
  IT_NORMAL     = 1,    --item
  IT_DISABLED   = 2,    --item
  IT_HILIGHT    = 3,    --item
  IT_HIPRESSED  = 4,    --item
  IT_SELECTED   = 5,    --item
--TTBI_TB_SEP_BASE        6
  SEPARATOR     = 7,    --toolbar
--TTBI_TB_BUTTON_BASE     12
  BUT_NORMAL    = 13,   --default button
  BUT_HILIGHT   = 15,   --default button
  BUT_HIPRESSED = 16,   --default button
--TTBI_TB_TAB_BASE        18
  TAB_BACK      = 18,   --tab background
  TAB_NORMAL    = 19,   --normal tab1
  TAB_DISABLED  = 20,   --disabled tab2
  TAB_HILIGHT   = 21,   --highlight tab3
  TAB_ACTIVE    = 23,   --active tab3
--TTBI_TB_TAB_SL_BASE     24
  TAB_NSL       = 25,   --tab scroll left
  TAB_HSL       = 28,   --tab scroll left
--TTBI_TB_TAB_SR_BASE     30
  TAB_NSR       = 31,   --tab scroll right
  TAB_HSR       = 34,   --tab scroll right
--TTBI_TB_TAB_CLOSE_BASE  36
  TAB_NCLOSE    = 37,   --normal close button
  TAB_HCLOSE    = 40,   --highlight close button
--TTBI_TB_TAB_CHG_BASE    42
  TAB_CHANGED   = 43,   --changed indicator
--TTBI_TB_DDBUT_BASE      48
  DDBUT_NORMAL  = 49,   --drop down button
  DDBUT_HILIGHT = 51,   --drop down button
  DDBUT_HIPRESSED=52,   --drop down button
  N             = 54
 }
end
