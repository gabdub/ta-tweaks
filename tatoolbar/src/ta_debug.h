// Copyright 2016-2022 Gabriel Dubatti. See LICENSE.
/*
    ta_debug.h
    ==========
*/
#ifndef __TA_DEBUG__
#define __TA_DEBUG__

#define SAVE_DEBUG

#ifdef SAVE_DEBUG
  //DEBUG ON
  int  SAVE_DEBUG_OPEN( void );
  void SAVE_DEBUG_CLOSE( void );
  void SAVE_DEBUG_KEEPCLOSED( int wasclosed );
  void SAVE_DEBUG_STR( char * txt );
  void SAVE_DEBUG_STR_INT( char * info, int v );
  void SAVE_DEBUG_TB_HW( struct toolbar_data *T, char * info );
  void SAVE_DEBUG_TB0_HW( struct toolbar_data *T, char * info );
#else
  //DEBUG OFF
  #define SAVE_DEBUG_OPEN()
  #define SAVE_DEBUG_CLOSE()
  #define SAVE_DEBUG_KEEPCLOSED(wasclosed)
  #define SAVE_DEBUG_STR(txt)
  #define SAVE_DEBUG_STR_INT(info,v)
  #define SAVE_DEBUG_TB_HW(T,info)
  #define SAVE_DEBUG_TB0_HW(T,info)
#endif

#endif
