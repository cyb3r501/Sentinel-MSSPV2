#!/bin/bash
# Redeploys a file as it existed at a previous commit, without a full git
# revert - useful for a fast rollback of a single bad rule while you sort
# out the proper fix.
#
# Usage: rollback.sh <customer> <content_type> <file_path_in_repo> <git_ref>
# Example: rollback.sh contoso AnalyticsRules customers/contoso/AnalyticsRules/suspicious-signin-impossible-travel.json HEAD~1
set -euo pipefail
CUSTOMER=$1; CONTENT_TYPE=$2; FILE=$3; REF=$4
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CFG="customers/${CUSTOMER}/config.json"
RG=$(jq -r .resourceGroup "$CFG")
WS=$(jq -r .workspaceName "$CFG")

echo "Rolling back $FILE to state at $REF for customer '$CUSTOMER'..."
TMP=$(mktemp)
git show "${REF}:${FILE}" > "$TMP"

case "$CONTENT_TYPE" in
  AnalyticsRules)  bash "$SCRIPT_DIR/deploy-analytics-rule.sh"  "$TMP" "$RG" "$WS" ;;
  AutomationRules) bash "$SCRIPT_DIR/deploy-automation-rule.sh" "$TMP" "$RG" "$WS" ;;
  Watchlists)      echo "::error::Rollback for watchlists needs the matching CSV too - restore both files manually with 'git checkout <ref> -- <path>' and redeploy normally instead." ; exit 1 ;;
  Workbooks)       echo "::error::Rollback for workbooks needs the matching .meta.json too - restore both files manually and redeploy normally instead." ; exit 1 ;;
  Playbooks)       echo "::error::Rollback for playbooks - restore the whole folder with 'git checkout <ref> -- customers/${CUSTOMER}/Playbooks/<name>/' and redeploy normally instead." ; exit 1 ;;
  *) echo "::error::Unknown content type $CONTENT_TYPE" ; exit 1 ;;
esac

rm -f "$TMP"
echo "Rolled back. Remember to also revert the file in Git (git revert / git checkout + commit) so the repo stays the source of truth - this script only fixes the live workspace, not history."
