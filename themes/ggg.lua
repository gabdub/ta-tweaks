local buffer = buffer
local property, property_int = buffer.property, buffer.property_int

--current line
property['color.curr_line_back']  = 0xf5f9ff
property['color.caret']           = 0x362b00
--default text
property['color.text_fore']       = 0x101000
property['color.text_back']       = 0xd6e7ff
--selection
property['color.selection_fore']  = 0xd6e7ff
property['color.selection_back']  = 0x101000
--calltips
property['color.calltips_fore']   = 0x0a70ff
property['color.calltips_back']   = 0x362b00
--linenum/markers
property['color.linenum_fore']    = 0x0a70ff
property['color.linenum_back']    = 0xb8dcff
property['color.folding']         = 0x6D6D3E
property['color.folding_sel']     = 0x0a70ff
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

-- Default font.
--property['font'], property['fontsize'] = 'Bitstream Vera Sans Mono', 11
property['font'], property['fontsize'] = 'Ubuntu Mono', 13
if WIN32 then
  property['font'], property['fontsize'] = 'DejaVu Sans Mono', 11
elseif OSX then
  property['font'], property['fontsize'] = 'Monaco', 12
end

-- Token styles.
property['style.nothing'] = ''
property['style.whitespace'] = ''
property['style.identifier'] = ''
property['style.class'] = 'fore:%(color.class)'
property['style.comment'] = 'fore:%(color.comment)'
property['style.constant'] = 'fore:%(color.constant)'
property['style.error'] = 'fore:%(color.error),italics'
property['style.function'] = 'fore:%(color.function)'
property['style.keyword'] = 'fore:%(color.keyword)'
property['style.label'] = 'fore:%(color.label)'
property['style.number'] = 'fore:%(color.number)'
property['style.operator'] = 'fore:%(color.operator)'
property['style.regex'] = 'fore:%(color.regex)'
property['style.string'] = 'fore:%(color.string)'
property['style.preprocessor'] = 'fore:%(color.preprocessor)'
property['style.type'] = 'fore:%(color.type)'
property['style.variable'] = 'fore:%(color.variable)'
property['style.embedded'] = 'fore:%(color.embedded),back:%(color.curr_line_back)'

-- Predefined styles.
property['style.default'] = 'font:%(font),size:%(fontsize),fore:%(color.text_fore),back:%(color.text_back)'
property['style.linenumber'] = 'fore:%(color.linenum_fore),back:%(color.linenum_back)'
property['style.bracelight'] = 'fore:%(color.brace_ok),underlined'
property['style.bracebad'] = 'fore:%(color.error)'
property['style.controlchar'] = '%(style.nothing)'
property['style.indentguide'] = 'fore:%(color.indentguide)'
property['style.calltip'] = 'fore:%(color.calltips_fore),back:%(color.color.calltips_back)'

-- Caret and Selection Styles.
buffer:set_sel_fore(true, property_int['color.selection_fore'])
buffer:set_sel_back(true, property_int['color.selection_back'])
--buffer.sel_alpha =
buffer.caret_fore = property_int['color.caret']
buffer.caret_line_back = property_int['color.curr_line_back']
--buffer.caret_line_back_alpha =
buffer.caret_width= 2
buffer.tab_width= 4
buffer.use_tabs = false

-- Fold Margin.
buffer:set_fold_margin_colour(true, property_int['color.text_back'])
buffer:set_fold_margin_hi_colour(true, property_int['color.text_back'])

-- Markers.
local MARK_BOOKMARK, t_run = textadept.bookmarks.MARK_BOOKMARK, textadept.run
buffer.marker_back[MARK_BOOKMARK] = property_int['color.bookmark']
buffer.marker_back[t_run.MARK_WARNING] = property_int['color.warning']
buffer.marker_back[t_run.MARK_ERROR] = property_int['color.error']
for i = 25, 31 do -- fold margin markers
  buffer.marker_fore[i] = property_int['color.text_back']
  buffer.marker_back[i] = property_int['color.folding']
  buffer.marker_back_selected[i] = property_int['color.folding_sel']
end

-- Long Lines.
buffer.edge_colour = property_int['color.curr_line_back']
