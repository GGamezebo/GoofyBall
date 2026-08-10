# Goofy Balls online identity (Phase 1)

Feature folder: `src/features/online/`.
Server module: `server/nakama/modules/identity.lua` (Lua — loads without JS bundling).

## Providers

| Platform id | Nakama API | Notes |
|-------------|------------|-------|
| `device` | authenticate/link device | Guest; always available |
| `google_android` / `google_web` | authenticate/link google | Inject Google ID token from SDK |
| `steam` | authenticate/link steam | Needs `social.steam` in Nakama + ticket |
| `yandex` | authenticate/link **custom** | Server `beforeAuthenticateCustom`; `yandex_<id>` |

All providers resolve to one Nakama `user_id`. Link later; do not create per-platform save tables.

## Local smoke (server)

```powershell
cd server
docker compose restart nakama
.\scripts\smoke.ps1
.\scripts\smoke_identity.ps1
```

## Godot smoke

Open `src/features/online/online_smoke.tscn` (F6) with Nakama running.
Default config: `online_config.tres` → `127.0.0.1:7350` + `server_key` from `.env`.

## Wiring tokens (later UI)

```gdscript
var google := GoogleAuth.new(online.client, "google_web")
google.set_id_token(token_from_js_bridge)
await online.link_provider_async(google)
```

Yandex Games export: set feature `yandex_games` so `OnlinePlatforms.detect_host_kind()` picks Yandex.
