# Client Project Kickoff Checklist

Use this checklist on Day 0/Day 1 after creating a new repo from this template.

## A. Create repo from template
- [ ] Click `Use this template` on GitHub.
- [ ] Create new repo with private visibility by default.
- [ ] Clone the new repo locally and confirm default branch is `main`.
- [ ] Run bootstrap (recommended): `./scripts/bootstrap-project.sh --stack <node|python|java|go|rust> --docker <on|off> --repo <owner/repo> --require-code-scanning-high on --solo on`.
- [ ] Or run manually: `./scripts/init-project.sh --stack <node|python|java|go|rust> --docker <on|off>` then `./scripts/install-hooks.sh` then `./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off> --require-code-scanning-high on --solo on`.

## B. GitHub settings checklist

### Repository setup
- [ ] `Settings -> General -> Features`: disable unused features (for example Projects/Wiki) if not needed by the client.
- [ ] `Settings -> General -> Pull Requests`: enable auto delete head branches.
- [ ] `Settings -> General -> Pull Requests`: enable auto-merge (required for Dependabot auto-merge workflow).
- [ ] `Settings -> General`: ensure `Template repository` is OFF for client delivery repos.

### Security
- [ ] `Settings -> Security`: enable `Dependency graph`.
- [ ] `Settings -> Security`: enable `Dependabot alerts`.
- [ ] `Settings -> Security`: enable `Dependabot security updates`.
- [ ] `Settings -> Security`: enable `Secret scanning` if available on your plan.
- [ ] `Settings -> Security`: enable `Code scanning` if available on your plan.

### Branch protection (Rulesets)
- [ ] `Settings -> Rules -> New ruleset` for `main`.
- [ ] Use `security_docs/branch-ruleset-template.md` as baseline.
- [ ] Or apply by script: `./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off> --solo on` (`--strict-required` optional).
- [ ] (Recommended) include CodeQL high gate: add `--require-code-scanning-high on` when applying ruleset.
- [ ] Require pull request before merge.
- [ ] Block force pushes.
- [ ] Block branch deletion.
- [ ] Require status checks:
- [ ] `dependency-review`
- [ ] `trivy-pr`
- [ ] `gitleaks`
- [ ] `codeql`
- [ ] `ci`
- [ ] If Docker enabled, also require `container-scan` and `dockerfile-lint`.

### Optional Docker module
- [ ] If project ships Docker image, run `./scripts/init-project.sh --stack <node|python|java|go|rust> --docker on` (or manually rename `.github/workflows/container-scan.yml.disabled`).
- [ ] Run one manual workflow dispatch for `container-scan` and verify success.
- [ ] Run one manual workflow dispatch for `dockerfile-lint` and verify success.

## C. Day 1 verification commands

Run from repo root:

```bash
git status
git remote -v
rg -n "your-email@example.com|example.com" .
rg -n "uses: .*@(v|main|master|latest)" .github/workflows
```

Expected:
- `git status` is clean before first feature work.
- No placeholder contacts remain.
- No unpinned actions remain in workflows.
- PR/Issue templates exist in `.github/`.
- `codeql.yml` exists in `.github/workflows/`.
- `ci.yml` exists in `.github/workflows/`.
- `dependency-audit-nightly.yml` exists in `.github/workflows/`.

If Docker is enabled:

```bash
docker build -t local/smoke:day1 .
```

Then create a small smoke PR (for example README change) and verify required checks pass on GitHub before real development starts.
