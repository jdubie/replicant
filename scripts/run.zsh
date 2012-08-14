#!/usr/bin/env zsh

NODE_PATH=`pwd` \
  DEBUG=* \
    ./node_modules/.bin/coffee app.coffee
