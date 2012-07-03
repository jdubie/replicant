TESTS = $(shell find test -name '*.coffee')

test:
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--require should \
			$(TESTS)

grep:
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--require should \
		--grep $(P) \
			$(TESTS)

run:
	./node_modules/.bin/coffee lib/index.coffee

.PHONY: run, test
