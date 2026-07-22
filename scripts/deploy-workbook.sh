#!/bin/bash
# Deploy or delete a Sentinel/Azure Monitor workbook, idempotently via a
# stable GUID stored in the matching <name>.meta.json file.
# Usage: deploy-workbook.sh <workbook-json-file> <resourceGroup> [delete]
set -euo pipefail
FILE=$1; RG=$2; ACTION=${3:-deploy}

METAFILE="${FILE%.json}.meta.json"
if [[ ! -f "$METAFILE" ]]; then
  echo "ERROR: expected metadata file at $METAFILE (must contain a stable workbookId GUID), not found."
  exit 1
fi

SUB_ID=$(az account show --query id -o tsv)
WORKBOOK_ID=$(jq -r '.workbookId' "$METAFILE")
DISPLAY_NAME=$(jq -r '.displayName' "$METAFILE")
CATEGORY=$(jq -r '.category' "$METAFILE")
API_VERSION="2023-06-01"
URL="https://management.azure.com/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.Insights/workbooks/${WORKBOOK_ID}?api-version=${API_VERSION}"

if [[ "$ACTION" == "delete" ]]; then
  echo "Deleting workbook '$DISPLAY_NAME' ($WORKBOOK_ID) from '$RG'..."
  az rest --method delete --url "$URL" || echo "Workbook may already be absent, continuing."
  exit 0
fi

echo "Deploying workbook '$DISPLAY_NAME' ($WORKBOOK_ID) to '$RG'..."
SERIALIZED_DATA=$(jq -Rs . < "$FILE")
BODY=$(jq -n \
  --arg name "$WORKBOOK_ID" \
  --arg displayName "$DISPLAY_NAME" \
  --arg category "$CATEGORY" \
  --arg location "$(az group show -n "$RG" --query location -o tsv)" \
  --argjson serializedData "$SERIALIZED_DATA" \
  '{
    location: $location,
    kind: "shared",
    properties: {
      displayName: $displayName,
      category: $category,
      sourceId: "azure monitor",
      serializedData: $serializedData
    }
  }')

az rest --method put --url "$URL" --body "$BODY"
echo "Done: $DISPLAY_NAME"
