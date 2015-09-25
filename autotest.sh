#!/bin/sh

set -e
trap exit INT

while true
do
  clear
  ruby test_proto1.rb
  fswatch -1 .
done
