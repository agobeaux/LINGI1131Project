# ----------------------------
# group nb XXX
# 42191600 : Alexandre Gobeaux
# noma2 : Gilles Peiffer
# ----------------------------

all :
	make compileAll
	make run

compileAll :
	ozc -c Input.oz
	make compile

compile :
	ozc -c PlayerManager.oz
	ozc -c Player*.oz
	ozc -c GUI.oz
	ozc -c Main.oz

compilePlayers : # compiles PlayerManager.oz too... can still use grep
	ozc -c Player*.oz

*.ozf :
	ozc -c *.oz

run :
	ozengine Main.ozf

clean : # Delete every file except .ozf for which we don't have .oz files
	ls *.ozf | grep -v Player000bomber.ozf | grep -v Projet2019util.ozf | xargs rm
