func:
	scripts/func.zsh

unit:
	scripts/unit.zsh

test:
	scripts/test.zsh

grep:
	scripts/grep.zsh

z:
	scripts/z.zsh

run:
	scripts/run.zsh $(ENV)

watch:
	scripts/watch.zsh

vim:
	vim -o \
		test \
		lib/helpers.coffee  \
		lib/replicant.coffee \
		app.coffee

.PHONY: run, test
