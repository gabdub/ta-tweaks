-- Control+F =    Shift+F3
keys.cf = keys.sf3

-- Control+G =    goto-line
keys.cg = textadept.editing.goto_line

-- Control+F4 =   RESET textadept
keys.cf4 = reset

-- Alt+1 = ($=cursor position) TYPE
-- /*
--      $:
--
-- */
keys.a1 = function()
  buffer.add_text(buffer, "/*\n    ")
  local pos= buffer.current_pos
  buffer.add_text(buffer, ":\n      \n*/\n")
  buffer.goto_pos(buffer, pos)
end

-- Alt+2 = ($=cursor position) TYPE
-- /* $ */
keys.a2 = function()
  buffer.add_text(buffer, "/* ")
  local pos= buffer.current_pos
  buffer.add_text(buffer, " */")
  buffer.goto_pos(buffer, pos)
end

-- Alt+3 = ($=cursor position) TYPE
-- #define $
keys.a3 = function()
  buffer.add_text(buffer, "#define ")
end


-- Alt+4 = ($=cursor position) TYPE
-- /* TO DO: $ */
keys.a4 = function()
  buffer.add_text(buffer, "/* TO DO: ")
  local pos= buffer.current_pos
  buffer.add_text(buffer, " */")
  buffer.goto_pos(buffer, pos)
end

-- Alt+5 = ($=cursor position) TYPE
--/*    |
--      |
--     \|/   */
-- $
keys.a5 = function()
  buffer.add_text(buffer, "/*    |\n      |\n     \\|/   */\n")
end

-- Alt+0 = ($=cursor position) TYPE
-- /* ==....== */
-- $
keys.a0 = function()
  buffer.add_text(buffer, "/* ============================================================================= */\n")
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
