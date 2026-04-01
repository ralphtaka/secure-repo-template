## Summary
- What changed:
- Why:

## Security Checklist
- [ ] I reviewed authentication/authorization impact (if applicable).
- [ ] I reviewed user input handling, validation, and output encoding.
- [ ] I reviewed secret handling (no hardcoded keys/tokens/certs).
- [ ] I reviewed dependency changes and risk (`dependency-review` / advisories).
- [ ] I reviewed logging for sensitive data leakage.
- [ ] I updated security_docs/runbook/checklist when security behavior changed.

## Testing
- [ ] Local tests pass.
- [ ] CI checks are expected to pass (`dependency-review`, `trivy-pr`, `gitleaks`, `codeql`, `ci`).

## Deployment Notes
- Any rollout or rollback concern:
