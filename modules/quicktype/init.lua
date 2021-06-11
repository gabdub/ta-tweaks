-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
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

-- Alt+6 = convert hexadecimal bytes to ascii
local function convert_hex_2_ascii()
  local s, e = buffer.selection_start, buffer.selection_end
  if s ~= e then
    local txthex= buffer:text_range(s,e)
    local ascii= Util.Hex2Ascii(txthex)
    if Util.confirm('Hex2Ascii', ascii, 'Copy to clipboard?') then buffer:copy_text(ascii) end
  else
    ui.statusbar_text= "No hexadecimal chars selected"
  end
end

-- Alt+& (Shift 6) = generate S19 checksum
local function generate_s19_checksum()
  local s, e = buffer.selection_start, buffer.selection_end
  if s ~= e then
    local txthex= buffer:text_range(s,e)
    if txthex:find('^S%d') then txthex = txthex:match('^S%d(.+)$') end
    local chk=0
    for c in txthex:gmatch("%x%x") do
      chk= chk + tonumber(c, 16)
    end
    local schk= string.format("%02X", 255 - (chk & 255))
    if Util.confirm('S19 Checksum', 'Checksum= '..schk, 'Copy to clipboard?') then buffer:copy_text(schk) end
  else
    ui.statusbar_text= "No hexadecimal chars selected"
  end
end

local function get_sel_linerange(all_lines)
  local n1, n2
  if all_lines then
    n1= 1
    n2= buffer.line_count
  else  --current line
    n1= buffer:line_from_position(buffer.current_pos)
    n2= n1
  end
  local s, e= buffer.selection_n_start[1], buffer.selection_n_end[1]
  if (buffer.selections > 1) or (s ~= e) then
    --if something is selected use the selected line range
    n1= buffer:line_from_position(s)
    n2= buffer:line_from_position(e)
    if n2 > n1 and buffer.column[e] == 0 then n2=n2-1 end
  end
  return n1, n2
end

-- Alt+7 = prefix type comment - uncomment in column #1
local function multiline_comment()
  local comment = textadept.editing.comment_string[buffer:get_lexer(true)] or ''
  local prefix, suffix = comment:match('^([^|]+)|?([^|]*)$')
  if not prefix then return end
  if prefix == '/*' then
    prefix= '//'
  end
  local n1, n2= get_sel_linerange(false) --current or selected lines

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
      buffer:delete_range(buffer.current_pos,#prefix)
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

-- Alt+8 = SORT CURRENT BUFFER
local function sort_curr_buffer()
  if Util.confirm('Sort confirmation','Sort the current buffer?') then Util.sort_buffer() end
end

-- Alt+9 = MULTILINE TYPER
-- [BEFORE]....[AFTER]
-- [EMPTY]
local function multiline_typer()
  local n1, n2= get_sel_linerange(true) --all or selected lines

  local button, inputs = ui.dialogs.inputbox{
    title = 'Quick-type',
    informative_text = {'Multiline Typer', 'Before begin:', 'After end:', 'Empty lines:', 'From line:', 'To line:'},
    text = {"","","", n1, n2}
  }
  if button == 1 then
    n1= tonumber(inputs[4])
    n2= tonumber(inputs[5])
    local minln= 1
    local maxln= buffer.line_count
    if n2 >= n1 then
      local totne= 0
      local totem= 0
      buffer:begin_undo_action()
      if n1 < minln then n1= minln end
      if n2 > maxln then n2= maxln end
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

-- Alt+")" = Select rectangular column down
local function sel_rec_col_down()
  local pos, e = buffer.selection_start, buffer.selection_end
  if pos == e then
    pos= buffer.current_pos
    e= pos
  end
  local toln= buffer.line_count
  local col= buffer.column[e]
  buffer.rectangular_selection_anchor= pos
  local erow= buffer:line_from_position(pos)
  for r= erow, toln do
    if buffer:line_length(r) <= col then break end
    erow= r
  end
  pos= buffer:find_column(erow, col)
  buffer.rectangular_selection_caret= pos
  buffer.ensure_visible_enforce_policy(erow)
end

local function find_line(fmatch,dirf,roff)
  local r
  local curr= buffer:line_from_position(buffer.current_pos)
  local fromln= 1
  local toln= buffer.line_count
  if dirf then --forward
    for i = curr +1 -roff, toln, 1 do
      if buffer:get_line(i):match(fmatch) then
        r=i+roff
        break
      end
    end
  else  --backward
    for i = curr -1 -roff, fromln, -1 do
      if buffer:get_line(i):match(fmatch) then
        r=i+roff
        break
      end
    end
  end
  if r then
    if r < fromln then r= fromln end
    Util.goto_line(buffer,r)
    return true
  end
  return false
end

local function nav_buf_marks(dirf)
  --navigate file compare results
  local curr= buffer:line_from_position(buffer.current_pos)
  local fromln= 1
  local toln= buffer.line_count
  if dirf then --forward
    for i= curr +1, toln, 1 do
      if buffer._mark_all[i] then Util.goto_line(buffer,i) return end
    end
    ui.statusbar_text= 'no more forward differences'
  else  --backward
    for i= curr -1, fromln, -1 do
      if buffer._mark_all[i] then Util.goto_line(buffer,i) return end
    end
    ui.statusbar_text= 'no more backward differences'
  end
end

-- Ctrl+, = GOTO previous FUNCTION/C-BLOCK BEG/file compare difference
-- Ctrl+. = GOTO next     FUNCTION/C-BLOCK BEG/file compare difference
--$nnnnnnnnn  ($=cursor position)
--{
--....
--}
--LUA version: $[....]function[ mm.www](
local function find_begin(dirf)
  if buffer._mark_all then  --navigate file compare results
    nav_buf_marks(dirf)
    return
  end
  local sbeg='^{'
  local roff=-1
  local lexer= buffer:get_lexer()
  if lexer == 'lua' then
    sbeg='^.*function%s*[%w_.]*%('
    roff=0
  end
  if not find_line(sbeg,dirf,roff) then
    ui.statusbar_text= 'main block begin: not found'
  end
end

-- Ctrl+; = GOTO previous FUNCTION/C-BLOCK END/file compare difference
-- Ctrl.: = GOTO next     FUNCTION/C-BLOCK END/file compare difference
--nnnnnnnnn
--{
--....
--$}          ($=cursor position)
--LUA version: $end
local function find_end(dirf)
  if buffer._mark_add then  --navigate file compare results
    nav_buf_marks(dirf)
    return
  end
  local send='^}'
  local lexer= buffer:get_lexer()
  if lexer == 'lua' then send='^end' end
  if not find_line(send,dirf,0) then
    ui.statusbar_text= 'main block end: not found'
  end
end

if actions then
  actions.add("prev_block_beg", 'Goto previous block begin/difference', function() find_begin(false) end, Util.KEY_CTRL..",")
  actions.add("next_block_beg", 'Goto next block begin/difference',     function() find_begin(true)  end, Util.KEY_CTRL..".")
  actions.add("prev_block_end", 'Goto previous block end/difference',   function() find_end(false) end,   Util.KEY_CTRL..";")
  actions.add("next_block_end", 'Goto next block end/difference',       function() find_end(true)  end,   Util.KEY_CTRL..":")

  actions.add("type_cfun_comm", 'Quicktype: C function comment',  qt_cfun_comm,   Util.KEY_ALT.."1")
  actions.add("type_c_comm",    'Quicktype: C comment',           qt_c_comm,      Util.KEY_ALT.."2")
  actions.add("type_c_define",  'Quicktype: C define',            qt_c_define,    Util.KEY_ALT.."3")
  actions.add("type_c_todo",    'Quicktype: C TODO',              qt_c_todo,      Util.KEY_ALT.."4")
  actions.add("type_c_switchcont",'Quicktype: C switch continue', qt_c_switchcont,Util.KEY_ALT.."5")
  actions.add("hex_to_ascii",   'Quicktype: convert selected text from hex to ascii', convert_hex_2_ascii, Util.KEY_ALT.."6")
  actions.add("s19_checksum",   'Quicktype: generate S19 checksum', generate_s19_checksum, Util.KEY_ALT.."&")
  actions.add("multiline_comment",'Multiline comment',            multiline_comment, Util.KEY_ALT.."7")
  actions.add("type_c_sep_line",'Quicktype: C separator line',    qt_c_sep_line,  Util.KEY_ALT.."0")
  actions.add("sel_r_col_down", 'Select rectangular column down', sel_rec_col_down, Util.KEY_ALT..")")
  actions.add("sort_curr_buffer", 'Sort buffer',                  sort_curr_buffer, Util.KEY_ALT.."8")
  actions.add("multiline_typer",'Multiline typer',                multiline_typer, Util.KEY_ALT.."9")
else
  keys[Util.KEY_CTRL..","] = function() find_begin(false) end
  keys[Util.KEY_CTRL.."."] = function() find_begin(true) end
  keys[Util.KEY_CTRL..";"] = function() find_end(false) end
  keys[Util.KEY_CTRL..":"] = function() find_end(true) end

  keys[Util.KEY_ALT.."1"] = qt_cfun_comm
  keys[Util.KEY_ALT.."2"] = qt_c_comm
  keys[Util.KEY_ALT.."3"] = qt_c_define
  keys[Util.KEY_ALT.."4"] = qt_c_todo
  keys[Util.KEY_ALT.."5"] = qt_c_switchcont
  keys[Util.KEY_ALT.."6"] = convert_hex_2_ascii
  keys[Util.KEY_ALT.."&"] = generate_s19_checksum
  keys[Util.KEY_ALT.."7"] = multiline_comment
  keys[Util.KEY_ALT.."0"] = qt_c_sep_line
  keys[Util.KEY_ALT..")"] = sel_rec_col
  keys[Util.KEY_ALT.."8"] = sort_curr_buffer
  keys[Util.KEY_ALT.."9"] = multiline_typer
end
