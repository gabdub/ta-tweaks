-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
----- utility functions
if Util == nil then
  Util = {}
  Util.TA_MAYOR_VER= tonumber(_RELEASE:match('^Textadept (.+)%..+$'))
  Util.LINE_BASE= (Util.TA_MAYOR_VER < 11) and 0 or 1
end

Util.PATH_SEP= (WIN32 and '\\' or '/')

function Util.info(msg,info)
  ui.dialogs.msgbox{
    title = 'Information',
    text = msg or '',
    informative_text = info or '',
    icon = 'gtk-dialog-info', button1 = Util.OK_TEXT
  }
end

function Util.confirm(tit, txt, info)
  return ui.dialogs.msgbox{ title = tit or 'Confirmation', text = txt or '', informative_text = info or '',
      icon = 'gtk-dialog-question', button1 = Util.OK_TEXT, button2 = Util.CANCEL_TEXT } == 1
end

function Util.goto_view(numview)
  if _VIEWS[view] ~= numview then
--    if Util.TA_MAYOR_VER < 9 then
--      ui.goto_view(numview)
--    else
      ui.goto_view(_VIEWS[numview])
--    end
  end
end

function Util.goto_buffer(buf)
--  if Util.TA_MAYOR_VER < 9 then
--    view:goto_buffer(_BUFFERS[buf])
--  else
    if buf then view:goto_buffer(buf) end
--  end
end

--goto line= 1...
function Util.goto_line(p_buffer,line)
  local r= line -1 + Util.LINE_BASE
  p_buffer:ensure_visible_enforce_policy(r)
  p_buffer:goto_line(r)
end

function Util.close_buffer()
  local ok
  if Util.TA_MAYOR_VER < 11 then ok= io.close_buffer() else ok= buffer:close() end
  return ok
end

function Util.reload_file()
  if Util.TA_MAYOR_VER < 11 then io.reload_file() else buffer:reload() end
end

function Util.save_file()
  if Util.TA_MAYOR_VER < 11 then io.save_file() else buffer:save() end
end

-- Returns the Path, Filename, and Extension of a filename as 3 strings
function Util.splitfilename(strfilename)
  if not strfilename then return {'','',''} end
  return string.match(strfilename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
end

-- Returns the Filename (+Extension) of a filename as a string
function Util.getfilename(strfilename, addext)
  local p,f,e= Util.splitfilename(strfilename)
  if not p then return '' end
  if addext or (#e == 0) or (f==e) then return f end
  --remove extension
  return f:sub(1,-(#e+2))
end

--remove blanks and CR/LF (begin and end)
function Util.str_trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--remove blanks and CR/LF (only end)
function Util.str_trim_final(s)
  return (s:gsub("^(.-)%s*$", "%1"))
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
  if (buffer.selections > 1) or (buffer.selection_n_start[ Util.LINE_BASE ] ~= buffer.selection_n_end[ Util.LINE_BASE ]) then
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

function Util.escape_filter(x)
  --trim spaces at the end/begin and replace inner spaces with wildards (.-)
  local f= Util.escape_match(Util.str_trim(x))
  return( f:gsub(' ','.-') )
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

function Util.rgb_2_bgr(col)
  return ((col >> 16) & 0xFF) | (col & 0x00FF00) | ((col << 16) & 0xFF0000)
end

---- configuration management ----
Util.cfg_int=     1 --integer:        "1"
Util.cfg_bool=    2 --boolean:        "true" / "false"
Util.cfg_str=     3 --string:         "zzzzz"
Util.cfg_hex=     4 --hex integer:    "0x808080"
Util.cfg_int_str= 5 --int [,string]:  "27,zzzzzzzzzz" / "33"
Util.cfg_str_int= 6 --string [,int]:  "zzzzzzzzzz,27" / "gggggg"
Util.cfg_int2=    7 --int,int:        "1,2"
Util.cfg_int3=    8 --int,int,int:    "1,2,3"
Util.cfg_int4=    9 --int,...,int:    "1,2,3,4"
Util.cfg_int5=   10 --int,...,int:    "1,2,3,4,5"
Util.cfg_int6=   11 --int,...,int:    "1,2,3,4,5,6"

function Util.add_config_field(config, fieldname, fieldtype, defvalue, maxindex)
  --save field definition
  config[#config+1]= {fieldname, fieldtype, defvalue, maxindex}
  if not config[0] then config[0]={} end

  if maxindex then --range?
    local j
    for j= 1, maxindex do
      config[fieldname.."#"..j]= defvalue
      config[0][fieldname.."#"..j]= #config --save def position
    end
  else
    config[fieldname]= defvalue
    config[0][fieldname]= #config --save def position
  end

end

function Util.set_config_defaults(config)
  local i,j
  for i = 1, #config do
    local ci= config[i]
    if ci[4] then --range?
      for j= 1, ci[4] do
        config[ci[1].."#"..j]= ci[3]
      end
    else config[ci[1]]= ci[3] end
  end
end

--file format:
-- field-name ":" field-value
-- ignore all other lines (like blanks or comments = lines that starts with ";")
function Util.parse_config_line(config, line)
  if config[0] == nil then return end
  local fname, fval= string.match(line, "^([^;].-):(.+)$")
  if fname and fval then
    fname= Util.str_trim(fname)
    fval= Util.str_trim(fval)
    if fname ~= "" then
      local i= config[0][fname]
      if i then
        local format= config[i][2]
        if format == Util.cfg_int then
          --integer
          config[fname]= tonumber(fval)

        elseif format == Util.cfg_bool then
          --boolean: "true" / "false"
          config[fname]= false
          if fval:find('^true') then config[fname]= true end

        elseif format == Util.cfg_str then
          --string
          config[fname]= fval

        elseif format == Util.cfg_hex then
          --0xhhhhhh
          local v= string.match(fval,"0x(.*)")
          if v then config[fname]= tonumber(v,16) end

        elseif format == Util.cfg_int_str then
          --integer[,string]
          local i, s = fval:match('^(.-),(.+)$')
          if i then i= tonumber(i) else i= tonumber(fval) end
          config[fname]= {i, s}

        elseif format == Util.cfg_str_int then
          --string [,integer]
          local s, i = fval:match('^(.+),(.+)$')
          if s then i=tonumber(i) else s= fval end
          config[fname]= {s, i}

        elseif format == Util.cfg_int2 then
          --integer,integer
          local a,b = fval:match('^(.-),(.+)$')
          config[fname]= {tonumber(a),tonumber(b)}
        elseif format == Util.cfg_int3 then
          --integer,integer,integer
          local a,b,c = fval:match('^(.-),(.-),(.+)$')
          config[fname]= {tonumber(a),tonumber(b),tonumber(c)}
        elseif format == Util.cfg_int4 then
          --integer,integer,integer,integer
          local a,b,c,d = fval:match('^(.-),(.-),(.-),(.+)$')
          config[fname]= {tonumber(a),tonumber(b),tonumber(c),tonumber(d)}
        elseif format == Util.cfg_int5 then
          --integer,integer,integer,integer,integer
          local a,b,c,d,e = fval:match('^(.-),(.-),(.-),(.-),(.+)$')
          config[fname]= {tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e)}
        elseif format == Util.cfg_int6 then
          --integer,integer,integer,integer,integer,integer
          local a,b,c,d,e,f = fval:match('^(.-),(.-),(.-),(.-),(.-),(.+)$')
          config[fname]= {tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e),tonumber(f)}
        end
      end
    end
  end
end

function Util.load_config_file(config, filename)
  local f = io.open(filename, 'rb')
  if f then
    for line in f:lines() do
      Util.parse_config_line(config, line)
    end
    f:close()
  end
end

function Util.save_config_file(config, filename)
  local f = io.open(filename, 'wb')
  if f then
    local savedata = {}
    for i=1, #config do
      local ci= config[i]
      local cvar= ci[1]
      local rval
      if ci[4] then --range?
        for j= 1, ci[4] do
          --range: only save if it's not the default value
          rval= tostring(config[cvar.."#"..j])
          if rval ~= ci[3] then savedata[#savedata+1]= cvar.."#"..j..":"..rval end
        end
      else
        if type(config[cvar]) == "table" then rval= table.concat(config[cvar], ',')
        else rval= tostring(config[cvar]) end
        savedata[#savedata+1]= cvar..":"..rval
      end
    end
    f:write(table.concat(savedata, '\n'))
    f:close()
  end
end

--usage:
--Util.cfg= {}
--Util.add_config_field(Util.cfg,"myinteger",Util.cfg_int,27)
--Util.add_config_field(Util.cfg,"mystring",Util.cfg_str,"zzzzzz")
--Util.add_config_field(Util.cfg,"color",Util.cfg_hex,0xFF)
--Util.add_config_field(Util.cfg,"toolbar_back",Util.cfg_str,"",5) --toolbar_back#1..#5
