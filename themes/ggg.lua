-- Solarized theme for Textadept (http://foicica.com/textadept/)
-- Theme author: Ethan Schoonover (http://ethanschoonover.com/solarized)
-- Base16 (https://github.com/chriskempson/base16)
-- Build with Base16 Builder (https://github.com/chriskempson/base16-builder)
-- Repository: https://github.com/rgieseke/ta-themes

local buffer = buffer
local property, property_int = buffer.property, buffer.property_int

property['color.base00'] = 0x362b00 --caret / back calltips
property['color.base01'] = 0x423607
property['color.base02'] = 0x101000 --texto / operadores / select-back
property['color.base03'] = 0x837b65 --indent-guide
property['color.base04'] = 0x6D6D3E --comentarios / back marks
property['color.base05'] = 0x0a70ff --fore numeros de linea / back marks selected / calltips
property['color.base06'] = 0xf5f9ff --fondo linea actual y lineas largas y embedded
property['color.base07'] = 0xd6e7ff --fondo y fore para reverse: hue=25 sat=99% light=+42%
property['color.base08'] = 0x2f32dc --variables, error, red
property['color.base09'] = 0x164bcb --ctes, numeros y tipos
property['color.base0A'] = 0x0089b5 --class, label, pre-proc
property['color.base0B'] = 0x006030 --strings, green
property['color.base0C'] = 0x98a12a --regext, [] ok
property['color.base0D'] = 0x015aee --bookmark
property['color.base0E'] = 0x800000 --funciones y keywords
property['color.base0F'] = 0x8236d3 --fore embedded
property['color.base10'] = 0xb8dcff --back linenumber

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
property['style.class'] = 'fore:%(color.base0A)'
property['style.comment'] = 'fore:%(color.base04)'
property['style.constant'] = 'fore:%(color.base09)'
property['style.error'] = 'fore:%(color.base08),italics'
property['style.function'] = 'fore:%(color.base0E)'
property['style.keyword'] = 'fore:%(color.base0E)'
property['style.label'] = 'fore:%(color.base0A)'
property['style.number'] = 'fore:%(color.base09)'
property['style.operator'] = 'fore:%(color.base02)'
property['style.regex'] = 'fore:%(color.base0C)'
property['style.string'] = 'fore:%(color.base0B)'
property['style.preprocessor'] = 'fore:%(color.base0A)'
property['style.type'] = 'fore:%(color.base09)'
property['style.variable'] = 'fore:%(color.base08)'
property['style.whitespace'] = ''
property['style.embedded'] = 'fore:%(color.base0F),back:%(color.base06)'
property['style.identifier'] = '%(style.nothing)'

-- Predefined styles.
property['style.default'] = 'font:%(font),size:%(fontsize),'..
                            'fore:%(color.base02),back:%(color.base07)'
property['style.linenumber'] = 'fore:%(color.base05),back:%(color.base10)'
property['style.bracelight'] = 'fore:%(color.base0C),underlined'
property['style.bracebad'] = 'fore:%(color.base08)'
property['style.controlchar'] = '%(style.nothing)'
property['style.indentguide'] = 'fore:%(color.base03)'
property['style.calltip'] = 'fore:%(color.base05),back:%(color.base00)'

-- Multiple Selection and Virtual Space.
--buffer.additional_sel_alpha =
--buffer.additional_sel_fore =
--buffer.additional_sel_back =
--buffer.additional_caret_fore =

-- Caret and Selection Styles.
buffer:set_sel_fore(true, property_int['color.base07'])
buffer:set_sel_back(true, property_int['color.base02'])
--buffer.sel_alpha =
buffer.caret_fore = property_int['color.base00']
buffer.caret_line_back = property_int['color.base06']
--buffer.caret_line_back_alpha =

--GGG--
buffer.caret_width= 2
buffer.tab_width= 4
buffer.use_tabs = false


-- Fold Margin.
buffer:set_fold_margin_colour(true, property_int['color.base07'])
buffer:set_fold_margin_hi_colour(true, property_int['color.base07'])

-- Markers.
local MARK_BOOKMARK, t_run = textadept.bookmarks.MARK_BOOKMARK, textadept.run
--buffer.marker_fore[MARK_BOOKMARK] = property_int['color.base05']
buffer.marker_back[MARK_BOOKMARK] = property_int['color.base0D']
--buffer.marker_fore[t_run.MARK_WARNING] = property_int['color.base05']
buffer.marker_back[t_run.MARK_WARNING] = property_int['color.base0A']
--buffer.marker_fore[t_run.MARK_ERROR] = property_int['color.base05']
buffer.marker_back[t_run.MARK_ERROR] = property_int['color.base08']
for i = 25, 31 do -- fold margin markers
  buffer.marker_fore[i] = property_int['color.base07']
  buffer.marker_back[i] = property_int['color.base04']
  buffer.marker_back_selected[i] = property_int['color.base05']
end

-- Long Lines.
buffer.edge_colour = property_int['color.base06']

-- Add red and green for diff lexer.
property['color.red'] = property['color.base08']
property['color.green'] = property['color.base0B']
