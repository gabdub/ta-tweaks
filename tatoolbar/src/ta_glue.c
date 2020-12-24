// Copyright 2016-2020 Gabriel Dubatti. See LICENSE.
/* ============================================================================= */
/* GLUE between ta-toolbar and textadept/LUA/GTK                                 */
/*   when modified, touch textadept.c to compile (because it's "included" there) */
/* ============================================================================= */
#include "ta_toolbar.h"

#include "ta_filediff.h"

static PangoFontFamily ** font_families= NULL;
int n_font_families= 0;

static void load_fonts( void )
{ //load font list
  if( font_families == NULL ){
    PangoFontMap * fontmap;
    fontmap = pango_cairo_font_map_get_default();
    pango_font_map_list_families (fontmap, & font_families, & n_font_families);
  }
}

static void get_font_name( char *str, int str_sz, int nfont )
{ //return the name of the font family "nfont" (1...n_font_families, 0="")
  if( (nfont > 0) && (nfont <= n_font_families) && (str_sz > 1) ){
    PangoFontFamily * family = font_families[ nfont-1 ];
    const char * family_name= pango_font_family_get_name( family );
    strncpy( str, family_name, str_sz-1 );
    str[str_sz-1]= 0;
  }else{
    str[0]= 0;
  }
}

static void kill_fonts( void )
{ //free font list
  if( font_families != NULL ){
    g_free (font_families);
    font_families= NULL;
  }
}


//from textadept.c
static void show_context_menu(lua_State *L, GdkEventButton *event, char *k);
//pre-def
static void create_tatoolbar( lua_State *L, GtkWidget *vbox, int ntoolbar );
static void setmenuitemstatus( int menu_id, int status);
int toolbar_set_statusbar_text(const char *text, int bar);

static int _update_ui= 1; //on by default

/* ============================================================================= */
/*                                 LUA FUNCTIONS                                 */
/* ============================================================================= */
static int intluadef(lua_State *L, int npos, int defval )
{
  if( lua_isnumber(L, npos) ){
    return lua_tointeger(L, npos);
  }
  return defval;
}

static int intlua_ntoolbar(lua_State *L, int npos )
{
  int num= 0;
  if( lua_isboolean(L,npos) ){
    num= 0;   //FALSE: horizontal = #0
    if( lua_toboolean(L,npos) ){
      num= 1; //TRUE:  vertical   = #1
    }
  }else{
    num= lua_tointeger(L, npos);   //toolbar number (0:horizonal, 1:vertical,..)
    if( (num < 0) || (num >= NTOOLBARS) ){
      num= 0; //default #0
    }
  }
  return num;
}

//----- TOOLBARS -----
/** `toolbar.new(barsize,buttonsize,imgsize,toolbarnum/isvertical,imgpath,borderw)` Lua function. */
/** returns toolbar num */
static int ltoolbar_new(lua_State *L)
{
  const char * imgpath= NULL;
  int num= intlua_ntoolbar(L,4);
  if( !lua_isnone(L, 5) ){
    //change global image base
    imgpath= luaL_checkstring(L, 5);
  }
  ttb_new_toolbar(num, lua_tointeger(L, 1), lua_tointeger(L, 2), lua_tointeger(L, 3), imgpath, lua_tointeger(L, 6) );
  lua_pushinteger(L, num);  //toolbar num
  return 1;
}

/** `toolbar.adjust(bwidth,bheight,xmargin,ymargin,xoff,yoff)` Lua function. */
static int ltoolbar_adjust(lua_State *L)
{
  struct toolbar_group * G= current_group();
  if( G != NULL ){
    G->bwidth=  lua_tointeger(L, 1);
    G->bheight= lua_tointeger(L, 2);
    G->xmargin= lua_tointeger(L, 3);
    G->ymargin= lua_tointeger(L, 4);
    G->xoff=    lua_tointeger(L, 5);
    G->yoff=    lua_tointeger(L, 6);
    G->xnew= G->xmargin;
    G->ynew= G->ymargin;
  }
  return 0;
}

/** `toolbar.show(show,[newsize])` Lua function. */
static int ltoolbar_show(lua_State *L)
{
  show_toolbar(current_toolbar(), lua_toboolean(L,1), lua_tointeger(L, 2));
  return 0;
}

//----- GROUPS -----
/** `toolbar.seltoolbar(toolbarnum/isvertical, [groupnum], [emptygroup])` Lua function. */
static int ltoolbar_seltoolbar(lua_State *L)
{
  //set the current toolbar num
  select_toolbar_n( intlua_ntoolbar(L,1), lua_tointeger(L, 2), lua_toboolean(L,3) );
  return 0;
}

/** `toolbar.addgroup(xcontrol,ycontrol,width,height,[hidden])` Lua function. */
/** x/y control:
  0:allow groups before and after 1:no groups at the left/top  2:no groups at the right/bottom
  3:exclusive row/col  +4:expand  +8:use item size +16:vert-scroll +32:show-vscroll */
/** returns group num */
static int ltoolbar_addgroup(lua_State *L)
{ //create a new button group and set as current
  int  h, w, num;
  num= 0;
  struct toolbar_group * g= add_groupT_rcoh(current_toolbar(), lua_tointeger(L,1), lua_tointeger(L,2), lua_toboolean(L,5));
  if( g != NULL ){
    w= lua_tointeger(L,3);
    if( w > 0 ){
      g->barx2= g->barx1 + w;
    }
    h= lua_tointeger(L,4);
    if( h > 0 ){
      g->bary2= g->bary1 + h;
    }
    group_vscroll_onoff(g,0);
    num= g->num;
  }
  lua_pushinteger(L, num);  //toolbar num
  return 1;
}

/** `toolbar.addtabs(xmargin,xsep,withclose,mod-show,fontsz,fontyoffset,[tab-drag],[xcontrol],[height],[font-num])` Lua function. */
/** xcontrol: 0:allow groups before and after 1:no groups at the left 2:no groups at the right
              3:exclusive row  +4:x-expand  +8:use item size for width */
static int ltoolbar_addtabs(lua_State *L)
{
  ttb_new_tabs_groupT( current_toolbar(), lua_tointeger(L,1), lua_tointeger(L,2), lua_toboolean(L,3),
    lua_tointeger(L,4), lua_tointeger(L,5), lua_tointeger(L,6), lua_toboolean(L,7), lua_tointeger(L,8), lua_tointeger(L,9), lua_tointeger(L,10) );
  return 0;
}

/** `toolbar.showgroup(show)` Lua function. */
static int ltoolbar_showgroup(lua_State *L)
{
  ttb_show_groupG( current_group(), lua_toboolean(L,1) );
  return 0;
}

//----- BUTTONS -----
/** `toolbar.addbutton(name,tooltiptext,[base])` Lua function. */
static int ltoolbar_addbutton(lua_State *L)
{
  ttb_addbutton( luaL_checkstring(L, 1), luaL_checkstring(L, 2), lua_tointeger(L, 3) );
  return 0;
}

/** `toolbar.addtext(name,text,tooltiptext,width,dropbutton,leftalign,bold,xoff,yoff)` Lua function. */
static int ltoolbar_addtext(lua_State *L)
{
  ttb_addtext( luaL_checkstring(L, 1), NULL, luaL_checkstring(L, 3), luaL_checkstring(L, 2),
    lua_tointeger(L, 4), lua_toboolean(L,5), lua_toboolean(L,6), lua_toboolean(L,7),
    lua_tointeger(L, 8), lua_tointeger(L, 9));
  return 0;
}

/** `toolbar.addlabel(text,tooltiptext,width,leftalign,bold,name,xoff,yoff)` Lua function. */
static int ltoolbar_addlabel(lua_State *L)
{
  int flags= 0;
  if( lua_toboolean(L,4) ){
    flags |= TTBF_TEXT_LEFT; //left align text
  }
  if( lua_toboolean(L,5) ){
    flags |= TTBF_TEXT_BOLD; //use bold
  }
  ttb_addlabel( lua_tostring(L,6), NULL, luaL_checkstring(L, 2), luaL_checkstring(L, 1),
                lua_tointeger(L, 3), flags, lua_tointeger(L, 4), lua_tointeger(L, 5) );
  return 0;
}

/** `toolbar.addspace(space,hidebar)` Lua function. */
static int ltoolbar_addspace(lua_State *L)
{
  ttb_addspaceG( current_buttongrp(), lua_tointeger(L, 1), lua_toboolean(L,2) );
  return 0;
}

/** `toolbar.gotopos(x,y)` Lua function. */
/** `toolbar.gotopos(dx)`  Lua function. */
static int ltoolbar_gotopos(lua_State *L)
{
  int x,y;
  struct toolbar_group * g= current_buttongrp();
  if( g != NULL ){
    x= lua_tointeger(L, 1);
    if( lua_isnone(L, 2) ){
      //only one parameter: new row/column
      if( (g->flags & TTBF_GRP_VERTICAL) != 0 ){
        //new column
        x= g->xnew + g->bwidth + x;
        y= g->ymargin;
      }else{
        //new row
        y= g->ynew + g->bheight + x;
        x= g->xmargin;
      }
    }else{
      //2 parameters: x,y
      y= lua_tointeger(L, 2);
    }
    g->xnew= x;
    g->ynew= y;
  }
  return 0;
}

/** `toolbar.enable(name,isenabled,[isgrayed],[onlyinthistoolbar])` Lua function. */
static int ltoolbar_enable(lua_State *L)
{
  int isgrayed= 1;
  int isselectable= lua_toboolean(L,2);
  if( lua_isnone(L, 3) ){
    if(isselectable){
      isgrayed= 0;
    }
  }else{
    isgrayed= lua_toboolean(L,3);
  }
  ttb_enable( luaL_checkstring(L, 1), isselectable, isgrayed, lua_toboolean(L,4) );
  return 0;
}

/** `toolbar.selected(name,selected,pressed,[onlyinthistoolbar])` Lua function. */
static int ltoolbar_selected(lua_State *L)
{
  ttb_setselected( luaL_checkstring(L, 1), lua_toboolean(L,2), lua_toboolean(L,3), lua_toboolean(L,4) );
  return 0;
}

/** `toolbar.ensurevisible(name,[onlyinthistoolbar])` Lua function. */
/** ensure a button in a scrollable group is visible */
static int ltoolbar_ensurevisible(lua_State *L)
{
  ttb_ensurevisible( luaL_checkstring(L, 1), lua_toboolean(L,2) );
  return 0;
}

/** `toolbar.collapse(name,collapse,[hide height],[onlyinthistoolbar])` Lua function. */
/** collapse/expand a block of items under this */
static int ltoolbar_collapse(lua_State *L)
{
  ttb_collapse( luaL_checkstring(L, 1), lua_toboolean(L, 2), lua_tointeger(L, 3), lua_toboolean(L,4) );
  return 0;
}

/** `toolbar.seticon(name,icon,[nicon],[onlyinthistoolbar])` Lua function. */
/** name= button name or "TOOLBAR" or "GROUP" */
static int ltoolbar_seticon(lua_State *L)
{
  ttb_seticon( luaL_checkstring(L, 1), luaL_checkstring(L, 2), lua_tointeger(L, 3), lua_toboolean(L,4) );
  return 0;
}

/** `toolbar.setbackcolor(name,color,[keep-background-img],[onlyinthistoolbar])` Lua function. */
/** name= button name or "TOOLBAR" or "GROUP", color=RRGGBB,-1=transparent, -2=color-picker
 -3=chosen color, -4=chosen red, -5=chosen green, -6=chosen blue */
/** name= "CPICKER" = set color picker current color */
static int ltoolbar_setbackcolor(lua_State *L)
{
  ttb_setbackcolor( luaL_checkstring(L, 1), lua_tointeger(L, 2), lua_toboolean(L,3), lua_toboolean(L,4) );
  return 0;
}

/** `toolbar.settooltip(name,tooltip,[onlyinthistoolbar])` Lua function. */
static int ltoolbar_settooltip(lua_State *L)
{
  ttb_settooltip( luaL_checkstring(L, 1), luaL_checkstring(L, 2), lua_toboolean(L,3) );
  return 0;
}

/** `toolbar.settext(name,text,[tooltip],[onlyinthistoolbar])` Lua function. */
static int ltoolbar_settext(lua_State *L)
{
  const char *tooltip= NULL;
  if( !lua_isnone(L, 3) ){
    tooltip= luaL_checkstring(L, 3);
  }
  ttb_settext( luaL_checkstring(L, 1), luaL_checkstring(L, 2), tooltip, lua_toboolean(L,4) );
  return 0;
}

/** `toolbar.textfont(fontsize,fontyoffset,NORMcol,GRAYcol,font-number)` Lua function. */
static int ltoolbar_textfont(lua_State *L)
{
  ttb_set_text_fontcolG( current_buttongrp(), lua_tointeger(L, 1), lua_tointeger(L, 2),
    intluadef(L, 3, 0x000000), intluadef(L, 4, 0x808080), lua_tointeger(L, 5) );
  return 0;
}

/** `toolbar.anchor(name,xright,anchor_end)` Lua function.
  xright= distance from item.xleft to toolbar.xright / 0 = left aligned
*/
static int ltoolbar_anchor(lua_State *L)
{
  ttb_set_anchor( luaL_checkstring(L, 1), lua_tointeger(L, 2), lua_toboolean(L,3) );
  return 0;
}

/** `toolbar.setresize(name,t_resize,min-size)` Lua function.
*/
static int ltoolbar_setresize(lua_State *L)
{ //the button resize the toolbar
  ttb_set_resize( luaL_checkstring(L, 1), lua_toboolean(L, 2), lua_tointeger(L, 3) );
  return 0;
}

//----- TABS -----
/** `toolbar.tabfontcolor(NORMcol,HIcol,ACTIVEcol,MODIFcol,GRAYcol)` Lua function. */
static int ltoolbar_tabfontcolor(lua_State *L)
{
  int ncol, hcol, acol, mcol, gcol;
  ncol= intluadef(L, 1, 0x000000);  //normal:   default black
  hcol= intluadef(L, 2, ncol );     //highlight:default == normal
  acol= intluadef(L, 3, hcol );     //active:   default == highlight
  mcol= intluadef(L, 4, ncol );     //modified: default == normal
  gcol= intluadef(L, 5, 0x808080);  //grayed:   default medium gray
  ttb_set_tab_colorsG(current_tabbar(), ncol, hcol, acol, mcol, gcol);
  return 0;
}

/** `toolbar.settab(num,name,tooltiptext)` Lua function. */
static int ltoolbar_settab(lua_State *L)
{
  set_tabtextG( current_tabbar(), lua_tointeger(L, 1), luaL_checkstring(L, 2), luaL_checkstring(L, 3), 1);
  return 0;
}

/** `toolbar.deletetab(num)` Lua function. */
static int ltoolbar_deletetab(lua_State *L)
{
  ttb_delete_tabG( current_tabbar(), lua_tointeger(L, 1) );
  return 0;
}

/** `toolbar.activatetab(num)` Lua function. */
static int ltoolbar_activatetab(lua_State *L)
{
  ttb_activate_tabG( current_tabbar(), lua_tointeger(L, 1) );
  return 0;
}

/** `toolbar.enabletab(num,enable)` Lua function. */
static int ltoolbar_enabletab(lua_State *L)
{
  ttb_enable_tabG( current_tabbar(), lua_tointeger(L, 1), lua_toboolean(L,2));
  return 0;
}

/** `toolbar.modifiedtab(num,changed)` Lua function. */
static int ltoolbar_modifiedtab(lua_State *L)
{
  ttb_set_changed_tabG( current_tabbar(), lua_tointeger(L, 1), lua_toboolean(L,2));
  return 0;
}

/** `toolbar.hidetab(num,hide)` Lua function. */
static int ltoolbar_hidetab(lua_State *L)
{
  ttb_hide_tabG( current_tabbar(), lua_tointeger(L, 1), lua_toboolean(L,2));
  return 0;
}

/** `toolbar.tabwidth(num,WW,minwidth,maxwidth)` Lua function. */
/** `toolbar.tabwidth(num,text)` Lua function. */
/** WW= 0:text width, >0:fix, <0:porcent */
static int ltoolbar_tabwidth(lua_State *L)
{
  int ntab= lua_tointeger(L, 1);
  if( lua_isnumber(L,2) ){
    ttb_change_tabwidthG( current_tabbar(), ntab, lua_tointeger(L, 2), lua_tointeger(L, 3), lua_tointeger(L, 4) );

  }else if( lua_isstring(L,2) ){
    //use the width of the given text (set min = max)
    int minwidth= get_tabtext_widthG( current_tabbar(), lua_tostring(L, 2) );
    ttb_change_tabwidthG( current_tabbar(), ntab, 0, minwidth, minwidth );
  }
  return 0;
}

/** `toolbar.gototab(tabpos)` Lua function. */
static int ltoolbar_gototab(lua_State *L)
{ //generate a click in tab: -1:prev,1:next,0:first,2:last
  ttb_goto_tabG( current_tabbar(), lua_tointeger(L, 1));
  return 0;
}

/** `toolbar.getpickcolor()` Lua function. */
static int ltoolbar_getpickcolor(lua_State *L)
{
  lua_pushinteger(L,ttb.cpick.HSV_rgb);
  return 1;
}

/** `toolbar.getversion([opt])` Lua function. */
/** opt:  0:ta-toolbar version: "1.0.13 (Nov 13 2018)", 1: compilation date :"Nov 13 2018", 2:target TA version:"10.2", 3:GTK version: "2.24.32" */
/** opt:  4:number of font families */
/** opt:  100: "" (default font) */
/** opt:  101..100+tonumber(toolbar.getversion(4)): font names */
static int ltoolbar_getversion(lua_State *L)
{
  char str[200];
  int opt= lua_tointeger(L, 1);
  str[0]= 0;
  switch( opt ){
    case 0:   //0: tatoolbar version
      strcpy( str, get_toolbar_version() );
      break;

    case 1:   //1: compilation date
      strcpy( str, __DATE__ );
      break;

    case 2:   //2: target TA version
      sprintf( str, "%d.%d", TA_VERSION / 10, TA_VERSION % 10 );
      break;

    case 3:   //3: GTK version
      sprintf( str, "%d.%d.%d", GTK_MAJOR_VERSION, GTK_MINOR_VERSION, GTK_MICRO_VERSION );
      break;

    case 4:   //4: get the number of installed fonts
      sprintf( str, "%d", n_font_families );
      break;

    default:  //100:... get fonts name
      //to print all available fonts run:
      //  for i=101, tonumber(toolbar.getversion(4))+100 do print(i, toolbar.getversion(i)) end
      get_font_name( str, sizeof(str), opt-100 );
      break;
  }
  lua_pushstring(L,str);
  return 1;
}

/** `toolbar.getflags(name)` Lua function. */
static int ltoolbar_getflags(lua_State *L)
{
  lua_pushinteger(L,ttb_get_flags(luaL_checkstring(L, 1)));
  return 1;
}

/** `toolbar.getsize(tbnum)` Lua function.
return the toolbar height (horizontal tb) or width (vertical tb)
*/
static int ltoolbar_getsize(lua_State *L)
{
  lua_pushinteger(L,ttb_get_size(lua_tointeger(L, 1)));
  return 1;
}

/* ============================================================================= */
/*                      FUNCTIONS CALLED FROM TA-TOOLBAR                         */
/*                             GTK / CAIRO                                       */
/* ============================================================================= */
char * alloc_img_str( const char *name )
{ //build + alloc image filename
  int n;
  char *img_file;
  char *scopy= NULL;
  if( name != NULL ){
    n= strlen(name);
    if( (n > 4) && ((strcmp(name+n-4, ".png") == 0)||(strcmp(name+n-4, ".PNG") == 0)) ){
      //contains ".png": use it
      scopy= alloc_str( name );
    }else{
      //build image name
      if( ttb.img_base == NULL ){ //no global image base, use default
        img_file= g_strconcat(textadept_home, "/core/images/bar/", name, ".png", NULL);
      }else{
        img_file= g_strconcat(ttb.img_base, name, ".png", NULL);
      }
      if( img_file != NULL ){
        scopy= alloc_str( img_file );
        g_free(img_file);
      }
    }
  }
  return scopy;
}

/* ============================================================================= */
/*                                REDRAW                                         */
/* ============================================================================= */
void redraw_begG( struct toolbar_group *G )
{ //start a group modification
  struct toolbar_data *T;
  if( G != NULL ){
    T= G->toolbar;
    T->_grp_x1= G->barx1;
    T->_grp_x2= G->barx2;
    T->_grp_y1= G->bary1;
    T->_grp_y2= G->bary2;
    T->_layout_chg= 0;
  }
}

void redraw_endG( struct toolbar_group *G )
{ //redraw the group/toolbar
  struct toolbar_data *T;
  if( G != NULL ){
    T= G->toolbar;
    if( (T->flags & TTBF_TB_VISIBLE) != 0 ){
      if( T->_layout_chg ){
        //layout has changed, redraw the complete toolbar
        T->_layout_chg= 0;
        redraw_toolbar(T);
      }else{
        //union of before and after size change
        if( T->_grp_x1 > G->barx1 ){
          T->_grp_x1= G->barx1;
        }
        if( T->_grp_x2 < G->barx2 ){
          T->_grp_x2= G->barx2;
        }
        if( T->_grp_y1 > G->bary1 ){
          T->_grp_y1= G->bary1;
        }
        if( T->_grp_y2 < G->bary2 ){
          T->_grp_y2= G->bary2;
        }
        if( _update_ui ){
          gtk_widget_queue_draw_area(T->draw, G->barx1 + T->_grp_x1, G->bary1 + T->_grp_y1,
              T->_grp_x2 - T->_grp_x1 +1, T->_grp_y2 - T->_grp_y1 +1);
        }else{
          T->flags |= TTBF_TB_REDRAW;
        }
      }
    }
  }
}

void redraw_toolbar( struct toolbar_data *T )
{ //redraw the complete toolbar
  if( (T != NULL) && ((T->flags & TTBF_TB_VISIBLE) != 0) ){
    if( _update_ui ){
      gtk_widget_queue_draw(T->draw);
    }else{
      T->flags |= TTBF_TB_REDRAW;
    }
  }
}

void redraw_group( struct toolbar_group *G )
{
  if( (G != NULL) && ((G->toolbar->flags & TTBF_TB_VISIBLE) != 0) && ((G->flags & TTBF_GRP_HIDDEN) == 0) ){
    if( _update_ui ){
      gtk_widget_queue_draw_area(G->toolbar->draw, G->barx1, G->bary1,
        G->barx2 - G->barx1 +1, G->bary2 - G->bary1 +1 );
    }else{
      G->toolbar->flags |= TTBF_TB_REDRAW;
    }
  }
}

void redraw_item( struct toolbar_item * p )
{
  struct toolbar_group *g;
  if( p != NULL ){
    g= p->group;
    if( ((g->toolbar->flags & TTBF_TB_VISIBLE) != 0) && ((g->flags & TTBF_GRP_HIDDEN) == 0) ){
      //the group is visible
      if( (p->flags & (TTBF_TAB|TTBF_XBUTTON)) == 0 ){
        //redraw the area of one regular button
        int yoff= item_hiddenH_offset(p); //height of the hidden items above this one or -1 if this item is hidden
        if( yoff >= 0 ){  //the item is visible
          if( _update_ui ){
            gtk_widget_queue_draw_area(g->toolbar->draw,
              g->barx1 + p->barx1,      g->bary1 + p->bary1 - g->yvscroll - yoff,
              p->barx2 - p->barx1 +1,   p->bary2 - p->bary1 +1 );
          }else{
            g->toolbar->flags |= TTBF_TB_REDRAW;
          }
        }
        return;
      }
      //redraw a tab or one of its buttons
      //redraw the complete group
      redraw_group(g);
    }
  }
}

void redraw_pending_toolbars( void )
{
  int nt;
  for( nt= 0; nt < NTOOLBARS; nt++ ){
    if( ((ttb.tbdata[nt].flags & TTBF_TB_REDRAW) != 0) && (ttb.tbdata[nt].draw != NULL) ){
      gtk_widget_queue_draw(ttb.tbdata[nt].draw);
      ttb.tbdata[nt].flags &= ~TTBF_TB_REDRAW;
    }
  }
}

static void ctx_set_font( cairo_t * ctx, int fontsz, int bold, int font_num )
{
  char fname[300];
  if( (font_num > 0) || (bold != 0) ){
    get_font_name( fname, sizeof(fname), font_num );
    if( bold == 0 ){
      cairo_select_font_face(ctx, fname, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL );
    }else{
      cairo_select_font_face(ctx, fname, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD );
    }
  }
  cairo_set_font_size(ctx, fontsz);
}

void draw_txt( void * gcontext, const char *txt, int x, int y, int y1, int w, int h, struct color3doubles *color, int fontsz, int bold, int font_num )
{
  if( txt != NULL ){
    cairo_t *ctx= (cairo_t *) gcontext;
    cairo_save(ctx);
    cairo_rectangle(ctx, x, y1, w, h );
    cairo_clip(ctx);
    cairo_move_to(ctx, x, y);
    cairo_set_source_rgb(ctx, color->R, color->G, color->B);
    ctx_set_font( ctx, fontsz, bold, font_num );
    cairo_show_text(ctx, txt);
    cairo_restore(ctx);
  }
}

void draw_img( void * gcontext, struct toolbar_img *pti, int x, int y, int grayed )
{
  if( pti != NULL ){
    cairo_t *ctx= (cairo_t *) gcontext;
    cairo_pattern_t *radpat;
    cairo_surface_t *img= cairo_image_surface_create_from_png(pti->fname);
    if( img != NULL ){
      cairo_save(ctx);
      cairo_translate(ctx, x, y);
      cairo_pattern_t *pattern= cairo_pattern_create_for_surface(img);
      cairo_pattern_set_extend(pattern, CAIRO_EXTEND_NONE);
      cairo_set_source(ctx, pattern);

      if( grayed ){
        radpat = cairo_pattern_create_rgba(0, 0, 0, 0.5);
        cairo_mask(ctx, radpat);
        cairo_pattern_destroy(radpat);
      }else{
        //cairo_rectangle(ctx, 0, 0, pti->width, pti->height);
        cairo_paint(ctx);
      }
      cairo_pattern_destroy(pattern);
      cairo_restore(ctx);
      cairo_surface_destroy(img);
    }
  }
}

//Fill a rectangle with a normal IMAGE
void draw_fill_img( void * gcontext, struct toolbar_img *pti, int x, int y, int w, int h )
{
  if( pti != NULL ){
    cairo_surface_t *img= cairo_image_surface_create_from_png(pti->fname);
    if( img != NULL ){
      cairo_t *ctx= (cairo_t *) gcontext;
      cairo_save(ctx);
      cairo_translate(ctx, x, y);
      cairo_pattern_t *pattern= cairo_pattern_create_for_surface(img);
      cairo_pattern_set_extend(pattern, CAIRO_EXTEND_REPEAT);
      cairo_set_source(ctx, pattern);
      cairo_rectangle(ctx, 0, 0, w, h);
      cairo_fill(ctx);
      cairo_pattern_destroy(pattern);
      cairo_restore(ctx);
      cairo_surface_destroy(img);
    }
  }
}

//Fill a rectangle with a multi-part IMAGE
void draw_fill_mp_img( void * gcontext, struct toolbar_img *pti, int x, int y, int w, int h )
{
  int xs[3], ys[3], ws[3], hs[3]; //source
  int xd[3], yd[3], wd[3], hd[3]; //destination
  int ht, hb, hh;
  int wl, wr, ww;
  int row, col;

  if( pti == NULL ){
    return;
  }

  if( ((pti->width == w)||((pti->width_l+pti->width_r) == 0)) && ((pti->height == h)||((pti->height_t+pti->height_b) == 0))  ){
    //special case: if no change in size is needed or the image doesn't have borders (in both dimmensions):
    // the rectangle can be filled in a "normal" way, it's quicker
    draw_fill_img( gcontext, pti, x, y, w, h );
    return;
  }

  cairo_t *ctx= (cairo_t *) gcontext;
  if( (w > 0) && (h > 0) ){
    cairo_surface_t *img= cairo_image_surface_create_from_png(pti->fname);
    if( img != NULL ){
      //--calc source--
      wl= pti->width_l;
      wr= pti->width_r;
      if( pti->width == w ){
        //special case: the image has the same width as the rectangle to fill
        wl= w;  //draw it in one block
        wr= 0;
      }else if( (w < pti->width) && (w > wl+wr) ){
        //special case: the rectangle to fill is smaller than the image but both borders are shown
        wl= w - wr; //add the variable part to the left border
      }
      xs[0]= 0;
      ws[0]= wl;
      xs[1]= wl;
      ws[1]= pti->width - wl - wr;
      xs[2]= pti->width - wr;
      ws[2]= wr;

      ht= pti->height_t;
      hb= pti->height_b;
      if( pti->height == h ){
        //special case: the image has the same height as the rectangle to fill
        ht= h;  //draw it in one block
        hb= 0;
      }else if( (h < pti->height) && (h > ht+hb) ){
        //special case: the rectangle to fill is smaller than the image but both borders are shown
        ht= h - hb; //add the variable part to the top border
      }
      ys[0]= 0;
      hs[0]= ht;
      ys[1]= ht;
      hs[1]= pti->height - ht - hb;
      ys[2]= pti->height - hb;
      hs[2]= hb;

      //--calc destination--
      if( wl >= w ){
        wl= w;      //only a part of the left column is visible
        wr= 0;
        ww= 0;
      }else if( (wl+wr) >= w ){
        wr= w - wl; //only a part of the right column is visible
        ww= 0;
      }else{
        ww= w - wl - wr;
      }
      xd[0]= x;
      wd[0]= wl;
      xd[1]= x + wl;
      wd[1]= ww;
      xd[2]= x + wl + ww;
      wd[2]= wr;

      if( ht >= h ){
        ht= h;      //only a part of the top row is visible
        hb= 0;
        hh= 0;
      }else if( (ht+hb) >= h ){
        hb= h - ht; //only a part of the bottom row is visible
        hh= 0;
      }else{
        hh= h - ht - hb;
      }
      yd[0]= y;
      hd[0]= ht;
      yd[1]= y + ht;
      hd[1]= hh;
      yd[2]= y + ht + hh;
      hd[2]= hb;

      //--fill the rectangle--
      for( row= 0; row < 3; row++ ){
        if( hs[row] > 0 ){
          for( col= 0; col < 3; col++ ){
            if( ws[col] > 0 ){
              //draw a section of a multi-part IMAGE
              cairo_surface_t *secimg= cairo_surface_create_for_rectangle( img, xs[col], ys[row], ws[col], hs[row] );
              cairo_save(ctx);
              cairo_translate(ctx, xd[col], yd[row]);
              cairo_pattern_t *pattern= cairo_pattern_create_for_surface(secimg);
              cairo_pattern_set_extend(pattern, CAIRO_EXTEND_REPEAT);
              cairo_set_source(ctx, pattern);
              cairo_rectangle(ctx, 0, 0, wd[col], hd[row]);
              cairo_fill(ctx);
              cairo_pattern_destroy(pattern);
              cairo_restore(ctx);
              cairo_surface_destroy(secimg);
            }
          }
        }
      }
      cairo_surface_destroy(img);
    }
  }
}


static int MMboxcount( struct minimap_line * pml, int b, int maxc )
{
  int n= 0;
  while( pml->linenum < b ){
    n++;
    if( n >= maxc ){
      break;
    }
    pml= pml->next;
    if( pml == NULL ){
      break;
    }
  }
  return n;
}

void draw_box( void * gcontext, int x, int y, int w, int h, int color, int fill ){
  struct color3doubles c;
  cairo_t *ctx= (cairo_t *) gcontext;
  setrgbcolor( color, &c );
  cairo_set_source_rgb(ctx, c.R, c.G, c.B );
  cairo_rectangle(ctx, x, y, w, h);
  if( fill ){
    cairo_fill(ctx);
  }else{
    cairo_stroke(ctx);
  }
}

void draw_fill_color( void * gcontext, int color, int x, int y, int w, int h, struct toolbar_img * opt_pti )
{
  struct color3doubles c;
  int i, j, n, xr, yr, dx, dy, a, b, hp, bwcol;
  double v, min, max, dv, tcol;
  char str[16];
  cairo_t *ctx= (cairo_t *) gcontext;

  if( color == BKCOLOR_NOT_SET ){
    return;
  }
  if( color == BKCOLOR_PICKER ){
    //== COLOR PICKER ==
    //HSV color wheel
    //  H   0º    60º   120º  180º  240º  300º
    //  R   max   down  min   min   up    max
    //  G   up    max   max   down  min   min
    //  B   min   min   up    max   max   down
    // max= V
    // min= V*(1-S)
    //X => H
    //Y => S
    //mouse wheel => V
    max= ttb.cpick.HSV_val; //V [0, 1] value of color picker (only one for now...)
    min= 0.0;
    hp= h-(PICKER_MARG_TOP+PICKER_MARG_BOTT);
    dx= (w-(PICKER_MARG_LEFT+PICKER_MARG_RIGHT+PICKER_VSCROLLW)) / PICKER_CELL_W;   //w=250-10 = 240
    dy= hp / PICKER_CELL_H;   //h=242-2= 240
    yr= y + PICKER_MARG_TOP;
    for( i= 0; i < (PICKER_CELL_H-1); i++){
      xr= x + PICKER_MARG_LEFT;
      c.R= max;
      c.G= min;
      c.B= min;
      v= 0;
      dv= (max - min) / ((double)(PICKER_CELL_W/6));
      a= -1;
      for( j= 0; j < PICKER_CELL_W; j++){
        if( (j % (PICKER_CELL_W/6)) == 0 ){
          v= 0;
          a++;
        }
        switch( a ){
        case 0:
          c.G= min+v;
          break;
        case 1:
          c.R= max-v;
          c.G= max;
          break;
        case 2:
          c.R= min;
          c.B= min+v;
          break;
        case 3:
          c.G= max-v;
          c.B= max;
          break;
        case 4:
          c.R= min+v;
          c.G= min;
          break;
        case 5:
          c.R= max;
          c.B= max-v;
          break;
        }
        cairo_set_source_rgb(ctx, c.R, c.G, c.B );
        cairo_rectangle(ctx, xr, yr, dx, dy);
        cairo_fill(ctx);
        xr += dx;
        v += dv;
      }
      yr += dy;
      min += max / ((double)PICKER_CELL_H);
    }
    //last row (B/W)
    xr= x + PICKER_MARG_LEFT;
    c.R= 0;
    c.G= 0;
    c.B= 0;
    dv= 1.0 / (PICKER_CELL_W-1);
    for( j= 0; j < PICKER_CELL_W; j++){
      cairo_set_source_rgb(ctx, c.R, c.G, c.B );
      cairo_rectangle(ctx, xr, yr, dx, dy);
      cairo_fill(ctx);
      xr += dx;
      c.R += dv;
      if( c.R > 1.0 ){
        c.R= 1.0;
      }
      c.G= c.R;
      c.B= c.R;
    }
    //highligth actual selection
    xr= x + PICKER_MARG_LEFT + ttb.cpick.HSV_x * dx;
    yr= y + PICKER_MARG_TOP + ttb.cpick.HSV_y * dy;
    cairo_set_line_width(ctx,1);
    bwcol= 0;
    if( ttb.cpick.HSV_y == (PICKER_CELL_H-1) ){
      //last row (B/W)
      if( ttb.cpick.HSV_x < PICKER_CELL_W/2 ){
        bwcol= 0xFFFFFF;
      }
    }else{
      //color
      if( (ttb.cpick.HSV_val < 0.7) ||
          (((ttb.cpick.HSV_rgb & 0xff) > 0x80) && (ttb.cpick.HSV_rgb & 0xff00) < 0x8000) ){
        bwcol= 0xFFFFFF;  //white over dark colors
      }
    }
    draw_box( ctx, xr, yr, dx, dy, bwcol, 0 ); //box border

    //Vscroll bar
    xr= x+w-PICKER_VSCROLLW;
    draw_box( ctx, xr, y+PICKER_MARG_TOP, PICKER_VSCROLLW, hp, 0x808080, 1 ); //filled box 50% gray
    yr= y + PICKER_MARG_TOP + hp * (1-ttb.cpick.HSV_val) * (1-HSV_V_DELTA);
    dy= hp * HSV_V_DELTA;
    draw_box( ctx, xr, yr, PICKER_VSCROLLW, dy, 0x4C4C4C, 1 ); //filled box 30% gray
    draw_box( ctx, xr+1, yr+1, PICKER_VSCROLLW-2, dy-2, 0x989898, 1 ); //filled box 60% gray

  }else if( color == BKCOLOR_MINIMAP_DRAW ){
    //=== MINI MAP ===
    struct minimap_line * pml= ttb.minimap.lines;
    if( (ttb.minimap.height > 0) && (ttb.minimap.linecount > 0) && (pml != NULL) ){
      if( h > ttb.minimap.height ){
        h= ttb.minimap.height;
      }
      //draw scrollbar if set
      if( ttb.minimap.linesscreen > 0){
        n= ttb.minimap.linesscreen;
        if( n > ttb.minimap.linecount){
          n= ttb.minimap.linecount;
        }
        yr= ttb.minimap.firstvisible-1;
        if( (yr+n) > ttb.minimap.linecount ){
          yr= ttb.minimap.linecount - n;
        }
        if( yr < 0 ){
          yr= 0;
        }
        n= ((n+1) * ttb.minimap.boxesheight +ttb.minimap.linecount-1)/ttb.minimap.linecount;
        yr= y + (yr * ttb.minimap.boxesheight +ttb.minimap.linecount-1)/ttb.minimap.linecount;
        //draw the scrollbar box
        if( opt_pti != NULL ){
          draw_fill_mp_img(ctx, opt_pti, x, yr, w, n ); //use the provided image
        }else{
          draw_box( ctx, x, yr, w, n, ttb.minimap.scrcolor, 0 ); //if not, draw a box
        }
      }
      //draw boxes
      i= 1 << 4;
      j= (ttb.minimap.linecount+1) << 4;
      yr= y+1;
      while( i <= j ){
        a= i >> 4; //block first line
        i += ttb.minimap.lineinc;
        b= i >> 4; //next block first line
        while( pml->linenum < a ){
          pml= pml->next;
          if( pml == NULL){
            break;
          }
        }
        if( pml == NULL){
          break;
        }
        //count up to 3 items per box
        n= MMboxcount( pml, b, 3 );
        if( n > 0 ){
          int wi= w-2;
          if( n > 1){
            wi= (w-n)/n;
          }
          int xi= x+1;
          while(1){
            draw_box( ctx, xi, yr, wi, ttb.minimap.yszbox-1, pml->color, 1 ); //filled box

            xi += wi+1;
            if( --n == 0 ){
              break;
            }
            pml= pml->next;
          };
        }
        yr += ttb.minimap.yszbox;
      }
    }

  }else if( color == BKCOLOR_TBH_SCR_DRAW ){
    //=== TBH_SCROLL ===
    if( (ttb.tbh_scroll.width > 0) && (ttb.tbh_scroll.maxcol > 0) ){
      if( w > ttb.tbh_scroll.width ){
        w= ttb.tbh_scroll.width;
      }
      //draw scrollbar if set
      if( ttb.tbh_scroll.colsscreen > 0){
        n= ttb.tbh_scroll.colsscreen;
        if( n > ttb.tbh_scroll.maxcol){
          n= ttb.tbh_scroll.maxcol;
        }
        xr= ttb.tbh_scroll.firstvisible-1;
        if( (xr+n) > ttb.tbh_scroll.maxcol ){
          xr= ttb.tbh_scroll.maxcol - n;
        }
        if( xr < 0 ){
          xr= 0;
        }
        n= (n*ttb.tbh_scroll.width)/ttb.tbh_scroll.maxcol;
        xr= x + ((xr * ttb.tbh_scroll.width)/ttb.tbh_scroll.maxcol);
        //draw the scrollbar box
        if( opt_pti != NULL ){
          draw_fill_mp_img(ctx, opt_pti, xr, y, n, h ); //use the provided image
        }else{
          draw_box( ctx, xr, y, n, h, ttb.tbh_scroll.scrcolor, 0 ); //if not, draw a box
        }
      }
    }

  }else if( (color == BKCOLOR_MINIMAP_CLICK) || (color == BKCOLOR_TBH_SCR_CLICK) ){
    //it's a transparent button
  }else{
    str[0]= 0;
    tcol= 1; //text color= black (0) or white (1)
    if( color == BKCOLOR_SEL_COLOR ){
      color= ttb.cpick.HSV_rgb; //choosen color in HSV color picker
      sprintf( str, "%06X", color );
      tcol= 0; //black
      if( ttb.cpick.HSV_y == (PICKER_CELL_H-1) ){
        //last row (B/W)
        if( ttb.cpick.HSV_x < PICKER_CELL_W/2 ){
          tcol= 1; //white over dark grays
        }
      }else{
        //color
        if( (ttb.cpick.HSV_val < 0.7) ||
            (((ttb.cpick.HSV_rgb & 0xff) > 0x80) && (ttb.cpick.HSV_rgb & 0xff00) < 0x8000) ){
          tcol= 1; //white over dark colors
        }
      }
    }else if( color == BKCOLOR_SEL_COL_R ){
      color= 0xFF0000; //RED
      sprintf( str, "%02X", (ttb.cpick.HSV_rgb >> 16) & 0xFF );
    }else if( color == BKCOLOR_SEL_COL_G ){
      color= 0x00FF00; //GREEN
      sprintf( str, "%02X", (ttb.cpick.HSV_rgb >> 8) & 0xFF );
      tcol= 0; //black text
    }else if( color == BKCOLOR_SEL_COL_B ){
      color= 0x0000FF; //BLUE
      sprintf( str, "%02X", ttb.cpick.HSV_rgb & 0xFF );
    }
    //solid color
    draw_box( ctx, x, y, w, h, color, 1 ); //filled box

    if( str[0] != 0 ){
      c.R= tcol;  c.G= tcol;   c.B= tcol;
      draw_txt(ctx, str, x+4, y+16, y, w-8, h, &c, 10, 0, 0 );
    }
  }
}

static int get_mp_param( char *s, char opt )
{
  s= strchr( s, opt );
  if( s != NULL ){
    while( (*s != 0) && (*s != '.') ){
      if( (*s >= '0') && (*s <= '9') ){
        return atoi(s);
      }
      s++;
    }
  }
  return 0;
}

//get borders size of multi-part images from filename
//filename format: fffff[__[L##][R##][T##][B##]].png
//or __[W##] => L=R=(image_width-W)/2
//or __[H##] => T=B=(image_height-H)/2
//valid examples:
//  f__ff__L10R15.png  : left border = 10, right= 15
//  fff__LRTB5.png     : all borders = 5
//  fff__LR5TB10.png   : left/right borders = 5, top/bottom borders = 10
//  fff__WH16.png      : if the image size is 32x32, the center part = 16x16 and the borders are 8
static void set_mp_borders( struct toolbar_img *pti )
{
  char *s, *last__;
  int n;

  //find the last "__"
  last__= NULL;
  s= strstr(pti->fname, "__");
  while( s != NULL ){
    last__= s;
    s= strstr(s+2, "__");
  }
  if( last__ != NULL ){
    //check that only valid chars are between "__" and "."
    last__ += 2;
    for( s= last__; (*s != 0)&&(*s != '.'); s++ ){
      if( strchr( "0123456789LRTBWH", *s) == NULL ){
        return; //invalid char found, ignore
      }
    }
    n= get_mp_param( last__, 'W' );
    if( (n > 0) && (n <= pti->width) ){
      pti->width_l= (pti->width -n)/2;
      pti->width_r= pti->width - n - pti->width_l;
    }else{
      pti->width_l= get_mp_param( last__, 'L' );
      pti->width_r= get_mp_param( last__, 'R' );
      if( (pti->width_l+pti->width_r) > pti->width ){
        pti->width_l= 0;
        pti->width_r= 0;
      }
    }
    n= get_mp_param( last__, 'H' );
    if( (n > 0) && (n <= pti->height) ){
      pti->height_t= (pti->height -n)/2;
      pti->height_b= pti->height - n - pti->height_t;
    }else{
      pti->height_t= get_mp_param( last__, 'T' );
      pti->height_b= get_mp_param( last__, 'B' );
      if( (pti->height_t+pti->height_b) > pti->height ){
        pti->height_t= 0;
        pti->height_b= 0;
      }
    }
  }
}

int set_img_size( struct toolbar_img *pti )
{
  int ok= 0;
  cairo_surface_t *cis= cairo_image_surface_create_from_png(pti->fname);
  if( cis != NULL ){
    pti->width=  cairo_image_surface_get_width(cis);
    pti->height= cairo_image_surface_get_height(cis);
    if( (pti->width > 0) && (pti->height > 0)){
      //get borders size of multi-part images from filename
      set_mp_borders( pti );
      ok= 1; //image OK
    }
    cairo_surface_destroy(cis);
  }
  return ok;
}

static GtkWidget * get_draw_widget( struct toolbar_data * T )
{
  if( T == NULL ){
    return NULL;
  }
  return (GtkWidget *) T->draw;
}

static GtkWidget * get_draw_tb0_widget( void )
{
  return (GtkWidget *) ttb.tbdata[0].draw;
}

int set_text_bt_width(struct toolbar_item * p )
{ //text button (text & no image)
  cairo_text_extents_t ext;
  struct toolbar_img * tn;
  int diff= 0;
  struct toolbar_group *G= p->group;
  if( p->text != NULL ){
    int htb= TTBI_TB_BUT_HILIGHT;
    if( (p->flags & TTBF_DROP_BUTTON) != 0 ){
      htb= TTBI_TB_DDBUT_HILIGHT;
    }
    //use toolbar #0 to measure text (pop-ups may not have a window yet)
    cairo_t *cr = gdk_cairo_create(get_draw_tb0_widget()->window);
    if( (p->flags & TTBF_TAB) == 0 ){
      ctx_set_font( cr, G->txtfontsz, 0, G->txtfontnum );
    }else{
      ctx_set_font( cr, G->tabfontsz, 0, G->tabfontnum );
    }
    cairo_text_extents( cr, p->text, &ext );
    p->textwidth= (int) ext.width;
    if( G->txttexty < 0 ){
      cairo_text_extents( cr, "H", &ext );
      G->txttexth= (int) ext.height;
      //center text verticaly + offset
      G->txttexty= ((G->bheight + G->txttexth)/2) + G->txttextoff;
      if( G->txttexty < 0){
        G->txttexty= 0;
      }
    }
    cairo_destroy(cr);
    diff= p->barx2;

    tn= get_group_img(G,htb);
    if( tn != NULL ){
      p->prew= tn->width_l;
      p->postw= tn->width_r;
    }else{
      p->prew= 4;
      p->postw= 4;
    }

    p->txtx= p->barx1 + p->prew;  //left align
    p->txty= p->bary1 + G->txttexty;
    p->barx2= p->txtx + p->textwidth + p->postw;
    if( p->barx2 < (p->barx1+p->minwidth)){
      //expand button
      if( (p->flags & TTBF_TEXT_LEFT) == 0){  //center text
        p->txtx += (p->barx1 + p->minwidth - p->barx2)/2;
      }
      p->barx2= p->barx1+p->minwidth;
    }
    if( (p->maxwidth > 0) && (p->barx2 > (p->barx1+p->maxwidth)) ){
      //reduce button (trim text)
      p->barx2= p->barx1+p->maxwidth;
    }
    diff= p->barx2 - diff;  //width diff
  }
  return diff;
}

int get_text_width( const char * text, int fontsz, int font_num )
{
  int w;
// NOTE: using variable width in status-bar fields 2..7 in "WIN32" breaks the UI!!
// this fields are updated from the UPDATE-UI event and
// calling gdk_cairo_create in this context (to get the text extension) freeze the UI for a second
// and breaks the editor update mecanism (this works fine under LINUX, though)
// so, fixed width is used for this fields
  cairo_text_extents_t ext;
  //use toolbar #0 to measure text (pop-ups may not have a window yet)
  cairo_t *cr = gdk_cairo_create(get_draw_tb0_widget()->window); //get_draw_widget(p->group->toolbar)->window);
  ctx_set_font( cr, fontsz, 0, font_num );
  cairo_text_extents( cr, text, &ext );
  w= (int) ext.width +1; //+1 to see the antialiasing complete
  cairo_destroy(cr);
  return w;
}

int get_text_height( const char * text, int fontsz, int font_num )
{
  int h;
  cairo_text_extents_t ext;
  //use toolbar #0 to measure text (pop-ups may not have a window yet)
  cairo_t *cr = gdk_cairo_create(get_draw_tb0_widget()->window); //get_draw_widget(p->group->toolbar)->window);
  ctx_set_font( cr, fontsz, 0, font_num );
  cairo_text_extents( cr, text, &ext );
  h= (int) ext.height;
  cairo_destroy(cr);
  return h;
}

void clear_tooltip_textT( struct toolbar_data *T )
{
  gtk_widget_set_tooltip_text(T->draw, "");
}

void set_hilight_tooltipT( struct toolbar_data *T )
{ //update tooltip text
  char *tooltip= "";
  if( (ttb.philight != NULL) && (ttb.ntbhilight == T->num) ){
    if(ttb.philight->tooltip != NULL){
      tooltip= ttb.philight->tooltip;
    }
  }
  gtk_widget_set_tooltip_text(T->draw, tooltip);
}

/* ============================================================================= */
/*                                EVENTS                                         */
/* ============================================================================= */
static void ttb_size_ev(GtkWidget *widget, GdkRectangle *prec, void*__)
{
  ttb_set_toolbarsize( toolbar_from_widget(widget), prec->width, prec->height );
}

static gboolean ttb_paint_ev(GtkWidget *widget, GdkEventExpose *event, void*__)
{
  int x0, y0, wt, ht, y2;
  struct toolbar_group *g;
  struct area drawarea;

  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T == NULL ){
    return FALSE;
  }

  //get the area to paint
  drawarea.x0= event->area.x;
  drawarea.y0= event->area.y;
  drawarea.x1= drawarea.x0 + event->area.width;
  drawarea.y1= drawarea.y0 + event->area.height;

  //if size is unknown, get it now
  if( (T->barwidth < 0) || (T->barheight < 0) ){
    ttb_set_toolbarsize( T, widget->allocation.width, widget->allocation.height );
  }

  cairo_t *cr = gdk_cairo_create(widget->window);

  //paint toolbar/group backgrounds
  paint_toolbar_back( T, cr, &drawarea );

  //draw all visible groups
  for( g= T->group; (g != NULL); g= g->next ){
    if( (g->flags & TTBF_GRP_HIDDEN) == 0 ){
      x0= g->barx1;
      y0= g->bary1;
      y2= g->bary2;
      if( y2 > T->barheight - T->borderw ){
        y2= T->barheight - T->borderw;
      }
      if( (y2 > y0) && need_redraw( &drawarea, x0, y0, g->barx2, y2) ){
        wt= g->barx2 - g->barx1 - g->show_vscroll_w; //don't draw over the scrollbar
        ht= y2 - y0;
        cairo_save(cr);
        cairo_rectangle(cr, x0, y0, wt, ht );
        cairo_clip(cr);
        //draw visible group's items
        paint_group_items(g, cr, &drawarea, x0, y0, wt, ht);
        //draw_box(cr, x0, y0, wt, ht, 0x800000, 0); //debug: show group borders
        cairo_restore(cr);
        if( g->show_vscroll_w > 0 ){ //draw the vertical scrollbar
          paint_vscrollbar(g, cr, &drawarea, x0+wt, y0, g->show_vscroll_w, ht);
        }
      }
    }
  }
  cairo_destroy(cr);
  return TRUE;
}

static gboolean ttb_mouseleave_ev(GtkWidget *widget, GdkEventCrossing *event)
{
  mouse_leave_toolbar( toolbar_from_widget(widget) );
  return FALSE;
}

static gboolean ttb_mousemotion_ev( GtkWidget *widget, GdkEventMotion *event )
{
  int x, y;
  GdkModifierType state;

  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T == NULL ){
    return FALSE;
  }

  if(event->is_hint){
    gdk_window_get_pointer(event->window, &x, &y, &state);
  }else{
    x = event->x;
    y = event->y;
  }
  mouse_move_toolbar(T, x, y);
  return TRUE;
}

static gboolean ttb_scrollwheel_ev(GtkWidget *widget, GdkEventScroll* event, void*__)
{
  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T != NULL ){
    //don't scroll if a button is pressed (mouse still down)
    if( ttb.phipress == NULL ){
      int shift= 0;
      if( (event->state & GDK_SHIFT_MASK) != 0){
        shift= 1;
      }
      if( (event->direction == GDK_SCROLL_UP)||(event->direction == GDK_SCROLL_LEFT) ){
        scroll_toolbarT(T, event->x, event->y, -1, shift);
      }else{
        scroll_toolbarT(T, event->x, event->y, 1, shift);
      }
    }
  }
  return TRUE;
}

static char * tabevtype_name[TEV_N_EVS]={
  "toolbar_tabclicked",    //TEV_CLICK
  "toolbar_tab2clicked",   //TEV_2CLICK
  "toolbar_tabRclicked",   //TEV_RCLICK
  "toolbar_tabclose"       //TEV_CLOSE
};

int fire_tab_event( struct toolbar_item * p, int evtype )
{ //emit event(tab.num, toolbar.num, tabgroup.num)
  //a context menu is shown when TEV_RCLICK return value is not 0
  if( (p != NULL) && (evtype >= 0) && (evtype < TEV_N_EVS) ){
    return emit(lua, tabevtype_name[evtype], LUA_TNUMBER, p->num, LUA_TNUMBER, p->group->toolbar->num, LUA_TNUMBER, p->group->num, -1);
  }
  return 0;
}

static void proc_tab_click( struct toolbar_item * p, GdkEventButton *event )
{
  if(event->button == 1){       //tab left click
    fire_tab_event(p, TEV_CLICK);

  }else if(event->button == 3){ //tab right click
    if( fire_tab_event(p, TEV_RCLICK) ){
      show_context_menu(lua, event, "tab_context_menu"); //open context menu
    }
  }
}

static char * evtype_name[TEV_N_EVS]={
  "toolbar_clicked",    //TEV_CLICK
  "toolbar_2clicked",   //TEV_2CLICK
  "toolbar_Rclicked",   //TEV_RCLICK
  "toolbar_close"       //TEV_CLOSE (not used)
};

int fire_item_event( struct toolbar_item * p, int evtype )
{ //emit event(item.name, toolbar.num, group.num)
  //a context menu is shown when TEV_RCLICK return value is not 0
  if( (p != NULL) && (p->name != NULL) && (evtype >= 0) && (evtype < TEV_N_EVS) ){
    return emit(lua, evtype_name[evtype], LUA_TSTRING, p->name, LUA_TNUMBER, p->group->toolbar->num, LUA_TNUMBER, p->group->num, -1);
  }
  return 0;
}

int fire_group_event( struct toolbar_group * g, int evtype )
{ //emit event("GROUP", toolbar.num, group.num)
  //a context menu is shown when TEV_RCLICK return value is not 0
  if( (g != NULL) && (evtype >= 0) && (evtype < TEV_N_EVS) ){
    return emit(lua, evtype_name[evtype], LUA_TSTRING, "GROUP", LUA_TNUMBER, g->toolbar->num, LUA_TNUMBER, g->num, -1);
  }
  return 0;
}

int fire_toolbar_event( struct toolbar_data * T, int evtype )
{ //emit event("TOOLBAR", toolbar.num, 0)
  //a context menu is shown when TEV_RCLICK return value is not 0
  if( (T != NULL) && (evtype >= 0) && (evtype < TEV_N_EVS) ){
    return emit(lua, evtype_name[evtype], LUA_TSTRING, "TOOLBAR", LUA_TNUMBER, T->num, LUA_TNUMBER, 0, -1);
  }
  return 0;
}

static void open_tb_contextmenu( GdkEventButton *event )
{
  show_context_menu(lua, event, "toolbar_context_menu"); //open context menu
}

static void proc_item_click( struct toolbar_item * p, GdkEventButton *event )
{ //item left/right click + open context menu
  if(event->button == 1){       //item left click
    fire_item_event(p, TEV_CLICK);

  }else if(event->button == 3){ //item right click
    if( fire_item_event(p, TEV_RCLICK) ){
      open_tb_contextmenu(event); //open context menu
    }
  }
}

static void proc_group_click( struct toolbar_group * g, GdkEventButton *event )
{ //group left/right click + open context menu
  if(event->button == 1){       //group left click
    fire_group_event(g, TEV_CLICK);

  }else if(event->button == 3){ //group right click
    if( fire_group_event(g, TEV_RCLICK) ){
      open_tb_contextmenu(event); //open context menu
    }
  }
}

static void proc_toolbar_click( struct toolbar_data * T, GdkEventButton *event )
{ //toolbar left/right click + open context menu
  if(event->button == 1){       //toolbar left click
    fire_toolbar_event(T, TEV_CLICK);

  }else if(event->button == 3){ //toolbar right click
    if( fire_toolbar_event(T, TEV_RCLICK) ){
      open_tb_contextmenu(event); //open context menu
    }
  }
}

static gboolean ttb_button_ev(GtkWidget *widget, GdkEventButton *event, void*__)
{
  struct toolbar_item * p;
  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T == NULL ){
    return FALSE;
  }

  if( (event->button == 1)||(event->button == 3) ){
    if(event->type == GDK_BUTTON_PRESS){
      set_hilight_off();  //clear previous highlight
      ttb.phipress= item_fromXYT(T, event->x, event->y);
      ttb.gclick= NULL;
      ttb.tclick= NULL;
      if( ttb.phipress != NULL ){ //click over a button
        ensure_item_isvisible(ttb.phipress);
        ttb.philight= ttb.phipress; //highlight as pressed
        ttb.ntbhilight= T->num;
        if( ttb.phipress->back_color == BKCOLOR_PICKER ){
          color_pick_ev( ttb.phipress, 0, 0 ); //COLOR PICKER click
        }else if( ttb.phipress->back_color == BKCOLOR_MINIMAP_CLICK ){
          mini_map_ev( 0, 0 );   //MINI MAP click
          fire_item_event(ttb.phipress, TEV_CLICK); //scroll buffer now
          start_drag(event->x, event->y);  //drag the minimap until the mouse button is released
        }else if( ttb.phipress->back_color == BKCOLOR_TBH_SCR_CLICK ){
          tbh_scroll_ev( 0, 0 );   //TBH SCROLL click
          fire_item_event(ttb.phipress, TEV_CLICK); //scroll buffer now
          start_drag(event->x, event->y);  //drag the tbh_scroll until the mouse button is released
        }else if( (ttb.phipress->flags & TTBF_SCROLL_BAR) != 0 ){
          vscroll_clickG(ttb.phipress->group); //scrollbar click
          start_drag(event->x, event->y);  //drag the scrollbar until the mouse button is released
        }else if( (ttb.phipress->flags & TTBF_IS_TRESIZE) != 0 ){
          start_drag(event->x, event->y);  //drag the resize button until the mouse button is released
          if( (T->flags & TTBF_TB_VERTICAL) != 0 ){
            T->drag_off= T->barwidth  - item_xoff; //resize toolbar horizontally (X+)
          }else{
            T->drag_off= T->barheight + item_yoff; //resize toolbar vertically   (Y-)
          }
          clear_tooltip_textT(T);
        }
        redraw_item(ttb.philight);
      }else{
        ttb.gclick= group_fromXYT(T, event->x, event->y); //click over a group
        if( ttb.gclick == NULL ){
          ttb.tclick= T;  //click over a toolbar
        }
      }
      return TRUE;
    }
    if(event->type == GDK_BUTTON_RELEASE){
      clear_tooltip_textT(T);
      p= item_fromXYT(T, event->x, event->y);
      if( (p != NULL) && (p == ttb.phipress) && (ttb.ntbhilight == T->num) ){
        //button pressed (mouse press and release over the same button)
        //NOTE: this prevents to keep a hilited button when a dialog is open from the event
        //(but also removes the hilite until the mouse is moved)
        set_hilight_off();

        if( (p->flags & TTBF_SCROLL_BUT) != 0 ){
          scroll_toolbarT(T, event->x, event->y, p->num, 0);

        }else if( (p->flags & TTBF_CLOSETAB_BUT) != 0 ){
          fire_tab_event(p, TEV_CLICK);
          fire_tab_event(p, TEV_CLOSE);

        }else if( (p->flags & TTBF_TAB) == 0 ){
          proc_item_click(p, event);  //item left/right click + open context menu
        }else{
          proc_tab_click(p, event);   //tab left/right click + open context menu
        }
      }else{
        if( ttb.pdrag != NULL ){
          if( event->button == 1 ){
            fire_item_event(ttb.pdrag, TEV_CLICK);         //notify drag end
          }
          set_hilight_off();  //cancel drag highlight

        }else if( (ttb.gclick != NULL) && (ttb.gclick == group_fromXYT(T, event->x, event->y)) ){
          //released over the same clicked group, generate event
          proc_group_click(ttb.gclick, event);  //group left/right click + open context menu

        }else if( ttb.tclick == T ){
          //released over the same clicked toolbar, generate event
          proc_toolbar_click(T, event);   //toolbar left/right click + open context menu
        }
        redraw_item(p);      //redraw button under mouse (if any)
        if( ttb.ntbhilight == T->num ){
          redraw_item(ttb.philight); //redraw highlighted button (if any in this toolbar)
        }
      }
      ttb.phipress= NULL;
      ttb.pdrag= NULL;
      ttb.gclick= NULL;
      ttb.tclick= NULL;
      return TRUE;
    }
    if(event->type == GDK_2BUTTON_PRESS){ //double click
      if(event->button == 1){
        p= item_fromXYT(T, event->x, event->y);
        if( p != NULL ){
          if( (p->flags & TTBF_TAB) == 0 ){
            fire_item_event(p, TEV_2CLICK); //button left double-click
          }else{
            fire_tab_event(p, TEV_2CLICK);  //tab left double-click
          }
        }
      }
      return TRUE;
    }
  }
  return FALSE;
}

/* ============================================================================= */
/*                          TOOLBAR POPUPS                                       */
/* ============================================================================= */
static int popup_focus_out_ev(GtkWidget * widget, GdkEventKey *_, void*__) {
  struct toolbar_data *T= toolbar_from_popup(widget);
  if( T != NULL ){
    emit(lua, "popup_close", LUA_TNUMBER, T->num, -1);
    return TRUE;
  }
  return FALSE;
}

static int popup_keypress_ev(GtkWidget * widget, GdkEventKey *event, void*_) {
  struct toolbar_data *T= toolbar_from_popup(widget);
  if( T != NULL ){
    if( emit(lua, "popup_key", LUA_TNUMBER, T->num, LUA_TNUMBER, event->keyval, -1) == 0 ){
      //ESC default action= close pop-up
      if( event->keyval == GDK_Escape ){
        emit(lua, "popup_close", LUA_TNUMBER, T->num, -1);
      }
    }
    return TRUE;
  }
  return FALSE;
}

static void ttb_show_popup(lua_State *L, int ntb, int show, int x, int y, int w, int h )
{
  struct toolbar_data *T;
  if((ntb < POPUP_FIRST) || (ntb >= NTOOLBARS)){
    ntb= POPUP_FIRST;
  }
  T= &ttb.tbdata[ntb];
  if( show ){
    //SHOW POPUP
    if( T->win == NULL ){
      T->win= gtk_window_new( GTK_WINDOW_TOPLEVEL );
      if( T->win != NULL ){
        T->barwidth= w;
        T->barheight= h;
        //connect to parent window (textadept window)
        gtk_window_set_transient_for( GTK_WINDOW(T->win), GTK_WINDOW(window) );
        gtk_window_set_resizable (GTK_WINDOW(T->win), FALSE);
        gtk_window_set_decorated (GTK_WINDOW(T->win), FALSE);
        gtk_window_set_skip_taskbar_hint (GTK_WINDOW(T->win), TRUE);
        gtk_window_set_skip_pager_hint (GTK_WINDOW(T->win), TRUE);

        gtk_window_set_accept_focus( GTK_WINDOW(T->win), TRUE );
        gtk_window_set_default_size(GTK_WINDOW(T->win), T->barwidth, T->barheight );
        gtk_window_move(GTK_WINDOW(T->win), x, y );

        gtk_widget_set_events(T->win, GDK_FOCUS_CHANGE_MASK|GDK_BUTTON_PRESS_MASK);

        g_signal_connect(T->win, "focus-out-event", G_CALLBACK(popup_focus_out_ev), L );
        g_signal_connect(T->win, "key-press-event", G_CALLBACK(popup_keypress_ev), L );

        GtkWidget *vbox = gtk_vbox_new(FALSE, 0);
        gtk_container_add(GTK_CONTAINER(T->win), vbox);
        create_tatoolbar(L, vbox, ntb);
        gtk_widget_show_all(T->win);
        show_toolbar( T, 1, 0 );
        gtk_widget_grab_focus(T->win);
      }
    }
  }else{
    //HIDE POPUP
    if( T->lock_group != NULL ){
      T->lock_group->flags &= ~TTBF_GRP_VSCR_INH;  //end vertical scroll lock
      T->lock_group= NULL;
    }
    if( T->win != NULL ){
      show_toolbar( T, 0, 0 );
      gtk_widget_destroy( T->win );
      T->win= NULL;
      T->draw= NULL;
    }
  }
}

/** `toolbar.popup(ntoolbar, show, x, y, width, height)` Lua function. */
/** `toolbar.popup(ntoolbar, show, button-name, button-corner, width, height)` Lua function. */
/** width, height >= 0: minimal size + expand if needed */
/** width, height < 0 : force this size */
static int ltoolbar_popup(lua_State *L)
{ //show popup toolbar
  struct toolbar_data * T;
  int ntb= POPUP_FIRST;
  int show= 1;
  int x= 100;
  int y= 100;
  int w= 0;
  int h= 0;
  if( lua_isnumber(L,1) ){
    ntb= lua_tointeger(L, 1);
    if((ntb < POPUP_FIRST) || (ntb >= NTOOLBARS)){
        ntb= POPUP_FIRST;
    }
  }
  if( lua_isboolean(L,2) ){
    if( !lua_toboolean(L,2) ){
      show= 0;
    }
  }
  T= toolbar_from_num(ntb);
  //set T->barwidth / T->barheight to show all fixed size groups
  calc_popup_sizeT( T );
  w= intluadef(L, 5, 10);
  if( w < 0 ){
    w= -w;  //use the given width
  }else{
    if( w < T->barwidth ){
      w= T->barwidth;  //expand width if needed
    }
  }
  h= intluadef(L, 6, 10);
  if( h < 0 ){
    h= -h;  //use the given height
  }else{
    if( h < T->barheight ){
      h= T->barheight;  //expand height if needed
    }
  }
  if( !lua_isnumber(L,3) && lua_isstring(L,3) ){
    struct toolbar_item * p=  NULL;
    int i;
    for( i= 0; i < NTOOLBARS; i++){
      p= item_from_nameT(toolbar_from_num(i), lua_tostring(L, 3));
      if( p != NULL ){
        break;
      }
    }
    if( p != NULL ){
      int wx, wy, loc;
      x= 0; y= 0;
      gdk_window_get_origin( get_draw_widget( p->group->toolbar)->window, &x, &y );
      x += p->group->barx1;
      y += p->group->bary1 - p->group->yvscroll;
      p->group->flags |= TTBF_GRP_VSCR_INH;  //inhibit vertical scroll while popup is open
      T->lock_group= p->group;  //unlock when closed
      loc= intluadef(L, 4, 0);
      wx= loc & 7;
      switch( wx ){
        case 0:   x += p->barx1-w-1;              break;  //left
        case 1:   x += p->barx1;                  break;
        case 2:   x += (p->barx1+p->barx2-w-1)/2; break;  //center
        case 3:   x += p->barx2-w-1;              break;
        default:  x += p->barx2;                  break;  //right
      }
      wy= (loc >> 3) & 7;
      switch( wy ){
        case 0:   y += p->bary1-h-1;              break;  //top
        case 1:   y += p->bary1;                  break;
        case 2:   y += (p->bary1+p->bary2-h)/2;   break;  //center
        case 3:   y += p->bary2-h;                break;
        default:  y += p->bary2;                  break;  //bottom
      }
    }
  }else{
    x= intluadef(L, 3, 100);
    y= intluadef(L, 4, 100);
  }
  ttb_show_popup( L, ntb, show, x, y, w, h );
  return 0;
}

/** `toolbar.menustatus(menu_id, status)` Lua function. */
/** status: 0=enabled, 1=checked, 2=unchecked, 3=radio-checked, 4=radio-unchecked, +8=disabled, (+16=radio is group-first) */
static int ltoolbar_menustatus(lua_State *L)
{
  setmenuitemstatus(lua_tointeger(L, 1), lua_tointeger(L, 2));
  return 0;
}

/** `toolbar.updatebuffinfo(onoff)` Lua function. */
char saved_title[512];
char saved_statusbar[512];
static int ltoolbar_updatebuffinfo(lua_State *L)
{
  _update_ui= lua_toboolean(L, 1);
  if( _update_ui ){ //update ui on?
    if( saved_title[0] != 0 ){  //set the saved title
      toolbar_set_win_title(saved_title);
      saved_title[0]= 0;
    }
    if( saved_statusbar[0] != 0 ){  //set the saved status bar fields
      toolbar_set_statusbar_text( saved_statusbar, 1);
      saved_statusbar[0]= 0;
    }
    redraw_pending_toolbars();
  }
  return 0;
}

/* ============================================================================= */
/*                          FILE DIFF                                            */
/* ============================================================================= */
/** `filediff.setfile(num, filecontent)` Lua function. */
/** num= 1...MAXFILEDIFF */
static int lfilediff_setfile(lua_State *L)
{
  fdiff_setfile(lua_tointeger(L, 1), lua_tostring(L, 2));
  return 0;
}

static int val_position;
static lua_State *Lstate;
static void pushint_intable( int val )
{
  lua_pushinteger(Lstate, val);
  lua_rawseti(Lstate, -2, val_position++);
}

/** `filediff.getdiff(num, dlist)` Lua function. */
/** num= 1...MAXFILEDIFF, returns an int array with "dlist" */
/** dlist= 1: (line from, line to) lines that are only in file #num (inserted in #num = deleted in the other file) */
/** dlist= 2: (line num, other file line num) modified lines (1 line changed in both files) */
/** dlist= 3: (line num, count) number of blank lines needed to add under line "num" to align equal lines between files */
/** dlist= 4: (nfile, char pos from, len) chars that are only in file1 or file2 (num param is ignored) */
/** NOTE: char ranges (dlist=2) are generated only for 1 line ranges (this lines are excluded from dlist=1) */
static int lfilediff_getdiff(lua_State *L)
{
  lua_newtable(L);
  Lstate= L;
  val_position= 1;
  fdiff_getdiff(lua_tointeger(L, 1), lua_tointeger(L, 2), pushint_intable );
  return 1;
}


/** `filediff.strdiff(str1, str2)` Lua function. */
/** returns an int array with (char pos from, len) chars that are only in str1 (inserted in str1 = deleted in str2) */
static int lfilediff_strdiff(lua_State *L)
{
  lua_newtable(L);
  Lstate= L;
  val_position= 1;
  fdiff_strdiff(lua_tostring(L, 1), lua_tostring(L, 2), pushint_intable );
  return 1;
}

/* ============================================================================= */
/** `minimap.init(buffnum, linecount, [yszbox] )` Lua function. */
/** init minimap: buffer number, buffer line count, change box size in pixels */
static int lminimap_init(lua_State *L)
{
  minimap_init(lua_tointeger(L, 1), lua_tointeger(L, 2), lua_tointeger(L, 3));
  return 0;
}

/** `minimap.hilight(linenum, color, [exclusive] )` Lua function. */
/** set line color, exclusive = only if not previously set */
static int lminimap_hilight(lua_State *L)
{
  minimap_hilight(lua_tointeger(L, 1), lua_tointeger(L, 2), lua_toboolean(L, 3) );
  return 0;
}

/** `minimap.getclickline()` Lua function. */
/** return last clicked line number */
static int lminimap_getclickline(lua_State *L)
{
  lua_pushinteger( L, minimap_getclickline() );
  return 1;
}

/** `minimap.scrollpos(linesscreen, firstvisible, color)` Lua function. */
/** set scroll bar position and size */
static int lminimap_scrollpos(lua_State *L)
{
  minimap_scrollpos(lua_tointeger(L, 1), lua_tointeger(L, 2), lua_tointeger(L, 3) );
  return 0;
}

/* ============================================================================= */
/** `tbh_scroll.setmaxcol(maxcol)` Lua function. */
/** set tbh_scroll max column */
static int ltbh_scroll_setmaxcol(lua_State *L)
{
  tbh_scroll_setmaxcol(lua_tointeger(L, 1));
  return 0;
}

/** `tbh_scroll.getclickcol()` Lua function. */
/** return last clicked col number */
static int ltbh_scroll_getclickcol(lua_State *L)
{
  lua_pushinteger( L, tbh_scroll_getclickcol() );
  return 1;
}

/** `tbh_scroll.scrollpos(colsscreen, firstvisible, color)` Lua function. */
/** set scroll bar position and size */
static int ltbh_scroll_scrollpos(lua_State *L)
{
  tbh_scroll_scrollpos(lua_tointeger(L, 1), lua_tointeger(L, 2), lua_tointeger(L, 3) );
  return 0;
}

#define DEF_C_FUNC(lua, funct, name) lua_pushcfunction(lua,funct), lua_setfield(lua, -2, name)
/* ============================================================================= */
/*                          FUNCTIONS CALLED FROM TA                             */
/* ============================================================================= */
/* register LUA toolbar object */
void register_toolbar(lua_State *L)
{
  _update_ui= 1;  //update buffer UI: on by default
  saved_title[0]= 0;
  saved_statusbar[0]= 0;
  //register "toolbar" functions
  lua_newtable(L);
  //toolbars
  DEF_C_FUNC(L, ltoolbar_new,           "new");             //create a new toolbar (returns toolbar num)
  DEF_C_FUNC(L, ltoolbar_adjust,        "adjust");          //optionaly fine tune some parameters
  DEF_C_FUNC(L, ltoolbar_show,          "show");            //show/hide toolbar
  //groups
  DEF_C_FUNC(L, ltoolbar_seltoolbar,    "seltoolbar");      //select which toolbar/group to edit
  DEF_C_FUNC(L, ltoolbar_addgroup,      "addgroup");        //add a new group (returns group num)
  DEF_C_FUNC(L, ltoolbar_addtabs,       "addtabs");         //add a tabs-group
  DEF_C_FUNC(L, ltoolbar_showgroup,     "showgroup");       //show/hide a group
  //buttons
  DEF_C_FUNC(L, ltoolbar_addbutton,     "addbutton");       //add button
  DEF_C_FUNC(L, ltoolbar_addtext,       "addtext");         //add text button
  DEF_C_FUNC(L, ltoolbar_addlabel,      "addlabel");        //add a text label
  DEF_C_FUNC(L, ltoolbar_addspace,      "addspace");        //add some space
  DEF_C_FUNC(L, ltoolbar_gotopos,       "gotopos");         //change next button position
  DEF_C_FUNC(L, ltoolbar_enable,        "enable");          //enable/disable a button
  DEF_C_FUNC(L, ltoolbar_selected,      "selected");        //un/select/press a button
  DEF_C_FUNC(L, ltoolbar_ensurevisible, "ensurevisible");   //ensure a button in a scrollable group is visible
  DEF_C_FUNC(L, ltoolbar_collapse,      "collapse");        //collapse/expand a block of items under this
  DEF_C_FUNC(L, ltoolbar_seticon,       "seticon");         //change a button, GROUP or TOOLBAR icon
  DEF_C_FUNC(L, ltoolbar_setbackcolor,  "setbackcolor");    //change a button, GROUP or TOOLBAR back color
  DEF_C_FUNC(L, ltoolbar_settooltip,    "settooltip");      //change a button tooltip
  DEF_C_FUNC(L, ltoolbar_settext,       "settext");         //change a button text
  DEF_C_FUNC(L, ltoolbar_textfont,      "textfont");        //set text buttons font size and colors
  DEF_C_FUNC(L, ltoolbar_anchor,        "anchor");          //anchor a buttons x position to the right
  DEF_C_FUNC(L, ltoolbar_setresize,     "setresize");       //the button resize the toolbar
  //tabs
  DEF_C_FUNC(L, ltoolbar_tabfontcolor,  "tabfontcolor");    //change default tab font color
  DEF_C_FUNC(L, ltoolbar_settab,        "settab");          //set tab num
  DEF_C_FUNC(L, ltoolbar_deletetab,     "deletetab");       //delete tab num
  DEF_C_FUNC(L, ltoolbar_activatetab,   "activatetab");     //activate tab num
  DEF_C_FUNC(L, ltoolbar_enabletab,     "enabletab");       //enable/disable tab num
  DEF_C_FUNC(L, ltoolbar_modifiedtab,   "modifiedtab");     //show/hide changed indicator in tab num
  DEF_C_FUNC(L, ltoolbar_hidetab,       "hidetab");         //hide/show tab num
  DEF_C_FUNC(L, ltoolbar_tabwidth,      "tabwidth");        //set tab num tabwidth (varible/fixed)
  DEF_C_FUNC(L, ltoolbar_gototab,       "gototab");         //generate a click in tab: -1:prev,1:next,0:first,2:last
  //get
  DEF_C_FUNC(L, ltoolbar_getpickcolor,  "getpickcolor");    //return integer (RGB) current selected color in picker
  DEF_C_FUNC(L, ltoolbar_getversion,    "getversion");      //return string ta-toolbar version
  DEF_C_FUNC(L, ltoolbar_getflags,      "getflags");        //return item/current group flags
  DEF_C_FUNC(L, ltoolbar_getsize,       "getsize");         //return the toolbar height (horizontal tb) or width (vertical tb)
  //popup
  DEF_C_FUNC(L, ltoolbar_popup,         "popup");           //show a popup toolbar
  //menuitem
  DEF_C_FUNC(L, ltoolbar_menustatus,    "menustatus");      //change menu item status
  //ui
  DEF_C_FUNC(L, ltoolbar_updatebuffinfo,"updatebuffinfo");  //update buffer info (app title/status bar)
  //toolbar object
  lua_setglobal(L, "toolbar");

  //register "filediff" functions
  lua_newtable(L);
  //file diff
  DEF_C_FUNC(L, lfilediff_setfile,      "setfile");         //load a file to compare
  DEF_C_FUNC(L, lfilediff_getdiff,      "getdiff");         //get file differences (int array)
  DEF_C_FUNC(L, lfilediff_strdiff,      "strdiff");         //compare to strings
  //filediff object
  lua_setglobal(L, "filediff");

  //register "minimap" functions
  lua_newtable(L);
  DEF_C_FUNC(L, lminimap_init,          "init");            //clear minimap
  DEF_C_FUNC(L, lminimap_hilight,       "hilight");         //highlight a line
  DEF_C_FUNC(L, lminimap_getclickline,  "getclickline");    //get clicked line number
  DEF_C_FUNC(L, lminimap_scrollpos,     "scrollpos");       //set scroll bar position and size
  lua_setglobal(L, "minimap");

  //register "tbh_scroll" functions
  lua_newtable(L);
  DEF_C_FUNC(L, ltbh_scroll_setmaxcol,  "setmaxcol");       //set h_scroll max column
  DEF_C_FUNC(L, ltbh_scroll_getclickcol,"getclickcol");     //get clicked col number
  DEF_C_FUNC(L, ltbh_scroll_scrollpos,  "scrollpos");       //set scroll bar position and size
  lua_setglobal(L, "tbh_scroll");

  //load font list
  load_fonts();
}

/* status bar text changed */
int toolbar_set_statusbar_text(const char *text, int bar)
{ //called when textadept change the text in the status bar (bar 0 => tab#1  bar 1 => tab#2..7)
  struct toolbar_group *G;
  char txt[64];
  const char *s;
  const char *d;
  unsigned n, ntab;

  struct toolbar_data *T= &ttb.tbdata[STAT_TOOLBAR];
  if( (text != NULL) && ((T->flags & TTBF_TB_VISIBLE) != 0) ){
    G= T->tab_group;
    if( G != NULL ){
      if( bar == 0 ){
        set_tabtextG(G, 1, text, text, 1 ); //tooltip = text in case it can be shown complete
      }else{
        if( _update_ui ){ //update buffer UI on?
          //split text in parts (separator= 4 spaces)
          ntab= 2;
          s= text;
          while( (*s != 0) && (ntab <= 7)){
            d= strstr( s, "    " );
            if( d != NULL ){
              n= d-s;
              if( n >= sizeof(txt) ){
                n= sizeof(txt)-1;
              }
              strncpy( txt, s, n );
              txt[n]= 0;
              set_tabtextG(G, ntab, txt, "", 0 );
              s=d+4;
            }else{
              //last field
              set_tabtextG(G, ntab, s, "", 0 );
              break;
            }
            ntab++;
          }
          //redraw the complete toolbar
          redraw_group(G);
        }else{
          //save for later
          strncpy( saved_statusbar, text, sizeof(saved_statusbar)-1 );
          saved_statusbar[sizeof(saved_statusbar)-1]= 0;
        }
      }
      return 0;
    }
  }
  return 1; //update the regular status bar
}

void toolbar_set_win_title( const char *title )
{
  if( _update_ui ){ //update buffer UI on?
    //update window title now
    gtk_window_set_title(GTK_WINDOW(window), title);
  }else{
    //save for later
    strncpy( saved_title, title, sizeof(saved_title)-1 );
    saved_title[sizeof(saved_title)-1]= 0;
  }
}

/* create a DRAWING-AREA for each toolbar */
static void create_tatoolbar( lua_State *L, GtkWidget *box, int ntoolbar )
{
  struct toolbar_data *T;
  GtkWidget * draw;
  int i;

  if( ntoolbar == 0 ){ //create first toolbar => init pop-ups
    for( i= POPUP_FIRST; i < NTOOLBARS; i++ ){
      init_tatoolbar( i, NULL, 1 ); //no drawing area yet (clear all)
    }
  }

  if( ntoolbar < NTOOLBARS ){
    draw = gtk_drawing_area_new();
    if( ntoolbar >= POPUP_FIRST ){
      //POP-UP
      T= init_tatoolbar( ntoolbar, draw, 0 );   //already cleared
      gtk_widget_set_size_request(draw, T->barwidth, T->barheight );
    }else{
      //TOOLBAR
      T= init_tatoolbar( ntoolbar, draw, 1 );   //clear all
      if( (T->flags & TTBF_TB_VERTICAL) != 0 ){
        gtk_widget_set_size_request(draw, 1, -1);
      }else{
        gtk_widget_set_size_request(draw, -1, 1);
      }
    }
    gtk_widget_set_events(draw, GDK_EXPOSURE_MASK|GDK_LEAVE_NOTIFY_MASK|
      GDK_POINTER_MOTION_MASK|GDK_BUTTON_PRESS_MASK|GDK_BUTTON_RELEASE_MASK );
    g_signal_connect(draw, "size-allocate",        G_CALLBACK(ttb_size_ev), L );
    g_signal_connect(draw, "expose_event",         G_CALLBACK(ttb_paint_ev), L );
    g_signal_connect(draw, "leave-notify-event",   G_CALLBACK(ttb_mouseleave_ev), L );
    g_signal_connect(draw, "motion_notify_event",  G_CALLBACK(ttb_mousemotion_ev), L );
    g_signal_connect(draw, "scroll-event",         G_CALLBACK(ttb_scrollwheel_ev), L );
    g_signal_connect(draw, "button-press-event",   G_CALLBACK(ttb_button_ev), L );
    g_signal_connect(draw, "button-release-event", G_CALLBACK(ttb_button_ev), L );

    gtk_box_pack_start(GTK_BOX(box), draw, FALSE, FALSE, 0);
  }
}

void set_toolbar_size(struct toolbar_data *T)
{
  GtkWidget * draw= get_draw_widget( T );
  if( draw != NULL ){
    if( T->num >= POPUP_FIRST ){
      gtk_widget_set_size_request(draw, T->barwidth, T->barheight); //POP-UP
    }else if( (T->flags & TTBF_TB_VERTICAL) != 0 ){
      gtk_widget_set_size_request(draw, T->barwidth, -1);
    }else{
      gtk_widget_set_size_request(draw, -1, T->barheight);
    }
  }
}

/* show/hide ALL toolbars */
void show_tatoolbar(int show)
{
  int i;
  for( i= 0; i < POPUP_FIRST; i++ ){
    GtkWidget * wid= get_draw_widget( &ttb.tbdata[i] );
    if( wid != NULL ){
      if( show ){ //show all toolbars
        gtk_widget_show( wid );
      }else{      //hide all toolbars
        gtk_widget_hide( wid );
      }
    }
  }
}

void show_toolbar(struct toolbar_data *T, int show, int newsize)
{ //show/hide one toolbar
  if( T != NULL ){
    if( (newsize > 0) && (T->num < POPUP_FIRST) ){
      if( (T->flags & TTBF_TB_VERTICAL) != 0 ){ //vertical toolbar: change width
        if( T->barwidth != newsize ){
          T->barwidth= newsize;
          set_toolbar_size(T);
        }
      }else{  //horizontal toolbar: change height
        if( T->barheight != newsize ){
          T->barheight= newsize;
          set_toolbar_size(T);
        }
      }
    }
    if( (show) && ((T->flags & TTBF_TB_VISIBLE) == 0) ){
      //show this toolbar
      T->_layout_chg= 0;
      T->flags |= TTBF_TB_VISIBLE;
      gtk_widget_show( T->draw );
      //redraw the complete toolbar
      redraw_toolbar(T);
      if( T->num == 2 ){
        gtk_widget_hide( statusbar[0] ); //hide default statusbar
        gtk_widget_hide( statusbar[1] );
      }
    }else if( (!show) && ((T->flags & TTBF_TB_VISIBLE) != 0) ){
      //hide this toolbar
      T->flags &= ~TTBF_TB_VISIBLE;
      gtk_widget_hide( T->draw );
      if( T->num == 2 ){
        gtk_widget_show( statusbar[0] ); //show default statusbar
        gtk_widget_show( statusbar[1] );
      }
    }
  }
}

/* ============================================================================= */
/* MENUITEMS: check, radio and enable support  */
#define NMENUITS_PAGE   500
struct defmenuitems {
  int menuid;
  GtkWidget * menuit;
};
struct pagemenuitems {
  struct pagemenuitems * next;
  int n;
  struct defmenuitems p[NMENUITS_PAGE];
};
static struct pagemenuitems * mitems_list= NULL;

//record all menuitems
static void add_defmenuitem( GtkWidget * mit, int id)
{
  struct pagemenuitems *m, *a;
  int i;
  a= NULL;
  //NOTE: the same ID can be defined in the main menu and in several context-menus
  //for( m= mitems_list; (m != NULL); m= m->next){
  //  for(i= 0; i < m->n; i++ ){
  //    if( m->p[i].menuid == id ){
  //      m->p[i].menuit= mit; //overwrite
  //      return;
  //    }
  //  }
  //  a= m;
  //} //not found, add at the end
  //just find the last page
  for( m= mitems_list; (m != NULL); m= m->next){
    a= m;
  }

  if( (a == NULL) || (a->n == NMENUITS_PAGE) ){
    //none or last page full: add a new page
    m= (struct pagemenuitems *) malloc( sizeof(struct pagemenuitems));
    if( m == NULL ){
      return;
    }
    m->next= NULL;
    m->n= 0;
    if( a == NULL ){
      mitems_list= m;
    }else{
      a->next= m;
    }
  }else{
    m= a; //add at the end of last page
  }
  i= m->n;
  m->p[i].menuid= id;
  m->p[i].menuit= mit;
  m->n= i+1;
}

static GSList *radiogroup = NULL;
GtkWidget * newmenuitem(const char *label, int menu_id)
{
  static GtkWidget * it;
  if( *label == 0 ){ //no label = separator
    return gtk_separator_menu_item_new();
  }
  if( *label == '\t' ){ //begins with TAB = check item
    it= gtk_check_menu_item_new_with_mnemonic(label+1);
  }else if( *label == '\b' ){ //begins with BACKSP = first radio item of a radio group
    it= gtk_radio_menu_item_new_with_mnemonic(NULL,label+1);
    radiogroup= gtk_radio_menu_item_get_group (GTK_RADIO_MENU_ITEM (it));
  }else if( *label == '\n' ){ //begins with NEWLINE = radio item of the same radio group
    it= gtk_radio_menu_item_new_with_mnemonic(radiogroup,label+1);
    radiogroup= gtk_radio_menu_item_get_group (GTK_RADIO_MENU_ITEM (it));
  }else{
    it= gtk_menu_item_new_with_mnemonic(label); //normal item
  }
  add_defmenuitem( it, menu_id); //record all menuitems
  return it;
}

//status: 0=enabled, 1=checked, 2=unchecked, 3=radio-checked, 4=radio-unchecked, +8=disabled, (+16=radio is group-first)
static void setmenuitemstatus( int menu_id, int status)
{
  GtkWidget * it;
  struct pagemenuitems * m;
  int i;
  for( m= mitems_list; (m != NULL); m= m->next){
    for(i= 0; i < m->n; i++ ){
      if( m->p[i].menuid == menu_id ){
        it= m->p[i].menuit;
        int n= status & 7;
        if( (n == 1)||(n == 3) ){
          gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM (it), TRUE);
        }else if( (n == 2)||(n == 4) ){
          gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM (it), FALSE);
        }
        if( (status & 8) == 8 ){
          gtk_widget_set_sensitive(it,FALSE); //disabled
        }else{
          gtk_widget_set_sensitive(it,TRUE);  //enabled
        }
      }
    }
  }
}

void clear_menuitem_list( void )
{ //free menuitems list
  struct pagemenuitems * m;
  while( mitems_list != NULL ){
    m= mitems_list;
    mitems_list= mitems_list->next;
    free(m);
  }
}

/* destroy all toolbars */
void kill_tatoolbar( void )
{
  //free all toolbars data
  free_tatoolbar();
  //free menuitems list
  clear_menuitem_list();

  //free all filediff memory
  fdiff_killall();

  //free font list
  kill_fonts();
}

void fire_minimap_scroll( int dir )
{
  emit(lua, "minimap_scroll", LUA_TNUMBER, dir, -1);
}

void fire_tbh_scroll( int dir )
{
  emit(lua, "tbh_scroll", LUA_TNUMBER, dir, -1);
}
