#!/bin/bash
# Usage: notify-failure.sh <customer> <content_type> <file> <run_url>
# Requires TEAMS_WEBHOOK_URL or SLACK_WEBHOOK_URL as an environment variable
# (set from a repo secret in the workflow - never commit the webhook URL itself).
set -euo pipefail
CUSTOMER=$1; CONTENT_TYPE=$2; FILE=$3; RUN_URL=$4

if [[ -n "${TEAMS_WEBHOOK_URL:-}" ]]; then
  curl -sf -H "Content-Type: application/json" -d @- "$TEAMS_WEBHOOK_URL" <<EOF
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "D40000",
  "title": "Sentinel deploy FAILED - ${CUSTOMER}",
  "text": "**Customer:** ${CUSTOMER}\n\n**Content type:** ${CONTENT_TYPE}\n\n**File:** ${FILE}\n\n**Run:** [${RUN_URL}](${RUN_URL})"
}
EOF
fi

if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
  curl -sf -H "Content-Type: application/json" -d @- "$SLACK_WEBHOOK_URL" <<EOF
{
  "text": ":rotating_light: Sentinel deploy FAILED for *${CUSTOMER}* — ${CONTENT_TYPE} (${FILE}). <${RUN_URL}|View run>"
}
EOF
fi

if [[ -z "${TEAMS_WEBHOOK_URL:-}" && -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  echo "::warning::No TEAMS_WEBHOOK_URL or SLACK_WEBHOOK_URL configured - failure for ${CUSTOMER}/${CONTENT_TYPE}/${FILE} was not externally notified."
fi
