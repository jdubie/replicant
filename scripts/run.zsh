#!/usr/bin/env zsh

case "$1" in production)
  echo "No pushing to production yet";
  ;;
stage)
  echo 'Running STAGING';
  ENV='STAGE' \
  NODE_PATH=`pwd` \
  DEBUG=* \
    ./node_modules/.bin/coffee app.coffee;
  ;;
*)
  echo "Running DEVELOP";
  ENV='DEV' \
  NODE_PATH=`pwd` \
  DEBUG=* \
    ./node_modules/.bin/coffee app.coffee;
  ;;
  esac


