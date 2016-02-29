#!/bin/sh
set -e

cat predef.tmp.garb program.garb > /tmp/test.tmp.garb

ruby proto2.rb /tmp/test.tmp.garb
