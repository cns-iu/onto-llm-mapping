#!/bin/bash
source constants.sh

LOG=$OUTPUT_DIR/$DATASET/$VERSION/log.txt
rm -r $OUTPUT_DIR/$DATASET/$VERSION/*
rm -rf $RAW_DIR/$DATASET/$VERSION/*

time bash -c "time ./run.sh 2>&1" | tee $LOG
