#!/bin/bash

remote_url=$(git config --local --get remote.origin.url)

if [[ $remote_url == *"github" ]]; then
  current_repo=$(git config --local --get remote.origin.url | \
    sed s/git@github.com:// | \
    sed s/https:\\/\\/// | \
    sed s/github.com\\/// | \
    sed s/.git//)

  hub pull-request -o -b $current_repo:$1 $2
else
  stash pull-request $1
fi
