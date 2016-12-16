local function type_before_after(before,after)
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

-- Alt+9 = MULTILINE TYPER
-- [BEFORE]....[AFTER]
-- [EMPTY]
keys.a9 = function()
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
