#!/bin/bash
# Deploy or delete a Sentinel analytics rule.
# Usage: deploy-analytics-rule.sh <file> <resourceGroup> <workspaceName> [delete]
set -euo pipefail
FILE=$1; RG=$2; WS=$3; ACTION=${4:-deploy}

SUB_ID=$(az account show --query id -o tsv)
RULE_ID=$(basename "$FILE" .json)
API_VERSION="2023-11-01"
URL="https://management.azure.com/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.OperationalInsights/workspaces/${WS}/providers/Microsoft.SecurityInsights/alertRules/${RULE_ID}?api-version=${API_VERSION}"

if [[ "$ACTION" == "delete" ]]; then
  echo "Deleting analytics rule '$RULE_ID' from workspace '$WS'..."
  az rest --method delete --url "$URL" || echo "Rule may already be absent, continuing."
  exit 0
fi

echo "Deploying analytics rule '$RULE_ID' to workspace '$WS'..."
TMP_BODY=$(mktemp)
jq --arg name "$RULE_ID" '.name = $name' "$FILE" > "$TMP_BODY"
az rest --method put --url "$URL" --body @"$TMP_BODY"
rm -f "$TMP_BODY"
echo "Done: $RULE_ID"
