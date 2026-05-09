#!/bin/bash
#
# Run this from ~/src

for i in */.git
do
  (cd "${i%/}"/.. && d=$(dirname "$i") && echo "  == $d" && git pull)
done
