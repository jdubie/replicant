TESTS = $(shell find test -name '*.coffee')
UNIT_TESTS = $(shell find test/unit -name '*.coffee')
FUNC_TESTS = $(shell find test/func -name '*.coffee')

unit:
	scripts/unit.zsh

test:
	scripts/test.zsh

func:
	scripts/func.zsh

grep:
	scripts/grep.zsh

run:
	scripts/run.zsh

.PHONY: run, test
