// Copyright 2016-2018 Gabriel Dubatti. See LICENSE.
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
//ntoolbar=3: VERTICAL    (right #2)
//ntoolbar=4: VERTICAL    (right #1)
//ntoolbar=5: VERTICAL    (POPUP:combo-list)
//ntoolbar=6: VERTICAL    (POPUP)
#define STAT_TOOLBAR      2
#define MINIMAP_TOOLBAR   4
#define POPUP_FIRST       5
#define NTOOLBARS         7

// toolbar -> group -> items

//item flags
#define TTBF_SELECTABLE     0x00000001  //accepts click
#define TTBF_HIDDEN         0x00000002  //it's hidden
#define TTBF_TEXT           0x00000004  //it's a text button or icon + text
#define TTBF_GRAYED         0x00000008  //show as disabled (grayed)
#define TTBF_SELECTED       0x00000010  //show as selected / checked / active tab (normal=selected img)
#define TTBF_PRESSED        0x00000020  //show as pressed (background=selected img)
#define TTBF_CHANGED        0x00000040  //show as changed
#define TTBF_TAB            0x00000080  //it's a tab
#define TTBF_TEXT_LEFT      0x00000100  //draw text left aligned (default = center)
#define TTBF_TEXT_BOLD      0x00000200  //draw text in bold
#define TTBF_DROP_BUTTON    0x00000400  //draw a drop down button at the end of a text button
#define TTBF_IS_SEPARATOR   0x00000800  //it's a separator
#define TTBF_SHOW_BORDER    0x00001000  //draw a border (used in text buttons)
#define TTBF_HIDE_BLOCK     0x00002000  //hide a block of items under this item (tree/list expand-collapse)
#define TTBF_IS_HRESIZE     0x00004000  //the button resize the toolbar horizontally
#define TTBF_ANCHOR_END     0x00008000  //anchor the item's right (x2) instead of it's left (x1)
//iternal use item flags
#define TTBF_CLOSETAB_BUT   0x01000000  //highlighted xbutton is a close tab button (internal use)
#define TTBF_SCROLL_BUT     0x02000000  //highlighted xbutton is a scroll button (internal use)
#define TTBF_SCROLL_BAR     0x04000000  //highlighted xbutton is a group scroll bar (internal use)
#define TTBF_XBUTTON        (TTBF_CLOSETAB_BUT|TTBF_SCROLL_BUT|TTBF_SCROLL_BAR)
//group flags
#define TTBF_GRP_SELECTABLE 0x00000001  //accepts click
#define TTBF_GRP_HIDDEN     0x00000002  //it's hidden
#define TTBF_GRP_VERTICAL   0x00000004  //it's vertical
#define TTBF_GRP_TABBAR     0x00000008  //tabs group
#define TTBF_GRP_DRAGTAB    0x00000010  //tab dragging enabled in TTBF_TABBAR
#define TTBF_GRP_AUTO       0x00000020  //auto created default group
#define TTBF_GRP_LEFT       0x00000040  //anchor group to the left
#define TTBF_GRP_RIGHT      0x00000080  //anchor group to the right
#define TTBF_GRP_TOP        0x00000100  //anchor group to the top
#define TTBF_GRP_BOTTOM     0x00000200  //anchor group to the bottom
#define TTBF_GRP_VAR_W      0x00000400  //this group has variable width
#define TTBF_GRP_VAR_H      0x00000800  //this group has variable height
#define TTBF_GRP_ITEM_W     0x00001000  //this group set width using items position
#define TTBF_GRP_ITEM_H     0x00002000  //this group set height using items position
#define TTBF_GRP_VSCROLL    0x00004000  //this group can be scrolled vertically when needed
#define TTBF_GRP_SHOWVSCR   0x00008000  //this group shows a vertical scrollbar when needed
//iternal use group flags
#define TTBF_GRP_TRY_PACK   0x01000000  //after item delete try to scroll left (internal use)
#define TTBF_GRP_LASTIT_SH  0x02000000  //is the last item of the group shown (internal use)
#define TTBF_GRP_VSCR_INH   0x04000000  //inhibit vertical scroll while popup is open
#define TTBF_GRP_HAS_RANCH  0x08000000  //the group has 1 or more right anchored items
//toolbar flags
#define TTBF_TB_VERTICAL    0x00000001  //it's vertical
#define TTBF_TB_VISIBLE     0x00000002  //it's visible
//iternal use toolbar flags
#define TTBF_TB_REDRAW      0x01000000  //hold updates for now.. redraw later (internal use)

//item images
#define TTBI_BACKGROUND     0
#define TTBI_NORMAL         1
#define TTBI_DISABLED       2
#define TTBI_HILIGHT        3 //mouse over
#define TTBI_HIPRESSED      4 //mouse down
#define TTBI_SELECTED       5
#define TTBI_N_IT_IMGS      6

//TTB images
#define TTBI_TB_BACK_BASE     0                                     //TOOLBAR/GROUP
#define TTBI_TB_BACKGROUND    (TTBI_TB_BACK_BASE+TTBI_BACKGROUND)   //background

#define TTBI_TB_SEP_BASE      (TTBI_TB_BACK_BASE+TTBI_N_IT_IMGS)    //SEPARATOR
#define TTBI_TB_HSEPARATOR    (TTBI_TB_SEP_BASE+TTBI_NORMAL)        //horizontal separator
#define TTBI_TB_VSEPARATOR    (TTBI_TB_SEP_BASE+TTBI_SELECTED)      //vertical separator

#define TTBI_TB_BUTTON_BASE   (TTBI_TB_SEP_BASE+TTBI_N_IT_IMGS)     //BUTTON
#define TTBI_TB_BUT_NORMAL    (TTBI_TB_BUTTON_BASE+TTBI_NORMAL)     //shown by text buttons
#define TTBI_TB_BUT_HILIGHT   (TTBI_TB_BUTTON_BASE+TTBI_HILIGHT)
#define TTBI_TB_BUT_HIPRESS   (TTBI_TB_BUTTON_BASE+TTBI_HIPRESSED)

#define TTBI_TB_TAB_BASE      (TTBI_TB_BUTTON_BASE+TTBI_N_IT_IMGS)  //TABS
#define TTBI_TB_TABBACK       (TTBI_TB_TAB_BASE+TTBI_BACKGROUND)    //background
#define TTBI_TB_NTAB          (TTBI_TB_TAB_BASE+TTBI_NORMAL)        //normal
#define TTBI_TB_DTAB          (TTBI_TB_TAB_BASE+TTBI_DISABLED)      //disabled
#define TTBI_TB_HTAB          (TTBI_TB_TAB_BASE+TTBI_HILIGHT)       //highlight
#define TTBI_TB_ATAB          (TTBI_TB_TAB_BASE+TTBI_SELECTED)      //active

#define TTBI_TB_TAB_SL_BASE   (TTBI_TB_TAB_BASE+TTBI_N_IT_IMGS)     //SCROLL LEFT TAB
#define TTBI_TB_TAB_NSL       (TTBI_TB_TAB_SL_BASE+TTBI_NORMAL)
#define TTBI_TB_TAB_HSL       (TTBI_TB_TAB_SL_BASE+TTBI_HIPRESSED)

#define TTBI_TB_TAB_SR_BASE   (TTBI_TB_TAB_SL_BASE+TTBI_N_IT_IMGS)  //SCROLL RIGHT TAB
#define TTBI_TB_TAB_NSR       (TTBI_TB_TAB_SR_BASE+TTBI_NORMAL)
#define TTBI_TB_TAB_HSR       (TTBI_TB_TAB_SR_BASE+TTBI_HIPRESSED)

#define TTBI_TB_TAB_CLOSE_BASE (TTBI_TB_TAB_SR_BASE+TTBI_N_IT_IMGS) //CLOSE TAB
#define TTBI_TB_TAB_NCLOSE    (TTBI_TB_TAB_CLOSE_BASE+TTBI_NORMAL)
#define TTBI_TB_TAB_HCLOSE    (TTBI_TB_TAB_CLOSE_BASE+TTBI_HIPRESSED)

#define TTBI_TB_TAB_CHG_BASE  (TTBI_TB_TAB_CLOSE_BASE+TTBI_N_IT_IMGS) //CHANGED TAB INDICATOR
#define TTBI_TB_TAB_CHANGED   (TTBI_TB_TAB_CHG_BASE+TTBI_NORMAL)

#define TTBI_TB_DDBUT_BASE    (TTBI_TB_TAB_CHG_BASE+TTBI_N_IT_IMGS) //DROP DOWN BUTTON
#define TTBI_TB_DDBUT_NORMAL  (TTBI_TB_DDBUT_BASE+TTBI_NORMAL)
#define TTBI_TB_DDBUT_HILIGHT (TTBI_TB_DDBUT_BASE+TTBI_HILIGHT)
#define TTBI_TB_DDBUT_HIPRESS (TTBI_TB_DDBUT_BASE+TTBI_HIPRESSED)

#define TTBI_TB_CHECK_BASE    (TTBI_TB_DDBUT_BASE+TTBI_N_IT_IMGS)   //CHECK box
#define TTBI_TB_CHECK_OFF     (TTBI_TB_CHECK_BASE+TTBI_NORMAL)      //unchecked
#define TTBI_TB_CHECK_HILIGHT (TTBI_TB_CHECK_BASE+TTBI_HILIGHT)
#define TTBI_TB_CHECK_HIPRESS (TTBI_TB_CHECK_BASE+TTBI_HIPRESSED)
#define TTBI_TB_CHECK_ON      (TTBI_TB_CHECK_BASE+TTBI_SELECTED)    //checked

#define TTBI_TB_RADIO_BASE    (TTBI_TB_CHECK_BASE+TTBI_N_IT_IMGS)   //RADIO box
#define TTBI_TB_RADIO_OFF     (TTBI_TB_RADIO_BASE+TTBI_NORMAL)      //unchecked
#define TTBI_TB_RADIO_HILIGHT (TTBI_TB_RADIO_BASE+TTBI_HILIGHT)
#define TTBI_TB_RADIO_HIPRESS (TTBI_TB_RADIO_BASE+TTBI_HIPRESSED)
#define TTBI_TB_RADIO_ON      (TTBI_TB_RADIO_BASE+TTBI_SELECTED)    //checked

#define TTBI_TB_VERT_SCROLL   (TTBI_TB_RADIO_BASE+TTBI_N_IT_IMGS)   //vertical scrollbar
#define TTBI_TB_VERTSCR_BACK  (TTBI_TB_VERT_SCROLL+TTBI_BACKGROUND) //background
#define TTBI_TB_VERTSCR_NORM  (TTBI_TB_VERT_SCROLL+TTBI_NORMAL)     //normal bar
#define TTBI_TB_VERTSCR_HILIGHT (TTBI_TB_VERT_SCROLL+TTBI_HILIGHT)

#define TTBI_N_TB_IMGS        (TTBI_TB_VERT_SCROLL+TTBI_N_IT_IMGS)


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

#define BKCOLOR_MINIMAP_DRAW  (-7)  //MINI MAP (back draw)
#define BKCOLOR_MINIMAP_CLICK (-8)  //MINI MAP (click)

#define VSCROLL_STEP    100  //vertical scroll whell step

// multi-part IMAGE
//
//  L=left     W=expand         R=right
// +------+--------------------+------+
// |      |                    |      | T=top
// +------+--------------------+------+
// |      |                    |      |
// |      |                    |      |
// |      |                    |      | H=expand
// |      |                    |      |
// |      |                    |      |
// +------+--------------------+------+
// |      |                    |      | B=bottom
// +------+--------------------+------+
//
struct toolbar_img
{
  struct toolbar_img * next;  //linked list
  unsigned long hash;         //hash(fname)

  char * fname;   //filename format: fffff[__[L##][R##][T##][B##]].png
                  //or __[W##] => L=R=(image_width-W)/2
                  //or __[H##] => T=B=(image_height-H)/2

  int  width;     //image width
  int  width_l;   //left fixed part    (__...L##)
  int  width_r;   //right fixed part   (__...R##)
                  //expand width= width - width_l - width_r

  int  height;    //image height
  int  height_t;  //top fixed part     (__...T##)
  int  height_b;  //bottom fixed part  (__...B##)
                  //expand height= height - height_t - height_b

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

  int offx, offy;     //position image/text inside the bar
  int imgx, imgy;     //image position relative to (barx1, bary1)+(offx, offy)
  int txtx, txty;     //text  position relative to (barx1, bary1)+(offx, offy)

  int textwidth;      //text width in pixels
  int changewidth;    //0=use text width, >0=use this value in pixels, <0= % of toolbar.width
  int minwidth;       //min tab width
  int maxwidth;       //max tab width
  int prew, postw;    //pre and post width (used in tabs and buttons)
  struct toolbar_img * img[ TTBI_N_IT_IMGS ];
  int back_color;     //-1:not set, 0x00RRGGBB
  int imgbase;        //0, TTBI_TB_SEP_BASE, TTBI_TB_BUTTON_BASE, TTBI_TB_DDBUT_BASE, TTBI_TB_CHECK_BASE, ...
  int hideblockH;     //height of the block under this item to hide when TTBF_HIDE_BLOCK flag is set
  int hideprev;       //height of all the hidden blocks before this item or -1 if the item is inside a hidden block
  int anchor_right;   //set the distance from item.xleft to toolbar.xright / 0 = left aligned
};

struct toolbar_group
{
  struct toolbar_group  * next;     //groups list
  struct toolbar_data   * toolbar;  //parent
  int num;                //number of group
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
  struct color3doubles tabtextcolH; //highlight
  struct color3doubles tabtextcolA; //active
  struct color3doubles tabtextcolM; //modified
  struct color3doubles tabtextcolG; //grayed

  //tab defaults
  int tabchangewidth;    //0=use text width, >0=use this value in pixels, <0= % of toolbar.width
  int tabminwidth;       //min tab width
  int tabmaxwidth;       //max tab width

  //group images (use toolbar images if NULL)
  struct toolbar_img * img[ TTBI_N_TB_IMGS ];
  int back_color;       //-1:not set, 0x00RRGGBB
  int yvscroll;         //vertical scrollbar offset (+/- VSCROLL_STEP)
  int show_vscroll_w;   //vertical scrollbar width (0=not shown)
  int hideblocks;       //height of all the hidden block in the group
};

struct toolbar_data
{
  void * win;           //GtkWidget = POPUP Window or NULL
  void * draw;          //GtkWidget = *drawing_area of this toolbar
  int num;              //number of toolbar
  int flags;            //TTBF_TB_... flags

  struct toolbar_group * group;
  struct toolbar_group * group_last;
  struct toolbar_group * curr_group;  //current BUTTON group
  struct toolbar_group * tab_group;   //current TAB group
  struct toolbar_group * lock_group;  //inhibit vertical scroll while popup is open

  int ngroups;        //total number of groups
  int currentgroup;   //current group num: 0...

  int barheight;      //actual toolbar size
  int barwidth;

  int min_width;      //minimun width when resizing or 0
  int drag_off;

  //defaults
  int buttonsize;
  int imgsize;

  int _grp_x1,_grp_x2,_grp_y1,_grp_y2;  //group redraw area
  int _layout_chg;

  //toolbar images
  struct toolbar_img * img[ TTBI_N_TB_IMGS ];
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

struct minimap_line
{
  struct minimap_line * next;
  int linenum;
  int color;
};

struct minimap_data
{
  struct minimap_line * lines;    //lines info
  int height;       //visible height in pixels = toolbar height
  int buffnum;      //asociated buffer ID
  int linecount;    //number of buffer's lines
  int yszbox;       //y-size of each box
  int lineinc;      //line increment from box to box
  int boxesheight;  //used height
  int linesscreen;  //number of completely visible lines
  int firstvisible; //number of the line at the top
  int scrcolor;     //scroll box color
};

struct all_toolbars_data
{
  struct toolbar_data tbdata[NTOOLBARS];  //horizonal & vertical toolbars

  struct toolbar_img * img_list;          //linked list of images

  struct toolbar_item * philight;
  struct toolbar_item * phipress;
  struct toolbar_item * pdrag;

  int ntbhilight;     //number of the toolbar with the highlighted button or -1

  int currentntb;     //current toolbar num

  char * img_base;    //global image base path

  struct color_picker_data cpick; //only one global color picker
  struct minimap_data minimap;    //only one global MINI MAP

  int drag_x, drag_y; //initial difference between mouse and item_xoff/yoff position
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
void draw_fill_mp_img( void * gcontext, struct toolbar_img *pti, int x, int y, int w, int h );
void draw_box( void * gcontext, int x, int y, int w, int h, int color, int fill );
void draw_fill_color( void * gcontext, int color, int x, int y, int w, int h );
int  set_img_size( struct toolbar_img *pti );
int  set_text_bt_width(struct toolbar_item * p );
int  get_text_width( const char * text, int fontsz );
int  get_text_height( const char * text, int fontsz );
void clear_tooltip_textT( struct toolbar_data *T );
void fire_tab_clicked_event( struct toolbar_item * p );
void fire_tb_clicked_event( struct toolbar_item * p );
int  fire_tb_Rclicked_event( struct toolbar_item * p );
void fire_tb_2clicked_event( struct toolbar_item * p );
void set_hilight_tooltipT( struct toolbar_data *T );
void set_toolbar_size(struct toolbar_data *T);
void show_toolbar(struct toolbar_data *T, int show, int newsize);

/* ============================================================================= */
/* ta_toolbar.c */
const char * get_toolbar_version( void );

char * alloc_str( const char *s );
char * chg_alloc_str( char *sold, const char *snew );
void free_tatoolbar( void );

void ttb_new_toolbar(int num, int barsize, int buttonsize, int imgsize, const char *imgpath);
void group_vscroll_onoff( struct toolbar_group * g, int forceredraw );
void toolbar_vscroll_onoff( struct toolbar_data *T );
void ensure_item_isvisible(struct toolbar_item * p);
struct toolbar_group *add_groupT_rcoh(struct toolbar_data *T, int xcontrol, int ycontrol, int hidden);
void ttb_new_tabs_groupT(struct toolbar_data *T, int xmargin, int xsep, int wclose, int modshow, int fntsz, int fntyoff, int wdrag, int xcontrol, int height);
void ttb_show_groupG( struct toolbar_group *G, int show );
struct toolbar_item *add_itemG(struct toolbar_group *G, const char * name, const char * img, const char *tooltip, const char * text, int chwidth, int flags);
void update_group_sizeG( struct toolbar_group *G, int redraw );
void ttb_enable_buttonT(struct toolbar_data *T, const char * name, int isselectable, int isgrayed );
void ttb_select_buttonT(struct toolbar_data *T, const char * name, int select, int press );
void ttb_ensurevisibleT(struct toolbar_data *T, const char * name );
void ttb_collapseT(struct toolbar_data *T, const char * name, int collapse, int hideheight );
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
void paint_toolbar_back(struct toolbar_data *T, void * gcontext, struct area * pdrawarea);
void paint_group_items(struct toolbar_group *g, void * gcontext, struct area * pdrawarea, int x0, int y0, int wt, int ht);
void paint_vscrollbar(struct toolbar_group *g, void * gcontext, struct area * pdrawarea, int x0, int y0, int wt, int ht);
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
void start_drag( int x, int y );
int item_hiddenH_offset( struct toolbar_item * p );
int group_hiddenH( struct toolbar_group *g );

int  set_item_img( struct toolbar_item *p, int nimg, const char *imgname );
void setrgbcolor(int rgb, struct color3doubles *pc);
struct toolbar_img * get_group_img( struct toolbar_group *G, int nimg );
int  get_group_imgW( struct toolbar_group *G, int nimg );
int  get_group_imgH( struct toolbar_group *G, int nimg );
void select_toolbar_n( int num, int ngrp, int emptygroup );
void ttb_addbutton( const char *name, const char *tooltip, int base );
void ttb_addtext( const char * name, const char * img, const char *tooltip, const char * text, int chwidth, int dropbutton, int leftalign, int bold, int xoff, int yoff);
void ttb_addlabel( const char * name, const char * img, const char *tooltip, const char * text, int chwidth, int flags, int xoff, int yoff );
void ttb_enable( const char * name, int isselectable, int isgrayed, int onlythistb );
void ttb_setselected( const char * name, int selected, int pressed, int onlythistb );
void ttb_ensurevisible( const char * name, int onlythistb );
void ttb_collapse( const char * name, int collapse, int hideheight, int onlythistb );
int  ttb_get_flags( const char * name  );
void ttb_seticon( const char * name, const char *img, int nicon, int onlythistb );
void ttb_setbackcolor( const char * name, int color, int keepback, int onlythistb );
void ttb_settooltip( const char * name, const char *tooltip, int onlythistb );
void ttb_settext( const char * name, const char * text, const char *tooltip, int onlythistb );
void ttb_set_toolbarsize( struct toolbar_data *T, int width, int height);
void ttb_set_anchor( const char * name, int xright, int anchor_end );
void ttb_set_resize( const char * name, int h_resize, int min_width );

void toolbar_set_win_title( const char *title );

void mini_map_ev( struct toolbar_item *p, int dir, int redraw );
void vscroll_clickG( struct toolbar_group *g );

void minimap_init(int buffnum, int linecount, int yszbox);
void minimap_hilight(int linenum, int color, int exclusive);
int  minimap_getclickline( void );
void minimap_scrollpos(int linesscreen, int firstvisible, int color);

void fire_minimap_scroll( int dir );


#endif
