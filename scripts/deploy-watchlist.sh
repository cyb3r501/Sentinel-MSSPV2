#!/bin/bash
# Deploy or delete a Sentinel watchlist (metadata JSON + CSV pair).
# Usage: deploy-watchlist.sh <metadata-json-file> <resourceGroup> <workspaceName> [delete]
set -euo pipefail
METAFILE=$1; RG=$2; WS=$3; ACTION=${4:-deploy}

SUB_ID=$(az account show --query id -o tsv)
NAME=$(jq -r '.name' "$METAFILE")
API_VERSION="2023-11-01"
URL="https://management.azure.com/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.OperationalInsights/workspaces/${WS}/providers/Microsoft.SecurityInsights/watchlists/${NAME}?api-version=${API_VERSION}"

if [[ "$ACTION" == "delete" ]]; then
  echo "Deleting watchlist '$NAME' from workspace '$WS'..."
  az rest --method delete --url "$URL" || echo "Watchlist may already be absent, continuing."
  exit 0
fi

CSVFILE="${METAFILE%.json}.csv"
if [[ ! -f "$CSVFILE" ]]; then
  echo "ERROR: expected CSV data file at $CSVFILE, not found."
  exit 1
fi

echo "Deploying watchlist '$NAME' to workspace '$WS'..."
RAW_CONTENT=$(jq -Rs . < "$CSVFILE")
BODY=$(jq -n \
  --argjson meta "$(cat "$METAFILE")" \
  --argjson content "$RAW_CONTENT" \
  '$meta + {"properties": ($meta.properties + {"rawContent": $content})}')

az rest --method put --url "$URL" --body "$BODY"
echo "Done: $NAME"
