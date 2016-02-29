set -e

ruby proto1.rb grammar2.garb > predef.tmp.garb
cat predef.tmp.garb program.garb > /tmp/test2.tmp.garb

ruby proto2.rb /tmp/test2.tmp.garb
