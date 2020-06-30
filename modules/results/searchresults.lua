-- Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
--
-- This module shows search results in the "results" toolbar
--
-- ** This module is used when USE_RESULTS_PANEL is true **
-- The SEARCH RESULTS INTERFACE is accessed through the "plugs" object
--
if toolbar then
  local itemsgrp
  local selitem=0
  local nitems= 0
  local yout= 1
  local full_search= {} --copy all
  local file_search= {} --files array
  local pos_search= {}  --{num_file,line-num} array

  local function search_create()
    itemsgrp= toolbar.addgroup(toolbar.GRPC.ONLYME|toolbar.GRPC.EXPAND, toolbar.GRPC.LAST|toolbar.GRPC.ITEMSIZE|toolbar.GRPC.SHOW_V_SCROLL, 0, 0, true)
    toolbar.sel_results_bar(itemsgrp)
    toolbar.textfont(toolbar.cfg.textfont_sz, toolbar.cfg.textfont_yoffset, toolbar.cfg.textcolor_normal, toolbar.cfg.textcolor_grayed)
  end

  local function get_rowname(n)
    return "sch-item#"..n
  end

  local function ensurevisible()
    if nitems > 0 then toolbar.ensurevisible(get_rowname(nitems)) end
    if selitem > 0 then toolbar.ensurevisible(get_rowname(selitem)) end
  end

  local function search_notify(switching)
    ensurevisible()
  end

  local function search_showlist(show)
    --show/hide list items
    toolbar.sel_results_bar(itemsgrp)
    toolbar.showgroup(show)
  end

  function toolbar.results_clear()
    --remove all items
    toolbar.sel_results_bar(itemsgrp,true) --empty items group
    nitems= 0
    yout= 1
    full_search= {}
    file_search= {}
    pos_search= {}
    selitem=0
  end

  --"edit-clear" / "edit-copy"
  local function search_act(name)
    if name == "edit-clear" then toolbar.results_clear()
    elseif name == "edit-select-all" then buffer:copy_text(table.concat(full_search,'\n'))
    elseif name == "edit-copy" then if selitem > 0 then buffer:copy_text(full_search[selitem]) end
    end
  end

  local function select_searchrow(n)
    --restore previously selected row
    toolbar.sel_results_bar(itemsgrp)
    if selitem > 0 then toolbar.setbackcolor(get_rowname(selitem), (selitem%2==1) and toolbar.cfg.backcolor_erow or -1,false,true) end
    selitem= n --highlight new
    toolbar.setbackcolor(get_rowname(n), toolbar.cfg.backcolor_hi,false,true)
  end

  local function search_click(name) --click= select row
    select_searchrow(toolbar.getnum_cmd(name))
  end

  function toolbar.search_result(txt, toolt, bold, icon)
    nitems= nitems+1
    toolbar.sel_results_bar(itemsgrp)
    local name= get_rowname(nitems)
    toolbar.listtb_y= yout
    if #txt > 2000 then txt= txt:sub(1,2000).."..." end
    local oneline= Util.str_one_line(txt)
    if #oneline > 300 then oneline= oneline:sub(1,300).."..." end
    oneline= string.gsub(oneline, "\t", " ") --replace TABs with spaces
    local tt= (toolt ~= nil) and toolt or txt
    full_search[#full_search+1]= tt
    if #tt > 300 then tt= tt:sub(1,300).."..." end
    toolbar.list_add_txt_ico(name, oneline, tt, bold, search_click, icon, (nitems%2==1), 0, 0, 0, 250)
    yout= yout + toolbar.cfg.butsize
    toolbar.showresults("searchresults")
    return name
  end

  local function search_dclick(name) --double click= goto file
    local nr= toolbar.getnum_cmd(name)
    local pos= pos_search[nr]
    if pos then
      Proj.go_file(file_search[pos[1]], pos[2]) --goto file / linenum
    else
      buffer:copy_text(full_search[nr]) --copy the tooltip
    end
  end

  local curr_file= ""
  --------------- SEARCH RESULTS INTERFACE --------------
  function plugs.search_result_start(s_txt, s_filter)
    --a new "search in files" begin
    local name= toolbar.search_result("["..s_txt.."]", s_txt, true)
    toolbar.ensurevisible(name)
    select_searchrow(nitems)
    if s_filter then toolbar.search_result(' search dir '..s_filter, nil, false, nil) end
    curr_file= ""
    return true
  end

  function plugs.search_result_info(s_txt, iserror)
    --report info/error
    toolbar.search_result(s_txt, nil, true, (iserror) and "package-broken" or "package-installed-outdated")
  end

  function plugs.search_result_in_file(shortname, fname, nfiles)
    --set the file currently searched
    toolbar.search_result(shortname, fname, true, toolbar.icon_fname(fname))
    if #file_search == 0 or file_search[#file_search] ~= fname then file_search[#file_search+1]= fname end
    pos_search[nitems]= {#file_search, 0} --open file
    curr_file= shortname
  end

  function plugs.search_result_found(fname, nlin, txt, s_start, s_end)
    --set the location of the found
    local spos= ' @'..('%4d'):format(nlin)..": "..Util.str_trim(txt)
    toolbar.search_result(' '..spos, curr_file..spos, false, nil)
    if fname and (#file_search == 0 or file_search[#file_search] ~= fname) then file_search[#file_search+1]= fname end
    if nlin > 0 then pos_search[nitems]= {#file_search, nlin} end
  end

  function plugs.search_result_end()
    --mark the end of the search
    toolbar.sel_results_bar(itemsgrp)
    toolbar.listtb_y= yout
    toolbar.list_add_separator()
    yout= toolbar.listtb_y
    ensurevisible()
  end

  --------------- COMPARE FILE RESULTS INTERFACE --------------
  local function dump_changes(n, buff, r, fname)
    if n > 0 then
      local c= 10
      for i=1, #r, 2 do
        local line= buff:get_line(r[i] -1 + Util.LINE_BASE)
        plugs.search_result_found(fname, r[i], line, 0, 0)
        c= c-1
        if c == 0 then --only show first 10 blocks
          if i < #r-1 then plugs.search_result_info('...', false) end
          break
        end
      end
    end
  end

  function plugs.compare_file_result(n1, buffer1, r1, n2, buffer2, r2, n3, rm)
    toolbar.results_clear()

    local fn1= buffer1.filename and buffer1.filename or 'left buffer'
    local p,f,e= Util.splitfilename(fn1)
    if f == '' then f= fn1 end
    local f1=f

    local fn2= buffer2.filename and buffer2.filename or 'right buffer'
    p,f,e= Util.splitfilename(fn2)
    if f == '' then f= fn2 end

    plugs.search_result_start("File compare: "..f1..' - '..f, nil)
    if n1+n2+n3 == 0 then
      plugs.search_result_info( "No changes found", false)
      return
    end

    plugs.search_result_in_file(' (+) '..n1..' '..f1, fn1, 1)
    curr_file= f1
    dump_changes(n1, buffer1, r1, fn1) --enum lines that are only in buffer 1

    plugs.search_result_in_file(' (-) '..n2..' '..f, fn2, 2)
    curr_file= f
    dump_changes(n2, buffer2, r2, fn2) --enum lines that are only in buffer 2

    plugs.search_result_in_file(' (*) '..n3..' edited lines', fn1, 3)
    curr_file= f1
    dump_changes(n3, buffer1, rm, fn1) --enum modified lines in buffer 1
  end
  -------------------------------------------------------

  toolbar.registerresultstb("searchresults", "Search results", "system-search", search_create, search_notify, search_showlist, search_act)
  toolbar.cmd_dclick("sch-item", search_dclick)
end
