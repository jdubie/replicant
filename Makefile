TESTS = $(shell find test -name '*.coffee')
UNIT_TESTS = $(shell find test/unit -name '*.coffee')
FUNC_TESTS = $(shell find test/func -name '*.coffee')

test:
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--reporter list \
		--require should \
			$(TESTS)

unit:
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--reporter list \
		--require should \
			$(UNIT_TESTS)

func:
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--reporter list \
		--require should \
			$(FUNC_TESTS)

grep:
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--require should \
		--grep $(P) \
			$(TESTS)

run:
	./node_modules/.bin/coffee lib/index.coffee

.PHONY: run, test
