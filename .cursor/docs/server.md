# Server (Nakama)

Path: `server/`. **Not** imported by Godot. Client talks over HTTP/WS only.

## Compose

| Service | Role |
|---------|------|
| `postgres` | Nakama DB |
| `nakama` | Runtime + console; mounts `./nakama` → `/nakama/data` |

Secrets: `server/.env` (gitignored). Example: `server/.env.example`.  
YAML under `server/` — **spaces only** (tabs break parsers).

After changing Lua modules: `docker compose restart nakama`.

## Ports

| Port | Use |
|------|-----|
| 5432 | Postgres |
| 7349 | gRPC |
| 7350 | HTTP / WebSocket (game client) |
| 7351 | Console |

## Modules (`server/nakama/modules/`)

| Module | RPCs / role |
|--------|-------------|
| `identity.lua` | Account view / auth-related helpers + Yandex hooks |
| `progress.lua` | `progress_*` Storage pull/push/merge (`schema_version`, `max()` merge) |
| `leaderboard.lua` | `submit_match_result`, `leaderboard_top` (`global_wins`; ranked only) |
| `rooms.lua` | `room_create` / `room_join` / `room_close` (codes, TTL) |
| `matchmaker.lua` | `mm_enqueue` / `mm_status` / `mm_cancel` |
| `goofy_match.lua` | Stub authoritative match handler (future) |

### Contracts (short)

- Key player data by Nakama `user_id`
- Progress: collection `player` / `progress`; offline-first on client
- Rooms: Storage `room_codes`; 4-char code; TTL ~45m; `match_name` for relayed join
- Matchmaker: lobby `ranked_1v1`; returns `match_name`
- Realtime gameplay today: **relayed** named matches via MultiplayerBridge (host = first peer)

## Smoke scripts

`server/scripts/smoke_*.ps1` — health, identity, progress, leaderboard, rooms, matchmaker.

## Backend roadmap

Phases 0–4 done in plan; **Phase 5** = hardening (rate limits, staging, backups, schema versioning, WSS origins).  
**Phase 6** = more auth providers.  
See [../plans/online-server-backend.plan.md](../plans/online-server-backend.plan.md).

Agent constraints: [../rules/server-backend.mdc](../rules/server-backend.mdc).
