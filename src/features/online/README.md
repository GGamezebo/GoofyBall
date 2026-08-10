# Goofy Balls online identity + progress + leaderboard (Phase 1–3)

Feature folder: `src/features/online/`.
Server modules: `identity.lua`, `progress.lua`, `leaderboard.lua`.

## Providers

| Platform id | Nakama API | Notes |
|-------------|------------|-------|
| `device` | authenticate/link device | Guest; always available |
| `google_android` / `google_web` | authenticate/link google | Inject Google ID token from SDK |
| `steam` | authenticate/link steam | Needs `social.steam` + ticket |
| `yandex` | authenticate/link **custom** | `yandex_<id>`; server before-hook |

## Cloud progress (Phase 2)

| RPC | Behavior |
|-----|----------|
| `progress_pull` | Read Storage `player/progress` |
| `progress_push` | Write if local `updated_at` >= cloud (else conflict) |
| `progress_merge` | `max()` on counters, write, return merged |

Offline-first: `SaveManager` always writes disk; if `_online_service` set and session exists, merges to cloud after flush.

## Leaderboard (Phase 3)

| RPC | Behavior |
|-----|----------|
| `submit_match_result` | `mode`: `vs_ai` \| `local_2p` \| `ranked`. Only **ranked** win writes `global_wins` |
| `leaderboard_top` | Top N records on `global_wins` |

Casual matches keep using local PData + `progress_merge`. Ranked path bumps `wins_ranked` server-side.

## Local smoke

```powershell
cd server
docker compose restart nakama
.\scripts\smoke.ps1
.\scripts\smoke_identity.ps1
.\scripts\smoke_progress.ps1
.\scripts\smoke_leaderboard.ps1
```

## Godot smoke

F6 `online_smoke.tscn` (Nakama running) — guest auth + progress_merge + ranked submit + top.

In Menu: **Dev account (guest)** → `OnlineService.authenticate_guest_async()` (needs `main` + Nakama).

## Wiring tokens (later UI)

```gdscript
var google := GoogleAuth.new(online.client, "google_web")
google.set_id_token(token_from_js_bridge)
await online.link_provider_async(google)
```
