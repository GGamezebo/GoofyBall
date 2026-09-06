# Entities

Named types and ownership. Paths are under the repo root unless noted.

## Resources (shared config / buses)

| Type | Path | Role |
|------|------|------|
| `GameConfig` | `src/common/game_config.gd` (+ `.tres` variants) | Match settings: `vs_ai`, `online`, `ranked`, `local_side`, scores, touches, timers |
| `RootEvents` | `src/game/scenes/app_root/root_events.gd` | App navigation / save / battle lifecycle signals |
| `GameEvents` | `src/game/scenes/game/game_events.gd` | In-match HUD / score / state signals |
| `PData` / saves | `src/game/account/` | Persistent progress mirrored to disk (+ optional cloud) |
| `OnlineConfig` | `src/features/online/online_config.gd` | Host, ports, server key, preferred platform |
| `OnlineEndpoints` | `src/features/online/online_endpoints.gd` | LAN constants for local multiplayer testing |

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
| Game | `src/game/scenes/game/game.gd` | Wires match + online sync |
| Post-battle | `src/game/scenes/post_battle/` | Results → menu / retry |

## Match orchestration

| Type | Role |
|------|------|
| `GameManager` | Match FSM host (`Serve` → `Play` → `Point` → …) |
| `MatchController` | Score, serve side, touch faults, court reset |
| FSM states | `serve_state`, `play_state`, `point_state`, `match_end_state` |

## Gameplay features

| Feature | Types | Notes |
|---------|-------|-------|
| `blob_player` | `BlobPlayer` | CharacterBody3D; `external_*` for AI/online; last-chance blast |
| `ball` | `Ball` | RigidBody3D; network puppet on guests |
| `ai_opponent` | `AiOpponent` | Drives right blob when `vs_ai` |
| `virtual_controls` | `VirtualControls` | Touch → `p1_*`; BOOM on touchscreen |

## Online feature

| Type | Role |
|------|------|
| `OnlineService` | Facade: auth, progress, rooms, MM, realtime |
| `OnlineClient` | NakamaClient auth + RPC |
| `OnlineRealtime` | Socket + `NakamaMultiplayerBridge` |
| `OnlineMatchSync` | CS listen-server sync (host physics, guest prediction + interp) |
| `OnlineSession` | Wrapper around `NakamaSession` |
| `OnlineProgress` | Cloud progress pull/push/merge helpers |
| `PlatformAuth` + factory | Device / Google / Steam / Yandex adapters |
| `DevAccounts` | Debug A–D usernames for LAN testing |

## Platform contexts

BoundEntities registered from `main.gd`:  
`DesktopContext`, `AndroidContext`, `SteamContext`, `WEBContext`, `YandexGamesContext`  
→ `src/game/contexts/`.

## Core utilities (selected)

| Type | Role |
|------|------|
| `HFSM` / loader | App state machine from JSON |
| `FSM` / `FSMState` | In-match state machine |
| `EventListener` | Safe signal subscribe/unsubscribe |
| `ResourceUtils` | Merge Resource fields at runtime |
| `PerformanceTune` | Mobile/Web quality cuts |

## Server (Lua / Docker)

See [server.md](server.md). Modules are **not** Godot classes; they expose RPCs keyed by Nakama `user_id`.
