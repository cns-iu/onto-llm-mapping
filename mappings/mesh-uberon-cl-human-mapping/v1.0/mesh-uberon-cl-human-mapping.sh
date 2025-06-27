#!/bin/bash

# Clean up the raw data
# grep -v ",,,,," mesh-uberon-cl-human-mapping.sssom.csv | csvcut -C accuracy > mesh-uberon-cl-human-mapping.fixed.sssom.csv

# Combine metadata and data into a final sssom.tsv file
sssom parse -m mesh-uberon-cl-human-mapping.sssom.yml -I tsv -o mesh-uberon-cl-human-mapping.sssom.tsv mesh-uberon-cl-human-mapping.sssom.csv

# Validate the sssom.tsv file
sssom validate mesh-uberon-cl-human-mapping.sssom.tsv

# Convert to RDF/turtle
sssom convert mesh-uberon-cl-human-mapping.sssom.tsv -O owl -o mesh-uberon-cl-human-mapping.sssom.ttl
