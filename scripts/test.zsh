#!/usr/bin/env zsh

NODE_PATH=`pwd` \
  ./node_modules/.bin/mocha \
    --compilers coffee:coffee-script \
    --reporter list \
    --require should
