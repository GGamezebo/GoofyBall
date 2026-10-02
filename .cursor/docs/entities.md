# Entities

Named types and ownership. Paths are under the repo root unless noted.

## Resources (shared config / buses)

| Type | Path | Role |
|------|------|------|
| `GameConfig` | `src/common/game_config.gd` (+ `.tres` variants) | Match settings: `vs_ai`, `online`, `ranked`, `local_side`, scores, touches, timers |
| `RootEvents` | `src/game/scenes/app_root/root_events.gd` | App navigation / save / battle lifecycle signals |
| `PData` / saves | `src/game/account/` | Persistent progress mirrored to disk (+ optional cloud) |
| `OnlineConfig` | `src/features/online/online_config.gd` | Host, ports, server key, preferred platform |
| `OnlineEndpoints` | `src/features/online/online_endpoints.gd` | Nakama host/port/key: env vars or `user://online.cfg`, localhost by default |

### GameConfig fields (match)

| Field | Meaning |
|-------|---------|
| `vs_ai` | Right side AI |
| `online` | Nakama 1v1 |
| `ranked` | Submit to `global_wins` on win |
| `local_side` | 0 Blue/left, 1 Red/right (online) |
| `win_score` | First to N |
| `max_touches` | Fault after N hits on one side (default 3) |
| `round_duration_sec` / `round_alarm_sec` | Rally clock + red alarm |

## Screens (`IScene`)

| Scene | Script | Role |
|-------|--------|------|
| App root | `src/game/scenes/app_root/root.gd` | Saves, RootEvents → HFSM, open platform |
| Menu | `src/game/scenes/menu/menu.gd` | Offline modes + online lobby |
| Game | `src/game/scenes/game/game.gd` | Wires match runner/view + online rollback |
| Post-battle | `src/game/scenes/post_battle/` | Results → menu / retry |

## Match orchestration

| Type | Role |
|------|------|
| `VolleySim` | Deterministic simulation: all rules, physics, phases (`src/features/volley_sim/`) |
| `MatchRunner` | Owns one `VolleySim`; steps it offline, exposes save/load/step for rollback |
| `MatchView` | Renders sim state: poses views, HUD, FX from state serials |
| `game.gd` | Wires config → runner → view; starts online via `OnlineRollback` |

## Gameplay features

| Feature | Types | Notes |
|---------|-------|-------|
| `volley_sim` | `VolleySim` | Pure state machine, no nodes (see [simulation.md](simulation.md)) |
| `blob_view` | `BlobView` | Node3D; `apply_state`, hit/blast FX |
| `ball_view` | `BallView` | Node3D; `apply_state`, alarm blink, explosion FX |
| `ai_opponent` | `AiOpponent` | `decide(state)` → input; `side` selects the blob |
| `player_input` | `PlayerInput` | InputMap/touch → `{x, j, b}` |
| `virtual_controls` | `VirtualControls` | Touch → `p1_*`; BOOM on touchscreen |

## Online feature

| Type | Role |
|------|------|
| `OnlineService` | Facade: auth, progress, rooms, MM, realtime |
| `OnlineClient` | NakamaClient auth + RPC |
| `OnlineRealtime` | Socket + `NakamaMultiplayerBridge` |
| `OnlineRollback` + `RollbackInput` | godot-rollback-netcode glue: handshake, input nodes, state callbacks |
| `OnlineSession` | Wrapper around `NakamaSession` |
| `OnlineProgress` | Cloud progress pull/push/merge helpers |
| `PlatformAuth` + factory | Device / Google / Steam / Yandex adapters |
| `DevAccounts` | Debug A–D usernames for local testing |

## Platform contexts

BoundEntities registered from `main.gd`:  
`DesktopContext`, `AndroidContext`, `SteamContext`, `WEBContext`, `YandexGamesContext`  
→ `src/game/contexts/`.

## Core utilities (selected)

| Type | Role |
|------|------|
| `HFSM` / loader | App state machine from JSON |
| `FSM` / `FSMState` | Generic state machine library (no longer used in-match) |
| `EventListener` | Safe signal subscribe/unsubscribe |
| `ResourceUtils` | Merge Resource fields at runtime |
| `PerformanceTune` | Mobile/Web quality cuts |

## Server (Lua / Docker)

See [server.md](server.md). Modules are **not** Godot classes; they expose RPCs keyed by Nakama `user_id`.
