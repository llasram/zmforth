// ZmForth! -- an ANS Forth implementation for the Z-machine

// Copyright (c) 2009 Marshall Vandegrift
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
        
#define IMMEDIATE (0x80)
#define HIDDEN (0x20)
#define LENMASK (0x1f)

.section data

header: .fill 0x40

// We're using the highest global registers as the forth interpreter pointers
globals:
        .globals globals
        .fill 236, 2, 0
#define WINDOW %g232
#define KIN %g233
#define KOUT %g234
#define TIMEOUTS %g235
#define UP %g236
        .word uvar
#define RSP %g237
        .word rstack
#define PSP %g238
        .word pstack
#define IP %g239
        .word 0

#define KBUFSZ 32
_kbuf:  // Single-key input-buffer
        .fill KBUFSZ, 1, 0

_abuf:  // ACCEPT buffer
        .fill 1024, 1, 0

uvar:   // Enough space for 8 tasks with 32 user variables each.
        .set _uoff, 0           // Current user variable offset
        .set _unext, uvar       // Address of next user variable
        .fill 32 * 8, 2, 0

tibtop: // TIB grows downwards
        .fill 1024, 1, 0

pstack: // Parameter stack grows upwards
        .fill 4, 2, 0           // Small underflow buffer

dict:   // The dictionary, where all the Forth words live
        .set _link, 0           // Dictionary last-link pointer

        // Hop down to the very end of allowed dynamic memory
        .fill (header + 0xfffa) - dict

rstack: // Return stack grows upwards
        .word 0

// Go back to the beginning of the dictionary
.org dict

 // Get the Forth party started
.section text
_start: .start _start
        calln forth
        quit

// Stack-manipulation helpers.
#define RS_PUSH(arg) \
        sub RSP, 2, RSP; \
        storew RSP, 0, arg
#define RS_POP(dst) \
        loadw RSP, 0, dst; \
        add RSP, 2, RSP
#define PS_PUSH(arg) \
        sub PSP, 2, PSP; \
        storew PSP, 0, arg
#define PS_POP(dst) \
        loadw PSP, 0, dst; \
        add PSP, 2, PSP

// Basic dictionary linked-list header
#define HEAD(name, flags, label1) \
.section data; \
.label entry_ ## label1; \
        .word _link; \
        .set _link, entry_ ## label1; \
        .set _name, .; \
        .byte 0; \
        .ascii name; \
        .set _len, (. - _name) - 1; \
        .align 2; \
        .set _here, .; \
        .org _name; \
        .byte _len | flags; \
        .org _here; \
.label label1
// end macro definition

// Macro to define a machine-code Forth word.  Adds the word to the dictionary
// and leaves the assembler ready for the word code to follow.  We're using
// indirect threaded code, so the word still needs an executor, but for machine
// code words the executor is just the word's code itself.
#define CODE(name, flags, label1) \
        HEAD(name, flags, label1); \
        .word @code_ ## label1; \
.section text; \
        .align 4; \
.label code_ ## label1
// end macro definition

//////
// Basic definitions for the Forth "inner interpreter."  The inner interpreter
// executes the indirect threaded code, but also needs to be able to support
// methods for encoding literal values and branching.

// Core Forth inner interpreter for indirect threaded code.  Executes the Forth
// word pointed at by the Forth instruction pointer via its word-specific
// executor function and advances the Forth IP.  Passes the address of the
// definition being executed in %l0 to avoid extra return stack operations
// when executing native code definitions.
//
// This inner interpreter implementation uses a vectored `jump' instruction to
// transfer control to the code implementing the target Forth word.  The
// Z-machine `jump' instruction is always relative, which means we need to do
// some address arithmetic in order to get to the right place.  Vectored `call'
// instructions are a bit easier and work just as well, but the Z-machine
// routine model would mean needing to be careful to always correctly `ret' and
// losing all local registers across calls.
//
.section text
.routine forth, 15
        store _boot, IP
_next:  loadw IP, 0, %l0
        add IP, 2, IP
_exec:  loadw %l0, 0, %l1
        sub %l1, @1f, %l1
        art_shift %l1, 2, %l1
        add %l1, 2, %l1
        jump %l1
1:      // Nothing -- we just want the address after the jump.

// Executor for Forth words coded as indirect threaded code.  This handles
// getting the interpreter pointer pointed at the right place then lets _next
// handle the rest.
        .align 4
docol:  RS_PUSH(IP)
        add %l0, 2, IP
        jump _next

// Finish executing a Forth word.  Pops the IP off the return stack then lets
// _next handle the rest.
CODE("exit", 0, exit)
        RS_POP(IP)
        jump _next

// Read a literal word from the Forth definition and push it on the stack.
CODE("(literal)", 0, dolit)                     // ( -- n|u )
        loadw IP, 0, %l0
        PS_PUSH(%l0)
        add IP, 2, IP
        jump _next

// Read a literal string from the Forth definition and push it on the stack
CODE("(sliteral)", 0, dosliteral)               // ( -- c-addr u )
        loadb IP, 0, %l1
        add IP, 1, %l0
        PS_PUSH(%l0)
        PS_PUSH(%l1)
        add %l0, %l1, IP
        and IP, 1, %l2
        add IP, %l2, IP
        jump _next

// Ditto, but push the string on as a counted string
CODE("(csliteral)", 0, docsliteral)             // ( -- c-addr )
        PS_PUSH(IP)
        loadb IP, 0, %l0
        add IP, %l0, IP
        inc IP
        and IP, 1, %l1
        add IP, %l1, IP
        jump _next

// Unconditional branch.
CODE("branch", 0, branch)
        loadw IP, 0, IP
        jump _next

// Conditional branch, only if flag is 0.
CODE("?branch", 0, qbranch)
        PS_POP(%l0)
        jz %l0, 1f
        add IP, 2, IP
        jump _next
1:      loadw IP, 0, IP
        jump _next

// Optimized loop constructs
CODE("(loop)", 0, doloop)
        loadw RSP, 0, %l0
        loadw RSP, 1, %l1
        inc %l0
        je %l0, %l1, 1f
        storew RSP, 0, %l0
        loadw IP, 0, IP
        jump _next
1:      add RSP, 4, RSP
        add IP, 2, IP
        jump _next

// ANS Forth +loop needs to terminate the loop when the loop index "cross[es]
// the boundary between the loop limit minus one and the loop limit."  This
// allows +loop to be used with signed and unsigned numbers and with positive
// and negative increments, but it's a pain in the ass to implement correctly.
CODE("(+loop)", 0, doplusloop)
        loadw RSP, 0, %l0
        loadw RSP, 1, %l1
        PS_POP(%l3)
        store 0, %l4
        jge %l0, %l1, 1f
        jl %l3, 0, 2f
        store 1, %l4
        jump 2f
1:      jg %l3, 0, 2f
        store 2, %l4
2:      add %l0, %l3, %l0
        jl %l0, %l1, 3f
        and %l4, 1, %l4
        jump 4f
3:      and %l4, 2, %l4
4:      jnz %l4, 5f
        storew RSP, 0, %l0
        loadw IP, 0, IP
        jump _next
5:      add RSP, 4, RSP
        add IP, 2, IP
        jump _next

// Execute a Forth word on the parameter stack.
CODE("execute", 0, execute)
        PS_POP(%l0)
        jump _exec

CODE("@execute", 0, fetchexecute)
        PS_POP(%l0)
        loadw %l0, 0, %l0
        jump _exec

// Macro to set up the dictionary entry etc. for hand-compiled Forth.  Now that
// we have the inner interpreter written, we can write Forth-wise when
// convenient.
#define COLON(name, flags, label1) \
        HEAD(name, flags, label1); \
        .word @docol
// end macro definition

////
// Basic return stack manipulation operations.

CODE("rp!", 0, rpstore)
        PS_POP(RSP)
        jump _next

CODE("rp@", 0, rpfetch)
        PS_PUSH(RSP)
        jump _next

CODE("r>", 0, fromr)
        RS_POP(%l0)
        PS_PUSH(%l0)
        jump _next

CODE("2r>", 0, twofromr)
        RS_POP(%l0)
        RS_POP(%l1)
        PS_PUSH(%l1)
        PS_PUSH(%l0)
        jump _next

CODE("r@", 0, rfetch)
CODE("i", 0, loopi)
        loadw RSP, 0, %l0
        PS_PUSH(%l0)
        jump _next

CODE("j", 0, loopj)
        loadw RSP, 2, %l0
        PS_PUSH(%l0)
        jump _next

CODE("2r@", 0, tworfetch)
        loadw RSP, 0, %l0
        loadw RSP, 1, %l1
        PS_PUSH(%l1)
        PS_PUSH(%l0)
        jump _next

CODE(">r", 0, tor)
        PS_POP(%l0)
        RS_PUSH(%l0)
        jump _next

CODE("2>r", 0, twotor)
        PS_POP(%l0)
        PS_POP(%l1)
        RS_PUSH(%l1)
        RS_PUSH(%l0)
        jump _next

CODE("rpick", 0, rpick)
        loadw PSP, 0, %l0
        loadw RSP, %l0, %l0
        storew PSP, 0, %l0
        jump _next

////
// Variable and user variable handling.  Now that we have >R we can implement
// variable handling in a Forth-wise reproducible fashion.

// Interpreter for variables.
.section text
.align 4
dovar:  add %l0, 2, %l0
        PS_PUSH(%l0)
        jump _next

// Macro to set up the dictionary entry etc. for a variable.
#define VARIABLE(name, flags, label1) \
        HEAD(name, flags, label1); \
        .word @dovar; \
.label var_ ## label1
// end macro definition

////
// Constants.

// Interpreter for constants.
.section text
.align 4
doconst:
        loadw %l0, 1, %l0
        PS_PUSH(%l0)
        jump _next

// Macro to set up the dictionary entry etc. for a constant.
#define CONSTANT(name, flags, label1, value) \
        HEAD(name, flags, label1); \
        .word @doconst; \
.label const_ ## label1; \
        .word value
// end macro definition

// Interpreter for 2constants.
.section text
.align 4
do2const:
        loadw %l0, 1, %l1
        loadw %l0, 2, %l0
        PS_PUSH(%l0)
        PS_PUSH(%l1)
        jump _next

// Macro to set up the dictionary entry etc. for a 2constant.
#define TWOCONSTANT(name, flags, label1, value1, value2) \
        HEAD(name, flags, label1); \
        .word @do2const; \
.label const_ ## label1; \
        .word value1; \
        .word value2
// end macro definition

CONSTANT("0", 0, zero, 0)
CONSTANT("1", 0, one, 1)
CONSTANT("2", 0, two, 2)
CONSTANT("-1", 0, negativeone, -1)
CONSTANT("true", 0, true, -1)
CONSTANT("false", 0, false, 0)
CONSTANT("bl", 0, bl, 32)
CONSTANT("'\"'", 0, chardquote, "\"")
CONSTANT("')'", 0, charcloseparen, ")")
CONSTANT(".:", 0, dotcolon, @docol)
CONSTANT(".variable", 0, dotvariable, @dovar)
CONSTANT(".constant", 0, dotconstant, @doconst)
CONSTANT(".2constant", 0, dot2constant, @do2const)
CONSTANT(".user", 0, dotuser, @douser)

////
// User variable handling

CODE("up!", 0, upstore)
        PS_POP(UP)
        jump _next

CODE("up@", 0, upfetch)
        PS_PUSH(UP)
        jump _next

// Forth-level interpreter for user variables.
.section text
.align 4
douser:
        loadw %l0, 1, %l0
        add UP, %l0, %l0
        PS_PUSH(%l0)
        jump _next

// Macro to set up the dictionary entry etc. for a variable.
#define USER(name, flags, label1, initial) \
        HEAD(name, flags, label1); \
        .word @douser; \
        .word _uoff; \
        .set index_ ## label1, _uoff >> 1; \
        .set _uoff, _uoff + 2; \
        .set _here, .; \
        .org _unext; \
        .word initial; \
        .set _unext, .; \
        .org _here

// Macros to access user variables from assembly routines
#define USER_FETCH(label1, dst) \
        loadw UP, index_ ## label1, dst
#define USER_STORE(label1, arg) \
        storew UP, index_ ## label1, arg

USER("sp0", 0, sp0, pstack)
USER("rp0", 0, rp0, rstack)
USER("base", 0, base, 10)
USER("$source-id", 0, dsourceid, 0)
USER("'?key", 0, xtqkey, qrx)
USER("'accept", 0, xtaccept, acceptln)
USER("'emit", 0, xtemit, txstore)
USER("'echo", 0, xtecho, emit)
USER("'prompt", 0, xtprompt, ok)
USER("state", 0, state, 0)
USER("#tib", 0, ntib, 0)
HEAD("span", 0, span)
        .word @douser
        .word index_ntib << 1
USER("ctib", 0, ctib, tibtop)
USER(">in", 0, toin, 0)
USER("cp", 0, cp, dict_end)
USER("latest", 0, latest, entry_boot)
USER("$recurse", 0, drecurse, 0)
USER("state", 0, state, 0)
USER("$word", 0, dword, 0)
USER("#$word", 0, ndword, 0)
USER("hld", 0, hld, 0)
USER("handler", 0, handler, 0)
USER("bt", 0, bt, 0)
USER("$abort", 0, dabort, 0)

VARIABLE(">user", 0, touser)
        .word _uoff

////
// Core parameter stack manipulation operations.

CODE("sp!", 0, spstore)
        loadw PSP, 0, PSP;
        jump _next

CODE("sp@", 0, spfetch)
        store PSP, %l0
        PS_PUSH(%l0)
        jump _next

CODE("depth", 0, depth)                 // ( -- +n )
        USER_FETCH(sp0, %l0)
        sub %l0, PSP, %l0
        art_shift %l0, -1, %l0
        PS_PUSH(%l0)
        jump _next

CODE("drop", 0, drop)                   // ( x1 -- )
        add PSP, 2, PSP
        jump _next

CODE("dup", 0, dup)                     // ( x1 -- x1 x1 )
        loadw PSP, 0, %l0
        PS_PUSH(%l0)
        jump _next

CODE("?dup", 0, qdup)                   // ( x1 flag -- x1 | )
        loadw PSP, 0, %l0
        jz %l0, 1f
        PS_PUSH(%l0)
1:      jump _next

CODE("swap", 0, swap)                   // ( x1 x2 -- x2 x1 )
        PS_POP(%l0)
        loadw PSP, 0, %l1
        storew PSP, 0, %l0
        PS_PUSH(%l1)
        jump _next

CODE("over", 0, over)                   // ( x1 x2 -- x1 x2 x1 )
        loadw PSP, 1, %l0
        PS_PUSH(%l0)
        jump _next

CODE("rot", 0, rot)                     // ( x1 x2 x3 -- x2 x3 x1 )
        PS_POP(%l2)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        storew PSP, 0, %l1
        PS_PUSH(%l2)
        PS_PUSH(%l0)
        jump _next

CODE("rot-", 0, rotminus)               // ( x1 x2 x3 -- x3 x1 x2 )
        PS_POP(%l2)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        storew PSP, 0, %l2
        PS_PUSH(%l0)
        PS_PUSH(%l1)
        jump _next

CODE("nip", 0, nip)                     // ( x1 x2 -- x2 )
        PS_POP(%l0)
        storew PSP, 0, %l0
        jump _next

CODE("tuck", 0, tuck)                   // ( x1 x2 -- x2 x1 x2 )
        loadw PSP, 0, %l1
        loadw PSP, 1, %l0
        storew PSP, 1, %l1
        storew PSP, 0, %l0
        PS_PUSH(%l1)
        jump _next

CODE("roll", 0, roll)                   // ( xu xu-1 .. x0 u -- xu-1 .. x0 xu )
CODE("cs-roll", 0, csroll)
        PS_POP(%l0)
        je %l0, 0, _next
        loadw PSP, %l0, %l3
1:      store %l0, %l1
        dec %l0
        loadw PSP, %l0, %l2
        storew PSP, %l1, %l2
        jne %l0, 0, 1b
2:      storew PSP, 0, %l3
        jump _next

CODE("pick", 0, pick)                   // ( xu .. x0 u -- xu .. x0 xu )
CODE("cs-pick", 0, cspick)
        loadw PSP, 0, %l0
        inc %l0
        loadw PSP, %l0, %l0
        storew PSP, 0, %l0
        jump _next

CODE("2drop", 0, twodrop)               // ( x1 x2 -- )
        add PSP, 4, PSP
        jump _next

CODE("2dup", 0, twodup)                 // ( x1 x2 -- x1 x2 x1 x2 )
        loadw PSP, 1, %l0
        PS_PUSH(%l0)
        loadw PSP, 1, %l0
        PS_PUSH(%l0)
        jump _next

CODE("2over", 0, twoover)               // ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )
        loadw PSP, 2, %l1
        loadw PSP, 3, %l0
        PS_PUSH(%l0)
        PS_PUSH(%l1)
        jump _next

CODE("2swap", 0, twoswap)               // ( x1 x2 x3 x4 -- x3 x4 x1 x2 )
        loadw PSP, 0, %l3
        loadw PSP, 1, %l2
        loadw PSP, 2, %l1
        loadw PSP, 3, %l0
        storew PSP, 3, %l2
        storew PSP, 2, %l3
        storew PSP, 1, %l0
        storew PSP, 0, %l1
        jump _next

CODE("2rot", 0, tworot)                 // ( xd1 xd2 xd3 -- xd2 xd3 xd1 )
        loadw PSP, 0, %l5
        loadw PSP, 1, %l4
        loadw PSP, 2, %l3
        loadw PSP, 3, %l2
        loadw PSP, 4, %l1
        loadw PSP, 5, %l0
        storew PSP, 5, %l2
        storew PSP, 4, %l3
        storew PSP, 3, %l4
        storew PSP, 2, %l5
        storew PSP, 1, %l0
        storew PSP, 0, %l1
        jump _next

////
// Basic memory manipulation operations.

CODE("!", 0, store)                     // ( x a-addr -- )
        PS_POP(%l1)
        PS_POP(%l0)
        storew %l1, 0, %l0
        jump _next

CODE("2!", 0, twostore)                 // ( x1 x2 a-addr -- )
        PS_POP(%l2)
        PS_POP(%l1)
        PS_POP(%l0)
        storew %l2, 0, %l1
        storew %l2, 1, %l0
        jump _next

CODE("@", 0, fetch)
        loadw PSP, 0, %l0
        loadw %l0, 0, %l0
        storew PSP, 0, %l0
        jump _next

CODE("2@", 0, twofetch)
        loadw PSP, 0, %l0
        loadw %l0, 0, %l1
        loadw %l0, 1, %l0
        storew PSP, 0, %l0
        PS_PUSH(%l1)
        jump _next

CODE("c!", 0, cstore)                   // ( char c-addr -- )
        PS_POP(%l0)
        PS_POP(%l1)
        storeb %l0, 0, %l1
        jump _next

CODE("c@", 0, cfetch)
        loadw PSP, 0, %l0
        loadb %l0, 0, %l0
        storew PSP, 0, %l0
        jump _next

CODE("cmove", 0, cmove)                 // ( c-addr1 c-addr2 u -- )
        PS_POP(%l2)
        PS_POP(%l1)
        PS_POP(%l0)
_cmove: store 0, %l3
        je %l3, %l2, _next
1:      loadb %l0, %l3, %l4
        storeb %l1, %l3, %l4
        inc %l3
        jne %l3, %l2, 1b
        jump _next

CODE("cmove>", 0, cmovehigh)            // ( c-addr1 c-addr2 u -- )
        PS_POP(%l2)
        PS_POP(%l1)
        PS_POP(%l0)
_cmovehigh:
        jz %l2, _next
1:      dec %l2
        loadb %l0, %l2, %l3
        storeb %l1, %l2, %l3
        jnz %l2, 1b
        jump _next

CODE("move", 0, move)                   // ( addr1 addr2 u -- )
        PS_POP(%l2)
        PS_POP(%l1)
        PS_POP(%l0)
_move:  jz %l1, 1f
        jl %l2, 0, 1f
        copy_table %l0, %l1, %l2
        jump _next
1:      sub %l0, 32768, %l3
        sub %l1, 32768, %l4
        jl %l3, %l4, _cmovehigh
        jump _cmove

CODE("+!", 0, plusstore)                // ( n|u addr -- )
        PS_POP(%l1)
        PS_POP(%l0)
        loadw %l1, 0, %l2
        add %l0, %l2, %l0
        storew %l1, 0, %l0
        jump _next

////
// Bitwise operations.

CODE("invert", 0, invert)
        loadw PSP, 0, %l0
        not %l0, %l0
        storew PSP, 0, %l0
        jump _next

CODE("and", 0, and)
        PS_POP(%l0)
        loadw PSP, 0, %l1
        and %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("or", 0, or)
        PS_POP(%l0)
        loadw PSP, 0, %l1
        or %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

// Bitwise exclusive or.  For some reason, the Z-machine does not have a native
// operation for xor, so we need to synthesize it.
CODE("xor", 0, xor)
        PS_POP(%l0)
        not %l0, %l1
        loadw PSP, 0, %l2
        not %l2, %l3
        and %l0, %l3, %l0
        and %l2, %l1, %l2
        or %l0, %l2, %l0
        storew PSP, 0, %l0
        jump _next

CODE("lshift", 0, lshift)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        log_shift %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("rshift", 0, rshift)
        PS_POP(%l1)
        sub 0, %l1, %l1
        loadw PSP, 0, %l0
        log_shift %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

////
// Logical comparisons.

CODE("0=", 0, zeroeq)
CODE("not", 0, not)
        loadw PSP, 0, %l0
        jz %l0, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("=", 0, eq)
        PS_POP(%l0)
        loadw PSP, 0, %l1
        je %l0, %l1, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("0<>", 0, zeroneq)
        loadw PSP, 0, %l0
        jnz %l0, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("<>", 0, neq)
        PS_POP(%l0)
        loadw PSP, 0, %l1
        jne %l0, %l1, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("0<", 0, zerolt)
        loadw PSP, 0, %l0
        jl %l0, 0, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("<", 0, lt)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        jl %l0, %l1, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("u<", 0, ult)
        PS_POP(%l1)
        loadw PSP, 0, %l0
_ult:   sub %l0, 32768, %l2
        sub %l1, 32768, %l3
        jl %l2, %l3, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("0>", 0, zerogt)
        loadw PSP, 0, %l0
        jg %l0, 0, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE(">", 0, gt)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        jg %l0, %l1, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("u>", 0, ugt)
        PS_POP(%l1)
        loadw PSP, 0, %l0
_ugt:   sub %l0, 32768, %l2
        sub %l1, 32768, %l3
        jg %l2, %l3, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("0<=", 0, zerolteq)
        loadw PSP, 0, %l0
        jle %l0, 0, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("<=", 0, lteq)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        jle %l0, %l1, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("0>=", 0, zerogteq)
        loadw PSP, 0, %l0
        jge %l0, 0, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE(">=", 0, gteq)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        jge %l0, %l1, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("min", 0, min)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        jge %l1, %l0, _next
        storew PSP, 0, %l1
        jump _next

CODE("max", 0, max)
        PS_POP(%l0)
        loadw PSP, 0, %l1
        jle %l0, %l1, _next
        storew PSP, 0, %l0
        jump _next

// Check if first arg is between the other two.
CODE("within", 0, within)       // ( n1|u1 n2|u2 n3|u3 -- flag)
        PS_POP(%l2)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        sub %l0, %l1, %l0
        sub %l2, %l1, %l1
        jump _ult

////
// Arithmetic

CODE("+", 0, plus)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        add %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("1+", 0, oneplus)
CODE("char+", 0, charplus)
        loadw PSP, 0, %l0
        add %l0, 1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("-", 0, minus)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        sub %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("1-", 0, oneminus)
        loadw PSP, 0, %l0
        sub %l0, 1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("*", 0, mul)
        PS_POP(%l0)
        loadw PSP, 0, %l1
        mul %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("/", 0, slash)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        div %l0, %l1, %l2
        storew PSP, 0, %l2
        jump _next

CODE("mod", 0, mod)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        mod %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("/mod", 0, slashmod)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        div %l0, %l1, %l2
        mod %l0, %l1, %l0
        storew PSP, 0, %l0
        PS_PUSH(%l2)
        jump _next

CODE("negate", 0, negate)
        loadw PSP, 0, %l0
        sub 0, %l0, %l0
        storew PSP, 0, %l0
        jump _next

CODE("abs", 0, abs)
        loadw PSP, 0, %l0
        jge %l0, 0, 1f
        sub 0, %l0, %l0
        storew PSP, 0, %l0
1:      jump _next

CODE("2*", 0, twomul)
        loadw PSP, 0, %l0
        art_shift %l0, 1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("2/", 0, twoslash)
        loadw PSP, 0, %l0
        art_shift %l0, -1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("4*", 0, fourmul)
        loadw PSP, 0, %l0
        art_shift %l0, 2, %l0
        storew PSP, 0, %l0
        jump _next

CODE("4/", 0, fourslash)
        loadw PSP, 0, %l0
        art_shift %l0, -2, %l0
        storew PSP, 0, %l0
        jump _next

////
// Double-length integer arithmetic (and helpers)

CODE("d>s", 0, dtos)                    // ( d -- n )
        add PSP, 2, PSP
        jump _next

CODE("s>d", 0, stod)                    // ( n -- d )
        loadw PSP, 0, %l0
        log_shift %l0, -15, %l0
        je %l0, 1, 1f
        PS_PUSH(0)
        jump _next
1:      PS_PUSH(-1)
        jump _next

CODE("um/mod+", 0, umslashmodplus)      // ( ud1 u1 -- u2 ud2 )
        loadw PSP, 0, %l3
        loadw PSP, 1, %l1
        loadw PSP, 2, %l0
        store 0, %l2
        store 31, %l4
        jnz %l1, 1f
        store %l0, %l1
        store 0, %l0
        store 15, %l4
1:      log_shift %l2, -15, %l7
        log_shift %l2, 1, %l2
        log_shift %l1, -15, %l5
        or %l2, %l5, %l2
        log_shift %l1, 1, %l1
        log_shift %l0, -15, %l5
        or %l1, %l5, %l1
        log_shift %l0, 1, %l0
        jnz %l7, 2f
        sub %l2, 32768, %l5
        sub %l3, 32768, %l6
        jl %l5, %l6, 3f
2:      sub %l2, %l3, %l2
        inc %l0                         // Safe as low bit is clear
3:      decjge %l4, 0, 1b
        storew PSP, 0, %l1
        storew PSP, 1, %l0
        storew PSP, 2, %l2
        jump _next

// ANS Forth UM/MOD returns a single-width quotient for some reason
COLON("um/mod", 0, umslashmod)          // ( ud u1 -- u2 u3 )
        .word umslashmodplus
        .word dtos
        .word exit

CODE("d+", 0, dplus)                    // ( d1 d2 -- d3 )
        PS_POP(%l3)
        PS_POP(%l2)
        loadw PSP, 0, %l1
        loadw PSP, 1, %l0
        calln r_dplus, %l0, %l1, %l2, %l3
        storew PSP, 1, %g0
        storew PSP, 0, %g1
        jump _next

.routine r_dplus, 6
        add %l0, %l2, %g0
        add %l1, %l3, %g1
        sub -1, %l2, %l2
        sub %l0, 32768, %l4
        sub %l2, 32768, %l5
        jle %l4, %l5, 1f
        inc %g1
1:      rtrue

CODE("um*+", 0, umstarplus)             // ( ud1 u -- ud2 )
        PS_POP(%l2)
        loadw PSP, 0, %l1
        loadw PSP, 1, %l0
        calln r_umstarplus, %l0, %l1, %l2
        storew PSP, 1, %g0
        storew PSP, 0, %g1
        jump _next

.routine r_umstarplus, 8
        store 0, %g1
        store 0, %g0
        store 31, %l4
        jnz %l1, 1f
        store %l0, %l1
        store 0, %l0
        store 15, %l4
1:      log_shift %g0, -15, %l6
        log_shift %g0, 1, %g0
        log_shift %g1, 1, %g1
        or %g1, %l6, %g1
        log_shift %l0, -15, %l6
        log_shift %l0, 1, %l0
        log_shift %l1, -15, %l7
        log_shift %l1, 1, %l1
        or %l1, %l6, %l1
        jz %l7, 2f
        calln r_dplus, %l2, 0, %g0, %g1
2:      decjge %l4, 0, 1b
        rtrue

COLON("um*", 0, umstar)                 // ( u1 u2 -- ud )
        .word zero, swap, umstarplus
        .word exit

CODE("dnegate", 0, dnegate)             // ( d1 -- d2 )
        loadw PSP, 0, %l1
        loadw PSP, 1, %l0
_dneg:  not %l1, %l1
        not %l0, %l0
        inc %l0
        jnz %l0, 1f
        inc %l1
1:      storew PSP, 1, %l0
        storew PSP, 0, %l1
        jump _next

CODE("dabs", 0, dabs)                   // ( d1 -- d2 )
        loadw PSP, 0, %l1
        loadw PSP, 1, %l0
        log_shift %l1, -15, %l2
        je %l2, 1, _dneg
        jump _next

CODE("d0=", 0, dzeroeq)                 // ( d -- f )
        PS_POP(%l1)
        loadw PSP, 0, %l0
        jnz %l1, 1f
        jnz %l0, 1f
        storew PSP, 0, -1
        jump _next
1:      storew PSP, 0, 0
        jump _next

CODE("d0<", 0, dzerolt)                 // ( d -- f )
        PS_POP(%l1)
        art_shift %l1, -15, %l1
        storew PSP, 0, %l1
        jump _next

CODE("d=", 0, deq)                      // ( xd1 xd2 -- f )
        PS_POP(%l3)
        PS_POP(%l2)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        jne %l0, %l2, 1f
        jne %l1, %l3, 1f
        storew PSP, 0, -1
        jump _next
1:      storew PSP, 0, 0
        jump _next

CODE("d2*", 0, dtwostar)                // ( xd1 -- xd2 )
        loadw PSP, 0, %l1
        loadw PSP, 1, %l0
        log_shift %l1, 1, %l1
        log_shift %l0, -15, %l2
        or %l2, %l1, %l1
        log_shift %l0, 1, %l0
        storew PSP, 1, %l0
        storew PSP, 0, %l1
        jump _next

CODE("d2/", 0, dtwoslash)               // ( xd1 -- xd1 )
        loadw PSP, 0, %l1
        loadw PSP, 1, %l0
        log_shift %l1, 15, %l2
        art_shift %l1, -1, %l1
        log_shift %l0, -1, %l0
        or %l2, %l0, %l0
        storew PSP, 1, %l0
        storew PSP, 0, %l1
        jump _next

CODE("d<", 0, dlt)                      // ( d1 d2 -- f )
        PS_POP(%l3)
        PS_POP(%l1)
        PS_POP(%l2)
        loadw PSP, 0, %l0
        je %l2, %l3, _ult
        jl %l2, %l3, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("d>", 0, dgt)                      // ( d1 d2 -- f )
        PS_POP(%l3)
        PS_POP(%l1)
        PS_POP(%l2)
        loadw PSP, 0, %l0
        je %l2, %l3, _ugt
        jg %l2, %l3, 1f
        storew PSP, 0, 0
        jump _next
1:      storew PSP, 0, -1
        jump _next

CODE("du<", 0, dult)                    // ( ud1 ud2 -- f )
        PS_POP(%l1)
        PS_POP(%l3)
        PS_POP(%l0)
        loadw PSP, 0, %l2
        jne %l0, %l1, _ult
        store %l2, %l0
        store %l3, %l1
        jump _ult

CODE("du>", 0, dugt)                    // ( ud1 ud2 -- f )
        PS_POP(%l1)
        PS_POP(%l3)
        PS_POP(%l0)
        loadw PSP, 0, %l2
        jne %l0, %l1, _ugt
        store %l2, %l0
        store %l3, %l1
        jump _ugt

////
// Address arithmetic and alignment

CODE("cell+", 0, cellplus)
        loadw PSP, 0, %l0
        add %l0, 2, %l0
        storew PSP, 0, %l0
        jump _next

CODE("cell-", 0, cellminus)
        loadw PSP, 0, %l0
        sub %l0, 2, %l0
        storew PSP, 0, %l0
        jump _next

CODE("chars", 0, chars)
CODE("nop", 0, nop)
        jump _next

CODE("cells", 0, cells)
        loadw PSP, 0, %l0
        art_shift %l0, 1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("aligned", 0, aligned)
        loadw PSP, 0, %l0
        and %l0, 1, %l1
        add %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

CODE("unaligned", 0, unaligned)
        loadw PSP, 0, %l0
        or %l0, 1, %l0
        storew PSP, 0, %l0
        jump _next

////
// Z-machine interface words

// Save the entire machine state
CODE("@save", 0, atsave)                        // ( -- n )
        save %l0
        PS_PUSH(%l0)
        jump _next

// Save part of memory
CODE("@save-table", 0, atsavetable)             // ( addr u c-addr -- n )
        PS_POP(%l2)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        save %l0, %l1, %l2, %l0
        storew PSP, 0, %l0
        jump _next

// Restore the entire machine state
CODE("@restore", 0, atrestore)                  // ( -- n )
        restore %l0
        PS_PUSH(%l0)
        jump _next

// Restore part of memory
CODE("@restore-table", 0, atrestoretable)       // ( addr u c-addr -- n )
        PS_POP(%l2)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        restore %l0, %l1, %l2, %l0
        storew PSP, 0, %l0
        jump _next

CODE("@split-window", 0, atsplitwindow)         // ( u -- )
        PS_POP(%l0)
        split_window %l0
        jump _next

CODE("@set-window", 0, atsetwindow)             // ( u -- )
        PS_POP(%l0)
        set_window %l0
        store %l0, WINDOW
        jump _next

CODE("@set-text-style", 0, atsettextstyle)      // ( u -- )
        PS_POP(%l0)
        set_text_style %l0
        jump _next

CODE("@set-font", 0, atsetfont)                 // ( u -- u )
        loadw PSP, 0, %l0
        set_font %l0, %l0
        storew PSP, 0, %l0
        jump _next

CODE("@set-cursor", 0, atsetcursor)             // ( u u -- )
        PS_POP(%l1)
        PS_POP(%l0)
        set_cursor %l0, %l1
        jump _next

CODE("at-xy", 0, atatxf)                        // ( u u -- )
        PS_POP(%l1)
        PS_POP(%l0)
        inc %l1
        inc %l0
        jnz WINDOW, 1f
        split_window 26
        set_window 1
        store 1, WINDOW
1:      set_cursor %l1, %l0
        jump _next

CODE("@set-colour", 0, atsetcolour)             // ( u u -- )
CODE("@set-color", 0, atsetcolor)
        PS_POP(%l1)
        PS_POP(%l0)
        set_colour %l0, %l1
        jump _next

CODE("@random", 0, atrandom)                    // ( n -- n )
        loadw PSP, 0, %l0
        random %l0, %l0
        storew PSP, 0, %l0
        jump _next

CODE("@get-cursor", 0, atgetcursor)             // ( -- u u )
        sub PSP, 4, PSP
        get_cursor PSP
        jump _next

CODE("@erase-window", 0, aterasewindow)         // ( u -- )
        PS_POP(%l0)
        erase_window %l0
        jump _next

CODE("page", 0, page)                           // ( -- )
        erase_window -2
        jump _next

CODE("@erase-line", 0, ateraseline)             // ( -- )
        erase_line 1
        jump _next

CODE("@buffer-mode", 0, atbuffermode)           // ( f -- )
        PS_POP(%l0)
        buffer_mode %l0
        jump _next

CODE("@input-stream", 0, atinputstream)         // ( n -- )
        PS_POP(%l0)
        input_stream %l0
        jump _next

CODE("@output-stream", 0, atoutputstream)       // ( n -- )
        PS_POP(%l0)
        output_stream %l0
        jump _next

// Exit the Forth environment and bring down the Z-machine. Bye!
CODE("@quit", 0, atquit)                        // ( -- )
CODE("bye", 0, bye)
        quit

//////
// On to the upper levels.  Now that we have most of the lowest-level words
// coded directly in assembly, we can start writing more definitions as
// hand-compiled Forth.

////
// Exceptions

COLON("catch", 0, catch)
        .word spfetch, tor, handler, fetch, tor
        .word rpfetch, handler, store
        .word execute
        .word fromr, handler, store, fromr, drop
        .word zero
        .word exit

COLON("throw", 0, throw)
        .word qdup, qbranch, 1f
        .word fromr, bt, store
        .word handler, fetch, rpstore
        .word fromr, handler, store
        .word fromr, swap, tor, spstore, drop, fromr
1:      .word exit

////
// Interpreter memory manipulation

CODE("here", 0, here)                   // ( -- a )
        USER_FETCH(cp, %l0)
        PS_PUSH(%l0)
        jump _next

CODE("allot", 0, allot)                 // ( u -- )
        USER_FETCH(cp, %l0)
        PS_POP(%l1)
        add %l0, %l1, %l0
        USER_STORE(cp, %l0)
        jump _next

CODE("align", 0, align)                 // ( -- )
        USER_FETCH(cp, %l0)
        and %l0, 1, %l1
        add %l0, %l1, %l0
        USER_STORE(cp, %l0)
        jump _next

CODE("release", 0, release)             // ( u -- )
        USER_FETCH(cp, %l0)
        PS_POP(%l1)
        sub %l0, %l1, %l0
        USER_STORE(cp, %l0)
        jump _next

CODE("unused", 0, unused)               // ( -- u )
        USER_FETCH(cp, %l0)
        sub _start, %l0, %l0
        PS_PUSH(%l0)
        jump _next

CODE("count", 0, count)                 // ( c-addr1 -- c-addr2 n )
        loadw PSP, 0, %l0
        loadb %l0, 0, %l1
        add %l0, 1, %l0
        storew PSP, 0, %l0
        PS_PUSH(%l1)
        jump _next

COLON("uncount", 0, uncount)            // ( c-addr n -- )
        .word here, over, oneplus, aligned, allot
        .word twodup, cstore, oneplus, swap, move
        .word exit

CODE(",", 0, comma)                     // ( x -- )
        PS_POP(%l0)
        USER_FETCH(cp, %l1)
        storew %l1, 0, %l0
        add %l1, 2, %l1
        USER_STORE(cp, %l1)
        jump _next

CODE("c,", 0, ccomma)                   // ( char -- )
        PS_POP(%l0)
        USER_FETCH(cp, %l1)
        storeb %l1, 0, %l0
        add %l1, 1, %l1
        USER_STORE(cp, %l1)
        jump _next

CODE("2,", 0, twocomma)                 // ( x1 x2 -- )
        PS_POP(%l1)
        PS_POP(%l0)
        USER_FETCH(cp, %l2)
        storew %l2, 0, %l1
        storew %l2, 1, %l0
        add %l2, 4, %l2
        USER_STORE(cp, %l2)
        jump _next

CODE("pad", 0, pad)                     // ( -- c-addr )
        USER_FETCH(cp, %l0)
        add %l0, 128, %l0
        PS_PUSH(%l0)
        jump _next

CODE("fill", 0, fill)                   // ( c-addr u char -- )
        PS_POP(%l2)
        PS_POP(%l1)
        PS_POP(%l0)
        jz %l1, _next
1:      dec %l1
        storeb %l0, %l1, %l2
        jnz %l1, 1b
        jump _next

CODE("-trailing", 0, minustrailing)     // ( b u -- b u )
        loadw PSP, 0, %l1
        loadw PSP, 1, %l0
        jz %l1, _next
        dec %l0
1:      loadb %l0, %l1, %l2
        jg %l2, 32, 2f
        decjge %l1, 1, 1b
2:      storew PSP, 0, %l1
        jump _next

CODE("pack$", 0, packdollar)            // ( b u a -- a )
        PS_POP(%l2)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        and %l2, 1, %l3
        add %l2, %l3, %l2
        storew PSP, 0, %l2
1:      jle %l1, 0, _next
        loadb %l0, %l1, %l3
        storeb %l2, %l1, %l3
        dec %l1
        jump 1b

CODE(">char", 0, tochar)                // ( c -- c )
        loadw PSP, 0, %l0
        and %l0, 0x7f, %l0
        jl %l0, 32, 1f
        jge %l0, 127, 1f
        jump _next
1:      storew PSP, 0, 95
        jump _next

CODE("compare", 0, compare)             // ( c-addr1 u1 c-addr2 u2 -- n )
        PS_POP(%l3)
        PS_POP(%l1)
        PS_POP(%l2)
        loadw PSP, 0, %l0
        calls r_compare, %l0, %l1, %l2, %l3, %l4
        storew PSP, 0, %l4
        jump _next

.routine r_compare, 8
        store 0, %l4
        store %l2, %l5
        jle %l2, %l3, 1f
        store %l3, %l5
1:      jge %l4, %l5, 2f
        loadb %l0, %l4, %l6
        loadb %l1, %l4, %l7
        inc %l4
        je %l6, %l7, 1b
        jl %l6, %l7, 3f
        jump 4f
2:      je %l2, %l3, 5f
        jg %l2, %l3, 4f
3:      ret -1
4:      ret 1
5:      ret 0

CODE("search", 0, search)               // ( addr1 u1 addr2 u2 -- addr3 u3 f )
        PS_POP(%l3)
        loadw PSP, 0, %l2
        loadw PSP, 1, %l1
        loadw PSP, 2, %l0
        jg %l3, %l1, 2f
1:      calls r_compare, %l0, %l2, %l3, %l3, %l5
        jz %l5, 3f
        inc %l0
        decjge %l1, %l3, 1b
2:      storew PSP, 0, 0
        jump _next
3:      storew PSP, 2, %l0
        storew PSP, 1, %l1
        storew PSP, 0, -1
        jump _next

CODE("compare-word", 0, compareword)    // ( c-addr1 u1 c-addr2 u2 -- f )
        PS_POP(%l3)
        PS_POP(%l2)
        PS_POP(%l1)
        loadw PSP, 0, %l0
        jne %l1, %l3, 5f
        jz %l1, 4f
        store 0, %l3
1:      loadb %l0, %l3, %l4
        jl %l4, "A", 2f
        jg %l4, "Z", 2f
        add %l4, 32, %l4
2:      loadb %l2, %l3, %l5
        jl %l5, "A", 3f
        jg %l5, "Z", 3f
        add %l5, 32, %l5
3:      jne %l4, %l5, 5f
        inc %l3
        jne %l1, %l3, 1b
4:      storew PSP, 0, -1
        jump _next
5:      storew PSP, 0, 0
        jump _next

CODE(">number", 0, tonumber)            // ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )
        loadw PSP, 0, %l1
        loadw PSP, 1, %l0
        loadw PSP, 2, %g1
        loadw PSP, 3, %g0
        USER_FETCH(base, %l2)
        jz %l1, 5f
1:      loadb %l0, 0, %l3
        jge %l3, "a", 3f
        jge %l3, "A", 2f
        sub %l3, "0", %l3
        jump 4f
2:      sub %l3, 55, %l3                // "A" - 10
        jump 4f
3:      sub %l3, 87, %l3                // "a" - 10
4:      jl %l3, 0, 5f
        jge %l3, %l2, 5f
        calln r_umstarplus, %g0, %g1, %l2
        calln r_dplus, %g0, %g1, %l3, 0
        inc %l0
        dec %l1
        jnz %l1, 1b
5:      storew PSP, 3, %g0
        storew PSP, 2, %g1
        storew PSP, 1, %l0
        storew PSP, 0, %l1
        jump _next

COLON("convert", 0, convert)           // ( ud1 c-addr1 -- ud2 c-addr2 )
        .word charplus, dolit, -1, tonumber, drop
        .word exit

VARIABLE("punct", 0, punct)
        .word 0

COLON("number", 0, number)              // ( c-addr -- n | u | d | ud )
        .word zero, punct, store
        .word dup, oneplus, cfetch
        .word dolit, "-"
        .word eq, dup, tor, minus
        .word zero, zero, rot
1:      .word convert
        .word dup, cfetch
        .word bl, minus
        .word qbranch, 2f
        .word dup, cfetch
        .word dup, dolit, ":", eq, swap
        .word dolit, 44, dolit, 48, within
        .word plus, dup, punct, store, not
        .word qbranch, 1b
        .word dolit, -13, throw
2:      .word drop, fromr
        .word qbranch, 3f
        .word dnegate
3:      .word punct, fetch
        .word qbranch, 4f
        .word true
        .word branch, 5f
4:      .word drop, false
5:      .word exit

////
// Time for some input-output!

.routine r_timeout, 0
        inc TIMEOUTS
        rtrue

// Pull in exactly one character.
CODE("?rx", 0, qrx)
        store 0, TIMEOUTS
        read_char 1, 0x7fff, @r_timeout, %l0
        PS_PUSH(%l0)
        jnz TIMEOUTS, 1f
        PS_PUSH(-1)
        jump _next
1:      PS_PUSH(0)
        jump _next

// Emit exactly one character.
CODE("tx!", 0, txstore)                 // ( char -- )
        PS_POP(%l0)
        print_char %l0
        jump _next

CODE("emit", 0, emit)                   // ( char -- )
        USER_FETCH(xtemit, %l0)
        jump _exec

COLON("space", 0, space)                // ( -- )
        .word bl, emit
        .word exit

CODE("cr", 0, cr)                       // ( -- )
        new_line
        jump _next

CODE(".", 0, dot)                       // ( n -- )
        PS_POP(%l0)
        print_num %l0
        print_char " "
        jump _next

COLON(".s", 0, dots)                    // ( -- )
        .word dolit, "<", emit
        .word dolit, " ", emit
        .word depth, dup, dot
        .word dolit, ">", emit
        .word dolit, " ", emit
1:      .word qdup
        .word qbranch, 2f
        .word dup, pick, dot
        .word oneminus
        .word branch, 1b
2:      .word exit

COLON("type", 0, type)                  // ( addr u -- )
1:      .word dup, qbranch, 2f
        .word oneminus, swap, dup, cfetch, emit
        .word oneplus, swap
        .word branch, 1b
2:      .word twodrop
        .word exit

CODE("?key", 0, qkey)                   // ( -- char f )
        USER_FETCH(xtqkey, %l0)
        jump _exec

// Sleep in milliseconds.  Fake it
CODE("ms", 0, ms)                       // ( u -- )
        PS_POP(%l0)
        div %l0, 100, %l0
        jnz %l0, 1f
        inc %l0
1:      store 0, %l1
2:      store 0, TIMEOUTS
        read_char 1, 1, @r_timeout, %l2
        jnz TIMEOUTS, 3f
        storeb _kbuf, KIN, %l2
        inc KIN
        mod KIN, KBUFSZ, KIN
3:      inc %l1
        jne %l1, %l0, 2b
        jump _next

CODE("key?", 0, keyq)                   // ( -- f )
        jne KIN, KOUT, 1f
        store 0, TIMEOUTS
        read_char 1, 1, @r_timeout, %l2
        jnz TIMEOUTS, 2f
        storeb _kbuf, KIN, %l2
        inc KIN
        mod KIN, KBUFSZ, KIN
1:      PS_PUSH(-1)
        jump _next
2:      PS_PUSH(0)
        jump _next

CODE("key", 0, key)                     // ( -- char )
        jne KIN, KOUT, 1f
        read_char 1, %l2
        PS_PUSH(%l2)
        jump _next
1:      loadb _kbuf, KOUT, %l2
        inc KOUT
        mod KOUT, KBUFSZ, KOUT
        PS_PUSH(%l2)
        jump _next

COLON("accept1c", 0, accept1c)          // ( c-addr u1 -- u2 )
        .word dup, rot
1:      .word over, zero, gt
        .word qkey, invert, dolit, -39, and, throw
        .word dup, dolit, 10, neq
        .word over, dolit, 13, neq
        .word and, rot, and
        .word qbranch, 2f
        .word dup, echo, over, cstore, oneplus
        .word swap, oneminus, swap
        .word branch, 1b
2:      .word drop, drop, minus
        .word bl, echo
        .word exit

CODE("acceptln", 0, acceptln)           // ( c-addr u1 -- u2 )
        PS_POP(%l2)
        PS_POP(%l1)
        sub %l2, 1, %l2
        storeb _abuf, 0, %l2
        storeb _abuf, 1, 0
        read _abuf, 0, %l2
        loadb _abuf, 1, %l2
        PS_PUSH(%l2)
        add _abuf, 2, %l0
        jump _move

CODE("accept", 0, accept)              // ( c-addr u1 -- u2 )
        USER_FETCH(xtaccept, %l0)
        jump _exec

CODE("echo", 0, echo)                   // ( char -- )
        USER_FETCH(xtecho, %l0)
        jump _exec

CODE("tib", 0, tib)
        USER_FETCH(ctib, %l0)
        PS_PUSH(%l0)
        jump _next

CODE("source", 0, source)
        USER_FETCH(ctib, %l0)
        PS_PUSH(%l0)
        USER_FETCH(ntib, %l0)
        PS_PUSH(%l0)
        jump _next

COLON("refill", 0, refill)              // ( -- flag )
        .word tib, dolit, 128
        .word dolit, accept, catch
        .word qbranch, 1f
        .word zero, ntib, store, zero, toin, store
        .word drop, drop, zero
        .word exit
1:      .word ntib, store, zero, toin, store
        .word negativeone
        .word exit

CODE("source-id", 0, sourceid)
        USER_FETCH(dsourceid, %l0)
        PS_PUSH(%l0)
        jump _next

COLON("console", 0, console)
        .word dolit, qrx, xtqkey, store
        .word dolit, acceptln, xtaccept, store
        .word dolit, emit, xtecho, store
        .word dolit, ok, xtprompt, store
        .word zero, dsourceid, store
        .word zero, atinputstream
        .word exit

COLON("query", 0, query)
        .word console, refill, drop
        .word exit

COLON("load", 0, load)
        .word dolit, qrx, xtqkey, store
        .word dolit, accept1c, xtaccept, store
        .word dolit, drop, xtecho, store
        .word dolit, nop, xtprompt, store
        .word one, dsourceid, store
        .word one, atinputstream
        .word exit

COLON("record", 0, record)
        .word dolit, 4, atoutputstream
        .word exit

////
// Parsing

CODE("parse", 0, parse)                 // ( char "ccc<char>" -- c-addr u )
        loadw PSP, 0, %l0
        USER_FETCH(ctib, %l1)
        USER_FETCH(toin, %l2)
        USER_FETCH(ntib, %l3)
        store %l2, %l4
_parse: add %l1, %l2, %l5
        storew PSP, 0, %l5
        jge %l4, %l3, 3f
        loadb %l1, %l4, %l5
        inc %l4
        je %l0, %l5, 2f
        jne %l0, 32, _parse
        jg %l5, 32, _parse
2:      inc %l2
3:      sub %l4, %l2, %l2
        PS_PUSH(%l2)
        USER_STORE(toin, %l4)
        jump _next

CODE("(parse-word)", 0, doparseword)    // ( c "<c*>aaa<c>" -- c-addr u )
        loadw PSP, 0, %l0
        USER_FETCH(ctib, %l1)
        USER_FETCH(toin, %l2)
        USER_FETCH(ntib, %l3)
        store %l2, %l4
        jge %l4, %l3, 3f
1:      loadb %l1, %l4, %l5
        je %l0, %l5, 2f
        jne %l0, 32, 3f
        jg %l5, 32, 3f
2:      inc %l4
        jl %l4, %l3, 1b
3:      store %l4, %l2
        jump _parse

COLON("parse-word", 0, parseword)       // ( c "<c*>aaa<c>" -- c-addr u )
        .word doparseword
        .word dolit, 31
        .word min
        .word exit

////
// Dictionary lookup and the colon compiler

COLON("word", 0, word)                  // ( c "<c*>ccc<c>" -- c-addr )
        .word parseword, here
        .word twodup, plus, oneplus, bl, swap, cstore
        .word twodup, cstore
        .word oneplus, swap, cmove
        .word here
        .word exit

COLON("find-header", 0, findheader)     // ( c-addr -- addr 0 | 1 | -1 )
        .word latest
1:      .word fetch, dup
        .word qbranch, 4f
        .word tor, rfetch, over, count
        .word fromr, cellplus, count
        .word dolit, (LENMASK | HIDDEN), and
        .word compareword
        .word qbranch, 1b
        .word swap, drop, dup, cellplus, cfetch
        .word dolit, IMMEDIATE, and
        .word qbranch, 3f
        .word one
        .word exit
3:      .word dolit, -1
4:      .word exit

CODE(">cfa", 0, tocfa)                  // ( addr -- addr )
        loadw PSP, 0, %l0
        loadb %l0, 2, %l1
        and %l1, LENMASK, %l1
        add %l0, 3, %l0
        add %l0, %l1, %l0
        and %l0, 1, %l1
        add %l0, %l1, %l0
        storew PSP, 0, %l0
        jump _next

COLON(">dfa", 0, todfa)                 // ( addr -- addr )
        .word tocfa, cellplus
        .word exit

COLON("find", 0, find)                  // ( c-addr -- c-addr 0 | xt flag )
        .word findheader, dup, qbranch, 1f
        .word swap, tocfa, swap
1:      .word exit

COLON("--'", 0, notnottick)             // ( "<spaces>ccc" -- xt flag )
        .word bl, word, find
        .word exit

COLON("?abort-find", 0, qabortfind)     // ( c-addr f -- c-addr f )
        .word qdup, zeroeq
        .word qbranch, 1f
        .word count, ndword, store, dword, store
        .word dolit, -13, throw
1:      .word exit

CODE(">body", 0, tobody)                // ( addr -- addr )
        loadw PSP, 0, %l0
        add %l0, 4, %l0
        storew PSP, 0, %l0
        jump _next

COLON("hidden", 0, hidden)
        .word latest, fetch, cellplus, dup, cfetch
        .word dolit, HIDDEN
        .word or, swap, cstore
        .word exit

COLON("visible", 0, visible)
        .word latest, fetch, cellplus, dup, cfetch
        .word dolit, ~HIDDEN
        .word and, swap, cstore
        .word exit

COLON("immediate", 0, immediate)
        .word latest, fetch, cellplus, dup, cfetch
        .word dolit, IMMEDIATE
        .word or, swap, cstore
        .word exit

COLON("(create)", 0, docreate)
        .word fromr
        .word exit

COLON("create>", 0, createto)
        .word align, here, latest, dup, fetch, comma, store
        .word bl, parseword, uncount
        .word exit

COLON("[", IMMEDIATE, lbracket)
        .word false, state, store
        .word exit

COLON("]", 0, rbracket)
        .word true, state, store
        .word exit

COLON(":", 0, colon)
        .word createto, hidden
        .word here, drecurse, store
        .word dotcolon, comma
        .word rbracket
        .word exit

COLON(";", IMMEDIATE, semicolon)
        .word compile, exit
        .word visible
        .word lbracket
        .word exit

COLON("abort", 0, abort)
        .word negativeone, throw

COLON("(abort\")", 0, doabortquote)
        .word swap
        .word qbranch, 1f
        .word dabort, store
        .word dolit, -2, throw
1:      .word drop
        .word exit

COLON("compile", 0, compile)
        .word fromr, dup, fetch, comma, cellplus, tor
        .word exit

////
// Comments -- don't leave home without

COLON("\\", IMMEDIATE, backslash)
        .word ntib, fetch, toin, store
        .word exit

COLON("(", IMMEDIATE, openparen)
        .word charcloseparen, parse, twodrop
        .word exit

////
// The interpreter / compiler

// The line interpreter proper
COLON("interpret", 0, interpret)
1:      .word tib, toin, fetch, plus, dword, store
        .word bl, word, dup, cfetch
        .word dup, ndword, store
        .word qbranch, 9f
        .word find, qdup
        .word qbranch, 4f
        .word oneminus, state, fetch, and
        .word qbranch, 2f
        .word comma
        .word branch, 3f
2:      .word execute
3:      .word branch, 7f
4:      .word number
        .word state, fetch
        .word qbranch, 6f
        .word qbranch, 5f
        .word swap, compile, dolit, comma
5:      .word compile, dolit, comma
        .word branch, 7f
6:      .word drop
7:      .word depth
        .word zero, lt
        .word qbranch, 8f
        .word dolit, -4, throw
8:      .word branch, 1b
9:      .word drop
        .word exit

CODE("prompt", 0, prompt)
        USER_FETCH(xtprompt, %l0)
        jump _exec

COLON("ok", 0, ok)                               // ( -- )
        .word state, fetch, zeroeq, qbranch, 1f
        .word dosliteral
        .byte 2, "ok"
        .word type
1:      .word cr
        .word exit

// The main system loop
COLON("quit", 0, quit)
1:      .word rp0, fetch, rpstore
        .word console, lbracket
2:      .word zero, sp0, fetch, store
        .word refill, qbranch, 9f
        .word dolit, interpret, catch
        .word zero, over, eq, qbranch, 3f
        .word drop, prompt
        .word branch, 2b
3:      .word tor, sp0, fetch, spstore, fromr
        .word zero, sourceid, neq, qbranch, 4f
        .word source, type, cr
4:      .word negativeone, over, eq, qbranch, 5f
        .word drop, branch, 1b
5:      .word dword, fetch, ndword, fetch, type, space
        .word dolit, -2, over, eq, qbranch, 6f
        .word dabort, fetch, count, type, cr
        .word drop, branch, 1b
6:      .word dolit, -4, over, eq, qbranch, 7f
        .word dosliteral
        .byte 15, "stack underflow"
        .word type, cr
        .word drop, branch, 1b
7:      .word dolit, -13, over, eq, qbranch, 8f
        .word dosliteral
        .byte 1, "?"
        .word type, cr
        .word drop, branch, 1b
8:      .word dosliteral
        .byte 21, "unhandled exception #"
        .word type, dot, cr
        .word drop, branch, 1b
9:      .word console, lbracket, prompt
        .word branch, 2b

VARIABLE("'boot", 0, xtboot)
        .word boot

// System startup and enter main loop
COLON("boot", 0, boot)
        .word two, atsettextstyle, dosliteral
        .byte 9, "ZmForth!\n"
        .word type
        .word zero, atsettextstyle, dosliteral
        .byte 111, "A Forth for the Z-machine\n"
        .byte "Copyright (c) 2009 by Marshall Vandegrift.\n"
        .byte "Release 1 / Serial number 090924 / Zas r1\n"
        .word type, quit
_boot:  .word xtboot, fetchexecute, bye

.section data
dict_end:
