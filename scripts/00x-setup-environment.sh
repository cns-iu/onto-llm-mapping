#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Base paths

DIR="${0%/*}"
ROOT_DIR="$DIR/.."

# Parse arguments

ENV=${1:-.venv}
if [[ ! "$ENV" = /* ]]; then ENV="$ROOT_DIR/$ENV"; fi

if [ ! -e "$ENV/bin/activate" ]; then
  python3 -m venv $ENV
fi

# Detect OS, from https://stackoverflow.com/a/3466183
unameOut="$(uname -s)"
case "${unameOut}" in
  Linux*)     machine=Linux;;
  Darwin*)    machine=Mac;;
  CYGWIN*)    machine=Cygwin;;
  MINGW*)     machine=MinGw;;
  *)          machine="UNKNOWN:${unameOut}"
esac

# Install dependencies
if [ -e "$ENV/bin/activate" ]; then
  set +u # Disable in case we are running old venv versions that can't handle strict mode
  source "$ENV/bin/activate"
  set -u

  # Install python deps
  python -m pip install -r "$ROOT_DIR/requirements.txt"
  python -m pip cache purge

  # Install node (latest LTS version)
  if [ ! -e "$ENV/bin/node" ]; then
    nodeenv --python-virtualenv --node lts
  fi

  # Install node deps
  npm ci
  # npm install -g ${ROOT_DIR}

  if [ ! -e "$ENV/bin/duckdb" ]; then
    wget -nv https://github.com/duckdb/duckdb/releases/download/v1.0.0/duckdb_cli-linux-amd64.zip &&
      unzip -qq duckdb_cli-linux-amd64.zip duckdb &&
      mv duckdb $ENV/bin/duckdb &&
      rm -f duckdb_cli-linux-amd64.zip
  fi

  if [ ! -e "$ENV/bin/ollama" ]; then
    wget -nv https://ollama.com/download/ollama-linux-amd64.tgz &&
      tar -C $ENV -xzf ollama-linux-amd64.tgz &&
      rm -f ollama-linux-amd64.tgz
  fi

  llm install llm-gpt4all llm-ollama llm-sentence-transformers

  llm sentence-transformers register all-mpnet-base-v2

  # Setup templates
  cp ${ROOT_DIR}/templates/*.yaml `llm templates path`
fi

if [ -e "$ENV/bin/activate" ]; then
  set +u # Just to be on the safe side
  deactivate
  set -u
fi
