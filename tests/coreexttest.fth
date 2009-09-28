\ To test some of the ANS Forth Core Ext word set, version 0.1

\ Copyright (C) Gerry Jackson 2006, 2007

\ This program is free software; you can redistribute it and/or
\ modify it any way.

\ This program is distributed in the hope that it will be useful,
\ but WITHOUT ANY WARRANTY; without even the implied warranty of
\ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

\ The tests are not claimed to be comprehensive or correct

\ --------------------------------------------------------------------
\ Version 0.3  6 March 2009 { and } replaced with T{ and }T
\                           CONVERT test now independent of cell size
\         0.2  20 April 2007 ANS Forth words changed to upper case
\                            Tests qd3 to qd6 by Reinhold Straub
\         0.1  Oct 2006 First version released

\ --------------------------------------------------------------------

\ This is only a partial test of the core extension words.
\ The tests are based on John Hayes test program for the core word set

\ Words tested in this file are:
\     TRUE FALSE :NONAME ?DO VALUE TO CASE OF ENDOF ENDCASE
\     C" CONVERT COMPILE, [COMPILE] SAVE-INPUT RESTORE-INPUT
\     NIP TUCK ROLL WITHIN

\ --------------------------------------------------------------------
\ Assumptions:
\     - tester.fr has been included prior to this file
\     - core words to have been tested
\ --------------------------------------------------------------------

Testing Core Extension words

DECIMAL

0 INVERT 1 RSHIFT CONSTANT max-int  \ 01...1


Testing TRUE FALSE

T{ TRUE  -> 0 INVERT }T
T{ FALSE -> 0 }T

\ --------------------------------------------------------------------

Testing :NONAME

VARIABLE nn1
VARIABLE nn2
:NONAME 1234 ; nn1 !
:NONAME 9876 ; nn2 !
T{ nn1 @ EXECUTE -> 1234 }T
T{ nn2 @ EXECUTE -> 9876 }T

\ --------------------------------------------------------------------

Testing ?DO

: qd ?DO I LOOP ;
T{ 789 789 qd -> }T
T{ -9876 -9876 qd -> }T
T{ 5 0 qd -> 0 1 2 3 4 }T

: qd1 ?DO I 10 +LOOP ;
T{ 50 1 qd1 -> 1 11 21 31 41 }T
T{ 50 0 qd1 -> 0 10 20 30 40 }T

: qd2 ?DO I 3 > if LEAVE else I then LOOP ;
T{ 5 -1 qd2 -> -1 0 1 2 3 }T

: qd3 ?DO I 1 +LOOP ;
T{ 4  4 qd3 -> }T
T{ 4  1 qd3 -> 1 2 3 }T
T{ 2 -1 qd3 -> -1 0 1 }T

: qd4 ?DO I -1 +LOOP ;
T{  4 4 qd4 -> }T
T{  1 4 qd4 -> 4 3 2 1 }T
T{ -1 2 qd4 -> 2 1 0 -1 }T

: qd5 ?DO I -10 +LOOP ;
T{   1 50 qd5 -> 50 40 30 20 10 }T
T{   0 50 qd5 -> 50 40 30 20 10 0 }T
T{ -25 10 qd5 -> 10 0 -10 -20 }T

VARIABLE iterations
VARIABLE increment

: qd6 ( limit start increment -- )
   increment !
   0 iterations !
   ?DO
      1 iterations +!
      I
      iterations @  6 = IF LEAVE THEN
      increment @
   +LOOP iterations @
;

T{  4  4 -1 qd6 -> 0 }T
T{  1  4 -1 qd6 -> 4 3 2 1 4 }T
T{  4  1 -1 qd6 -> 1 0 -1 -2 -3 -4 6 }T
T{  4  1  0 qd6 -> 1 1 1 1 1 1 6 }T
T{  0  0  0 qd6 -> 0 }T
T{  1  4  0 qd6 -> 4 4 4 4 4 4 6 }T
T{  1  4  1 qd6 -> 4 5 6 7 8 9 6 }T
T{  4  1  1 qd6 -> 1 2 3 3 }T
T{  4  4  1 qd6 -> 0 }T
T{  2 -1 -1 qd6 -> -1 -2 -3 -4 -5 -6 6 }T
T{ -1  2 -1 qd6 -> 2 1 0 -1 4 }T
T{  2 -1  0 qd6 -> -1 -1 -1 -1 -1 -1 6 }T
T{ -1  2  0 qd6 -> 2 2 2 2 2 2 6 }T
T{ -1  2  1 qd6 -> 2 3 4 5 6 7 6 }T
T{  2 -1  1 qd6 -> -1 0 1 3 }T

\ --------------------------------------------------------------------

Testing VALUE TO

T{ 111 VALUE v1 -999 VALUE v2 -> }T
T{ v1 -> 111 }T
T{ v2 -> -999 }T
T{ 222 TO v1 -> }T
T{ v1 -> 222 }T
T{ : vd1 v1 ; -> }T
T{ vd1 -> 222 }T
T{ : vd2 TO v2 ; -> }T
T{ v2 -> -999 }T
T{ -333 vd2 -> }T
T{ v2 -> -333 }T
T{ v1 -> 222 }T

\ --------------------------------------------------------------------

Testing CASE OF ENDOF ENDCASE

: cs1 CASE 1 OF 111 ENDOF
           2 OF 222 ENDOF
           3 OF 333 ENDOF
           >R 999 R>
      ENDCASE
;

T{ 1 cs1 -> 111 }T
T{ 2 cs1 -> 222 }T
T{ 3 cs1 -> 333 }T
T{ 4 cs1 -> 999 }T

: cs2 >R CASE -1 OF CASE R@ 1 OF 100 ENDOF
                            2 OF 200 ENDOF
                           >R -300 R>
                    ENDCASE
                 ENDOF
              -2 OF CASE R@ 1 OF -99  ENDOF
                            >R -199 R>
                    ENDCASE
                 ENDOF
                 >R 299 R>
         ENDCASE R> DROP
;

T{ -1 1 cs2 ->  100 }T
T{ -1 2 cs2 ->  200 }T
T{ -1 3 cs2 -> -300 }T
T{ -2 1 cs2 -> -99  }T
T{ -2 2 cs2 -> -199 }T
T{  0 2 cs2 ->  299 }T

\ --------------------------------------------------------------------

Testing C" CONVERT

T{ : cq1 C" 123" ; -> }T
T{ cq1 COUNT EVALUATE -> 123 }T
T{ : cq2 C" " ; -> }T
T{ cq2 COUNT EVALUATE -> }T

\ Create two large integers, small enough to not cause overflow
max-int 3 / CONSTANT cvi1
max-int 5 / CONSTANT cvi2

\ Create a string of the form "(n1digits.n2digits)"
: 2n>str  ( +n1 +n2 -- caddr u )
   <# [CHAR] ) HOLD S>D #S 2DROP    ( -- +n1 )
      [CHAR] . HOLD S>D #S
      [CHAR] ( HOLD #>              ( -- caddr1 u )
   HERE SWAP 2DUP 2>R CHARS DUP ALLOT MOVE 2R>
;

cvi1 cvi2 2n>str CONSTANT cv$len CONSTANT cv$ad

T{ 0 0 cv$ad CONVERT C@ -> cvi1 S>D CHAR . }T
T{ 0 0 cv$ad CONVERT CONVERT C@
      -> 0 0 cv$ad CHAR+ cv$len 1- >NUMBER
         1- SWAP CHAR+ SWAP >NUMBER 2DROP CHAR ) }T

\ --------------------------------------------------------------------

Testing COMPILE, [COMPILE]

:NONAME DUP + ; CONSTANT dup+
T{ : q dup+ COMPILE, ; -> }T
T{ : as [ q ] ; -> }T
T{ 123 as -> 246 }T

T{ : [c1] [COMPILE] DUP ; IMMEDIATE -> }T
T{ 123 [c1] -> 123 123 }T                 \ With default compilation semantics
T{ :  [c2] [COMPILE] [c1] ; -> }T
T{ 234 [c2] -> 234 234 }T                 \ With an immediate word
T{ : [cif] [COMPILE] IF ; IMMEDIATE -> }T
T{ : [c3] [cif] 111 ELSE 222 THEN ; -> }T \ With special compilation semantics
T{ -1 [c3] -> 111 }T
T{  0 [c3] -> 222 }T

\ --------------------------------------------------------------------

Testing NIP TUCK ROLL

T{ 1 2 3 NIP -> 1 3 }T
T{ 1 2 3 TUCK -> 1 3 2 3 }T
T{ 1 2 3 4 0 ROLL -> 1 2 3 4 }T
T{ 1 2 3 4 1 ROLL -> 1 2 4 3 }T
T{ 1 2 3 4 2 ROLL -> 1 3 4 2 }T
T{ 1 2 3 4 3 ROLL -> 2 3 4 1 }T

\ --------------------------------------------------------------------

Testing WITHIN

T{ 0 0 1 WITHIN -> <true> }T
T{ 1 0 1 WITHIN -> <false> }T
T{ -1 -1 1 WITHIN -> <true> }T
T{ 0 -1 1 WITHIN -> <true> }T
T{ 1 -1 1 WITHIN -> <false> }T
T{ MID-UINT MID-UINT MID-UINT+1 WITHIN -> <true> }T
T{ MID-UINT+1 MID-UINT MID-UINT+1 WITHIN -> <false> }T
T{ MID-UINT MID-UINT+1 MAX-UINT WITHIN -> <false> }T
T{ MID-UINT+1 MID-UINT+1 MAX-UINT WITHIN -> <true> }T

\ --------------------------------------------------------------------

CR .( End of Core Extension word tests) CR
