# Online (client)

Feature: `src/features/online/`. Addon: `addons/com.heroiclabs.nakama` (autoload `Nakama`).  
Offline AI / local 2P must never require this feature.

## Stack

```mermaid
flowchart TB
  Menu[Menu lobby] --> Service[OnlineService]
  Service --> Client[OnlineClient / NakamaClient]
  Service --> RT[OnlineRealtime]
  RT --> Bridge[NakamaMultiplayerBridge]
  Bridge --> Peer[SceneMultiplayer peer]
  Game[game.gd] --> Sync[OnlineMatchSync]
  Sync -->|rpc_input / rpc_world_state| Peer
  Client -->|auth + RPC| Nakama[Nakama HTTP]
  RT -->|socket match join| Nakama
```

## Pieces

| Piece | Role |
|-------|------|
| `OnlineEndpoints` | LAN `HOST` / ports / `SERVER_KEY` for phone→PC testing |
| `OnlineConfig` | Resource defaults (can override endpoints) |
| `OnlineService` | Auth, progress, rooms, MM, auto realtime join |
| `OnlineClient` | SDK-only auth + `rpc_async` |
| `OnlineRealtime` | Socket from same client + bridge |
| `OnlineMatchSync` | Listen-server gameplay sync |
| `PlatformAuth*` | Device / Google / Steam / Yandex |
| `DevAccounts` | Debug users A–D |

## Lobby flow (menu)

```mermaid
sequenceDiagram
  participant A as Client A
  participant N as Nakama
  participant B as Client B
  A->>N: auth + room_create / mm_enqueue
  B->>N: auth + room_join / mm_enqueue
  A->>N: join_named_match
  B->>N: join_named_match
  Note over A,B: MultiplayerBridge assigns host peer 1
  A->>A: wait 2 peers
  B->>B: wait 2 peers
  A->>A: ev_start_game online local_side=0
  B->>B: ev_start_game online local_side=1
```

1. Dev account (or platform auth) → Sign in  
2. Create Room / Join code / Find Ranked  
3. Wait until 2 peers  
4. `ev_start_game` with `online`, `local_side`, optional `ranked`, display name  
5. Host runs `GameManager`; guest does **not** — HUD/world from sync  

Rooms / MM return `match_name` (`gb_room_*` / `gb_mm_*`); service can auto `join_named_match`.

## CS listen-server sync

Host (peer 1) = authority for physics + match FSM. Guests are thin clients for the world.

```mermaid
flowchart LR
  subgraph host [Host phone]
    InputH[Local p1_*]
    Phys[Physics + FSM]
    Snap[Snapshots ~30 Hz]
    InputH --> Phys --> Snap
    RemIn[Remote input RPC] --> Phys
  end
  subgraph guest [Guest phone]
    Pred[Predict local blob]
    Buf[Snapshot buffer]
    Interp[Interp remote + ball ~100ms]
    Pred --> Send[rpc_input]
    Buf --> Interp
  end
  Send --> RemIn
  Snap --> Buf
```

| Concern | Host | Guest |
|---------|------|-------|
| Own blob | Immediate | Client-side prediction + soft reconcile |
| Remote blob / ball | Simulated | Delayed snapshot interpolation |
| Match FSM / score | Owns | Receives via HUD / state snaps |
| Boom / revive | `prepare_round` | Latest authority life flags (not interp frame) |

Implementation: `OnlineMatchSync` (`INTERP_DELAY_SEC`, snapshot buffer, `_rpc_input`, `_rpc_world_state`).

**Not yet:** dedicated Nakama match authority, lag compensation, full input history reconcile.  
`goofy_match` Lua handler remains a stub for later ranked authority.

## Local testing

```powershell
cd server
docker compose up -d
.\scripts\smoke_rooms.ps1
.\scripts\smoke_matchmaker.ps1
```

Set `OnlineEndpoints.HOST` to the PC LAN IP when testing phones.  
F6 `online_smoke.tscn` — API smoke without full battle UI.

Also see `src/features/online/README.md`.
