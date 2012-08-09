#!/usr/bin/env zsh

NODE_PATH=`pwd` ENV=test \
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--reporter list \
		--require should \
    test/func/**/*.coffee
