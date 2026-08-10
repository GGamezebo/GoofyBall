# Goofy Balls online identity + progress (Phase 1–2)

Feature folder: `src/features/online/`.
Server modules: `identity.lua`, `progress.lua`.

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

## Local smoke

```powershell
cd server
docker compose restart nakama
.\scripts\smoke.ps1
.\scripts\smoke_identity.ps1
.\scripts\smoke_progress.ps1
```

## Godot smoke

F6 `online_smoke.tscn` (Nakama running) — guest auth + progress_merge.

## Wiring tokens (later UI)

```gdscript
var google := GoogleAuth.new(online.client, "google_web")
google.set_id_token(token_from_js_bridge)
await online.link_provider_async(google)
```
