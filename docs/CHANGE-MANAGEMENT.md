# Change Management

## New content lifecycle

1. Author new/changed content against `customers/_canary/` or `shared/` first.
2. Let it run in canary. Suggested minimum burn-in: **7 days** for analytics
   rules (matches Microsoft's own guidance on false-positive tuning before
   trusting a rule), **3 days** for playbooks/watchlists/workbooks.
3. Use **Promote Content to Customers** (`promote-to-customers.yml`) to open
   a PR moving it from canary/shared into the real customer folder(s). Include
   the burn-in evidence in the PR — false positive rate, incident count, etc.
4. Normal PR review + `validate-pr.yml` gate applies to the promotion PR like
   any other change.

## Change freeze windows

For customers with contractual change-freeze periods (e.g. retail during
peak season, finance during quarter-close), don't rely on memory:

- Add a `changeFreezeUntil` field to that customer's `config.json` (a date).
- Add a check at the top of the deploy job that reads it and fails the run
  with a clear message if `today < changeFreezeUntil` — this repo's deploy
  workflow doesn't enforce this by default yet; add it as a step in
  `deploy-sentinel.yml` before the Azure Login step once you have a customer
  who needs it, since the check needs real freeze dates to be meaningful.

## Rollback

For a single bad file: `scripts/rollback.sh <customer> <content_type> <path> <git_ref>`
redeploys the previous version immediately, then commit the same reversion in
Git so the repo doesn't drift from what's live.

For a bad shared/baseline change affecting multiple customers: revert the
commit in `shared/`, then re-run `scripts/build-effective-content.py --all`
and redeploy the regenerated `.effective/` files to every affected customer
(the workflow's shared-file-changed fan-out handles this automatically on
merge of the revert PR).

## Emergency changes (skip canary)

Sometimes a detection needs to go out same-day (active incident, urgent
customer ask). That's legitimate — but it should be visibly different from
routine changes:

- Title the PR `[EMERGENCY]` and note why canary was skipped.
- Get a second reviewer even if the customer's Environment doesn't normally
  require one for routine changes.
- Backfill canary validation within 48 hours anyway, so the next similar
  change has real burn-in data instead of "we did this once under pressure
  and it seemed fine."
