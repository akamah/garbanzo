set -e

ruby proto1.rb grammar2.garb > predef.tmp.garb
cat predef.tmp.garb program.garb > test.tmp.garb

ruby proto2.rb test.tmp.garb
