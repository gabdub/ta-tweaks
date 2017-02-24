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
  char *s1= l->line;
  char *s2= o->line;
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
    if( strncmp( s1, s2, sz) != 0 ){
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
  int n, no, nl, longest, ns1, ns2, bpl, bpo, len, dist, ln;
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
            //only replace the best match for one with the same length if this option is nearear the top
            //NOTE: this try to get the same results when the files are permuted
            dist= n1-n; //dist= max(distance from file begin to match)
            if( dist < n2-no){
              dist= n2-no;
            }
            if( (bpl <= dist) && (bpo <= dist) ){
              len= 0; //this option is not "nearer" to the lines start, keep the actual one
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
            for( p= bl, n= len; (p != NULL)&& (n > 0); p= p->next, n-- ){
              p->otherline= ln++;
            }
            ln= bl->linenum;
            for( p= bo, n= len; (p != NULL)&& (n > 0); p= p->next, n-- ){
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
    while( p->otherline != 0 ){
      p= p->next;
      if( p == NULL ){
        return;
      }
    }
    while( o->otherline != 0 ){
      o= o->next;
      if( o == NULL ){
        return;
      }
    }
    //check there is only one modification in both files
    if( ((p->next == NULL) || (p->next->otherline != 0)) &&
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

//compare both strings an emit the position and lenght of strings that are only in line1
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
// dlist= 2: (nfile, char pos from, len) chars that are only in file nfile (deleted in the other file)
// dlist= 3: (line num, count) number of blank lines needed to add under line "num" (0=before first) to align equal lines between files
// NOTE: char ranges (dlist=2) are generated only for 1 line ranges (excluded from dlist=1) when they are "similar enough"
void fdiff_getdiff( int filenum, int dlist, t_pushint pfunc )
{
  struct line_info *p, *o;
  int n, no, fother;

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

  //push integers in the return table
  if( dlist == 1 ){
    //(line from, line to) lines that are only in file #num (inserted in #num = deleted in the other file)
    n= 0;
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

  }else if( dlist == 2 ){   //this get option ignores "filenum" param
    //(nfile, char pos from, len) chars that are only in file nfile (deleted in the other file)
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
          emit_line_diff( filemem[ f1 ], p->line, strlen(p->line),
                          filemem[ f2 ], o->line, strlen(o->line), pfunc );
        }
      }
    }

  }else if( dlist == 3 ){
    //(line num, count) number of blank lines needed to add under line "num" (0=before first)
    //to align equal lines between files
    if( filenum == f1 ){
      fother= f2;
    }else{
      fother= f1;
    }
    n= 0;
    no= 0;
    for( p= linelist[fother]; (p != NULL); p= p->next ){
      if( p->otherline == 0 ){ //this line is only in the "other file"
        if( n == 0 ){
          n= p->linenum;  //get the first
        }
      }else{ //same or 1 line modification
        if( n != 0 ){
          (*pfunc)( no );   //emit "line num"
          (*pfunc)( n );    //emit "count"
          n= 0;
        }
        no= p->otherline;
        if( no < 0 ){
          no= -no;
        }
      }
    }
    if( n != 0 ){       //emit pending
      (*pfunc)( no );   //emit "line num"
      (*pfunc)( n );    //emit "count"
      n= 0;
    }
  }
}

//get string differences as an int array
//compare both strings an emit the position and lenght of strings that are only in s1
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
