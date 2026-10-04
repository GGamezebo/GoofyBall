## What & why
<!-- What changed and why. Link the issue: Closes #N -->

## How to test
<!-- Steps, or which scene to run with F6 -->

## Screenshots / GIF
<!-- For visual changes -->

## Checklist
- [ ] Changed scenes run standalone (F6)
- [ ] No new autoloads/singletons; features talk via `ev_*` signals + `initialize`
- [ ] No parent references in components
- [ ] Gameplay logic only in `volley_sim`; cosmetics don't touch sim
- [ ] Rules/docs updated if structure or conventions changed
- [ ] Commits in English
