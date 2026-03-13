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
2. Require break-glass PRs to reference an incident ID and include `break-glass` label.
3. Add PR template fields: impact, rollback plan, risk, and compensation deadline (e.g. 24h).
4. Add a workflow to fail PR when incident ID / required fields / label are missing.
5. Require follow-up PR or issue within 24h to restore normal security gates and add missing tests/docs.
6. Track follow-up items via a dedicated milestone (e.g. `break-glass-followup`).

#### Exit criteria for enabling
- At least one real incident or near-miss indicates need for emergency override.
- Team agrees on on-call owner and SLA for follow-up completion.
