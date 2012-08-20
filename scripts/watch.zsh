
#!/usr/bin/env zsh

#DEBUG='*' \
NODE_PATH=`pwd` ENV=test \
	./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--reporter list \
    --watch \
		--require should \
    test/func/**/*.coffee
