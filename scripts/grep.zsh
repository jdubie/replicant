#!/usr/bin/env zsh

NODE_PATH=`pwd` \
DEBUG=replicant* \
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--require should \
		--grep $P