# Project Profiles

Profiles let you keep one shared security baseline while applying only the language-specific parts per client project.

## Available profiles
- `node`
- `python`
- `java`
- `go`
- `rust`

## Profile contents
- `dependabot.yml`: language-specific Dependabot config (no Docker updates)
- `dependabot-docker.yml`: same as above, plus Docker ecosystem updates
- `codeql.yml`: language-specific CodeQL workflow
- `ci.yml`: language-specific CI test workflow
- `smoke/`: minimal runnable scaffold copied only when target files do not exist
- `gitignore.snippet`: language-specific `.gitignore` entries

Note:
- Rust profile `codeql.yml` scans GitHub Actions workflow language (`actions`); Rust code dependency risk is primarily covered by `cargo audit`.

## Apply a profile
Run from repo root:

```bash
./scripts/init-project.sh --stack node --docker off
```

Then commit the generated changes in the new client repository.
