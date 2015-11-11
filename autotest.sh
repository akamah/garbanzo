#!/bin/sh

trap exit INT

while true
do
  clear
  ruby test_proto1.rb
  date
  fswatch -1 .
done
