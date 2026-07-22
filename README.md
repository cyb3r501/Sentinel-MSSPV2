# Ms-sentinel — MSSP Multi-Customer Sentinel-as-Code

Precision CI/CD for Microsoft Sentinel content (analytics rules, automation
rules, playbooks, watchlists, workbooks) across multiple customer
subscriptions/tenants, built for an MSSP operating model.

A change to a file under `customers/<customer>/...` deploys **only** to that
customer's workspace. A change to `shared/...` fans out only to customers who
explicitly subscribe to it, merged with any customer-specific override.

## Repo structure

```
Ms-sentinel/
├── .github/
│   ├── CODEOWNERS                  # scopes PR review per customer
│   └── workflows/
│       ├── deploy-sentinel.yml     # push-to-main -> precise per-customer deploy
│       ├── validate-pr.yml         # PR gate: JSON checks + what-if, no deploys
│       ├── promote-to-customers.yml# canary/shared -> real customers, via PR
│       ├── offboard-customer.yml   # gated content removal on contract end
│       └── reporting.yml           # weekly compliance report regeneration
├── customers/
│   ├── _template/                  # copy this to onboard a new customer
│   ├── _canary/                    # your own lab tenant - burn-in ground, deploys like a real target
│   └── contoso/                    # example customer
│       ├── config.json             # subscriptionId / resourceGroup / workspaceName / tenantId
│       ├── subscriptions.json      # which shared/ baseline content this customer inherits/overrides
│       ├── lighthouse/             # delegation ARM template the CUSTOMER runs to grant you access
│       ├── AnalyticsRules/
│       │   └── overrides/          # customer-specific tweaks to shared baseline rules
│       ├── AutomationRules/
│       ├── Playbooks/<name>/       # azuredeploy.json + azuredeploy.parameters.json
│       ├── Watchlists/             # <name>.json (metadata) + <name>.csv (data)
│       └── Workbooks/              # <name>.json + <name>.meta.json (stable GUID for idempotent redeploy)
├── shared/AnalyticsRules/          # baseline content, keyed by contentId, rolled out via subscriptions.json
├── scripts/                        # deploy, delete, rollback, offboard, verify, report, notify
├── reports/<customer>/             # auto-generated compliance/deployment history (git-log derived)
└── docs/
    ├── LIGHTHOUSE-ONBOARDING.md
    ├── CHANGE-MANAGEMENT.md
    ├── OFFBOARDING.md
    └── SECRET-ROTATION.md
```

## MSSP architecture summary

**Identity**: one MSSP service principal (OIDC, no stored secrets), delegated
into every customer subscription via **Azure Lighthouse** — not one app
registration per customer. See `docs/LIGHTHOUSE-ONBOARDING.md`.

**Tenant boundary enforcement**: before any deploy, `scripts/verify-tenant-scope.sh`
confirms the subscription in `config.json` actually belongs to the declared
tenant *and* is genuinely Lighthouse-delegated to your management tenant —
not just accessible for some coincidental other reason. A config typo fails
closed instead of silently deploying cross-tenant.

**Shared baseline + per-customer overrides**: `shared/AnalyticsRules/*.json`
holds baseline content keyed by a stable `contentId`. Each customer's
`subscriptions.json` declares `inherit` (as-is) or `override` (merged with a
file in `AnalyticsRules/overrides/`). `scripts/build-effective-content.py`
resolves these into deployable `.effective/` files at deploy time — nothing
copy-pasted, nothing silently drifted. Changing the shared baseline
automatically redeploys to every subscribed customer.

**Canary tier**: `customers/_canary/` points at your own lab tenant and
deploys through the exact same pipeline as a real customer. New content goes
here first, burns in, then moves to real customers via
`promote-to-customers.yml` — which opens a PR (with burn-in evidence in the
description) rather than deploying directly. See `docs/CHANGE-MANAGEMENT.md`.

**Failure alerting**: every deploy job posts to Teams/Slack on failure via
`scripts/notify-failure.sh`, using `TEAMS_WEBHOOK_URL`/`SLACK_WEBHOOK_URL`
repo secrets.

**Compliance reporting**: `reporting.yml` runs weekly (and on demand),
regenerating `reports/<customer>/deployment-log.md` from git history per
content type — evidence of what was deployed and when, per customer.

**Review scoping**: `.github/CODEOWNERS` ensures only the engineer(s)
responsible for a given customer (or shared content, or the pipeline itself)
can approve changes to it.

**Rollback**: `scripts/rollback.sh <customer> <content_type> <file> <git_ref>`
redeploys a prior version of a single file immediately, independent of a full
git revert, for analytics/automation rules. Playbooks/watchlists/workbooks
need their paired files restored together — the script tells you the exact
`git checkout` command.

**Offboarding**: `offboard-customer.yml` (gated by that customer's GitHub
Environment reviewers) removes all pipeline-deployed content. It does **not**
revoke Lighthouse delegation — that's the customer's action, documented in
`docs/OFFBOARDING.md`.

**Secret rotation**: centralized because of the single-identity Lighthouse
model — revoking one federated credential kills pipeline access to every
customer at once if compromised. See `docs/SECRET-ROTATION.md`.

## Onboarding a new customer

1. Copy `customers/_template/` → `customers/<new-customer>/`.
2. Fill in `config.json` (subscriptionId / resourceGroup / workspaceName /
   tenantId).
3. Fill in `lighthouse/delegation.parameters.json` with your MSSP tenant ID
   and service principal Object ID (same one for every customer). Send the
   customer `lighthouse/delegation.json` + `.parameters.json` — **they** run
   the deployment against their own subscription; see
   `docs/LIGHTHOUSE-ONBOARDING.md` for the exact commands.
4. Create a GitHub Environment named exactly `<new-customer>` (for approval
   gating only — no per-customer secrets needed with Lighthouse). Add
   required reviewers if this customer needs deploy approval.
5. Optionally add `subscriptions.json` if this customer should inherit any
   `shared/` baseline content.
6. Commit content — the workflow picks it up automatically, no workflow file
   edits required.

## Repo-level secrets to configure once

- `AZURE_CLIENT_ID` — the MSSP service principal's client ID
- `AZURE_TENANT_ID` — your MSSP management tenant ID
- `TEAMS_WEBHOOK_URL` and/or `SLACK_WEBHOOK_URL` — for failure alerts
  (optional but recommended)

## Testing before touching a real customer

- Push changes to `customers/_canary/` first — it deploys through the same
  pipeline as any real customer, into your own lab tenant.
- `workflow_dispatch` on `deploy-sentinel.yml` with a `customer` input forces
  a full redeploy of one customer on demand.
- Every PR against `main` runs `validate-pr.yml` (JSON/CSV syntax + Azure
  what-if for playbooks) before merge is even possible.
