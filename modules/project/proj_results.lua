-- Copyright 2016-2019 Gabriel Dubatti. See LICENSE.
local Proj = Proj

--------------- RESULTS INTERFACE --------------
function plugs.clear_results()
  Proj.clear_search_results()
end

--------------- SEARCH RESULTS INTERFACE --------------
function plugs.search_result_start(s_txt, s_filter)
  --a new "search in files" begin
  Proj.stop_update_ui(true)
  --activate/create search view
  Proj.beg_search_add()
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
  Proj.end_search_add()
  --set search context menu
  Proj.set_contextm_search()
  Proj.stop_update_ui(false)
end
-------------------------------------------------------

-------- overwrite default ui._print function -----
-- Helper function for printing messages to buffers.
local function proj_print(buffer_type, ...)
  --add to the search-view buffer
  Proj.beg_search_add()
  --show buffer_type when changed
  if last_print_buftype ~= buffer_type then buffer:append_text(buffer_type..'\n') end
  buffer:goto_pos(buffer.length)
  local args, n = {...}, select('#', ...)
  for i = 1, n do args[i] = tostring(args[i]) end
  buffer:append_text(table.concat(args, '\t'))
  buffer:append_text('\n')
  Proj.end_search_add(buffer_type)
end
function ui._print(buffer_type, ...) pcall(proj_print, buffer_type, ...) end
-------------------------------------------------------
