#!/bin/bash
source constants.sh
shopt -s extglob
set -e

# Setup parameters
WORKFLOW=desc-vec
export EMBED_MODEL=sentence-transformers/all-mpnet-base-v2

# Setup directories and their variables
DIR=$RAW_DIR/$DATASET/$VERSION/$WORKFLOW
MAPPINGS=$RAW_DIR/$DATASET/$VERSION/mappings
SSSOM_BASE=$MAPPINGS/${DATASET}-mapping.${WORKFLOW}
mkdir -p $DIR $MAPPINGS

## Create descriptions from raw data, no LLM
node src/create-descriptions.js $SOURCE_TERMS $DIR/source.content.csv
node src/create-descriptions.js $TARGET_TERMS $DIR/target.content.csv

## Find similar terms using vectorized versions of expanded content
time node src/find-similar.js $DIR/source.content.csv $DIR/target.content.csv $DIR/vec-scores.csv

## Compile results to SSSOM format
./src/create-sssom-scored.sh $SOURCE_TERMS $TARGET_TERMS $DIR/vec-scores.csv ${SSSOM_BASE}.sssom.csv

## Validate SSSOM files
sssom validate ${SSSOM_BASE}.sssom.csv
