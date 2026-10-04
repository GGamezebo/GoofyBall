# Contributing

## Branches
- `main` — stable, protected; changes only via Pull Request.
- `develop` — integration branch; feature branches start here and merge back via PR.
- Short-lived branches: `feature/...`, `fix/...`, `docs/...`, `chore/...`.

## Commits
- English, imperative, up to 72 chars in the subject: `Add rollback sync for ball state`.
- One logical change per commit; do not mix refactoring with features.

## Pull Requests
- Small and focused; fill in the PR template.
- Feature -> `develop`: squash merge. `develop` -> `main` (release): merge commit.
- Link the issue (`Closes #N`) and attach a screenshot/GIF for visual changes.

## Code & architecture
Rules live in [`.claude/rules/`](.claude/rules/) (`project.md`, `architecture.md`, `gdscript.md`, ...).
Docs are in Russian; code, identifiers and commits in English.
Structural changes must update the matching rule and doc in the same commit.
