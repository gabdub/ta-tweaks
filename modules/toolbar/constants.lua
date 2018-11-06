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
