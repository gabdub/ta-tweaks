/* TA toolbar */

//#define UNUSED(expr) do { (void)(expr); } while (0)

//flags
#define TTBF_SELECTABLE	0x0001
#define TTBF_GRAYED		0x0002

//images
#define TTBI_BACKGROUND		0 //toolbar
#define TTBI_NORMAL			0 //button
#define TTBI_DISABLED		1 //button
#define TTBI_HILIGHT		2 //button/toolbar
#define TTBI_HIPRESSED		3 //button/toolbar
#define TTBI_SEPARATOR		4 //toolbar
#define TTBI_N				5

struct toolbar_img
{
  char * fname;
  int  width;
  int  height;
};

struct toolbar_node
{
	struct toolbar_node * next;
	int flags;		//TTBF_.. flags
	char * name;
	char * tooltip;
	int barx1, bary1;
	int barx2, bary2;
	int imgx, imgy;
	struct toolbar_img img[TTBI_N];
};

#define NTOOLBARS 2
static struct toolbar_data
{
	GtkWidget *draw[NTOOLBARS];	//horizonal & vertical toolbar

	GtkWidget *drawing_area;	//current toolbar

	struct toolbar_node * list;
	struct toolbar_node * list_last;

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

	struct toolbar_node * philight;
	struct toolbar_node * phipress;

	char * img_base;
	struct toolbar_img img[TTBI_N];
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

  if( (nimg < 0)||(nimg >= TTBI_N)){
    return 0; //invalid image num
  }
  if( p == NULL ){
    pti= &(ttb.img[nimg]); //toolbar img
  }else{
    if( nimg == TTBI_SEPARATOR ){
	  nimg= TTBI_NORMAL;
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
    //redraw the area of one button
    gtk_widget_queue_draw_area(ttb.drawing_area, p->barx1, p->bary1, p->barx2-p->barx1+1, p->bary2-p->bary1+1 ); //redraw
  }else{
    //redraw the toolbar
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
		for(i= 0; (i < TTBI_N); i++){
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

static void kill_tatoolbar( void )
{
  struct toolbar_node * p;
  int i;
  while(ttb.list != NULL){
	p= ttb.list;
	ttb.list= ttb.list->next;
	if(p->name != NULL){
	  free((void*)p->name);
	}
	if(p->tooltip != NULL){
	  free((void*)p->tooltip);
	}
	for(i= 0; (i < TTBI_N); i++){
	  if( p->img[i].fname != NULL ){
	    free((void*)p->img[i].fname);
	  }
	}
	free((void*)p);
  }
  ttb.list_last= NULL;
  ttb.philight= NULL;
  ttb.phipress= NULL;

  if( ttb.img_base != NULL ){
	free((void *)ttb.img_base);
    ttb.img_base= NULL;
  }
  for(i= 0; (i < TTBI_N); i++){
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
  int nx;
  for( p= ttb.list, nx=0; (p != NULL); p= p->next, nx++ ){
    //ignore non selectable things (like separators)
	if( ((p->flags & TTBF_SELECTABLE)!=0) && (x >= p->barx1) && (x <= p->barx2) && (y >= p->bary1) && (y <= p->bary2) ){
      return p;
    }
  }
  return NULL;  //invalid
}

/*static struct toolbar_node * getButtonFromPos(int nx)*/
/*{*/
  /*struct toolbar_node * p= ttb.list;*/
  /*while( (nx >= 0) && (p != NULL) ){*/
	/*if(nx == 0){*/
	  /*return p;*/
	/*}*/
	/*nx--;*/
    /*p= p->next;*/
  /*}*/
  /*return NULL;*/
/*}*/

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

static gboolean ttb_button_ev(GtkWidget *widget, GdkEventButton *event, void*__)
{
  struct toolbar_node * p;
  UNUSED(__);
  if( event->button == 1 ){
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
        lL_event(lua, "toolbar_clicked", LUA_TSTRING, p->name, -1);
      }else{
  	    redraw_button(p); 			  //redraw button under mouse (if any)
	    redraw_button(ttb.philight);  //redraw hilighted button (if any)
	  }
      ttb.phipress= NULL;
      return TRUE;
    }
    if(event->type == GDK_2BUTTON_PRESS){ //double click
      return TRUE;
    }
  }
  return FALSE;
}

static gboolean ttb_scrollwheel_ev(GtkWidget *widget, GdkEvent* event, void*__)
{
    UNUSED(event);
    UNUSED(__);
    gtk_widget_queue_draw(widget); //TEST force complete redraw
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

static void draw_fill_img( cairo_t *ctx, struct toolbar_img *pti, int w, int h )
{
  if( pti->fname != NULL ){
    cairo_surface_t *img= cairo_image_surface_create_from_png(pti->fname);
    if( img != NULL ){
	  cairo_save(ctx);
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

static gboolean ttb_paint_ev(GtkWidget *widget, GdkEventExpose *event, void*__)
{
  UNUSED(__);
  struct toolbar_node * p;
  struct toolbar_img *pti;
  int h, grayed;

  cairo_t *cr = gdk_cairo_create(widget->window);
  //draw background image (if any)
  draw_fill_img(cr, &(ttb.img[TTBI_BACKGROUND]), widget->allocation.width, widget->allocation.height );
  //draw hilight (under buttons)
  p= ttb.philight;
  if( (p != NULL) && need_redraw(event, p->barx1, p->bary1, p->barx2, p->bary2) ){
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
  //draw all button images
  for( p= ttb.list; (p != NULL); p= p->next ){
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
  cairo_destroy(cr);
  return TRUE;
}

static gboolean ttb_mousemotion_ev( GtkWidget *widget, GdkEventMotion *event )
{
  int x, y, nx, xhi;
  GdkModifierType state;
  struct toolbar_node * p;
  char *tooltip;

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
	tooltip= "";
	if(p != NULL){
      if(p->tooltip != NULL){
	    tooltip= p->tooltip;
      }
    }
	gtk_widget_set_tooltip_text(widget, tooltip);
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
  //destroy current toolbar (if any)
  kill_tatoolbar();

  ttb.isvertical= lua_toboolean(L, 4);

  if( !lua_isnone(L, 5) ){ //image base
    ttb.img_base= alloc_str(luaL_checkstring(L, 5));
  }
  //default toolbar images
  set_tb_img( NULL, TTBI_HILIGHT,   "ttb-back-hi");
  set_tb_img( NULL, TTBI_HIPRESSED, "ttb-back-press");
  if( ttb.isvertical ){
    set_tb_img( NULL, TTBI_SEPARATOR, "ttb-hsep" );
  }else{
    set_tb_img( NULL, TTBI_SEPARATOR, "ttb-vsep" );
  }

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
	  p= add_ttb_node( NULL, ttb.img[TTBI_SEPARATOR].fname, NULL);
	  if( p != NULL ){
	    asep= ttb.img[TTBI_SEPARATOR].height; //minimun separator = image height
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
	  p= add_ttb_node( NULL, ttb.img[TTBI_SEPARATOR].fname, NULL);
	  if( p != NULL ){
	    asep= ttb.img[TTBI_SEPARATOR].width; //minimun separator = image width
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

static void register_toolbar(lua_State *L) {
  lua_newtable(L);
  l_setcfunction(L, -1, "new",      ltoolbar_new);	     //create a new toolbar
  l_setcfunction(L, -1, "adjust",   ltoolbar_adjust);	 //optionaly fine tune some parameters
  l_setcfunction(L, -1, "addbutton",ltoolbar_addbutton); //add buttons
  l_setcfunction(L, -1, "addspace", ltoolbar_addspace);  //add some space
  l_setcfunction(L, -1, "gotopos",  ltoolbar_gotopos);	 //change next button position
  l_setcfunction(L, -1, "show",     ltoolbar_show);	     //show/hide toolbar
  l_setcfunction(L, -1, "enable",   ltoolbar_enable);	 //enable/disable a button
  l_setcfunction(L, -1, "seticon",  ltoolbar_seticon);	 //change a button or TOOLBAR icon
  lua_setglobal(L, "toolbar");
}
