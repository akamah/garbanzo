set -e

ruby proto1.rb grammar.garb > predef.tmp.garb
cat predef.tmp.garb program.garb > /tmp/test.tmp.garb

ruby proto2.rb /tmp/test.tmp.garb
