# Security Workflow Overview

```mermaid
flowchart TD
    A["Pull Request Opened"] --> B["security-pr<br/>dependency-review + trivy-pr"]
    A --> C["gitleaks"]
    A --> D["ci (profile)"]
    A --> E["codeql (profile)"]
    B --> F{"Required checks pass?"}
    C --> F
    D --> F
    E --> F
    F -->|Yes| G["Merge to main"]
    F -->|No| H["Fix and push updates"]
    G --> I["security-nightly<br/>Trivy SARIF to code scanning"]
    G --> J["dependency-audit-nightly<br/>npm/pip/maven/go/rust audits"]
    G --> K["generate-sbom"]
    G --> L["gitleaks (push)"]
    G --> M["Optional Docker module<br/>container-scan + dockerfile-lint"]
```

## Notes
- `security-pr` runs on PR to block high-risk dependencies and filesystem vulnerabilities before merge.
- `security-nightly` and `dependency-audit-nightly` continue scanning after merge for drift and newly disclosed CVEs.
- If Docker mode is enabled, include `container-scan` and `dockerfile-lint` in required checks.
