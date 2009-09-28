\ ANS Forth tests - run all tests

\ Adjust the file paths as appropriate to your system

.( Running all ANS Forth tests) CR

	S" tester.fr" INCLUDED
	S" core.fr" INCLUDED
   S" coreplustest.fth" INCLUDED
	S" coreexttest.fth" INCLUDED
	S" doubletest.fth" INCLUDED
	S" exceptiontest.fth" INCLUDED
	S" filetest.fth" INCLUDED
	S" memorytest.fth" INCLUDED
	S" toolstest.fth" INCLUDED
	S" searchordertest.fth" INCLUDED
	S" stringtest.fth" INCLUDED

CR CR .( Forth tests completed ) CR CR


