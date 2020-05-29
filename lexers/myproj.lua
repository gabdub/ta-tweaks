-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
-- myproj LPeg lexer.

local l = require('lexer')
local token, word_match = l.token, l.word_match
local P, R, S = lpeg.P, lpeg.R, lpeg.S

local M = {_NAME = 'myproj'}

-- Whitespace.
local ws = token(l.WHITESPACE, l.space^1)

local hidden = token('hidden', '::' * l.nonnewline^0)
local style_hidden = 'notvisible'

local group1 = token('group1', '[' * (l.nonnewline - ']')^0 * ']' )
local style_group1 = 'fore:$(color.variable),bold'

local group2 = token('group2', '(' * (l.nonnewline - ')')^0 * ')' )
local style_group2 = 'fore:$(color.function),bold'

local group3 = token('group3', '<' * (l.nonnewline - '>')^0 * '>' )
local style_group3 = 'fore:$(color.type),bold'

local extension = token('extension', '.' * l.word^0 )
local style_extension = 'fore:$(color.comment),italics'

--search view
local search_line = token('search_line', '@' * l.space^0 * l.digit^1 * ':' * l.nonnewline^0)
local style_search_line = 'fore:$(color.comment)'


M._rules = {
  {'whitespace',  ws},
  {'hidden',      hidden},
  {'group1',      group1},
  {'group2',      group2},
  {'group3',      group3},
  {'extension',   extension},
  {'search_line', search_line},
}

M._tokenstyles = {
   hidden   = style_hidden,
   group1   = style_group1,
   group2   = style_group2,
   group3   = style_group3,
   extension= style_extension,
   search_line= style_search_line,
}

M._FOLDBYINDENTATION = true
M._LEXBYLINE = true

return M
