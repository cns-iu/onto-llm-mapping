#!/bin/bash
source constants.sh
shopt -s extglob
set -ev

DIR=$RAW_DIR/$DATASET/$VERSION
OUT=$OUTPUT_DIR/$DATASET/$VERSION

mkdir -p $OUT/mappings

cp -r $DIR/mappings/* $OUT/mappings/

# Zip up files > 95MB
for file in `find $OUT -name "*.*" -size +95M`; do
  zip -j ${file}.zip $file
  rm $file
done

CREATION_DATE=$(date)
echo "$CREATION_DATE" > $OUT/CREATION_DATE
