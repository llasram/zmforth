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
from struct import pack, unpack

class ZHeader(object):
    def __init__(self, data=None):
        if data is None:
            data = '\0' * 64
        self._from_image(data[:64])

    def _from_image(self, data):
        self.version, = unpack('>B', data[0])
        flags1, = unpack('>B', data[1])
        self.colors = bool(flags1 & 0x01)
        self.picts = bool(flags1 & 0x02)
        self.bold = bool(flags1 & 0x04)
        self.italic = bool(flags1 & 0x08)
        self.fixed = bool(flags1 & 0x10)
        self.sounds = bool(flags1 & 0x20)
        self.timed = bool(flags1 & 0x80)
        self.relnum, = unpack('>H', data[2:4])
        self.himem, = unpack('>H', data[4:6])
        self.initpc, = unpack('>H', data[6:8])
        self.dict, = unpack('>H', data[8:10])
        self.objects, = unpack('>H', data[10:12])
        self.globals, = unpack('>H', data[12:14])
        self.statmem, = unpack('>H', data[14:16])
        flags2, = unpack('>H', data[16:18])
        self.transcript = bool(flags2 & 0x01)
        self.forcefixed = bool(flags2 & 0x02)
        self.dirtystatus = bool(flags2 & 0x04)
        self.want_picts = bool(flags2 & 0x08)
        self.want_undo = bool(flags2 & 0x10)
        self.want_mouse = bool(flags2 & 0x20)
        self.want_colors = bool(flags2 & 0x40)
        self.want_sounds = bool(flags2 & 0x80)
        self.want_menus = bool(flags2 & 0x100)
        self.serial, = unpack('>6s', data[18:24])
        self.abbrevs, = unpack('>H', data[24:26])
        self.filesz = unpack('>H', data[26:28])[0] * 4
        self.chksum, = unpack('>H', data[28:30])
        self.intnum, = unpack('>B', data[30])
        self.intver, = unpack('>B', data[31])
        self.screen_cheight, = unpack('>B', data[32])
        self.screen_cwidth, = unpack('>B', data[33])
        self.screen_uheight, = unpack('>H', data[34:36])
        self.screen_uwidth, = unpack('>H', data[36:38])
        self.font_uwidth, = unpack('>B', data[38])
        self.font_uheight, = unpack('>B', data[39])
        self.codeoff = unpack('>H', data[40:42])[0] * 8
        self.stroff = unpack('>H', data[42:44])[0] * 8
        self.bgcolor, = unpack('>B', data[44])
        self.fgcolor, = unpack('>B', data[45])
        self.termchars, = unpack('>H', data[46:48])
        self.stream3_pwidth, = unpack('>H', data[48:50])
        self.revnum, = unpack('>H', data[50:52])
        self.alphabet, = unpack('>H', data[52:54])
        self.hdrext, = unpack('>H', data[54:56])
        self.compver, = unpack('>4s', data[60:64])

    def __str__(self):
        flags1 = 0
        if self.colors: flags1 |= 0x1
        if self.picts: flags1 |= 0x02
        if self.bold: flags1 |= 0x04
        if self.italic: flags1 |= 0x08
        if self.fixed: flags1 |= 0x10
        if self.sounds: flags1 |= 0x20
        if self.timed: flags1 |= 0x80
        flags2 = 0
        if self.transcript: flags2 |= 0x01
        if self.forcefixed: flags2 |= 0x02
        if self.dirtystatus: flags2 |= 0x04
        if self.want_picts: flags2 |= 0x08
        if self.want_undo: flags2 |= 0x10
        if self.want_mouse: flags2 |= 0x20
        if self.want_colors: flags2 |= 0x40
        if self.want_sounds: flags2 |= 0x80
        if self.want_menus: flags2 |= 0x100
        himem = min([self.himem, 0xfffe])
        return pack('>BBHHHHHHHH6sHHHBBBBHHBBHHBBHHHHHxxxx4s',
                    self.version, flags1, self.relnum, himem,
                    self.initpc, self.dict, self.objects, self.globals,
                    self.statmem, flags2, self.serial, self.abbrevs,
                    self.filesz / 4, self.chksum, self.intnum, self.intver,
                    self.screen_cheight, self.screen_cwidth,
                    self.screen_uheight, self.screen_uwidth, self.font_uwidth,
                    self.font_uheight, self.codeoff / 8, self.stroff / 8,
                    self.bgcolor, self.fgcolor, self.termchars,
                    self.stream3_pwidth, self.revnum, self.alphabet,
                    self.hdrext, self.compver)

    def dump(self):
        print "% 16s:" % "version", self.version
        print "% 16s:" % "colors", self.colors
        print "% 16s:" % "picts", self.picts
        print "% 16s:" % "bold", self.bold
        print "% 16s:" % "italic", self.italic
        print "% 16s:" % "fixed", self.fixed
        print "% 16s:" % "sounds", self.sounds
        print "% 16s:" % "timed", self.timed
        print "% 16s:" % "himem", self.himem
        print "% 16s:" % "initpc", self.initpc
        print "% 16s:" % "dict", self.dict
        print "% 16s:" % "objects", self.objects
        print "% 16s:" % "globals", self.globals
        print "% 16s:" % "statmem", self.statmem
        print "% 16s:" % "transcript", self.transcript
        print "% 16s:" % "forcefixed", self.forcefixed
        print "% 16s:" % "dirtystatus", self.dirtystatus
        print "% 16s:" % "want_picts", self.want_picts
        print "% 16s:" % "want_undo", self.want_undo
        print "% 16s:" % "want_mouse", self.want_mouse
        print "% 16s:" % "want_colors", self.want_colors
        print "% 16s:" % "want_sounds", self.want_sounds
        print "% 16s:" % "want_menus", self.want_menus
        print "% 16s:" % "abbrevs", self.abbrevs
        print "% 16s:" % "filesz", self.filesz
        print "% 16s:" % "chksum", self.chksum
        print "% 16s:" % "intnum", self.intnum
        print "% 16s:" % "intver", self.intver
        print "% 16s:" % "screen_cheight", self.screen_cheight
        print "% 16s:" % "screen_cwidth", self.screen_cwidth
        print "% 16s:" % "screen_uheight", self.screen_uheight
        print "% 16s:" % "screen_uwidth", self.screen_uwidth
        print "% 16s:" % "font_uwidth", self.font_uwidth
        print "% 16s:" % "font_uheight", self.font_uheight
        print "% 16s:" % "codeoff", self.codeoff
        print "% 16s:" % "stroff", self.stroff
        print "% 16s:" % "bgcolor", self.bgcolor
        print "% 16s:" % "fgcolor", self.fgcolor
        print "% 16s:" % "termchars", self.termchars
        print "% 16s:" % "stream3_pwidth", self.stream3_pwidth
        print "% 16s:" % "revnum", self.revnum
        print "% 16s:" % "alphabet", self.alphabet
        print "% 16s:" % "hdrext", self.hdrext


def main(argv=sys.argv):
    args = argv[1:]
    for path in args:
        with open(path) as inf:
            header = ZHeader(inf.read())
            header.dump()
    return 0

if __name__ == '__main__':
    sys.exit(main())
