#!/bin/bash
# Removes all Sentinel content this pipeline deployed for a customer.
# Does NOT and cannot revoke Lighthouse delegation - that must be done by the
# customer (or by you, if they've delegated that specific permission) per
# docs/OFFBOARDING.md. This script only cleans up content.
#
# Usage: offboard-customer.sh <customer>
set -euo pipefail
CUSTOMER=$1
SKIP_CONFIRM=${2:-}
BASE="customers/${CUSTOMER}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$BASE/config.json" ]]; then
  echo "::error::No config.json for customer '$CUSTOMER', aborting."
  exit 1
fi

RG=$(jq -r .resourceGroup "$BASE/config.json")
WS=$(jq -r .workspaceName "$BASE/config.json")

echo "Offboarding '$CUSTOMER' - removing deployed content from $RG / $WS"
echo "This does NOT delete the resource group or workspace itself."

if [[ "$SKIP_CONFIRM" != "--yes" ]]; then
  read -p "Type the customer name to confirm: " CONFIRM
  if [[ "$CONFIRM" != "$CUSTOMER" ]]; then
    echo "Confirmation did not match, aborting."
    exit 1
  fi
fi

for f in "$BASE"/AnalyticsRules/*.json; do
  [[ -e "$f" ]] && bash "$SCRIPT_DIR/deploy-analytics-rule.sh" "$f" "$RG" "$WS" delete
done
for f in "$BASE"/AutomationRules/*.json; do
  [[ -e "$f" ]] && bash "$SCRIPT_DIR/deploy-automation-rule.sh" "$f" "$RG" "$WS" delete
done
for d in "$BASE"/Playbooks/*/; do
  [[ -e "${d}azuredeploy.json" ]] && bash "$SCRIPT_DIR/deploy-playbook.sh" "${d}azuredeploy.json" "$RG" delete
done
for f in "$BASE"/Watchlists/*.json; do
  [[ -e "$f" ]] && bash "$SCRIPT_DIR/deploy-watchlist.sh" "$f" "$RG" "$WS" delete
done
for f in "$BASE"/Workbooks/*.json; do
  [[ "$f" == *.meta.json ]] && continue
  [[ -e "$f" ]] && bash "$SCRIPT_DIR/deploy-workbook.sh" "$f" "$RG" delete
done

echo ""
echo "Content removed. Remaining manual steps (see docs/OFFBOARDING.md):"
echo "  1. Ask the customer to delete the Lighthouse registration assignment in their subscription."
echo "  2. Remove the '${CUSTOMER}' GitHub Environment (Settings -> Environments)."
echo "  3. Archive customers/${CUSTOMER}/ in a final commit rather than deleting it outright, for audit history."
