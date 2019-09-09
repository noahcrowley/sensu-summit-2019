#!/bin/sh

# Intended for use on Linux
#
# This check outputs some random data in line protocol format.

printf "randoms value=$(cat /dev/urandom | tr -dc '0-9' | fold -w 2 | head -n 1) $(date +%s)000000000\n"