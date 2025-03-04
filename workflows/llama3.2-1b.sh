#!/bin/bash
source constants.sh
shopt -s extglob
set -e

# Setup parameters
WORKFLOW=llama3.2-1b
export LLM_MODEL=llama3.2:1b
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
time node src/expand-descriptions.js $SOURCE_TERMS $DIR/source.content.csv
time node src/expand-descriptions.js $TARGET_TERMS $DIR/target.content.csv

## Find similar terms using vectorized versions of expanded content
time node src/find-similar.js $DIR/source.content.csv $DIR/target.content.csv $DIR/vec-scores.csv

## Use an LLM to rank the similar terms from expanded content comparison
# time node ./src/rank-similar.js $SOURCE_TERMS $TARGET_TERMS $DIR/source.content.csv $DIR/target.content.csv $DIR/vec-scores.csv $DIR/ranked-vec-scores.csv

## Compile results to SSSOM format
./src/create-sssom-scored.sh $SOURCE_TERMS $TARGET_TERMS $DIR/vec-scores.csv ${SSSOM_BASE}.llm-vec.sssom.csv
# ./src/create-sssom-ranked.sh $SOURCE_TERMS $TARGET_TERMS $DIR/ranked-vec-scores.csv ${SSSOM_BASE}.llm-rank.sssom.csv

## Validate SSSOM files
sssom validate ${SSSOM_BASE}.llm-vec.sssom.csv
# sssom validate ${SSSOM_BASE}.llm-rank.sssom.csv
