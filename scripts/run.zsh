#!/usr/bin/env zsh

case "$1" in PROD)
  echo 'Running PROD';
  ENV='PROD' \
  NODE_PATH=`pwd` \
  DEBUG='replicant*' \
    ./node_modules/.bin/coffee app.coffee;
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
