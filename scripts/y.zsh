#!/usr/bin/env zsh

NODE_PATH=`pwd` \
  ENV=TEST \
    ./node_modules/.bin/mocha \
      --compilers coffee:coffee-script \
      --reporter nyan \
      --require should \
      --grep 'yyy' \
      test/**/*.coffee
