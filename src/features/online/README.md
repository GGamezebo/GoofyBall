# Goofy Balls online (Phase 1–4 + realtime)

Feature folder: `src/features/online/`.
Addon: `addons/com.heroiclabs.nakama` (autoload `Nakama`).

## Single client path

All auth, RPC, and realtime go through **nakama-godot** (`NakamaClient` / `NakamaSocket`).
`OnlineClient` wraps the SDK; `OnlineRealtime` reuses the same `NakamaClient` + session.

| Piece | Role |
|-------|------|
| `OnlineClient` | `authenticate_*` / `link_*` / `rpc_async` via SDK |
| `OnlineRealtime` | Socket from same client + `NakamaMultiplayerBridge` |
| `join_named_match` | Rooms / MM (`match_name`) — relayed, first peer = host |
| `OnlineService.auto_join_realtime` | After room/mm success → socket + join |

Godot HLAPI `@rpc` works after `ev_match_joined`.

## Providers / progress / leaderboard

Device / google / steam / yandex; `progress_*`; `global_wins` (ranked only).

## Rooms + matchmaker

| RPC | Join target |
|-----|-------------|
| `room_*` | `match_name` = `gb_room_<CODE>` |
| `mm_*` | `match_name` = `gb_mm_<uuid>` when matched |

## Local smoke

```powershell
cd server
docker compose up -d --force-recreate nakama
.\scripts\smoke_rooms.ps1
.\scripts\smoke_matchmaker.ps1
```

F6 `online_smoke.tscn` — guest + progress + LB + room create/join realtime.

## Note

Gameplay sync (ball/players over `@rpc`) is not wired yet — only match presence / peer map. Offline AI / local 2P unchanged.
