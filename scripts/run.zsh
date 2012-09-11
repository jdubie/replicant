#!/usr/bin/env zsh

case "$1" in PROD)
  echo 'Running PROD';
  ENV='PROD' \
  NODE_PATH=`pwd` \
  DEBUG='replicant*' \
    ./node_modules/.bin/forever \
      -l ~/prod.log \
      -o ~/prod.out \
      -e ~/prod.err \
      -c ./node_modules/.bin/coffee app.coffee; 
  ;;
STAGE)
  echo 'Running STAGING';
  ENV='STAGE' \
  NODE_PATH=`pwd` \
  DEBUG='replicant*' \
    ./node_modules/.bin/forever \
      -l ~/stage.log \
      -o ~/stage.out \
      -e ~/stage.err \
      -c ./node_modules/.bin/coffee app.coffee; 
  ;;
*)
  echo "Running DEVELOP";
  ENV='DEV' \
  NODE_PATH=`pwd` \
  DEBUG='replicant*' \
    ./node_modules/.bin/forever \
      -l ~/dev.log \
      -o ~/dev.out \
      -e ~/dev.err \
      -c ./node_modules/.bin/coffee app.coffee; 
  ;;
  esac
