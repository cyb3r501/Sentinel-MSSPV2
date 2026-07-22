# Customer Offboarding Runbook

## When a contract ends

1. **Run the offboarding workflow**: Actions → "Offboard Customer" →
   `workflow_dispatch` with the customer name. This requires approval if
   you've set required reviewers on that customer's GitHub Environment
   (recommended - offboarding is destructive).
2. This removes all Sentinel content the pipeline deployed (analytics rules,
   automation rules, playbooks, watchlists, workbooks) from the customer's
   workspace. It does **not** delete the resource group, workspace, or any
   raw log data — that's the customer's decision, not this pipeline's.
3. **Ask the customer to revoke Lighthouse delegation** themselves:
   Azure portal → Service providers → find your MSSP offer → Remove.
   This is the actual access-revocation step — do not skip it, and don't
   assume removing GitHub secrets alone revokes their subscription access.
4. **Delete the GitHub Environment** for that customer (Settings →
   Environments) so no future workflow run can accidentally target them.
5. **Archive, don't delete, `customers/<name>/`** — commit its removal in
   a single clearly-labeled commit rather than force-deleting history. You
   want to be able to prove what was deployed and when even after offboarding,
   for compliance/contract-dispute purposes. `reports/<name>/deployment-log.md`
   is your evidence trail; keep it.

## If offboarding is involuntary / adversarial (e.g. disputed contract)

Treat it like credential compromise — see rotation steps below — because you
can no longer assume the customer will cooperate on step 3. Escalate directly
with Microsoft support to force-remove the Lighthouse delegation if the
customer won't.
