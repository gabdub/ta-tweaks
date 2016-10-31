local function toggle_showconfig()
  --toggle shown state
  local b="showconfig"
  if toolbar.config_toolbar_shown then
    toolbar.config_toolbar_shown= false
    toolbar.setthemeicon(b, "visualization")
    toolbar.settooltip(b, "Show configuration panel")
  else
    toolbar.config_toolbar_shown= true
    toolbar.setthemeicon(b, "ttb-proj-c")
    toolbar.settooltip(b, "Hide configuration panel")
  end
  toolbar.sel_config_bar()
  toolbar.show(toolbar.config_toolbar_shown)
end

--add a button to show/hide the config panel
function toolbar.add_showconfig_button()
  --add tab group if pending
  toolbar.addpending()
  --add a group of buttons after tabs
  toolbar.addrightgroup()
  toolbar.cmd("showconfig", toggle_showconfig, "Show configuration panel", "visualization")
end

function toolbar.config_tab_click(ntab)
  toolbar.sel_config_bar()
  toolbar.activatetab(ntab)
  toolbar.settext("cfgtit", toolbar.cfgtabs[ntab].." configuration", "", true)
  if toolbar.cfggroup[ntab] > 0 then
    toolbar.sel_toolbar_n(3,toolbar.cfggroup[toolbar.cfgcurgroup])
    toolbar.showgroup(false)
    toolbar.sel_toolbar_n(3,toolbar.cfggroup[ntab])
    toolbar.showgroup(true)
    toolbar.cfgcurgroup= ntab
  end
end

function toolbar.add_config_panel()
  toolbar.cfgtabs={"Buffer", "View", "Project", "Editor", "Toolbar"}
  toolbar.cfggroup={0,0,0,0,0}
  toolbar.cfgcurgroup=1

  --vertical right (config)
  toolbar.new(350, 24, 16, 3, toolbar.themepath)
  toolbar.current_toolbar= 3
  toolbar.current_tb_group= 0
  toolbar.seticon("TOOLBAR", "ttb-cback", 0, true)  --vertical back

  --config title: width=expand / height=27
  toolbar.addgroup(7, 0, 0, 27)
  toolbar.seticon("GROUP", "ttb-cback2", 0, true)
  toolbar.textfont(toolbar.textfont_sz+4, toolbar.textfont_yoffset, toolbar.statcolor_normal, toolbar.statcolor_normal)
  toolbar.addtext("cfgtit", toolbar.cfgtabs[1].." configuration", "", 350)
  toolbar.enable("cfgtit",false,true)

  toolbar.tabwithclose=false
  toolbar.tabwidthmode=0
  toolbar.tabwidthmin=0
  toolbar.add_tabs_here()
  toolbar.img[2]= "ttb-back-hi-2"
  toolbar.img[3]= "ttb-back-press-2"
  if toolbar.img[4]  == "" then toolbar.img[4]=  "ttb-tab-back" end
  if toolbar.img[7]  == "" then toolbar.img[7]=  "ttb-ntab3nc" end
  if toolbar.img[10] == "" then toolbar.img[10]= "ttb-dtab3nc" end
  if toolbar.img[13] == "" then toolbar.img[13]= "ttb-htab3nc" end
  if toolbar.img[16] == "" then toolbar.img[16]= "ttb-atab3nc" end
  for i, img in ipairs(toolbar.img) do
    if img ~= "" then toolbar.seticon("TOOLBAR", img, i, true) end
  end
  toolbar.seticon("GROUP", toolbar.back[1], 0, true)  --horizontal back x 1row
  toolbar.textfont(toolbar.textfont_sz, toolbar.textfont_yoffset, toolbar.textcolor_normal, toolbar.textcolor_grayed)
  for i,txt in ipairs(toolbar.cfgtabs) do
    toolbar.settab(i,txt, "")
  end
  toolbar.addgroup(7,8,0,0,false)
  toolbar.adjust(48,24,2,1,3,3)
  toolbar.addtext("", "text 1", "", 350)

  local function check_test()
    if toolbar._chk_a then
      toolbar._chk_a= false
      toolbar.setthemeicon("chk_a", "check0")
    else
      toolbar._chk_a= true
      toolbar.setthemeicon("chk_a", "check1")
    end
  end
  toolbar.cmd("chk_a", check_test, "Check test", "check0")
  toolbar.seticon("GROUP", "", 2, true)
  toolbar.seticon("GROUP", "", 3, true)

  toolbar.cfggroup[1]=3
  toolbar.addgroup(7,8,0,0,true)
  toolbar.addtext("", "text 2", "", 350)
  toolbar.cfggroup[2]=4
  toolbar.addgroup(7,8,0,0,true)
  toolbar.addtext("", "text 3", "", 350)
  toolbar.cfggroup[3]=5
  toolbar.addgroup(7,8,0,0,true)
  toolbar.addtext("", "text 4", "", 350)
  toolbar.cfggroup[4]=6
  toolbar.addgroup(7,8,0,0,true)
  toolbar.addtext("", "text 5", "", 350)
  toolbar.cfggroup[5]=7

  toolbar.activatetab(1)

  toolbar.show(false)
end

