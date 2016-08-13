------------------ goto nearest occurrence --------------------------
-- for local mode:
--  replace M.last_search with buffer.last_search
--  replace M.goto_nearest_whole_word with buffer.goto_nearest_whole_word
--  replace M.goto_nearest_match_case with buffer.goto_nearest_match_case
local M = {}

local function goto_nearest_default()
  if M.goto_nearest_whole_word == nil then
    --set default search options HERE--
    M.goto_nearest_whole_word= false
    M.goto_nearest_match_case= true
  end
end

local function str_trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function str_one_line(s)
  return (s:gsub("^%s*(.-)%s*\n.*$", "%1"))
end

local function goto_nearest_occurrence(reverse,ask)
  local buffer = buffer
  local suggest= ''
  local word = ''
  goto_nearest_default()
  local s, e = buffer.selection_start, buffer.selection_end
  if s == e or ask then
    --no selection, use last_search or ask for the first time search
    if not ask and M.last_search ~= nil and M.last_search ~= "" then
      --keep last_search
      word = M.last_search
    else
      if s == e then
        --suggest current word
        s, e = buffer:word_start_position(s), buffer:word_end_position(s)
      end
      suggest= str_trim(buffer:text_range(s, e))  --remove trailing \n
      --ask what to search, suggest current word o last-search
      local tit= (M.goto_nearest_whole_word and 'Word:yes | ' or 'Word:no | ') ..
                 (M.goto_nearest_match_case and ' Match case | ' or 'Ignore case | ') ..
                 (reverse and 'Backward' or 'Forward') ..
                 '\n(change options: alt+F3 / ctrl+shift+F3)'
      r,word= ui.dialogs.inputbox{title = 'Search', informative_text = tit, width = 400, text = suggest}
      if type(word) == 'table' then
        word= table.concat(word, '\n')
      end
    end
  else
    --use selection
    word = str_trim(buffer:text_range(s, e))
  end

  if word == '' then return end
  M.last_search = word       --save last search
  
  -- Store the current position in the jump history if applicable, clearing any
  -- jump history positions beyond the current one.
  Proj.store_current_pos()
  
  buffer.search_flags = (M.goto_nearest_whole_word and buffer.FIND_WHOLEWORD or 0) +
                        (M.goto_nearest_match_case and buffer.FIND_MATCHCASE or 0)
  if reverse then
    buffer.target_start = s - 1
    buffer.target_end = 0
  else
    buffer.target_start = e + 1
    buffer.target_end = buffer.length
  end
  if buffer:search_in_target(word) == -1 then
    if reverse then
      buffer.target_start = buffer.length
      buffer.target_end = e + 1
    else
      buffer.target_start = 0
      buffer.target_end = s - 1
    end
    if buffer:search_in_target(word) == -1 then
      ui.statusbar_text= str_one_line(M.last_search) .. ': not found'
      return
    end
  end
  buffer:set_sel(buffer.target_start, buffer.target_end)
  ui.statusbar_text= str_one_line(M.last_search) .. ': found'
  -- Store the current position at the end of the jump history.
  Proj.append_current_pos()
end

local function goto_nearest_config(choose)
  goto_nearest_default()
  local r,sel
  local curr = (M.goto_nearest_whole_word and 3 or 1) + (M.goto_nearest_match_case and 1 or 0)

  if choose then
    r,sel= ui.dialogs.dropdown{title = 'Search options', select = curr, width= 300, items = {'Word:no + Ignore case (soft match)', 'Word:no + Match case', 'Word:yes + Ignore case', 'Word:yes + Match case (strict match)'}}
  else
    r=1
    sel= (curr > 1 and 1 or 4)   --toggle: strict  <--> soft match
  end

  if r > 0 and sel then
    M.goto_nearest_whole_word= (sel > 2)
    M.goto_nearest_match_case= (sel==2) or (sel==4)
  end
  stat= 'Search options: Word:' .. (M.goto_nearest_whole_word and 'yes + ' or 'no + ') .. (M.goto_nearest_match_case and 'Match case' or 'Ignore case')
  if M.goto_nearest_whole_word and M.goto_nearest_match_case then
    stat= stat .. ' (strict match)'
  elseif not M.goto_nearest_whole_word and not M.goto_nearest_match_case then
    stat= stat .. ' (soft match)'
  end
  ui.statusbar_text= stat
end

-------find text in project's files----
local function find_text_in_project(ask)
  local buffer = buffer
  local suggest= ''
  local word = ''

  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer == nil then
    ui.statusbar_text= 'No project found'
    return
  end

  goto_nearest_default()
  local s, e = buffer.selection_start, buffer.selection_end
  if s == e or ask then
    --no selection, use last_search or ask for the first time search
    if not ask and M.last_search ~= nil and M.last_search ~= "" then
      --keep last_search
      word = M.last_search
    else
      if s == e then
        --suggest current word
        s, e = buffer:word_start_position(s), buffer:word_end_position(s)
      end
      suggest= str_trim(buffer:text_range(s, e))  --remove trailing \n
      --ask what to search, suggest current word o last-search
      local tit= (M.goto_nearest_whole_word and 'Word:yes | ' or 'Word:no | ') ..
                 (M.goto_nearest_match_case and ' Match case | ' or 'Ignore case | ') ..
                 '\n(change options: alt+F3 / ctrl+shift+F3)'
      r,word= ui.dialogs.inputbox{title = 'Search', informative_text = tit, width = 400, text = suggest}
      if type(word) == 'table' then
        word= table.concat(word, '\n')
      end
    end
  else
    --use selection
    word = str_trim(buffer:text_range(s, e))
  end

  if word == '' then return end
  M.last_search = word       --save last search

  Proj.find_in_files(p_buffer,word,M.goto_nearest_match_case,M.goto_nearest_whole_word)
end

function Proj.search_in_files()
  find_text_in_project(true)
end

--------------------------------------------------------------
-- F3 =               goto nearest occurrence FORWARD
-- Control+F3 =       goto nearest occurrence BACKWARD
-- Alt+F3 =           goto nearest occurrence CHOOSE SEARCH OPTIONS
-- Shift+F3 =         ASK + goto nearest occurrence FORWARD
-- Alt+Shift+F =      search in project files
-- Control+Shift+F3 = goto nearest occurrence TOGGLE SEARCH OPTIONS
keys.f3 =   function() goto_nearest_occurrence(false) end
keys.cf3 =  function() goto_nearest_occurrence(true) end
keys.af3 =  function() goto_nearest_config(true) end
keys.sf3 =  function() goto_nearest_occurrence(false, true) end
keys.csf3 = function() goto_nearest_config(false) end
keys.aF = Proj.search_in_files
