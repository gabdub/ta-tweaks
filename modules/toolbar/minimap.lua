-- Copyright 2016-2021 Gabriel Dubatti. See LICENSE.
local Util = Util
local toolbar = toolbar
local events, events_connect = events, events.connect

function toolbar.show_hide_minimap()
  --hide the minimap when the config is open
  toolbar.sel_minimap()
  if toolbar.tbhidemmapcfg then
    toolbar.show(toolbar.tbshowminimap and (not toolbar.config_toolbar_shown))
  else
    toolbar.show(toolbar.tbshowminimap)
  end
end

--"logical line number" (1..) to "visual line number" (1..)
local function lin2vis(nl)
  return buffer:visible_from_doc_line( nl+Util.LINE_BASE-1 ) +1-Util.LINE_BASE
end

--add a hilight to the minimap (correcting annotation/hidden lines)
local function mmhilight(nl,color)
  minimap.hilight(lin2vis(nl),color)
end

--add markers to the minimap
local function add_mmap_markers(markbit, colorprop)
  local mbit= 1 << (markbit -Util.LINE_BASE)
  local color= toolbar.get_rgbcolor_prop(colorprop)
  local nl= buffer:marker_next(0, mbit)
  while nl >= 0 do
    mmhilight(nl +1 -Util.LINE_BASE,color)
    local nl2= buffer:marker_next(nl+1, mbit)
    if nl2 <= nl then break end
    nl= nl2
  end
end

--add indicators to the minimap
local function add_mmap_indicators(indicator, colorprop)
  local color= toolbar.get_rgbcolor_prop(colorprop)
  local pos= buffer:indicator_end(indicator, Util.LINE_BASE)
  while pos > Util.LINE_BASE and pos < buffer.length do
    local nl= buffer:line_from_position(pos) + 1 - Util.LINE_BASE
    mmhilight(nl, color)
    pos= buffer:indicator_end(indicator, buffer:position_from_line(nl + Util.LINE_BASE))
  end
end

local function add_mmap_changes(changes, colorprop)
  if changes then
    local color= toolbar.get_rgbcolor_prop(colorprop)
    for i=1,#changes do
      mmhilight(changes[i], color)
    end
  end
end

local function minimap_scroll()
  local nl= buffer.lines_on_screen
  local first= buffer.first_visible_line + 1 - Util.LINE_BASE
  minimap.scrollpos(nl, first, 0)
  minimap.lines_screen= nl
end

--load buffer markers/indicators into the minimap
function toolbar.minimap_load()
  if toolbar.tbshowminimap then
    local totlin= lin2vis(buffer.line_count)
    minimap.init(buffer._buffnum, totlin, 6)
    minimap.line_count= totlin
    --show bookmarks
    add_mmap_markers(textadept.bookmarks.MARK_BOOKMARK, 'color.bookmark')
    if buffer._comparing then  --show file compare results
      add_mmap_changes(buffer._mark_add, 'color.green')
      add_mmap_changes(buffer._mark_del, 'color.red')
      add_mmap_changes(buffer._mark_mod, 'color.yellow')
    end
    --show highlighted words
    add_mmap_indicators(textadept.editing.INDIC_HIGHLIGHT, 'color.hilight')
    --show first/last lines
    color= toolbar.get_rgbcolor_prop('color.curr_line_back')
    minimap.hilight(1,color,true)
    minimap.hilight(totlin,color,true)
    minimap_scroll()
  end

--  if tbh_scroll then
--    tbh_scroll.setmaxcol(2000)
--    tbh_scroll_scroll()
--  end
end

if Proj then
  events_connect(events.UPDATE_UI, function(updated)
  --if we are updating, ignore this event
    if updated and Proj.update_ui == 0 then
      if (updated & (buffer.UPDATE_CONTENT | buffer.UPDATE_SELECTION)) > 0 then toolbar.minimap_load()
      elseif (updated & buffer.UPDATE_V_SCROLL) > 0 then minimap_scroll() end

      if tbh_scroll_scroll and (updated & buffer.UPDATE_H_SCROLL) > 0 then tbh_scroll_scroll() end
    end
  end)
end

--check every second: hidden lines / window size
local function check_vis_changes()
  if toolbar.tbshowminimap and Proj and Proj.update_ui == 0 and minimap.lines_screen then
    local totlin= lin2vis(buffer.line_count)
    if minimap.line_count ~= totlin then toolbar.minimap_load()
    elseif minimap.lines_screen ~= buffer.lines_on_screen then minimap_scroll() end
  end
  if tbh_scroll then
    if tbh_scroll.xoff ~= buffer.x_offset then tbh_scroll_scroll() end
  end
  return true
end
timeout(1, check_vis_changes)

local function minimap_clicked()
  local nl= minimap.getclickline()
  if nl > 0 then
    --"visual line number" (1..) to "logical line number" (0..)
    nl= buffer:doc_line_from_visible(nl-1+Util.LINE_BASE)
    if nl >= buffer.line_count then nl= buffer.line_count-1 end
    textadept.editing.goto_line(nl)
    buffer:vertical_center_caret()
  end
end

events_connect("minimap_scroll", function(dir)
  buffer:line_scroll( 0, dir*3)
end)

if tbh_scroll then
  function toolbar.show_hide_tbh_scroll()
    --show/hide the horizontal scrollbar
    toolbar.sel_toolbar_n(toolbar.H_SCROLL_TOOLBAR)
    toolbar.show(toolbar.tbreplhscroll)
  end

  function tbh_scroll_clicked()
    buffer.x_offset= tbh_scroll.getclickcol()
  end

  function tbh_scroll_scroll()
    tbh_scroll.scrollpos(100*tbh_scroll.char_w, buffer.x_offset, 0)
    tbh_scroll.xoff= buffer.x_offset
  end

  events_connect("tbh_scroll", function(dir)
    buffer:line_scroll( dir*12, 0)
  end)
end

function toolbar.minimap_setup()
  --set toolbar #4 as a MINIMAP
  toolbar.new(14, 14, 14, toolbar.MINIMAP_TOOLBAR, toolbar.themepath)
  --width=14 / height=expand
  toolbar.addgroup(toolbar.GRPC.ONLYME, toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, 14, 0)
  toolbar.themed_icon(toolbar.globalicon,"ttb-vscroll-back", toolbar.TTBI_TB.BACKGROUND)
  toolbar.themed_icon(toolbar.groupicon, "ttb-scroll-box", toolbar.TTBI_TB.BACKGROUND)
  toolbar.setbackcolor(toolbar.groupicon, toolbar.BKCOLOR.MINIMAP_DRAW, true, true)
  toolbar.adjust(14, 4096, 2,1,3,3)
  toolbar.gotopos(0,0)
  toolbar.cmd("minimap", minimap_clicked, "", "")
  toolbar.setbackcolor("minimap", toolbar.BKCOLOR.MINIMAP_CLICK, false, true)
  toolbar.seticon(toolbar.globalicon, "", toolbar.TTBI_TB.IT_HILIGHT, true) --don't highlight
  toolbar.seticon(toolbar.globalicon, "", toolbar.TTBI_TB.IT_HIPRESSED, true)
  toolbar.show(toolbar.tbshowminimap)

  if tbh_scroll then
    tbh_scroll.char_w= view:text_width(view.STYLE_LINENUMBER, '0')
    tbh_scroll.setmaxcol(300*tbh_scroll.char_w)
    --set toolbar #6 as a HORIZONTAL SCROLLBAR
    toolbar.new(14, 14, 14, toolbar.H_SCROLL_TOOLBAR, toolbar.themepath)
    --width=expand / height=14
    toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.ONLYME, 0, 14)
    toolbar.themed_icon(toolbar.globalicon,"ttb-hscroll-back", toolbar.TTBI_TB.BACKGROUND)
    toolbar.themed_icon(toolbar.groupicon, "ttb-scroll-box", toolbar.TTBI_TB.BACKGROUND)
    toolbar.setbackcolor(toolbar.groupicon, toolbar.BKCOLOR.TBH_SCR_DRAW, true, true)
    toolbar.adjust(4096, 14, 1,1,3,3)
    toolbar.gotopos(0,0)
    toolbar.cmd("tbh_scroll", tbh_scroll_clicked, "", "")
    toolbar.setbackcolor("tbh_scroll", toolbar.BKCOLOR.TBH_SCR_CLICK, false, true)
    toolbar.seticon(toolbar.globalicon, "", toolbar.TTBI_TB.IT_HILIGHT, true) --don't highlight
    toolbar.seticon(toolbar.globalicon, "", toolbar.TTBI_TB.IT_HIPRESSED, true)
    toolbar.show(toolbar.tbreplhscroll)
  end
end
