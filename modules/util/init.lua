-- Copyright 2016-2017 Gabriel Dubatti. See LICENSE.
----- utility functions
Util = {}

Util.TA_MAYOR_VER= tonumber(_RELEASE:match('^Textadept (.+)%..+$'))

function Util.info(msg,info)
  ui.dialogs.msgbox{
    title = 'Information',
    text = msg or '',
    informative_text = info or '',
    icon = 'gtk-dialog-info', button1 = _L['_OK']
  }
end

function Util.confirm(tit, txt, info)
  return ui.dialogs.msgbox{ title = tit or 'Confirmation', text = txt or '', informative_text = info or '',
      icon = 'gtk-dialog-question', button1 = _L['_OK'], button2 = _L['_Cancel'] } == 1
end

function Util.goto_view(numview)
  if _VIEWS[view] ~= numview then
    if Util.TA_MAYOR_VER < 9 then
      ui.goto_view(numview)
    else
      ui.goto_view(_VIEWS[numview])
    end
  end
end

function Util.goto_buffer(buf)
  if Util.TA_MAYOR_VER < 9 then
    view:goto_buffer(_BUFFERS[buf])
  else
    view:goto_buffer(buf)
  end
end

--goto line= 0...
function Util.goto_line(p_buffer,line)
  p_buffer:ensure_visible_enforce_policy(line)
  p_buffer:goto_line(line)
end

-- Returns the Path, Filename, and Extension of a filename as 3 strings
function Util.splitfilename(strfilename)
  if not strfilename then return {'','',''} end
  return string.match(strfilename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
end

--remove blanks and CR/LF
function Util.str_trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--return only the first line of text
function Util.str_one_line(s)
  return (s:gsub("^%s*(.-)%s*\n.*$", "%1"))
end

function Util.file_exists(fn)
  if fn:match('[^\\/]+$') then
    local f, err = io.open(fn, 'rb')
    if f then
      f:close()
      return true
    end
  end
  return false
end

function Util.type_before_after(before,after)
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

function Util.escape_match(x)
   return( x:gsub('%%', '%%%%'):gsub('^%^', '%%^'):gsub('%$$', '%%$'):gsub('%(', '%%(')
            :gsub('%)', '%%)'):gsub('%.', '%%.'):gsub('%[', '%%['):gsub('%]', '%%]')
            :gsub('%*', '%%*'):gsub('%+', '%%+'):gsub('%-', '%%-'):gsub('%?', '%%?') )
end

function Util.sort_buffer(b)
  if not b then b= buffer end
  local ls= {}
  for l in b.get_text():gmatch('[^\n]+') do ls[#ls+1]=l end
  table.sort(ls)
  b.set_text(table.concat(ls, '\n'))
end

function Util.Hex2Ascii(str)
  local res=''
  for c in str:gmatch("%x%x") do
    res= res .. string.char(tonumber(c, 16))
  end
  return res
end
