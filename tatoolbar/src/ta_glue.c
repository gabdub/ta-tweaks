/* ============================================================================= */
/* GLUE between ta-toolbar and textadept/LUA/GTK                                 */
/*   when modified, touch textadept.c to compile (because it's "included" there) */
/* ============================================================================= */
#include "ta_toolbar.h"

#include "ta_filediff.h"

//from textadept.c
static void lL_showcontextmenu(lua_State *L, GdkEventButton *event, char *k);
//pre-def
static void create_tatoolbar( GtkWidget *vbox, int ntoolbar );
static void setmenuitemstatus( int menu_id, int status);

/* ============================================================================= */
/*                                 LUA FUNCTIONS                                 */
/* ============================================================================= */
static int intluadef(lua_State *L, int npos, int defval )
{
  if( !lua_isnone(L, npos) ){
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
/** `toolbar.new(barsize,buttonsize,imgsize,toolbarnum/isvertical,imgpath)` Lua function. */
/** returns toolbar num */
static int ltoolbar_new(lua_State *L)
{
  const char * imgpath= NULL;
  int num= intlua_ntoolbar(L,4);
  if( !lua_isnone(L, 5) ){
    //change global image base
    imgpath= luaL_checkstring(L, 5);
  }
  ttb_new_toolbar(num, lua_tointeger(L, 1), lua_tointeger(L, 2), lua_tointeger(L, 3), imgpath );
  lua_pushinteger(L, num);  //toolbar num
  return 0;
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

/** `toolbar.show(show)` Lua function. */
static int ltoolbar_show(lua_State *L)
{
  show_toolbar(current_toolbar(), lua_toboolean(L,1));
  return 0;
}

//----- GROUPS -----
/** `toolbar.seltoolbar(toolbarnum/isvertical, [groupnum])` Lua function. */
static int ltoolbar_seltoolbar(lua_State *L)
{
  //set the current toolbar num
  select_toolbar_n( intlua_ntoolbar(L,1), lua_tointeger(L, 2) );
  return 0;
}

/** `toolbar.addgroup(xcontrol,ycontrol,width,height,[hidden])` Lua function. */
/** x/y control:
  0:allow groups before and after 1:no groups at the left/top  2:no groups at the right/bottom
  3:exclusive row/col  +4:expand  +8:use item size */
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
    num= g->num;
  }
  lua_pushinteger(L, num);  //toolbar num
  return 0;
}

/** `toolbar.addtabs(xmargin,xsep,withclose,mod-show,fontsz,fontyoffset,[tab-drag],[xcontrol],[height])` Lua function. */
/** xcontrol: 0:allow groups before and after 1:no groups at the left 2:no groups at the right
              3:exclusive row  +4:x-expand  +8:use item size for width */
static int ltoolbar_addtabs(lua_State *L)
{
  ttb_new_tabs_groupT( current_toolbar(), lua_tointeger(L,1), lua_tointeger(L,2), lua_toboolean(L,3),
    lua_tointeger(L,4), lua_tointeger(L,5), lua_tointeger(L,6), lua_toboolean(L,7), lua_tointeger(L,8), lua_tointeger(L,9) );
  return 0;
}

/** `toolbar.showgroup(show)` Lua function. */
static int ltoolbar_showgroup(lua_State *L)
{
  ttb_show_groupG( current_group(), lua_toboolean(L,1) );
  return 0;
}

//----- BUTTONS -----
/** `toolbar.addbutton(name,tooltiptext)` Lua function. */
static int ltoolbar_addbutton(lua_State *L)
{
  ttb_addbutton( luaL_checkstring(L, 1), luaL_checkstring(L, 2) );
  return 0;
}

/** `toolbar.addtext(name,text,tooltiptext,width)` Lua function. */
static int ltoolbar_addtext(lua_State *L)
{
  ttb_addtext( luaL_checkstring(L, 1), NULL, luaL_checkstring(L, 3), luaL_checkstring(L, 2), lua_tointeger(L, 4));
  return 0;
}

/** `toolbar.addlabel(text,tooltiptext,width,leftalign,bold,name)` Lua function. */
static int ltoolbar_addlabel(lua_State *L)
{
  int flags= 0;
  if( lua_toboolean(L,4) ){
    flags |= TTBF_TEXT_LEFT; //left align text
  }
  if( lua_toboolean(L,5) ){
    flags |= TTBF_TEXT_BOLD; //use bold
  }
  ttb_addlabel( lua_tostring(L,6), NULL, luaL_checkstring(L, 2), luaL_checkstring(L, 1), lua_tointeger(L, 3), flags );
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
      if( g->isvertical ){
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

/** `toolbar.enable(name,isenabled,[onlyinthistoolbar])` Lua function. */
static int ltoolbar_enable(lua_State *L)
{
  ttb_enable( luaL_checkstring(L, 1), lua_toboolean(L,2), lua_toboolean(L,3) );
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

/** `toolbar.textfont(fontsize,fontyoffset,NORMcol,GRAYcol)` Lua function. */
static int ltoolbar_textfont(lua_State *L)
{
  ttb_set_text_fontcolG( current_buttongrp(), lua_tointeger(L, 1), lua_tointeger(L, 2),
    intluadef(L, 3, 0x000000), intluadef(L, 4, 0x808080) );
  return 0;
}

//----- TABS -----
/** `toolbar.tabfontcolor(NORMcol,HIcol,ACTIVEcol,MODIFcol,GRAYcol)` Lua function. */
static int ltoolbar_tabfontcolor(lua_State *L)
{
  int ncol, hcol, acol, mcol, gcol;
  ncol= intluadef(L, 1, 0x000000);  //normal:   default black
  hcol= intluadef(L, 2, ncol );     //hilight:  default == normal
  acol= intluadef(L, 3, hcol );     //active:   default == hilight
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

/** `toolbar.getversion()` Lua function. */
static int ltoolbar_getversion(lua_State *L)
{
  lua_pushstring(L,get_toolbar_version());
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
    if( T->isvisible ){
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
        gtk_widget_queue_draw_area(T->draw, G->barx1 + T->_grp_x1, G->bary1 + T->_grp_y1,
            T->_grp_x2 - T->_grp_x1 +1, T->_grp_y2 - T->_grp_y1 +1);
      }
    }
  }
}

void redraw_toolbar( struct toolbar_data *T )
{ //redraw the complete toolbar
  if( (T != NULL) && (T->isvisible) ){
    gtk_widget_queue_draw(T->draw);
  }
}

void redraw_group( struct toolbar_group *G )
{
  if( (G != NULL) && (G->toolbar->isvisible) && ((G->flags & TTBF_HIDDEN) == 0) ){
    gtk_widget_queue_draw_area(G->toolbar->draw, G->barx1, G->bary1,
      G->barx2 - G->barx1 +1, G->bary2 - G->bary1 +1 );
  }
}

void redraw_item( struct toolbar_item * p )
{
  struct toolbar_group *g;
  if( p != NULL ){
    g= p->group;
    if( ((g->flags & TTBF_HIDDEN) == 0) && (g->toolbar->isvisible) ){
      //the group is visible
      if( (p->flags & (TTBF_TAB|TTBF_SCROLL_BUT|TTBF_CLOSETAB_BUT|TTBF_HIDDEN)) == 0 ){
        //redraw the area of one regular button
        gtk_widget_queue_draw_area(p->group->toolbar->draw, g->barx1 + p->barx1, g->bary1 + p->bary1 - g->yvscroll,
            p->barx2 - p->barx1 +1, p->bary2 - p->bary1 +1 );
        return;
      }
      //redraw a tab or one of its buttons
      //redraw the complete group
      redraw_group(g);
    }
  }
}

void draw_txt( void * gcontext, const char *txt, int x, int y, int y1, int w, int h, struct color3doubles *color, int fontsz, int bold )
{
  if( txt != NULL ){
    cairo_t *ctx= (cairo_t *) gcontext;
    cairo_save(ctx);
    cairo_rectangle(ctx, x, y1, w, h );
    cairo_clip(ctx);
    cairo_move_to(ctx, x, y);
    cairo_set_source_rgb(ctx, color->R, color->G, color->B);
    cairo_set_font_size(ctx, fontsz);
    if( bold ){
      cairo_select_font_face(ctx, "", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD );
    }
    cairo_show_text(ctx, txt);
    cairo_restore(ctx);
  }
}

void draw_img( void * gcontext, struct toolbar_img *pti, int x, int y, int grayed )
{
  cairo_t *ctx= (cairo_t *) gcontext;
  cairo_pattern_t *radpat;
  if( pti->fname != NULL ){
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

void draw_fill_img( void * gcontext, struct toolbar_img *pti, int x, int y, int w, int h )
{
  if( pti->fname != NULL ){
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

void draw_fill_color( void * gcontext, int color, int x, int y, int w, int h )
{
  struct color3doubles c;
  int i, j, xr, yr, dx, dy, a, hp;
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
    c.R= 0;
    if( ttb.cpick.HSV_y == (PICKER_CELL_H-1) ){
      //last row (B/W)
      if( ttb.cpick.HSV_x < PICKER_CELL_W/2 ){
        c.R= 1;
      }
    }else{
      //color
      if( (ttb.cpick.HSV_val < 0.7) ||
          (((ttb.cpick.HSV_rgb & 0xff) > 0x80) && (ttb.cpick.HSV_rgb & 0xff00) < 0x8000) ){
        c.R= 1; //white over dark colors
      }
    }
    cairo_set_source_rgb(ctx, c.R, c.R, c.R );
    cairo_rectangle(ctx, xr, yr, dx, dy);
    cairo_stroke(ctx);

    //Vscroll bar
    xr= x+w-PICKER_VSCROLLW;
    cairo_set_source_rgb(ctx, 0.5, 0.5, 0.5 );
    cairo_rectangle(ctx, xr, y+PICKER_MARG_TOP, PICKER_VSCROLLW, hp);
    cairo_fill(ctx);
    yr= y + PICKER_MARG_TOP + hp * (1-ttb.cpick.HSV_val) * (1-HSV_V_DELTA);
    dy= hp * HSV_V_DELTA;
    cairo_set_source_rgb(ctx, 0.3, 0.3, 0.3 );
    cairo_rectangle(ctx, xr, yr, PICKER_VSCROLLW, dy);
    cairo_fill(ctx);
    cairo_set_source_rgb(ctx, 0.6, 0.6, 0.6 );
    cairo_rectangle(ctx, xr+1, yr+1, PICKER_VSCROLLW-2, dy-2);
    cairo_fill(ctx);

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
    setrgbcolor( color, &c );
    cairo_set_source_rgb(ctx, c.R, c.G, c.B );
    cairo_rectangle(ctx, x, y, w, h);
    cairo_fill(ctx);
    if( str[0] != 0 ){
      c.R= tcol;  c.G= tcol;   c.B= tcol;
      draw_txt(ctx, str, x+4, y+16, y, w-8, h, &c, 10, 0 );
    }
  }
}

int set_pti_img( struct toolbar_img *pti, const char *imgname )
{ //set a new item/group/toolbar image
  //return 1 if redraw is needed
  char * simg;

  if( pti->fname != NULL ){
    if( (imgname != NULL) && (strcmp( pti->fname, imgname ) == 0) ){
      return 0; //same img, no redraw is needed
    }
    //free previous img
    free((void *)pti->fname);
    pti->fname= NULL;
    pti->width= 0;
    pti->height= 0;
  }
  if( imgname != NULL ){
    simg= alloc_img_str(imgname); //get img fname
    if( simg != NULL ){
      cairo_surface_t *cis= cairo_image_surface_create_from_png(simg);
      if( cis != NULL ){
        pti->width=  cairo_image_surface_get_width(cis);
        pti->height= cairo_image_surface_get_height(cis);
        if( (pti->width > 0) && (pti->height > 0)){
          pti->fname= simg;
          cairo_surface_destroy(cis);
          return 1; //image OK
        }
        cairo_surface_destroy(cis);
      }
      free( (void *) simg);
    }
  }
  return 1; //image not found or invalid: redraw (just in case...)
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
  cairo_t *cr;
  int diff= 0;
  struct toolbar_group *G= p->group;
  if( p->text != NULL ){
    //use toolbar #0 to measure text (pop-ups may not have a window yet)
    cairo_t *cr = gdk_cairo_create(get_draw_tb0_widget()->window); //get_draw_widget(p->group->toolbar)->window);
    cairo_set_font_size(cr, G->txtfontsz);
    cairo_text_extents( cr, p->text, &ext );
    p->textwidth= (int) ext.width;
    if( G->txttexty < 0 ){
      cairo_text_extents( cr, "H", &ext );
      G->txttexth= (int) ext.height;
      //center text verticaly + offset
      G->txttexty= ((get_group_imgH(G,TTBI_TB_TXT_HIL1) + G->txttexth)/2) + G->txttextoff;
      if( G->txttexty < 0){
        G->txttexty= 0;
      }
    }
    cairo_destroy(cr);
    diff= p->barx2;
    p->prew= get_group_imgW(G,TTBI_TB_TXT_HIL1);
    p->postw= get_group_imgW(G,TTBI_TB_TXT_HIL3);
    p->imgx= p->barx1 + p->prew;
    p->imgy= p->bary1 + G->txttexty;
    p->barx2= p->imgx + p->textwidth + p->postw;
    if( p->barx2 < (p->barx1+p->minwidth)){
      //expand button (center text)
      p->imgx += (p->barx1 + p->minwidth - p->barx2)/2;
      p->barx2= p->barx1+p->minwidth;
    }
    if( (p->maxwidth > 0) && (p->barx2 > (p->barx1+p->maxwidth)) ){
      //reduce button (trimm text)
      p->barx2= p->barx1+p->maxwidth;
    }
    diff= p->barx2 - diff;  //width diff
  }
  return diff;
}

int get_text_width( const char * text, int fontsz )
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
  cairo_set_font_size(cr, fontsz );
  cairo_text_extents( cr, text, &ext );
  w= (int) ext.width +1; //+1 to see the antialiasing complete
  cairo_destroy(cr);
  return w;
}

int get_text_height( const char * text, int fontsz )
{
  int h;
  cairo_text_extents_t ext;
  //use toolbar #0 to measure text (pop-ups may not have a window yet)
  cairo_t *cr = gdk_cairo_create(get_draw_tb0_widget()->window); //get_draw_widget(p->group->toolbar)->window);
  cairo_set_font_size(cr, fontsz );
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
  UNUSED(__);
  ttb_set_toolbarsize( toolbar_from_widget(widget), prec->width, prec->height );
}

static gboolean ttb_paint_ev(GtkWidget *widget, GdkEventExpose *event, void*__)
{
  UNUSED(__);
  int x0, y0, wt, ht, hibackpainted;
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

  //paint background / draw hilighted background (before drawing items)
  hibackpainted= paint_toolbar_back( T, cr, &drawarea );

  //draw all visible groups
  for( g= T->group; (g != NULL); g= g->next ){
    if( (g->flags & TTBF_HIDDEN) == 0 ){
      x0= g->barx1;
      y0= g->bary1;
      if( need_redraw( &drawarea, x0, y0, g->barx2, g->bary2) ){
        wt= g->barx2 - g->barx1;
        ht= g->bary2 - g->bary1;
        cairo_save(cr);
        cairo_rectangle(cr, x0, y0, wt, ht );
        cairo_clip(cr);
        //draw visible group's items
        paint_group_items(g, cr, &drawarea, x0, y0, wt, ht, hibackpainted );
        cairo_restore(cr);
      }
    }
  }
  cairo_destroy(cr);
  return TRUE;
}

static gboolean ttb_mouseleave_ev(GtkWidget *widget, GdkEventCrossing *event)
{
  UNUSED(event);
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
//    state = event->state;
  }
//  if( (state & GDK_BUTTON1_MASK) == 0 ){
//    if( ttb.phipress != NULL ) //mouse release event lost or coming?
//  }
  mouse_move_toolbar(T, x, y);
  return TRUE;
}

static gboolean ttb_scrollwheel_ev(GtkWidget *widget, GdkEventScroll* event, void*__)
{
  UNUSED(__);
  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T != NULL ){
    //don't scroll if a button is pressed (mouse still down)
    if( ttb.phipress == NULL ){
      if( (event->direction == GDK_SCROLL_UP)||(event->direction == GDK_SCROLL_LEFT) ){
        scroll_toolbarT(T, event->x, event->y, -1);
      }else{
        scroll_toolbarT(T, event->x, event->y, 1);
      }
    }
  }
  return TRUE;
}

void fire_tab_clicked_event( struct toolbar_item * p )
{
  if( p != NULL ){
    lL_event(lua, "toolbar_tabclicked", LUA_TNUMBER, p->num, LUA_TNUMBER, p->group->toolbar->num, -1);
  }
}

static gboolean ttb_button_ev(GtkWidget *widget, GdkEventButton *event, void*__)
{
  struct toolbar_item * p;
  UNUSED(__);
  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T == NULL ){
    return FALSE;
  }

  if( (event->button == 1)||(event->button == 3) ){
    if(event->type == GDK_BUTTON_PRESS){
      set_hilight_off();  //clear previous hilight
      ttb.phipress= item_fromXYT(T, event->x, event->y);
      if( ttb.phipress != NULL ){
        ttb.philight= ttb.phipress; //hilight as pressed
        ttb.ntbhilight= T->num;
        if( ttb.phipress->back_color == BKCOLOR_PICKER ){
          color_pick_ev( ttb.phipress, 0, 0 ); //COLOR PICKER click
        }
        redraw_item(ttb.philight);
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
          scroll_toolbarT(T, event->x, event->y, p->num);

        }else if( (p->flags & TTBF_CLOSETAB_BUT) != 0 ){
          lL_event(lua, "toolbar_tabclicked", LUA_TNUMBER, p->num, LUA_TNUMBER, T->num, -1);
          lL_event(lua, "toolbar_tabclose",   LUA_TNUMBER, p->num, LUA_TNUMBER, T->num, -1);

        }else if( (p->flags & TTBF_TAB) == 0 ){
          if((event->button == 1) && (p->name != NULL)){
            lL_event(lua, "toolbar_clicked", LUA_TSTRING, p->name, LUA_TNUMBER, T->num, -1);
          }
        }else{
          if(event->button == 1){
            lL_event(lua, "toolbar_tabclicked", LUA_TNUMBER, p->num, LUA_TNUMBER, T->num, -1);
          }else if(event->button == 3){
            if( lL_event(lua, "toolbar_tabRclicked", LUA_TNUMBER, p->num, LUA_TNUMBER, T->num, -1) ){
              lL_showcontextmenu(lua, event, "tab_context_menu"); //open context menu
            }
          }
        }
      }else{
        redraw_item(p);      //redraw button under mouse (if any)
        if( ttb.ntbhilight == T->num ){
          redraw_item(ttb.philight); //redraw hilighted button (if any in this toolbar)
        }
      }
      ttb.phipress= NULL;
      return TRUE;
    }
    if(event->type == GDK_2BUTTON_PRESS){ //double click
      if(event->button == 1){
        p= item_fromXYT(T, event->x, event->y);
        if( p != NULL ){
          if( (p->flags & TTBF_TAB) != 0 ){
            lL_event(lua, "toolbar_tab2clicked", LUA_TNUMBER, p->num, LUA_TNUMBER, T->num, -1);
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
  UNUSED(_); UNUSED(__);
  struct toolbar_data *T= toolbar_from_popup(widget);
  if( T != NULL ){
    lL_event(lua, "popup_close", LUA_TNUMBER, T->num, -1);
    return TRUE;
  }
  return FALSE;
}

static int popup_keypress_ev(GtkWidget * widget, GdkEventKey *event, void*_) {
  UNUSED(_);
  struct toolbar_data *T= toolbar_from_popup(widget);
  if( (T != NULL) && (event->keyval == GDK_Escape) ){
    lL_event(lua, "popup_close", LUA_TNUMBER, T->num, -1);
    return TRUE;
  }
  return FALSE;
}

static void ttb_show_popup( int ntb, int show, int x, int y, int w, int h )
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

        signal(T->win, "focus-out-event", popup_focus_out_ev);
        signal(T->win, "key-press-event", popup_keypress_ev);

        GtkWidget *vbox = gtk_vbox_new(FALSE, 0);
        gtk_container_add(GTK_CONTAINER(T->win), vbox);
        create_tatoolbar(vbox, ntb);
        gtk_widget_show_all(T->win);
        show_toolbar( T, 1 );
        gtk_widget_grab_focus(T->win);
      }
    }
  }else{
    //HIDE POPUP
    if( T->win != NULL ){
      show_toolbar( T, 0 );
      gtk_widget_destroy( T->win );
      T->win= NULL;
      T->draw= NULL;
    }
  }
}

/** `toolbar.popup(ntoolbar, show, x, y, width, height)` Lua function. */
/** `toolbar.popup(ntoolbar, show, button-name, button-corner, width, height)` Lua function. */
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
  if( w < T->barwidth ){
    w= T->barwidth;
  }
  h= intluadef(L, 6, 10);
  if( h < T->barheight ){
    h= T->barheight;
  }
  if( lua_isstring(L,3) ){
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
      y += p->group->bary1;
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
  ttb_show_popup( ntb, show, x, y, w, h );
  return 0;
}

/** `toolbar.menustatus(menu_id, status)` Lua function. */
/** status: 0=enabled, 1=checked, 2=unchecked, 3=radio-checked, 4=radio-unchecked, +8=disabled, (+16=radio is group-first) */
static int ltoolbar_menustatus(lua_State *L)
{
  setmenuitemstatus(lua_tointeger(L, 1), lua_tointeger(L, 2));
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
/*                          FUNCTIONS CALLED FROM TA                             */
/* ============================================================================= */
/* register LUA toolbar object */
void register_toolbar(lua_State *L)
{
  //init tatoolbar vars like color picker
  init_tatoolbar_vars();

  //register "toolbar" functions
  lua_newtable(L);
  //toolbars
  l_setcfunction(L, -1, "new",          ltoolbar_new);	        //create a new toolbar (returns toolbar num)
  l_setcfunction(L, -1, "adjust",       ltoolbar_adjust);	      //optionaly fine tune some parameters
  l_setcfunction(L, -1, "show",         ltoolbar_show);	        //show/hide toolbar
  //groups
  l_setcfunction(L, -1, "seltoolbar",   ltoolbar_seltoolbar);   //select which toolbar/group to edit
  l_setcfunction(L, -1, "addgroup",     ltoolbar_addgroup);     //add a new group (returns group num)
  l_setcfunction(L, -1, "addtabs",      ltoolbar_addtabs);      //add a tabs-group
  l_setcfunction(L, -1, "showgroup",    ltoolbar_showgroup);    //show/hide a group
  //buttons
  l_setcfunction(L, -1, "addbutton",    ltoolbar_addbutton);    //add button
  l_setcfunction(L, -1, "addtext",      ltoolbar_addtext);      //add text button
  l_setcfunction(L, -1, "addlabel",     ltoolbar_addlabel);     //add a text label
  l_setcfunction(L, -1, "addspace",     ltoolbar_addspace);     //add some space
  l_setcfunction(L, -1, "gotopos",      ltoolbar_gotopos);	    //change next button position
  l_setcfunction(L, -1, "enable",       ltoolbar_enable);	      //enable/disable a button
  l_setcfunction(L, -1, "seticon",      ltoolbar_seticon);	    //change a button, GROUP or TOOLBAR icon
  l_setcfunction(L, -1, "setbackcolor", ltoolbar_setbackcolor); //change a button, GROUP or TOOLBAR back color
  l_setcfunction(L, -1, "settooltip",   ltoolbar_settooltip);	  //change a button tooltip
  l_setcfunction(L, -1, "settext",      ltoolbar_settext);      //change a button text
  l_setcfunction(L, -1, "textfont",     ltoolbar_textfont);     //set text buttons font size and colors
  //tabs
  l_setcfunction(L, -1, "tabfontcolor", ltoolbar_tabfontcolor); //change default tab font color
  l_setcfunction(L, -1, "settab",       ltoolbar_settab);       //set tab num
  l_setcfunction(L, -1, "deletetab",    ltoolbar_deletetab);    //delete tab num
  l_setcfunction(L, -1, "activatetab",  ltoolbar_activatetab);  //activate tab num
  l_setcfunction(L, -1, "enabletab",    ltoolbar_enabletab);    //enable/disable tab num
  l_setcfunction(L, -1, "modifiedtab",  ltoolbar_modifiedtab);  //show/hide changed indicator in tab num
  l_setcfunction(L, -1, "hidetab",      ltoolbar_hidetab);      //hide/show tab num
  l_setcfunction(L, -1, "tabwidth",     ltoolbar_tabwidth);     //set tab num tabwidth (varible/fixed)
  l_setcfunction(L, -1, "gototab",      ltoolbar_gototab);      //generate a click in tab: -1:prev,1:next,0:first,2:last
  //get
  l_setcfunction(L, -1, "getpickcolor", ltoolbar_getpickcolor); //return integer (RGB) current selected color in picker
  l_setcfunction(L, -1, "getversion",   ltoolbar_getversion);   //return string ta-toolbar version
  //popup
  l_setcfunction(L, -1, "popup",        ltoolbar_popup);        //show a popup toolbar
  //menuitem
  l_setcfunction(L, -1, "menustatus",   ltoolbar_menustatus);   //change menu item status
  //toolbar object
  lua_setglobal(L, "toolbar");

  //register "filediff" functions
  lua_newtable(L);
  //file diff
  l_setcfunction(L, -1, "setfile",      lfilediff_setfile);	    //load a file to compare
  l_setcfunction(L, -1, "getdiff",      lfilediff_getdiff);     //get file differences (int array)
  l_setcfunction(L, -1, "strdiff",      lfilediff_strdiff);     //compare to strings
  //filediff object
  lua_setglobal(L, "filediff");
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
  if( (text != NULL) && (T->isvisible) ){
    G= T->tab_group;
    if( G != NULL ){
      if( bar == 0 ){
        set_tabtextG(G, 1, text, text, 1 ); //tooltip = text in case it can be shown complete
      }else{
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
      }
      return 0;
    }
  }
  return 1; //update the regular status bar
}

/* create a DRAWING-AREA for each toolbar */
//ntoolbar=0: HORIZONTAL  (top)
//ntoolbar=1: VERTICAL    (left)
//ntoolbar=2: HORIZONTAL  (bottom)
//ntoolbar=3: VERTICAL    (right)
//ntoolbar=4: VERTICAL    (POPUP)
static void create_tatoolbar( GtkWidget *vbox, int ntoolbar )
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
      if( T->isvertical ){
        gtk_widget_set_size_request(draw, 1, -1);
      }else{
        gtk_widget_set_size_request(draw, -1, 1);
      }
    }
    gtk_widget_set_events(draw, GDK_EXPOSURE_MASK|GDK_LEAVE_NOTIFY_MASK|
      GDK_POINTER_MOTION_MASK|GDK_BUTTON_PRESS_MASK|GDK_BUTTON_RELEASE_MASK );
    signal(draw, "size-allocate",        ttb_size_ev);
    signal(draw, "expose_event",         ttb_paint_ev);
    signal(draw, "leave-notify-event",   ttb_mouseleave_ev);
    signal(draw, "motion_notify_event",  ttb_mousemotion_ev);
    signal(draw, "scroll-event",         ttb_scrollwheel_ev);
    signal(draw, "button-press-event",   ttb_button_ev);
    signal(draw, "button-release-event", ttb_button_ev);

    gtk_box_pack_start(GTK_BOX(vbox), draw, FALSE, FALSE, 0);
  }
}

void set_toolbar_size(struct toolbar_data *T)
{
  GtkWidget * draw= get_draw_widget( T );
  if( draw != NULL ){
      gtk_widget_set_size_request(draw, T->barwidth, T->barheight);
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

void show_toolbar(struct toolbar_data *T, int show)
{ //show/hide one toolbar
  if( T != NULL ){
    if( (show) && (!T->isvisible) ){
      //show this toolbar
      T->_layout_chg= 0;
      T->isvisible= 1;
      gtk_widget_show( T->draw );
      //redraw the complete toolbar
      redraw_toolbar(T);
      if( T->num == 2 ){
        gtk_widget_hide( statusbar[0] );
        gtk_widget_hide( statusbar[1] );
      }
    }else if( (!show) && (T->isvisible) ){
      //hide this toolbar
      T->isvisible= 0;
      gtk_widget_hide( T->draw );
      if( T->num == 2 ){
        gtk_widget_show( statusbar[0] );
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
}
