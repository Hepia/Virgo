#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <repo_directory>"
  exit 1
fi

REPO_DIR="$1"

cd "$REPO_DIR" || { echo "Directory $REPO_DIR not found"; exit 1; }

FILE="attack_tcp.c"

declare -A lines_vars=(
  ["389"]="struct iphdr *iph = NULL;"
  ["390"]="struct tcphdr *tcph = NULL;"
  ["391"]="char *payload = NULL;"
)

if [ ! -f "$FILE" ]; then
  echo "File $FILE not found in $REPO_DIR"
  exit 1
fi

for LINE in "${!lines_vars[@]}"; do
  line_content=$(sed -n "${LINE}p" "$FILE")

  # Check if variable is already initialized
  if [[ "${line_content}" == *"= NULL"* ]]; then
    echo "Line $LINE already initialized."
    continue
  fi

  # Replace the entire line with the initialized variable declaration
  sed -i "${LINE}s/.*/${lines_vars[$LINE]}/" "$FILE"
  echo "Line $LINE updated: ${lines_vars[$LINE]}"
done
