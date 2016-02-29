#!/bin/sh

trap exit INT

while true
do
  ruby test_garbanzo.rb
  date
  fswatch -1 .
done
