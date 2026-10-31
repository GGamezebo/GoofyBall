# Logging (always)
Goal: logs let AI agents (and humans) find bugs from a run log alone.
- Log every major event: HFSM transitions, scene `initialize`/`deinit`, match start/end, rally/point, buff/env event apply/expire, session connect/disconnect/desync, save/load, purchases, errors.
- Severity: `DEBUG` < `INFO` < `WARN` < `ERROR`. Min level per channel in a `.tres` settings Resource; release build default `WARN`, editor `DEBUG`.
- Logger lives in `core/lib/log/` (project-agnostic), no singleton: owner gets it via `@export` settings Resource / passes a channel instance to components.
- Line format, one line, greppable: `[<frame|ms>] <SEV> <channel> <event> key=value ...` (e.g. `INFO sim point team=1 score=5:3`).
- `WARN`/`ERROR` also go to `push_warning`/`push_error`.
- Log facts with ids and values (state names, player/team ids, tick), not prose. No per-frame spam above `DEBUG`.
- Never log personal data, tokens, or free user text.
- Sim logging must not affect determinism (no logging-driven branches, no RNG use).
