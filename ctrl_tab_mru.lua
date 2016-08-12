-------------- ctrl+tab / ctrl+shift+tab MRU --------------------
--HOLD control key DOWN and press tab = goto previous used buffers (MRU list)
-- ctrl+tab       : forward
-- ctrl+shift+tab : backwards
--example with 5 buffers: CONTROL pressed, TAB pressed 5 times, CONTROL released
--  tab tab tab tab tab
-- 1-  2-  3-  4-  5^  1
-- 2-  1   1   1   1^  2
-- 3   3-  2   2   2^  3
-- 4   4   4-  3   3^  4
-- 5   5   5   5-  4^  5
-- 
local ctrl_key_down = false
local tab_mru_idx= 0
local mru_buff= {}

--DEBUG: show the MRU list in the status bar
local function mru_status()
  local txt= 'MRU'
  local i= 1
  while i <= #mru_buff and i < 15 do
    local p,f,e
    if mru_buff[i].filename == nil then
      f='*'
    else
      p,f,e= string.match(mru_buff[i].filename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
      if f == nil then
        f= mru_buff[i].filename
      end
    end
    txt= txt .. '|' .. f
    i=i+1
  end
  ui.statusbar_text= txt
end

local function mru_getbuffpos(b)
  --locate buffer 'b' in the MRU list
  local i= 1
  while i <= #mru_buff do
    if mru_buff[i] == b then
      return i  --return buffer position: 1...
    end
    i=i+1
  end
  return 0  --not found
end

local function mru_buftotop(b)
  --move/add buffer 'b' to the TOP of the MRU list
  if b ~= nil then
    local i= mru_getbuffpos(b)
    if i == 0 then
      --not on the list, add it
      i=#mru_buff+1
      mru_buff[i]= b
    end
    if i > 1 then
      while i > 1 do
        mru_buff[i]= mru_buff[i-1]
        i=i-1
      end
      mru_buff[1]= b
    end
  end
end

--control+tab handler
local function mru_ctrl_tab_handler(shift)
  --we need 2 or more buffers to swap
  if #mru_buff < 2 then
    return --not enought buffers
  end
  
  if buffer._project_select ~= nil or buffer._type ~= nil then
    --goto files view before handling control+tab
    Proj.goto_filesview() --change to files view if needed
    return
  end
  
  if ctrl_key_down then
    --CONTROL key was pressed before 'this' TAB
    --START A NEW SWAP CYCLE
    tab_mru_idx= 1
    ctrl_key_down = false
  end
  
  local swap
  repeat
    if shift then
      --ctrl+shift+ tab + .. + tab: swap 'backwards'
      swap= tab_mru_idx
      tab_mru_idx= tab_mru_idx-1
      if swap < 2 then      
        tab_mru_idx= #mru_buff
        swap=0
        --ROTATE DOWN (bring bottom to top)
        mru_buftotop(mru_buff[#mru_buff])
      end
    else
      --ctrl+ tab +..+ tab: swap 'foreward'
      tab_mru_idx= tab_mru_idx+1
      swap= tab_mru_idx
      if tab_mru_idx > #mru_buff then
        tab_mru_idx= 1
        swap=0
        --ROTATE UP (send top to bottom)
        local b= mru_buff[1]
        local i= 1
        while i < #mru_buff do
          mru_buff[i]= mru_buff[i+1]
          i=i+1
        end
        mru_buff[i]= b
      end
    end

    if swap > 0 then
      --SWAP 'swap' and top (pos=1)
      --to prevent buffer pushing in BUFFER_AFTER_SWITCH
      local b= mru_buff[1]
      mru_buff[1]= mru_buff[swap]
      mru_buff[swap]= b
    end
  until mru_buff[1]._project_select == nil and mru_buff[1]._type == nil
  
  --activate the buffer in the TOP of the MRU list
  if TA_MAYOR_VER < 9 then
    view:goto_buffer(_BUFFERS[mru_buff[1]])
  else
    view:goto_buffer(mru_buff[1])
  end
end

events.connect(events.KEYPRESS, function(code, shift, control, alt, meta)
  --control key pressed? (left=65507=FFE3, right=65508=FFE4)
  if code == 0xFFE3 or code == 0xFFE4 then
    ctrl_key_down = true
  end
end )

events.connect(events.BUFFER_AFTER_SWITCH, function()
  --move the current buffer to the TOP of the MRU list, pushing down the rest
  mru_buftotop(buffer)
  --mru_status()
end)

events.connect(events.BUFFER_NEW, function()
  --add a new buffer to the TOP of the MRU list
  --keep in mind that this event is also fired when TA starts
  if #_BUFFERS > #mru_buff then
    mru_buftotop(buffer)
    --mru_status()
  end  
end)

events.connect(events.BUFFER_DELETED, function()
  --remove the closed buffer from the MRU list
  --this event is called AFTER the buffer was deleted 
  --(the deleted buffer is NOT in the top of the MRU list)
  --is safer to check ALL the buffers and remove from the MRU list
  --the ones that don't exist any more
  local i= 1
  while i <= #mru_buff do
    if mru_buff[i] ~= nil then
      if _BUFFERS[mru_buff[i]] == nil then
        --this buffer was deleted, remove it from the list
        local j= i
        while j < #mru_buff do
          mru_buff[j]= mru_buff[j+1]
          j=j+1
        end
        mru_buff[j]= nil
      end
      i=i+1
    end
  end
  --mru_status()
end)

--load existing buffers in the MRU list
if #_BUFFERS > 0 then
  local nb= #_BUFFERS
  local i= 1
  while nb > 0 do
    mru_buff[i]= _BUFFERS[nb]
    nb=nb-1
    i=i+1
  end
  --bring the current buffer to the top of the list
  mru_buftotop(buffer)
end

--------------------------------------------------------------
-- Control+TAB            goto next MRU buffer
-- Control+Shift+TAB      goto prev MRU buffer
keys['c\t'] = function() mru_ctrl_tab_handler(false) end
keys['cs\t']= function() mru_ctrl_tab_handler(true)  end
