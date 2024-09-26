#!/bin/bash
source constants.sh
shopt -s extglob
set -ev

for workflow in $WORKFLOWS; do
  echo "Running workflow:" $workflow
  time ./workflows/${workflow}.sh
done
