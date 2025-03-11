#!/bin/bash

INPUT=$1
OUTPUT=$2
DEFAULT_EMBED_MODEL=sentence-transformers/all-mpnet-base-v2
EMBED_MODEL=${EMBED_MODEL:=$DEFAULT_EMBED_MODEL}

rm -f $OUTPUT
csvformat -T $INPUT | llm embed-multi --format tsv -m $EMBED_MODEL -d $OUTPUT items -
