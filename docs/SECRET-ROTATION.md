# Secret / Credential Rotation

Because this pipeline uses **one MSSP identity via Lighthouse + OIDC**
(no client secrets, no per-customer app registrations), rotation is
centralized — this is one of the main payoffs of the Lighthouse model.

## Routine rotation (no compromise suspected)

OIDC federated credentials don't expire the way client secrets do, so there's
no forced rotation calendar. Still, review annually:

1. Azure AD → App registrations → your MSSP deploy identity → Certificates &
   secrets → Federated credentials. Confirm the subject still matches
   `repo:cyb3r501/Ms-sentinel:ref:refs/heads/main` (and hasn't drifted if the
   repo was renamed/transferred).
2. Confirm the app's role assignments in each customer's Lighthouse
   delegation are still least-privilege (Sentinel Contributor + Logic App
   Contributor only) — `az role assignment list` per delegated subscription.

## If the MSSP identity is suspected compromised

This is higher-severity than a single customer breach — a compromised MSSP
identity has delegated access to **every** customer via Lighthouse.

1. **Immediately** delete the federated credential in Azure AD (App
   registrations → Certificates & secrets → Federated credentials → Delete).
   This kills the pipeline's ability to authenticate anywhere, instantly,
   without needing to touch each customer individually.
2. Disable the app registration entirely if there's any doubt.
3. Audit sign-in logs for that service principal across the management
   tenant for the suspected compromise window.
4. Create a **new** app registration and federated credential, update the
   repo secrets (`AZURE_CLIENT_ID`), and re-verify each customer's Lighthouse
   `authorizations[].principalId` points at the new service principal's
   Object ID — old delegations reference the old principal ID and won't
   automatically pick up a new one.
5. Notify affected customers per your incident response / contractual
   disclosure obligations before resuming deployments.

## Per-customer secret exposure (rare under this model)

If you're still running the older per-customer-app-registration model for
some customers (not yet migrated to Lighthouse), rotating one customer's
credential doesn't affect others — delete that customer's federated
credential, issue a new one, update only that customer's GitHub Environment
secrets. This isolation is the main argument for finishing the Lighthouse
migration for every customer, not leaving some on the old model.
