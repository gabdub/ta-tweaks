local Util = Util

-- Alt+1 = ($=cursor position) TYPE
-- /*
--      $:
--
-- */
local function qt_cfun_comm()
  Util.type_before_after("/*\n    ", ":\n      \n*/\n")
end

-- Alt+2 = ($=cursor position) TYPE
-- /* $ */
local function qt_c_comm()
  Util.type_before_after("/* ", " */")
end

-- Alt+3 = ($=cursor position) TYPE
-- #define $
local function qt_c_define()
  Util.type_before_after("#define ", "")
end


-- Alt+4 = ($=cursor position) TYPE
-- /* TO DO: $ */
local function qt_c_todo()
  Util.type_before_after("/* TO DO: ", " */")
end

-- Alt+5 = ($=cursor position) TYPE
--/*    |
--      |
--     \|/   */
-- $
local function qt_c_switchcont()
  Util.type_before_after("/*    |\n      |\n     \\|/   */\n", "")
end

-- Alt+0 = ($=cursor position) TYPE
-- /* ==....== */
-- $
local function qt_c_sep_line()
  Util.type_before_after("/* ============================================================================= */\n", "")
end

-- Alt+7 = prefix type comment - uncomment in column #1
local function multiline_comment()
  local comment = textadept.editing.comment_string[buffer:get_lexer(true)] or ''
  local prefix, suffix = comment:match('^([^|]+)|?([^|]*)$')
  if not prefix then return end
  if prefix == '/*' then
    prefix= '//'
  end
  local n1= buffer:line_from_position(buffer.current_pos)
  local n2= n1
  if (buffer.selections > 1) or (buffer.selection_n_start[0] ~= buffer.selection_n_end[0]) then
    --if something is selected use the selected line range
    n1=buffer:line_from_position(buffer.selection_n_start[0])
    n2=buffer:line_from_position(buffer.selection_n_end[0])
  end
  local uncomm= true
  local iscomm= '^'..Util.escape_match(prefix)
  for i= n1, n2 do
    local cl= buffer:get_line(i)
    if not cl:match(iscomm) then
      uncomm= false
      break
    end
  end
  buffer:begin_undo_action()
  if uncomm then
    --all lines already commented: uncomment them
    for i= n1, n2 do
      buffer:goto_line(i)
      buffer:delete_range(buffer.current_pos,2)
    end
    ui.statusbar_text= ""..(n2-n1+1).." lines uncommented"
  else
    for i= n1, n2 do
      buffer:goto_line(i)
      buffer.add_text(buffer, prefix)
    end
    ui.statusbar_text= ""..(n2-n1+1).." lines commented"
  end
  if n1 ~= n2 then
    buffer:set_sel( buffer:position_from_line(n1), buffer.line_end_position[n2])
  end
  buffer:end_undo_action()
end

-- Alt+9 = MULTILINE TYPER
-- [BEFORE]....[AFTER]
-- [EMPTY]
local function multiline_typer()
  local n1=1
  local n2=buffer.line_count
  if (buffer.selections > 1) or (buffer.selection_n_start[0] ~= buffer.selection_n_end[0]) then
    --if something is selected use selected line range
    n1=buffer:line_from_position(buffer.selection_n_start[0])+1
    n2=buffer:line_from_position(buffer.selection_n_end[0])+1
  end

  local button, inputs = ui.dialogs.inputbox{
    title = 'Quick-type',
    informative_text = {'Multiline Typer', 'Before begin:', 'After end:', 'Empty lines:', 'From line:', 'To line:'},
    text = {"","","",n1,n2}
  }
  if button == 1 then
    n1=tonumber(inputs[4])-1
    n2=tonumber(inputs[5])-1
    if n2 >= n1 then
      local totne= 0
      local totem= 0
      buffer:begin_undo_action()
      if n1 < 0 then n1=0 end
      if n2 > buffer.line_count-1 then n2=buffer.line_count-1 end
      for i= n1, n2 do
        buffer:goto_line(i)
        if buffer:get_line(i):match('^[\r\n]*$') then
          buffer.add_text(buffer, inputs[3])
          totem=totem+1
        else
          buffer.add_text(buffer, inputs[1])
          buffer.goto_pos(buffer, buffer.line_end_position[i])
          buffer.add_text(buffer, inputs[2])
          totne=totne+1
        end
      end
      buffer:end_undo_action()
      ui.statusbar_text= "Modified lines: "..totem.." empty, "..totne.." non empty"
    end
  end
end

local function get_lexer()
  local GETLEXERLANGUAGE= _SCINTILLA.properties.lexer_language[1]
  return buffer:private_lexer_call(GETLEXERLANGUAGE):match('^[^/]+')
end

local function find_line(fmatch,dirf,roff)
  local r
  local curr= buffer:line_from_position(buffer.current_pos)
  if dirf then --forward
    for i = curr +1 -roff, buffer.line_count, 1 do
      if buffer:get_line(i):match(fmatch) then
        r=i+roff
        break
      end
    end
  else  --backward
    for i = curr -1 -roff, 0, -1 do
      if buffer:get_line(i):match(fmatch) then
        r=i+roff
        break
      end
    end
  end
  if r then
    if r < 0 then r= 0 end
    buffer:ensure_visible_enforce_policy(r)
    buffer:goto_line(r)
    return true
  end
  return false
end

-- Ctrl+, = GOTO previous FUNCTION/C-BLOCK BEG
-- Ctrl+. = GOTO next     FUNCTION/C-BLOCK BEG
--$nnnnnnnnn  ($=cursor position)
--{
--....
--}
--LUA version: $[....]function[ mm.www](
local function find_begin(dirf)
  local sbeg='^{'
  local roff=-1
  local lexer= get_lexer()
  if lexer == 'lua' then
    sbeg='^.*function%s*[%w_.]*%('
    roff=0
  end
  if not find_line(sbeg,dirf,roff) then
    ui.statusbar_text= 'main block begin: not found'
  end
end

-- Ctrl+; = GOTO previous FUNCTION/C-BLOCK END
-- Ctrl.: = GOTO next     FUNCTION/C-BLOCK END
--nnnnnnnnn
--{
--....
--$}          ($=cursor position)
--LUA version: $end
local function find_end(dirf)
  local send='^}'
  local lexer= get_lexer()
  if lexer == 'lua' then send='^end' end
  if not find_line(send,dirf,0) then
    ui.statusbar_text= 'main block end: not found'
  end
end

if actions then
  actions.add("prev_block_beg", 'Goto previous block begin', function() find_begin(false) end, "c,")
  actions.add("next_block_beg", 'Goto next block begin',     function() find_begin(true)  end, "c.")
  actions.add("prev_block_end", 'Goto previous block end',   function() find_end(false) end,   "c;")
  actions.add("next_block_end", 'Goto next block end',       function() find_end(true)  end,   "c:")

  actions.add("type_cfun_comm",'Quicktype: C function comment',   qt_cfun_comm,   "a1")
  actions.add("type_c_comm",   'Quicktype: C comment',            qt_c_comm,      "a2")
  actions.add("type_c_define", 'Quicktype: C define',             qt_c_define,    "a3")
  actions.add("type_c_todo",   'Quicktype: C TODO',               qt_c_todo,      "a4")
  actions.add("type_c_switchcont",'Quicktype: C switch continue', qt_c_switchcont,"a5")
  actions.add("multiline_comment",'Multiline comment',            multiline_comment,"a7")
  actions.add("type_c_sep_line",'Quicktype: C separator line',    qt_c_sep_line,  "a0")
  actions.add("multiline_typer",'Multiline typer',                multiline_typer,"a9")
else
  keys["c,"] = function() find_begin(false) end
  keys["c."] = function() find_begin(true) end
  keys["c;"] = function() find_end(false) end
  keys["c:"] = function() find_end(true) end

  keys.a1 = qt_cfun_comm
  keys.a2 = qt_c_comm
  keys.a3 = qt_c_define
  keys.a4 = qt_c_todo
  keys.a5 = qt_c_switchcont
  keys.a7 = multiline_comment
  keys.a0 = qt_c_sep_line
  keys.a9 = multiline_typer
end
