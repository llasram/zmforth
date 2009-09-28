#! /usr/bin/python

# Copyright (c) 2009 Marshall Vandegrift
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

from __future__ import with_statement

import sys
import re
from cStringIO import StringIO
from operator import add, sub
import copy
import struct
from itertools import islice, izip
import antlr3
import antlr3.tree
from ZasLexer import ZasLexer
from ZasParser import ZasParser
from ZasWalker import ZasWalker
from opcodes import OPCODES, COUNT_0OP, COUNT_1OP, COUNT_2OP, COUNT_VAR, \
    COUNT_EXT, RESULT, BRANCH, BYREF, PACK1, RELATIVE, REVERSE, INVERT
from zheader import ZHeader

class ZasError(Exception):
    pass

class Atom(object):
    def argbits(self, byref=False, offset=0):
        try:
            _, value = self.eval()
        except ZasError:
            return 0
        value = value - offset
        if value >= 0 and value < (1 << 8):
            return 1
        return 0

    def arg2opbits(self):
        bits = self.argbits()
        if bits == 1 or bits == 2:
            return bits - 1
        return None

class Register(Atom):
    def __init__(self, name, indirect=False):
        self.name = name
        self.indirect = indirect
        self.value = self._eval()

    def __repr__(self):
        return "Register(%r)" % (self.name,)

    def _eval(self):
        value = None
        if self.name == '%sp':
            value = 0
        elif self.name.startswith('%l'):
            value = int(self.name[2:]) + 1
            if value < 1 or value > 15:
                raise ZasError("invalid local register")
        elif self.name.startswith('%g'):
            value = int(self.name[2:]) + 16
            if value < 16 or value > 255:
                raise ZasError("invalid global register")
        return value

    def eval(self):
        return set(), self.value

    def argbits(self, byref=False, offset=0):
        if byref and not self.indirect:
            return 1
        return 2

class String(Atom):
    ESCAPE_RE = re.compile(r'[\\](.)')
    # Newline is carriage return
    ESCAPES = {'a': '\a', 'b': '\b', 'f': '\f', 'n': '\r', 'r': '\r',
               't': '\t', 'v': '\v'}

    def _escape(self, match):
        char = match.group(1)
        return self.ESCAPES.get(char, char)

    def __init__(self, value):
        self.value = self.ESCAPE_RE.sub(self._escape, value[1:-1])

    def eval(self):
        return set(), ord(self.value[0])

    def __str__(self):
        return self.value

    def __repr__(self):
        return "String(%r)" % (self.value,)

class Integer(Atom):
    def __init__(self, value):
        if isinstance(value, (int, long)):
            pass
        elif value[:2] == '0b':
            value = int(value[2:], 2)
        elif value[:2] == '0x':
            value = int(value[2:], 16)
        else:
            value = int(value)
        self.value = value

    def eval(self):
        return set(), self.value

    def argbits(self, byref=False, offset=0):
        if offset > 0:
            return 0
        if self.value >= 0 and self.value < (1 << 8):
            return 1
        return 0

    def __repr__(self):
        return "Integer(%r)" % (self.value,)

class RetBool(Atom):
    VALUES = {':rfalse': 0,':rtrue': 1}

    def __init__(self, value):
        self.value = value

    def eval(self):
        return set(), self.VALUES[self.value]

    def argbits(self, byref=False, offset=0):
        return 1

    def __repr__(self):
        return "RetBool(%s)" % (self.value,)

class Symbol(Atom):
    def __init__(self, name, locdir=None):
        self.name = name
        self.locdir = locdir
        self.local = bool(locdir) or name[0].isdigit()
        self.sections = set()
        self.value = None
        self.expr = None

    def eval(self):
        if self.value is not None:
            return self.sections, self.value
        if self.expr is not None:
            sections, value = self.expr.eval()
            return sections, value
        raise ZasError('Evaluated not-yet-defined symbol %r' % self.name)

    def argbits(self, byref=False, offset=0):
        if self.local and not self.value and not self.expr and offset > 0:
            return 1
        try:
            value = self.eval()[1]
        except ZasError:
            return 0
        if value >= 0 and value < (1 << 8):
            return 1
        return 0

    def __repr__(self):
        return "Symbol(%r)" % (self.name + (self.locdir or ''),)

class Expr(Atom):
    def __init__(self, oper, *args):
        self.oper = oper
        self.args = args

    def eval(self):
        sections, args = set(), []
        for arg in self.args:
            s, a = arg.eval()
            if self.oper == sub:
                sections.difference_update(s)
            else:
                sections.update(s)
            args.append(a)
        value = self.oper(*args)
        return sections, value

    def __repr__(self):
        result = []
        for arg in self.args:
            result.append(repr(arg))
        return 'Expr(?, %s)' % ', '.join(result)

class Section(object):
    def __init__(self, name):
        self.name = name
        self.content = StringIO()
        # Fake-out pre-relocation symbol sizes
        self.base = 0x10000

    def offset():
        def fget(self):
            return self.content.tell()
        def fset(self, value):
            self.content.seek(value)
        return property(fget=fget, fset=fset)
    offset = offset()

    def __len__(self):
        offset = self.content.tell()
        try:
            self.content.seek(0, 2)
            result = self.content.tell()
        finally:
            self.content.seek(offset, 0)
        return result

    def eval(self):
        return set([self]), self.base

    def __getattr__(self, name):
        return getattr(self.content, name)

    def __repr__(self):
        return "Section(%r)" % (self.name,)

class ZasAssembler(object):
    ALPHATAB = ["abcdefghijklmnopqrstuvwxyz",
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                "\r0123456789.,!?_#'\"/\\-:()"]

    def __init__(self):
        self.symtab = {}
        self.relocs = []
        self.sections = {'data': Section('data'),
                         'rodata': Section('rodata'),
                         'text': Section('text')}
        self.section = self.sections['text']
        self.start = None

    def finalize(self):
        sections = self.sections
        base = sections['data'].base = 0
        datasz = len(sections['data'])
        mod = datasz % 4
        if mod != 0:
            sections['data'].write('\0' * (8 - mod))
            datasz = len(sections['data'])
        sections['rodata'].base = base + datasz
        rodatasz = len(sections['rodata'])
        mod = rodatasz % 4
        if mod != 0:
            sections['rodata'].write('\0' * (8 - mod))
            rodatasz = len(sections['rodata'])
        sections['text'].base = base + datasz + rodatasz
        mod = len(sections['text']) % 4
        if mod != 0:
            sections['text'].write('\0' * (8 - mod))
        for reloc in self.relocs:
            section, offset, expr, widths, relative, branch, invert = reloc
            # print (section, hex(offset), widths, expr, expr.eval())
            self._relocate(expr, widths, relative=relative, branch=branch,
                           invert=invert, fixup=True, section=section,
                           offset=offset)
        self.start = self.start.eval()[1]
        self.globals = self.globals.eval()[1]

    def symbol(self, name):
        if name == '.':
            return self._current_address()
        if name[0].isdigit() and not name[-1].isdigit():
            locdir = name[-1]
            name = name[:-1]
        else:
            locdir = None
        if name not in self.symtab or \
           (locdir == 'f' and self.symtab[name].expr is not None):
            self.symtab[name] = Symbol(name, locdir)
        return self.symtab[name]

    def packaddr(self, number):
        return number >> 2

    def integer(self, *args):
        return Integer(*args)

    def expr(self, *args):
        return Expr(*args)

    def register(self, *args):
        return Register(*args)

    def string(self, *args):
        return String(*args)

    def retbool(self, *args):
        return RetBool(*args)

    def insn(self, name, args):
        meth = '_insn_' + name.replace('.', 'dot_')
        if hasattr(self, meth):
            return getattr(self, meth)(*args)
        raise ZasError('unknown instruction or directive %r' % name)

    def _relocate(self, expr, widths, relative=False, branch=False,
                  invert=False, fixup=False, section=None, offset=None):
        section = self.section if section is None else section
        if offset is not None:
            section.offset = offset
        else:
            offset = section.offset
        if isinstance(expr, (Register, RetBool)):
            relative = False
        elif branch:
            relative = True
        sections, value = None, None
        try:
            sections, value = expr.eval()
        except ZasError:
            if fixup:
                raise
        if value is None or \
           (not fixup and sections and
            (not relative or (len(sections) > 1 or
                              section not in sections))):
            if relative and isinstance(expr, Symbol) and expr.local:
                width = widths[0]
            else:
                width = widths[-1]
            reloc = (section, offset, expr, width, relative, branch, invert)
            if fixup:
                raise ZasError('could not perform relocation: %r' % (reloc,))
            self.relocs.append(reloc)
            self.section.write(struct.pack('>' + width, 0))
            return struct.calcsize(width)
        for width in widths:
            bytes = struct.calcsize(width)
            v = value
            if relative:
                v = v - (section.base + offset + bytes) + 2
            fbits = 2 if branch else 0
            max = 1 << ((bytes * 8) - fbits)
            min = 0 if bytes == 1 else -(max >> 1)
            if relative and bytes == 2:
                max = (max >> 1)
            if v < min or v > max:
                continue
            if branch:
                if v < 0:
                    width = width.upper()
                    v = (1 << 14) - abs(v)
                if not invert:
                    v |= 0x80 << (8 * (bytes - 1))
                if bytes == 1:
                    v |= 0x40
            if v > 0 and v >= (max >> 1):
                width = width.upper()
            #print 1, (expr, relative, width, v)
            section.write(struct.pack('>' + width, v))
            return struct.calcsize(width)
        else:
            raise ZasError("number %r out of range for width options %r" %
                           (value, widths))
        return

    def _current_address(self):
        return Expr(add, self.section, Integer(self.section.offset))

    def _zencode(self, chars):
        enchars = []
        for char in chars:
            if char == ' ':
                enchars.append(0)
            elif char in self.ALPHATAB[0]:
                zchar = self.ALPHATAB[0].index(char) + 6
                enchars.append(zchar)
            elif char in self.ALPHATAB[1]:
                zchar = self.ALPHATAB[1].index(char) + 6
                enchars.extend([4, zchar])
            elif char in self.ALPHATAB[2]:
                zchar = self.ALPHATAB[2].index(char) + 7
                enchars.extend([5, zchar])
            else:
                zchar = ord(char)
                enchars.extend([5, 6, (zchar >> 5) & 0x1f, zchar & 0x1f])
        mod = len(enchars) % 3
        pad = 0 if mod == 0 else 3 - mod
        enchars.extend([5] * pad)
        words = []
        slices = [islice(enchars, i, None, 3) for i in xrange(3)]
        for hi, mi, lo in izip(*slices):
            words.append((hi << 10) | (mi << 5) | (lo << 0))
        words[-1] |= 0x8000
        result = struct.pack('>' + ('H' * len(words)), *words)
        return result

    def _insn_dot_set(self, symbol, expr):
        if symbol.value is None and symbol.expr is None:
            symbol.expr = expr
            return
        symbol = copy.copy(symbol)
        symbol.expr = expr
        self.symtab[symbol.name] = symbol

    def _insn_dot_section(self, symbol):
        self.section = self.sections[symbol.name]

    def _insn_dot_align(self, expr):
        _, value = expr.eval()
        self._align(value)

    def _align(self, value):
        mod = self.section.offset % value
        if mod != 0:
            self.section.offset += value - mod
        return

    def _insn_dot_byte(self, *args):
        for arg in args:
            if isinstance(arg, String):
                self.section.write(str(arg))
            else:
                self._relocate(arg, 'b')
        return

    def _insn_dot_word(self, *args):
        self._align(2)
        for arg in args:
            self._relocate(arg, 'h')
        return

    def _insn_dot_ascii(self, *args):
        for arg in args:
            self.section.write(str(arg))
        return

    def _insn_dot_asciz(self, *args):
        for arg in args:
            self.section.write(str(arg) + '\0')
        return

    def _insn_dot_zscii(self, *args):
        for arg in args:
            self.section.write(self._zencode(str(arg)))
        return

    def _insn_dot_fill(self, repeat, size=None, value=None):
        repeat = repeat.eval()[1]
        size = 1 if size is None else size.eval()[1]
        value = 0 if value is None else value.eval()[1]
        format = {1: '>b', 2: '>h', 4: '>i'}[size]
        code = struct.pack(format, value) * repeat
        self.section.write(code)

    def _insn_dot_org(self, expr):
        sections, value = expr.eval()
        if len(sections) > 1:
            raise ZasError('nonsensical .org address')
        if len(sections) > 0:
            self.section = sections.pop()
            value = value - self.section.base
        self.section.offset = value

    def _insn_dot_start(self, expr):
        self.start = expr

    def _insn_dot_label(self, label):
        return self._insn_dot_set(label, self.symbol('.'))

    def _insn_dot_routine(self, label, regcount):
        regcount = regcount.eval()[1]
        if regcount < 0 or regcount > 15:
            raise ZasError('invalid number of local registers %r' %
                           (regcount,))
        self._align(4)
        self._insn_dot_label(label)
        self.section.write(struct.pack('>b', regcount))
        return

    def _insn_dot_globals(self, label):
        self.globals = label

    def _insn_calln(self, *args):
        if len(args) == 1:
            return self._insn_call_1n(*args)
        elif len(args) == 2:
            return self._insn_call_2n(*args)
        elif len(args) <= 4:
            return self._insn_call_vn(*args)
        else:
            return self._insn_call_vn2(*args)

    def _insn_calls(self, *args):
        if len(args) == 1:
            raise ZasError('calls instruction without result operand')
        if len(args) == 2:
            return self._insn_call_1s(*args)
        elif len(args) == 3:
            return self._insn_call_2s(*args)
        elif len(args) <= 5:
            return self._insn_call_vs(*args)
        else:
            return self._insn_call_vs2(*args)

    def _insn_print(self, string):
        self.section.write(struct.pack('>B', 0xb2))
        self.section.write(self._zencode(str(string)))


def create_insns():
    def create_insn(name, count, opcode, flags):
        def do_insn(self, *args):
            args = list(args)
            branch = None
            result = None
            if flags & BRANCH:
                branch = args.pop()
            if flags & RESULT:
                result = args.pop()
                if not isinstance(result, Register):
                    raise ZasError('non-register result operand')
            if flags & REVERSE:
                args.reverse()
            if flags & PACK1 and not isinstance(args[0], Register):
                args[0] = Expr(self.packaddr, args[0])
            if flags & BYREF and not args[0].indirect:
                args[0] = Integer(args[0].value)
            if count == COUNT_0OP:
                if len(args) != 0:
                    raise ZasError("bad arguments for %r" % (name,))
                code = 0xb0 | opcode
                self.section.write(struct.pack('>B', code))
            elif count == COUNT_1OP:
                if len(args) != 1:
                    raise ZasError("bad arg count for %r" % (name,))
                arg, = args
                if flags & RELATIVE:
                    relative = True
                    argbits = arg.argbits(offset=self.section.offset)
                else:
                    relative = False
                    argbits = arg.argbits()
                code = 0x80 | (argbits << 4) | opcode
                self.section.write(struct.pack('>B', code))
                self._relocate(arg, 'bh', relative=relative)
            elif count == COUNT_2OP and len(args) == 2 and \
                 args[0].arg2opbits() is not None and \
                 args[1].arg2opbits() is not None:
                code = ((args[0].arg2opbits() << 6) |
                        (args[1].arg2opbits() << 5) |
                        opcode)
                self.section.write(struct.pack('>B', code))
                self._relocate(args[0], 'bh')
                self._relocate(args[1], 'bh')
            elif count == COUNT_2OP or count == COUNT_VAR:
                if len(args) > 4 and name not in ('call_vn2', 'call_vs2'):
                    raise ZasError("bad arg count for %r" % (name,))
                if len(args) > 8:
                    raise ZasError("bad arg count for %r" % (name,))
                code = 0xc0 if count == COUNT_2OP else 0xe0
                code = code | opcode
                self.section.write(struct.pack('>B', code))
                argb = 0xff
                for arg in reversed(args[:4]):
                    argb = (argb >> 2) | (arg.argbits() << 6)
                self.section.write(struct.pack('>B', argb))
                if len(args) > 4:
                    argb = 0xff
                    for arg in reversed(args[4:]):
                        argb = (argb >> 2) | (arg.argbits() << 6)
                        self.section.write(struct.pack('>B', argb))
                for arg in args:
                    self._relocate(arg, 'bh')
            elif count == COUNT_EXT:
                if len(args) > 4:
                    raise ZasError("bad arg count for %r" % (name,))
                argb = 0xff
                for arg in reversed(args):
                    argb = (argb >> 2) | (arg.argbits() << 6)
                self.section.write(struct.pack('>BBB', 0xbe, opcode, argb))
                for arg in args:
                    self._relocate(arg, 'bh')
            else:
                raise ZasError('wtf? unexpected instruction type')
            if result:
                self._relocate(result, 'b')
            if branch:
                invert = flags & INVERT
                self._relocate(branch, 'bh', branch=True, invert=invert)
        setattr(ZasAssembler, '_insn_' + name, do_insn)
    for name, count, opcode, flags in OPCODES:
        create_insn(name, count, opcode, flags)
create_insns()

class ZasWalker(ZasWalker):
    def __init__(self, input, assembler):
        super(ZasWalker, self).__init__(input)
        self.assembler = assembler

def main(argv=sys.argv):
    inpath, outpath = argv[1:]
    with open(inpath, 'rb') as inf:
        char_stream = antlr3.ANTLRInputStream(inf)
    lexer = ZasLexer(char_stream)
    tokens = antlr3.CommonTokenStream(lexer)
    parser = ZasParser(tokens)
    r = parser.program()
    t = r.tree
    #print t.toStringTree()
    nodes = antlr3.tree.CommonTreeNodeStream(t)
    nodes.setTokenStream(tokens)
    assembler = ZasAssembler()
    walker = ZasWalker(nodes, assembler)
    walker.program()
    assembler.finalize()
    zcode = []
    for secname in ('data', 'rodata', 'text'):
        zcode.append(assembler.sections[secname].getvalue())
    zcode = ''.join(zcode)[0x40:]
    header = ZHeader()
    header.version = 5
    header.initpc = assembler.start
    header.globals = assembler.globals
    header.statmem = assembler.sections['rodata'].base
    header.himem = assembler.sections['text'].base
    header.filesz = len(zcode) + 0x40
    with open(outpath, 'wb') as outf:
        outf.write(str(header))
        outf.write(zcode)
    return 0

if __name__ == '__main__':
    sys.exit(main())
