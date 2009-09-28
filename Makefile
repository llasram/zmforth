CPP = cpp
ANTLR = antlr3
ZAS = ./zas.py
REC = ./rec.py
ZSAV = ./zsav.exp
ZMERGE = ./zmerge.py

ZAS_STATIC = zas.py opcodes.py zheader.py
ZAS_GENERATED = ZasParser.py ZasWalker.py
ZAS_SOURCES = $(ZAS_STATIC) $(ZAS_GENERATED)

TESTS = tests/tester.fr tests/core.fr tests/coreplustest.fth \
        tests/coreexttest.fth tests/exceptiontest.fth \
        tests/stringtest.fth tests/doubletest.fth \
        tests/toolstest.fth

all: zmforth.z5 zmforth+tools.z5

test: all tests.rec
	./test.exp

examples: tetris.z5

zmforth+tools.z5: zmforth.z5 zmforth+tools.sav
	$(ZMERGE) $^ $@

zmforth+tools.sav: zmforth.z5 tools.rec
	$(ZSAV) $^ $@

zmforth.z5: zmforth-base.z5 zmforth.sav
	$(ZMERGE) $^ $@

zmforth.sav: zmforth-base.z5 zmforth.rec
	$(ZSAV) $^ $@

zmforth-base.z5: zmforth.s $(ZAS_SOURCES)
	$(ZAS) zmforth.s $@

ZasParser.py: Zas.g
	$(ANTLR) $^

ZasWalker.py: ZasWalker.g
	$(ANTLR) $^

zmforth.s: zmforth.S
	$(CPP) -o $@ $^

tetris.z5: zmforth.z5 tetris.sav
	$(ZMERGE) zmforth.z5 tetris.sav $@

tetris.sav: zmforth.z5 tetris.rec
	$(ZSAV) $^ $@

zmforth.rec: zmforth.fs
tools.rec: tools.fs

tetris.rec: examples/tetris.fs
	$(REC) $^ >$@

tests.rec: $(TESTS)
	$(REC) $^ >$@

%.rec: %.fs
	$(REC) $^ >$@

clean:
	rm -f ZasLexer.py ZasParser.py ZasWalker.py Zas__.g \
          *.tokens *.pyc *.s *.z5 *.rec *.sav

.PHONY: all test examples clean 
