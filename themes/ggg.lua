local buffer = buffer
local property, property_int = buffer.property, buffer.property_int

--COLORS--
--current line
property['color.curr_line_back']  = 0xf5f9ff
property['color.caret']           = 0x362b00
--default text
property['color.text_fore']       = 0x101000
property['color.text_back']       = 0xd6e7ff
--selection
property['color.selection_fore']  = 0x905090
property['color.selection_back']  = 0x88acdf
property['color.hilight']         = 0xa8ccff
property['color.placeholder']     = 0x88acdf
property['color.find']            = 0xa8ccff
--calltips
property['color.calltips_fore']   = 0x0a70ff
property['color.calltips_back']   = 0x362b00
--linenum/markers
property['color.linenum_fore']    = 0x0a70ff
property['color.linenum_back']    = 0xb8dcff
property['color.markers']         = 0x6D6D3E --folding
property['color.markers_sel']     = 0x0a70ff
property['color.bookmark']        = 0x015aee
property['color.warning']         = 0x0089b5
property['color.error']           = 0x2f32dc
property['color.indentguide']     = 0x837b65
--project
property['color.prj_sel_bar']     = 0x88acdf --with focus
property['color.prj_sel_bar_nof'] = 0xa8ccff --without focus
--syntax highlighting
property['color.comment']         = 0x6D6D3E
property['color.variable']        = 0x2f32dc
property['color.constant']        = 0x164bcb
property['color.number']          = 0x164bcb
property['color.type']            = 0x164bcb
property['color.class']           = 0x0089b5
property['color.label']           = 0x0089b5
property['color.preprocessor']    = 0x0089b5
property['color.string']          = 0x006030
property['color.regex']           = 0x98a12a
property['color.brace_ok']        = 0x98a12a
property['color.function']        = 0x800000
property['color.keyword']         = 0x800000
property['color.embedded']        = 0x8236d3
property['color.operator']        = 0x101000
--Diff lexer
property['color.red']             = 0x2f32dc
property['color.green']           = 0x006030

--Default font
property['font'], property['fontsize'] = 'Ubuntu Mono', 13
if WIN32 then
  property['font'], property['fontsize'] = 'DejaVu Sans Mono', 11
elseif OSX then
  property['font'], property['fontsize'] = 'Monaco', 12
end

--Predefined styles
property['style.default'] = 'font:%(font),size:%(fontsize),fore:%(color.text_fore),back:%(color.text_back)'
property['style.linenumber'] = 'fore:%(color.linenum_fore),back:%(color.linenum_back)'
--property['style.controlchar'] = ''
property['style.indentguide'] = 'fore:%(color.indentguide)'
property['style.calltip'] = 'fore:%(color.calltips_fore),back:%(color.color.calltips_back)'

--Token styles
property['style.class'] = 'fore:%(color.class)'
property['style.comment'] = 'fore:%(color.comment)'
property['style.constant'] = 'fore:%(color.constant)'
property['style.embedded'] = 'fore:%(color.embedded),back:%(color.curr_line_back)'
property['style.error'] = 'fore:%(color.error),italics'
property['style.function'] = 'fore:%(color.function)'
property['style.identifier'] = ''
property['style.keyword'] = 'fore:%(color.keyword)'
property['style.label'] = 'fore:%(color.label)'
property['style.number'] = 'fore:%(color.number)'
property['style.operator'] = 'fore:%(color.operator)'
property['style.preprocessor'] = 'fore:%(color.preprocessor)'
property['style.regex'] = 'fore:%(color.regex)'
property['style.string'] = 'fore:%(color.string)'
property['style.type'] = 'fore:%(color.type)'
property['style.variable'] = 'fore:%(color.variable)'
property['style.whitespace'] = ''

--Multiple Selection and Virtual Space
--buffer.additional_sel_alpha =
--buffer.additional_sel_fore =
--buffer.additional_sel_back =
--buffer.additional_caret_fore =

--Caret and Selection Styles
buffer:set_sel_fore(true, property_int['color.selection_fore'])
buffer:set_sel_back(true, property_int['color.selection_back'])
--buffer.sel_alpha =
buffer.caret_fore = property_int['color.caret']
buffer.caret_line_back = property_int['color.curr_line_back']
--buffer.caret_line_back_alpha =

--Fold Margin
buffer:set_fold_margin_colour(true, property_int['color.text_back'])
buffer:set_fold_margin_hi_colour(true, property_int['color.text_back'])

--Markers
local MARK_BOOKMARK = textadept.bookmarks.MARK_BOOKMARK
--buffer.marker_fore[MARK_BOOKMARK] = property_int['color.text_fore']
buffer.marker_back[MARK_BOOKMARK] = property_int['color.bookmark']
--buffer.marker_fore[textadept.run.MARK_WARNING] = property_int['color.text_fore']
buffer.marker_back[textadept.run.MARK_WARNING] = property_int['color.warning']
--buffer.marker_fore[textadept.run.MARK_ERROR] = property_int['color.text_fore']
buffer.marker_back[textadept.run.MARK_ERROR] = property_int['color.error']
for i = 25, 31 do -- fold margin markers
  buffer.marker_fore[i] = property_int['color.text_back']
  buffer.marker_back[i] = property_int['color.markers']
  buffer.marker_back_selected[i] = property_int['color.markers_sel']
end

--Indicators
buffer.indic_fore[ui.find.INDIC_FIND] = property_int['color.find']
buffer.indic_alpha[ui.find.INDIC_FIND] = 255
local INDIC_BRACEMATCH = textadept.editing.INDIC_BRACEMATCH
buffer.indic_fore[INDIC_BRACEMATCH] = property_int['color.brace_ok']
local INDIC_HIGHLIGHT = textadept.editing.INDIC_HIGHLIGHT
buffer.indic_fore[INDIC_HIGHLIGHT] = property_int['color.hilight']
buffer.indic_alpha[INDIC_HIGHLIGHT] = 255
local INDIC_PLACEHOLDER = textadept.snippets.INDIC_PLACEHOLDER
buffer.indic_fore[INDIC_PLACEHOLDER] = property_int['color.placeholder']

--Call tips
--buffer.call_tip_fore_hlt = property_int['color.light_blue']

--Long Lines
buffer.edge_colour = property_int['color.curr_line_back']
