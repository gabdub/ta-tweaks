// Copyright 2016-2022 Gabriel Dubatti. See LICENSE.
/* write some debugging information to a file */

#include "ta_debug.h"

#ifdef SAVE_DEBUG
static FILE * _fo_dbg= NULL;

int SAVE_DEBUG_OPEN( void )
{
  if( _fo_dbg == NULL ){
    _fo_dbg= fopen( "debug.txt", "a" );
    //log date / time here if needed
    return 1;
  }
  return 0;
}

void SAVE_DEBUG_CLOSE( void )
{
  if( _fo_dbg != NULL ){
    fputs( "\n", _fo_dbg );
    fclose( _fo_dbg );
    _fo_dbg= NULL;
  }
}

void SAVE_DEBUG_KEEPCLOSED( int wasclosed )
{
  if( wasclosed ){
    SAVE_DEBUG_CLOSE();
  }
}

void SAVE_DEBUG_STR( char * txt )
{
  int wasclosed= SAVE_DEBUG_OPEN();
  fputs( txt, _fo_dbg );
  SAVE_DEBUG_KEEPCLOSED( wasclosed );
}

void SAVE_DEBUG_STR_INT( char * info, int v )
{
  char txt[20];
  int wasclosed= SAVE_DEBUG_OPEN();
  SAVE_DEBUG_STR( info );
  sprintf( txt, "%d", v );
  SAVE_DEBUG_STR( txt );
  SAVE_DEBUG_KEEPCLOSED( wasclosed );
}

void SAVE_DEBUG_TB_HW( struct toolbar_data *T, char * info )
{
  int wasclosed= SAVE_DEBUG_OPEN();
  SAVE_DEBUG_STR( info );
  SAVE_DEBUG_STR_INT( " #",  T->num );
  SAVE_DEBUG_STR_INT( " w=", T->barwidth );
  SAVE_DEBUG_STR_INT( " h=", T->barheight );
  SAVE_DEBUG_KEEPCLOSED( wasclosed );
}

void SAVE_DEBUG_TB0_HW( struct toolbar_data *T, char * info )
{
  if( T->num == 0 ){
    SAVE_DEBUG_TB_HW( T, info );
  }
}

#endif
