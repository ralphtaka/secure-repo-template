# TODO Backlog

## Deferred

### Break-glass workflow (without external incident tracking)
- Status: Deferred
- Priority: Medium
- Added: 2026-03-13
- Why deferred: Current phase focuses on baseline setup; incident process is not yet needed day-to-day.

#### Goal
Provide a controlled emergency merge path that is auditable and recoverable, even when no dedicated incident system exists.

#### Minimal implementation plan
1. Use GitHub Issues as incident records with ID format `INC-YYYYMMDD-###` and label `incident`.
2. Define two emergency paths:
   - P0 path: allow repo admin bypass first, then require incident/backfill records.
   - P1 path: use break-glass PR with lightweight format validation.
3. Require break-glass PRs to reference an incident ID and include `break-glass` label.
4. Add PR template fields: impact, rollback plan, risk, and compensation deadline (e.g. 24h).
5. Add workflow validation only for P1 break-glass PR format (do not block P0 admin bypass path).
6. Require follow-up PR or issue within 24h to restore normal security gates and add missing tests/docs.
7. Track follow-up items via a dedicated milestone (e.g. `break-glass-followup`).
8. Explicitly define authorization: only repo admins (or designated on-call maintainers) can bypass ruleset or trigger break-glass.

#### Exit criteria for enabling
- At least one real incident or near-miss indicates need for emergency override.
- Team agrees on on-call owner and SLA for follow-up completion.

### Ruleset apply idempotency regression test
- Status: Deferred
- Priority: Low
- Why deferred: `scripts/apply-ruleset.sh` already uses upsert logic (existing ruleset -> PUT, missing -> POST).

#### Goal
Prevent future regressions where repeated runs would fail due to duplicate ruleset creation.

#### Implementation sketch
1. Add a small CLI smoke test (dry-run and non-dry-run in a sandbox repo).
2. Verify first run creates ruleset and second run updates same ruleset ID.
3. Add this check to maintenance checklist.

### Enforce PR template completion
- Status: Deferred
- Priority: Medium
- Why deferred: Template is auto-inserted but not gate-enforced yet.

#### Goal
Fail PR if required security checklist fields are empty or removed.

#### Implementation sketch
1. Add a PR-body validation workflow.
2. Require specific headings/checklist tokens from `PULL_REQUEST_TEMPLATE.md`.
3. Add this validation job to ruleset required checks.

### Automate pinned-action lifecycle
- Status: Deferred
- Priority: Medium
- Why deferred: Current update flow relies on Dependabot PR + manual review.

#### Goal
Reduce manual effort for commit-SHA upgrades while keeping supply-chain safety.

#### Implementation sketch
1. Evaluate Renovate or a custom verification script.
2. Validate SHA/tag mapping and changelog risk automatically.
3. Auto-label low-risk action bumps for faster review.

### Container image signing (Docker mode)
- Status: Deferred
- Priority: Medium
- Why deferred: Not all client projects publish container images.

#### Goal
Sign release images and verify provenance (Cosign/Sigstore).

#### Implementation sketch
1. Add optional signing workflow for tagged releases.
2. Generate signature and attestations.
3. Add verification step before deploy/release promotion.

### Expand local pre-commit guardrails
- Status: Deferred
- Priority: Low
- Why deferred: Current mandatory `gitleaks` + secret-file block covers minimum baseline.

#### Goal
Catch more quality/security issues before CI.

#### Implementation sketch
1. Add optional file-size guard for large binary commits.
2. Add optional commit message policy (Conventional Commits).
3. Add optional lint/format staged checks by stack.

### Security alert notifications (Slack/Teams)
- Status: Deferred
- Priority: Low
- Why deferred: Solo operation can currently monitor in GitHub UI.

#### Goal
Notify on nightly scan failures/high-severity findings without manual dashboard checks.

#### Implementation sketch
1. Add webhook notification step for nightly workflows.
2. Send compact incident payload (repo, run URL, severity, owner).
3. Throttle duplicate alerts and include recovery notifications.
