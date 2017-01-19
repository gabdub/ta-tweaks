local keys, OSX = keys, OSX

--list of accelerators (index= action)
actions.accelerators = {}

if OSX then
  require('textadept.keys_osx')
else
  require('textadept.keys_winlin')
end

--don't use this accelerators
function actions.free_accelerator(klist)
  local function freeacc(key)
    for act,k in pairs(actions.accelerators) do
      if type(k) == 'table' then
        --multiple key options
        for i=1,#k do
          if k[i] == key then
            --remove this option
            if #k == 1 then --only 1
              actions.accelerators[act]=nil
              return
            end
            if #k == 2 then --1 left (1),2->2 or 1,(2)->1
              actions.accelerators[act]=k[3-i]
              return
            end
            --2 or more options left
            if i < #k then
              k[i]= k[#k]
            end
            k[#k]= nil
            return
          end
        end
      else
        if k == key then
          actions.accelerators[act]=nil
          return
        end
      end
    end
  end
  if type(klist) == 'table' then
    for i=1, #klist do
      freeacc(klist[i])
    end
  else
    freeacc(klist)
  end
end

local function key_name(kcode)
  local mods, key = kcode:match('^([cams]*)(.+)$')
  local mname = (mods:find('m') and (CURSES and "Alt+" or "Cmd+") or "") ..
                (mods:find('c') and "Ctrl+" or "") ..
                (mods:find('a') and "Alt+" or "") ..
                (mods:find('s') and "Shift+" or "")
  local ku=string.upper(key)
  local lu=string.lower(key)
  if ku == lu then --only symbols and numbers
    if ku == " " then ku= "Space"
    elseif ku == "\t" then ku= "Tab"
    elseif ku == "\n" then ku= "Return"
    else ku= "["..ku.."]" end
  elseif ku == key then
    mname= mname.."Shift+" --upper case letter: add shift
  end
  return mname..ku
end

function actions.getaccelkeyname(action)
  local k= actions.accelerators[action]
  if k then
    if type(k) == 'table' then
      if k[1] == "++" then
        return key_name(k[2]).." "..key_name(k[3])
      end
      k= k[1]
    end
    return key_name(k)
  end
  return ""
end

-- Returns the GDK integer keycode and modifier mask for a key sequence.
-- This is used for creating menu accelerators.
function actions.get_gdkkey(action)
  local key_seq= actions.accelerators[action]
  if not key_seq then return nil end
  if type(key_seq) == 'table' then
    if key_seq[1] == "++" then
      --don't show dual level keys in menus
      return nil
    end
    --more than one option, show the first in menus
    key_seq= key_seq[1]
  end
  local mods, key = key_seq:match('^([cams]*)(.+)$')
  if not mods or not key then return nil end
  local modifiers = ((mods:find('s') or key:lower() ~= key) and 1 or 0) +
                    (mods:find('c') and 4 or 0) + (mods:find('a') and 8 or 0) +
                    (mods:find('m') and 0x10000000 or 0)
  local code = string.byte(key)
  if #key > 1 or code < 32 then
    for i, s in pairs(keys.KEYSYMS) do
      if s == key and i > 0xFE20 then code = i break end
    end
  end
  return code, modifiers
end

function actions.run(act_name)
  if act_name then
    local action= actions.list[act_name]
    assert(type(action) == 'function', _L['Unknown command:']..' '..tostring(act_name))
    action()
  end
end

function actions.run_id(act_id)
  actions.run( actions.action_fromid[act_id] )
end

--set accelerator keys
local function setacceleratorskeys()
  for acc,k in pairs(actions.accelerators) do
    --local runacc= function() actions.run(acc) end
    if type(k) == 'table' then
      if k[1] == "++" then  --dual level keys: {"++","cmv","w"} OR {"++","cmv","+","cmv","="}
        for i=2, #k, 2 do
          if keys[k[i]] == nil then keys[k[i]]= {} end
          keys[k[i]][k[i+1]]= actions.list[acc][2]
        end
      else
        --more than one accelerator for the same action
        for i=1, #k do
          keys[k[i]]= actions.list[acc][2]
        end
      end
    else
      keys[k]= actions.list[acc][2]
    end
  end
end

events.connect(events.INITIALIZED, setacceleratorskeys)

-- Modes.
keys.filter_through = {
  ['\n'] = function()
    return ui.command_entry.finish_mode(textadept.editing.filter_through)
  end,
}
keys.find_incremental = {
  ['\n'] = function()
    ui.find.find_entry_text = ui.command_entry:get_text() -- save
    ui.find.find_incremental(ui.command_entry:get_text(), true, true)
  end,
  ['cr'] = function()
    ui.find.find_incremental(ui.command_entry:get_text(), false, true)
  end,
  ['\b'] = function()
    local e = ui.command_entry:position_before(ui.command_entry.length)
    ui.find.find_incremental(ui.command_entry:text_range(0, e), true)
    return false -- propagate
  end
}
-- Add the character for any key pressed without modifiers to incremental find.
setmetatable(keys.find_incremental, {__index = function(_, k)
               if #k > 1 and k:find('^[cams]*.+$') then return end
               ui.find.find_incremental(ui.command_entry:get_text()..k, true)
             end})
-- Show documentation for symbols in the Lua command entry.
keys.lua_command[CURSES and 'mh' or 'ch'] = function()
  -- Temporarily change _G.buffer since ui.command_entry is the "active" buffer.
  local orig_buffer = _G.buffer
  _G.buffer = ui.command_entry
  textadept.editing.show_documentation()
  _G.buffer = orig_buffer
end

return M
