#!/bin/bash
# Deploy (or validate/what-if) a Sentinel playbook ARM template.
# Usage: deploy-playbook.sh <path-to-any-file-in-playbook-folder> <resourceGroup> [validate|whatif|delete]
set -euo pipefail
FILE=$1; RG=$2; MODE=${3:-deploy}

PLAYBOOK_DIR=$(dirname "$FILE")
TEMPLATE="${PLAYBOOK_DIR}/azuredeploy.json"
PARAMS="${PLAYBOOK_DIR}/azuredeploy.parameters.json"
DEPLOY_NAME="playbook-$(basename "$PLAYBOOK_DIR")-$(date +%s)"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "No azuredeploy.json found in $PLAYBOOK_DIR, skipping."
  exit 0
fi

PARAM_ARGS=()
if [[ -f "$PARAMS" ]]; then
  PARAM_ARGS=(--parameters @"$PARAMS")
fi

if [[ "$MODE" == "delete" ]]; then
  PLAYBOOK_NAME=$(jq -r '.parameters.PlaybookName.value // empty' "$PARAMS" 2>/dev/null)
  [[ -z "$PLAYBOOK_NAME" ]] && PLAYBOOK_NAME=$(basename "$PLAYBOOK_DIR")
  echo "Deleting playbook '$PLAYBOOK_NAME' from resource group '$RG'..."
  az logic workflow delete --resource-group "$RG" --name "$PLAYBOOK_NAME" --yes || echo "Playbook may already be absent, continuing."
  exit 0
fi

if [[ "$MODE" == "validate" ]]; then
  echo "Validating $TEMPLATE against $RG..."
  az deployment group validate --resource-group "$RG" --template-file "$TEMPLATE" "${PARAM_ARGS[@]}"
  exit 0
fi

if [[ "$MODE" == "whatif" ]]; then
  echo "Running what-if for $TEMPLATE against $RG..."
  az deployment group what-if --resource-group "$RG" --template-file "$TEMPLATE" "${PARAM_ARGS[@]}"
  exit 0
fi

echo "Deploying playbook from $TEMPLATE to $RG..."
az deployment group create \
  --name "$DEPLOY_NAME" \
  --resource-group "$RG" \
  --template-file "$TEMPLATE" \
  "${PARAM_ARGS[@]}"
echo "Done: $PLAYBOOK_DIR"
