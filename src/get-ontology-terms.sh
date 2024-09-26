#!/bin/bash
source constants.sh
shopt -s extglob
set -ev

DIR=$1

# Get UBERON Terms
./src/sparql-select.sh https://lod.humanatlas.io/sparql queries/all-hra-uberon-terms.rq \
  | csvformat > $DIR/uberon-terms.csv

# Get MeSH Terms
./src/sparql-select.sh "https://id.nlm.nih.gov/mesh/sparql" queries/mesh-terms.rq \
  | csvformat > $DIR/mesh-terms.csv
./src/sparql-select.sh "https://id.nlm.nih.gov/mesh/sparql?offset=1000" queries/mesh-terms.rq \
  | csvformat | tail -n +2 >> $DIR/mesh-terms.csv

# Get MeSH Terms + Descriptors
./src/sparql-select.sh "https://id.nlm.nih.gov/mesh/sparql" queries/mesh-descriptors.rq \
  | csvformat > $DIR/mesh-descriptors.csv
./src/sparql-select.sh "https://id.nlm.nih.gov/mesh/sparql?offset=1000" queries/mesh-descriptors.rq \
  | csvformat | tail -n +2 >> $DIR/mesh-descriptors.csv
