\ To test the ANS Forth Double-Number word set and double number extensions

\ Copyright (C) Gerry Jackson 2006, 2007, 2009

\ This program is free software; you can redistribute it and/or
\ modify it any way.

\ This program is distributed in the hope that it will be useful,
\ but WITHOUT ANY WARRANTY; without even the implied warranty of
\ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

\ The tests are not claimed to be comprehensive or correct 

\ --------------------------------------------------------------------
\ Version 0.4   6 March 2009 { and } replaced with T{ and }T
\               Tests rewritten to be independent of word size and
\               tests re-ordered
\         0.3   20 April 2007 ANS Forth words changed to upper case
\         0.2   30 Oct 2006 Updated following GForth test to include
\               various constants from core.fr
\         0.1   Oct 2006 First version released

\ --------------------------------------------------------------------
\ The tests are based on John Hayes test program for the core word set
\ and requires tester.fr to have been loaded

\ Words tested in this file are:
\     2CONSTANT 2LITERAL 2VARIABLE D+ D- D. D.R D0< D0= D2* D2/
\     D< D= D>S DABS DMAX DMIN DNEGATE M*/ M+ 2ROT DU<
\ Also tests the interpreter and compiler reading a double number

\ --------------------------------------------------------------------
\ Assumptions and dependencies:
\     - tester.fr has been included prior to this file
\     - core words and core extension words to have been tested
\ ------------------------------------------------------------------------------
\ Constant definitions

DECIMAL
0 INVERT       CONSTANT 1s
1s 1 RSHIFT    CONSTANT max-int  \ 01...1
max-int INVERT CONSTANT min-int  \ 10...0
max-int 2/     CONSTANT hi-int   \ 001...1
min-int 2/     CONSTANT lo-int   \ 110...1
0  CONSTANT <false>
1s CONSTANT <true>

\ ------------------------------------------------------------------------------
testing interpreter and compiler reading a double number

T{ 1. -> 1 0 }T
T{ -2. -> -2 -1 }T
T{ : rdl1 3. ; rdl1 -> 3 0 }T
T{ : rdl2 -4. ; rdl2 -> -4 -1 }T

\ ------------------------------------------------------------------------------
testing 2CONSTANT

T{ 1 2 2CONSTANT 2c1 -> }T
T{ 2c1 -> 1 2 }T
T{ : cd1 2c1 ; -> }T
T{ cd1 -> 1 2 }T
T{ : cd2 2CONSTANT ; -> }T
T{ -1 -2 cd2 2c2 -> }T
T{ 2c2 -> -1 -2 }T

\ ------------------------------------------------------------------------------
\ Some 2CONSTANTs for the following tests

1s max-int 2CONSTANT max-2int    \ 01...1
0  min-int 2CONSTANT min-2int    \ 10...0
max-2int 2/ 2CONSTANT hi-2int    \ 001...1
min-2int 2/ 2CONSTANT lo-2int    \ 110...0

\ ------------------------------------------------------------------------------
testing DNEGATE

T{ 0. DNEGATE -> 0. }T
T{ 1. DNEGATE -> -1. }T
T{ -1. DNEGATE -> 1. }T
T{ max-2int DNEGATE -> min-2int SWAP 1+ SWAP }T
T{ min-2int SWAP 1+ SWAP DNEGATE -> max-2int }T

\ ------------------------------------------------------------------------------
testing D+ with small integers

T{  0.  5. D+ ->  5. }T
T{ -5.  0. D+ -> -5. }T
T{  1.  2. D+ ->  3. }T
T{  1. -2. D+ -> -1. }T
T{ -1.  2. D+ ->  1. }T
T{ -1. -2. D+ -> -3. }T
T{ -1.  1. D+ ->  0. }T

testing D+ with mid range integers

T{  0  0  0  5 D+ ->  0  5 }T
T{ -1  5  0  0 D+ -> -1  5 }T
T{  0  0  0 -5 D+ ->  0 -5 }T
T{  0 -5 -1  0 D+ -> -1 -5 }T
T{  0  1  0  2 D+ ->  0  3 }T
T{ -1  1  0 -2 D+ -> -1 -1 }T
T{  0 -1  0  2 D+ ->  0  1 }T
T{  0 -1 -1 -2 D+ -> -1 -3 }T
T{ -1 -1  0  1 D+ -> -1  0 }T
T{ min-int 0 2DUP D+ -> 0 1 }T
T{ min-int S>D min-int 0 D+ -> 0 0 }T

testing D+ with large double integers

T{ hi-2int 1. D+ -> 0 hi-int 1+ }T
T{ hi-2int 2DUP D+ -> 1s 1- max-int }T
T{ max-2int min-2int D+ -> -1. }T
T{ max-2int lo-2int D+ -> hi-2int }T
T{ hi-2int min-2int D+ 1. D+ -> lo-2int }T
T{ lo-2int 2DUP D+ -> min-2int }T

\ --------------------------------------------------------------------
testing D- with small integers

T{  0.  5. D- -> -5. }T
T{  5.  0. D- ->  5. }T
T{  0. -5. D- ->  5. }T
T{  1.  2. D- -> -1. }T
T{  1. -2. D- ->  3. }T
T{ -1.  2. D- -> -3. }T
T{ -1. -2. D- ->  1. }T
T{ -1. -1. D- ->  0. }T

testing D- with mid-range integers

T{  0  0  0  5 D- ->  0 -5 }T
T{ -1  5  0  0 D- -> -1  5 }T
T{  0  0 -1 -5 D- ->  1  4 }T
T{  0 -5  0  0 D- ->  0 -5 }T
T{ -1  1  0  2 D- -> -1 -1 }T
T{  0  1 -1 -2 D- ->  1  2 }T
T{  0 -1  0  2 D- ->  0 -3 }T
T{  0 -1  0 -2 D- ->  0  1 }T
T{  0  0  0  1 D- ->  0 -1 }T
T{ min-int 0 2DUP D- -> 0. }T
T{ min-int S>D max-int 0 D- -> 1 1s }T

testing D- with large integers

T{ max-2int max-2int D- -> 0. }T
T{ min-2int min-2int D- -> 0. }T
T{ max-2int hi-2int  D- -> lo-2int DNEGATE }T
T{ hi-2int  lo-2int  D- -> max-2int }T
T{ lo-2int  hi-2int  D- -> min-2int 1. D+ }T
T{ min-2int min-2int D- -> 0. }T
T{ min-2int lo-2int  D- -> lo-2int }T

\ --------------------------------------------------------------------
testing D0< D0=

T{ 0. D0< -> <false> }T
T{ 1. D0< -> <false> }T
T{ min-int 0 D0< -> <false> }T
T{ 0 max-int D0< -> <false> }T
T{ max-2int  D0< -> <false> }T
T{ -1. D0< -> <true> }T
T{ min-2int D0< -> <true> }T

T{ 1. D0= -> <false> }T
T{ min-int 0 D0= -> <false> }T
T{ max-2int  D0= -> <false> }T
T{ -1 max-int D0= -> <false> }T
T{ 0. D0= -> <true> }T
T{ -1. D0= -> <false> }T
T{ 0 min-int D0= -> <false> }T

\ --------------------------------------------------------------------
testing D2* D2/

T{ 0. D2* -> 0. D2* }T
T{ min-int 0 D2* -> 0 1 }T
T{ hi-2int D2* -> max-2int 1. D- }T
T{ lo-2int D2* -> min-2int }T

T{ 0. D2/ -> 0. }T
T{ 1. D2/ -> 0. }T
T{ 0 1 D2/ -> min-int 0 }T
T{ max-2int D2/ -> hi-2int }T
T{ -1. D2/ -> -1. }T
T{ min-2int D2/ -> lo-2int }T

\ --------------------------------------------------------------------
testing D< D=

T{  0.  1. D< -> <true>  }T
T{  0.  0. D< -> <false> }T
T{  1.  0. D< -> <false> }T
T{ -1.  1. D< -> <true>  }T
T{ -1.  0. D< -> <true>  }T
T{ -2. -1. D< -> <true>  }T
T{ -1. -2. D< -> <false> }T
T{ -1. max-2int D< -> <true> }T
T{ min-2int max-2int D< -> <true> }T
T{ max-2int -1. D< -> <false> }T
T{ max-2int min-2int D< -> <false> }T
T{ max-2int 2DUP -1. D+ D< -> <false> }T
T{ min-2int 2DUP  1. D+ D< -> <true>  }T
T{ -1 1 1 1 D< -> <false> }T
T{ -1 1 1 1 D> -> <true> }T
T{ 1 -1 1 1 D> -> <false> }T
T{ 1 -1 1 1 D< -> <true> }T
T{ -1 -1 1 -1 D> -> <true> }T
T{ -1 -1 1 -1 D< -> <false> }T

T{ -1. -1. D= -> <true>  }T
T{ -1.  0. D= -> <false> }T
T{ -1.  1. D= -> <false> }T
T{  0. -1. D= -> <false> }T
T{  0.  0. D= -> <true>  }T
T{  0.  1. D= -> <false> }T
T{  1. -1. D= -> <false> }T
T{  1.  0. D= -> <false> }T
T{  1.  1. D= -> <true>  }T

T{ 0 -1 0 -1 D= -> <true>  }T
T{ 0 -1 0  0 D= -> <false> }T
T{ 0 -1 0  1 D= -> <false> }T
T{ 0  0 0 -1 D= -> <false> }T
T{ 0  0 0  0 D= -> <true>  }T
T{ 0  0 0  1 D= -> <false> }T
T{ 0  1 0 -1 D= -> <false> }T
T{ 0  1 0  0 D= -> <false> }T
T{ 0  1 0  1 D= -> <true>  }T

T{ max-2int min-2int D= -> <false> }T
T{ max-2int 0. D= -> <false> }T
T{ max-2int max-2int D= -> <true> }T
T{ max-2int hi-2int  D= -> <false> }T
T{ max-2int min-2int D= -> <false> }T
T{ min-2int min-2int D= -> <true> }T
T{ min-2int lo-2int  D=  -> <false> }T
T{ min-2int max-2int D= -> <false> }T

\ --------------------------------------------------------------------
testing 2LITERAL 2VARIABLE

T{ : cd1 [ max-2int ] 2LITERAL ; -> }T
T{ cd1 -> max-2int }T
T{ 2VARIABLE 2v1 -> }T
T{ 0. 2v1 2! -> }T
T{ 2v1 2@ -> 0. }T
T{ -1 -2 2v1 2! -> }T
T{ 2v1 2@ -> -1 -2 }T
T{ : cd2 2VARIABLE ; -> }T
T{ cd2 2v2 -> }T
T{ : cd3 2v2 2! ; -> }T
T{ -2 -1 cd3 -> }T
T{ 2v2 2@ -> -2 -1 }T

\ --------------------------------------------------------------------
testing DMAX DMIN

T{  1.  2. DMAX -> 2. }T
T{  1.  0. DMAX -> 1. }T
T{  1. -1. DMAX -> 1. }T
T{  1.  1. DMAX -> 1. }T
T{  0.  1. DMAX -> 1. }T
T{  0. -1. DMAX -> 0. }T
T{ -1.  1. DMAX -> 1. }T
T{ -1. -2. DMAX -> -1. }T

T{ max-2int hi-2int  DMAX -> max-2int }T
T{ max-2int min-2int DMAX -> max-2int }T
T{ min-2int max-2int DMAX -> max-2int }T
T{ min-2int lo-2int  DMAX -> lo-2int  }T

T{ max-2int  1. DMAX -> max-2int }T
T{ max-2int -1. DMAX -> max-2int }T
T{ min-2int  1. DMAX ->  1. }T
T{ min-2int -1. DMAX -> -1. }T


T{  1.  2. DMIN ->  1. }T
T{  1.  0. DMIN ->  0. }T
T{  1. -1. DMIN -> -1. }T
T{  1.  1. DMIN ->  1. }T
T{  0.  1. DMIN ->  0. }T
T{  0. -1. DMIN -> -1. }T
T{ -1.  1. DMIN -> -1. }T
T{ -1. -2. DMIN -> -2. }T

T{ max-2int hi-2int  DMIN -> hi-2int  }T
T{ max-2int min-2int DMIN -> min-2int }T
T{ min-2int max-2int DMIN -> min-2int }T
T{ min-2int lo-2int  DMIN -> min-2int }T

T{ max-2int  1. DMIN ->  1. }T
T{ max-2int -1. DMIN -> -1. }T
T{ min-2int  1. DMIN -> min-2int }T
T{ min-2int -1. DMIN -> min-2int }T

\ --------------------------------------------------------------------
testing D>S DABS

T{  1234  0 D>S ->  1234 }T
T{ -1234 -1 D>S -> -1234 }T
T{ max-int  0 D>S -> max-int }T
T{ min-int -1 D>S -> min-int }T

T{  1. DABS -> 1. }T
T{ -1. DABS -> 1. }T
T{ max-2int DABS -> max-2int }T
T{ min-2int 1. D+ DABS -> max-2int }T

\ --------------------------------------------------------------------
testing M+ M*/

T{ hi-2int   1 M+ -> hi-2int   1. D+ }T
T{ max-2int -1 M+ -> max-2int -1. D+ }T
T{ min-2int  1 M+ -> min-2int  1. D+ }T
T{ lo-2int  -1 M+ -> lo-2int  -1. D+ }T

\ To correct the result if the division is floored, only used when
\ necessary i.e. negative quotient and remainder <> 0

: ?floored [ -3 2 / -2 = ] LITERAL IF 1. D- THEN ;

T{  5.  7 11 M*/ ->  3. }T
T{  5. -7 11 M*/ -> -3. ?floored }T    \ floored -4.
T{ -5.  7 11 M*/ -> -3. ?floored }T    \ floored -4.
T{ -5. -7 11 M*/ ->  3. }T
T{ max-2int  8 16 M*/ -> hi-2int }T
T{ max-2int -8 16 M*/ -> hi-2int DNEGATE ?floored }T  \ floored subtract 1
T{ min-2int  8 16 M*/ -> lo-2int }T
T{ min-2int -8 16 M*/ -> lo-2int DNEGATE }T
T{ max-2int max-int max-int M*/ -> max-2int }T
T{ max-2int max-int 2/ max-int M*/ -> max-int 1- hi-2int NIP }T
T{ min-2int lo-2int NIP DUP NEGATE M*/ -> min-2int }T
T{ min-2int lo-2int NIP 1- max-int M*/ -> min-int 3 + hi-2int NIP 2 + }T
T{ max-2int lo-2int NIP DUP NEGATE M*/ -> max-2int DNEGATE }T
T{ min-2int max-int DUP M*/ -> min-2int }T

\ --------------------------------------------------------------------
testing D. D.R

\ Create some large double numbers
max-2int 71 73 m*/ 2CONSTANT dbl1
min-2int 73 79 m*/ 2CONSTANT dbl2

: d>ascii  ( d -- caddr u )
   DUP >R <# DABS #S R> SIGN #>    ( -- caddr1 u )
   HERE SWAP 2DUP 2>R CHARS DUP ALLOT MOVE 2R>
;

dbl1 d>ascii 2CONSTANT "dbl1"
dbl2 d>ascii 2CONSTANT "dbl2"

: DoubleOutput
   CR ." You should see lines duplicated:" CR
   5 SPACES "dbl1" TYPE CR
   5 SPACES dbl1 D. CR
   8 SPACES "dbl1" DUP >R TYPE CR
   5 SPACES dbl1 R> 3 + D.R CR
   5 SPACES "dbl2" TYPE CR
   5 SPACES dbl2 D. CR
   10 SPACES "dbl2" DUP >R TYPE CR
   5 SPACES dbl2 R> 5 + D.R CR
;

T{ DoubleOutput -> }T

\ --------------------------------------------------------------------
testing 2ROT DU< (Double Number extension words)

T{ 1. 2. 3. 2ROT -> 2. 3. 1. }T
T{ max-2int min-2int 1. 2ROT -> min-2int 1. max-2int }T

T{  1.  1. DU< -> <false> }T
T{  1. -1. DU< -> <true>  }T
T{ -1.  1. DU< -> <false> }T
T{ -1. -2. DU< -> <false> }T

T{ max-2int hi-2int  DU< -> <false> }T
T{ hi-2int  max-2int DU< -> <true>  }T
T{ max-2int min-2int DU< -> <true> }T
T{ min-2int max-2int DU< -> <false> }T
T{ min-2int lo-2int  DU< -> <true> }T

\ --------------------------------------------------------------------

CR .( End of Double-Number word tests) CR

