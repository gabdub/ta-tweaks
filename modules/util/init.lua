----- utility functions
Util = {}

Util.TA_MAYOR_VER= tonumber(_RELEASE:match('^Textadept (.+)%..+$'))

function Util.info(msg,info)
  ui.dialogs.msgbox{
    title = 'Information',
    text = msg,
    informative_text = info,
    icon = 'gtk-dialog-info', button1 = _L['_OK']
  }
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

