#!/bin/sh
cat predef.garb program.garb > test.garb

ruby proto2.rb test.garb
