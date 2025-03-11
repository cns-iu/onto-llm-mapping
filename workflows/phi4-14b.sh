#!/bin/bash
source constants.sh
shopt -s extglob
set -e

# Setup parameters
WORKFLOW=phi4-14b
export LLM_MODEL=phi4:14b
export LLM_MODEL_OPTS="-o num_predict 384" # gets added to the LLM command in expand and rank
export LLM_EXPAND_TEMPLATE="term-description"
export LLM_RANK_TEMPLATE="rank-similar"
export EMBED_MODEL=sentence-transformers/all-mpnet-base-v2

# Setup directories and their variables
DIR=$RAW_DIR/$DATASET/$VERSION/$WORKFLOW
MAPPINGS=$RAW_DIR/$DATASET/$VERSION/mappings
SSSOM_BASE=$MAPPINGS/${DATASET}-mapping.${WORKFLOW}
mkdir -p $DIR $MAPPINGS

## Use an LLM to create an expanded description
time node src/expand-descriptions.js $SOURCE_TERMS $DIR/source.content.csv &
time node src/expand-descriptions.js $TARGET_TERMS $DIR/target.content.csv &
wait

## Create embeddings of source and target content
./src/create-embeddings.sh $DIR/source.content.csv $DIR/source.content.csv.db &
./src/create-embeddings.sh $DIR/target.content.csv $DIR/target.content.csv.db &
wait

## Find similar terms using vectorized versions of content
time node src/parallel-find-similar.js $DIR/source.content.csv.db $DIR/target.content.csv.db $DIR/vec-scores.csv

## Compile results to SSSOM format
./src/create-sssom-scored.sh $SOURCE_TERMS $TARGET_TERMS $DIR/vec-scores.csv ${SSSOM_BASE}.llm-vec.sssom.csv

## Validate SSSOM files
sssom validate ${SSSOM_BASE}.llm-vec.sssom.csv
