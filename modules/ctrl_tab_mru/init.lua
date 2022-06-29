-- Copyright 2016-2022 Gabriel Dubatti. See LICENSE.
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
local Util = Util
local ctrl_key_down = false
local tab_mru_idx= 0
local mru_buff= {}
local events, events_connect = events, events.connect

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

  local right= nil
  --Project module? check current view and goto files view before handling control+tab
  if Proj then
    if Proj.goto_filesview() then return end  --exit if the view changed
    --in the right panel: only switch to another right marked file
    if _VIEWS[view] == Proj.get_projview(Proj.PRJV_FILES_2) then right= true end
  end

  if ctrl_key_down then
    --CONTROL key was pressed before 'this' TAB
    --START A NEW SWAP CYCLE
    tab_mru_idx= 1
    ctrl_key_down = false
  end

  local swap, mr
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

    mr= mru_buff[1]
  until mr._project_select == nil and (mr._type == nil or mr._type == Util.UNTITLED_TEXT) and mr._right_side == right

  --activate the buffer in the TOP of the MRU list
  --Project module? change to left/right files view if needed (without project: 1/2, with project: 2/4)
  local newb= mru_buff[1]
  if Proj then
    Proj.goto_filesview(newb._right_side and Proj.FILEPANEL_RIGHT or Proj.FILEPANEL_LEFT)
  else
    --no project module: view #2 is the right_side panel
    if newb._right_side then
      if #_VIEWS == 1 then
        view:split(true)
      end
      if _VIEWS[view] == 1 then Util.goto_view(2) end
    else --view #1 is the left/only panel
      if _VIEWS[view] ~= 1 then Util.goto_view(1) end
    end
  end
  Util.goto_buffer(newb)
end

events_connect(events.KEYPRESS, function(code, shift, control, alt, meta)
  --control key pressed? (left=65507=FFE3, right=65508=FFE4)
  if code == 0xFFE3 or code == 0xFFE4 then
    ctrl_key_down = true
  end
end )

events_connect(events.BUFFER_AFTER_SWITCH, function()
  --move the current buffer to the TOP of the MRU list, pushing down the rest
  mru_buftotop(buffer)
end)

events_connect(events.BUFFER_NEW, function()
  --add a new buffer to the TOP of the MRU list
  --keep in mind that this event is also fired when TA starts
  if #_BUFFERS > #mru_buff then
    mru_buftotop(buffer)
  end
end)

events_connect(events.BUFFER_DELETED, function()
  --remove the closed buffer from the MRU list
  --this event is called AFTER the buffer was deleted
  --(the deleted buffer is NOT in the top of the MRU list)
  --it's safer to check ALL the buffers and remove from the MRU list
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
    end
    i=i+1
  end
end)

--return the top buffer in the MRU list (any/left/right)
function gettop_MRUbuff(any, right)
  if right == false then right= nil end
  for i= 1, #mru_buff do
    local b= mru_buff[i]
    if b._project_select == nil and (b._type == nil or b._type == Util.UNTITLED_TEXT) and
      (any or b._right_side == right) then return b end
  end
  return nil
end

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
if actions then
  actions.add("next_mru_buffer", 'Next MRU buffer', function() mru_ctrl_tab_handler(false) end, Util.KEY_CTRL.."\t")
  actions.add("prev_mru_buffer", 'Prev MRU buffer', function() mru_ctrl_tab_handler(true)  end, Util.KEY_CTRL..Util.KEY_SHIFT.."\t")
else
  keys[Util.KEY_CTRL..'\t'] = function() mru_ctrl_tab_handler(false) end
  keys[Util.KEY_CTRL..Util.KEY_SHIFT..'\t']= function() mru_ctrl_tab_handler(true)  end
end
