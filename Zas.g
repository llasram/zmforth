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

grammar Zas;

options {
    language = Python;
    output = AST;
    ASTLabelType = CommonTree;
}

tokens {
    INDIRECT;
    INSN;
}

program
    :   statement+
    ;

statement
    :   label eol               -> label
    |   label? insnlist eol     -> label? insnlist
    |   ID eq='=' expr eol      -> ^(INSN ID[$eq, ".set"] ID expr)
    |   NEWLINE                 ->
    ;

eol :   ';'? NEWLINE | EOF      -> ;


label
    :   ID c=':'                -> ^(INSN ID[$c, ".set"] ID ID[$c, "."])
    |   v=INT c=':'             -> ^(INSN ID[$c, ".set"] ID[$v] ID[$c, "."])
    ;

insnlist
    :   insn ( ';' insn )*      -> insn+
    ;

insn:   ID arglist?             -> ^(INSN ID arglist?) ;

arglist
    :   arg (',' arg)*          -> arg+
    ;

arg :   REG
    |   lp='(' REG ')'          -> ^(INDIRECT REG)
    |   QSTR
    |   RETBOOL
    |   expr
    ;

expr:   expr1 ('|'^ expr1)* ;
expr1:  expr2 ('^'^ expr2)* ;
expr2:  expr3 ('&'^ expr3)* ;
expr3:  expr4 (('<<'^ | '>>'^) expr4)* ;
expr4:  expr5 (('+'^ | '-'^) expr5)* ;
expr5:  expr6 (('*'^ | '/'^ | '%'^) expr6)* ;
expr6:  atom | (('~'^ | '+'^ | '-'^ | '@'^) atom) ;

atom:   INT
    |   ID
    |   l=LOCAL                 -> ID[$l]
    |   '(' expr ')'            -> expr
    ;


REG :   '%' ((('l' | 'g') '0'..'9' '0'..'9'* ) | 'sp') ;
QSTR:   '"' ( ( '\\' . ) | ~('"' | '\\') )* '"'
    |   '\'' ( ( '\\' . ) | ~('\'' | '\\') )* '\'' ;
RETBOOL
    :   ':' ( 'rtrue' | 'rfalse' ) ;
ID  :   ('a'..'z' | 'A'..'Z' | '.' | '_')
        ('a'..'z' | 'A'..'Z' | '.' | '_' | '$' | '!' | '0'..'9')* ;
LOCAL: '1'..'9' '0'..'9'* ( 'f' | 'b' ) ;
INT :   '0'..'9'+
    |   ('0x' ('0'..'9' | 'A'..'F' | 'a'..'f')+)
    |   ('0b' ('0'..'1')+) ;
NEWLINE
    :   ('\r'? '\n') ;
COMMENT
    :   ('//' | '#') ( ~'\n' )* { $channel = "hidden" } ;
WS  :   ( ( ' ' | '\t' )+
        | ( '\\'  ( ' ' | '\t' )* NEWLINE ) ) { $channel = "hidden" } ;
