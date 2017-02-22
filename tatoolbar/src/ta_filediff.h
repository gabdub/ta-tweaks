/*
    ta_filediff.h
    =============
    TA  file diff
*/
#ifndef __TA_FILEDIFF__
#define __TA_FILEDIFF__

#define MAXFILEDIFF      2

struct line_info {
  struct line_info * next;

  char * line;
  int linesz;
  unsigned long hash;

  int linenum;      //this file line number

  int otherline;    //   0 if this line is only in this file
                    // > 0 other file line number (same text)
                    // < 0 other file line number (when only one line changed in both sides)
};

//load a file to compare (filenum= 1...MAXFILEDIFF)
void fdiff_setfile( int filenum, const char * filecontent );

typedef void t_pushint( int val );

//get file differences as an int array
void fdiff_getdiff( int filenum, int dlist, t_pushint pfunc );

//get string differences as an int array
void fdiff_strdiff( const char *s1, const char *s2, t_pushint pfunc );

//free all filediff memory
void fdiff_killall( void );

#endif
