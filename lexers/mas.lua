-- MAS Assembly LPeg lexer.

local l = require('lexer')
local token, word_match = l.token, l.word_match
local P, R, S = lpeg.P, lpeg.R, lpeg.S

local M = {_NAME = 'mas'}

-- Whitespace.
local ws = token(l.WHITESPACE, l.space^1)

-- Comments.
local comment = token(l.COMMENT, ';' * l.nonnewline^0)

-- Strings.
local sq_str = l.delimited_range("'", true)
local dq_str = l.delimited_range('"', true)
local string = token(l.STRING, sq_str + dq_str)

-- Numbers.
local number = token(l.NUMBER, l.float + l.integer * S('hqb')^-1)

-- Preprocessor.
local preproc_word = word_match({
  '$elseif',
  '$endif',
  '$if',
  '$ifnot',
  '$include',
  '$set',
  '$setnot',
  'db',
  'double',
  'ds',
  'dw',
  'equ',
  'float',
  'org',
}, nil, true)  --ignore case
local preproc = token(l.PREPROCESSOR, preproc_word)

-- Keywords.
local control = token('control', word_match({
  'break',
  'case',
  'continue',
  'default',
  'do',
  'else',
  'if',
  'switch',
  'while',
}, nil, true))  --ignore case
local style_control= 'fore:#000080,bold'

-- Instructions.
-- awk '{print $1}'|uniq|tr '[:upper:]' '[:lower:]'|
-- lua -e "for l in io.lines() do print(\"'\"..l..\"',\") end"|fmt -w 78
local instruction = token('instruction', word_match({
  'adc', 'add', 'aix', 'and', 'asl', 'asla', 'aslx', 'asr', 'asra', 'asrx',
  'bcc', 'bclr', 'bcs', 'beq', 'bge', 'bgt', 'bhcc', 'bhcs', 'bhi', 'bhs',
  'bih', 'bil', 'bit', 'ble', 'blo', 'bls', 'blt', 'bmc', 'bmi', 'bms', 'bne',
  'bpl', 'bra', 'brclr', 'brn', 'brset', 'bset', 'bsr',
  'cbeq', 'cbeqa', 'cbeqx', 'clc', 'cli', 'clr', 'clra', 'clrh', 'clrx', 'cmp',
  'com', 'cphx', 'cpx', 'coma', 'comx',
  'daa', 'dbnz', 'dbnza', 'dbnzx', 'dec', 'deca', 'decx', 'div',
  'eor',
  'inc', 'inca', 'incx',
  'jmp', 'jsr',
  'lda', 'ldhx', 'ldx', 'lsl', 'lsla', 'lslx', 'lsr', 'lsra', 'lsrx',
  'mov', 'mul',
  'neg', 'nega', 'negx', 'nop', 'nsa',
  'ora',
  'rol', 'rola', 'rolx', 'ror', 'rora', 'rorx', 'rsp', 'rts',
  'sbc', 'sec', 'sei', 'sta', 'sthx', 'stx', 'sub',
  'tap', 'tax', 'tpa', 'tst', 'tsta', 'tstx', 'tsx', 'txa', 'txs',
}, nil, true))  --ignore case

-- opcodes hilited.
local hilited_op = word_match({
  'ais',
  'psha',
  'pshh',
  'pshx',
  'pula',
  'pulh',
  'pulx',
  'rti',
  'stop',
  'swi',
  'wait',
}, nil, true)  --ignore case
local hi_op = token('hi_op', hilited_op)
local style_hi_op= 'fore:#800000'

local word = (l.alpha + S('$._?')) * (l.alnum + S('$._?#@~'))^0

-- Labels.
local label = token(l.LABEL, word * ':')

-- Identifiers.
local identifier = token(l.IDENTIFIER, word)

-- Constants.
local constants = word_match({
  '(double)',
  '(float)',
}, nil, true)  --ignore case
local constant = token(l.CONSTANT, constants + '$' * P('$')^-1 * -identifier)

-- Operators.
local operator = token(l.OPERATOR, S('+-/*%<>!=^&|~:,()[]'))

M._rules = {
  {'whitespace', ws},
  {'control', control},
  {'instruction', instruction},
  {'preproc', preproc},
  {'hi_op', hi_op},
  {'constant', constant},
  {'label', label},
  {'identifier', identifier},
  {'string', string},
  {'comment', comment},
  {'number', number},
  {'operator', operator},
}

M._tokenstyles = {
  hi_op   = style_hi_op,
  control = style_control,
  instruction = l.STYLE_FUNCTION,
}

--M._foldsymbols = {
--  _patterns = {'%l+', '//'},
--  [l.PREPROCESSOR] = {
--    ['if'] = 1, endif = -1, macro = 1, endmacro = -1, rep = 1, endrep = -1,
--    ['while'] = 1, endwhile = -1,
--  },
--  [l.KEYWORD] = {struc = 1, endstruc = -1},
--  [l.COMMENT] = {['//'] = l.fold_line_comments('//')}
--}
M._FOLDBYINDENTATION = true

return M
