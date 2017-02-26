if toolbar then
  --HTML quicktype toolbar
  local addclass= false
  local addid= false
  local addstyle= false

  local function type_before_after(before,after)
    if (buffer.selections > 1) or (buffer.selection_n_start[0] ~= buffer.selection_n_end[0]) then
      --if something is selected use enclose (left the cursor at the end)
      textadept.editing.enclose(before,after)
      return
    end
    --nothing is selected, left the cursor between 'before' and 'after'
    buffer.add_text(buffer, before)
    local pos= buffer.current_pos
    buffer.add_text(buffer, after)
    buffer.goto_pos(buffer, pos)
  end

  local function type_html(befclass,before,after)
    if addclass then befclass= befclass..' class=""'  end
    if addid    then befclass= befclass..' id=""'     end
    if addstyle then befclass= befclass..' style=""'  end
    type_before_after(befclass..before,after)
  end
  local function enc_html_html()
    type_before_after('<!DOCTYPE html>\n<html lang="es">\n<head>\n  <title></title>\n</head>\n<body>\n  ', '\n</body>\n</html>\n')
  end
  local function enc_html_para()
    type_html('<p','>', '</p>\n')
  end
  local function enc_html_bold()
    if addclass then
      type_before_after('<strong>', '</strong>')
    else
      type_before_after('<b>', '</b>')
    end
  end
  local function enc_html_italic()
    if addclass then
      type_before_after('<em>', '</em>')
    else
      type_before_after('<i>', '</i>')
    end
  end
  local function enc_html_underline()
    type_before_after('<u>', '</u>')
  end
  local function enc_html_ul()
    type_html('<ul','>\n', '</ul>\n')
  end
  local function enc_html_ol()
    type_html('<ol','>\n', '</ol>\n')
  end
  local function enc_html_li()
    type_html('<li','>', '</li>\n')
  end
  local function enc_html_table()
    type_html('<table','><tbody>\n', '</tbody></table>\n')
  end
  local function enc_html_row()
    type_html('<tr','>', '</tr>')
  end
  local function enc_html_data()
    type_html('<td','>', '</td>')
  end
  local function enc_html_input()
    type_html('<input',' type="" name="', '" value="">\n')
  end
  local function enc_html_link()
    type_html('<a href=""','>', '</a>')
  end
  local function enc_html_img()
    type_html('<img',' src="', '" alt="" />')
  end

  local function enc_html_class()
    local b="addclass"
    if addclass then
      addclass=false
      toolbar.settext(b, "cl", "HTML insert class: OFF")
    else
      addclass=true
      toolbar.settext(b, "CL", "HTML insert class: ON")
    end
  end
  local function enc_html_id()
    local b="addid"
    if addid then
      addid=false
      toolbar.settext(b, "id", "HTML insert id: OFF")
    else
      addid=true
      toolbar.settext(b, "ID", "HTML insert id: ON")
    end
  end
  local function enc_html_style()
    local b="addstyle"
    if addstyle then
      addstyle=false
      toolbar.settext(b, "st", "HTML insert style: OFF")
    else
      addstyle=true
      toolbar.settext(b, "ST", "HTML insert style: ON")
    end
  end

  --HTML quicktype toolbar
  function toolbar.add_html_toolbar()
    toolbar.sel_left_bar()
    toolbar.cmd("go-home",                enc_html_html,        "HTML basic blocks")
    toolbar.addspace()
    toolbar.cmd("edit-select-all",        enc_html_para,        "HTML paragraph")
    toolbar.cmd("format-text-bold",       enc_html_bold,        "HTML bold text")
    toolbar.cmd("format-text-italic",     enc_html_italic,      "HTML italic text")
    toolbar.cmd("format-text-underline",  enc_html_underline,   "HTML underline text")
    toolbar.addspace()
    toolbar.cmd("add-ul",                 enc_html_ul,          "HTML unordered list", "view-list-compact-symbolic")
    toolbar.cmd("add-ol",                 enc_html_ol,          "HTML ordered list", "view-list-details-symbolic")
    toolbar.cmd("add-li",                 enc_html_li,          "HTML list item", "list-add")
    toolbar.addspace()
    toolbar.cmd("view-list-icons-symbolic",enc_html_table,      "HTML table")
    toolbar.cmd("table-row",              enc_html_row,         "HTML table row",  "view-list-compact-symbolic")
    toolbar.cmd("table-data",             enc_html_data,        "HTML table data", "list-add")
    toolbar.cmd("table-input",            enc_html_input,       "HTML input", "gtk-edit")
    toolbar.addspace()
    toolbar.cmd("insert-link",            enc_html_link,        "HTML link")
    toolbar.cmd("insert-image",           enc_html_img,         "HTML image")
    toolbar.addspace()
    toolbar.cmdtext("cl",                 enc_html_class,       "HTML insert class: OFF", "addclass", true)
    toolbar.cmdtext("id",                 enc_html_id,          "HTML insert id: OFF",    "addid",    true)
    toolbar.cmdtext("st",                 enc_html_style,       "HTML insert style: OFF", "addstyle", true)
    toolbar.addspace()

    if actions then
      toolbar.idviewhtmltb= actions.add("toggle_viewhtmltb", 'Show HTML Tool_Bar', toolbar.html_toolbar_onoff, "sf10", nil, function()
        return (buffer.html_toolbar_on and 1 or 2) end) --check
      local med= actions.getmenu_fromtitle(_L['_View'])
      if med then
        local m=med[#med]
        m[#m+1]= "toggle_viewhtmltb"
      end
    end
    toolbar.html_tb= false --hide for now...
    toolbar.show(false)
  end

  function toolbar.html_toolbar_onoff()
    --if the current view is a project view, goto left/only files view. if not, keep the current view
    Proj.getout_projview()
    if buffer.html_toolbar_on == true then
      buffer.html_toolbar_on= false
    else
      buffer.html_toolbar_on= true
    end
    toolbar.show_html_toolbar('') --update toolbar
  end

  function toolbar.show_html_toolbar(lang)
    if lang ~= 'myproj' then --ignore project files
      if buffer.html_toolbar_on == nil then
        --default: show only in html files
        buffer.html_toolbar_on= (lang == 'html')
      end
      local on= buffer.html_toolbar_on
      if on ~= toolbar.html_tb then
        toolbar.html_tb= on
        toolbar.sel_left_bar()
        toolbar.show(on)
        --check menuitem
        if toolbar.idviewhtmltb then actions.setmenustatus(toolbar.idviewhtmltb, (on and 1 or 2)) end
        if toolbar then toolbar.setcfg_from_buff_checks() end --update config panel
      end
    end
  end

  --show vertical toolbar only in html files
  events.connect(events.LEXER_LOADED, toolbar.show_html_toolbar)
end
