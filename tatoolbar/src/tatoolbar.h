/*
    tatoolbar.h
    ===========
    TA  toolbar
*/
#ifndef __TATOOLBAR__
#define __TATOOLBAR__

//ntoolbar=0: HORIZONTAL  (top)
//ntoolbar=1: VERTICAL    (left)
//ntoolbar=2: HORIZONTAL  (bottom)
//ntoolbar=3: VERTICAL    (right)
#define STAT_TOOLBAR      2
#define NTOOLBARS         4

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
};

struct toolbar_data
{
  GtkWidget *draw;    //(GtkWidget *drawing_area of this toolbar)
  int num;            //number of toolbar
  int isvertical;     //is a vertical toolbar (#1=yes)
  int isvisible;

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
};

struct all_toolbars_data
{
  struct toolbar_data tbdata[NTOOLBARS]; //horizonal & vertical toolbars

  struct toolbar_item * philight;
  struct toolbar_item * phipress;
  int ntbhilight;     //number of the toolbar with the hilighted button or -1

  int currentntb;     //current toolbar num

  char * img_base;
};

#endif
