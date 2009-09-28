\ To test the ANS Forth search-order word set and search order extensions

\ Copyright (C) Gerry Jackson 2006, 2007

\ This program is free software; you can redistribute it and/or
\ modify it any way.

\ This program is distributed in the hope that it will be useful,
\ but WITHOUT ANY WARRANTY; without even the implied warranty of
\ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

\ The tests are not claimed to be comprehensive or correct 

\ ------------------------------------------------------------------------------
\ Version 0.4 6 March 2009 { and } replaced with T{ and }T
\         0.3 20 April 2007 ANS Forth words changed to upper case
\         0.2 30 Oct 2006 updated following GForth tests to get
\             initial search order into a known state
\         0.1 Oct 2006 First version released

\ ------------------------------------------------------------------------------
\ The tests are based on John Hayes test program for the core word set
\ and requires those files to have been loaded

\ Words tested in this file are:
\     FORTH-WORDLIST GET-ORDER SET-ORDER ALSO ONLY FORTH GET-CURRENT
\     SET-CURRENT DEFINITIONS PREVIOUS SEARCH-WORDLIST WORDLIST FIND
\ Words not fully tested:
\     ORDER ONLY tests that it executes, display is implementation
\           dependent

\ ------------------------------------------------------------------------------
\ Assumptions and dependencies:
\     - tester.fr has been loaded prior to this file
\     - that ONLY FORTH DEFINITIONS will work at the start of the file
\       to ensure the search order is in a known state
\ ------------------------------------------------------------------------------

ONLY FORTH DEFINITIONS

Testing Search-order word set

DECIMAL

VARIABLE wid1  VARIABLE wid2

: save-orderlist ( widn ... wid1 n -> ) DUP , 0 ?DO , LOOP ;

\ ------------------------------------------------------------------------------

Testing FORTH-WORDLIST GET-ORDER SET-ORDER

T{ FORTH-WORDLIST wid1 ! -> }T

CREATE order-list

T{ GET-ORDER save-orderlist -> }T

: get-orderlist  ( -- widn ... wid1 n )
   order-list DUP @ CELLS  ( -- ad n )
   OVER +                  ( -- AD AD' )
   ?DO I @ -1 CELLS +LOOP  ( -- )
;

T{ GET-ORDER OVER -> GET-ORDER wid1 @ }T \ Forth wordlist at top
T{ GET-ORDER SET-ORDER -> }T             \ Effectively noop
T{ GET-ORDER -> get-orderlist }T         \ Check nothing changed
T{ get-orderlist DROP get-orderList 2* SET-ORDER -> }T
T{ GET-ORDER -> get-orderlist DROP get-orderList 2* }T
T{ get-orderlist SET-ORDER GET-ORDER -> get-orderlist }T

\ ------------------------------------------------------------------------------

Testing ALSO ONLY FORTH

T{ ALSO GET-ORDER -> get-orderlist OVER SWAP 1+ }T
T{ ONLY FORTH GET-ORDER -> get-orderlist }T    \ See assumptions above

\ ------------------------------------------------------------------------------

Testing GET-CURRENT SET-CURRENT WORDLIST (simple)

T{ GET-CURRENT -> wid1 @ }T        \ See assumptions above
T{ WORDLIST wid2 ! -> }T
T{ wid2 @ SET-CURRENT -> }T
T{ GET-CURRENT -> wid2 @ }T
T{ wid1 @ SET-CURRENT

\ ------------------------------------------------------------------------------

Testing minimum search order list contains FORTH-WORDLIST and SET-ORDER

: so1 SET-ORDER ;    \ In case it is unavailable in the forth wordlist

T{ ONLY FORTH-WORDLIST 1 SET-ORDER get-orderlist so1 -> }T
T{ GET-ORDER -> get-orderlist }T

\ ------------------------------------------------------------------------------

Testing GET-ORDER SET-ORDER with 0 and -1 number of wids argument

: so2a GET-ORDER get-orderlist SET-ORDER ; \  To recover search order
: so2 0 SET-ORDER so2a ;

T{ so2 -> 0 }T         \ 0 set-order leaves an empty search order

: so3 -1 SET-ORDER so2a ;
: so4 ONLY so2a ;

T{ so3 -> so4 }T       \ -1 SET-ORDER = ONLY

\ ------------------------------------------------------------------------------

Testing DEFINITIONS PREVIOUS

T{ ONLY FORTH DEFINITIONS -> }T
T{ GET-CURRENT -> FORTH-WORDLIST }T
T{ GET-ORDER wid2 @ SWAP 1+ SET-ORDER DEFINITIONS GET-CURRENT -> wid2 @ }T
T{ GET-ORDER -> get-orderlist wid2 @ SWAP 1+ }T
T{ PREVIOUS GET-ORDER -> get-orderlist }T
T{ DEFINITIONS GET-CURRENT -> forth-wordlist }T

\ ------------------------------------------------------------------------------

Testing SEARCH-WORDLIST WORDLIST FIND

ONLY FORTH DEFINITIONS
VARIABLE xt  ' DUP xt !
VARIABLE xti ' .( xti !    \ Immediate word

T{ S" DUP" wid1 @ SEARCH-WORDLISt -> xt  @ -1 }T
T{ S" .("  wid1 @ SEARCH-WORDLIST -> xti @  1 }T
T{ S" DUP" wid2 @ SEARCH-WORDLIST ->        0 }T

: c"dup" C" DUP" ;
: c".("  C" .(" ;
: c"x" C" unknown word"  ;

T{ c"dup" FIND -> xt  @ -1 }T
T{ c".("  FIND -> xti @  1 }T
T{ c"x"   FIND -> c"x"   0 }T

\ ------------------------------------------------------------------------------

Testing new definitions are put into the correct wordlist

: alsowid2 ALSO GET-ORDER wid2 @ ROT DROP SWAP SET-ORDER ;
alsowid2
: w1 1234  ;
DEFINITIONS
: w1 -9876 ; IMMEDIATE

ONLY FORTH
T{ w1 -> 1234 }T
DEFINITIONS
T{ w1 -> 1234 }T
alsowid2
T{ w1 -> -9876 }T
DEFINITIONS
T{ w1 -> -9876 }T 

ONLY FORTH DEFINITIONS

: so5  DUP IF SWAP EXECUTE THEN ;

T{ S" w1" wid1 @ SEARCH-WORDLIST so5 -> -1  1234 }T
T{ S" w1" wid2 @ SEARCH-WORDLIST so5 ->  1 -9876 }T

: c"w1" C" w1" ;
T{ alsowid2 c"w1" FIND so5 ->  1 -9876 }T
T{ previous c"w1" FIND so5 -> -1  1234 }T

\ ------------------------------------------------------------------------------

Testing ORDER  \ Should display search order and compilation wordlist

cr .( ONLY FORTH DEFINITIONS search order and compilation list) cr
T{ ONLY FORTH DEFINITIONS ORDER -> }T

cr .( Plus another unnamed wordlist at the head of the search order) cr
T{ alsowid2 DEFINITIONS ORDER -> }T

\ ------------------------------------------------------------------------------

CR .( End of Search Order word tests) CR

ONLY FORTH DEFINITIONS		\ Leave search order in the standard state
