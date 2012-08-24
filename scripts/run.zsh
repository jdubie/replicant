#!/usr/bin/env zsh

case "$1" in PRODUCTION)
  echo "No pushing to production yet";
  ;;
STAGE)
  echo 'Running STAGING';
  ENV='STAGE' \
  NODE_PATH=`pwd` \
  DEBUG='replicant*' \
    ./node_modules/.bin/coffee app.coffee;
  ;;
*)
  echo "Running DEVELOP";
  ENV='DEV' \
  NODE_PATH=`pwd` \
  DEBUG='replicant*' \
    ./node_modules/.bin/coffee app.coffee;
  ;;
  esac
