-- Copyright 2016-2022 Gabriel Dubatti. See LICENSE.
--
-- This module shows search results in a buffer and
-- overwrites ui._print() to display its output in the same buffer
--
-- ** This module is NOT used when USE_RESULTS_PANEL is true **
-- The SEARCH RESULTS INTERFACE is accessed through the "plugs" object
--
local Proj = Proj
local last_print_buftype

local s_started= false

local function beg_search_add()
  --goto search view and activate text modifications
  s_started= plugs.goto_searchview()
  if s_started then buffer.read_only= false end
  return s_started
end

local function end_search_add(buftype)
  --end search text modifications
  if s_started then
    buffer:set_save_point()
    buffer.read_only= true
    buffer:set_lexer('myproj')
    last_print_buftype= buftype
    s_started= false
  end
end

local function clear_search_results()
  local sv= Proj.get_projview(Proj.PRJV_SEARCH)
  if sv > 0 and sv <= #_VIEWS then
    if beg_search_add() then
       --delete search content
      textadept.bookmarks.clear()
      Proj.remove_search_from_pos_table()
      buffer:set_text('')
      end_search_add()
    end
  end
end

local function close_search_view()
  local sv= Proj.get_projview(Proj.PRJV_SEARCH)
  --if more views are open, ignore the close
  if sv < 1 or sv < #_VIEWS then return false end
  last_print_buftype=''
  if #_VIEWS == sv then
    --remove search from position table
    Proj.remove_search_from_pos_table()
    --activate search view
    plugs.goto_searchview()
    --close buffer / view
    buffer:set_save_point()
    buffer:close()
    Util.goto_view( sv -1 )
    view.unsplit(view)
    return true
  end
  --no search view, try to close the search buffer
  for _, sbuffer in ipairs(_BUFFERS) do
    if sbuffer._type == Proj.PRJT_SEARCH then
      --goto search results view
      if view.buffer._type ~= Proj.PRJT_SEARCH then
        Util.goto_buffer(sbuffer)
      end
      buffer:close()
      break
    end
  end
  return false
end

--------------- RESULTS INTERFACE --------------
function plugs.init_searchview()
  --check if a search results buffer is open
  for _, buff in ipairs(_BUFFERS) do
    if buff._type == Proj.PRJT_SEARCH then
      --activate search view
      plugs.goto_searchview()
      buff.read_only= true
      break
    end
  end
end

function plugs.goto_searchview()
  --activate/create search view
  --goto the view for search results, split views and create empty buffers if needed
  if Proj.get_projview(Proj.PRJV_SEARCH) < 1 then return false end --the project is closed
  Proj.goto_projview(Proj.PRJV_SEARCH)
  --goto search results view
  if buffer._type ~= Proj.PRJT_SEARCH then
    for nbuf, sbuf in ipairs(_BUFFERS) do
      if sbuf._type == Proj.PRJT_SEARCH then
        Util.goto_buffer(sbuf)
        return true
      end
    end
    return false --not found
  end
  return true
end

function plugs.close_results(viewclosed)
  --viewclosed= the right view was closed, close this too
  return close_search_view()  --only close this view if this is the last one
end

function plugs.clear_results()
  clear_search_results()
end

--------------- SEARCH RESULTS INTERFACE --------------
function plugs.search_result_start(s_txt, s_filter)
  --a new "search in files" begin
  Proj.stop_update_ui(true)
  --activate/create search view
  if beg_search_add() then
    buffer:append_text('['..s_txt..']\n')
    if s_filter then buffer:append_text(' search dir '..s_filter..'::::\n') end
    buffer:goto_pos(buffer.length)
    buffer.indicator_current = ui.find.INDIC_FIND
    return true
  end
  Proj.stop_update_ui(false)  --no buffer to show results
  return false
end

function plugs.search_result_info(s_txt, iserror)
  --report info/error
  if s_started then
    if iserror then buffer:append_text(('(%s)::::\n'):format(s_txt)) else buffer:append_text(' '..s_txt..'\n') end
  end
end

function plugs.search_result_in_file(shortname, fname, nfiles)
  --set the file currently searched
  if s_started then
    buffer:append_text((' %s::%s::\n'):format(shortname, fname))
    if nfiles == 1 then buffer:goto_pos(buffer.length) end
  end
end

function plugs.search_result_found(fname, nlin, txt, s_start, s_end)
  --set the location of the found
  if s_started then
    local snum= ('%4d'):format(nlin)
    buffer:append_text(('  @%s:%s\n'):format(snum, txt))
    local pos = buffer:position_from_line(buffer.line_count -1) + #snum + 4
    buffer:indicator_fill_range(pos + s_start - 1, s_end - s_start + 1)
  end
end

function plugs.search_result_end()
  --mark the end of the search
  if s_started then
    buffer:append_text('\n')
    end_search_add()
    --set search context menu
    Proj.set_contextm_search()
    Proj.stop_update_ui(false)
  end
end

local function get_fileerror(ln)
  local fname, linenum, errtxt= string.match(ln, 'lua:%s(.-):(%d*):%s(.*)')
  if not fname then
    --try with incomplete path ".../path/../fname.lua:linenum: error description"
    fname, linenum, errtxt= string.match(ln, '%.%.%.(.-):(%d*):%s(.*)')
    if fname then
      if Proj.data.is_open then
        --try to complete the path
        local lenfname= #fname
        for k,v in ipairs(Proj.data.proj_files) do
          if #v > lenfname then
            if fname == string.sub(v,-lenfname) then
              fname= v  --found, open this file
              break
            end
          end
        end
      end
    end
  end
  if fname and Util.file_exists(fname) then
    return fname, linenum, errtxt
  end
  return nil
end

function plugs.doble_click_searchview()
  --open the selected file in the search view
  --clear selection
  buffer.selection_start= buffer.selection_end
  --get line number, format: " @ nnn:....."
  local line_num = buffer:get_cur_line():match('^%s*@%s*(%d+):.+$')
  local file
  if line_num then
    --get file name from previous lines
    local fromln= buffer:line_from_position(buffer.current_pos)
    local toln= 1
    for i = fromln, toln, -1 do
      file = buffer:get_line(i):match('^[^@]-::(.+)::.+$')
      if file then break end
    end
  else
    --try: open the file
    local ln= buffer:get_cur_line()
    file= ln:match('^[^@]-::(.+)::.+$')
    if file == nil then
      local errtxt --try: lua error
      file, line_num, errtxt= get_fileerror(ln)
    end
  end
  if file then
    textadept.bookmarks.clear()
    textadept.bookmarks.toggle()
    -- Store the current position in the jump history if applicable, clearing any
    -- jump history positions beyond the current one.
    Proj.store_current_pos(true)
    Proj.go_file(file, line_num)
    -- Store the current position at the end of the jump history.
    Proj.append_current_pos()
  end
end

--------------- COMPARE FILE RESULTS INTERFACE --------------
local function dump_changes(n, buff, r)
  if n > 0 then
    local c= 10
    for i=1, #r, 2 do
      local snum= ('%4d'):format(r[i])
      local line= buff:get_line(r[i]-1)
      buffer:append_text(('  @%s:%s'):format(snum, line))
      c= c-1
      if c == 0 then --only show first 10 blocks
        if i < #r-1 then buffer:append_text('  ...') end
        break
      end
    end
  end
  buffer:append_text('\n')
end

function plugs.compare_file_result(n1, buffer1, r1, n2, buffer2, r2, n3, rm)
  clear_search_results()
  --activate/create search view
  if plugs.goto_searchview() then
    buffer.read_only= false
     --delete search content
    buffer:append_text('[File compare]\n')
    buffer:goto_pos(buffer.length)
    local fn1= buffer1.filename and buffer1.filename or 'left buffer'
    local p,f,e= Util.splitfilename(fn1)
    if f == '' then f= fn1 end
    buffer:append_text((' (+)%4d %s::%s::\n'):format(n1, f, fn1))
    --enum lines that are only in buffer 1
    dump_changes(n1,buffer1,r1)

    local fn2= buffer2.filename and buffer2.filename or 'right buffer'
    p,f,e= Util.splitfilename(fn2)
    if f == '' then f= fn2 end
    buffer:append_text((' (-)%4d %s::%s::\n'):format(n2, f, fn2))
    --enum lines that are only in buffer 2
    dump_changes(n2,buffer2,r2)

    buffer:append_text((' (*)%4d edited lines::%s::\n'):format(n3,fn1))
    --enum modified lines in buffer 1
    dump_changes(n3,buffer1,rm)

    buffer:append_text('\n')
    buffer:set_save_point()
    buffer.read_only= true
    buffer:set_lexer('myproj')

    --return to file #1
    Proj.goto_projview(Proj.PRJV_FILES)
  end
end
-------------------------------------------------------

-------- overwrite default ui._print function -----
-- Helper function for printing messages to buffers.
local function proj_print(buffer_type, ...)
  --add to the search-view buffer
  if beg_search_add() then
    --show buffer_type when changed
    if last_print_buftype ~= buffer_type then buffer:append_text(buffer_type..'\n') end
    buffer:goto_pos(buffer.length)
    local args, n = {...}, select('#', ...)
    for i = 1, n do args[i] = tostring(args[i]) end
    buffer:append_text(table.concat(args, '\t'))
    buffer:append_text('\n')
    end_search_add(buffer_type)
  else
    --show in a buffer (use TA default code)
    local buffer
    for _, buf in ipairs(_BUFFERS) do
      if buf._type == buffer_type then buffer = buf break end
    end
    if not buffer then
      --if not ui.tabs then view:split() end
      buffer= _G.buffer.new()
      buffer._type = buffer_type
      events.emit(events.FILE_OPENED)
    elseif not ui.silent_print then
      for _, view in ipairs(_VIEWS) do
        if view.buffer._type == buffer_type then ui.goto_view(view) break end
      end
      if view.buffer._type ~= buffer_type then view:goto_buffer(buffer) end
    end
    local args, n = {...}, select('#', ...)
    for i = 1, n do args[i] = tostring(args[i]) end
    buffer:append_text(table.concat(args, '\t'))
    buffer:append_text('\n')
    buffer:goto_pos(buffer.length + 1)
    buffer:set_save_point()
  end
end
function ui._print(buffer_type, ...) pcall(proj_print, buffer_type, ...) end
-------------------------------------------------------
