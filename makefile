# ----------------------------
# group nb 1
# 42191600 : Alexandre Gobeaux
# 24321600 : Gilles Peiffer
#
# ----------------------------

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S), Darwin)
C = /Applications/Mozart2.app/Contents/Resources/bin/ozc -c
X = /Applications/Mozart2.app/Contents/Resources/bin/ozengine
else
C = ozc -c
X = ozengine
endif

all:
	make clean
	make compileAll
	make run

compileAll:
	@$(C) Input.oz
	make compile

compile:
	@$(C) PlayerManager.oz
	make compilePlayers
	@$(C) GUI.oz
	@$(C) Main.oz

compilePlayers:
	@$(C) Player001*.oz

*.ozf:
	@$(C) *.oz

run:
	@$(X) Main.ozf

zip:
	rm -rf project.zip
	zip -j project.zip GUI.oz Main.oz PlayerManager.oz Player001*.oz Input.oz makefile

clean: # Delete every file except .ozf for which we don't have .oz files
	ls *.ozf | grep -v Player000bomber.ozf | grep -v Projet2019util.ozf | xargs rm
