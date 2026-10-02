# Simulation (VolleySim)

`src/features/volley_sim/volley_sim.gd` is the single source of gameplay truth for **every** mode
(offline, vs AI, online). It is plain GDScript on a `Dictionary` state — no nodes, no engine physics.

## Why

godot-rollback-netcode re-simulates past ticks after a late remote input. That only works if
`state + inputs → next state` is a pure function. Engine physics (Jolt/GodotPhysics), `randf()`,
wall-clock time and tweens/timers are not. So all of that lives *outside* the sim.

## Contract

| Rule | Reason |
|------|--------|
| Only `+ - * /`, `sqrt`, `min/max/clamp/abs/sign`, `move_toward` on floats | bit-identical across CPUs (no `sin/cos/pow`) |
| No `randf`, no `Time`, no node access | determinism |
| All match state is in `s` (ints, floats, bools, arrays, dicts) | save/load/hash by SyncManager |
| `step(inputs)` mutates only `s` | rollback = `load_state` + replay |
| FX/HUD derive from state (`*_serial` counters, `msg`, `phase`) | no duplicate effects on re-sim |
| Inputs are small ints `{x:-100..100, j:0|1, b:0|1}`; `b` is edge-detected in the sim | cheap to send, safe under prediction |

Changing any constant or ordering in `step()` changes the game for everybody: online peers must run
the same build.

## Tests

`tests/cases/test_volley_sim.gd` covers phases, net, blast, timeout, faults, and
**determinism + save/load roundtrip**. `test_rollback.gd` drives the real `SyncManager`
(mechanized mode) with late remote input and checks the result equals a rollback-free replay.
`test_gameplay.gd` plays bot-vs-bot matches and runs the real game scene offline.

```powershell
godot --headless --path . --script res://tests/run_all.gd
```

CI (`.github/workflows/android-apk.yml`) runs the same, then builds the debug APK.
