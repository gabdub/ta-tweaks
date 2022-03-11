// Copyright 2016-2022 Gabriel Dubatti. See LICENSE.
/* TA  file diff */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ta_filediff.h"

static char * filemem[ MAXFILEDIFF ];                 //file content
static int linecount[ MAXFILEDIFF ];                  //file line count
static struct line_info * linelist[ MAXFILEDIFF ];    //file line info list
static int fdiff_dirty= 0;
static int f1= 0; //files to compare (there are only 2 for now..)
static int f2= 1;

//free all the memory used by a file (0...)
static void free_filemem( int i )
{
  struct line_info *lines, *n;
  //free file image
  if( filemem[i] != NULL ){
    free( filemem[i] );
    filemem[i]= NULL;
  }
  linecount[i]= 0;
  //free lines list memory
  if( linelist[i] != NULL ){
    lines= linelist[i];
    while( lines != NULL ){
      n= lines->next;
      free( lines );
      lines= n;
    }
    linelist[i]= NULL;
  }
  fdiff_dirty= 1; //last file difference is now invalid
}

//load a file to compare (filenum= 1..)
void fdiff_setfile( int filenum, const char * filecontent )
{
  struct line_info *m, *a, *list;
  unsigned long hash;
  int c, linesz, linenum;
  size_t sz;
  char *mem, *s;

  if( (filenum >= 1) && (filenum <= MAXFILEDIFF) && (filecontent != NULL) ){
    filenum--;
    //delete previous content / invalidate last difference
    free_filemem( filenum );
    sz= strlen( filecontent ) +1;
    mem= (char *) malloc( sz );
    if( mem != NULL ){
      strcpy( mem, filecontent );
      //split the file in lines
      //NOTE: the '\0' at the end of the string is used to count
      //      and extra line when the document ends with '\n'
      s= mem;
      list= NULL;
      a= NULL;
      linenum= 0;
      do{
        m= (struct line_info *) malloc( sizeof(struct line_info) );
        if( m == NULL ){
          return;  //NO MEMORY ERROR
        }
        linenum++;
        m->line= s; //line start pointer
        linesz= 0;
        hash = 5381;
        while( sz > 0 ){
          sz--;
          linesz++;
          c= *s++;
          hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
          if( c == '\n' ){
            break;
          }
        }
        m->linesz= linesz;
        m->hash= hash;
        m->linenum= linenum;
        m->otherline= 0;

        m->next= NULL;
        if( a == NULL ){
          list= m;    //list head
        }else{
          a->next= m; //add node at the end of the list
        }
        a= m;
      } while( sz > 0 );
      //save file info
      filemem[ filenum ]=   mem;
      linecount[ filenum ]= linenum;
      linelist[ filenum ]=  list;
    }
  }
}

static void clear_otherline( struct line_info *p, int n )
{
  for( ; (p != NULL) && (n > 0); p= p->next, n-- ){
    p->otherline= 0;
  }
}

//get the number of lines that are the same in both lists
static int get_common_chain_len( struct line_info * list1, int n1, struct line_info * list2, int n2, int longest )
{
  struct line_info * l= list1;
  struct line_info * o= list2;
  int sz= 0;
  int len= 0;
  int n;

  //find the longest match using hash codes and sizes only
  if( n1 > n2 ){
    n1= n2;
  }
  n= n1;
  while( (l != NULL) && (o != NULL) && (n > 0) ){
    if( (l->hash != o->hash) || (l->linesz != o->linesz) ){
      break;
    }
    len++;
    sz += l->linesz;
    o= o->next;
    l= l->next;
    n--;
  }
  if( (len > 0) && (len >= longest) ){
    //this chain could to be the new longest, check the strings to be sure
    if( strncmp( list1->line, list2->line, sz) != 0 ){
      //some of the hash colide so this chain is not that long...
      //recalculate the chain len comparing line strings (slower)
      if( len == longest ){
        return 0; //no need to check: len < longest
      }
      l= list1;
      o= list2;
      n= n1;
      len= 0;
      while( (l != NULL) && (o != NULL) && (n > 0) ){
        if( strncmp( l->line, o->line, l->linesz) != 0 ){ //(l->linesz == o->linesz) already checked
          break;
        }
        len++;
        o= o->next;
        l= l->next;
        n--;
      }
    }
  }
  return len;
}

//compare list1 and list2 lists (only up to n1 and n2 lines)
//using the first longest match, split the lists in 3 parts and repit...
//set line's "otherline" equal to the matching line number in the other list
static void listcompare( struct line_info * list1, int n1, struct line_info *list2, int n2 )
{
  struct line_info * l, *o, *bl, *bo, *p;
  int n, no, i, longest, ns1, ns2, bpl, bpo, len, dist, ln;
  unsigned long h1;

  if( (list1 == NULL) || (n1 == 0) || (list2 == NULL) || (n2 == 0) ){
    return;
  }

  //find the longest common line block
  longest= 0;
  bl= NULL;
  bo= NULL;
  bpl= 0;
  bpo= 0;
  for( l= list1, n= n1; (n > 0) && (n >= longest); n--, l= l->next ){
    h1= l->hash;
    for( o= list2, no= n2; (no > 0) && (no >= longest); no--, o= o->next ){
      //ignore lines that have different hashes or are already linked as part of the current longest chain
      if( (o->hash == h1) && (l->otherline != o->linenum) ){
        len= get_common_chain_len( l, n, o, no, longest );
        if( len > 0 ){
          if( len == longest ){
            //only replace the best match for one with the same length if this option is nearear the block start
            //NOTE: this try to get the same results when the files are permuted
            dist= n1-n; //dist= max(distance from block start to match)
            if( dist < n2-no){
              dist= n2-no;
            }
            if( (bpl <= dist) && (bpo <= dist) ){
              len= 0; //this option is not "nearer" to the block start, keep the actual one
            }
          }
          if( len >= longest ){
            //clear line links in the previous best chain
            if( longest > 0 ){
              clear_otherline( bl, longest );
              clear_otherline( bo, longest );
            }
            //set the new best chain
            bl= l;
            bo= o;
            longest= len;
            bpl= n1-n;
            bpo= n2-no;
            //link line numbers in one file with the line numbers in the other
            ln= bo->linenum;
            for( p= bl, i= len; (p != NULL)&& (i > 0); p= p->next, i-- ){
              p->otherline= ln++;
            }
            ln= bl->linenum;
            for( p= bo, i= len; (p != NULL)&& (i > 0); p= p->next, i-- ){
              p->otherline= ln++;
            }
          }
        }
      }
    }
  }

  //a common block split the list in 3 logical parts: "before", "match" and "after"
  if( longest > 0 ){
    ns1= bl->linenum - list1->linenum;
    ns2= bo->linenum - list2->linenum;
    if( (ns1 > 0) && (ns2 > 0) ){
      //compare the lines "before" the best match. **recursion**
      listcompare( list1, ns1, list2, ns2 );
    }
    //skip "match" part
    while( longest > 0 ){
      longest--;
      bl= bl->next;
      bo= bo->next;
    }
    if( (bl != NULL) && (bo != NULL) ){
      ns1= n1 - (bl->linenum - list1->linenum);
      ns2= n2 - (bo->linenum - list2->linenum);
      if( (ns1 > 0) && (ns2 > 0) ){
        //compare the lines "after" the best match. **recursion**
        listcompare( bl, ns1, bo, ns2 );
      }
    }
  }
}

//detect and conect one line modifications
static void link_modifications( struct line_info * list1, struct line_info *list2 )
{
  struct line_info *p, *o;

  p= list1;
  o= list2;
  while( (p != NULL) && (o != NULL) ){
    //skip linked lines (same in both files)
    while( p->otherline == o->linenum ){
      p= p->next;
      o= o->next;
      if( (p == NULL) || (o == NULL) ){
        return;
      }
    }
    if( (p->otherline != 0) && (o->otherline != 0) ){
      return; //prevent infinite loop if the table was bad generated
    }

    //check if there is only one line change in both files
    if( (p->otherline == 0) && (o->otherline == 0) &&
        ((p->next == NULL) || (p->next->otherline != 0)) &&
        ((o->next == NULL) || (o->next->otherline != 0)) ){
      //one line change, link them using negatives line numbers
      p->otherline= - o->linenum;
      o->otherline= - p->linenum;
      p= p->next;
      o= o->next;
    }else{
      //more than one modification in one or both sides, skip them
      while( p->otherline == 0 ){
        p= p->next;
        if( p == NULL ){
          return;
        }
      }
      while( o->otherline == 0 ){
        o= o->next;
        if( o == NULL ){
          return;
        }
      }
    }
  }
}

/* ============================================================================= */
//get longest common prefix length
static int get_common_len( const char * s1, int n1, const char * s2, int n2 )
{
  int len= 0;
  if( n1 > n2 ){
    n1= n2;
  }
  while( (len < n1) && (*s1++ == *s2++) ){
    len++;
  }
  return len;
}

//compare both strings an emit the position and lenght of strings that are only in line1 or line2
static void emit_line_diff( const char * f1beg, const char * line1, int n1, const char * f2beg, const char *line2, int n2, t_pushint pfunc )
{
  int n, no, longest, ns1, ns2, len, dist;
  const char *l, *o;
  const char *bl, *bo;

  if( (n1 > 0) && (n2 > 0) ){
    //find the longest common string
    longest= 0;
    bl= NULL;
    bo= NULL;
    for( l= line1, n= n1; (n >= longest); n--, l++ ){
      for( o= line2, no= n2; (no >= longest); no--, o++ ){
        //if the common prefix is bigger that the current longest chain, set this string as the current best option
        len= get_common_len( l, n, o, no );
        if( len > 0 ){
          if( len > longest ){
            bl= l;
            bo= o;
            longest= len;
          }else if( len == longest ){
            //if more than one string has the same "longest" length, choose one
            //NOTE: this try to get the same results when the lines are permuted
            dist= l -line1; //dist= max(distance from string begin to match)
            if( dist < o - line2){
              dist= o -line2;
            }
            if( (bl-line1 > dist) || (bo-line2 > dist) ){
              //this option is "nearer" to the lines start
              bl= l;
              bo= o;
              longest= len;
            }
          }
        }
      }
    }
    //a common string split the line in 3 logical parts: "before", "match" and "after"
    if( longest > 2 ){  //at least 3 consecutive chars are needed to prevent useless random matches
      ns1= bl - line1;
      ns2= bo - line2;
      //compare the strings "before" the best match. **recursion**
      emit_line_diff( f1beg, line1, ns1, f2beg, line2, ns2, pfunc );
      //skip "match" part
      bl += longest;
      bo += longest;
      ns1= n1 - (bl - line1);
      ns2= n2 - (bo - line2);
      //compare the lines "after" the best match. **recursion**
      emit_line_diff( f1beg, bl, ns1, f2beg, bo, ns2, pfunc );
      return;
    }
  }
  if( n1 > 0 ){
    (*pfunc)( f1+1 );           //file number
    (*pfunc)( line1 - f1beg );  //start position
    (*pfunc)( n1 );             //length
  }
  if( n2 > 0 ){
    (*pfunc)( f2+1 );           //file number
    (*pfunc)( line2 - f2beg );  //start position
    (*pfunc)( n2 );             //length
  }
}


// get file differences as an int array (num= 1...MAXFILEDIFF)
// dlist= 1: (line from, line to) lines that are only in file #num (inserted in #num = deleted in the other file)
// dlist= 2: (line num, other file line num) modified lines (1 line changed in both files)
// dlist= 3: (line num, count) number of blank lines needed to add under line "num" to align equal lines between files
//           (0=before first, is not emited, is added to line 1 instead)
// dlist= 4: (nfile, char pos from, len) chars that are only in file1 or file2 (num param is ignored)
// NOTE: char ranges (dlist=2) are generated only for 1 line ranges (this lines are excluded from dlist=1)
void fdiff_getdiff( int filenum, int dlist, t_pushint pfunc )
{
  struct line_info *p, *o;
  int n, no, n1p, fother;

  if( (filenum < 1) || (filenum > MAXFILEDIFF) ){
    return;
  }
  filenum--;

  if( fdiff_dirty ){
    //disconect all lines
    clear_otherline( linelist[f1], linecount[f1] );
    clear_otherline( linelist[f2], linecount[f2] );
    //conect the lines that are the same in both files
    listcompare( linelist[f1], linecount[f1], linelist[f2], linecount[f2] );
    //conect one line modifications
    link_modifications( linelist[f1], linelist[f2] );
    fdiff_dirty= 0;
  }

  n= 0;
  no= 0;
  n1p= 0; //pending line 0 changes

  //push integers in the return table
  if( dlist == 1 ){
    //(line from, line to) lines that are only in file #num (inserted in #num = deleted in the other file)
    for( p= linelist[ filenum ]; (p != NULL); p= p->next ){
      if( p->otherline == 0 ){
        if( n == 0 ){   //emit "line from"
          (*pfunc)( p->linenum );
        }
        n= p->linenum;
      }else{
        if( n > 0 ){    //emit "line to"
          (*pfunc)( n );
          n= 0;
        }
      }
    }
    if( n > 0 ){        //emit pending "line to"
      (*pfunc)( n );
    }

  }else if( dlist == 2 ){
    //(line num, other file line num) modified lines (1 line changed in both files)
    for( p= linelist[ filenum ]; (p != NULL); p= p->next ){
      if( p->otherline < 0 ){
        (*pfunc)( p->linenum );     //emit "line num"
        (*pfunc)( - p->otherline ); //emit "other line num"
      }
    }

  }else if( dlist == 3 ){
    //(line num, count) number of blank lines needed to add under line "num" to align differences
    //NOTE: line 0 (before first line) changes ARE NOT EMITED, they are moved/added to line 1
    if( filenum == f1 ){
      //check f2 lines (file1 changes are shown "before" file2 changes)
      for( p= linelist[f2]; (p != NULL); p= p->next ){
        if( p->otherline == 0 ){ //this line is only in file2
          n++;
        }else{ //same or 1 line modification
          if( n > 0 ){
            no= p->otherline;   //show over "first next same" line
            if( no < 0 ){
              no= -no;
            }
            no--;
            if( no == 0 ){
              n1p= n;           //save line #0 changes
            }else{
              if( no == 1 ){    //add line #0 to line #1
                n += n1p;
                n1p= 0;
              }else if( n1p != 0 ){ //emit pending line #0 as line #1
                (*pfunc)( 1 );  //emit "line num"
                (*pfunc)( n1p );//emit "count"
                n1p= 0;
              }
              (*pfunc)( no );   //emit "line num"
              (*pfunc)( n );    //emit "count"
            }
            n= 0;
          }
        }
      }
      no= linecount[f1];  //show pending file2 changes under the last file1 line

    }else if( filenum == f2 ){
      //check f1 lines (file2 changes are shown "after" file1 changes)
      for( p= linelist[f1]; (p != NULL); p= p->next ){
        if( p->otherline == 0 ){ //this line is only in file1
          n++;
        }else{ //same or 1 line modification
          if( n > 0 ){
            if( no == 0 ){
              n1p= n;           //save line #0 changes
            }else{
              if( no == 1 ){    //add line #0 to line #1
                n += n1p;
                n1p= 0;
              }else if( n1p != 0 ){ //emit pending line #0 as line #1
                (*pfunc)( 1 );  //emit "line num"
                (*pfunc)( n1p );//emit "count"
                n1p= 0;
              }
              (*pfunc)( no );   //emit "line num"
              (*pfunc)( n );    //emit "count"
            }
            n= 0;
          }
          no= p->otherline;   //show under last "same" line
          if( no < 0 ){
            no= -no;
          }
        }
      }
    }
    if( n1p != 0 ){ //emit pending line #0 as line #1
      (*pfunc)( 1 );    //emit "line num"
      (*pfunc)( n1p );  //emit "count"
    }
    if( n != 0 ){       //emit pending
      (*pfunc)( no );   //emit "line num"
      (*pfunc)( n );    //emit "count"
    }

  }else if( dlist == 4 ){   //this get option ignores "filenum" param
    //(nfile, char pos from, len) chars that are only in file1 or file2
    o= linelist[f2];
    no= 1;
    for( p= linelist[f1]; (p != NULL); p= p->next ){
      if( p->otherline < 0 ){
        //locate the other line in f2
        n= - p->otherline;
        if( n < no ){ //restart count from line 1
          o= linelist[f2];
          no= 1;
        }
        while( (n > no) && (o != NULL) ){
          no++;
          o= o->next;
        }
        if( o != NULL ){
          //compare both strings an emit the position and lenght of strings that are only in one file
          emit_line_diff( filemem[ f1 ], p->line, p->linesz,
                          filemem[ f2 ], o->line, o->linesz, pfunc );
        }
      }
    }

  }else{ //DEBUG: dump internal table
    p= linelist[ filenum ];
    while( p != NULL ){
      if( p->otherline == 0 ){
        n= p->linenum;
        while( (p != NULL) && (p->otherline == 0) ){
          no= p->linenum;
          p= p->next;
        }
        (*pfunc)( 0 );    //only in this file
        (*pfunc)( n );    //from line
        (*pfunc)( no );   //to line

      }else if( p->otherline < 0 ){
        (*pfunc)( 1 );              //one line change
        (*pfunc)( p->linenum );     //line in file 1
        (*pfunc)( - p->otherline ); //line in file 2
        p= p->next;

      }else{
        n= p->linenum;
        fother= p->otherline;
        while( (p != NULL) && (p->otherline == (fother+p->linenum-n)) ){
          no= p->linenum;
          p= p->next;
        }
        (*pfunc)( 2 );    //same text in file 1
        (*pfunc)( n );    //from line
        (*pfunc)( no );   //to line
        (*pfunc)( 3 );    //same text in file 2
        (*pfunc)( fother );      //from line
        (*pfunc)( fother+no-n ); //to line
      }
    }
  }
}

//get string differences as an int array
//compare both strings an emit the position and lenght of strings that are only in s1 or s2
void fdiff_strdiff( const char *s1, const char *s2, t_pushint pfunc )
{
  emit_line_diff( s1, s1, strlen(s1), s2, s2, strlen(s2), pfunc );
}

//free all filediff memory
void fdiff_killall( void )
{
  int i;
  for( i= 0; i < MAXFILEDIFF; i++ ){
    free_filemem( i );
  }
}
