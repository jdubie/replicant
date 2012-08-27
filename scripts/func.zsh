#!/usr/bin/env zsh

#DEBUG='*' \
NODE_PATH=`pwd` ENV=TEST \
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--reporter list \
		--require should \
    test/func/**/*.coffee
