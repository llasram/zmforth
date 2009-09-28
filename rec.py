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
import re
from contextlib import closing

CHAR_RE = re.compile(r'.', re.DOTALL)

def sopen(path):
    if path == '-':
        return closing(sys.stdin)
    return open(path)

def rec(match):
    char = match.group(0)
    if char == "\n":
        return "\n"
    return "[%d]\n" % ord(char)

def main(argv=sys.argv):
    arg0, args = argv[0], argv[1:]
    if len(args) == 0:
        args.append('-')
    for path in args:
        with sopen(path) as f:
            buf = f.read(2048)
            while buf:
                sys.stdout.write(CHAR_RE.sub(rec, buf))
                buf = f.read(2048)
    sys.stdout.write("[0]\n")
    return 0

if __name__ == '__main__':
    sys.exit(main())
