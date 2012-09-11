#!/usr/bin/env zsh

NODE_PATH=`pwd` ENV=TEST \
  ./node_modules/.bin/mocha \
    --timeout 5000 \
    --compilers coffee:coffee-script \
    --reporter list \
    --require should
