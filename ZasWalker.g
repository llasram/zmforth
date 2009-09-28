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

tree grammar ZasWalker;

options {
    language = Python;
    tokenVocab = Zas;
    ASTLabelType = CommonTree;
}

@header {
from operator import or_, xor, and_, lshift, rshift, add, sub, mul, div, \
    mod, invert, neg
}

program
    :   insn+
    ;

insn:   ^(INSN ID arglist) {
            self.assembler.insn($ID.getText(), $arglist.value)
        }
    ;

arglist returns [list value]
@init { $value = [] }
    :  (a=arg { $value.append($a.value) })*
    ;

arg returns [object value]
    @init { 
        register = self.assembler.register 
        string = self.assembler.string
        retbool = self.assembler.retbool
    }
    :   REG                     {$value = register($REG.getText())}
    |   ^(INDIRECT REG)         {$value = register($REG.getText(), True)}
    |   QSTR                    {$value = string($QSTR.getText())}
    |   RETBOOL                 {$value = retbool($RETBOOL.getText())}
    |   expr                    {$value = $expr.value}
    ;

expr returns [object value] options { backtrack=true; }
    @init {
        expr = self.assembler.expr
        symbol = self.assembler.symbol
        integer = self.assembler.integer
        packaddr = self.assembler.packaddr
    }
    :   ^('|' l=expr r=expr)    {$value = expr(or_, $l.value, $r.value)}
    |   ^('^' l=expr r=expr)    {$value = expr(xor, $l.value, $r.value)}
    |   ^('&' l=expr r=expr)    {$value = expr(and_, $l.value, $r.value)}
    |   ^('<<' l=expr r=expr)   {$value = expr(lshift, $l.value, $r.value)}
    |   ^('>>' l=expr r=expr)   {$value = expr(rshift, $l.value, $r.value)}
    |   ^('+' l=expr r=expr)    {$value = expr(add, $l.value, $r.value)}
    |   ^('-' l=expr r=expr)    {$value = expr(sub, $l.value, $r.value)}
    |   ^('*' l=expr r=expr)    {$value = expr(mul, $l.value, $r.value)}
    |   ^('/' l=expr r=expr)    {$value = expr(div, $l.value, $r.value)}
    |   ^('%' l=expr r=expr)    {$value = expr(mod, $l.value, $r.value)}
    |   ^('+' e=expr)           {$value = $e.value}
    |   ^('-' e=expr)           {$value = expr(neg, $e.value)}
    |   ^('~' e=expr)           {$value = expr(invert, $e.value)}
    |   ^('@' e=expr)           {$value = expr(packaddr, $e.value)}
    |   INT                     {$value = integer($INT.getText())}
    |   ID                      {$value = symbol($ID.getText())}
    ;
