-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.

toolbar.globalicon= "TOOLBAR"
toolbar.groupicon=  "GROUP"

toolbar.TOP_TOOLBAR=      0
toolbar.LEFT_TOOLBAR=     1
toolbar.STAT_TOOLBAR=     2
toolbar.RIGHT_TOOLBAR=    3
toolbar.MINIMAP_TOOLBAR=  4
toolbar.FIRST_POPUP=      5
toolbar.COMBO_POPUP=      5
toolbar.POPUP_TOOLBAR=    6
toolbar.NTOOLBARS=        7

toolbar.TTBI_TB = {
  BACK_BASE     = 0,
    BACKGROUND    = 0,    --item/toolbar
    IT_NORMAL     = 1,    --item
    IT_DISABLED   = 2,    --item
    IT_HILIGHT    = 3,    --item
    IT_HIPRESSED  = 4,    --item
    IT_SELECTED   = 5,    --item
  SEP_BASE       = 6,
    HSEPARATOR    = 7,    --horizontal separator (for vertical toolbars)
    VSEPARATOR    = 11,   --vertical separator   (for horizontal toolbars)
  BUTTON_BASE   = 12,
    BUT_NORMAL    = 13,   --default button
    BUT_HILIGHT   = 15,
    BUT_HIPRESSED = 16,
    BUT_SELECTED  = 17,
  TAB_BASE      = 18,
    TAB_BACK      = 18,   --tab background
    TAB_NORMAL    = 19,   --normal tab1
    TAB_DISABLED  = 20,   --disabled tab2
    TAB_HILIGHT   = 21,   --highlight tab3
    TAB_ACTIVE    = 23,   --active tab3
  TAB_SL_BASE   = 24,
    TAB_NSL       = 25,   --tab scroll left
    TAB_HSL       = 28,
  TAB_SR_BASE   = 30,
    TAB_NSR       = 31,   --tab scroll right
    TAB_HSR       = 34,
  TAB_CLOSE_BASE= 36,
    TAB_NCLOSE    = 37,   --normal close button
    TAB_HCLOSE    = 40,   --highlight close button
  TAB_CHG_BASE  = 42,
    TAB_CHANGED   = 43,   --changed indicator
  DDBUT_BASE    = 48,
    DDBUT_NORMAL  = 49,   --drop down button
    DDBUT_HILIGHT = 51,
    DDBUT_HIPRESSED=52,
    DDBUT_SELECTED= 53,
  CHECK_BASE    = 54,
    CHECK_OFF     = 55,   --unchecked
    CHECK_HILIGHT = 57,
    CHECK_HIPRESS = 58,
    CHECK_ON      = 59,   --checked
  RADIO_BASE    = 60,
    RADIO_OFF     = 61,   --unchecked
    RADIO_HILIGHT = 63,
    RADIO_HIPRESS = 64,
    RADIO_ON      = 65,   --checked
  VERT_SCROLL   = 66,
    VERTSCR_BACK  = 66,   --vertical scrollbar background
    VERTSCR_NORM  = 67,   --bar
  N             = 72
}

toolbar.BKCOLOR = {
  NOT_SET       = -1,
  PICKER        = -2,
  SEL_COLOR     = -3,
  SEL_COL_R     = -4,
  SEL_COL_G     = -5,
  SEL_COL_B     = -6,
  MINIMAP_DRAW  = -7,
  MINIMAP_CLICK = -8
}

toolbar.TTBF ={
--item flags
  SELECTABLE    = 0x00000001,   --accepts click
  HIDDEN        = 0x00000002,   --it's hidden
  TEXT          = 0x00000004,   --it's a text button or icon + text
  GRAYED        = 0x00000008,   --show as disabled (grayed)
  SELECTED      = 0x00000010,   --show as selected / checked / active tab (normal=selected img)
  PRESSED       = 0x00000020,   --show as pressed (background=selected img)
  CHANGED       = 0x00000040,   --show as changed
  TAB           = 0x00000080,   --it's a tab
  TEXT_LEFT     = 0x00000100,   --draw text left aligned (default = center)
  TEXT_BOLD     = 0x00000200,   --draw text in bold
  DROP_BUTTON   = 0x00000400,   --draw a drop down button at the end of a text button
  IS_SEPARATOR  = 0x00000800,   --it's a separator
  SHOW_BORDER   = 0x00001000,   --draw a border (used in text buttons)
--group flags
  GRP_SELECTABLE= 0x00000001,   --accepts click
  GRP_HIDDEN    = 0x00000002,   --it's hidden
  GRP_VERTICAL  = 0x00000004,   --it's vertical
  GRP_TABBAR    = 0x00000008,   --tabs group
  GRP_DRAGTAB   = 0x00000010,   --tab dragging enabled in TTBF_TABBAR
  GRP_AUTO      = 0x00000020,   --auto created default group
  GRP_LEFT      = 0x00000040,   --anchor group to the left
  GRP_RIGHT     = 0x00000080,   --anchor group to the right
  GRP_TOP       = 0x00000100,   --anchor group to the top
  GRP_BOTTOM    = 0x00000200,   --anchor group to the bottom
  GRP_VAR_W     = 0x00000400,   --this group has variable width
  GRP_VAR_H     = 0x00000800,   --this group has variable height
  GRP_ITEM_W    = 0x00001000,   --this group set width using items position
  GRP_ITEM_H    = 0x00002000,   --this group set height using items position
  GRP_VSCROLL   = 0x00004000,   --this group can be scrolled vertically when needed
  GRP_SHOWVSCR  = 0x00008000,   --this group shows a vertical scrollbar when needed
--toolbar flags
  TB_VERTICAL   = 0x00000001,   --it's vertical
  TB_VISIBLE    = 0x00000002,   --it's visible
}

toolbar.GRPC ={
--group control flags
  FIRST         = 0x00000001,   --no groups at the left/top
  LAST          = 0x00000002,   --no groups at the right/bottom
  ONLYME        = 0x00000003,   --exclusive row/col (FIRST and LAST)
  EXPAND        = 0x00000004,   --use all available space
  ITEMSIZE      = 0x00000008,   --use item size
  VERT_SCROLL   = 0x00000010,   --scroll items vertically but don't show a scroll bar
  SHOW_V_SCROLL = 0x00000030,   --scroll items vertically and show a scroll bar
}