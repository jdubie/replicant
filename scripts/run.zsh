#!/usr/bin/env zsh

NODE_PATH=`pwd` \
  DEBUG=replicant* \
    ./node_modules/.bin/coffee app.coffee
