DEFAULT_CONFIG=input-data/uberon-mesh/v0.0.1/config.sh
DEFAULT_WORKFLOWS=""

INPUT_DIR="./input-data"
OUTPUT_DIR="./output-data"
RAW_DIR="./raw-data"

export PATH=./node_modules/.bin:${PATH}
export CONFIG=${CONFIG:=$DEFAULT_CONFIG}
export WORKFLOWS=${WORKFLOWS:=$DEFAULT_WORKFLOWS}

source $CONFIG

mkdir -p $RAW_DIR/$DATASET/$VERSION
mkdir -p $INPUT_DIR/$DATASET/$VERSION
mkdir -p $OUTPUT_DIR/$DATASET/$VERSION

JAVA_OPTS="-Xms2g -Xmx64g"
export NODE_OPTIONS="--max-old-space-size=60480"
