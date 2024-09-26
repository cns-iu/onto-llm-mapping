#!/bin/bash
source constants.sh
shopt -s extglob
set -ev

# Before running workflows, ensure the llm templates directory is up to date
./src/update-templates.sh

for workflow in $WORKFLOWS; do
  echo "Running workflow:" $workflow
  time ./workflows/${workflow}.sh
done
