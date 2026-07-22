#!/bin/bash
# Fails closed if the subscription in a customer's config.json doesn't match
# reality - either the wrong tenant, or not actually delegated via Lighthouse
# to this MSSP tenant. Run this AFTER az login, BEFORE any deploy script.
#
# Usage: verify-tenant-scope.sh <customerConfigJson> <mspManagementTenantId>
set -euo pipefail
CFG=$1; MSP_TENANT_ID=$2

EXPECTED_TENANT=$(jq -r '.tenantId' "$CFG")
EXPECTED_SUB=$(jq -r '.subscriptionId' "$CFG")
CUSTOMER=$(jq -r '.customerName' "$CFG")

echo "Verifying tenant scope for customer '$CUSTOMER'..."

ACTUAL_TENANT=$(az account show --subscription "$EXPECTED_SUB" --query tenantId -o tsv 2>/dev/null) || {
  echo "::error::Could not resolve subscription $EXPECTED_SUB - not visible to this identity at all. Aborting."
  exit 1
}

if [[ "$ACTUAL_TENANT" != "$EXPECTED_TENANT" ]]; then
  echo "::error::Tenant mismatch for '$CUSTOMER'. config.json says tenant $EXPECTED_TENANT, but subscription $EXPECTED_SUB actually belongs to tenant $ACTUAL_TENANT. Refusing to deploy - this would be a cross-tenant deployment."
  exit 1
fi

MANAGED_BY=$(az account show --subscription "$EXPECTED_SUB" --query "managedByTenants[].tenantId" -o tsv 2>/dev/null || echo "")
if ! echo "$MANAGED_BY" | grep -qi "$MSP_TENANT_ID"; then
  echo "::error::Subscription $EXPECTED_SUB is not Lighthouse-delegated to management tenant $MSP_TENANT_ID (managedByTenants: [$MANAGED_BY]). This identity may have access for an unrelated/unexpected reason. Refusing to deploy."
  exit 1
fi

echo "OK: '$CUSTOMER' -> subscription $EXPECTED_SUB confirmed in tenant $EXPECTED_TENANT, delegated to MSSP tenant $MSP_TENANT_ID."
