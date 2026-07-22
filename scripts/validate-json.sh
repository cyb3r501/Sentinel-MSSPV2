#!/bin/bash
# Basic sanity validation for changed content files before they're allowed to merge.
# Usage: validate-json.sh <file>
set -euo pipefail
FILE=$1

if [[ "$FILE" == *.json ]]; then
  echo "Checking JSON syntax: $FILE"
  jq empty "$FILE"
  echo "OK: valid JSON"
elif [[ "$FILE" == *.csv ]]; then
  echo "Checking CSV has a header + at least one data row: $FILE"
  LINES=$(wc -l < "$FILE")
  if [[ "$LINES" -lt 2 ]]; then
    echo "ERROR: CSV must have a header row plus at least one data row."
    exit 1
  fi
  echo "OK: CSV looks structurally valid"
else
  echo "No validator for file type of $FILE, skipping."
fi
