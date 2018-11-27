-- Copyright 2016-2018 Gabriel Dubatti. See LICENSE.
local Proj = Proj
local Util = Util

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

-- ====[ code from CTAGS Textadept module ]====
-- List of jump positions comprising a jump history.
-- Has a `pos` field that points to the current jump position.
-- @class table
-- @name jump_list
local jump_list = {pos = 0}

local function goto_current_pos()
  if jump_list.pos <= #jump_list and jump_list[jump_list.pos] then
    ui.statusbar_text= 'Pos: '..jump_list.pos..' / '..#jump_list
    local bname= jump_list[jump_list.pos][1]
    if bname == Proj.PRJT_SEARCH then
      Proj.goto_searchview()
    else
      --if the current view is a project view, goto left/only files view. if not, keep the current view
      Proj.go_file(bname)
    end
    buffer:goto_pos(jump_list[jump_list.pos][2])
  end
end

local function update_go_toolbar()
  if toolbar then
    actions.updateaction("prev_position")
    actions.updateaction("next_position")
  end
end

-- Store the current position at the end of the jump history.
function Proj.append_current_pos()
  local bname= buffer.filename
  if not bname then
    if buffer._type == Proj.PRJT_SEARCH then
      bname= Proj.PRJT_SEARCH
    else
      return
    end
  end
  if buffer._project_select ~= nil then return end
  local n=#jump_list
  if n == 0 or jump_list[n][1] ~= bname or jump_list[n][2] ~= buffer.current_pos then
    n=n+1
    jump_list[n]= {bname, buffer.current_pos}
    jump_list.pos= n
  end
  update_go_toolbar()
end

--remove search from position table
function Proj.remove_search_from_pos_table()
  if #jump_list > 0 then
    local j = 0
    for i = 0, #jump_list do
      if jump_list[i] and jump_list[i][1] == Proj.PRJT_SEARCH then
        if jump_list.pos > 0 and jump_list.pos >=  i then
          jump_list.pos= jump_list.pos-1
        end
      else
        if j < i then jump_list[j] = jump_list[i] end
        j=j+1
      end
    end
    for i = j, #jump_list do jump_list[i] = nil end
  end
end

---- ACTIONS ----
--ACTION: goto_tag
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

  --if ctags list is open, find symbol in this file
  if toolbar.list_tb then toolbar.list_find_sym() return end

  local word = ''
  local s, e = buffer.selection_start, buffer.selection_end
  if s == e or ask then
    if s == e then
      --suggest current word
      s, e = buffer:word_start_position(s), buffer:word_end_position(s)
    end
    local suggest= Util.str_trim(buffer:text_range(s, e))  --remove trailing \n
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
    word = Util.str_trim(buffer:text_range(s, e))
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
  Proj.store_current_pos(true)
  --if the current view is a project view, goto left/only files view. if not, keep the current view
  Proj.go_file(tag[2])
  if not tonumber(tag[3]) then
    for i = 0, buffer.line_count - 1 do
      if buffer:get_line(i):find(tag[3], 1, true) then
        Util.goto_line(buffer, i)
        break
      end
    end
  else
    Util.goto_line(buffer, tonumber(tag[3])-1)
  end
  -- Store the current position at the end of the jump history.
  Proj.append_current_pos()
end

--ACTION: save_position
function Proj.store_current_pos(quiet)
  -- Store the current position in the jump history if applicable, clearing any
  -- jump history positions beyond the current one.
  if jump_list.pos < #jump_list then
    for i = jump_list.pos + 1, #jump_list do jump_list[i] = nil end
  end
  -- Store the current position at the end of the jump history.
  Proj.append_current_pos()
  update_go_toolbar()
  if not quiet then  ui.statusbar_text= 'Pos '..jump_list.pos..' set' end
end

--ACTION: prev_position
function Proj.goprev_status() --go prev position
  return ((jump_list.pos >= 1) and 0 or 8) --8=disabled
end
function Proj.goto_prev_pos()
  -- Navigate within the jump history.
  local n=jump_list.pos
  if n < 1 then
    ui.statusbar_text= 'No previous position'
    return
  end
  local moved= false --check if moved from jump_list.pos position
  if buffer._project_select == nil then --ignore project buffer
    local bname= buffer.filename
    if not bname and buffer._type == Proj.PRJT_SEARCH then bname= Proj.PRJT_SEARCH end
    moved= (jump_list[n][1] ~= bname or buffer:line_from_position(jump_list[n][2]) ~= buffer:line_from_position(buffer.current_pos))
    --if moved from last position line, store current pos so we can return here
    if moved and n == #jump_list then
      Proj.store_current_pos(true)
      jump_list.pos = n
      update_go_toolbar()
    end
  end
  if not moved then
    if n > 1 then
      jump_list.pos = n -1
      update_go_toolbar()
    else
      ui.statusbar_text= 'No previous position'
      return
    end
  end
  goto_current_pos()
end

--ACTION: next_position
function Proj.gonext_status() --go next position
  return ((jump_list.pos < #jump_list) and 0 or 8) --8=disabled
end
function Proj.goto_next_pos()
  -- Navigate within the jump history.
  if jump_list.pos > #jump_list or not jump_list[jump_list.pos+1] then
    ui.statusbar_text= 'No next position'
    return
  end
  jump_list.pos = jump_list.pos +1
  update_go_toolbar()
  goto_current_pos()
end

--ACTION: clear_position
--clear position table
function Proj.clear_pos_table()
  if #jump_list > 0 then
    for i = 0, #jump_list do jump_list[i] = nil end
  end
  jump_list.pos= 0
  update_go_toolbar()
  ui.statusbar_text= 'All position cleared'
end

--------------------------------------------------------------
-- F11          goto Tag
-- Shift+F11    goto previous position
-- Shift+F12    goto next position
-- Control+F11  store current position
-- Control+F12  clear all positions
