#!/bin/bash

id=`xinput list|grep Expert|cut -d '=' -f2|sed -r 's/\t.+//g'`

if [[ -n "$id" ]]; then
  xinput set-button-map $id 1 8 2 4 5 6 7 3 9 10 11 12
fi
