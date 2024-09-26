#!/bin/bash
set -e
source constants.sh

echo Run started on $(date)...
echo
for f in scripts/??-*.sh
do
  echo ">>" Running $f...
  time bash $f
  echo
done

echo
echo Run finished on $(date)
