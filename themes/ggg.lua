-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
local buffer = buffer
local property, property_int = buffer.property, buffer.property_int

--COLORS--
dofile(_USERHOME..'/themes/colors.lua')

--Default font
property['font'], property['fontsize'] = 'Ubuntu Mono', 13
if WIN32 then
  property['font'], property['fontsize'] = 'DejaVu Sans Mono', 11
elseif OSX then
  property['font'], property['fontsize'] = 'Monaco', 12
end

--Predefined styles
property['style.default'] = 'font:%(font),size:%(fontsize),fore:%(color.text_fore),back:%(color.text_back)'
--property['style.controlchar'] = ''

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
--view.additional_sel_alpha =
--view.additional_sel_fore =
--view.additional_sel_back =
--view.additional_caret_fore =

property['style.line_number'] = 'fore:%(color.linenum_fore),back:%(color.linenum_back)'
property['style.indent_guide'] = 'fore:%(color.indentguide)'
property['style.call_tip'] = 'fore:%(color.calltips_fore),back:%(color.calltips_back)'
property['style.fold_display_text'] = 'fore:%(color.text_fore),back:%(color.text_back)'

--Caret and Selection Styles
view:set_sel_fore(true, property_int['color.selection_fore'])
view:set_sel_back(true, property_int['color.selection_back'])
--view.sel_alpha =
view.caret_fore = property_int['color.caret']
view.caret_line_back = property_int['color.curr_line_back']
--view.caret_line_back_alpha =

--Fold Margin
view:set_fold_margin_color(true, property_int['color.text_back'])
view:set_fold_margin_hi_color(true, property_int['color.text_back'])

--Long Lines
view.edge_color = property_int['color.curr_line_back']

-- Markers.
--view.marker_fore[textadept.bookmarks.MARK_BOOKMARK] = property_int['color.text_fore']
view.marker_back[textadept.bookmarks.MARK_BOOKMARK] = property_int['color.bookmark']
--view.marker_fore[textadept.run.MARK_WARNING] = property_int['color.text_fore']
view.marker_back[textadept.run.MARK_WARNING] = property_int['color.warning']
--view.marker_fore[textadept.run.MARK_ERROR] = property_int['color.text_fore']
view.marker_back[textadept.run.MARK_ERROR] = property_int['color.error']

for i = buffer.MARKNUM_FOLDEREND, buffer.MARKNUM_FOLDEROPEN do -- fold margin
  view.marker_fore[i] = property_int['color.text_back']
  view.marker_back[i] = property_int['color.markers']
  view.marker_back_selected[i] = property_int['color.markers_sel']
end

-- Indicators.
view.indic_fore[ui.find.INDIC_FIND] = property_int['color.find']
view.indic_alpha[ui.find.INDIC_FIND] = 128
view.indic_fore[textadept.editing.INDIC_BRACEMATCH] = property_int['color.brace_ok']
view.indic_fore[textadept.editing.INDIC_HIGHLIGHT] = property_int['color.hilight']
view.indic_alpha[textadept.editing.INDIC_HIGHLIGHT] = 128
view.indic_fore[textadept.snippets.INDIC_PLACEHOLDER] = property_int['color.placeholder']

-- Call tips.
view.call_tip_fore_hlt = property_int['color.light_blue']

--solve underscore visibility after updating to Ubuntu 20.04
buffer.extra_descent= 1

-- User overrides (thanks Lukas)
do
  local thm = _USERHOME .. '/themes/ggg.' .. (os.getenv("USERNAME") or os.getenv("USER") or '_') .. ".lua"

  if lfs.attributes(thm) then
    local fun = dofile(thm)
    if type(fun) == "function" then fun(property) end
  end
end
