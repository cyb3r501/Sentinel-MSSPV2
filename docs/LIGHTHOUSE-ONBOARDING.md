# Azure Lighthouse Onboarding (per new customer)

Lighthouse replaces "one app registration per customer" with **one MSSP
identity, delegated into every customer subscription**. Do this once per
customer; after that, the same GitHub Actions identity deploys everywhere.

## One-time MSSP-side setup (do this once, not per customer)

1. Create a single Azure AD app registration in your **management tenant**
   (e.g. `MS-Sentinel-Deploy-Automation`).
2. Add a federated credential trusting this GitHub repo:
   `repo:cyb3r501/Ms-sentinel:ref:refs/heads/main` (and one for
   `pull_request` if you want PR validation to also authenticate).
3. Note the app's **Object ID** (of the service principal, not the app
   registration) — this goes into every customer's `delegation.parameters.json`.
4. Store `AZURE_CLIENT_ID` and `AZURE_TENANT_ID` (your management tenant) as
   **repository-level secrets** — not per-customer. This identity is shared;
   what's per-customer is the delegated *subscription*, not the credential.

## Per-customer onboarding

1. Copy `customers/_template/` → `customers/<new-customer>/`, fill in
   `config.json`.
2. Fill in `customers/<new-customer>/lighthouse/delegation.parameters.json`:
   - `managedByTenantId` = your management tenant ID
   - `authorizations[].principalId` = the MSSP service principal Object ID
     from step 3 above
   - **Verify the role definition IDs before use** — run
     `az role definition list --name "Microsoft Sentinel Contributor"` and
     `az role definition list --name "Logic App Contributor"` in a
     subscription you control and confirm the GUIDs match what's in this
     template. Never grant `Owner` or subscription-scope `Contributor` for
     an MSSP delegation — least privilege only.
3. **The customer** (not you) runs the delegation deployment against their
   own subscription — this is what makes it a legitimate, auditable consent
   rather than something you granted yourself:
   ```
   az deployment sub create \
     --location eastus \
     --template-file customers/<new-customer>/lighthouse/delegation.json \
     --parameters customers/<new-customer>/lighthouse/delegation.parameters.json
   ```
4. Once deployed, the customer's subscription shows up under
   **Azure portal → My customers** in your management tenant. Confirm with:
   ```
   az account list --query "[?tenantId=='<managementTenantId>']" -o table
   ```
5. Add a GitHub **Environment** named `<new-customer>` (for approval gating
   only — it no longer needs its own secrets). Optionally require reviewers.

## Why this is safer than per-customer app registrations

- One identity to rotate, not N.
- Every delegation is scoped to exactly two roles (Sentinel Contributor,
  Logic App Contributor) — never subscription Owner/Contributor.
- The customer can revoke access unilaterally at any time by deleting the
  registration assignment in their own subscription, without needing you.
- `scripts/verify-tenant-scope.sh` (see below) checks that the subscription
  the pipeline is about to touch is *actually* Lighthouse-delegated to your
  tenant — not just accessible for some other reason — before any deploy runs.
