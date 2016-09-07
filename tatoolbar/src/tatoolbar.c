/* TA toolbar */

//#define UNUSED(expr) do { (void)(expr); } while (0)

static void lL_showcontextmenu(lua_State *L, GdkEventButton *event, char *k);

//flags
#define TTBF_SELECTABLE     0x0001
#define TTBF_GRAYED         0x0002
#define TTBF_TABBAR         0x0004
#define TTBF_TAB            0x0008
#define TTBF_ACTIVE         0x0010
#define TTBF_SCROLL_BUT     0x0020
#define TTBF_CLOSETAB_BUT   0x0040
#define TTBF_CHANGED        0x0080

//node images
#define TTBI_NORMAL         0  //button/separator
#define TTBI_DISABLED       1  //button
#define TTBI_HILIGHT        2  //button/toolbar
#define TTBI_HIPRESSED      3  //button/toolbar
#define TTBI_NODE_N         4

//TTB images
#define TTBI_TB_BACKGROUND  0  //toolbar
#define TTBI_TB_SEPARATOR   1  //toolbar
#define TTBI_TB_HILIGHT     (TTBI_HILIGHT)     //button/toolbar
#define TTBI_TB_HIPRESSED   (TTBI_HIPRESSED)   //button/toolbar
#define TTBI_TB_TABBACK     4 //tab background
#define TTBI_TB_NTAB1       5  //normal tab1
#define TTBI_TB_NTAB2       6  //normal tab2
#define TTBI_TB_NTAB3       7  //normal tab3
#define TTBI_TB_DTAB1       8  //disabled tab1
#define TTBI_TB_DTAB2       9  //disabled tab2
#define TTBI_TB_DTAB3       10 //disabled tab3
#define TTBI_TB_HTAB1       11 //hilight tab1
#define TTBI_TB_HTAB2       12 //hilight tab2
#define TTBI_TB_HTAB3       13 //hilight tab3
#define TTBI_TB_ATAB1       14 //active tab1
#define TTBI_TB_ATAB2       15 //active tab2
#define TTBI_TB_ATAB3       16 //active tab3
#define TTBI_TB_TAB_NSL     17 //tab scroll left
#define TTBI_TB_TAB_NSR     18 //tab scroll right
#define TTBI_TB_TAB_HSL     19 //tab scroll left
#define TTBI_TB_TAB_HSR     20 //tab scroll right
#define TTBI_TB_TAB_NCLOSE  21 //normal close button   
#define TTBI_TB_TAB_HCLOSE  22 //hilight close button
#define TTBI_TB_TAB_CHANGED 23 //changed indicator
#define TTBI_TB_N           24

struct toolbar_img
{
  char * fname;
  int  width;
  int  height;
};

struct toolbar_node
{
  struct toolbar_node * next;
  int flags;      //TTBF_.. flags
  char * name;
  char * tooltip;
  int num;
  int barx1, bary1;
  int barx2, bary2;
  int imgx, imgy;
  struct toolbar_img img[TTBI_NODE_N];
};

struct color3doubles
{
  double R;
  double G;
  double B;
};

static char xbutt_tooltip[128];
static struct toolbar_node xbutton;

#define NTOOLBARS 2
static struct toolbar_data
{
  GtkWidget *draw[NTOOLBARS]; //horizonal & vertical toolbar

  GtkWidget *drawing_area;    //current toolbar

  struct toolbar_node * list;
  struct toolbar_node * list_last;
  struct toolbar_node * philight;
  struct toolbar_node * phipress;

  struct toolbar_node * tabs;
  struct toolbar_node * tabs_last;
  struct toolbar_node * tab_node;
  int ntabs;
  
  int ntabs_hide; //scroll tab support
  int islast_tab_shown;
  int xscleft, xscright;

  int isvertical;
  int barheight;
  int barwidth;
  int bwidth;
  int bheight;
  int xmargin;
  int ymargin;
  int xoff;
  int yoff;

  int xnew;
  int ynew;

  int tabxmargin;
  int tabxsep; //< 0 == overlap
  int tabheight;
  int tabwidth; //total tab width without extra space
  int closeintabs;
  int tabfontsz;  //font size in points (default = 10 points)
  int tabtexth;   //font height
  int tabtextoff; //font y offset
  int tabtexty;   //font baseline y pos
  int tabmodshow; //modified tab: 0:ignore 1:show icon 2:change text color
  struct color3doubles tabtextcolN; //normal
  struct color3doubles tabtextcolH; //hilight
  struct color3doubles tabtextcolA; //active
  struct color3doubles tabtextcolM; //modified
  struct color3doubles tabtextcolG; //grayed

  char * img_base;
  struct toolbar_img img[TTBI_TB_N];
} ttb;

static char * alloc_str( const char *s )
{
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
{
  if( sold != NULL ){
    if( snew != NULL ){
      if( strcmp( sold, snew) == 0 ){
        return sold;  //same string, keep the old one
      }
    }
    //delete old value
    free( (void *) sold);
  }
  //use new value
  return alloc_str(snew);
}


static char * alloc_img_str( const char *name )
{
  int n;
  char *img_file;
  char *scopy= NULL;
  if( name != NULL ){
    n= strlen(name);
    if( (n > 4) && ((strcmp(name+n-4, ".png") == 0)||(strcmp(name+n-4, ".PNG") == 0)) ){
      scopy= alloc_str( name );
    }else{
      if( ttb.img_base == NULL ){
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

static int set_tb_img( struct toolbar_node *p, int nimg, const char *imgname)
{
  struct toolbar_img *pti;

  if( nimg < 0 ){
    return 0; //invalid image num
  }
  if( p == NULL ){
    if( nimg >= TTBI_TB_N ){
      return 0; //invalid image num
    }
    pti= &(ttb.img[nimg]); //toolbar img
  }else{
    if( nimg >= TTBI_NODE_N ){
      return 0; //invalid image num
    }
    pti= &(p->img[nimg]);  //button img
  }

  if( pti->fname != NULL ){
    if( (imgname != NULL) && (strcmp( pti->fname, imgname ) == 0) ){
      return 0; //same img
    }
    //free previous img
    free((void *)pti->fname);
    pti->fname= NULL;
    pti->width= 0;
    pti->height= 0;
  }
  if( imgname != NULL ){
    pti->fname= alloc_img_str(imgname); //get img fname
    if( pti->fname != NULL ){
      cairo_surface_t *cis= cairo_image_surface_create_from_png(pti->fname);
      if( cis != NULL ){
        pti->width=  cairo_image_surface_get_width(cis);
        pti->height= cairo_image_surface_get_height(cis);
        cairo_surface_destroy(cis);
      }
    }
  }
  return 1;
}

static void redraw_button( struct toolbar_node * p )
{
  if( p != NULL ){
    if( (p->flags & (TTBF_TAB|TTBF_SCROLL_BUT|TTBF_CLOSETAB_BUT)) == 0 ){
      //redraw the area of one regular button
      gtk_widget_queue_draw_area(ttb.drawing_area, p->barx1, p->bary1, p->barx2-p->barx1+1, p->bary2-p->bary1+1 ); //redraw
      return;
    }
    //redraw a tab or one of its buttons
  }
  //redraw the complete toolbar
  gtk_widget_queue_draw(ttb.drawing_area);
}

static  int _tabs_x1,_tabs_x2,_tabs_y1,_tabs_y2;
static void redraw_tabs_beg( void )
{
  if( ttb.tab_node != NULL ){
    _tabs_x1= ttb.tab_node->barx1;
    _tabs_x2= ttb.tab_node->barx2;
    _tabs_y1= ttb.tab_node->bary1;
    _tabs_y2= ttb.tab_node->bary2;
  }
}

static void redraw_tabs_end( void )
{
  if( ttb.tab_node != NULL ){
    //union of before and after change size
    if( _tabs_x1 > ttb.tab_node->barx1 ){
      _tabs_x1= ttb.tab_node->barx1;
    }
    if( _tabs_x2 < ttb.tab_node->barx2 ){
      _tabs_x2= ttb.tab_node->barx2;
    }
    if( _tabs_y1 > ttb.tab_node->bary1 ){
      _tabs_y1= ttb.tab_node->bary1;
    }
    if( _tabs_y2 < ttb.tab_node->bary2 ){
      _tabs_y2= ttb.tab_node->bary2;
    }
    //redraw the tabs area
    gtk_widget_queue_draw_area(ttb.drawing_area, _tabs_x1, _tabs_y1, _tabs_x2-_tabs_x1+1, _tabs_y2-_tabs_y1+1 );
  }else{
    //redraw the complete toolbar
    gtk_widget_queue_draw(ttb.drawing_area);
  }
}

static struct toolbar_node *add_ttb_node(const char * name, const char * img, const char *tooltip)
{
  int i;
  struct toolbar_node * p= (struct toolbar_node *) malloc( sizeof(struct toolbar_node));
  if( p != NULL){
    p->next= NULL;
    p->name= alloc_str(name);
    p->tooltip= alloc_str(tooltip);
    p->num= 0;
    p->flags= 0;
    if( p->name != NULL){
      p->flags |= TTBF_SELECTABLE; //if a name is provided, it can be selected
    }
    p->barx1= ttb.xnew;
    p->bary1= ttb.ynew;
    p->imgx= ttb.xnew + ttb.xoff;
    p->imgy= ttb.ynew + ttb.yoff;
    p->barx2= ttb.xnew + ttb.bwidth;
    p->bary2= ttb.ynew + ttb.bheight;
    if( ttb.isvertical ){
      ttb.ynew += ttb.bheight;
    }else{
      ttb.xnew += ttb.bwidth;
    }
    for(i= 0; (i < TTBI_NODE_N); i++){
      p->img[i].fname= NULL;
      p->img[i].width= 0;
      p->img[i].height= 0;
    }
    set_tb_img( p, TTBI_NORMAL, img );

    //conect node to the end of the list
    if( ttb.list_last != NULL ){
      ttb.list_last->next= p;
    }else{
      ttb.list= p; //first
    }
    ttb.list_last= p;
  }
  return p;
}

static void calc_tabnode_width(void)
{
  if( ttb.tab_node != NULL ){
    int x= ttb.tab_node->barx1 + ttb.tabxmargin + ttb.tabwidth;
    //add extra space between tabs
    if( (ttb.ntabs > 1) && (ttb.tabxsep != 0) ){
      x += (ttb.ntabs-1) * ttb.tabxsep;
    }
    ttb.tab_node->barx2= x;
  }
}


static void chg_tab_texts( struct toolbar_node * p, const char *name, const char *tooltip )
{
  int textw;
  p->name= chg_alloc_str(p->name, name);
  textw= 0;
  if( p->name != NULL ){
    cairo_text_extents_t ext;
    cairo_t *cr = gdk_cairo_create(ttb.drawing_area->window);
    cairo_set_font_size(cr, ttb.tabfontsz);
    cairo_text_extents( cr, p->name, &ext );
    textw= (int) ext.width;
    cairo_destroy(cr);
  }
  p->tooltip= chg_alloc_str(p->tooltip, tooltip);
  p->barx1= 0;
  p->bary1= 0;
  p->imgx=  ttb.img[TTBI_TB_NTAB1].width;	//text start
  p->barx2= p->imgx + textw + ttb.img[TTBI_TB_NTAB3].width;
  p->bary2= ttb.img[TTBI_TB_NTAB1].height;
  p->imgy=  ttb.tabtexty;
  //total tab width without extra space
  ttb.tabwidth += p->barx2;
  calc_tabnode_width();
}

static struct toolbar_node *add_ttb_tab(int ntab, const char * name, const char *tooltip)
{
  int i;
  struct toolbar_node * p= (struct toolbar_node *) malloc( sizeof(struct toolbar_node));
  if( p != NULL){
    p->next= NULL;
    p->name= NULL;
    p->tooltip= NULL;
    p->num= ntab;
    p->flags= TTBF_TAB | TTBF_SELECTABLE;
    chg_tab_texts(p, name, tooltip);

    for(i= 0; (i < TTBI_NODE_N); i++){
      p->img[i].fname= NULL;
      p->img[i].width= 0;
      p->img[i].height= 0;
    }
    //set_tb_img( p, TTBI_NORMAL, img ); //TODO: add an image

    //conect node to the end of the list
    if( ttb.tabs_last != NULL ){
      ttb.tabs_last->next= p;
    }else{
      ttb.tabs= p; //first
    }
    ttb.tabs_last= p;
    ttb.ntabs++;
  }
  return p;
}

static struct toolbar_node *get_ttb_tab(int ntab)
{
  struct toolbar_node * p;
  for( p= ttb.tabs; (p != NULL); p= p->next ){
    if( p->num == ntab){
      return p;
    }
  }
  return NULL;
}

static struct toolbar_node *set_ttb_tab(int ntab, const char * name, const char *tooltip)
{
  struct toolbar_node * p;
  void * vp;

  redraw_tabs_beg();
  p= get_ttb_tab(ntab);
  if( p == NULL ){  //not found, add at the end
    p= add_ttb_tab(ntab, name, tooltip);
  }else{
    //tab found, adjust total tab width without extra space
    ttb.tabwidth -= p->barx2;
    p->barx2= 0;
    //update texts
    chg_tab_texts( p, name, tooltip);
  }
  //queue a redraw using the post-modify size (in case the tabbar gets bigger)
  redraw_tabs_end();
  return p;
}

static void activate_ttb_tab(int ntab)
{
  struct toolbar_node *p, *t, *vistab;
  int x, nhide;

  redraw_tabs_beg();
  t= NULL;
  for( p= ttb.tabs; (p != NULL); p= p->next ){
    if( p->num == ntab){
      p->flags |= TTBF_ACTIVE | TTBF_SELECTABLE;
      p->flags &= ~TTBF_GRAYED;
      t= p;
    }else{
      p->flags &= ~TTBF_ACTIVE; //only one tab can be active
    }
  }
  if( (t != NULL) && (ttb.tab_node != NULL) && (ttb.barwidth > 0) ){
    //check tab visibility
    x= ttb.tab_node->barx1 + ttb.tabxmargin;
    for( p= ttb.tabs, nhide= ttb.ntabs_hide; (nhide > 0)&&(p != NULL); nhide-- ){
      if( p->num == ntab){
        //the tab is left-hiden, set as the first visible
        ttb.ntabs_hide -= nhide;
        ttb.philight= NULL; //force hilight off
        ttb.phipress= NULL;
        gtk_widget_set_tooltip_text(ttb.drawing_area, "");
        t= NULL;  //ready
        break;
      }
      p= p->next; //skip hidden tabs
    }
    vistab= p;    //first visible tab
    if( t != NULL ){
      //not a left-hiden tab
      for( ; (p != NULL); p= p->next ){
        if( x > ttb.barwidth ){
          break;  //the rest of the tabs are right-hiden
        }
        if( p->num == ntab ){
          //check if it's completely visible
          if( x+t->barx2 <= ttb.barwidth ){
            t= NULL;  //visible, nothing to do
          }
          break;  //some part of the tab is hiden
        }
        x += p->barx2 + ttb.tabxsep;
      }
    }
    if( t != NULL ){
      //at least a part of the tab is right-hiden
      for( ; (p != NULL); p= p->next ){
        x += p->barx2;
        if( p->num == ntab ){
          break;
        }
        x += ttb.tabxsep;
      }
      //hide some tabs until the tab is completely visible
      while( (vistab != NULL) && (x > ttb.barwidth) ){
        x -= vistab->barx2 + ttb.tabxsep;
        vistab= vistab->next;
        ttb.ntabs_hide++;
      }
      if( vistab == NULL ){
        //not enought space to be completely visible
        //set as the first visible tab
        ttb.ntabs_hide= 0;
        for( p= ttb.tabs; (p != NULL); p= p->next ){
          if( p->num == ntab){
            break;
          }
          ttb.ntabs_hide++;
        }
      }
      ttb.philight= NULL; //force hilight off
      ttb.phipress= NULL;
      gtk_widget_set_tooltip_text(ttb.drawing_area, "");
    }
  }
  redraw_tabs_end();
}

static void enable_ttb_tab(int ntab, int enable)
{
  redraw_tabs_beg();
  struct toolbar_node * p= get_ttb_tab(ntab);
  if( p != NULL ){
    if( enable ){
      p->flags &= ~TTBF_GRAYED;
      p->flags |= TTBF_SELECTABLE;
    }else{
      p->flags |= TTBF_GRAYED;
      p->flags &= ~(TTBF_ACTIVE | TTBF_SELECTABLE);
    }
  }
  redraw_tabs_end();
}

static void set_changed_ttb_tab(int ntab, int changed)
{
  redraw_tabs_beg();
  struct toolbar_node * p= get_ttb_tab(ntab);
  if( p != NULL ){
    if( changed ){
      p->flags |= TTBF_CHANGED;
    }else{
      p->flags &= ~TTBF_CHANGED;
    }
  }
  redraw_tabs_end();
}

static void kill_toolbar_node( struct toolbar_node * p )
{
  int i;
  if(p->name != NULL){
    free((void*)p->name);
  }
  if(p->tooltip != NULL){
    free((void*)p->tooltip);
  }
  for(i= 0; (i < TTBI_NODE_N); i++){
    if( p->img[i].fname != NULL ){
      free((void*)p->img[i].fname);
    }
  }
  free((void*)p);
}

static void kill_toolbar_list( struct toolbar_node * list )
{
  struct toolbar_node * p;
  while(list != NULL){
    p= list;
    list= list->next;
    kill_toolbar_node(p);
  }
}

static void kill_tatoolbar( void )
{
  int i;

  kill_toolbar_list(ttb.list);
  ttb.list= NULL;
  ttb.list_last= NULL;
  ttb.philight= NULL;
  ttb.phipress= NULL;

  kill_toolbar_list(ttb.tabs);
  ttb.tabs= NULL;
  ttb.tabs_last= NULL;
  ttb.tab_node= NULL;
  ttb.ntabs= 0;
  ttb.ntabs_hide= 0;
  ttb.islast_tab_shown= 1;
  ttb.xscleft= -1;
  ttb.xscright= -1;
  ttb.tabwidth= 0;
  ttb.tabxmargin= 0;
  ttb.tabxsep= 0;
  ttb.closeintabs= 0;
  ttb.tabfontsz= 10;  //font size in points (default = 10 points)
  ttb.tabtextoff= 0;
  ttb.tabtexty= 0;
  ttb.tabtexth= 0;
  ttb.tabtextcolN.R= 0.0;
  ttb.tabtextcolN.G= 0.0;
  ttb.tabtextcolN.B= 0.0;

  if( ttb.img_base != NULL ){
    free((void *)ttb.img_base);
    ttb.img_base= NULL;
  }
  for(i= 0; (i < TTBI_TB_N); i++){
    if( ttb.img[i].fname != NULL ){
      free((void*)ttb.img[i].fname);
      ttb.img[i].fname= NULL;
      ttb.img[i].width= 0;
      ttb.img[i].height= 0;
    }
  }
}

static struct toolbar_node * getButtonFromXY(int x, int y)
{
  struct toolbar_node * p;
  int nx, nhide, xc1, xc2, yc1, yc2;
  char *s;
  
  for( p= ttb.list, nx=0; (p != NULL); p= p->next, nx++ ){
    //ignore non selectable things (like separators)
    if( ((p->flags & TTBF_SELECTABLE)!=0) && (x >= p->barx1) && (x <= p->barx2) && (y >= p->bary1) && (y <= p->bary2) ){
      if( (p->flags & TTBF_TABBAR) != 0){
        //is a tabbar, locate tab node
        if((ttb.xscleft >= 0)&&(x >= ttb.xscleft)&&(x <= ttb.xscleft+ttb.img[TTBI_TB_TAB_NSL].width+1)){
          xbutton.flags= TTBF_SCROLL_BUT;
          xbutton.num= -1;
          xbutton.tooltip= NULL;
          return &xbutton; //scroll left button
        }
        if((ttb.xscright >= 0)&&(x >= ttb.xscright)&&(x <= ttb.xscright+ttb.img[TTBI_TB_TAB_NSR].width+1)){
          xbutton.flags= TTBF_SCROLL_BUT;
          xbutton.num= 1;
          xbutton.tooltip= NULL;
          return &xbutton; //scroll right button
        }
        x -= p->barx1 + ttb.tabxmargin;
        y -= p->bary1;
        for( p= ttb.tabs, nhide= ttb.ntabs_hide; (nhide > 0)&&(p != NULL); nhide-- ){
          p= p->next; //skip hidden tabs (scroll support)
        }
        for( ; (x >= 0)&&(p != NULL); p= p->next ){
          if( ((p->flags & TTBF_SELECTABLE)!=0) && (x <= p->barx2) ){
            if( ttb.closeintabs ){
              //over close tab button?
              xc1= p->barx2-ttb.img[TTBI_TB_NTAB3].width;
              xc2= xc1+ttb.img[TTBI_TB_TAB_NCLOSE].width;
              yc2= ttb.img[TTBI_TB_TAB_NCLOSE].height;
              yc1= yc2-ttb.img[TTBI_TB_TAB_NCLOSE].width; //square close area
              if( yc1 < 0){
                yc1= 0;
              }
              if( (x >= xc1)&&(x <= xc2)&&(y >= yc1)&&(y <= yc2) ){
                xbutton.flags= TTBF_CLOSETAB_BUT;
                xbutton.num= p->num;
                xbutton.tooltip= xbutt_tooltip;
                strcpy( xbutt_tooltip, "Close " );
                s= p->tooltip;
                if( s == NULL ){
                  s= p->name;
                }
                if( s != NULL ){
                  strncpy( xbutt_tooltip+6, s, sizeof(xbutt_tooltip)-7 );
                  xbutt_tooltip[sizeof(xbutt_tooltip)-1]= 0;
                }else{
                  strcpy( xbutt_tooltip+6, "tab" );
                }
                return &xbutton; //close tab button
              }
            }
            return p; //TAB
          }
          x -= p->barx2 + ttb.tabxsep;
        }
        return NULL;
      }
      return p; //BUTTON
    }
  }
  return NULL;
}

static struct toolbar_node * getButtonFromName(const char *name)
{
  struct toolbar_node * p;
  if( name != NULL ){
    for( p= ttb.list; (p != NULL); p= p->next ){
      if( (p->name != NULL) && (strcmp(p->name, name) == 0) ){
        return p;
      }
    }
  }
  return NULL;  //invalid
}

static void ttb_change_button_img(const char *name, int nimg, const char *img )
{
  struct toolbar_node * p= getButtonFromName(name);
  if( (p != NULL) || (strcmp(name, "TOOLBAR") == 0) ){
    if( set_tb_img(p, nimg, img ) ){
      redraw_button(p); //redraw button / toolbar (p==NULL)
    }
  }
}

static void ttb_enable_button(const char * name, int isenabled )
{
  int flg;
  struct toolbar_node * p= getButtonFromName(name);
  if( p != NULL){
    flg= p->flags;
    if( isenabled ){
      p->flags= (flg & ~TTBF_GRAYED) | TTBF_SELECTABLE;
    }else{
      p->flags= (flg & ~TTBF_SELECTABLE) | TTBF_GRAYED;
    }
    if( flg != p->flags ){
      redraw_button(p); //redraw button
    }
  }
}

static void set_hilight_tooltip(GtkWidget *widget)
{ //update tooltip text
  char *tooltip= "";
  if(ttb.philight != NULL){
    if(ttb.philight->tooltip != NULL){
      tooltip= ttb.philight->tooltip;
    }
  }
  gtk_widget_set_tooltip_text(widget, tooltip);
}

static void scroll_tabs(GtkWidget *widget, int x, int y, int dir )
{
  int nhide= ttb.ntabs_hide;
  if((dir < 0)&&(ttb.ntabs_hide > 0)){
    ttb.ntabs_hide--;
  }
  if((dir > 0)&&(!ttb.islast_tab_shown) && (ttb.ntabs_hide < ttb.ntabs-1)){
    ttb.ntabs_hide++;
  }
  if( nhide != ttb.ntabs_hide ){
    //update hilight
    ttb.philight= getButtonFromXY(x, y);
    //update tooltip text
    set_hilight_tooltip(widget);
    gtk_widget_queue_draw(widget);
  }
}

static gboolean ttb_button_ev(GtkWidget *widget, GdkEventButton *event, void*__)
{
  struct toolbar_node * p;
  UNUSED(__);
  if( (event->button == 1)||(event->button == 3) ){
    if(event->type == GDK_BUTTON_PRESS){
      ttb.phipress= getButtonFromXY(event->x, event->y);
      if( ttb.phipress != NULL ){
        ttb.philight= ttb.phipress; //hilight as pressed
      }
      redraw_button(ttb.phipress); //redraw button
      return TRUE;
    }
    if(event->type == GDK_BUTTON_RELEASE){
      p= getButtonFromXY(event->x, event->y);
      gtk_widget_set_tooltip_text(widget, "");
      if( (p != NULL) && (p == ttb.phipress) ){
        redraw_button(ttb.philight);  //redraw hilighted button
        //button pressed (mouse press and release over the same button)

        //NOTE: this prevents to keep a hilited button when a dialog is open from the event
        ttb.philight= NULL; //(but also removes the hilite until the mouse is moved)
        if( (p->flags & TTBF_SCROLL_BUT) != 0 ){
          scroll_tabs(widget, event->x, event->y, p->num);
          
        }else if( (p->flags & TTBF_CLOSETAB_BUT) != 0 ){
          lL_event(lua, "toolbar_tabclicked", LUA_TNUMBER, p->num, -1);
          lL_event(lua, "toolbar_tabclose",   LUA_TNUMBER, p->num, -1);
          
        }else if( (p->flags & TTBF_TAB) == 0 ){
          if(event->button == 1){
            lL_event(lua, "toolbar_clicked", LUA_TSTRING, p->name, -1);
          }
        }else{
          lL_event(lua, "toolbar_tabclicked", LUA_TNUMBER, p->num, -1);
          if(event->button == 3){
            lL_showcontextmenu(lua, event, "tab_context_menu"); //open context menu
          }
        }
      }else{
        redraw_button(p); 			  //redraw button under mouse (if any)
        redraw_button(ttb.philight);  //redraw hilighted button (if any)
      }
      ttb.phipress= NULL;
      return TRUE;
    }
    if(event->type == GDK_2BUTTON_PRESS){ //double click
      p= getButtonFromXY(event->x, event->y);
      if( p != NULL ){
        if( (p->flags & TTBF_TAB) != 0 ){
          lL_event(lua, "toolbar_tab2clicked", LUA_TNUMBER, p->num, -1);
        }
      }
      return TRUE;
    }
  }
  return FALSE;
}

static gboolean ttb_scrollwheel_ev(GtkWidget *widget, GdkEventScroll* event, void*__)
{
  UNUSED(__);
  
  //don't scroll if a button is pressed (mouse still down)
  if( ttb.phipress == NULL ){
    if( (event->direction == GDK_SCROLL_UP)||(event->direction == GDK_SCROLL_LEFT) ){
      scroll_tabs(widget, event->x, event->y, -1);
    }else{
      scroll_tabs(widget, event->x, event->y, 1);
    }
  }
  return TRUE;
}

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

static void draw_txt( cairo_t *ctx, const char *txt, int x, int y, struct color3doubles *color )
{
  if( txt != NULL ){
    cairo_save(ctx);
    cairo_set_source_rgb(ctx, color->R, color->G, color->B);
    cairo_set_font_size(ctx, ttb.tabfontsz); 
    cairo_move_to(ctx, x, y);
    cairo_show_text(ctx, txt);
    cairo_restore(ctx);
  }
}

static void draw_tab(cairo_t *cr, struct toolbar_node *t, int x, int y)
{
  int h, hc, x3;
  struct color3doubles *color= &ttb.tabtextcolN;
  h= TTBI_TB_NTAB1;
  hc= TTBI_TB_TAB_NCLOSE;
  if( ttb.closeintabs ){
    if( (ttb.philight != NULL) && (ttb.philight->flags & TTBF_CLOSETAB_BUT) != 0 ){
      //a tab close button is hilited, is from this tab?
      if( ttb.philight->num == t->num ){
        hc= TTBI_TB_TAB_HCLOSE;  //hilight close tab button
        h=  TTBI_TB_HTAB1;       //and tab
        color= &ttb.tabtextcolH;
      }
    }
  }
  if( (t->flags & TTBF_ACTIVE) != 0 ){
    h= TTBI_TB_ATAB1;
    color= &ttb.tabtextcolA;
    
  }else if( (t->flags & TTBF_GRAYED) != 0 ){
    h= TTBI_TB_DTAB1;
    color= &ttb.tabtextcolG;
    
  }else if( (t == ttb.philight)&&((ttb.phipress == NULL)||(ttb.phipress == t)) ){
    h= TTBI_TB_HTAB1;
    color= &ttb.tabtextcolH;
  }
  draw_img(cr, &(ttb.img[h]), x, y, 0 );
  draw_fill_img(cr, &(ttb.img[h+1]), x+t->imgx, y, t->barx2 -t->imgx -ttb.img[TTBI_TB_NTAB3].width, ttb.img[TTBI_TB_NTAB2].height );
  
  x3= x+t->barx2-ttb.img[TTBI_TB_NTAB3].width;
  draw_img(cr, &(ttb.img[h+2]), x3, y, 0 );
  if( (t->flags & TTBF_CHANGED) != 0 ){
    if( ttb.tabmodshow == 1 ){
      draw_img(cr, &(ttb.img[TTBI_TB_TAB_CHANGED]), x3, y, 0 );
    }else if( ttb.tabmodshow == 2 ){
      color= &ttb.tabtextcolM;
    }
  }
  if( ttb.closeintabs ){
    draw_img(cr, &(ttb.img[hc]), x3, y, 0 );
  }

  draw_txt(cr, t->name, x+t->imgx, y+t->imgy, color );
}

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
  UNUSED(widget);  UNUSED(__);
  ttb.barwidth= prec->width;
  ttb.barheight= prec->height;
}

static gboolean ttb_paint_ev(GtkWidget *widget, GdkEventExpose *event, void*__)
{
  UNUSED(__);
  struct toolbar_node * p, *t, *ta;
  struct toolbar_img *pti;
  int h, grayed, x, y, xa, nhide;

  if( (ttb.barwidth < 0) || (ttb.barheight < 0) ){
    ttb.barwidth=  widget->allocation.width;
    ttb.barheight= widget->allocation.height;
  }
  
  cairo_t *cr = gdk_cairo_create(widget->window);
  //draw background image (if any)
  draw_fill_img(cr, &(ttb.img[TTBI_TB_BACKGROUND]), 0, 0, ttb.barwidth, ttb.barheight );
  //draw hilight (under regular buttons)
  p= ttb.philight;
  if( (p != NULL) && ((p->flags & (TTBF_TAB|TTBF_SCROLL_BUT|TTBF_CLOSETAB_BUT))==0) ){
    if( need_redraw(event, p->barx1, p->bary1, p->barx2, p->bary2) ){
      h= -1;
      if(ttb.phipress == p){
        h= TTBI_HIPRESSED; //hilight as pressed
      }else if(ttb.phipress == NULL){
        h= TTBI_HILIGHT; //normal hilight (and no other button is pressed)
      }
      if( h >= 0){
        //try to use the button hilight version
        pti= &(p->img[h]);
        if( pti->fname == NULL ){
          //use the toolbar version
          pti= &(ttb.img[h]);
        }
        draw_img(cr, pti, p->barx1, p->bary1, 0 );
      }
    }
  }
  //draw all button images
  ta= NULL;
  xa= 0;
  for( p= ttb.list; (p != NULL); p= p->next ){
    if( (p->flags & TTBF_TABBAR) != 0){
      //tab-bar
      if( need_redraw( event, p->barx1, p->bary1, ttb.barwidth, p->bary2) ){
        x= p->barx1;
        y= p->bary1;
        draw_fill_img(cr, &(ttb.img[TTBI_TB_TABBACK]), x, y, ttb.barwidth, p->bary2 );
        x += ttb.tabxmargin;
        for( t= ttb.tabs, nhide= ttb.ntabs_hide; (nhide > 0)&&(t != NULL); nhide-- ){
          t= t->next; //skip hidden tabs (scroll support)
        }
        for( ; (t != NULL); t= t->next ){
          if( need_redraw( event, x, y, x+t->barx2, y+t->bary2) ){
            if( (t->flags & TTBF_ACTIVE) != 0 ){
              ta= t;
              xa= x;
            }else{
              draw_tab( cr, t, x, y );
            }
          }
          x += t->barx2 + ttb.tabxsep;
        }
        ttb.islast_tab_shown= (ttb.barwidth >= x );
        //draw the active tab over the other tabs
        if( ta != NULL ){
          draw_tab( cr, ta, xa, y );
        }
        ttb.xscleft= -1;
        ttb.xscright= -1;
        //draw scroll indicator over the tabs
        if( ttb.ntabs_hide > 0 ){
          ttb.xscleft= p->barx1+ttb.tabxmargin;
          h= TTBI_TB_TAB_NSL;
          if( (ttb.philight != NULL)&&(ttb.philight==ttb.phipress)&&(ttb.philight->flags==TTBF_SCROLL_BUT)&&(ttb.philight->num==-1)){
            h= TTBI_TB_TAB_HSL;
          }
          draw_img(cr, &(ttb.img[h]), ttb.xscleft, p->bary1, 0 );
        }
        if( !ttb.islast_tab_shown ){
          ttb.xscright= ttb.barwidth-ttb.img[TTBI_TB_TAB_NSR].width;
          h= TTBI_TB_TAB_NSR;
          if( (ttb.philight != NULL)&&(ttb.philight==ttb.phipress)&&(ttb.philight->flags==TTBF_SCROLL_BUT)&&(ttb.philight->num==1)){
            h= TTBI_TB_TAB_HSR;
          }
          draw_img(cr, &(ttb.img[h]), ttb.xscright, p->bary1, 0 );
        }
      }
    }else{
      //buttons
      if( need_redraw( event, p->imgx, p->imgy, p->barx2, p->bary2) ){
        h= TTBI_NORMAL;
        grayed= 0;
        if( (p->flags & TTBF_GRAYED) != 0){
          if( p->img[TTBI_DISABLED].fname != NULL ){
            h= TTBI_DISABLED;
          }else{
            grayed= 1; //no disabled image, gray it
          }
        }
        draw_img(cr, &(p->img[h]), p->imgx, p->imgy, grayed );
      }
    }
  }
  cairo_destroy(cr);
  return TRUE;
}

static gboolean ttb_mousemotion_ev( GtkWidget *widget, GdkEventMotion *event )
{
  int x, y, nx, xhi;
  GdkModifierType state;
  struct toolbar_node * p;

  if(event->is_hint){
    gdk_window_get_pointer (event->window, &x, &y, &state);
  }else{
    x = event->x;
    y = event->y;
    state = event->state;
  }
  if( (state & GDK_BUTTON1_MASK) == 0 ){
    ttb.phipress= NULL;
  }
  p= getButtonFromXY(x, y);
  if( p != ttb.philight ){
    //hilight changed
    redraw_button(ttb.philight); //redraw prev button
    ttb.philight= p;
    redraw_button(ttb.philight); //redraw new button
    //update tooltip text
    set_hilight_tooltip(widget);
  }
  return TRUE;
}

static gboolean ttb_mouseleave_ev(GtkWidget *widget, GdkEventCrossing *event)
{
  UNUSED(event);
  if(ttb.philight != NULL){
    //force hilight and tooltip OFF
    redraw_button(ttb.philight); //redraw button
    ttb.philight= NULL;
    gtk_widget_set_tooltip_text(widget, "");
  }
  return FALSE;
}

//ntoolbar=0: HORIZONTAL
//ntoolbar=1: VERTICAL
static void create_tatoolbar( GtkWidget *vbox, int ntoolbar )
{
  if( ntoolbar < NTOOLBARS){
    ttb.drawing_area = gtk_drawing_area_new();
    ttb.draw[ntoolbar]= ttb.drawing_area;
    gtk_widget_set_size_request(ttb.drawing_area, -1, 1);
    gtk_widget_set_events(ttb.drawing_area, GDK_EXPOSURE_MASK|GDK_LEAVE_NOTIFY_MASK|
      GDK_POINTER_MOTION_MASK|GDK_BUTTON_PRESS_MASK|GDK_BUTTON_RELEASE_MASK );
    signal(ttb.drawing_area, "size-allocate",        ttb_size_ev);
    signal(ttb.drawing_area, "expose_event",         ttb_paint_ev);
    signal(ttb.drawing_area, "leave-notify-event",   ttb_mouseleave_ev);
    signal(ttb.drawing_area, "motion_notify_event",  ttb_mousemotion_ev);
    signal(ttb.drawing_area, "scroll-event",         ttb_scrollwheel_ev);
    signal(ttb.drawing_area, "button-press-event",   ttb_button_ev);
    signal(ttb.drawing_area, "button-release-event", ttb_button_ev);
    gtk_box_pack_start(GTK_BOX(vbox), ttb.drawing_area, FALSE, FALSE, 0);
  }
}

static void show_tatoolbar(int show)
{
  if( show ){
    //show current toolbar
    gtk_widget_show( ttb.drawing_area );
    //hide the other toolbar
    if( ttb.drawing_area == ttb.draw[0] ){
      gtk_widget_hide( ttb.draw[1] );
    }else{
      gtk_widget_hide( ttb.draw[0] );
    }
    gtk_widget_queue_draw(ttb.drawing_area); //force redraw
  }else{
    //hide all toolbars
    gtk_widget_hide( ttb.draw[0] );
    gtk_widget_hide( ttb.draw[1] );
  }
}

//-------------------------------------------------------------------
/** `toolbar.new(barsize,buttonsize,imgsize,isvertical,imgpath)` Lua function. */
static int ltoolbar_new(lua_State *L) {
  int i;
  char str[32];
  //destroy current toolbar (if any)
  kill_tatoolbar();

  ttb.isvertical= lua_toboolean(L, 4);

  if( !lua_isnone(L, 5) ){ //image base
    ttb.img_base= alloc_str(luaL_checkstring(L, 5));
  }
  //default toolbar images
  set_tb_img( NULL, TTBI_TB_HILIGHT,   "ttb-back-hi");
  set_tb_img( NULL, TTBI_TB_HIPRESSED, "ttb-back-press");
  if( ttb.isvertical ){
    set_tb_img( NULL, TTBI_TB_SEPARATOR, "ttb-hsep" );
  }else{
    set_tb_img( NULL, TTBI_TB_SEPARATOR, "ttb-vsep" );
  }

  //3 images per tab state: beging, middle, end
  strcpy( str, "ttb-#tab#" );
  for( i= 0; i < 3; i++){
    str[8]= '1'+i;
    str[4]= 'n';
    set_tb_img( NULL, TTBI_TB_NTAB1+i, str ); //normal
    str[4]= 'd';
    set_tb_img( NULL, TTBI_TB_DTAB1+i, str ); //disabled
    str[4]= 'h';
    set_tb_img( NULL, TTBI_TB_HTAB1+i, str ); //hilight
    str[4]= 'a';
    set_tb_img( NULL, TTBI_TB_ATAB1+i, str ); //active
  }
  //set_tb_img( NULL, TTBI_TB_TABBACK, "ttb-tab-back" );   //tab background
  set_tb_img( NULL, TTBI_TB_TAB_NSL,    "ttb-tab-sl"    ); //normal tab scroll left
  set_tb_img( NULL, TTBI_TB_TAB_NSR,    "ttb-tab-sr"    ); //normal tab scroll right
  set_tb_img( NULL, TTBI_TB_TAB_HSL,    "ttb-tab-hsl"   ); //hilight tab scroll left
  set_tb_img( NULL, TTBI_TB_TAB_HSR,    "ttb-tab-hsr"   ); //hilight tab scroll right
  set_tb_img( NULL, TTBI_TB_TAB_NCLOSE, "ttb-tab-close" ); //normal close button   
  set_tb_img( NULL, TTBI_TB_TAB_HCLOSE, "ttb-tab-hclose"); //hilight close button
  set_tb_img( NULL, TTBI_TB_TAB_CHANGED,"ttb-tab-chg"   ); //change indicator


  ttb.barheight= -1;
  ttb.barwidth= -1;
  ttb.xmargin= 1;
  ttb.ymargin= 1;
  if( ttb.isvertical ){
    ttb.drawing_area= ttb.draw[1];	//use toolbar 1 = vertical
    ttb.barwidth= lua_tointeger(L, 1);
    ttb.ymargin= 2;
  }else{
    ttb.drawing_area= ttb.draw[0];  //use toolbar 0 = horizontal
    ttb.barheight= lua_tointeger(L, 1);
    ttb.xmargin= 2;
  }
  //default: square buttons
  ttb.bwidth= lua_tointeger(L, 2);
  ttb.bheight= ttb.bwidth;
  ttb.xoff= (ttb.bwidth - lua_tointeger(L, 3))/2;
  if( ttb.xoff < 0){
    ttb.xoff= 0;
  }
  ttb.yoff= ttb.xoff;
  ttb.xnew= ttb.xmargin;
  ttb.ynew= ttb.ymargin;
  gtk_widget_set_size_request(ttb.drawing_area, ttb.barwidth, ttb.barheight);
  return 0;
}

/** `toolbar.adjust(bwidth,bheight,xmargin,ymargin,xoff,yoff)` Lua function. */
static int ltoolbar_adjust(lua_State *L) {
  ttb.bwidth=  lua_tointeger(L, 1);
  ttb.bheight= lua_tointeger(L, 2);
  ttb.xmargin= lua_tointeger(L, 3);
  ttb.ymargin= lua_tointeger(L, 4);
  ttb.xoff=    lua_tointeger(L, 5);
  ttb.yoff=    lua_tointeger(L, 6);
  ttb.xnew= ttb.xmargin;
  ttb.ynew= ttb.ymargin;
  return 0;
}

/** `toolbar.addbutton(name,tooltiptext)` Lua function. */
static int ltoolbar_addbutton(lua_State *L) {
  const char *name= luaL_checkstring(L, 1);
  add_ttb_node( name, name, luaL_checkstring(L, 2));
  return 0;
}

/** `toolbar.addspace(space,hidebar)` Lua function. */
static int ltoolbar_addspace(lua_State *L) {
  struct toolbar_node * p;
  int asep;
  int x= lua_tointeger(L, 1);
  int hide= lua_toboolean(L,2);
  if( ttb.isvertical ){
    if( x == 0 ){
      x= ttb.bheight/2;
    }
    if( !hide ){
      //show H separator in the middle
      p= add_ttb_node( NULL, ttb.img[TTBI_TB_SEPARATOR].fname, NULL);
      if( p != NULL ){
        asep= ttb.img[TTBI_TB_SEPARATOR].height; //minimun separator = image height
        if( x < asep ){
          x= asep;
        }
        ttb.ynew -= ttb.bheight;
        p->imgx= ttb.xnew;
        p->imgy= ttb.ynew + ((x-asep)/2);
        p->bary2= ttb.ynew + x;
      }
    }
    ttb.ynew += x;
  }else{
    if( x == 0 ){
      x= ttb.bwidth/2;
    }
    if( !hide ){
      //show V separator in the middle
      p= add_ttb_node( NULL, ttb.img[TTBI_TB_SEPARATOR].fname, NULL);
      if( p != NULL ){
        asep= ttb.img[TTBI_TB_SEPARATOR].width; //minimun separator = image width
        if( x < asep ){
          x= asep;
        }
        ttb.xnew -= ttb.bwidth;
        p->imgx= ttb.xnew + ((x-asep)/2);
        p->imgy= ttb.ynew;
        p->barx2= ttb.xnew + x;
      }
    }
    ttb.xnew += x;
  }
  return 0;
}

/** `toolbar.gotopos(x,y)` Lua function. */
/** `toolbar.gotopos(dx)`  Lua function. */
static int ltoolbar_gotopos(lua_State *L) {
  int x,y;
  x= lua_tointeger(L, 1);
  if( lua_isnone(L, 2) ){
    //only one parameter: new row/column
    if( ttb.isvertical ){
      //new column
      x= ttb.xnew + ttb.bwidth + x;
      y= ttb.ymargin;
    }else{
      //new row
      y= ttb.ynew + ttb.bheight + x;
      x= ttb.xmargin;
    }
  }else{
    //2 parameters: x,y
    y= lua_tointeger(L, 2);
  }
  ttb.xnew= x;
  ttb.ynew= y;
  return 0;
}

/** `toolbar.show(show)` Lua function. */
static int ltoolbar_show(lua_State *L) {
  show_tatoolbar(lua_toboolean(L,1));
  return 0;
}

/** `toolbar.enable(name,isenabled)` Lua function. */
static int ltoolbar_enable(lua_State *L) {
  const char *name= luaL_checkstring(L, 1);
  ttb_enable_button(name, lua_toboolean(L,2) );
  return 0;
}

/** `toolbar.seticon(name,icon,[nicon])` Lua function. */
static int ltoolbar_seticon(lua_State *L) {
  const char *name= luaL_checkstring(L, 1);
  const char *img= luaL_checkstring(L, 2);
  ttb_change_button_img(name, lua_tointeger(L, 3), img );
  return 0;
}

/** `toolbar.addtabs(xmargin,xsep,withclose,mod-show,fontsz,fontyoffset)` Lua function. */
static int ltoolbar_addtabs(lua_State *L) {
  cairo_t * cr;
  cairo_text_extents_t ext;
  int i, rgb;
  if( ttb.tab_node == NULL ){ //only one tabbar for now
    ttb.tab_node= add_ttb_node( NULL, NULL, NULL);
    if( ttb.tab_node != NULL ){
      ttb.tab_node->flags |= TTBF_TABBAR|TTBF_SELECTABLE;	//show tabs here
      ttb.tabxmargin= lua_tointeger(L, 1);
      ttb.tabxsep= lua_tointeger(L, 2);

      ttb.tabmodshow= lua_tointeger(L, 4);
      
      ttb.tabfontsz= lua_tointeger(L, 5);  //font size in points (default = 10 points)
      if( ttb.tabfontsz < 2){
        ttb.tabfontsz= 10;
      }
      cr= gdk_cairo_create(ttb.drawing_area->window);
      cairo_set_font_size(cr, ttb.tabfontsz); 
      cairo_text_extents( cr, "H", &ext );
      ttb.tabtexth= (int) ext.height;
      cairo_destroy(cr);
      
      ttb.tabtextoff= lua_tointeger(L, 6);
      //center text verticaly + offset
      ttb.tabtexty=  ((ttb.img[TTBI_TB_NTAB1].height+ttb.tabtexth)/2)+ttb.tabtextoff; 
      if( ttb.tabtexty < 0){
        ttb.tabtexty= 0;
      }
      
      calc_tabnode_width();
      ttb.tab_node->bary1 -= ttb.ymargin;
      ttb.tabheight= 0; //use the tallest image
      for(i= TTBI_TB_TABBACK; i <= TTBI_TB_ATAB3; i++ ){
        if( ttb.tabheight < ttb.img[i].height ){
          ttb.tabheight= ttb.img[i].height;
        }
      }
      ttb.tab_node->bary2= ttb.tab_node->bary1 + ttb.tabheight;
      ttb.closeintabs= lua_toboolean(L,3);
      redraw_button(NULL); //redraw the complete toolbar
    }
  }
  return 0;
}

static double rgb2double(int color)
{
  return ((double)(color & 0x0FF))/255.0;
}

static void settabcolor(lua_State *L, int ncolor, struct color3doubles *pc )
{
  int rgb;
  if( !lua_isnone(L, ncolor) ){
    rgb= lua_tointeger(L, ncolor);
    pc->R= rgb2double(rgb >> 16);
    pc->G= rgb2double(rgb >> 8);
    pc->B= rgb2double(rgb);
  }
}

/** `toolbar.tabfontcolor(NORMcol,HIcol,ACTIVEcol,MODIFcol,GRAYcol)` Lua function. */
static int ltoolbar_tabfontcolor(lua_State *L) {
  redraw_tabs_beg();
  ttb.tabtextcolN.R= 0.0;   //normal: default black
  ttb.tabtextcolN.G= 0.0;
  ttb.tabtextcolN.B= 0.0;
  settabcolor( L, 1, &ttb.tabtextcolN );
  ttb.tabtextcolH= ttb.tabtextcolN;   //hilight: default == normal 
  settabcolor( L, 2, &ttb.tabtextcolH );
  ttb.tabtextcolA= ttb.tabtextcolH;   //active: default == hilight 
  settabcolor( L, 3, &ttb.tabtextcolA );
  ttb.tabtextcolM= ttb.tabtextcolN;   //modified: default == normal 
  settabcolor( L, 4, &ttb.tabtextcolM );
  ttb.tabtextcolG.R= 0.5;     //grayed: default medium gray
  ttb.tabtextcolG.G= 0.5;
  ttb.tabtextcolG.B= 0.5;
  settabcolor( L, 5, &ttb.tabtextcolG );
  redraw_tabs_end();
  return 0;
}

/** `toolbar.settab(num,name,tooltiptext)` Lua function. */
static int ltoolbar_settab(lua_State *L) {
  set_ttb_tab( lua_tointeger(L, 1), luaL_checkstring(L, 2), luaL_checkstring(L, 3));
  return 0;
}

/** `toolbar.deletetab(num)` Lua function. */
static int ltoolbar_deletetab(lua_State *L) {
  struct toolbar_node *k, *kprev, *p, *prev;
  int ntab= lua_tointeger(L, 1);
  kprev= NULL;
  k= get_ttb_tab(ntab);
  if( k != NULL ){
    redraw_tabs_beg();
    prev= NULL;
    for( p= ttb.tabs; (p != NULL); p= p->next ){
      if( p->num == ntab){
        kprev= prev;
      }else if( p->num > ntab){
        p->num--; //decrement bigger "num"s
      }
      prev= p;
    }    
    //kill node
    if( kprev == NULL ){
      ttb.tabs= k->next;
    }else{
      kprev->next= k->next;
    }
    ttb.ntabs--;
    ttb.tabwidth -= k->barx2;
    kill_toolbar_node(k);
    redraw_tabs_end();
  }
  return 0;
}

/** `toolbar.activatetab(num)` Lua function. */
static int ltoolbar_activatetab(lua_State *L) {
  activate_ttb_tab( lua_tointeger(L, 1));
  return 0;
}

/** `toolbar.enabletab(num,enable)` Lua function. */
static int ltoolbar_enabletab(lua_State *L) {
  enable_ttb_tab( lua_tointeger(L, 1), lua_toboolean(L,2));
  return 0;
}

/** `toolbar.modifiedtab(num,changed)` Lua function. */
static int ltoolbar_modifiedtab(lua_State *L) {
  set_changed_ttb_tab( lua_tointeger(L, 1), lua_toboolean(L,2));
  return 0;
}

static void register_toolbar(lua_State *L) {
  lua_newtable(L);
  l_setcfunction(L, -1, "new",      ltoolbar_new);	      //create a new toolbar
  l_setcfunction(L, -1, "adjust",   ltoolbar_adjust);	    //optionaly fine tune some parameters
  l_setcfunction(L, -1, "addbutton",ltoolbar_addbutton);  //add buttons
  l_setcfunction(L, -1, "addspace", ltoolbar_addspace);   //add some space
  l_setcfunction(L, -1, "gotopos",  ltoolbar_gotopos);	  //change next button position
  l_setcfunction(L, -1, "show",     ltoolbar_show);	      //show/hide toolbar
  l_setcfunction(L, -1, "enable",   ltoolbar_enable);	    //enable/disable a button
  l_setcfunction(L, -1, "seticon",  ltoolbar_seticon);	  //change a button or TOOLBAR icon
  l_setcfunction(L, -1, "addtabs",  ltoolbar_addtabs);    //show tabs in the toolbar
  l_setcfunction(L, -1, "tabfontcolor", ltoolbar_tabfontcolor); //change default tab font color
  l_setcfunction(L, -1, "settab",   ltoolbar_settab);     //set tab n
  l_setcfunction(L, -1, "deletetab",ltoolbar_deletetab);  //delete tab n
  l_setcfunction(L, -1, "activatetab", ltoolbar_activatetab); //activate tab n
  l_setcfunction(L, -1, "enabletab", ltoolbar_enabletab); //enable/disable tab n
  l_setcfunction(L, -1, "modifiedtab", ltoolbar_modifiedtab); //show/hide changed indicator in tab n
  lua_setglobal(L, "toolbar");
}
