# Goofy Balls online (Phase 1–4 + realtime + online 1v1)

Feature folder: `src/features/online/`.
Addon: `addons/com.heroiclabs.nakama` (autoload `Nakama`).

## Local LAN Nakama endpoints for local multiplayer testing (PC + phones).
## Change `OnlineEndpoints.HOST` when your PC Wi‑Fi IP changes.

| Constant | Default |
|----------|---------|
| `OnlineEndpoints.HOST` | LAN IP of PC |
| `PORT` / `CONSOLE_PORT` | 7350 / 7351 |
| `SERVER_KEY` | must match `server/.env` |

All auth, RPC, and realtime go through **nakama-godot** (`NakamaClient` / `NakamaSocket`).
`OnlineClient` wraps the SDK; `OnlineRealtime` reuses the same `NakamaClient` + session.

| Piece | Role |
|-------|------|
| `OnlineClient` | `authenticate_*` / `link_*` / `rpc_async` via SDK |
| `OnlineRealtime` | Socket from same client + `NakamaMultiplayerBridge` |
| `OnlineMatchSync` | Host-authoritative `@rpc` for blobs + ball |
| `join_named_match` | Rooms / MM (`match_name`) — relayed, first peer = host |
| `OnlineService.auto_join_realtime` | After room/mm success → socket + join |

## Menu online flow

1. Pick **Player A/B/C/D** in the dropdown (`DevAccounts`) → Sign in (creates account if new)
2. Create Room / Join code / Find Ranked
3. Wait until 2 peers in match
4. `ev_start_game` with `GameConfig.online=true`, `local_side` (host=0 / guest=1), `ranked` for MM
5. Host runs GameManager FSM; client puppets via `OnlineMatchSync`

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

Sync is minimal (pose / velocity / HUD). Offline AI / local 2P unchanged.
