# Project Profiles

Profiles let you keep one shared security baseline while applying only the language-specific parts per client project.

## Available profiles
- `node`
- `python`
- `java`

## Profile contents
- `dependabot.yml`: language-specific Dependabot config (no Docker updates)
- `dependabot-docker.yml`: same as above, plus Docker ecosystem updates
- `codeql.yml`: language-specific CodeQL workflow
- `gitignore.snippet`: language-specific `.gitignore` entries

## Apply a profile
Run from repo root:

```bash
./scripts/init-project.sh --stack node --docker off
```

Then commit the generated changes in the new client repository.
