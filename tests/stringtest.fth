\ To test the ANS Forth String word set

\ Copyright (C) Gerry Jackson 2006, 2007

\ This program is free software; you can redistribute it and/or
\ modify it any way.

\ This program is distributed in the hope that it will be useful,
\ but WITHOUT ANY WARRANTY; without even the implied warranty of
\ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

\ The tests are not claimed to be comprehensive or correct 

\ --------------------------------------------------------------------
\ Version 0.3 6 March 2009 { and } replaced with T{ and }T
\         0.2 20 April 2007 ANS Forth words changed to upper case
\         0.1 Oct 2006 First version released

\ --------------------------------------------------------------------
\ The tests are based on John Hayes test program for the core word set
\ and requires those files to have been loaded

\ Words tested in this file are:
\     -TRAILING /STRING BLANK COMPARE SEARCH SLITERAL
\
\ Tests to be added:
\     CMOVE CMOVE>
\     
\ --------------------------------------------------------------------
\ Assumptions and dependencies:
\     - tester.fr has been loaded prior to this file
\     - COMPARE is case sensitive
\ --------------------------------------------------------------------

Testing String word set

DECIMAL

0 INVERT CONSTANT <true>
0 CONSTANT <false>

T{ :  s1 S" abcdefghijklmnopqrstuvwxyz" ; -> }T
T{ :  s2 S" abc"   ; -> }T
T{ :  s3 S" jklmn" ; -> }T
T{ :  s4 S" z"     ; -> }T
T{ :  s5 S" mnoq"  ; -> }T
T{ :  s6 S" 12345" ; -> }T
T{ :  s7 S" "      ; -> }T
T{ :  s8 S" abc  " ; -> }T
T{ :  s9 S"      " ; -> }T
T{ : s10 S"    a " ; -> }T

\ --------------------------------------------------------------------

Testing -TRAILING

T{  s1 -TRAILING -> s1 }T
T{  s8 -TRAILING -> s8 2 - }T
T{  s7 -TRAILING -> s7 }T
T{  s9 -TRAILING -> s9 DROP 0 }T
T{ s10 -TRAILING -> s10 1- }T

\ --------------------------------------------------------------------

Testing /STRING

T{ s1  5 /STRING -> s1 SWAP 5 + SWAP 5 - }T
T{ s1 10 /STRING -4 /STRING -> s1 6 /STRING }T
T{ s1  0 /STRING -> s1 }T

\ --------------------------------------------------------------------

Testing SEARCH

T{ s1 s2 SEARCH -> s1 <true> }T
T{ s1 s3 SEARCH -> s1  9 /STRING <true> }T
T{ s1 s4 SEARCH -> s1 25 /STRING <true> }T
T{ s1 s5 SEARCH -> s1 <false> }T
T{ s1 s6 SEARCH -> s1 <false> }T
T{ s1 s7 SEARCH -> s1 <true> }T

\ --------------------------------------------------------------------

Testing COMPARE

T{ s1 s1 COMPARE -> 0 }T
T{ s1 PAD SWAP CMOVE -> }T
T{ s1 PAD OVER COMPARE -> 0 }T
T{ s1 PAD 6 COMPARE -> 1 }T
T{ PAD 10 s1 COMPARE -> -1 }T
T{ s1 PAD 0 COMPARE -> 1 }T
T{ PAD  0 s1 COMPARE -> -1 }T
T{ s1 s6 COMPARE ->  1 }T
T{ s6 s1 COMPARE -> -1 }T

: "abdde"  S" abdde" ;
: "abbde"  S" abbde" ;
: "abcdf"  S" abcdf" ;
: "abcdee" S" abcdee" ;

T{ s1 "abdde" COMPARE -> -1 }T
T{ s1 "abbde" COMPARE ->  1 }T
T{ s1 "abcdf"  COMPARE -> -1 }T
T{ s1 "abcdee" COMPARE ->  1 }T

: s11 S" 0abc" ;
: s12 S" 0aBc" ;

T{ s11 s12  COMPARE -> 1 }T
T{ s12 s11  COMPARE -> -1 }T

\ --------------------------------------------------------------------

Testing BLANK

: s13 S" aaaaa      a" ;   \ Don't move this down or might corrupt PAD

T{ PAD 25 CHAR a FILL -> }T
T{ PAD 5 CHARS + 6 BLANK -> }T
T{ PAD 12 s13 COMPARE -> 0 }T

\ --------------------------------------------------------------------

Testing SLITERAL

T{ : s14 [ s1 ] SLITERAL ; -> }T
T{ s1 s14 COMPARE -> 0 }T
T{ s1 s14 ROT = ROT ROT = -> <true> <false> }T


\ --------------------------------------------------------------------

CR .( End of String word tests) CR
