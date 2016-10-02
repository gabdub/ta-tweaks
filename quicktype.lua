-- Control+F =    Shift+F3
keys.cf = keys.sf3

-- Control+G =    goto-line
keys.cg = textadept.editing.goto_line

-- Control+F4 =   RESET textadept
keys.cf4 = reset

function type_before_after(before,after)
  if (buffer.selections > 1) or (buffer.selection_n_start[0] ~= buffer.selection_n_end[0]) then
    --if something is selected use enclose (left the cursor at the end)
    textadept.editing.enclose(before,after)
    return
  end
  --nothing is selected, left the cursor between 'before' and 'after'
  buffer.add_text(buffer, before)
  local pos= buffer.current_pos
  buffer.add_text(buffer, after)
  buffer.goto_pos(buffer, pos)
end

-- Alt+1 = ($=cursor position) TYPE
-- /*
--      $:
--
-- */
keys.a1 = function()
  type_before_after("/*\n    ", ":\n      \n*/\n")
end

-- Alt+2 = ($=cursor position) TYPE
-- /* $ */
keys.a2 = function()
  type_before_after("/* ", " */")
end

-- Alt+3 = ($=cursor position) TYPE
-- #define $
keys.a3 = function()
  type_before_after("#define ", "")
end


-- Alt+4 = ($=cursor position) TYPE
-- /* TO DO: $ */
keys.a4 = function()
  type_before_after("/* TO DO: ", " */")
end

-- Alt+5 = ($=cursor position) TYPE
--/*    |
--      |
--     \|/   */
-- $
keys.a5 = function()
  type_before_after("/*    |\n      |\n     \\|/   */\n", "")
end

-- Alt+0 = ($=cursor position) TYPE
-- /* ==....== */
-- $
keys.a0 = function()
  type_before_after("/* ============================================================================= */\n", "")
end

-- Ctrl+, = ($=cursor position) GOTO MAIN C-BLOCK BEG
--$nnnnnnnnn
--{
--....
--}
keys["c,"] = function()
  for i = buffer:line_from_position(buffer.current_pos) - 1, 0, -1 do
    if buffer:get_line(i):match('^{') then
      if i > 0 then i= i-1 end
      buffer:ensure_visible_enforce_policy(i)
      buffer:goto_line(i)
      return
    end
  end
  ui.statusbar_text= 'main block begin: not found'
end

-- Ctrl+. = ($=cursor position) GOTO MAIN C-BLOCK END
--nnnnnnnnn
--{
--....
--$}
keys["c."] = function()
  for i = buffer:line_from_position(buffer.current_pos) + 1, buffer.line_count, 1 do
    if buffer:get_line(i):match('^}') then
      buffer:ensure_visible_enforce_policy(i)
      buffer:goto_line(i)
      return
    end
  end
  ui.statusbar_text= 'main block end: not found'
end
