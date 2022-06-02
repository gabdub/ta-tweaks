-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
local keys, OSX = keys, OSX
local Util = Util

--list of accelerators (index= action)
actions.accelerators = {}

actions.MACROHOME= _USERHOME..(WIN32 and '\\' or '/')..'macros'
--check/create macro dir
if not lfs.attributes(actions.MACROHOME) then lfs.mkdir(actions.MACROHOME) end

if OSX then
  require('textadept.keys_osx')
else
  require('textadept.keys_winlin')
end

--set action accelerator
function actions.setkey(act,key)
  actions.free_accelerator(key)
  actions.accelerators[act]= key
end

--add a new action to the list
function actions.add(name, menutext, exec, keyacc, icon, status, butttext)
  actions.list[name]= {menutext, exec}
  local id= #actions.action_fromid +1
  actions.action_fromid[id]= name
  actions.id_fromaction[name]= id
  if icon then actions.icons[name]=icon end
  if status then actions.status[name]=status end
  if butttext then actions.buttontext[name]=butttext end
  if keyacc then actions.setkey(name,keyacc) end
  return id
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
  local mods, key, mname
  mods, key = kcode:match('^(.*%+)(.+)$')
  if not mods and not key then mods, key = '', kcode end
  mname = (mods:find('meta+') and (CURSES and "Alt+" or "Cmd+") or "") ..
                (mods:find('ctrl+') and "Ctrl+" or "") ..
                (mods:find('alt+') and "Alt+" or "") ..
                (mods:find('shift+') and "Shift+" or "")
  local ku=string.upper(key)
  local lu=string.lower(key)
  if ku == lu then --only symbols and numbers
    if ku == " " then ku= "Space"
    elseif ku == "\t" then ku= "Tab"
    elseif ku == "\b" then ku= "Back"
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
  local mods, key = key_seq:match('^(.*%+)(.+)$')
  if not mods and not key then mods, key = '', key_seq end
  local modifiers = ((mods:find('shift%+') or key:lower() ~= key) and 1 or 0) +
    (mods:find('ctrl%+') and 4 or 0) + (mods:find('alt%+') and 8 or 0) +
    (mods:find('cmd%+') and 0x10000000 or 0)
  local code = string.byte(key)
  if #key > 1 or code < 32 then
    for i, s in pairs(keys.KEYSYMS) do
      if s == key and i > 0xFE20 then code = i break end
    end
  end
  return code, modifiers
end

--macro recording
actions.recording=false
actions.recorded= {}
actions.recordlevel=0
actions.record_dirty=false

local function mrec_updateactions()
  --actions.updateaction("start_macrorec")
  --actions.updateaction("stop_macrorec")
  actions.updateaction("toggle_macrorec")
  actions.updateaction("play_macrorec")
  actions.updateaction("dump_macrorec")
  actions.updateaction("save_macrorec")
  actions.updateaction("load_macrorec")
end

local function check_dirty()
  if record_dirty then
    if not Util.confirm("Macro overwrite confirmation", "The last recorded macro wasn't saved", "Do you want to overwrite it?") then return false end
    record_dirty=false
  end
  return true
end

local function mrec_start()
  if actions.recording then
    ui.statusbar_text= "Macro recording already in progress"
  else
    if not check_dirty() then return end
    actions.recorded= {}
    actions.recording= true
    actions.recordlevel=0
    mrec_updateactions()
    ui.statusbar_text= "Macro recording in progress..."
  end
end
--local function mrecstart_status()
--  return (actions.recording and 8 or 0) --8=disabled
--end
--actions.add("start_macrorec", '_Start macro recording', mrec_start, nil, "media-record", mrecstart_status)

local function mrec_stop()
  if not actions.recording then
    ui.statusbar_text= "No macro recording in progress"
  else
    actions.recording= false
    mrec_updateactions()
    local n= #actions.recorded
    ui.statusbar_text= "Macro recording complete, "..n.." actions recorded"
  end
end
--local function mrecstop_status()
--  return (actions.recording and 0 or 8) --8=disabled
--end
--actions.add("stop_macrorec", '_Stop macro recording', mrec_stop, nil, "media-playback-stop", mrecstop_status)

local function mrec_toggle()
  if actions.recording then mrec_stop() else mrec_start() end
end
local function mrectog_icon()
  return (actions.recording and "media-playback-stop" or "media-record")
end
local function mrectog_text()
  return (actions.recording and "Stop macro recording" or "Start macro recording")
end
actions.add("toggle_macrorec", '_Start/stop macro recording', mrec_toggle, "ctrl+f7", mrectog_icon, nil, mrectog_text)

local function mrec_play()
  if actions.recording then
    ui.statusbar_text= "Macro recording in progress"
  elseif #actions.recorded > 0 then
    buffer.begin_undo_action()
    for i=1, #actions.recorded do
      actions.run(actions.recorded[i])
    end
    buffer.end_undo_action()
    ui.statusbar_text= ""..#actions.recorded.." actions played back"
  end
end
local function mrecplay_status()
  return ((not actions.recording and #actions.recorded > 0) and 0 or 8) --8=disabled
end
actions.add("play_macrorec", '_Play last recorded macro', mrec_play, "f7", "media-playback-start", mrecplay_status)

local function mrecdump()
  if not actions.recording and #actions.recorded > 0 then
    actions.run("new")  --new buffer
    for i=1, #actions.recorded do
      buffer:append_text(actions.recorded[i]..'\n')
    end
  end
end
actions.add("dump_macrorec", '_Dump last recorded macro', mrecdump, nil, "lpi-translate", mrecplay_status)

local function mrecsave()
  if not actions.recording and #actions.recorded > 0 then
    local filename = ui.dialogs.filesave{
      title = _L['Save']..' macro', with_directory = actions.MACROHOME,
      with_file= 'macro_name',
      width = CURSES and ui.size[1] - 2 or nil
    }
    if filename then
      local f = io.open(filename, 'wb')
      if f then
        f:write(table.concat(actions.recorded,'\n'))
        f:close()
        record_dirty=false
      end
    end
  end
end
actions.add("save_macrorec", _L['Save']..' macro', mrecsave, "shift+f7", "document-export", mrecplay_status)

local function mrecload_status()
  return ((not actions.recording) and 0 or 8) --8=disabled
end
local function mrecload()
  if not actions.recording then
    if not check_dirty() then return end
    local filename = ui.dialogs.fileselect{
      title = _L['Open']..' macro', with_directory = actions.MACROHOME,
      width = CURSES and ui.size[1] - 2 or nil,
      select_multiple = false
    }
    if filename then
      local f = io.open(filename, 'rb')
      if f then
        actions.recorded= {}
        for line in f:lines() do
          actions.recorded[#actions.recorded+1]= line
        end
        f:close()
        mrec_updateactions()
        ui.statusbar_text= "Macro loaded with "..#actions.recorded.." actions"
      end
    end
  end
end
actions.add("load_macrorec", _L['Open']..' macro', mrecload, nil, "document-import", mrecload_status)

local function key_return()
  buffer.add_text('\n')
  if not textadept.editing.auto_indent then return end
  local line = buffer:line_from_position(buffer.current_pos)
  if line > 1 and buffer:get_line(line - 1):find('^[\r\n]+$') and
     buffer:get_line(line):find('^[^\r\n]') then
    return -- do not auto-indent when pressing enter from start of previous line
  end
  local i = line - 1
  while i >= 1 and buffer:get_line(i):find('^[\r\n]+$') do i = i - 1 end
  if i >= 1 then
    buffer.line_indentation[line] = buffer.line_indentation[i]
    buffer:vc_home()
  end
end
actions.add("key_return", 'Return key', key_return)

if toolbar then
  local function run_mult_action(a_normal, a_shift, a_control)
    if (toolbar.keyflags & toolbar.KEYFLAGS.SHIFT) ~= 0 then actions.run(a_shift)
    elseif (toolbar.keyflags & toolbar.KEYFLAGS.CONTROL) ~= 0 then actions.run(a_control)
    else actions.run(a_normal) end
  end

  local function save_saveas() --save / saveas (+SHIFT) / saveall (+CONTROL)
    run_mult_action("save", "saveas", "saveall")
  end
  actions.add("save_saveas", 'Save      [Click]/[Ctrl+S]\nSave As [Shift+Click]/[Ctrl+Shift+S]\nSave All [Ctrl+Click]', save_saveas, nil, "document-save")

  local function new_open() --new / open (+SHIFT) / recent (+CONTROL)
    run_mult_action("new", "open", "recent")
  end
  actions.add("new_open", 'New      [Click]/[Ctrl+N]\nOpen   [Shift+Click]/[Ctrl+O]\nRecent [Ctrl+Click]/[Ctrl+Alt+O]', new_open, nil, "document-new")

  local function togg_clear_bookmark() --toggle_bookmark / goto_bookmark (+SHIFT) / clear_bookmarks (+CONTROL)
    run_mult_action("toggle_bookmark", "goto_bookmark", "clear_bookmarks")
  end
  actions.add("togg_clear_bookmark", 'Toggle Bookmark [Click]/[Ctrl+F2]\nGoto Bookmark... [Shift+Click]/[Alt+F2]\nClear Bookmarks  [Ctrl+Click]/[Ctrl+Shift+F2]', togg_clear_bookmark, nil, "gnome-app-install-star")
end

--run an action (act: action-name=string, action-id=number, {act}=1 item table)
function actions.run(act)
  local ret
  if type(act) == 'table' then act=act[1] end
  if type(act) == 'number' then act=actions.action_fromid[act] end
  if act then
    local typeact=act:match('^[!|](.*)')
    if typeact then
      if act:match('^|(.*)') then --"|": replace text (delete before type)
        buffer.delete_range(buffer.current_pos, #typeact)
      end
      buffer.add_text(typeact)  --type action
    else
      local action= actions.list[act][2]
      assert(type(action) == 'function', 'Unknown command: '..tostring(act))
      --don't save "run_command", save the choosen action instead
      local saveact=(act ~= 'run_command') and not act:find('macrorec') and actions.recording and (actions.recordlevel == 0)
      if saveact then
        record_dirty=true
        local n= #actions.recorded+1
        actions.recorded[n]= act
        ui.statusbar_text="recording #"..n..": "..act
        --don't save "sub-actions"
        actions.recordlevel=actions.recordlevel+1
      end
      ret= action()
      if saveact then actions.recordlevel=actions.recordlevel-1 end
    end
  end
  return ret
end

events.connect(events.CHAR_ADDED, function(key)
  if actions.recording then
    local n= #actions.recorded
    local k= string.char(key)
    if k == '\n' then
      k= "key_return"
      n=n+1
      actions.recorded[n]= k
      ui.statusbar_text="recorded #"..n..": "..k
      return
    end
    local tcmd= buffer.overtype and "|" or "!"
    if n > 0 then
      local lastact=actions.recorded[n]
      local prevk=lastact:match('^'..tcmd..'(.*)')
      if prevk then --add to the end of last type action
        actions.recorded[n]= lastact..k
        ui.statusbar_text="recorded #"..n..": type "..prevk..k
        return
      end
    end
    --create a new type action: "!" / "|"
    n=n+1
    actions.recorded[n]= tcmd..k
    ui.statusbar_text="recorded #"..n..": type "..k
  end
end)

--set accelerator keys
local function setacceleratorskeys()
  for act,k in pairs(actions.accelerators) do
    --run the connected action
    local runact= function() return actions.run({act}) end
    if type(k) == 'table' then
      if k[1] == "++" then  --dual level keys: {"++","cmv","w"} OR {"++","cmv","+","cmv","="}
        for i=2, #k, 2 do
          if keys[k[i]] == nil then keys[k[i]]= {} end
          keys[k[i]][k[i+1]]= runact
        end
      else
        --more than one accelerator for the same action
        for i=1, #k do
          keys[k[i]]= runact
        end
      end
    else
      keys[k]= runact
    end
  end
end

events.connect(events.INITIALIZED, setacceleratorskeys)

-- Other.
if ui.find.find_incremental_keys then
	ui.find.find_incremental_keys.cr = function()
	  ui.find.find_incremental(ui.command_entry:get_text(), false, true) -- reverse
	end
end

return M
