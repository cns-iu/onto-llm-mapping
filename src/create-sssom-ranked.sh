#!/bin/bash

export SOURCE=$1
export TARGET=$2
export SCORES=$3
export OUTPUT=$4

duckdb :memory: -no-stdin -init queries/sssom-ranked.sql | csvformat > $OUTPUT
