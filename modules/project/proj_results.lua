-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
--
-- This module shows search results in a buffer and
-- overwrites ui._print() to display its output in the same buffer
--
-- ** This module is NOT used when USE_RESULTS_PANEL is true **
-- The SEARCH RESULTS INTERFACE is accessed through the "plugs" object
--
local Proj = Proj
local last_print_buftype

local function beg_search_add()
  --goto search view and activate text modifications
  plugs.goto_searchview()
  buffer.read_only= false
end

local function end_search_add(buftype)
  --end search text modifications
  buffer:set_save_point()
  buffer.read_only= true
  buffer:set_lexer('myproj')
  last_print_buftype= buftype
end

local function clear_search_results()
  if #_VIEWS >= Proj.prefview[Proj.PRJV_SEARCH] then
    beg_search_add()
     --delete search content
    textadept.bookmarks.clear()
    Proj.remove_search_from_pos_table()
    buffer:set_text('')
    end_search_add()
  end
end

local function close_search_view()
  local sv= Proj.prefview[Proj.PRJV_SEARCH]
  --if more views are open, ignore the close
  if #_VIEWS > sv then return false end
  last_print_buftype=''
  if #_VIEWS == sv then
    --remove search from position table
    Proj.remove_search_from_pos_table()
    --activate search view
    plugs.goto_searchview()
    --close buffer / view
    buffer:set_save_point()
    Util.close_buffer()
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
      Util.close_buffer()
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
  Proj.goto_projview(Proj.PRJV_SEARCH)
  --goto search results view
  if buffer._type ~= Proj.PRJT_SEARCH then
    for nbuf, sbuf in ipairs(_BUFFERS) do
      if sbuf._type == Proj.PRJT_SEARCH then
        Util.goto_buffer(sbuf)
        break
      end
    end
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
  beg_search_add()
  buffer:append_text('['..s_txt..']\n')
  if s_filter then buffer:append_text(' search dir '..s_filter..'::::\n') end
  buffer:goto_pos(buffer.length)
  buffer.indicator_current = ui.find.INDIC_FIND
end

function plugs.search_result_info(s_txt, iserror)
  --report info/error
  if iserror then buffer:append_text(('(%s)::::\n'):format(s_txt)) else buffer:append_text(' '..s_txt..'\n') end
end

function plugs.search_result_in_file(shortname, fname, nfiles)
  --set the file currently searched
  buffer:append_text((' %s::%s::\n'):format(shortname, fname))
  if nfiles == 1 then buffer:goto_pos(buffer.length) end
end

function plugs.search_result_found(fname, nlin, txt, s_start, s_end)
  --set the location of the found
  local snum= ('%4d'):format(nlin)
  buffer:append_text(('  @%s:%s\n'):format(snum, txt))
  local pos = buffer:position_from_line(buffer.line_count - 2) + #snum + 4
  buffer:indicator_fill_range(pos + s_start - 1, s_end - s_start + 1)
end

function plugs.search_result_end()
  --mark the end of the search
  buffer:append_text('\n')
  end_search_add()
  --set search context menu
  Proj.set_contextm_search()
  Proj.stop_update_ui(false)
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
  plugs.goto_searchview()
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
-------------------------------------------------------

-------- overwrite default ui._print function -----
-- Helper function for printing messages to buffers.
local function proj_print(buffer_type, ...)
  --add to the search-view buffer
  beg_search_add()
  --show buffer_type when changed
  if last_print_buftype ~= buffer_type then buffer:append_text(buffer_type..'\n') end
  buffer:goto_pos(buffer.length)
  local args, n = {...}, select('#', ...)
  for i = 1, n do args[i] = tostring(args[i]) end
  buffer:append_text(table.concat(args, '\t'))
  buffer:append_text('\n')
  end_search_add(buffer_type)
end
function ui._print(buffer_type, ...) pcall(proj_print, buffer_type, ...) end
-------------------------------------------------------
