#!/bin/sh
set -e

cat predef.tmp.garb program.garb > test.tmp.garb

ruby proto2.rb test.tmp.garb -i
