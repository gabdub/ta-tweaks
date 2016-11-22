/* TA toolbar */
#include "tatoolbar.h"

//#define UNUSED(expr) do { (void)(expr); } while (0)

//from textadept.c
static void lL_showcontextmenu(lua_State *L, GdkEventButton *event, char *k);

//pre declarations
static int  set_item_img( struct toolbar_item *p, int nimg, const char *imgname );
static void setrgbcolor(int rgb, struct color3doubles *pc);
static int set_text_bt_width(struct toolbar_item * p );
static int get_group_imgW( struct toolbar_group *G, int nimg );
static int get_group_imgH( struct toolbar_group *G, int nimg );
static void set_hilight_off( void );
static void set_hilight_tooltipT( struct toolbar_data *T );

/* ============================================================================= */
/*                                DATA                                           */
/* ============================================================================= */
static struct all_toolbars_data ttb;
static char xbutt_tooltip[128];
static struct toolbar_item xbutton;

/* ============================================================================= */
/*                                MEMORY LISTS                                   */
/* ============================================================================= */
static char * alloc_str( const char *s )
{ //alloc a copy of a string
  char *scopy= NULL;
  if( s != NULL ){
    scopy= malloc(strlen(s)+1);
    if( scopy != NULL ){
      strcpy( scopy, s);
    }
  }
  return scopy;
}

static char * chg_alloc_str( char *sold, const char *snew )
{ //reuse or alloc a new string
  if( sold != NULL ){
    if( snew != NULL ){
      if( strcmp( sold, snew) == 0 ){
        //same string, keep the old one
        return sold;
      }
      if( strlen(sold) >= strlen(snew) ){
        //the newer is equal or shorter the old one, overwrite it
        strcpy( sold, snew );
        return sold;
      }
    }
    //delete old value
    free( (void *) sold);
  }
  //use new value
  return alloc_str(snew);
}

static char * alloc_img_str( const char *name )
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

static struct toolbar_group *add_groupT(struct toolbar_data *T, int flg)
{ //add a new group to a toolbar (flags version)
  int i;
  struct toolbar_group * g;

  if( T == NULL ){
    return NULL;
  }

  g= T->group_last;
  //check for the auto created group
  if( (g != NULL) && (flg != TTBF_GRP_AUTO) && (g->flags == TTBF_GRP_AUTO) ){
    g->flags= flg;  //set the new flags
    return g;
  }
  g= (struct toolbar_group *) malloc( sizeof(struct toolbar_group));
  if( g != NULL){
    //set defaults
    memset( (void *)g, 0, sizeof(struct toolbar_group));
    g->tabfontsz= 10;  //tab font size in points (default = 10 points)
    setrgbcolor( 0x808080, &g->tabtextcolG); //gray
    g->txtfontsz= 12;  //text button font size in points (default = 12 points)
    g->txttexty= -1;
    setrgbcolor( 0x808080, &g->txttextcolG); //gray

    if( g->isvertical ){
      g->xmargin= 1;
      g->ymargin= 2;
    }else{
      g->xmargin= 2;
      g->ymargin= 1;
    }
    g->toolbar= T;        //set parent
    g->num= T->ngroups;   //number of group (0..)
    g->flags= flg;
    T->ngroups++;
    g->isvertical= T->isvertical; //is a vertical group
    //hide scroolbar buttons
    g->islast_item_shown= 1;
    g->scleftx1= -1;
    g->scrightx1= -1;

    //default: square buttons
    g->bwidth= T->buttonsize;
    g->bheight= g->bwidth;
    g->xoff= (g->bwidth - T->imgsize)/2;
    if( g->xoff < 0){
      g->xoff= 0;
    }
    g->yoff= g->xoff;
    g->xnew= g->xmargin;
    g->ynew= g->ymargin;
    g->back_color= BKCOLOR_NOT_SET;
    g->yvscroll= 0;

    //add the group to the end of the list
    if( T->group_last != NULL ){
      T->group_last->next= g;
    }else{
      T->group= g; //first one
    }
    T->group_last= g;
    //set as the current group
    T->curr_group= g;
  }
  return g;
}

/** x/y control:
  0:allow groups before and after 1:no groups at the left/top  2:no groups at the right/bottom
  3:exclusive row/col  +4:expand  +8:use item size +16:vert-scroll */
static struct toolbar_group *add_groupT_rcoh(struct toolbar_data *T, int xcontrol, int ycontrol, int hidden)
{ //add a new group to a toolbar (row, col, hidden version)
  int flags= TTBF_SELECTABLE;

  if( (xcontrol & 1) != 0 ){
    flags |= TTBF_GRP_LEFT;   //no groups before in the same row
  }
  if( (xcontrol & 2) != 0 ){
    flags |= TTBF_GRP_RIGHT;  //no groups after in the same row
  }
  if( (xcontrol & 4) != 0 ){
    flags |= TTBF_GRP_VAR_W;  //this group has variable width
  }else if( (xcontrol & 8) != 0 ){
    flags |= TTBF_GRP_ITEM_W; //this group set width using items position
  }

  if( (ycontrol & 1) != 0 ){
    flags |= TTBF_GRP_TOP;   //no groups before in the same column
  }
  if( (ycontrol & 2) != 0 ){
    flags |= TTBF_GRP_BOTTOM; //no groups after in the same column
  }
  if( (ycontrol & 4) != 0 ){
    flags |= TTBF_GRP_VAR_H;  //this group has variable height
  }else if( (ycontrol & 8) != 0 ){
    flags |= TTBF_GRP_ITEM_H; //this group set height using items position
  }
  if( (ycontrol & 16) != 0 ){
    flags |= TTBF_GRP_VSCROLL; //this group shows a vertical scrollbar when needed
  }

  if( hidden ){
    flags |= TTBF_HIDDEN;
  }
  return add_groupT(T, flags);
}

static struct toolbar_item *add_itemG(struct toolbar_group *G, const char * name, const char * img, const char *tooltip, const char * text, int chwidth)
{ //add a new item to a group
  if( G == NULL ){
    return NULL;
  }
  struct toolbar_item * p= (struct toolbar_item *) malloc( sizeof(struct toolbar_item));
  if( p != NULL){
    memset( (void *)p, 0, sizeof(struct toolbar_item));
    p->group= G;  //set parent
    p->name= alloc_str(name);
    p->text= alloc_str(text);
    p->tooltip= alloc_str(tooltip);
    if( (p->name != NULL) && (*(p->name) != 0) ){
      p->flags= TTBF_SELECTABLE; //if a name is provided, it can be selected (it's a button)
    }
    p->barx1= G->xnew;
    p->bary1= G->ynew;
    p->imgx= G->xnew + G->xoff;
    p->imgy= G->ynew + G->yoff;
    p->barx2= G->xnew + G->bwidth;
    p->bary2= G->ynew + G->bheight;
    p->changewidth= chwidth;
    if( chwidth > 0 ){
      p->minwidth= chwidth;
      p->maxwidth= chwidth;
    }
    if( img != NULL ){
      set_item_img( p, TTBI_NORMAL, img );

    }else if( p->text != NULL ){
      //text button (text & no image)
      set_text_bt_width(p);
      p->flags |= TTBF_TEXT;
    }
    p->back_color= BKCOLOR_NOT_SET;
    if( G->isvertical ){
      G->ynew= p->bary2;
    }else{
      G->xnew= p->barx2;
    }

    //add the item to the end of the list
    if( G->list_last != NULL ){
      G->list_last->next= p;
    }else{
      G->list= p; //first one
    }
    G->list_last= p;
  }
  return p;
}

static struct toolbar_item *add_tabG(struct toolbar_group *G, int ntab)
{ //add a new tab to a group
  struct toolbar_item * p= (struct toolbar_item *) malloc( sizeof(struct toolbar_item));
  if( p != NULL){
    memset( (void *)p, 0, sizeof(struct toolbar_item));
    p->group= G;  //set parent
    p->num= ntab;
    p->flags= TTBF_TAB | TTBF_SELECTABLE;

    p->changewidth= G->tabchangewidth;  //use TAB default
    if( p->changewidth < 0 ){
      G->nitems_expand++;
    }
    p->minwidth= G->tabminwidth;
    p->maxwidth= G->tabmaxwidth;
    p->back_color= BKCOLOR_NOT_SET;

    //add the tab to the end of the list
    if( G->list_last != NULL ){
      G->list_last->next= p;
    }else{
      G->list= p; //first
    }
    G->list_last= p;
    G->nitems++;
    G->nitems_nothidden++;
  }
  return p;
}

static void free_item_node( struct toolbar_item * p )
{
  int i;
  if( ttb.cpick.pchosen == p ){
    ttb.cpick.pchosen= NULL;
  }
  if(p->name != NULL){
    free((void*)p->name);
  }
  if(p->text != NULL){
    free((void*)p->text);
  }
  if(p->tooltip != NULL){
    free((void*)p->tooltip);
  }
  //free item images
  for(i= 0; (i < TTBI_NODE_N); i++){
    if( p->img[i].fname != NULL ){
      free((void*)p->img[i].fname);
    }
  }
  free((void*)p);
}

static void free_item_list( struct toolbar_item * list )
{
  struct toolbar_item * p;
  while(list != NULL){
    p= list;
    list= list->next;
    free_item_node(p);
  }
}

static void free_group_node( struct toolbar_group * g )
{
  int i;
  free_item_list( g->list );
  //free group images
  for(i= 0; (i < TTBI_TB_N); i++){
    if( g->img[i].fname != NULL ){
      free((void*)g->img[i].fname);
    }
  }
  free((void*)g);
}

static void free_group_list( struct toolbar_group * group )
{
  struct toolbar_group * g;
  while(group != NULL){
    g= group;
    group= group->next;
    free_group_node(g);
  }
}

static void free_toolbar_num( int num )
{ //free one toolbar data
  int i;
  struct toolbar_data *T;

  if( (num >= 0) && (num < NTOOLBARS) ){
    T= &(ttb.tbdata[num]);
    free_group_list( T->group );
    T->group= NULL;
    T->group_last= NULL;
    T->curr_group= NULL;
    T->ngroups= 0;
    T->currentgroup= 0;
    if(ttb.ntbhilight == num){
      ttb.philight= NULL;
      ttb.phipress= NULL;
      ttb.ntbhilight= -1;
    }
    //free toolbar images
    for(i= 0; (i < TTBI_TB_N); i++){
      if( T->img[i].fname != NULL ){
        free((void*)T->img[i].fname);
        T->img[i].fname= NULL;
      }
      T->img[i].width= 0;
      T->img[i].height= 0;
    }
  }
}

static void free_tatoolbar( void )
{
  int nt;
  for( nt= 0; nt < NTOOLBARS; nt++ ){
    free_toolbar_num(nt);
  }
  //free global image base
  if( ttb.img_base != NULL ){
    free((void *)ttb.img_base);
    ttb.img_base= NULL;
  }
  ttb.philight= NULL;
  ttb.phipress= NULL;
  ttb.ntbhilight= -1;
  ttb.currentntb= 0;
  ttb.cpick.pchosen= NULL;
}

/* ============================================================================= */
/*                                FIND                                           */
/* ============================================================================= */
static struct toolbar_data * toolbar_from_num(int num)
{
  if( (num >= 0) && (num < NTOOLBARS) ){
    return &(ttb.tbdata[num]);
  }
  return NULL;  //toolbar not found
}

static struct toolbar_data * current_toolbar( void )
{
  return toolbar_from_num(ttb.currentntb);
}

static struct toolbar_data * toolbar_from_widget(GtkWidget *widget)
{
  int i;
  if( widget != NULL ){
    for( i= 0; i < NTOOLBARS; i++ ){
      if( widget == ttb.tbdata[i].draw ){
        return &(ttb.tbdata[i]);
      }
    }
  }
  return NULL;  //toolbar not found
}

static struct toolbar_group * group_from_numT(struct toolbar_data *T, int ngrp)
{
  struct toolbar_group * g;
  if( T != NULL ){
    for( g= T->group; (g != NULL); g= g->next ){
      if( g->num == ngrp ){
        return g;
      }
    }
  }
  return NULL; //group not found
}

static struct toolbar_group * current_group( void )
{
  struct toolbar_data * T= current_toolbar();
  if( T != NULL ){
    return T->curr_group;
  }
  return NULL;
}

static struct toolbar_group * current_tabbar( void )
{
  struct toolbar_data * T= current_toolbar();
  if( T != NULL ){
    return T->tab_group;
  }
  return NULL;
}

static struct toolbar_item * item_from_numG(struct toolbar_group *G, int nitem)
{
  struct toolbar_item * p;
  if( G != NULL ){
    for( p= G->list; (p != NULL); p= p->next ){
      if( p->num == nitem ){
        return p;
      }
    }
  }
  return NULL; //item not found
}

static struct toolbar_item * item_from_nameG(struct toolbar_group *G, const char *name)
{ //find an item in a group
  struct toolbar_item * p;
  if( (G != NULL) && (name != NULL) ){
    for( p= G->list; (p != NULL); p= p->next ){
      if( (p->name != NULL) && (strcmp(p->name, name) == 0) ){
        return p;
      }
    }
  }
  return NULL; //item not found
}

static struct toolbar_item * item_from_nameT(struct toolbar_data *T, const char *name)
{ //find an item in a toolbar
  struct toolbar_item * p;
  struct toolbar_group * g;
  if( T != NULL ){
    for( g= T->group; (g != NULL); g= g->next ){
      p= item_from_nameG(g, name);
      if( p != NULL){
        return p;
      }
    }
  }
  return NULL; //item not found
}

static struct toolbar_item * find_prev_itemG( struct toolbar_group *G, struct toolbar_item * item )
{
  struct toolbar_item * p;
  if( (G != NULL) && (G->list != item) ){
    for( p= G->list; (p != NULL); p= p->next ){
      if( p->next == item ){
        return p; //previous item in the list
      }
    }
  }
  return NULL;  //first (or not found)
}

static struct toolbar_group * group_fromXYT(struct toolbar_data *T, int x, int y)
{
  struct toolbar_group * g;
  if( T != NULL ){
    for( g= T->group; (g != NULL); g= g->next ){
      //the group must be selectable and not hidden
      if( ((g->flags & (TTBF_SELECTABLE|TTBF_HIDDEN)) == TTBF_SELECTABLE) &&
          (x >= g->barx1) && (x <= g->barx2) && (y >= g->bary1) && (y <= g->bary2) ){
        return g;
      }
    }
  }
  return NULL; //group not found
}

static int item_xoff;
static int item_yoff;
static struct toolbar_item * item_fromXYT(struct toolbar_data *T, int xt, int yt)
{
  struct toolbar_group * G;
  struct toolbar_item * p;
  int nx, nhide, xc1, xc2, yc1, yc2, x, y;
  char *s;

  item_xoff= 0;
  item_yoff= 0;
  if( T == NULL ){
    return NULL; //no toolbar
  }
  //first find the group
  G= group_fromXYT(T, xt, yt);
  if( G == NULL ){
    return NULL; //no selectable group found in x,y
  }
  //check if scroll buttons are shown in the group
  if((G->scleftx1 >= 0)&&(xt >= G->scleftx1)&&(xt <= G->scleftx2)&&
      (yt >= G->sclefty1)&&(yt <= G->sclefty2)){
    item_xoff= xt - G->scleftx1;
    item_yoff= yt - G->sclefty1;
    xbutton.flags= TTBF_SCROLL_BUT;
    xbutton.num= -1;
    xbutton.tooltip= NULL;
    xbutton.group= G;
    return &xbutton; //scroll left button
  }
  if((G->scrightx1 >= 0)&&(xt >= G->scrightx1)&&(xt <= G->scrightx2)&&
      (yt >= G->scrighty1)&&(yt <= G->scrighty2)){
    item_xoff= xt - G->scrightx1;
    item_yoff= yt - G->scrighty1;
    xbutton.flags= TTBF_SCROLL_BUT;
    xbutton.num= 1;
    xbutton.tooltip= NULL;
    xbutton.group= G;
    return &xbutton; //scroll right button
  }
  x= xt - G->barx1 - G->tabxmargin;
  y= yt - G->bary1;
  if( (G->flags & TTBF_GRP_TABBAR) != 0){
    //is a tabbar, locate tab-node
    for( p= G->list, nx=0; (p != NULL); p= p->next, nx++ ){
      for( p= G->list, nhide= G->nitems_scroll; (nhide > 0)&&(p != NULL); nhide-- ){
        p= p->next; //skip hidden tabs (scroll support)
      }
      for( ; (x >= 0)&&(p != NULL); p= p->next ){
        //ignore non selectable or hidden tabs
        if( (p->flags & TTBF_HIDDEN) == 0 ){  //skip hidden tabs
          if( ((p->flags & TTBF_SELECTABLE) != 0) && (x <= p->barx2) ){
            if( G->closeintabs ){
              //over close tab button?
              xc1= p->barx2 - p->postw;
              xc2= xc1 + get_group_imgW(G,TTBI_TB_TAB_NCLOSE);
              yc2= get_group_imgH(G,TTBI_TB_TAB_NCLOSE);
              yc1= yc2 - (xc2-xc1); //square close area
              if( yc1 < 0){
                yc1= 0;
              }
              if( (x >= xc1)&&(x <= xc2)&&(y >= yc1)&&(y <= yc2) ){
                xbutton.flags= TTBF_CLOSETAB_BUT;
                xbutton.num= p->num;
                xbutton.group= G;
                xbutton.tooltip= xbutt_tooltip;
                strcpy( xbutt_tooltip, "Close " );
                s= p->tooltip;
                if( s == NULL ){
                  s= p->text;
                }
                if( s != NULL ){
                  strncpy( xbutt_tooltip+6, s, sizeof(xbutt_tooltip)-7 );
                  xbutt_tooltip[sizeof(xbutt_tooltip)-1]= 0;
                }else{
                  strcpy( xbutt_tooltip+6, "tab" );
                }
                item_xoff= x - xc1;
                item_yoff= y - yc1;
                return &xbutton; //close tab button
              }
            }
            item_xoff= x;
            item_yoff= y;
            return p; //TAB
          }
          x -= p->barx2 + G->tabxsep;
        }
      }
      return NULL; //no tab found
    }
  }
  //is a regular button bar
  y += G->yvscroll;  //vertical scroll support
  for( p= G->list; (p != NULL); p= p->next ){
    //ignore non selectable or hidden things (like separators)
    if( ((p->flags & (TTBF_SELECTABLE|TTBF_HIDDEN)) == TTBF_SELECTABLE) &&
        (x >= p->barx1) && (x <= p->barx2) && (y >= p->bary1) && (y <= p->bary2) ){
      item_xoff= x - p->barx1;
      item_yoff= y - p->bary1;
      return p; //BUTTON
    }
  }
  return NULL;
}

/* ============================================================================= */
/*                                IMG LIST                                       */
/* ============================================================================= */
static int set_pti_img( struct toolbar_img *pti, const char *imgname )
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

static int set_toolbar_img( struct toolbar_data *T, int nimg, const char *imgname )
{ //set a toolbar image
  //return 1 if a toolbar redraw is needed
  struct toolbar_img *pti;
  struct toolbar_group * g;
  if( (T != NULL) && (nimg >= 0) && (nimg < TTBI_TB_N) ){
    pti= &(T->img[nimg]);
    return set_pti_img(pti, imgname );
  }
  return 0; //no redraw needed
}

static int set_group_img( struct toolbar_group *G, int nimg, const char *imgname )
{ //set a group image
  //return 1 if a group redraw is needed
  struct toolbar_img *pti;
  if( (G != NULL) && (nimg >= 0) && (nimg < TTBI_TB_N) ){
    pti= &(G->img[nimg]);
    return set_pti_img(pti, imgname );
  }
  return 0; //no redraw needed
}

static int set_item_img( struct toolbar_item *p, int nimg, const char *imgname )
{ //set an item image
  //return 1 if redraw is needed
  if( (p != NULL) && (nimg >= 0) && (nimg < TTBI_NODE_N) ){
    return set_pti_img( &(p->img[nimg]), imgname );
  }
  return 0; //no redraw needed
}

static struct toolbar_img * get_toolbar_img( struct toolbar_data *T, int nimg )
{
  return &(T->img[nimg]); //use toolbar image
}


static struct toolbar_img * get_group_img( struct toolbar_group *G, int nimg )
{
  if(G->img[nimg].width > 0){
    return &(G->img[nimg]);         //use group image
  }
  return &(G->toolbar->img[nimg]);  //use toolbar image
}

static struct toolbar_img * get_item_img( struct toolbar_item *p, int nimg )
{
  struct toolbar_img *pti= &(p->img[nimg]); //use item image
  if( (pti->width == 0) && ((nimg == TTBI_HIPRESSED) || (nimg == TTBI_HILIGHT)) ){
    //no item image: use group/toolbar image (only for hilight)
    pti= get_group_img(p->group, nimg);
  }
  return pti;
}

static int get_group_imgW( struct toolbar_group *G, int nimg )
{
  if(G->img[nimg].width > 0){
    return G->img[nimg].width; //use group image
  }
  return G->toolbar->img[nimg].width; //use toolbar image
}

static int get_group_imgH( struct toolbar_group *G, int nimg )
{
  if(G->img[nimg].width > 0){
    return G->img[nimg].height; //use group image
  }
  return G->toolbar->img[nimg].height; //use toolbar image
}

/* ============================================================================= */
/*                                REDRAW                                         */
/* ============================================================================= */
static void redraw_toolbar( struct toolbar_data *T )
{ //redraw the complete toolbar
  if( (T != NULL) && (T->isvisible) ){
    gtk_widget_queue_draw(T->draw);
  }
}

static void redraw_group( struct toolbar_group *G )
{
  if( (G != NULL) && (G->toolbar->isvisible) && ((G->flags & TTBF_HIDDEN) == 0) ){
    gtk_widget_queue_draw_area(G->toolbar->draw, G->barx1, G->bary1,
      G->barx2 - G->barx1 +1, G->bary2 - G->bary1 +1 );
  }
}

static void redraw_item( struct toolbar_item * p )
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

static void redraw_begG( struct toolbar_group *G )
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

static void redraw_endG( struct toolbar_group *G )
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

/* ============================================================================= */
/*                            SIZE                                               */
/* ============================================================================= */
static int set_text_bt_width(struct toolbar_item * p )
{ //text button (text & no image)
  cairo_text_extents_t ext;
  cairo_t *cr;
  int diff= 0;
  struct toolbar_group *G= p->group;
  if( p->text != NULL ){
    cr = gdk_cairo_create(G->toolbar->draw->window);
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

    }else if( (p->maxwidth > 0) && (p->barx2 > (p->barx1+p->maxwidth)) ){
      //reduce button (trimm text)
      p->barx2= p->barx1+p->maxwidth;
    }
    diff= p->barx2 - diff;  //width diff
  }
  return diff;
}

static void clear_tabwidth(struct toolbar_item * p)
{
  if( p != NULL ){
    if( (p->flags & TTBF_HIDDEN) == 0 ){
      struct toolbar_group *G= p->group;
      if( p->changewidth >= 0 ){
        G->tabwidth -= p->barx2;
      }else{
        G->tabwidth -= p->prew + p->postw;
      }
    }
    p->barx2= 0;
  }
}

static void set_tabwidth(struct toolbar_item * p)
{
  if( (p != NULL) && ((p->flags & TTBF_HIDDEN) == 0) ){
    struct toolbar_group *G= p->group;
    if( p->changewidth >= 0 ){
      if( p->changewidth == 0 ){  //use text width
        //update textwidth if 0
        if( (p->textwidth == 0) && (p->text != NULL) && (*(p->text) != 0) &&
            ((p->minwidth == 0)||(p->minwidth != p->maxwidth)) ){
      //if min and max are set and equal, there is no need to know the textwidth
      // NOTE: using variable width in status-bar fields 2..7 in "WIN32" breaks the UI!!
      // this fields are updated from the UPDATE-UI event and
      // calling gdk_cairo_create in this context (to get the text extension) freeze the UI for a second
      // and breaks the editor update mecanism (this works fine under LINUX, though)
      // so, fixed width is used for this fields
          cairo_text_extents_t ext;
          cairo_t *cr = gdk_cairo_create(G->toolbar->draw->window);
          cairo_set_font_size(cr, G->tabfontsz);
          cairo_text_extents( cr, p->text, &ext );
          p->textwidth= (int) ext.width;
          cairo_destroy(cr);
        }
        p->barx2= p->prew + p->textwidth + p->postw;
      }else{
        p->barx2= p->changewidth; //use this value
        if( p->barx2 < (p->prew + p->postw) ){
          p->barx2= p->prew + p->postw;
        }
      }
      if( p->barx2 < p->minwidth ){
        p->barx2= p->minwidth;
      }
      if( (p->barx2 > p->maxwidth) && (p->maxwidth > 0) ){
        p->barx2= p->maxwidth;
      }
    }else{
      //% of toolbar.width
      p->barx2= p->prew + p->postw; //adjusted in update_tabs_sizeG()
    }
    G->tabwidth += p->barx2;
  }
}

static void update_tabs_sizeG( struct toolbar_group *G )
{
  int n, nexpv, extrasp, remainsp, varw, porctot, xend, groupwidth;
  struct toolbar_item *p, *pte;

  //get available width
  groupwidth= G->barx2 - G->barx1;

  //calc 'fixed' tabs end
  xend= G->barx1 + G->tabxmargin + G->tabwidth;
  //add extra space between visible tabs
  if( (G->nitems_nothidden > 1) && (G->tabxsep != 0) ){
    xend += (G->nitems_nothidden-1) * G->tabxsep;
  }

  //split free space in tabs that expand
  nexpv= 0;
  if( (G->nitems_expand > 0) && (groupwidth > 0) ){
    G->nitems_scroll= 0;
    G->islast_item_shown= 1;
    extrasp= groupwidth - xend; //extra space
    if( extrasp < 0 ){
      extrasp= 0; //no extra space
    }
    remainsp= extrasp;
    pte= NULL;
    porctot= 0;
    //first pass, count visible expand-tabs
    for( p= G->list; (p != NULL); p= p->next ){
      if( (p->changewidth < 0) && ((p->flags & TTBF_HIDDEN) == 0) ){
        if( nexpv == 0){
          pte= p; //the first one
        }
        nexpv++;
        porctot += p->changewidth;
      }
    }
    if( porctot == 0 ){
      porctot= -1;  //not needed, just in case... to prevent 0 div
    }
    //second pass, split the extra space
    for( p= pte, n= nexpv; (p != NULL); p= p->next, n-- ){
      if( (p->changewidth < 0) && ((p->flags & TTBF_HIDDEN) == 0) ){
        if( n == 1 ){
          //the last tab use all the remaining space
          remainsp -= G->tabxsep;
          if( remainsp < 0 ){
            remainsp= 0;
          }
          p->barx2= p->prew + p->postw + remainsp;
          if( p->barx2 < p->minwidth ){
            p->barx2= p->minwidth;
          }
          if( (p->barx2 > p->maxwidth) && (p->maxwidth > 0) ){
            p->barx2= p->maxwidth;
          }
          break;
        }
        varw= ((extrasp * p->changewidth) / porctot) - G->tabxsep;
        if( varw < 0 ){
          varw= 0;
        }
        if( varw > remainsp ){
          varw= remainsp;
        }
        p->barx2= p->prew + varw + p->postw;
        if( p->barx2 < p->minwidth ){
          p->barx2= p->minwidth;
        }
        if( (p->barx2 > p->maxwidth) && (p->maxwidth > 0) ){
          p->barx2= p->maxwidth;
        }
        remainsp -= p->barx2 - p->prew - p->postw;
      }
    }
//    if( nexpv > 0){
//      //at least one expand-tab is visible
//      //expand tab-node to use all the extra space
//      if( xend < groupwidth ){
//        xend= groupwidth;
//      }
//    }
//    G->barx2= xend
  }
}

static void set_XlayoutG(struct toolbar_group * g, int x1, int width)
{
  int x2= x1 + width;
  if( (g->barx1 != x1) || (g->barx2 != x2) ){
    g->barx1= x1;
    g->barx2= x2;
    //layout changed, redraw the complete toolbar
    g->toolbar->_layout_chg= 1;
  }
}

static void set_YlayoutG(struct toolbar_group * g, int y1, int height)
{
  int y2= y1 + height;
  if( (g->bary1 != y1) || (g->bary2 != y2) ){
    g->bary1= y1;
    g->bary2= y2;
    //layout changed, redraw the complete toolbar
    g->toolbar->_layout_chg= 1;
  }
}

static struct toolbar_group * find_rowendG( struct toolbar_group * g)
{
  struct toolbar_group * e;
  e= g;
  while( g->next != NULL ){
    g= g->next;
    if( (g->flags & TTBF_HIDDEN) == 0 ){  //ignore hidden groups
      if( (g->flags & TTBF_GRP_LEFT) != 0 ){
        break;  //this group start a new row
      }
      e= g;
      if( (g->flags & TTBF_GRP_RIGHT) != 0 ){
        break;  //this group is the last of the row
      }
    }
  }
  return e;
}

static struct toolbar_group * find_colendG( struct toolbar_group * g)
{
  struct toolbar_group * e;
  e= g;
  while( g->next != NULL ){
    g= g->next;
    if( (g->flags & TTBF_HIDDEN) == 0 ){  //ignore hidden groups
      if( (g->flags & TTBF_GRP_TOP) != 0 ){
        break;  //this group start a new col
      }
      e= g;
      if( (g->flags & TTBF_GRP_BOTTOM) != 0 ){
        break;  //this group is the last of the col
      }
    }
  }
  return e;
}

static void update_layoutT( struct toolbar_data *T)
{
  struct toolbar_group *g, *gs, *ge;
  int tw, th, w, h, n, sz, x, y, hg, wg, ww, hh;

  if( (T->barwidth < 0) || (T->barheight < 0) ){
    return; //wait for size to be known
  }

  //update variable size groups
  //and set group positions
  th= T->barheight;
  tw= T->barwidth;
  n= 0;
  if( T->isvertical ){   //---vertical toolbar---
    x= 0;
    gs= T->group;
    while( gs != NULL ){
      ge= find_colendG(gs); //process one COLUMN at a time
      h= th;
      g= gs;
      while( g != NULL ){
        w= 0;
        if( (g->flags & TTBF_HIDDEN) == 0 ){
          if( (g->flags & TTBF_GRP_VAR_H) == 0 ){
            h -= (g->bary2 - g->bary1); //fixed vert size
          }else{
            n++;  //var vert size
          }
          if( (g->flags & TTBF_GRP_VAR_W) == 0 ){
            ww= (g->barx2 - g->barx1);  //fixed horz size
            if( w < ww ){
              w= ww;
            }
          }
        }
        if( g == ge ){
          break; //last group of this col
        }
        g= g->next;
      }
      if( h < 0 ){
        h= 0;
      }
      sz= h;
      if( n > 1 ){
        sz= h / n;  //split 'not fixed' vertical space
      }
      y= 0;
      g= gs;
      while( g != NULL ){
        if( (g->flags & TTBF_HIDDEN) == 0 ){
          if( (g->flags & TTBF_GRP_VAR_H) == 0 ){
            hg= g->bary2 - g->bary1;  //fixed vert size
          }else{
            n--;    //var vert size
            if( n == 0 ){
              hg= h;
            }else{
              hg= sz;
              h -= sz;
            }
          }
          set_YlayoutG(g, y, hg);
          if( (g->flags & TTBF_GRP_VAR_W) == 0 ){
            set_XlayoutG(g, x, w);  //fixed horz size
          }else{
            set_XlayoutG(g, x, tw); //var horz size
          }
          y += hg;
        }
        if( g == ge ){
          break; //last group of this col
        }
        g= g->next;
      }
      gs= ge->next; //see next column
      x += w;
      tw -= w;
      if( tw < 0 ){
        tw= 0;
      }
    }
  }else{        //---horizontal toolbar---
    y= 0;
    gs= T->group;
    while( gs != NULL ){
      ge= find_rowendG(gs); //process one ROW at a time
      w= tw;
      g= gs;
      while( g != NULL ){
        h= 0;
        if( (g->flags & TTBF_HIDDEN) == 0 ){
          if( (g->flags & TTBF_GRP_VAR_W) == 0 ){
            w -= (g->barx2 - g->barx1); //fixed horz size
          }else{
            n++;    //var horz size
          }
          if( (g->flags & TTBF_GRP_VAR_H) == 0 ){
            hh= (g->bary2 - g->bary1);  //fixed ver size
            if( h < hh ){
              h= hh;
            }
          }
        }
        if( g == ge ){
          break; //last group of this row
        }
        g= g->next;
      }
      if( w < 0 ){
        w= 0;
      }
      sz= w;
      if( n > 1 ){
        sz= w / n;  //split 'not fixed' vertical space
      }
      x= 0;
      g= gs;
      while( g != NULL ){
        if( (g->flags & TTBF_HIDDEN) == 0 ){
          if( (g->flags & TTBF_GRP_VAR_W) == 0 ){
            wg= g->barx2 - g->barx1;    //fixed horz size
          }else{
            n--;    //var horz size
            if( n == 0 ){
              wg= w;
            }else{
              wg= sz;
              w -= sz;
            }
          }
          set_XlayoutG(g, x, wg);
          if( (g->flags & TTBF_GRP_VAR_H) == 0 ){
            set_YlayoutG(g, y, h);  //fixed vert size
          }else{
            set_YlayoutG(g, y, th); //var vert size
          }
          x += wg;
        }
        if( g == ge ){
          break; //last group of his row
        }
        g= g->next;
      }
      gs= ge->next;   //see next row
      y += h;
      th -= h;
      if( th < 0 ){
        th= 0;
      }
    }
  }
  //adjust tabs inside tabgroups
  for( g= T->group; (g != NULL); g= g->next ){
    if( (g->flags & (TTBF_GRP_TABBAR|TTBF_HIDDEN)) == TTBF_GRP_TABBAR ){
      update_tabs_sizeG(g); //split free space in tabs that expand
    }
  }
}

static void update_group_sizeG( struct toolbar_group *G, int redraw )
{ //group size changed, update toolbar
  struct toolbar_item * p;
  int w, h;

  if( (G->flags & (TTBF_GRP_ITEM_W|TTBF_GRP_ITEM_H)) != 0 ){
    //this group set its size using items position
    w= 0;
    h= 0;
    if( (G->flags & TTBF_HIDDEN) == 0 ){
      for( p= G->list; (p != NULL); p= p->next ){
        if( (p->flags & TTBF_HIDDEN) == 0 ){
          if( w < p->barx2 ){
            w= p->barx2;    //item's max X
          }
          if( h < p->bary2 ){
            h= p->bary2;    //item's max Y
          }
        }
      }
    }
    if( (G->flags & TTBF_GRP_ITEM_W) != 0 ){
      G->barx2= G->barx1 + w; //use items width
    }
    if( (G->flags & TTBF_GRP_ITEM_H) != 0 ){
      G->bary2= G->bary1 + h; //use items height
    }
  }

  //move groups if needed
  update_layoutT(G->toolbar);

  if( redraw ){
    //redraw the group/toolbar
    redraw_endG(G);
  }
}

static int get_tabtext_widthG(struct toolbar_group *G, const char * text )
{ //return the width of the given text
  if( (G != NULL) && (text != NULL) && (*text != 0) ){
    cairo_text_extents_t ext;
    cairo_t *cr = gdk_cairo_create(G->toolbar->draw->window);
    cairo_set_font_size(cr, G->tabfontsz);
    cairo_text_extents( cr, text, &ext );
    cairo_destroy(cr);
    return ((int) ext.width) + get_group_imgW(G,TTBI_TB_NTAB1) + get_group_imgW(G,TTBI_TB_NTAB3);
  }
  return 0;
}

//COLOR PICKER: dir: 0= (item_xoff, item_yoff) click,  +1/-1=mouse wheel
static void color_pick_ev( struct toolbar_item *p, int dir, int redraw )
{
  int x, y;
  int change= 0;
  if( dir == 0 ){
    //mouse down
    y= item_yoff - PICKER_MARG_TOP;
    if( y < 0 ){
      y= 0;
    }
    int yscroll= p->bary2 - p->bary1 - (PICKER_MARG_TOP+PICKER_MARG_BOTT);  //h=242-2= 240
    double dy= yscroll * HSV_V_DELTA * (1-HSV_V_DELTA);
    int xscroll= p->barx2 - p->barx1 - PICKER_VSCROLLW;
    if( item_xoff >= xscroll ){
      //V value scroll bar: set V
      ttb.cpick.HSV_val = 1.0 - (((int)((double)y / dy)) * HSV_V_DELTA);
      if( ttb.cpick.HSV_val > 1.0 ){
        ttb.cpick.HSV_val= 1.0;
      }
      if( ttb.cpick.HSV_val < 0.0 ){
        ttb.cpick.HSV_val= 0.0;
      }
    }else{
      //new color
      x= item_xoff - PICKER_MARG_LEFT;
      if( x < 0 ){
        x= 0;
      }
      ttb.cpick.HSV_x= (x * PICKER_CELL_W) / (xscroll - (PICKER_MARG_LEFT+PICKER_MARG_RIGHT));
      ttb.cpick.HSV_y= (y * PICKER_CELL_H) / yscroll;
      if( ttb.cpick.HSV_x >= PICKER_CELL_W ){
        ttb.cpick.HSV_x= PICKER_CELL_W-1;
      }
      if( ttb.cpick.HSV_y >= PICKER_CELL_H ){
        ttb.cpick.HSV_y= PICKER_CELL_H-1;
      }
    }
    change= 1;

  }else if( (dir < 0) && (ttb.cpick.HSV_val < 1.0) ){
    //wheel up
    ttb.cpick.HSV_val += HSV_V_DELTA;
    if( ttb.cpick.HSV_val > 1.0){
      ttb.cpick.HSV_val= 1.0;
    }
    change= 1;

  }else if( (dir > 0) && (ttb.cpick.HSV_val > 0.0) ){
    //wheel down
    ttb.cpick.HSV_val -= HSV_V_DELTA;
    if( ttb.cpick.HSV_val < 0.0){
      ttb.cpick.HSV_val= 0.0;
    }
    change= 1;
  }
  if( change ){
    /* update RGB from HSV */
    if( ttb.cpick.HSV_y == (PICKER_CELL_H-1) ){
      //last row (B/W)
      double dv= 255.0 / (PICKER_CELL_W-1);
      int r= dv * ttb.cpick.HSV_x;
      ttb.cpick.HSV_rgb= r | r << 8 | r << 16;
    }else{
      //HSV color wheel
      //  H   0º    60º   120º  180º  240º  300º
      //  R   max   down  min   min   up    max
      //  G   up    max   max   down  min   min
      //  B   min   min   up    max   max   down
      // max= V
      // min= V*(1-S)
      int a= ttb.cpick.HSV_x / (PICKER_CELL_W/6); //H section
      int f= ttb.cpick.HSV_x % (PICKER_CELL_W/6); //H
      double max= ttb.cpick.HSV_val;
      double min= max * ((double)ttb.cpick.HSV_y) / ((double)PICKER_CELL_H);
      double v= ((max - min) * f)/(PICKER_CELL_W/6);
      int vi= (int)((min + v) * 255.0);
      int vd= (int)((max - v) * 255.0);
      int maxi= (int)(max * 255.0);
      int mini= (int)(min * 255.0);
      if( vi > 255){
          vi= 255;
      }
      if( vd > 255){
          vd= 255;
      }
      if( maxi > 255){
          maxi= 255;
      }
      if( mini > 255){
          mini= 255;
      }
      switch(a){
      case 0: ttb.cpick.HSV_rgb= maxi << 16 | vi   << 8 | mini;   break;
      case 1: ttb.cpick.HSV_rgb= vd   << 16 | maxi << 8 | mini;   break;
      case 2: ttb.cpick.HSV_rgb= mini << 16 | maxi << 8 | vi;     break;
      case 3: ttb.cpick.HSV_rgb= mini << 16 | vd   << 8 | maxi;   break;
      case 4: ttb.cpick.HSV_rgb= vi   << 16 | mini << 8 | maxi;   break;
      case 5: ttb.cpick.HSV_rgb= maxi << 16 | mini << 8 | vd;     break;
      }
    }
    if( redraw ){
      redraw_item(p); //redraw color picker only if asked
    }
    if( ttb.cpick.pchosen != NULL ){
      redraw_item(ttb.cpick.pchosen); //always redraw the chosen color
    }
  }
}

static void scroll_toolbarT(struct toolbar_data *T, int x, int y, int dir )
{ //change the number of tabs not shown at the left (ignore hidden tabs)
  struct toolbar_item *t;
  int n, nt, nh, nhide;
  struct toolbar_group * G= group_fromXYT(T, x, y);
  if( G != NULL ){
    if( (G->flags & TTBF_GRP_TABBAR) != 0 ){
      //TAB-BAR (H-SCROLL)
      nhide= G->nitems_scroll;
      if((dir < 0)&&(G->nitems_scroll > 0)){
        nh= 0;
        nt= 0;
        for( t= G->list, n= G->nitems_scroll-1; (n > 0)&&(t != NULL); n-- ){
          nt++;
          if( (t->flags & TTBF_HIDDEN) == 0 ){  //not hidden
            nh= nt; //number of the previous visible tab
          }
          t= t->next;
        }
        G->nitems_scroll= nh;
      }
      if((dir > 0)&&(!G->islast_item_shown) && (G->nitems_scroll < G->nitems-1)){
        nh= G->nitems_scroll+1;  //locate next tab
        for( t= G->list, n= nh; (n > 0)&&(t != NULL); n-- ){
          t= t->next;
        }
        if( t != NULL){
          //skip hidden tabs
          while( (t != NULL) && ((t->flags & TTBF_HIDDEN) != 0) ){
            nh++;
            t= t->next;
          }
          if( t != NULL){
            G->nitems_scroll= nh;
          }
        }
      }
      if( nhide != G->nitems_scroll ){
        //update hilight
        set_hilight_off();  //clear previous hilight
        ttb.philight= item_fromXYT(T, x, y); //set new hilight
        ttb.ntbhilight= T->num;
        //update tooltip text
        set_hilight_tooltipT(T);
        //redraw the tabs
        redraw_group(G);
      }

    }else{
      t= item_fromXYT(T, x, y);
      if( t != NULL ){
        //COLOR PICKER: change HSV: V value
        if( t->back_color == BKCOLOR_PICKER ){
          color_pick_ev( t, dir, 1 );
          return;
        }
      }

      if( (G->flags & TTBF_GRP_VSCROLL) != 0 ){
        //V-SCROLL enabled
        nhide= G->yvscroll;
        if( (dir > 0) && (!G->islast_item_shown) ){
          G->yvscroll += 30;
        }else if( (dir < 0) && (G->yvscroll > 0) ){
          G->yvscroll -= 30;
          if( G->yvscroll < 0 ){
            G->yvscroll= 0;
          }
        }
        if( nhide != G->yvscroll ){
          //update hilight after scrolling
          set_hilight_off();  //clear previous hilight
          ttb.philight= item_fromXYT(T, x, y); //set new hilight
          ttb.ntbhilight= T->num;
          //update tooltip text
          set_hilight_tooltipT(T);
          //redraw the group
          redraw_group(G);
        }
      }
    }
  }
}

/* ============================================================================= */
/*                            TEXT / TOOLTIP                                     */
/* ============================================================================= */
static void set_tabtextG(struct toolbar_group *G, int ntab, const char * text, const char *tooltip, int redraw)
{
  struct toolbar_item * p;
  if( G != NULL ){
    redraw_begG(G);
    p= item_from_numG(G, ntab);
    if( p == NULL ){  //not found, add at the end
      p= add_tabG(G, ntab);
      if( p == NULL ){
        return;
      }
    }else{
      //tab found, adjust total tab width without extra space
      clear_tabwidth(p);
    }
    //update texts
    p->text= chg_alloc_str(p->text, text);
    p->tooltip= chg_alloc_str(p->tooltip, tooltip);
    p->barx1= 0;
    p->bary1= 0;
    p->prew= get_group_imgW(G,TTBI_TB_NTAB1);
    p->postw= get_group_imgW(G,TTBI_TB_NTAB3);
    p->imgx=  p->prew;	//text start
    p->imgy=  G->tabtexty;
    p->bary2= get_group_imgH(G,TTBI_TB_NTAB1);
    p->textwidth= 0;
    set_tabwidth(p);
    //group size changed, update toolbar
    update_group_sizeG(G, redraw);
  }
}

static void clear_tooltip_textT( struct toolbar_data *T )
{
  gtk_widget_set_tooltip_text(T->draw, "");
}

static void set_hilight_tooltipT( struct toolbar_data *T )
{ //update tooltip text
  char *tooltip= "";
  if( (ttb.philight != NULL) && (ttb.ntbhilight == T->num) ){
    if(ttb.philight->tooltip != NULL){
      tooltip= ttb.philight->tooltip;
    }
  }
  gtk_widget_set_tooltip_text(T->draw, tooltip);
}

static void set_hilight_off( void )
{ //force hilight off (in any toolbar)
  struct toolbar_item * p;
  p= ttb.philight;
  if( (p != NULL) && (ttb.ntbhilight >= 0) ){
    ttb.philight= NULL;
    ttb.phipress= NULL;
    redraw_item( p );
    ttb.ntbhilight= -1;
  }
}

static double rgb2double(int color)
{
  return ((double)(color & 0x0FF))/255.0;
}

static void setrgbcolor(int rgb, struct color3doubles *pc)
{
  pc->R= rgb2double(rgb >> 16);
  pc->G= rgb2double(rgb >> 8);
  pc->B= rgb2double(rgb);
}

static void ttb_show_groupG( struct toolbar_group *G, int show )
{
  int f;
  if( G != NULL ){
    redraw_begG(G);
    f= G->flags;
    if( show ){
      f &= ~TTBF_HIDDEN;
    }else{
      f |= TTBF_HIDDEN;
    }
    if( f != G->flags ){
      G->flags= f;
      //layout changed, redraw the complete toolbar
      G->toolbar->_layout_chg= 1;
      //group size changed, update toolbar
      update_group_sizeG(G, 1);
    }
  }
}

/* ============================================================================= */
/*                            TOOLBAR                                            */
/* ============================================================================= */
static void ttb_new_toolbar(int num, int barsize, int buttonsize, int imgsize, const char *imgpath)
{ //reset toolbar content and start a new one
  struct toolbar_data *T;
  struct toolbar_group *G;
  char str[32];
  int i;

  T= toolbar_from_num(num);
  if( T != NULL ){
    //destroy all existing groups in toolbar
    free_toolbar_num(num);
    //set as current toolbar
    ttb.currentntb= num;
    //set size
    if( T->isvertical ){
      T->barwidth= barsize;
      T->barheight= -1;
    }else{
      T->barwidth= -1;
      T->barheight= barsize;
    }
    //change global image base
    if( imgpath != NULL ){
      ttb.img_base= chg_alloc_str(ttb.img_base, imgpath);
    }
    //set default toolbar images
    set_toolbar_img( T, TTBI_TB_HILIGHT,   "ttb-back-hi");
    set_toolbar_img( T, TTBI_TB_HIPRESSED, "ttb-back-press");
    if( T->isvertical ){
      set_toolbar_img( T, TTBI_TB_SEPARATOR, "ttb-hsep" );
    }else{
      set_toolbar_img( T, TTBI_TB_SEPARATOR, "ttb-vsep" );
    }

    //3 images per tab state: beginning, middle, end
    strcpy( str, "ttb-#tab#" );
    for( i= 0; i < 3; i++){
      str[8]= '1'+i;
      str[4]= 'n';
      set_toolbar_img( T, TTBI_TB_NTAB1+i, str ); //normal
      str[4]= 'd';
      set_toolbar_img( T, TTBI_TB_DTAB1+i, str ); //disabled
      str[4]= 'h';
      set_toolbar_img( T, TTBI_TB_HTAB1+i, str ); //hilight
      str[4]= 'a';
      set_toolbar_img( T, TTBI_TB_ATAB1+i, str ); //active
    }
    //set_toolbar_img( T, TTBI_TB_TABBACK, "ttb-tab-back" );   //tab background
    set_toolbar_img( T, TTBI_TB_TAB_NSL,    "ttb-tab-sl"    ); //normal tab scroll left
    set_toolbar_img( T, TTBI_TB_TAB_NSR,    "ttb-tab-sr"    ); //normal tab scroll right
    set_toolbar_img( T, TTBI_TB_TAB_HSL,    "ttb-tab-hsl"   ); //hilight tab scroll left
    set_toolbar_img( T, TTBI_TB_TAB_HSR,    "ttb-tab-hsr"   ); //hilight tab scroll right
    set_toolbar_img( T, TTBI_TB_TAB_NCLOSE, "ttb-tab-close" ); //normal close button
    set_toolbar_img( T, TTBI_TB_TAB_HCLOSE, "ttb-tab-hclose"); //hilight close button
    set_toolbar_img( T, TTBI_TB_TAB_CHANGED,"ttb-tab-chg"   ); //change indicator

    //3 images per text-button state: beginning, middle, end
    set_toolbar_img( T, TTBI_TB_TXT_HIL1, "ttb-back-hi1" );    //hilight
    set_toolbar_img( T, TTBI_TB_TXT_HIL2, "ttb-back-hi2" );
    set_toolbar_img( T, TTBI_TB_TXT_HIL3, "ttb-back-hi3" );
    set_toolbar_img( T, TTBI_TB_TXT_HPR1, "ttb-back-press1" ); //hi-pressed
    set_toolbar_img( T, TTBI_TB_TXT_HPR2, "ttb-back-press2" );
    set_toolbar_img( T, TTBI_TB_TXT_HPR3, "ttb-back-press3" );

    //set defaults
    T->buttonsize= buttonsize;
    T->imgsize= imgsize;
    T->back_color= BKCOLOR_NOT_SET;
    //auto-create the first group
    G= add_groupT(T, TTBF_GRP_AUTO);
    gtk_widget_set_size_request(T->draw, T->barwidth, T->barheight);
  }
}

/* ==== BUTTONS ==== */

static void ttb_change_button_imgT(struct toolbar_data *T, const char *name, int nimg, const char *img )
{
  if( strcmp(name, "TOOLBAR") == 0 ){
    if( set_toolbar_img( T, nimg, img ) ){
      redraw_toolbar(T);
    }
  }else if( strcmp(name, "GROUP") == 0 ){
    if( set_group_img( T->curr_group, nimg, img ) ){
      redraw_group(T->curr_group);
    }
  }else{
    struct toolbar_item * p= item_from_nameT(T, name);
    if( p != NULL ){
      if( set_item_img( p, nimg, img ) ){
        redraw_item(p);
      }
    }
  }
}

static void ttb_set_back_colorT(struct toolbar_data *T, const char *name, int color, int keepback )
{
  if( strcmp(name, "TOOLBAR") == 0 ){
    T->back_color= color;
    if( !keepback ){
      set_toolbar_img( T, TTBI_TB_BACKGROUND, NULL );
    }
    redraw_toolbar(T);
  }else if( strcmp(name, "GROUP") == 0 ){
    if( T->curr_group != NULL ){
      T->curr_group->back_color= color;
      if( !keepback ){
        set_group_img( T->curr_group, TTBI_TB_BACKGROUND, NULL );
      }
      redraw_group(T->curr_group);
    }
  }else{
    struct toolbar_item * p= item_from_nameT(T, name);
    if( p != NULL ){
      p->back_color= color;
      if( color == BKCOLOR_SEL_COLOR ){
        ttb.cpick.pchosen= p; //update this item when the chosen color changes
      }else if( ttb.cpick.pchosen == p ){
        ttb.cpick.pchosen= NULL;
      }
      redraw_item(p);
    }
  }
}

static void ttb_change_button_tooltipT(struct toolbar_data *T, const char *name, const char *tooltip )
{
  struct toolbar_item * p= item_from_nameT(T, name);
  if( p != NULL ){
    p->tooltip= chg_alloc_str(p->tooltip, tooltip);
    //redraw_item(p); //redraw button
  }
}

static void ttb_change_button_textT(struct toolbar_data *T, const char *name, const char *text )
{
  int dif;
  struct toolbar_item * p= item_from_nameT(T, name);
  struct toolbar_group * G;
  if( p != NULL ){
    G= p->group;
    p->text= chg_alloc_str(p->text, text);
    dif= set_text_bt_width(p);
    if( dif != 0){
      redraw_begG(G);
      //button width changed, update all buttons to the right
      p= p->next;
      while( p != NULL ){
        p->barx1 += dif;
        p->barx2 += dif;
        p->imgx += dif;
        p= p->next;
      }
      //group size changed, update toolbar
      update_group_sizeG(G, 1); //redraw
    }else{
      //same width
      redraw_item(p);
    }
  }
}

static void ttb_set_text_fontcolG(struct toolbar_group *G, int fntsz, int fntyoff, int ncol, int gcol)
{
  if( G != NULL ){
    G->txtfontsz= fntsz;  //font size in points (default = 12 points)
    if( G->txtfontsz < 2){
      G->txtfontsz= 12;
    }
    /* TO DO: new font size= check buttons width */
    G->txttextoff= fntyoff;
    setrgbcolor( ncol, &G->txttextcolN);  //normal color
    setrgbcolor( gcol, &G->txttextcolG);  //grayed color
    //redraw the complete group
    redraw_group(G);
  }
}

static void ttb_enable_buttonT(struct toolbar_data *T, const char * name, int isenabled )
{
  int flg;
  struct toolbar_item * p= item_from_nameT(T, name);
  if( p != NULL){
    flg= p->flags;
    if( isenabled ){
      p->flags= (flg & ~TTBF_GRAYED) | TTBF_SELECTABLE;
    }else{
      p->flags= (flg & ~TTBF_SELECTABLE) | TTBF_GRAYED;
    }
    if( flg != p->flags ){
      redraw_item(p);
    }
  }
}

static void ttb_addspaceG(struct toolbar_group * G, int sepsize, int hide)
{
  struct toolbar_item * p;
  int asep;
  if( G != NULL ){
    redraw_begG(G);
    if( G->isvertical ){
      if( sepsize == 0 ){
        sepsize= G->bheight/2;
      }
      if( !hide ){
        //show H separator in the middle
        p= add_itemG(G, NULL, get_group_img(G,TTBI_TB_SEPARATOR)->fname, NULL, NULL, 0);
        if( p != NULL ){
          asep= get_group_imgH(G,TTBI_TB_SEPARATOR); //minimun separator = image height
          if( sepsize < asep ){
            sepsize= asep;
          }
          G->ynew -= G->bheight;
          p->imgx= G->xnew;
          p->imgy= G->ynew + ((sepsize - asep)/2);
          p->bary2= G->ynew + sepsize;
        }
      }
      G->ynew += sepsize;
    }else{
      if( sepsize == 0 ){
        sepsize= G->bwidth/2;
      }
      if( !hide ){
        //show V separator in the middle
        p= add_itemG(G, NULL, get_group_img(G,TTBI_TB_SEPARATOR)->fname, NULL, NULL, 0);
        if( p != NULL ){
          asep= get_group_imgW(G,TTBI_TB_SEPARATOR); //minimun separator = image width
          if( sepsize < asep ){
            sepsize= asep;
          }
          G->xnew -= G->bwidth;
          p->imgx= G->xnew + ((sepsize - asep)/2);
          p->imgy= G->ynew;
          p->barx2= G->xnew + sepsize;
        }
      }
      G->xnew += sepsize;
    }
    //group size changed, update toolbar
    update_group_sizeG(G, 1); //redraw
  }
}

/* ==== TABS ==== */

static void ttb_new_tabs_groupT(struct toolbar_data *T, int xmargin, int xsep, int wclose, int modshow,
  int fntsz, int fntyoff, int wdrag, int xcontrol, int height)
{
  cairo_t * cr;
  cairo_text_extents_t ext;
  struct toolbar_group *G;
  int i, rgb, flags;

  if( T != NULL ){
    //create a new tab-bar group and set as current
    G= add_groupT_rcoh(T, xcontrol, 0, 0);
    T->tab_group= G;
    if( G != NULL ){
      redraw_begG(G);
      G->flags |= TTBF_GRP_TABBAR;    //it's a tabbar group
      if( wdrag ){
        G->flags |= TTBF_GRP_DRAGTAB; //enable drag support
      }
      G->tabxmargin= xmargin;
      G->tabxsep= xsep;

      G->tabmodshow= modshow;

      G->tabfontsz= fntsz;  //font size in points (default = 10 points)
      if( G->tabfontsz < 2){
        G->tabfontsz= 10;
      }
      cr= gdk_cairo_create(T->draw->window);
      cairo_set_font_size(cr, G->tabfontsz);
      cairo_text_extents( cr, "H", &ext );
      G->tabtexth= (int) ext.height;
      cairo_destroy(cr);

      G->tabtextoff= fntyoff;
      //center text verticaly + offset
      G->tabtexty=  ((get_group_imgH(G,TTBI_TB_NTAB1) + G->tabtexth)/2)+G->tabtextoff;
      if( G->tabtexty < 0){
        G->tabtexty= 0;
      }
      G->bary1= 0;
      G->tabheight= G->tabtexth; //use the tallest image or text
      for(i= TTBI_TB_TABBACK; i <= TTBI_TB_ATAB3; i++ ){
        if( G->tabheight < get_group_imgH(G,i) ){
          G->tabheight= get_group_imgH(G,i);
        }
      }
      if( height == 0 ){
        G->bary2= G->bary1 + G->tabheight;
      }else{
        G->bary2= G->bary1 + height;
      }
      G->closeintabs= wclose;
      //group size changed, update toolbar
      update_group_sizeG(G, 1); //redraw
    }
  }
}

static void ttb_set_tab_colorsG(struct toolbar_group *G, int ncol, int hcol, int acol, int mcol, int gcol)
{
  if( G != NULL ){
    setrgbcolor( ncol, &G->tabtextcolN);  //normal   color
    setrgbcolor( hcol, &G->tabtextcolH);  //hilight  color
    setrgbcolor( acol, &G->tabtextcolA);  //active   color
    setrgbcolor( mcol, &G->tabtextcolM);  //modified color
    setrgbcolor( gcol, &G->tabtextcolG);  //grayed   color
    //redraw the complete group
    redraw_group(G);
  }
}

static void ttb_activate_tabG(struct toolbar_group *G, int ntab)
{
  struct toolbar_item *p, *t, *vistab;
  struct toolbar_data *T;
  int x, nhide, tabpos, n;

  if( G == NULL ){
    return;
  }
  T= G->toolbar;
  redraw_begG(G);
  t= NULL;
  tabpos= 0;
  n= 0;
  for( p= G->list; (p != NULL); p= p->next ){
    if( p->num == ntab){
      p->flags |= TTBF_ACTIVE | TTBF_SELECTABLE;
      p->flags &= ~TTBF_GRAYED;
      t= p;
      tabpos= n;
    }else{
      p->flags &= ~TTBF_ACTIVE; //only one tab can be active
    }
    n++;
  }
  //check tab visibility (ignore this tab if hidden)
  if((t != NULL) && (G != NULL) && (G->barx2 > 0) && ((t->flags & TTBF_HIDDEN) == 0)){
    x= G->barx1 + G->tabxmargin;
    for( p= G->list, nhide= G->nitems_scroll; (nhide > 0)&&(p != NULL); nhide-- ){
      if( p->num == ntab ){
        //the tab is left-hidden,
        //force "no scroll" to move this tab to the rightmost position
        if( ttb.ntbhilight == T->num ){
          set_hilight_off(); //force hilight off (in this toolbar only)
        }
        clear_tooltip_textT(T);
        G->nitems_scroll= 0; //
        p= G->list;
        break;
      }
      p= p->next; //skip hidden tabs
    }
    vistab= p;    //first visible tab
    if( t != NULL ){
      if( ((p->num == ntab) || (G->try_scrollpack)) && (G->nitems_scroll > 0) ){
        //is the first visible tab or a tab was deleted: try to remove the left scroll button
        G->nitems_scroll= 0; //force "no scroll" to move this tab to the rightmost position
        p= G->list;
        vistab= p;    //first visible tab
      }
      G->try_scrollpack= 0; //clear pack flag

      for( ; (p != NULL); p= p->next ){
        if( (p->flags & TTBF_HIDDEN) == 0 ){
          if( x > G->barx2 ){
            break;  //the rest of the tabs are right-hidden
          }
          if( p->num == ntab ){
            //check if it's completely visible
            if( x+t->barx2 <= G->barx2 ){
              t= NULL;  //visible, nothing to do
            }
            break;  //some part of the tab is hidden
          }
          x += p->barx2 + G->tabxsep;
        }
      }
    }
    if( t != NULL ){
      //at least a part of the tab is right-hidden
      for( ; (p != NULL); p= p->next ){
        if( (p->flags & TTBF_HIDDEN) == 0 ){
          x += p->barx2;
          if( p->num == ntab ){
            break;
          }
          x += G->tabxsep;
        }
      }
      //hide some tabs until the tab is completely visible
      while( (vistab != NULL) && (x > G->barx2) ){
        if( (vistab->flags & TTBF_HIDDEN) == 0 ){
          x -= vistab->barx2 + G->tabxsep;
        }
        vistab= vistab->next;
        G->nitems_scroll++;
      }
      if( vistab == NULL ){
        //not enought space to be completely visible
        //set as the first visible tab
        G->nitems_scroll= tabpos;
      }
      if( ttb.ntbhilight == T->num ){
          set_hilight_off(); //force hilight off (in this toolbar only)
      }
      clear_tooltip_textT(T);
    }
  }
  //redraw the group/toolbar
  redraw_endG(G);
}

static void ttb_enable_tabG(struct toolbar_group *G, int ntab, int enable)
{
  struct toolbar_item * p= item_from_numG(G, ntab);
  if( p != NULL ){
    if( enable ){
      p->flags &= ~TTBF_GRAYED;
      p->flags |= TTBF_SELECTABLE;
    }else{
      p->flags |= TTBF_GRAYED;
      p->flags &= ~(TTBF_ACTIVE | TTBF_SELECTABLE);
    }
    redraw_group(G);
  }
}

static void ttb_hide_tabG(struct toolbar_group *G, int ntab, int hide)
{
  if( G != NULL ){
    redraw_begG(G);
    struct toolbar_item * p= item_from_numG(G, ntab);
    if( p != NULL ){
      if( hide ){
        if( ((p->flags & TTBF_HIDDEN) == 0) ){
          clear_tabwidth(p);
          p->flags |= TTBF_HIDDEN;
          G->nitems_nothidden--;
          //group size changed, update toolbar
          update_group_sizeG(G, 1); //redraw
        }
      }else{
        if( (p->flags & TTBF_HIDDEN) != 0 ){
          p->flags &= ~TTBF_HIDDEN;
          G->nitems_nothidden++;
          set_tabwidth(p);
          //group size changed, update toolbar
          update_group_sizeG(G, 1); //redraw
        }
      }
    }
  }
}

static void ttb_change_tabwidthG(struct toolbar_group *G, int ntab, int percwidth, int minwidth, int maxwidth )
{
  struct toolbar_item * p= item_from_numG(G, ntab);
  if( p != NULL ){
    redraw_begG(G);
    if( p->changewidth < 0 ){
      G->nitems_expand--;
    }
    clear_tabwidth(p);
    //set new change width min, max and mode: 0:text width, >0:fixes, <0:porcent
    p->changewidth= percwidth;
    if( percwidth > 0 ){
      //fixed width, ignore minimum and maximum
      p->minwidth= 0;
      p->maxwidth= 0;
    }else{
      //variable width
      p->minwidth= minwidth;
      p->maxwidth= maxwidth;
      if( percwidth < 0 ){
        G->nitems_expand++;
      }
    }
    set_tabwidth(p);
    //group size changed, update toolbar
    update_group_sizeG(G, 1); //redraw

  }else if( ntab <= 0 ){
    //invalid tab, change toolbar defaults
    G->tabchangewidth= percwidth;
    if( percwidth > 0 ){
      //fixed width, ignore minimum and maximum
      G->tabminwidth= 0;
      G->tabmaxwidth= 0;
    }else{
      G->tabminwidth= minwidth;
      G->tabmaxwidth= maxwidth;
    }
  }
}

static void ttb_set_changed_tabG(struct toolbar_group *G, int ntab, int changed)
{
  struct toolbar_item * p= item_from_numG(G, ntab);
  if( p != NULL ){
    if( changed ){
      p->flags |= TTBF_CHANGED;
    }else{
      p->flags &= ~TTBF_CHANGED;
    }
    redraw_group(G);
  }
}

static void ttb_delete_tabG(struct toolbar_group *G, int ntab)
{
  struct toolbar_item *k, *kprev, *p;
  k= item_from_numG(G, ntab);
  if( k != NULL ){
    redraw_begG(G);
    kprev= find_prev_itemG( G, k );
    if( k == G->list_last ){
      //the last tab will be deleted, choose the previous as the new "last"
      G->list_last= kprev;
    }
    //disconect tab-node
    if( kprev == NULL ){
      G->list= k->next;
    }else{
      kprev->next= k->next;
    }
    G->nitems--;
    if( (k->flags & TTBF_HIDDEN) == 0 ){
      G->nitems_nothidden--;
      if( k->changewidth < 0 ){
        G->nitems_expand--;
      }
      clear_tabwidth(k);
    }
    //after tab delete, try to remove the left scroll button when a new tab is activated
    if( G->nitems_scroll > 0 ){
      G->try_scrollpack= 1;
    }
    if(ttb.ntbhilight == G->toolbar->num){
      if( (ttb.philight == k) || (ttb.phipress == k) ){
        ttb.philight= NULL;
        ttb.phipress= NULL;
        ttb.ntbhilight= -1;
      }
    }
    free_item_node(k);
    //group size changed, update toolbar
    update_group_sizeG(G, 1); //redraw
  }
}

static void ttb_goto_tabG(struct toolbar_group *G, int tabpos)
{  //generate a click in tab: -1:prev,1:next,0:first,2:last
  struct toolbar_item *p, *pcurr;
  p= NULL;
  if( G != NULL ){
    //find the current active tab
    for( pcurr= G->list; (pcurr != NULL); pcurr= pcurr->next ){
      if( (pcurr->flags & TTBF_ACTIVE) != 0 ){
        break;
      }
    }
    if( tabpos == 1 ){
      //next visible tab
      if( pcurr != NULL ){
        p= pcurr->next;
        while( (p != NULL) && ((p->flags & TTBF_HIDDEN) != 0) ){
          p= p->next; //skip hidden tabs
        }
      }
      if( p == NULL ){
        tabpos= 0; //activate the first one
      }
    }else if( tabpos == -1 ){
      //prev visible tab
      if( pcurr != NULL ){
        p= find_prev_itemG( G, pcurr );
        while( (p != NULL) && ((p->flags & TTBF_HIDDEN) != 0) ){
          p= find_prev_itemG( G, p ); //skip hidden tabs
        }
      }
      if( p == NULL ){
        tabpos= 2; //activate the last one
      }
    }
    if( tabpos == 0 ){
      //first visible tab
      for( p= G->list; (p != NULL); p= p->next ){
        if( (p->flags & TTBF_HIDDEN) == 0 ){
          break;
        }
      }
    }else if( tabpos == 2 ){
      //last visible tab
      p= G->list_last;
      while( (p != NULL) && ((p->flags & TTBF_HIDDEN) != 0) ){
        p= find_prev_itemG( G, p ); //skip hidden tabs
      }
    }
    if( (p != NULL) && (p != pcurr) ){
      lL_event(lua, "toolbar_tabclicked", LUA_TNUMBER, p->num, LUA_TNUMBER, G->toolbar->num, -1);
    }
  }
}

/* ============================================================================= */
/*                                   DRAW                                        */
/* ============================================================================= */
static void draw_img( cairo_t *ctx, struct toolbar_img *pti, int x, int y, int grayed )
{
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

static void draw_fill_color( cairo_t *ctx, int color, int x, int y, int w, int h )
{
  struct color3doubles c;
  int i, j, xr, yr, dx, dy, a, hp;
  double v, min, max, dv;

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
      if( ttb.cpick.HSV_val < 0.7 ){
        c.R= 1;
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
    if( color == BKCOLOR_SEL_COLOR ){
      color= ttb.cpick.HSV_rgb; //choosen color in HSV color picker
    }
    //solid color
    setrgbcolor( color, &c );
    cairo_set_source_rgb(ctx, c.R, c.G, c.B );
    cairo_rectangle(ctx, x, y, w, h);
    cairo_fill(ctx);
  }
}

static void draw_fill_img( cairo_t *ctx, struct toolbar_img *pti, int x, int y, int w, int h )
{
  if( pti->fname != NULL ){
    cairo_surface_t *img= cairo_image_surface_create_from_png(pti->fname);
    if( img != NULL ){
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

static void draw_txt( cairo_t *ctx, const char *txt, int x, int y, int y1, int w, int h, struct color3doubles *color, int fontsz, int bold )
{
  if( txt != NULL ){
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

static void draw_tabG(struct toolbar_group *G, cairo_t *cr, struct toolbar_item *t, int x, int y)
{
  int h, hc, x3;
  struct color3doubles *color= &(G->tabtextcolN);
  h= TTBI_TB_NTAB1;
  hc= TTBI_TB_TAB_NCLOSE;
  if( G->closeintabs ){
    if( (ttb.philight != NULL) && (ttb.ntbhilight == G->toolbar->num) && ((ttb.philight->flags & TTBF_CLOSETAB_BUT) != 0) ){
      //a tab close button is hilited, is from this tab?
      if( ttb.philight->num == t->num ){
        hc= TTBI_TB_TAB_HCLOSE;  //hilight close tab button
        h=  TTBI_TB_HTAB1;       //and tab
        color= &(G->tabtextcolH);
      }
    }
  }
  if( (t->flags & TTBF_ACTIVE) != 0 ){
    h= TTBI_TB_ATAB1;
    color= &(G->tabtextcolA);

  }else if( (t->flags & TTBF_GRAYED) != 0 ){
    h= TTBI_TB_DTAB1;
    color= &(G->tabtextcolG);

  }else if( (t == ttb.philight)&&((ttb.phipress == NULL)||(ttb.phipress == t)) ){
    h= TTBI_TB_HTAB1;
    color= &(G->tabtextcolH);
  }
  draw_img(cr, get_group_img(G,h), x, y, 0 );
  draw_fill_img(cr, get_group_img(G,h+1), x+t->prew, y,
      t->barx2 - t->prew - t->postw, get_group_imgH(G,TTBI_TB_NTAB2) );

  x3= x + t->barx2 - t->postw;
  draw_img(cr, get_group_img(G,h+2), x3, y, 0 );
  if( (t->flags & TTBF_CHANGED) != 0 ){
    if( G->tabmodshow == 1 ){
      draw_img(cr, get_group_img(G,TTBI_TB_TAB_CHANGED), x3, y, 0 );
    }else if( G->tabmodshow == 2 ){
      color= &(G->tabtextcolM);
    }
  }
  if( G->closeintabs ){
    draw_img(cr, get_group_img(G,hc), x3, y, 0 );
  }

  draw_txt(cr, t->text, x+t->imgx, y+t->imgy, y, x3-x-t->imgx, get_group_imgH(G,TTBI_TB_NTAB2), color, G->tabfontsz, 0 );
}

/* ============================================================================= */
/*                                EVENTS                                         */
/* ============================================================================= */

static int need_redraw(GdkEventExpose *event, int x, int y, int xf, int yf)
{
  int x0, y0, x1, y1;
  //area to paint
  x0= event->area.x;
  y0= event->area.y;
  x1= x0 + event->area.width;
  y1= y0 + event->area.height;
  return ((x <= x1) && (y <= y1) && (xf >= x0) && (yf >= y0));
}

static void ttb_size_ev(GtkWidget *widget, GdkRectangle *prec, void*__)
{
  UNUSED(__);
  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T != NULL ){
    T->barwidth= prec->width;
    T->barheight= prec->height;
    //toolbar size changed, adjust groups layout
    update_layoutT(T);
  }
}

static gboolean ttb_paint_ev(GtkWidget *widget, GdkEventExpose *event, void*__)
{
  UNUSED(__);
  struct toolbar_item *p, *phi, *t, *ta;
  int h, grayed, x, y, xa, nhide, x0, y0, x1, wt, ht, hibackpainted;
  struct color3doubles *color;
  struct toolbar_group *g;
  struct toolbar_img * bback;

  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T == NULL ){
    return FALSE;
  }
  hibackpainted= 0;

  if( (T->barwidth < 0) || (T->barheight < 0) ){
    T->barwidth=  widget->allocation.width;
    T->barheight= widget->allocation.height;
    //toolbar size changed, adjust groups layout
    update_layoutT(T);
  }

  cairo_t *cr = gdk_cairo_create(widget->window);
  //paint toolbar back color if set
  draw_fill_color(cr, T->back_color, 0, 0, T->barwidth, T->barheight );
  //draw toolbar background image (if any)
  draw_fill_img(cr, get_toolbar_img(T,TTBI_TB_BACKGROUND), 0, 0, T->barwidth, T->barheight );
  //draw groups back color / background (if any)
  for( g= T->group; (g != NULL); g= g->next ){
    if( (g->flags & (TTBF_HIDDEN|TTBF_GRP_TABBAR)) == 0 ){
      if( need_redraw( event, g->barx1, g->bary1, g->barx2, g->bary2) ){
        x0= g->barx1;
        y0= g->bary1;
        wt= g->barx2 - g->barx1;
        ht= g->bary2 - g->bary1;
        //paint back color if set
        draw_fill_color(cr, g->back_color, x0, y0, wt, ht );
        //draw background image (if any)
        if(g->img[TTBI_TB_BACKGROUND].width > 0){
          draw_fill_img(cr, get_group_img(g,TTBI_TB_BACKGROUND), x0, y0, wt, ht );
        }
      }
    }
  }

  //draw hilighted background (before drawing buttons)
  phi= NULL;
  if( ttb.ntbhilight == T->num ){
    phi= ttb.philight;
  }
  if( (phi != NULL) && ((phi->flags & (TTBF_TAB|TTBF_SCROLL_BUT|TTBF_CLOSETAB_BUT))==0) ){
    g= phi->group;
    x0= g->barx1;
    y0= g->bary1 - g->yvscroll;
    x= x0+phi->barx1;
    y= y0+phi->bary1;
    if( (y >= 0) && (need_redraw(event, x, y, x0+phi->barx2, y0+phi->bary2)) && (phi->back_color != BKCOLOR_PICKER) ){
      h= -1;
      if(ttb.phipress == phi){
        h= TTBI_HIPRESSED; //hilight as pressed
      }else if(ttb.phipress == NULL){
        h= TTBI_HILIGHT; //normal hilight (and no other button is pressed)
      }
      if( h >= 0){
        hibackpainted= 1;
        //paint back color if set
        draw_fill_color(cr, phi->back_color, x, y, phi->barx2-phi->barx1, phi->bary2-phi->bary1 );
        if( (phi->flags & TTBF_TEXT) == 0 ){
          //graphic button
          draw_img(cr, get_item_img(phi,h), x, y, 0 );
        }else{
          //text button
          if( h == TTBI_HILIGHT ){
            h= TTBI_TB_TXT_HIL1;  //normal hilight
          }else{
            h= TTBI_TB_TXT_HPR1;  //hilight as pressed
          }
          draw_img(cr, get_group_img(g,h), x, y, 0 );
          x += phi->prew;
          xa= x0 + phi->barx2 - phi->postw;
          draw_fill_img(cr, get_group_img(g,h+1), x, y, xa-x, get_group_imgH(g,h) );
          draw_img(cr, get_group_img(g,h+2), xa, y, 0 );
        }
      }
    }
  }

  //draw all visible groups
  for( g= T->group; (g != NULL); g= g->next ){
    if( (g->flags & TTBF_HIDDEN) == 0 ){
      x0= g->barx1;
      y0= g->bary1;
      if( need_redraw( event, x0, y0, g->barx2, g->bary2) ){
        wt= g->barx2 - g->barx1;
        ht= g->bary2 - g->bary1;
        cairo_save(cr);
        cairo_rectangle(cr, x0, y0, wt, ht );
        cairo_clip(cr);
        //draw group items
        if( (g->flags & TTBF_GRP_TABBAR) != 0){
          //tab-bar
          draw_fill_img(cr, get_group_img(g,TTBI_TB_TABBACK), x0, y0, wt, ht );
          ta= NULL;
          xa= 0;
          x= x0 + g->tabxmargin;
          y= y0;
          for( t= g->list, nhide= g->nitems_scroll; (nhide > 0)&&(t != NULL); nhide-- ){
            t= t->next; //skip hidden tabs (scroll support)
          }
          for( ; (t != NULL); t= t->next ){
            if( (t->flags & TTBF_HIDDEN) == 0 ){  //skip hidden tabs
              if( need_redraw( event, x, y, x+t->barx2, y+t->bary2) ){
                if( (t->flags & TTBF_ACTIVE) != 0 ){
                  ta= t;
                  xa= x;
                }else{
                  draw_tabG( g, cr, t, x, y );
                }
              }
              x += t->barx2 + g->tabxsep;
            }
          }
          g->islast_item_shown= (g->barx2 >= x );
          //draw the active tab over the other tabs
          if( ta != NULL ){
            draw_tabG( g, cr, ta, xa, y );
          }
          g->scleftx1= -1;
          g->scrightx1= -1;
          //draw scroll indicator over the tabs
          if( g->nitems_scroll > 0 ){
            h= TTBI_TB_TAB_NSL;
            if( (phi != NULL)&&(phi==ttb.phipress)&&(phi->flags==TTBF_SCROLL_BUT)&&(phi->num==-1)){
              h= TTBI_TB_TAB_HSL;
            }
            g->scleftx1= x0; //+ g->tabxmargin;
            g->scleftx2= g->scleftx1 + get_group_imgW(g,h);
            g->sclefty1= y0;
            g->sclefty2= y0 + get_group_imgH(g,h);
            draw_img(cr, get_group_img(g,h), g->scleftx1, g->sclefty1, 0 );
          }
          if( !g->islast_item_shown ){
            h= TTBI_TB_TAB_NSR;
            if( (phi != NULL)&&(phi==ttb.phipress)&&(phi->flags==TTBF_SCROLL_BUT)&&(phi->num==1)){
              h= TTBI_TB_TAB_HSR;
            }
            g->scrightx2= g->barx2;
            g->scrightx1= g->scrightx2 - get_group_imgW(g,h);
            g->scrighty1= y0;
            g->scrighty2= y0 + get_group_imgH(g,h);
            draw_img(cr, get_group_img(g,h), g->scrightx1, g->scrighty1, 0 );
          }

        }else{
          //buttons
          y0 -= g->yvscroll;  //vertical scroll support
          g->islast_item_shown= 1;
          for( p= g->list; (p != NULL); p= p->next ){
            x= x0 + p->imgx;
            y= y0 + p->imgy;
            if( (y0+p->bary2) > T->barheight ){
              g->islast_item_shown= 0;
              break;
            }
            if( (y0+p->bary1 >= 0) && need_redraw( event, x0+p->barx1, y0+p->bary1, x0+p->barx2, y0+p->bary2) ){
              h= TTBI_NORMAL;
              grayed= 0;
              //paint back color / background if set and wasn't painted by highlight
              if( (phi != p) || (!hibackpainted) ){
                draw_fill_color(cr, p->back_color, x0+p->barx1, y0+p->bary1, p->barx2-p->barx1, p->bary2-p->bary1 );
                //draw a normal button background if the button is selectable
                if( (p->flags & TTBF_SELECTABLE) != 0 ){
                  if( (p->flags & TTBF_TEXT) == 0 ){
                    //graphic button
                    draw_img(cr, get_group_img(g,TTBI_TB_HINORMAL), x0+p->barx1, y0+p->bary1, 0 );
                  }else{
                    //text button
                    h= TTBI_TB_TXT_NOR1;
                    if( get_group_imgW(g,h) > 0 ){
                      draw_img(cr, get_group_img(g,h), x0+p->barx1, y0+p->bary1, 0 );
                      x1= x0 + p->barx1 + p->prew;
                      xa= x0 + p->barx2 - p->postw;
                      draw_fill_img(cr, get_group_img(g,h+1), x1, y0+p->bary1, xa-x1, get_group_imgH(g,h) );
                      draw_img(cr, get_group_img(g,h+2), xa, y0+p->bary1, 0 );
                    }
                  }
                }
              }
              if( (p->flags & TTBF_TEXT) == 0 ){
                //graphic button
                if( (p->flags & TTBF_GRAYED) != 0){
                  if( get_item_img(p,TTBI_DISABLED)->fname != NULL ){
                    h= TTBI_DISABLED;
                  }else{
                    grayed= 1; //there is no disabled image, gray it
                  }
                }
                draw_img(cr, get_item_img(p,h), x, y, grayed );
              }else{
                //text button
                color= &(g->txttextcolN);
                if( (p->flags & TTBF_GRAYED) != 0){
                  color= &(g->txttextcolG);
                }
                if( (p->flags & TTBF_TEXT_LEFT) != 0){
                  x= x0 + p->barx1 + p->prew; //text is left aligned
                }
                xa= x0 + p->barx2 - p->postw;
                draw_txt(cr, p->text, x, y, y0+p->bary1, xa - x, p->bary2 - p->bary1, color, g->txtfontsz, (p->flags & TTBF_TEXT_BOLD) );
              }
            }
          }
        }
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
  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T != NULL ){
    if( (ttb.philight != NULL) && (ttb.ntbhilight == T->num) ){
      //force hilight and tooltip OFF (in this toolbar only)
      set_hilight_off();
      clear_tooltip_textT(T);
    }
  }
  return FALSE;
}

static gboolean ttb_mousemotion_ev( GtkWidget *widget, GdkEventMotion *event )
{
  int x, y, nx, xhi, ok;
  GdkModifierType state;
  struct toolbar_item * p, *prev;
  struct toolbar_group *G;

  struct toolbar_data *T= toolbar_from_widget(widget);
  if( T == NULL ){
    return FALSE;
  }

  if(event->is_hint){
    gdk_window_get_pointer(event->window, &x, &y, &state);
  }else{
    x = event->x;
    y = event->y;
    state = event->state;
  }
//  if( (state & GDK_BUTTON1_MASK) == 0 ){
//    if( ttb.phipress != NULL ) //mouse release event lost or coming?
//  }
  p= item_fromXYT(T, x, y);
  if( p != ttb.philight ){
    //hilight changed
    if( (p != NULL) && (ttb.phipress != NULL) && ((p->group->flags & TTBF_GRP_DRAGTAB) != 0) &&
        (p != ttb.phipress) && ((p->flags & TTBF_TAB) != 0) && (ttb.phipress->group == p->group) ){
      //drag tab from "ttb.phipress" to "p" position (in the SAME tab group)
      G= p->group;
      ok= 1;
      if( p == ttb.phipress->next ){
        ok= 2;  //special case: move the tab one place to the right (swap tabs)
      }
      //remove the dragged tab from the list
      prev= find_prev_itemG( G, ttb.phipress );
      if( prev == NULL){
        if( G->list == ttb.phipress ){
          //remove from list head
          G->list= ttb.phipress->next;
          ttb.phipress->next= NULL;
        }else{
          ok= 0; //tab position???? ignore the drag
        }
      }else{
        //remove from list
        prev->next= ttb.phipress->next;
        ttb.phipress->next= NULL;
      }
      if( ok == 1 ){
        //put dragged tab before "p"
        ttb.phipress->next= p;
        prev= find_prev_itemG( G, p );
        if( prev == NULL){
          G->list= ttb.phipress;
        }else{
          prev->next= ttb.phipress;
        }
      }else if( ok == 2 ){
        //put dragged tab after "p"
        ttb.phipress->next= p->next;
        p->next= ttb.phipress;
      }
      if( ok != 0 ){
        //update the last tab (insertion point)
        G->list_last= find_prev_itemG( G, NULL );
        //hilight the dragged tab
        p= ttb.phipress;
        //redraw the complete toolbar
        redraw_toolbar(T);
      }
    }
    //clear previous hilight (in any toolbar)
    if( (ttb.philight != NULL) && (ttb.ntbhilight >= 0) ){
      redraw_item(ttb.philight );
    }
    ttb.philight= p;
    ttb.ntbhilight= T->num;
    //redraw new hilighted button in this toolbar
    redraw_item(ttb.philight);
    //update tooltip text
    set_hilight_tooltipT(T);

  }else if( (p != NULL) && (p == ttb.phipress) ){
    //drag over the same highlight
    if( p->back_color == BKCOLOR_PICKER ){
      color_pick_ev( p, 0, 1 ); //update color click
    }
  }
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

static void show_toolbar(struct toolbar_data *T, int show)
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
/*                                 LUA FUNCTIONS                                 */
/* ============================================================================= */
static int intluadef(lua_State *L, int ncolor, int defcol )
{
  if( !lua_isnone(L, ncolor) ){
    return lua_tointeger(L, ncolor);
  }
  return defcol;
}

//----- TOOLBARS -----
/** `toolbar.new(barsize,buttonsize,imgsize,toolbarnum/isvertical,imgpath)` Lua function. */
static int ltoolbar_new(lua_State *L)
{
  int num;
  const char * imgpath= NULL;

  if( lua_isboolean(L,4) ){
    num= 0;   //FALSE: horizontal = #0
    if( lua_toboolean(L,4) ){
      num= 1; //TRUE:  vertical   = #1
    }
  }else{
    num= lua_tointeger(L, 4);   //toolbar number (0:horizonal, 1:vertical,..)
  }
  if( (num < 0) || (num >= NTOOLBARS) ){
    num= 0; //default #0
  }
  if( !lua_isnone(L, 5) ){
    //change global image base
    imgpath= luaL_checkstring(L, 5);
  }
  ttb_new_toolbar(num, lua_tointeger(L, 1), lua_tointeger(L, 2), lua_tointeger(L, 3), imgpath );
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
  struct toolbar_data *T;
  struct toolbar_group *G;
  int num, ngrp;

  if( lua_isboolean(L,1) ){
    num= 0;   //FALSE: horizontal-top = #0
    if( lua_toboolean(L,1) ){
      num= 1; //TRUE:  vertical-left  = #1
    }
  }else{
    num= lua_tointeger(L, 1);   //toolbar number= 0:top(H), 1:left(V), 2=bottom(H), 3=right(V)
  }
  if( (num < 0) || (num >= NTOOLBARS) ){
    num= 0; //default #0
  }
  //set the current toolbar num
  ttb.currentntb= num;
  ngrp= lua_tointeger(L, 2);
  if( (ngrp >= 0) && (ngrp < ttb.tbdata[num].ngroups) ){
    //set the current group in that toolbar
    G= group_from_numT( &(ttb.tbdata[num]), ngrp );
    if( G != NULL ){
      T= toolbar_from_num(num);
      if( T != NULL ){
        T->currentgroup= ngrp;
        T->curr_group= G;
        if( (G->flags & TTBF_GRP_TABBAR) != 0){
          //the group is a tab-bar, set as default
          T->tab_group= G;
        }
      }
    }
  }
  return 0;
}

/** `toolbar.addgroup(xcontrol,ycontrol,width,height,[hidden])` Lua function. */
/** x/y control:
  0:allow groups before and after 1:no groups at the left/top  2:no groups at the right/bottom
  3:exclusive row/col  +4:expand  +8:use item size */
static int ltoolbar_addgroup(lua_State *L)
{ //create a new button group and set as current
  int  h, w;
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
  }
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

static struct toolbar_group * current_buttongrp( void )
{
  struct toolbar_data *T;
  struct toolbar_group * g= current_group();
  if( (g != NULL) && ((g->flags & (TTBF_GRP_AUTO|TTBF_GRP_TABBAR)) != 0) ){
    g= NULL; //don't use a tabbar for buttons / replace auto generated group
  }
  if( g == NULL ){
    //create a new button group and set as current
    g= add_groupT_rcoh(current_toolbar(), 8, 8, 0); //default: use items size
  }
  return g;
}

//----- BUTTONS -----
/** `toolbar.addbutton(name,tooltiptext)` Lua function. */
static int ltoolbar_addbutton(lua_State *L)
{
  const char *name= luaL_checkstring(L, 1);
  struct toolbar_group * g= current_buttongrp();
  if( g != NULL ){
    redraw_begG(g);
    add_itemG( g, name, name, luaL_checkstring(L, 2), NULL, 0);
    //group size changed, update toolbar
    update_group_sizeG(g, 1); //redraw
  }
  return 0;
}

/** `toolbar.addtext(name,text,tooltiptext,width)` Lua function. */
static int ltoolbar_addtext(lua_State *L)
{
  const char *name= luaL_checkstring(L, 1);
  struct toolbar_group * g= current_buttongrp();
  if( g != NULL ){
    redraw_begG(g);
    add_itemG( g, name, NULL, luaL_checkstring(L, 3), luaL_checkstring(L, 2), lua_tointeger(L, 4));
    //group size changed, update toolbar
    update_group_sizeG(g, 1); //redraw
  }
  return 0;
}

/** `toolbar.addlabel(text,tooltiptext,width,leftalign,bold,name)` Lua function. */
static int ltoolbar_addlabel(lua_State *L)
{
  struct toolbar_item * p;
  struct toolbar_group * g= current_buttongrp();
  if( g != NULL ){
    redraw_begG(g);
    p= add_itemG( g, lua_tostring(L,6), NULL, luaL_checkstring(L, 2), luaL_checkstring(L, 1), lua_tointeger(L, 3));
    if( p != NULL ){
      p->flags &= ~TTBF_SELECTABLE; //remove the selectable flag (it's not a button)
      if( lua_toboolean(L,4) ){
        p->flags |= TTBF_TEXT_LEFT; //left align text
      }
      if( lua_toboolean(L,5) ){
        p->flags |= TTBF_TEXT_BOLD; //use bold
      }
    }
    //group size changed, update toolbar
    update_group_sizeG(g, 1); //redraw
  }
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
  struct toolbar_group * G= current_buttongrp();
  if( G != NULL ){
    x= lua_tointeger(L, 1);
    if( lua_isnone(L, 2) ){
      //only one parameter: new row/column
      if( G->isvertical ){
        //new column
        x= G->xnew + G->bwidth + x;
        y= G->ymargin;
      }else{
        //new row
        y= G->ynew + G->bheight + x;
        x= G->xmargin;
      }
    }else{
      //2 parameters: x,y
      y= lua_tointeger(L, 2);
    }
    G->xnew= x;
    G->ynew= y;
  }
  return 0;
}

/** `toolbar.enable(name,isenabled,onlyinthistoolbar)` Lua function. */
static int ltoolbar_enable(lua_State *L)
{
  int i, isenabled;
  const char *name= luaL_checkstring(L, 1);
  isenabled= lua_toboolean(L,2);
  if( lua_toboolean(L,3) ){
    //enable button in this toolbar only
    ttb_enable_buttonT(current_toolbar(), name, isenabled );
  }else{
    //enable button in every toolbar
    for( i= 0; i < NTOOLBARS; i++){
      ttb_enable_buttonT(toolbar_from_num(i), name, isenabled );
    }
  }
  return 0;
}

/** `toolbar.seticon(name,icon,[nicon],onlyinthistoolbar)` Lua function. */
/** name= button name or "TOOLBAR" or "GROUP" */
static int ltoolbar_seticon(lua_State *L)
{
  int i, nicon;
  const char *name= luaL_checkstring(L, 1);
  const char *img= luaL_checkstring(L, 2);
  nicon= lua_tointeger(L, 3);
  if( lua_toboolean(L,4) ){
    //set icon in this toolbar only
    ttb_change_button_imgT(current_toolbar(), name, nicon, img );
  }else{
    //set icon in every toolbar
    for( i= 0; i < NTOOLBARS; i++){
      ttb_change_button_imgT(toolbar_from_num(i), name, nicon, img );
    }
  }
  return 0;
}

/** `toolbar.setbackcolor(name,color,[keep-background-img],[onlyinthistoolbar])` Lua function. */
/** name= button name or "TOOLBAR" or "GROUP", color=RRGGBB,-1=transparent, -2=color-picker */
static int ltoolbar_setbackcolor(lua_State *L)
{
  int i, color, keepback;
  const char *name= luaL_checkstring(L, 1);
  color= lua_tointeger(L, 2);
  keepback= lua_toboolean(L,3);
  if( lua_toboolean(L,4) ){
    //set back color in this toolbar only
    ttb_set_back_colorT(current_toolbar(), name, color, keepback );
  }else{
    //set back color in every toolbar
    for( i= 0; i < NTOOLBARS; i++){
      ttb_set_back_colorT(toolbar_from_num(i), name, color, keepback );
    }
  }
  return 0;
}

/** `toolbar.settooltip(name,tooltip,[onlyinthistoolbar])` Lua function. */
static int ltoolbar_settooltip(lua_State *L)
{
  int i;
  const char *name= luaL_checkstring(L, 1);
  const char *tooltip= luaL_checkstring(L, 2);
  if( lua_toboolean(L,3) ){
    //set button's tooltip in this toolbar only
    ttb_change_button_tooltipT(current_toolbar(), name, tooltip );
  }else{
    //set button's tooltip in every toolbar
    for( i= 0; i < NTOOLBARS; i++){
      ttb_change_button_tooltipT(toolbar_from_num(i), name, tooltip );
    }
  }
  return 0;
}

/** `toolbar.settext(name,text,[tooltip],[onlyinthistoolbar])` Lua function. */
static int ltoolbar_settext(lua_State *L)
{
  int i;
  const char *name= luaL_checkstring(L, 1);
  const char *text= luaL_checkstring(L, 2);
  const char *tooltip= NULL;
  if( !lua_isnone(L, 3) ){
    tooltip= luaL_checkstring(L, 3);
  }
  if( lua_toboolean(L,4) ){
    //set button's text/tooltip in this toolbar only
    ttb_change_button_textT(current_toolbar(), name, text );
    if(tooltip != NULL){
      ttb_change_button_tooltipT(current_toolbar(), name, tooltip );
    }
  }else{
    //set button's text/tooltip in every toolbar
    for( i= 0; i < NTOOLBARS; i++){
      ttb_change_button_textT(toolbar_from_num(i), name, text );
      if(tooltip != NULL){
        ttb_change_button_tooltipT(toolbar_from_num(i), name, tooltip );
      }
    }
  }
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
  int percwidth, minwidth, maxwidth;
  int ntab= lua_tointeger(L, 1);
  if( lua_isnumber(L,2) ){
    percwidth= lua_tointeger(L, 2);
    minwidth=  lua_tointeger(L, 3);
    maxwidth=  lua_tointeger(L, 4);
    ttb_change_tabwidthG( current_tabbar(), ntab, percwidth, minwidth, maxwidth );

  }else if( lua_isstring(L,2) ){
    //use the width of the given text
    minwidth= get_tabtext_widthG( current_tabbar(), lua_tostring(L, 2) );
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

/* ============================================================================= */
/*                          CALLED FROM TA                                       */
/* ============================================================================= */
/* register LUA toolbar object */
void register_toolbar(lua_State *L)
{
  ttb.cpick.HSV_val= 1.0; //V value of color picker (only one for now...)
  ttb.cpick.HSV_x= 0;
  ttb.cpick.HSV_y= 0;
  ttb.cpick.HSV_rgb= 0x00FF0000; //RED
  ttb.cpick.pchosen= NULL;

  lua_newtable(L);
//toolbars
  l_setcfunction(L, -1, "new",          ltoolbar_new);	        //create a new toolbar
  l_setcfunction(L, -1, "adjust",       ltoolbar_adjust);	      //optionaly fine tune some parameters
  l_setcfunction(L, -1, "show",         ltoolbar_show);	        //show/hide toolbar
//groups
  l_setcfunction(L, -1, "seltoolbar",   ltoolbar_seltoolbar);   //select which toolbar/group to edit
  l_setcfunction(L, -1, "addgroup",     ltoolbar_addgroup);     //add a new group
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

  lua_setglobal(L, "toolbar");
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
//ntoolbar=0: HORIZONTAL
//ntoolbar=1: VERTICAL
//ntoolbar=2: HORIZONTAL
//ntoolbar=3: VERTICAL
void create_tatoolbar( GtkWidget *vbox, int ntoolbar )
{
  GtkWidget * drawing_area;

  if( ntoolbar < NTOOLBARS ){
    drawing_area = gtk_drawing_area_new();
    ttb.tbdata[ntoolbar].draw= drawing_area;
    ttb.tbdata[ntoolbar].num=  ntoolbar;
    ttb.tbdata[ntoolbar].isvertical= ((ntoolbar == 1)||(ntoolbar == 3));
    ttb.tbdata[ntoolbar].isvisible= 0;
    if( ttb.tbdata[ntoolbar].isvertical ){
      gtk_widget_set_size_request(drawing_area, 1, -1);
    }else{
      gtk_widget_set_size_request(drawing_area, -1, 1);
    }
    gtk_widget_set_events(drawing_area, GDK_EXPOSURE_MASK|GDK_LEAVE_NOTIFY_MASK|
      GDK_POINTER_MOTION_MASK|GDK_BUTTON_PRESS_MASK|GDK_BUTTON_RELEASE_MASK );
    signal(drawing_area, "size-allocate",        ttb_size_ev);
    signal(drawing_area, "expose_event",         ttb_paint_ev);
    signal(drawing_area, "leave-notify-event",   ttb_mouseleave_ev);
    signal(drawing_area, "motion_notify_event",  ttb_mousemotion_ev);
    signal(drawing_area, "scroll-event",         ttb_scrollwheel_ev);
    signal(drawing_area, "button-press-event",   ttb_button_ev);
    signal(drawing_area, "button-release-event", ttb_button_ev);

    gtk_box_pack_start(GTK_BOX(vbox), drawing_area, FALSE, FALSE, 0);
  }
}

/* show/hide ALL toolbars */
void show_tatoolbar(int show)
{
  int i;
  for( i= 0; i < NTOOLBARS; i++ ){
    if( ttb.tbdata[i].draw != NULL ){
      if( show ){
        //show all toolbars
        gtk_widget_show( ttb.tbdata[i].draw );
      }else{
        //hide all toolbars
        gtk_widget_hide( ttb.tbdata[i].draw );
      }
    }
  }
}

/* destroy all toolbars */
void kill_tatoolbar( void )
{ //free all toolbars data
  free_tatoolbar();
}
