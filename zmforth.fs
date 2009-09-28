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

\ Primitives unneeded in hand-compiled code
: if compile ?branch here 0 , ; immediate
: then here swap ! ; immediate
: literal compile (literal) , ; immediate
: ' --' ?abort-find drop ;
: [compile] ' , ; immediate
: postpone --' ?abort-find -1 = if compile compile then , ; immediate
: 2literal swap postpone literal postpone literal ; immediate
: ['] ' [compile] literal ; immediate
: char bl word 1+ c@ ;
: [char] char [compile] literal ; immediate
: recurse $recurse @ , ; immediate
: sliteral compile (sliteral) uncount ; immediate
: s" '"' parse state @ if [compile] sliteral then ; immediate
: ." [compile] s" state @ if compile then type ; immediate
: s( ')' parse state @ if [compile] sliteral then ; immediate
: .( [compile] s( state @ if compile then type ; immediate
: csliteral compile (csliteral) uncount ; immediate
: c" '"' parse [compile] csliteral ; immediate
: abort" postpone c" compile (abort") ; immediate
: compile, , ;
: hex 16 base ! ;
: decimal 10 base ! ;

\ Word creation and deletion
: create create> .: , compile (create) ;
: variable create> .variable , 0 , ;
: 2variable create> .variable , 0 0 2, ;
: constant create> .constant , , ;
: 2constant create> .2constant , 2, ;
: user create> .user , >user dup @ , cell+ swap +! ;
: :noname align here dup $recurse ! .: , ] ;
: (does) r> dup cell+ >r @ latest @ >dfa ! ;
: does> compile (does) here 0 , postpone ;
    :noname swap ! compile r> ; immediate
: value create , does> @ ;
: to ' >body state @ if [compile] literal compile then ! ; immediate
: (marker) r> dup @ dup @ latest ! cp ! cell+ >r ;
: marker : compile (marker) latest @ , postpone ; ;
: forget bl word find-header ?abort-find drop dup @ latest ! cp ! ;

\ Flow-control
: begin here ; immediate
: again compile branch , ; immediate
: until compile ?branch , ; immediate
: ahead compile branch here 0 , ; immediate
: while postpone if 1 roll ; immediate
: repeat postpone again postpone then ; immediate
: else postpone ahead 1 roll postpone then ; immediate
variable leaves
: do leaves @ 0 leaves ! compile 2>r here ; immediate
: (?do) r> rot- 2dup = if 2drop @ else 2>r cell+ then >r ;
: ?do leaves @ compile (?do) here leaves ! 0 , here ; immediate
: (leave) r> 2r> 2drop @ >r ;
: leave compile (leave) here leaves dup @ , ! ; immediate
: rake begin ?dup while dup @ swap here swap ! repeat ;
: loop-resolve , leaves dup @ rake ! ;
: loop compile (loop) loop-resolve ; immediate
: +loop compile (+loop) loop-resolve ; immediate
: unloop r> 2r> 2drop >r ;
: case 0 ; immediate
: (of) over = r> swap if cell+ swap drop else @ then >r ;
: of compile (of) here 0 , ; immediate
: endof compile branch here rot , here rot ! ; immediate
: endcase compile drop rake ; immediate

\ Arithmetic
: m+ s>d d+ ;
: m* dup 0< >r abs swap dup 0< >r abs um* 2r> - if dnegate then ;
: sm/rem rot- 2dup d0< >r dabs rot dup 0< >r abs um/mod
    2r@ xor if negate then 2r> drop if swap negate swap then ;
: fm/mod dup >r sm/rem over 0<> >r dup 0< r> and
    if 1- swap r> + swap else r> drop then ;
: */mod >r m* r> sm/rem ;
: */ */mod swap drop ;
: d- dnegate d+ ;
: dmax 2over 2over d< if 2swap then 2drop ;
: dmin 2over 2over d> if 2swap then 2drop ;
: m*/ ( d1 n1 n2 -- d2 )
    dup 0< rot- abs >r
    dup 0< rot- abs >r xor rot-
    2dup d0< rot- dabs 2swap xor rot- ( f d1 ) ( r: n2 n1 )
    r@ um* rot r> um* ( f dhigh dlow )
    swap >r 0 d+ r> 0 2swap ( f dlow dhigh )
    r@ um/mod 0 swap rot 0 swap 2rot d+ r> um/mod+ rot drop
    d+ rot if dnegate then ;

\ Misc core/core-ext routines
: spaces 0 ?do space loop ;
: erase 0 fill ;
: evaluate ( i*x c-addr u -- j*x )
    -1 $source-id dup @ >r ! 0 >in dup @ >r ! #tib dup @ >r ! ctib dup @ >r !
    ['] interpret catch r> ctib ! r> #tib ! r> >in ! r> $source-id ! throw ;

\ Number formatting
: <# pad hld ! ;
: hold hld dup @ 1- rot over c! swap ! ;
: digit 9 over < 7 and + [char] 0 + ;
: # base @ um/mod+ rot digit hold ;
: #s begin # 2dup d0= until ;
: sign 0< if [char] - hold then ;
: #> 2drop hld @ dup pad swap - ;
: (.) dup s>d dabs <# #s rot sign #> ;
: . (.) type space ;
: u. 0 <# #s #> type space ;
: (d.) swap over dabs <# #s rot sign #> ;
: d. (d.) type space ;
: ud. <# #s #> type space ;
: (.r) rot over - dup 0> if spaces else drop then type ;
: .r swap (.) (.r) ;
: u.r swap 0 <# #s #> (.r) ;
: d.r rot- (d.) (.r) ;

\ Strings
: /string dup 2swap rot - rot- + swap ;
: blank 32 fill ;

\ Environment queries
variable eqlatest 0 eqlatest !
: :environment? here eqlatest dup @ , ! bl parse-word uncount :noname drop ;
: environment? ( c-addr u -- false | i*x true )
    eqlatest begin @ dup while
            dup cell+ 2over rot count compare-word if
                rot- 2drop cell+ count + align execute true exit then
    repeat drop 2drop false ;
:environment? /counted-string 255 ;
:environment? /hold 128 ;
:environment? /pad 32767 ;
:environment? address-unit-bits 8 ;
:environment? core true ;
:environment? core-ext true ;
:environment? floored false ;
:environment? max-char 255 ;
:environment? max-d -1 32767 ;
:environment? max-n 32767 ;
:environment? max-u -1 ;
:environment? max-ud -1 -1 ;
:environment? return-stack-cells 512 ;
:environment? stack-cells 512 ;
:environment? double true ;
:environment? double-ext true ;
:environment? exception true ;
:environment? exception-ext true ;
:environment? facility true ;
:environment? facility-ext false ;
:environment? string true ;
