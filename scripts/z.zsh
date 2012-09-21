#!/usr/bin/env zsh

NODE_PATH=`pwd` \
  ENV=TEST \
  DEBUG=replicant* \
    ./node_modules/.bin/mocha \
      --timeout 8000 \
      --compilers coffee:coffee-script \
      --require should \
      --grep 'zzz' \
      test/**/*.coffee
