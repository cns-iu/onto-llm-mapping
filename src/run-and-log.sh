#!/bin/bash
source constants.sh

RUN=$1
LOG=$2

time bash -c "time ${RUN} 2>&1" | tee $LOG
