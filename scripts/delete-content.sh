#!/bin/bash
# Routes a deleted file to the correct script's delete mode.
# Usage: delete-content.sh <content_type> <file> <resourceGroup> <workspaceName>
set -euo pipefail
CONTENT_TYPE=$1; FILE=$2; RG=$3; WS=$4
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$CONTENT_TYPE" in
  AnalyticsRules)
    bash "$SCRIPT_DIR/deploy-analytics-rule.sh" "$FILE" "$RG" "$WS" delete
    ;;
  AutomationRules)
    bash "$SCRIPT_DIR/deploy-automation-rule.sh" "$FILE" "$RG" "$WS" delete
    ;;
  Playbooks)
    bash "$SCRIPT_DIR/deploy-playbook.sh" "$FILE" "$RG" delete
    ;;
  Watchlists)
    # Only act once per watchlist (metadata json triggers it; csv-only changes are ignored here)
    if [[ "$FILE" == *.json ]]; then
      bash "$SCRIPT_DIR/deploy-watchlist.sh" "$FILE" "$RG" "$WS" delete
    fi
    ;;
  Workbooks)
    if [[ "$FILE" == *.json && "$FILE" != *.meta.json ]]; then
      bash "$SCRIPT_DIR/deploy-workbook.sh" "$FILE" "$RG" delete
    fi
    ;;
  *)
    echo "Unknown content type '$CONTENT_TYPE' for deletion, skipping."
    ;;
esac
