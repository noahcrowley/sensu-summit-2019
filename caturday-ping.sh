#!/bin/sh

# Intended for use on macOS
#
# This script is used to repeatedly ping the Caturday application every 0-1 seconds
# in order to generate data.

while :
do
  curl -s 'http://localhost:3333/' > /dev/null
  sleep 0."$(cat /dev/urandom | LC_CTYPE=C tr -dc '0-9' | fold -w 2 | head -n 1)"
done
