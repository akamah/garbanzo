set -e

ruby proto1.rb calc.garb > predef.garb
cat predef.garb program.garb > test.garb

ruby proto2.rb test.garb
