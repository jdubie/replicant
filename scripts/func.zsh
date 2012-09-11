#!/usr/bin/env zsh

#DEBUG='*' \
NODE_PATH=`pwd` ENV=TEST \
	./node_modules/.bin/mocha \
    --timeout 8000 \
		--compilers coffee:coffee-script \
		--reporter nyan \
		--require should \
    test/func/**/*.coffee
