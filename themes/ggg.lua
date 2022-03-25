-- Copyright 2016-2022 Gabriel Dubatti. See LICENSE.

-- based on theme\light.lua
-- Copyright 2007-2022 Mitchell. See LICENSE.
-- Light theme for Textadept.
-- Contributions by Ana Balan.

local view, colors, styles = view, lexer.colors, lexer.styles

-- Greyscale colors.
colors.dark_black = 0x000000
colors.black = 0x1A1A1A
colors.light_black = 0x333333
colors.grey_black = 0x4D4D4D
colors.dark_grey = 0x666666
colors.grey = 0x808080
colors.light_grey = 0x999999
colors.grey_white = 0xB3B3B3
colors.dark_white = 0xCCCCCC
colors.white = 0xE6E6E6
colors.light_white = 0xFFFFFF

-- Dark colors.
colors.dark_red = 0x1A1A66
colors.dark_yellow = 0x1A6666
colors.dark_green = 0x1A661A
colors.dark_teal = 0x66661A
colors.dark_purple = 0x661A66
colors.dark_orange = 0x1A66B3
colors.dark_pink = 0x6666B3
colors.dark_lavender = 0xB36666
colors.dark_blue = 0xB3661A

-- Normal colors.
--colors.red = 0x4D4D99     --overwritten by colors.lua
--colors.yellow = 0x4D9999  --overwritten by colors.lua
--colors.green = 0x4D994D   --overwritten by colors.lua
colors.teal = 0x99994D
colors.purple = 0x994D99
colors.orange = 0x4D99E6
colors.pink = 0x9999E6
colors.lavender = 0xE69999
colors.blue = 0xE6994D

-- Light colors.
colors.light_red = 0x8080CC
colors.light_yellow = 0x80CCCC
colors.light_green = 0x80CC80
colors.light_teal = 0xCCCC80
colors.light_purple = 0xCC80CC
colors.light_orange = 0x80CCFF
colors.light_pink = 0xCCCCFF
colors.light_lavender = 0xFFCCCC
colors.light_blue = 0xFFCC80

--DEFAULT COLORS
colors.text_fore=0x101000
colors.text_back=0xFAFAFA
colors.caret=0x362b00
colors.selection_fore=0xFFFFFF
colors.selection_back=0xFF9900
colors.hilight=0xC06B00
colors.placeholder=0xC06B00
colors.find=0xFFB200
colors.calltips_fore=0xFFFFFF
colors.calltips_back=0xC06B00
colors.linenum_fore=0xA8A8A8
colors.linenum_back=0xEDEDED
colors.markers=0x4C3500
colors.markers_sel=0xC06B00
colors.bookmark=0xFFB200
colors.warning=0x0089b5
colors.error=0x2f32dc
colors.indentguide=0x4C3500
colors.prj_sel_bar_nof=0xE5E5E5
colors.prj_sel_bar=0xF9EAD8
colors.prj_open_mark=0x404040
colors.comment=0x6D6D3E
colors.variable=0x2f32dc
colors.constant=0x164bcb
colors.number=0x164bcb
colors.type=0x164bcb
colors.class=0x0089b5
colors.label=0x0089b5
colors.preprocessor=0x0089b5
colors.string=0x006030
colors.regex=0x98a12a
colors.brace_ok=0x98a12a
colors.function_=0x800000
colors.keyword=0x800000
colors.embedded=0x8236d3
colors.operator=0x101000
colors.yellow=0x7FFFFF
colors.red=0x9999FF
colors.green=0x7AE584
--LOAD CONFIGURED COLORS--
dofile(_USERHOME..'/themes/colors.lua')
if not colors.curr_line_back then colors.curr_line_back=0xF9EAD8 end  --hack: doesn't like to change more than once

-- Default font.
if not font then
  font = colors.myfont or WIN32 and 'DejaVu Sans Mono' or OSX and 'Monaco' or 'Ubuntu Mono'
end
if not size then size = WIN32 and 11 or OSX and 12 or 13 end
size= size + (tonumber(colors.myextrasize) or 0)

-- Predefined styles.
styles.default = {font = font, size = size, fore = colors.text_fore, back = colors.text_back}
styles.line_number = {fore = colors.linenum_fore, back = colors.linenum_back}
-- styles.control_char = {}
styles.indent_guide = {fore = colors.indentguide}
styles.call_tip = {fore = colors.calltips_fore, back = colors.calltips_back}
styles.fold_display_text = {fore = colors.text_fore, back = colors.text_back}

-- Token styles.
styles.class = {fore = colors.class}
styles.comment = {fore = colors.comment}
styles.constant = {fore = colors.constant}
styles.embedded = {fore = colors.embedded, back = colors.curr_line_back}
styles.error = {fore = colors.error, italics = true}
styles['function'] = {fore = colors.function_}
styles.identifier = {}
styles.keyword = {fore = colors.keyword}
styles.label = {fore = colors.label}
styles.number = {fore = colors.number}
styles.operator = {fore = colors.operator}
styles.preprocessor = {fore = colors.preprocessor}
styles.regex = {fore = colors.regex}
styles.string = {fore = colors.string}
styles.type = {fore = colors.type}
styles.variable = {fore = colors.variable}
styles.whitespace = {}

-- Element colors.
view.element_color[view.ELEMENT_SELECTION_TEXT] = colors.selection_fore
view.element_color[view.ELEMENT_SELECTION_BACK] = colors.selection_back
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_TEXT] = colors.selection_fore
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_BACK] = colors.selection_back
view.element_color[view.ELEMENT_SELECTION_SECONDARY_TEXT] = colors.selection_fore
view.element_color[view.ELEMENT_SELECTION_SECONDARY_BACK] = colors.selection_back
-- view.element_color[view.ELEMENT_SELECTION_INACTIVE_TEXT] = colors.light_black
view.element_color[view.ELEMENT_SELECTION_INACTIVE_BACK] = colors.dark_white
view.element_color[view.ELEMENT_CARET] = colors.caret
view.element_color[view.ELEMENT_CARET_ADDITIONAL] = colors.caret
view.element_color[view.ELEMENT_CARET_LINE_BACK] = colors.curr_line_back

-- Fold Margin.
view:set_fold_margin_color(true, colors.text_back)
view:set_fold_margin_hi_color(true, colors.text_back)

-- Markers.
-- view.marker_fore[textadept.bookmarks.MARK_BOOKMARK] = colors.text_back
view.marker_back[textadept.bookmarks.MARK_BOOKMARK] = colors.bookmark
-- view.marker_fore[textadept.run.MARK_WARNING] = colors.text_back
view.marker_back[textadept.run.MARK_WARNING] = colors.warning
-- view.marker_fore[textadept.run.MARK_ERROR] = colors.text_back
view.marker_back[textadept.run.MARK_ERROR] = colors.error
for i = buffer.MARKNUM_FOLDEREND, buffer.MARKNUM_FOLDEROPEN do -- fold margin
  view.marker_fore[i] = colors.text_back
  view.marker_back[i] = colors.markers
  view.marker_back_selected[i] = colors.markers_sel
end

-- Indicators.
view.indic_fore[ui.find.INDIC_FIND] = colors.find
view.indic_alpha[ui.find.INDIC_FIND] = 128
view.indic_fore[textadept.editing.INDIC_BRACEMATCH] = colors.brace_ok
view.indic_outline_alpha[textadept.editing.INDIC_BRACEMATCH] = 255
view.indic_fore[textadept.editing.INDIC_HIGHLIGHT] = colors.hilight
view.indic_alpha[textadept.editing.INDIC_HIGHLIGHT] = 128
view.indic_fore[textadept.snippets.INDIC_PLACEHOLDER] = colors.placeholder

-- Call tips.
view.call_tip_fore_hlt = colors.light_blue

-- Long Lines.
view.edge_color = colors.curr_line_back

-- Find & replace pane entries.
ui.find.entry_font = font .. ' ' .. size

----solve underscore visibility after updating to Ubuntu 20.04
buffer.extra_descent= 1

-- User overrides (thanks Lukas)
do
  local thm = _USERHOME .. '/themes/ggg.' .. (os.getenv("USERNAME") or os.getenv("USER") or '_') .. ".lua"
  if lfs.attributes(thm) then
    local fun = dofile(thm)
    if type(fun) == "function" then fun(buffer.property) end
  end
end
