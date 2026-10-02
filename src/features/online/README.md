# Goofy Balls online (Phase 1–4 + realtime + online 1v1)

Feature folder: `src/features/online/`.
Addon: `addons/com.heroiclabs.nakama` (autoload `Nakama`).

## Nakama endpoints

`OnlineEndpoints` resolves host / port / server key in this order:

1. env vars `GOOFY_NAKAMA_HOST`, `GOOFY_NAKAMA_PORT`, `GOOFY_NAKAMA_KEY`
2. `user://online.cfg` — `[nakama]` section with `host`, `port`, `server_key`
3. defaults: `127.0.0.1:7350`, key `goofyballs_dev_server_key` (must match `server/.env`)

For phone testing put your PC's LAN IP (`ipconfig`) into `user://online.cfg` on the device.

All auth, RPC, and realtime go through **nakama-godot** (`NakamaClient` / `NakamaSocket`).
`OnlineClient` wraps the SDK; `OnlineRealtime` reuses the same `NakamaClient` + session.

| Piece | Role |
|-------|------|
| `OnlineClient` | `authenticate_*` / `link_*` / `rpc_async` via SDK |
| `OnlineRealtime` | Socket from same client + `NakamaMultiplayerBridge` |
| `OnlineRollback` | godot-rollback-netcode glue (`SyncManager`): handshake, per-side input nodes, state callbacks |
| `RollbackInput` | Input node per side (authority = that side's peer) |
| `join_named_match` | Rooms / MM (`match_name`) — relayed, first peer = host |
| `OnlineService.auto_join_realtime` | After room/mm success → socket + join |

## Menu online flow

1. Pick **Player A/B/C/D** in the dropdown (`DevAccounts`) → Sign in (creates account if new)
2. Create Room / Join code / Find Ranked
3. Wait until 2 peers in match
4. `ev_start_game` with `GameConfig.online=true`, `local_side` (host=0 / guest=1), `ranked` for MM
5. Both peers run the same `VolleySim`; `OnlineRollback` exchanges inputs and rolls back on misprediction

Two clients on one PC: editor = Player A, export = Player B (different dropdown).

## Rooms + matchmaker

| RPC | Join target |
|-----|-------------|
| `room_*` | `match_name` = `gb_room_<CODE>` |
| `mm_*` | `match_name` = `gb_mm_<uuid>` when matched |

## Local smoke

```powershell
cd server
docker compose up -d
.\scripts\smoke_rooms.ps1
.\scripts\smoke_matchmaker.ps1
```

Two game instances (or export + editor): Create Room on A, Join code on B → online battle.

F6 `online_smoke.tscn` — guest + progress + LB + room create/join realtime (API only).

## Note

Sync: rollback netcode via `OnlineRollback` + `SyncManager` (inputs only; deterministic `VolleySim`).
Offline AI / local 2P unchanged. See `.cursor/docs/online.md`.
