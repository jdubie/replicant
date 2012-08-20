#!/usr/bin/env zsh

NODE_PATH=`pwd` \
  ENV=test \
  DEBUG=replicant* \
    ./node_modules/.bin/mocha \
      --compilers coffee:coffee-script \
      --require should \
      --grep 'zzz' \
      test/**/*.coffee
