-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.

toolbar.globalicon= "TOOLBAR"
toolbar.groupicon=  "GROUP"

toolbar.TOP_TOOLBAR=      0
toolbar.LEFT_TOOLBAR=     1
toolbar.STAT_TOOLBAR=     2
toolbar.RIGHT_TOOLBAR=    3
toolbar.MINIMAP_TOOLBAR=  4
toolbar.RESULTS_TOOLBAR=  5
if tbh_scroll then
  --horizonal scrollbar toolbar IS defined
  toolbar.H_SCROLL_TOOLBAR= 6
  toolbar.FIRST_POPUP=      7
  toolbar.COMBO_POPUP=      7
  toolbar.DIALOG_POPUP=     8
  toolbar.POPUP_TOOLBAR=    9
else
  --horizonal scrollbar toolbar is NOT defined
  toolbar.FIRST_POPUP=      6
  toolbar.COMBO_POPUP=      6
  toolbar.DIALOG_POPUP=     7
  toolbar.POPUP_TOOLBAR=    8
end
toolbar.NTOOLBARS=        10

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
    VERTSCR_HILIGHT=69,
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
  MINIMAP_CLICK = -8,
  TBH_SCR_DRAW  = -9, --use only when tbh_scroll is defined
  TBH_SCR_CLICK = -10 --use only when tbh_scroll is defined
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
  HIDE_BLOCK    = 0x00002000,   --hide a block of items under this item (tree/list expand-collapse)
  IS_TRESIZE    = 0x00004000,   --the button resize the toolbar
  ANCHOR_END    = 0x00008000,   --anchor the item's right (x2) instead of it's left (x1)
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
  TB_VERTICAL   = 0x00000001,   --vertical toolbar
  TB_VISIBLE    = 0x00000002,   --it's visible
  TB_V_LAYOUT   = 0x00000004,   --put groups in a vertical layout
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

toolbar.KEY = {
  BACKSPACE     = 65288,
  RETURN        = 65293,
  ESCAPE        = 65307,
  HOME          = 65360,
  LEFT          = 65361,
  UP            = 65362,
  RIGHT         = 65363,
  DOWN          = 65364,
  PG_UP         = 65365,
  PG_DWN        = 65366,
  END           = 65367,
  INSERT        = 65379,
  KPRETURN      = 65421, --key pad Return (Linux)

  KP_MULT       = 65450, --key pad *
  KP_PLUS       = 65451, --key pad +
--KP_COMMA      = 65452, --key pad ,
  KP_MINUS      = 65453, --key pad -
  KP_POINT      = 65454, --key pad .
  KP_DIV        = 65455, --key pad /
  KP0           = 65456, --key pad 0
  KP9           = 65465, --key pad 9

  MULT          = 42,    --regular *
  PLUS          = 43,    --regular +
  COMMA         = 44,    --regular ,
  MINUS         = 45,    --regular -
  POINT         = 46,    --regular .
  DIV           = 47,    --regular /
  _0            = 48,    --regular 0
  _9            = 57,    --regular 9
  DELETE        = 65535
}

toolbar.ANCHOR = {
  --horizontal
  POP_R_IT_L    = 0,  --popup right at item left
  POP_L_IT_L    = 1,  --popup left  at item left
  HCENTER       = 2,  --align centers
  POP_R_IT_R    = 3,  --popup right at item right
  POP_L_IT_R    = 4,  --popup left  at item right

  --vertical
  POP_B_IT_T    = 0,  --popup bottom at item top
  POP_T_IT_T    = 8,  --popup top    at item top
  VCENTER       = 16, --align centers
  POP_B_IT_B    = 24, --popup bottom at item bottom
  POP_T_IT_B    = 32, --popup top    at item bottom
}

toolbar.GETVER = {    --toolbar.getversion(x)
  TATOOLBAR     = 0,  --tatoolbar version: "1.1.8 (Dec 14 2020)"
  COMPILED      = 1,  --compilation date:  "Dec 14 2020"
  TATARGET      = 2,  --target TA version: "11.0"
  GTK           = 3,  --GTK version:       "2.24.32"
  N_FONTS       = 4,  --number of installed fonts: "175"
  FONT_BASE     = 100 --name of the first font (100 .. 100+N_FONTS-1)
}

toolbar.DLGBUT ={
--dialog buttons flags
  CLOSE         = 0x00000001,   --close the dialog before calling the callback
  RELOAD        = 0x00000002,   --reload the list after calling the callback
  LEFT          = 0x00000004,   --left align text
  BOLD          = 0x00000008,   --bold text
  DROPDOWN      = 0x00000010    --show a drop down arrow
}

toolbar.DEFAULT_FONT= "(default)"

local font_list= {}
local font_nums= {}

function toolbar.font_support()
  --check if tatoolbar was compiled with font support functions
  return (toolbar.getversion(toolbar.GETVER.N_FONTS) ~= toolbar.getversion(toolbar.GETVER.TATOOLBAR)) and ((tonumber(toolbar.getversion(toolbar.GETVER.N_FONTS)) or 0) > 0)
end

function toolbar.get_font_list()
  if #font_list < 1 and toolbar.font_support() then
    font_list[1]= toolbar.DEFAULT_FONT
    local nfonts= tonumber(toolbar.getversion(toolbar.GETVER.N_FONTS)) or 0 --number of available fonts
    if nfonts > 0 then
      local i --sort by font name
      for i=1, nfonts do
        local fontn= toolbar.getversion(i+toolbar.GETVER.FONT_BASE)
        font_list[#font_list+1]= fontn
        font_nums[fontn]= i
      end
      table.sort(font_list)
    end
  end
  return font_list
end

function toolbar.get_font_num(fontname)
  if #font_list < 1 then toolbar.get_font_list() end
  return font_nums[fontname] or 0
end

function toolbar.get_font_name(nfont)
  if #font_list < 1 then toolbar.get_font_list() end
  if nfont > 0 and nfont <= #font_list then return toolbar.getversion(nfont+toolbar.GETVER.FONT_BASE) end
  return toolbar.DEFAULT_FONT
end
