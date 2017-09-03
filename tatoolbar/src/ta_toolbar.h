// Copyright 2016-2017 Gabriel Dubatti. See LICENSE.
/*
    ta_toolbar.h
    ============
    TA  toolbar
*/
#ifndef __TA_TOOLBAR__
#define __TA_TOOLBAR__

//ntoolbar=0: HORIZONTAL  (top)
//ntoolbar=1: VERTICAL    (left)
//ntoolbar=2: HORIZONTAL  (bottom)
//ntoolbar=3: VERTICAL    (right)
//ntoolbar=4: VERTICAL    (POPUP)
#define STAT_TOOLBAR      2
#define POPUP_FIRST       4
#define NTOOLBARS         5

// toolbar -> group -> items

//item flags
#define TTBF_SELECTABLE     0x00000001  //accepts click
#define TTBF_HIDDEN         0x00000002  //not shown
#define TTBF_TEXT           0x00000004  //it's a text button
#define TTBF_GRAYED         0x00000008  //show as disabled (grayed)
#define TTBF_ACTIVE         0x00000010  //show as active
#define TTBF_CHANGED        0x00000020  //show as changed
#define TTBF_TAB            0x00000040  //it's a tab
#define TTBF_CLOSETAB_BUT   0x00000080  //it's a close tab button
#define TTBF_SCROLL_BUT     0x00000100  //it's a scroll button
#define TTBF_TEXT_LEFT      0x00000200  //draw text left aligned (default = center)
#define TTBF_TEXT_BOLD      0x00000400  //draw text in bold
//group flags
#define TTBF_GRP_TABBAR     0x00010000  //tabs group
#define TTBF_GRP_DRAGTAB    0x00020000  //tab dragging enabled in TTBF_TABBAR
#define TTBF_GRP_AUTO       0x00040000  //auto created default group
#define TTBF_GRP_LEFT       0x00080000  //anchor group to the left
#define TTBF_GRP_RIGHT      0x00100000  //anchor group to the right
#define TTBF_GRP_TOP        0x00200000  //anchor group to the top
#define TTBF_GRP_BOTTOM     0x00400000  //anchor group to the bottom
#define TTBF_GRP_VAR_W      0x00800000  //this group has variable width
#define TTBF_GRP_VAR_H      0x01000000  //this group has variable height
#define TTBF_GRP_ITEM_W     0x02000000  //this group set width using items position
#define TTBF_GRP_ITEM_H     0x04000000  //this group set height using items position
#define TTBF_GRP_VSCROLL    0x08000000  //this group shows a vertical scrollbar when needed

//item images
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
#define TTBI_TB_TXT_HIL1    24 //hilight text button1
#define TTBI_TB_TXT_HIL2    25 //hilight text button2
#define TTBI_TB_TXT_HIL3    26 //hilight text button3
#define TTBI_TB_TXT_HPR1    27 //hi-pressed text button1
#define TTBI_TB_TXT_HPR2    28 //hi-pressed text button2
#define TTBI_TB_TXT_HPR3    29 //hi-pressed text button3
#define TTBI_TB_HINORMAL    30 //normal button back
#define TTBI_TB_TXT_NOR1    31 //normal text button1 back
#define TTBI_TB_TXT_NOR2    32 //normal text button2 back
#define TTBI_TB_TXT_NOR3    33 //normal text button3 back
#define TTBI_TB_N           34

#define BKCOLOR_NOT_SET (-1)  //background color = not set

#define BKCOLOR_PICKER  (-2)  //background color = HSV color picker
#define HSV_V_DELTA     0.05
#define PICKER_VSCROLLW   8   //Vscroll width
#define PICKER_MARG_TOP   1
#define PICKER_MARG_BOTT  1
#define PICKER_MARG_LEFT  1
#define PICKER_MARG_RIGHT 1   //Vscroll separation
#define PICKER_CELL_W   60    //total w=250 = 60x4 + 1 + 1 + 8
#define PICKER_CELL_H   30    //total h=242 = 60x4 + 1 + 1

#define BKCOLOR_SEL_COLOR  (-3)  //background color = chosen color in color picker, shows the color in hex
#define BKCOLOR_SEL_COL_R  (-4)  //background color = RED, shows the chosen color, RED part in hex
#define BKCOLOR_SEL_COL_G  (-5)  //same with GREEN part (scroll-wheel to edit)
#define BKCOLOR_SEL_COL_B  (-6)  //same with BLUE part

struct toolbar_img
{
  char * fname;
  int  width;
  int  height;
};

struct color3doubles
{
  double R;
  double G;
  double B;
};

struct area
{
  int x0,y0,x1,y1;
};

struct toolbar_item
{
  struct toolbar_item * next;     //items list
  struct toolbar_group * group;   //parent
  int flags;          //TTBF_..
  int num;            //number of a tab
  char * name;        //name of a button
  char * text;        //text shown (tab/text button)
  char * tooltip;     //tooltip text

  int barx1, bary1;   //item positions are relatives to the parent
  int barx2, bary2;

  int imgx, imgy;
  int textwidth;      //text width in pixels
  int changewidth;    //0=use text width, >0=use this value in pixels, <0= % of toolbar.width
  int minwidth;       //min tab width
  int maxwidth;       //max tab width
  int prew, postw;    //pre and post width (used in tabs and buttons)
  struct toolbar_img img[TTBI_NODE_N];
  int back_color;     //-1:not set, 0x00RRGGBB
};

struct toolbar_group
{
  struct toolbar_group  * next;     //groups list
  struct toolbar_data   * toolbar;  //parent
  int num;                //number of group
  int isvertical;         //is a vertical group
  int flags;              //TTBF_GRP_...

  struct toolbar_item   * list; //group's items list (like tabs)
  struct toolbar_item   * list_last;

  int barx1, bary1;
  int barx2, bary2;

  int changeheight;       //>0=use this value in pixels, <0= % of toolbar.height
  int minheight;          //0 or min height
  int maxheight;          //0 or max height

  int changewidth;        //>0=use this value in pixels, <0= % of toolbar.width
  int minwidth;           //0 or min width
  int maxwidth;           //0 or max width

  int nitems;             //total number of items
  int nitems_nothidden;   //number of items without HIDDEN flag
  int nitems_expand;      //number of items that expand to use all the free space
  int nitems_scroll;      //number of items not shown at the left = scroll support
  int islast_item_shown;
  int try_scrollpack;     //after item delete try to scroll left
  int scleftx1, scleftx2; //left/top scroll button position (scleftx1 < 0 if hidden)
  int sclefty1, sclefty2;
  int scrightx1, scrightx2;//right/bottom scroll button position (scrightx1 < 0 if hidden)
  int scrighty1, scrighty2;

  //group defaults
  int bwidth;             //button width
  int bheight;            //button height
  int xmargin;
  int ymargin;
  int xoff;               //image pos offset
  int yoff;
  int xnew;               //next item position
  int ynew;

  //text buttons
  int txtfontsz;  //font size in points (default = 12 points)
  int txttexth;   //font height
  int txttextoff; //font y offset
  int txttexty;   //font baseline y pos
  struct color3doubles txttextcolN; //normal
  struct color3doubles txttextcolG; //grayed

  //tabs
  int tabxmargin;
  int tabxsep;    //< 0 == overlap
  int tabheight;
  int tabwidth;   //total 'fixed' tab width without extra space
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

  //tab defaults
  int tabchangewidth;    //0=use text width, >0=use this value in pixels, <0= % of toolbar.width
  int tabminwidth;       //min tab width
  int tabmaxwidth;       //max tab width

  //group images (use toolbar images if NULL)
  struct toolbar_img img[TTBI_TB_N];
  int back_color;     //-1:not set, 0x00RRGGBB
  int yvscroll;         //vertical scrollbar offset
};

struct toolbar_data
{
  void * win;           //GtkWidget = POPUP Window or NULL
  void * draw;          //GtkWidget = *drawing_area of this toolbar
  int num;              //number of toolbar
  int isvertical;       //is a vertical toolbar (#1=yes)
  int isvisible;
  int redrawlater;      //flag: hold updates for now.. redraw later

  struct toolbar_group * group;
  struct toolbar_group * group_last;
  struct toolbar_group * curr_group;  //current BUTTON group
  struct toolbar_group * tab_group;   //current TAB group

  int ngroups;        //total number of groups
  int currentgroup;   //current group num: 0...

  int barheight;      //actual toolbar size
  int barwidth;

  //defaults
  int buttonsize;
  int imgsize;

  int _grp_x1,_grp_x2,_grp_y1,_grp_y2;  //group redraw area
  int _layout_chg;

  //toolbar images
  struct toolbar_img img[TTBI_TB_N];
  int back_color;     //-1:not set, 0x00RRGGBB
};

struct color_picker_data
{
  int HSV_x;          //(0..PICKER_CELL_W-1) => H value
  int HSV_y;          //(0..PICKER_CELL_H-1) => S value
  double HSV_val;     //[0.0 .. 1.0] V value of color picker

  int HSV_rgb;        //chosen color in RGB format
  struct toolbar_item * ppicker;  //item that shows the color picker or NULL
  struct toolbar_item * pchosen;  //item that shows the chosen color or NULL
  struct toolbar_item * pchosenR; //item that shows the RED part of the chosen color or NULL
  struct toolbar_item * pchosenG; //same for the GREEN part
  struct toolbar_item * pchosenB; //same for the BLUE part
};

struct all_toolbars_data
{
  struct toolbar_data tbdata[NTOOLBARS]; //horizonal & vertical toolbars

  struct toolbar_item * philight;
  struct toolbar_item * phipress;
  int ntbhilight;     //number of the toolbar with the hilighted button or -1

  int currentntb;     //current toolbar num

  char * img_base;

  struct color_picker_data cpick; //only one global color picker
};
extern struct all_toolbars_data ttb;


/* ============================================================================= */
/* ta_glue.c */
char * alloc_img_str( const char *name );
void redraw_begG( struct toolbar_group *G );
void redraw_endG( struct toolbar_group *G );
void redraw_toolbar( struct toolbar_data *T );
void redraw_group( struct toolbar_group *G );
void redraw_item( struct toolbar_item * p );
void draw_txt( void * gcontext, const char *txt, int x, int y, int y1, int w, int h, struct color3doubles *color, int fontsz, int bold );
void draw_img( void * gcontext, struct toolbar_img *pti, int x, int y, int grayed );
void draw_fill_img( void * gcontext, struct toolbar_img *pti, int x, int y, int w, int h );
void draw_fill_color( void * gcontext, int color, int x, int y, int w, int h );
int  set_pti_img( struct toolbar_img *pti, const char *imgname );
int  set_text_bt_width(struct toolbar_item * p );
int  get_text_width( const char * text, int fontsz );
int  get_text_height( const char * text, int fontsz );
void clear_tooltip_textT( struct toolbar_data *T );
void fire_tab_clicked_event( struct toolbar_item * p );
void set_hilight_tooltipT( struct toolbar_data *T );
void set_toolbar_size(struct toolbar_data *T);
void show_toolbar(struct toolbar_data *T, int show);

/* ============================================================================= */
/* ta_toolbar.c */
const char * get_toolbar_version( void );

char * alloc_str( const char *s );
char * chg_alloc_str( char *sold, const char *snew );
void free_tatoolbar( void );

void ttb_new_toolbar(int num, int barsize, int buttonsize, int imgsize, const char *imgpath);
struct toolbar_group *add_groupT_rcoh(struct toolbar_data *T, int xcontrol, int ycontrol, int hidden);
void ttb_new_tabs_groupT(struct toolbar_data *T, int xmargin, int xsep, int wclose, int modshow, int fntsz, int fntyoff, int wdrag, int xcontrol, int height);
void ttb_show_groupG( struct toolbar_group *G, int show );
struct toolbar_item *add_itemG(struct toolbar_group *G, const char * name, const char * img, const char *tooltip, const char * text, int chwidth);
void update_group_sizeG( struct toolbar_group *G, int redraw );
void ttb_enable_buttonT(struct toolbar_data *T, const char * name, int isenabled );
void ttb_addspaceG(struct toolbar_group * G, int sepsize, int hide);
void ttb_change_button_imgT(struct toolbar_data *T, const char *name, int nimg, const char *img );
void set_color_pick_rgb( int color );
void ttb_set_back_colorT(struct toolbar_data *T, const char *name, int color, int keepback );
void ttb_change_button_tooltipT(struct toolbar_data *T, const char *name, const char *tooltip );
void ttb_change_button_textT(struct toolbar_data *T, const char *name, const char *text );
void ttb_set_text_fontcolG(struct toolbar_group *G, int fntsz, int fntyoff, int ncol, int gcol);
void ttb_set_tab_colorsG(struct toolbar_group *G, int ncol, int hcol, int acol, int mcol, int gcol);
void set_tabtextG(struct toolbar_group *G, int ntab, const char * text, const char *tooltip, int redraw);
int  get_tabtext_widthG(struct toolbar_group *G, const char * text );
void ttb_delete_tabG(struct toolbar_group *G, int ntab);
void ttb_activate_tabG(struct toolbar_group *G, int ntab);
void ttb_enable_tabG(struct toolbar_group *G, int ntab, int enable);
void ttb_set_changed_tabG(struct toolbar_group *G, int ntab, int changed);
void ttb_hide_tabG(struct toolbar_group *G, int ntab, int hide);
void ttb_change_tabwidthG(struct toolbar_group *G, int ntab, int percwidth, int minwidth, int maxwidth );
void ttb_goto_tabG(struct toolbar_group *G, int tabpos);
void update_layoutT( struct toolbar_data *T);
int  need_redraw(struct area * pdrawarea, int x, int y, int xf, int yf);
int  paint_toolbar_back(struct toolbar_data *T, void * gcontext, struct area * pdrawarea);
void paint_group_items(struct toolbar_group *g, void * gcontext, struct area * pdrawarea, int x0, int y0, int wt, int ht, int hibackpainted);
void set_hilight_off( void );
void calc_popup_sizeT( struct toolbar_data *T);

void mouse_leave_toolbar( struct toolbar_data *T );
void mouse_move_toolbar( struct toolbar_data *T, int x, int y );
void scroll_toolbarT(struct toolbar_data *T, int x, int y, int dir );
void color_pick_ev( struct toolbar_item *p, int dir, int redraw );

void init_tatoolbar_vars( void );
struct toolbar_data * init_tatoolbar( int ntoolbar, void * draw, int clearall );
struct toolbar_group * current_buttongrp( void );
struct toolbar_data * current_toolbar( void );
struct toolbar_data * toolbar_from_num(int num);
struct toolbar_data * toolbar_from_widget( void * widget );
struct toolbar_data * toolbar_from_popup( void * win );
struct toolbar_group * group_from_numT(struct toolbar_data *T, int ngrp);
struct toolbar_group * current_group( void );
struct toolbar_group * current_tabbar( void );
struct toolbar_item * item_from_numG(struct toolbar_group *G, int nitem);
struct toolbar_item * item_from_nameG(struct toolbar_group *G, const char *name);
struct toolbar_item * item_from_nameT(struct toolbar_data *T, const char *name);
struct toolbar_item * find_prev_itemG( struct toolbar_group *G, struct toolbar_item * item );
struct toolbar_group * group_fromXYT(struct toolbar_data *T, int x, int y);

extern int item_xoff;
extern int item_yoff;
struct toolbar_item * item_fromXYT(struct toolbar_data *T, int xt, int yt);


int  set_item_img( struct toolbar_item *p, int nimg, const char *imgname );
void setrgbcolor(int rgb, struct color3doubles *pc);
int  get_group_imgW( struct toolbar_group *G, int nimg );
int  get_group_imgH( struct toolbar_group *G, int nimg );
void select_toolbar_n( int num, int ngrp );
void ttb_addbutton( const char *name, const char *tooltip );
void ttb_addtext( const char * name, const char * img, const char *tooltip, const char * text, int chwidth);
void ttb_addlabel( const char * name, const char * img, const char *tooltip, const char * text, int chwidth, int flags );
void ttb_enable( const char * name, int isenabled, int onlythistb );
void ttb_seticon( const char * name, const char *img, int nicon, int onlythistb );
void ttb_setbackcolor( const char * name, int color, int keepback, int onlythistb );
void ttb_settooltip( const char * name, const char *tooltip, int onlythistb );
void ttb_settext( const char * name, const char * text, const char *tooltip, int onlythistb );
void ttb_set_toolbarsize( struct toolbar_data *T, int width, int height);

void toolbar_set_win_title( const char *title );

#endif
