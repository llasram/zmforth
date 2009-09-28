\ Copyright (c) 2009 Marshall Vandegrift
\
\ This program is free software: you can redistribute it and/or modify
\ it under the terms of the GNU General Public License as published by
\ the Free Software Foundation, either version 3 of the License, or
\ (at your option) any later version.
\
\ This program is distributed in the hope that it will be useful,
\ but WITHOUT ANY WARRANTY; without even the implied warranty of
\ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
\ GNU General Public License for more details.
\
\ You should have received a copy of the GNU General Public License
\ along with this program.  If not, see <http://www.gnu.org/licenses/>.

\ Programming-Tools
: .s depth dup [char] < emit (.) type [char] > emit space
    begin dup 0> while dup pick . 1- repeat drop ;
: zeros 0 ?do [char] 0 emit loop ;
: u.0r swap 0 <# #s #> rot over - dup 0> if zeros else drop then type ;
: dump ( addr u -- )
    base @ >r hex
    over + over [ 15 invert ] literal and over swap ?do
        i 4 u.0r 2 spaces i 16 + i ?do
            2dup i rot- within if
                i c@ 2 u.0r
            else 2 spaces then
            i 2 mod abs 1+ spaces
        loop [char] | emit
        i 16 + i ?do
            2dup i rot- within if
                i c@ dup 32 127 within not if
                    drop [char] .
                then emit
            else space then
        loop [char] | emit cr
    16 +loop 2drop r> base ! ;
: >name ( addr -- addr u ) cell+ dup 1+ swap c@ 31 and ;
: cfa>+ ( addr -- addr addr )
    here >r latest @ begin
        2dup u< over and while
            r> drop dup >r @ repeat
    swap drop r> swap ;
: cfa> ( addr -- addr ) cfa>+ swap drop ;
: ? @ . ;
: indent 4 spaces ;
: words ( -- )
    base @ hex latest begin
        @ ?dup while
            cr dup >cfa 4 u.r space dup >name type
    repeat space base ! ;
: see-literal cell+ dup @ . ;
: see-string cell+ count 2dup type + aligned cell- ;
: see-sliteral .( s" ) see-string .( " ) ;
: see-csliteral .( c" ) see-string .( " ) ;
: see-: dup >name type >cfa - ?dup if [char] + emit . then space ;
: see ( "<spaces>name" -- )
    ' dup >r ." : " cfa>+
    dup >name type space
    >dfa ( prev dfa ) begin
        cr indent ." ( " dup r@ - 3 u.r space ." ) "
        dup @ case
            ['] (literal) of see-literal endof
            ['] (sliteral) of see-sliteral endof
            ['] (csliteral) of see-csliteral endof
            dup cfa> ?dup if see-: else . then dup
        endcase
        cell+ 2dup cell+ <> while
    repeat
    ." ; " 2drop r> drop ;
: [undefined] bl parse-word find swap 0= ; immediate
: [else] ( -- )
    1 begin begin bl parse-word dup while
        2dup s" [if]" compare-word if 2drop 1+ else 2dup s" [else]"
            compare-word if 2drop 1- dup if 1+ then
            else s" [then]" compare-word if 1- then then
        then ?dup 0= if exit then
    repeat 2drop refill 0= until drop ; immediate
: [if] ( flag -- ) 0= if postpone [else] then ; immediate
: [then] ( -- ) ; immediate

:environment? tools true ;
\ Everything but the assembly-related words
:environment? tools-ext true ;
