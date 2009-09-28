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
import os
from chunk import Chunk
import struct
from itertools import izip

class ZMergeError(Exception):
    pass

def main(argv=sys.argv):
    zinpath, savpath, zoutpath = argv[1:]
    data = ''
    with open(savpath, 'rb') as savf:
        form = Chunk(savf)
        if form.getname() != 'FORM':
            raise ZMergeError('not a valid IFF file')
        if form.read(4) != 'IFZS':
            raise ZMergeError('not a valid QUETZAL save file')
        mem = Chunk(form)
        while mem.getname() not in ('CMem', 'UMem'):
            mem.skip()
            mem = Chunk(form)
        if mem.getname() == 'UMem':
            data = mem.read()
        else:
            data = []
            byte = mem.read(1)
            while byte:
                data.append(byte)
                if byte == '\x00':
                    count = struct.unpack('B', mem.read(1))[0]
                    data.append(byte * count)
                byte = mem.read(1)
            data = ''.join(data)
    data = data[0x40:]
    with open(zinpath, 'rb') as zinf:
        header = zinf.read(0x40)
        statmem = zinf.read(len(data))
        himem = zinf.read()
    statmem = ''.join([chr(ord(x) ^ ord(y)) for x, y in izip(data, statmem)])
    with open(zoutpath, 'wb') as zoutf:
        zoutf.write(header)
        zoutf.write(statmem)
        zoutf.write(himem)
    return 0

if __name__ == '__main__':
    sys.exit(main())
