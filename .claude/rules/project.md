# Project (always) — approaches mirror GGamezebo/quizmatik
Layout:
- `main.tscn` → `src/game/main.gd` HFSM bootstrap · `src/game/hfsm/app_hfsm.json` app phases
- `src/game/scenes/{app_root,menu,game,post_battle}` orchestration only
- `src/features/{name}/` isolated features (.gd+.tscn colocated): `volley_sim` (+`buffs/`), `blob_view`, `ball_view`, `buff_fx`, `online`, `virtual_controls`, `ai_opponent`
- `src/common/` shared Resources/presets (.tres) · `src/ui/` shared widgets · `core/` project-agnostic libs (never import `src/`) · `server/` Nakama · `tests/` headless · `tools/` generators · `concept/` art (Godot-ignored)
Must:
- Feature talks out only via `ev_*` signals + `initialize`/`setup`; never import another feature's internals; scenes compose features.
- Every scene runs alone (F6): defaults in exported `.tres`; parent overrides via event → `initialize(data)` → `ResourceUtils.update_resource`.
- No new autoloads/singletons (use RootEvents/GameEvents Resources); exception: third-party plugins like rollback `SyncManager`. See `architecture.md`.
- `class_name`/`@export` over hardcoded `res://`.
- Mobile + Steam + HTML5: touch and KBM/gamepad; platform code only in platform HFSM contexts (`architecture.md`).
- volley_sim is the only gameplay truth; never assume 2 players/left-right (N teams × N players).
- No pay-to-win: cosmetics never touch sim.
- Docs Russian; code/identifiers/commits English.
- Structural/convention change → update matching rule + doc in same commit; rules ≤ ~50 lines, one concern each.
