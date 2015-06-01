--if not CURSES then ui.set_theme('base16-tomorrow-dark') end
if not CURSES then ui.set_theme('ggg') end

--F3 find
require('goto_nearest')
--replace CTRL+F with SHIFT+F3
keys.cf =  keys.sf3

--F4 toggle project mode
require('project')

events.connect(events.LEXER_LOADED, function(lang)
  if lang == 'vala' then
    buffer.tab_width = 4
    buffer.use_tabs = false
    
  elseif lang == 'lua' then
    buffer.tab_width = 2
    buffer.use_tabs = false
  end
end)

------------------- DEBUG -------------------key list----------
local function get_gdk_key(key_seq)
  if not key_seq then return nil end
  local mods, key = key_seq:match('^([cams]*)(.+)$')
  if not mods or not key then return nil end
  local modifiers = ((mods:find('s') or key:lower() ~= key) and 1 or 0) +
                    (mods:find('c') and 4 or 0) + (mods:find('a') and 8 or 0) +
                    (mods:find('m') and 0x10000000 or 0)
  local byte = string.byte(key)
  if #key > 1 or byte < 32 then
    for i, s in pairs(keys.KEYSYMS) do
      if s == key and i > 0xFE20 then byte = i break end
    end
  end
  return byte, modifiers
end

local function get_id(f)
  local id = ''
  if type(f) == 'function' then
    id = tostring(f)
  elseif type(f) == 'table' then
    for i = 1, #f do id = id..tostring(f[i]) end
  end
  return id
end

function ver_keys()
  for key, f in pairs(keys) do 
    k, mods = get_gdk_key(key)
    t= "key=" .. key .. " k=" .. k .. " m=" .. mods .. " get_id(f)=" .. get_id(f) 
    ui._print('teclas', t)
  end
  t= " get_id(M.proj_toggle_sel_mode)=" .. get_id(M.proj_toggle_sel_mode) 
  ui._print('teclas', t)
  t= " get_id(M.open_proj_file)=" .. get_id(M.open_proj_file) 
  ui._print('teclas', t)
end
--------------------------------------------------------------
-- SHIFT+F4     show key list
keys.sf4 = ver_keys
-- CONTROL+F4   RESET textadept
keys.cf4 = reset

------------------- tab-double-click close buffer ---------------
--events.connect(events.TAB_DOUBLE_CLICK, function() io.close_buffer() end)
