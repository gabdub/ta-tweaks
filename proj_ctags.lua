local Proj = Proj

--=============================================================================--
--CTAG file format (Windows example):
--    ctagmitto.ctag::C:\textadept\ctags-ta.ctag::C
--    [Update CTAGS]::C:\GNU\ctags.exe -n -L %{projfiles.lua.c} -f C:\textadept\ctags-ta.ctag::R
--
--!_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append ;" to lines/
--!_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/
--!_TAG_PROGRAM_AUTHOR	Darren Hiebert	/dhiebert@users.sourceforge.net/
--!_TAG_PROGRAM_NAME	Exuberant Ctags	//
--!_TAG_PROGRAM_URL	http://ctags.sourceforge.net	/official site/
--!_TAG_PROGRAM_VERSION	5.5.4	//
--ABS_MIN_SE	C:\xxx\trunk\sip\sip_timer.c	31;"	d	file:
--ACCMWIP_CANT	C:\xxx\trunk\interfase.h	2148;"	d
--...
--ADDR_MAX_COUNT	C:\xxx\trunk\sip\sip_resolve.c	37;"	d	file:
--ADDR_MAX_COUNT	C:\xxx\trunk\util\srv_resolver.c	33;"	d	file:
--=============================================================================--
--CTAG file format (Linux example):
--    ctags::/home/gabriel/.textadept/ctags::C
--    [Update CTAGS]::ctags -n -L %{projfiles.lua.c} -f /home/gabriel/.textadept/ctags::R
--
--!_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append ;" to lines/
--!_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/
--!_TAG_PROGRAM_AUTHOR	Darren Hiebert	/dhiebert@users.sourceforge.net/
--!_TAG_PROGRAM_NAME	Exuberant Ctags	//
--!_TAG_PROGRAM_URL	http://ctags.sourceforge.net	/official site/
--!_TAG_PROGRAM_VERSION	5.9~svn20110310	//
--FindButton	/home/xxx/textadept_8.6.x86_64/src/textadept.c	147;"	t	file:
--FindButton	/home/xxx/textadept_8.6.x86_64/src/textadept.c	195;"	t	typeref:enum:__anon2	file:
--...
--M.stop	/home/xxx/textadept_8.6.x86_64/modules/textadept/run.lua	260;"	f
--M.syntax_commands 	/home/xxx/textadept_8.6.x86_64/modules/textadept/run.lua	362;"	f
--=============================================================================--

local function str_trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- ====[ code from CTAGS Textadept module ]====
-- List of jump positions comprising a jump history.
-- Has a `pos` field that points to the current jump position.
-- @class table
-- @name jump_list
local jump_list = {pos = 0}


function Proj.goto_tag(ask)
  --find CTAGS file in project
  local p_buffer = Proj.get_projectbuffer(true)
  if p_buffer == nil then
    ui.statusbar_text= 'No project found'
    return
  end

  local tag_files = {}  
  if p_buffer.proj_files ~= nil then
    for row= 1, #p_buffer.proj_files do
      local ftype= p_buffer.proj_filestype[row]
      if ftype == Proj.PRJF_CTAG then
        tag_files[ #tag_files+1 ]= p_buffer.proj_files[row]
      end
    end
  end
  if #tag_files < 1 then
    ui.statusbar_text= 'No CTAGS files found in project'
    return
  end
  
  local word = ''
  local s, e = buffer.selection_start, buffer.selection_end
  if s == e or ask then
    if s == e then
      --suggest current word
      s, e = buffer:word_start_position(s), buffer:word_end_position(s)
    end
    local suggest= str_trim(buffer:text_range(s, e))  --remove trailing \n
    if suggest == '' or ask then
      --ask what to search, suggest current word o last-search
      r,word= ui.dialogs.inputbox{title = 'Tag search', width = 400, text = suggest}
      if type(word) == 'table' then
        word= table.concat(word, '\n') 
      end
    else
      word= suggest
    end
  else
    --use selection
    word = str_trim(buffer:text_range(s, e))
  end
  if word == '' then return end
  
  --code from CTAGS Textadept module
  local tags = {}
  local patt = '^('..word..'%S*)\t(%S+)\t(.-);"\t?(.*)$'
  
  for i = 1, #tag_files do
    local dir, found = tag_files[i]:match('^.+[/\\]'), false
    local f = io.open(tag_files[i])
    for line in f:lines() do
      local tag, file, ex_cmd, ext_fields = line:match(patt)
      if tag then
        if not file:find('^%a?:?[/\\]') then file = dir..file end
        if ex_cmd:find('^/') then ex_cmd = ex_cmd:match('^/^(.+)$/$') end
        tags[#tags + 1] = {tag, file, ex_cmd, ext_fields}
        found = true
      elseif found then
        break -- tags are sorted, so no more matches exist in this file
      end
    end
    f:close()
  end
  if #tags == 0 then 
    ui.statusbar_text = 'TAG: '..word..' not found'
    return 
  end
  -- Prompt the user to select a tag from multiple candidates or automatically
  -- pick the only one.
  if #tags > 1 then
    ui.statusbar_text = 'TAG: '..word..' ('..#tags..' matches)'
    local items = {}
    for i = 1, #tags do
      items[#items + 1] = tags[i][1]
      items[#items + 1] = tags[i][2]:match('[^/\\]+$') -- filename only
      items[#items + 1] = tags[i][3]:match('^%s*(.+)$') -- strip indentation
      --items[#items + 1] = tags[i][4]:match('^%a?%s*(.*)$') -- ignore kind
      items[#items + 1] = tags[i][2]:match('(.-)[^\\/]-$') -- path only
    end
    local button, i = ui.dialogs.filteredlist{
      title = _L['Go To'],
      columns = {_L['Name'], _L['File'], _L['Line:'], 'Path'}, --'Extra Information'},
      items = items, search_column = 2, width = CURSES and ui.size[1] - 2 or nil
    }
    if button < 1 then return end
    tag = tags[i]
  else
    tag = tags[1]
    ui.statusbar_text = 'TAG: '..word..' (1 match)'
  end

  -- Store the current position in the jump history if applicable, clearing any
  -- jump history positions beyond the current one.
  if jump_list.pos < #jump_list then
    for i = jump_list.pos + 1, #jump_list do jump_list[i] = nil end
  end
  if jump_list.pos == 0 or jump_list[#jump_list][1] ~= buffer.filename or
     jump_list[#jump_list][2] ~= buffer.current_pos then
    jump_list[#jump_list + 1] = {buffer.filename, buffer.current_pos}
  end
  
  -- Jump to the tag.
  io.open_file(tag[2])
  if not tonumber(tag[3]) then
    for i = 0, buffer.line_count - 1 do
      if buffer:get_line(i):find(tag[3], 1, true) then
        textadept.editing.goto_line(i + 1)
        break
      end
    end
  else
    textadept.editing.goto_line(tonumber(tag[3]))
  end

  -- Store the new position in the jump history.
  jump_list[#jump_list + 1] = {buffer.filename, buffer.current_pos}
  jump_list.pos = #jump_list
end

function Proj.goto_prev_next(prev)
  -- Navigate within the jump history.
  if prev then
    if jump_list.pos <= 1 then
      ui.statusbar_text= 'No previous position'
      return
    end
    jump_list.pos = jump_list.pos -1
  else
    if jump_list.pos == #jump_list then
      ui.statusbar_text= 'No next position'
      return
    end
    jump_list.pos = jump_list.pos +1
  end
  io.open_file(jump_list[jump_list.pos][1])
  buffer:goto_pos(jump_list[jump_list.pos][2])
end

--------------------------------------------------------------
-- F11          Goto Tag
-- SHIFT+F11    Goto previous position
-- CONTROL+F11  Goto next position
keys.f11 = {Proj.goto_tag, false}
keys.sf11 = {Proj.goto_prev_next, true}
keys.cf11 = {Proj.goto_prev_next, false}
