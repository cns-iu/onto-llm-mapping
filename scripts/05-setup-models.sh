#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if [ "$(pgrep -x ollama)" == "" ]; then 
  echo "Please start OLLAMA (ollama serve) in a separate shell before running the workflow"
  exit -1 
fi

llm -m Meta-Llama-3 'Welcome to the Matrix' # serverless llama3.1:8b
ollama pull llama3.1:8b
ollama pull llama3.2:3b
ollama pull llama3.2:1b

llm sentence-transformers register all-mpnet-base-v2
