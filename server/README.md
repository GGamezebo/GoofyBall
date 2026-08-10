# Goofy Balls — local game backend (Nakama)

Phase 0 infrastructure: **Postgres + Nakama** via Docker Compose.
Game clients (Godot) are not required for this folder to run.

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows: WSL2 backend recommended)
- `docker` available in PATH (`docker version` works in PowerShell)
- Docker daemon running before `compose up`

### Install Docker on Windows (if missing)

1. Install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/).
2. Enable **WSL2** backend when prompted; reboot if asked.
3. Start Docker Desktop and wait until it says **Running**.
4. Open a **new** PowerShell and confirm:

```powershell
docker version
docker compose version
```

## Quick start

```powershell
cd server
copy .env.example .env
# Edit .env — set real passwords (defaults in the committed .env.example are placeholders)

docker compose up -d
.\scripts\smoke.ps1
```

Console UI: http://127.0.0.1:7351/  
HTTP / WebSocket API: http://127.0.0.1:7350/  
gRPC: `127.0.0.1:7349`

Login to Console with `NAKAMA_CONSOLE_USERNAME` / `NAKAMA_CONSOLE_PASSWORD` from `.env`.

Client `server_key` (for later Godot / HTML): `NAKAMA_SERVER_KEY` from `.env`.

## Ports

| Port | Service | Use |
|------|---------|-----|
| 5432 | Postgres | DB (localhost only for tools) |
| 7349 | Nakama | gRPC |
| 7350 | Nakama | HTTP API + WebSocket (Godot / HTML) |
| 7351 | Nakama | Admin Console |

## Useful commands

```powershell
cd server

docker compose ps
docker compose logs -f nakama
docker compose logs -f postgres

docker compose down          # stop, keep DB volume
docker compose down -v       # stop AND wipe Postgres data (destructive)
```

## Layout

```
server/
  docker-compose.yml     # Postgres + Nakama
  .env.example           # variable template (safe to commit)
  .env                   # local secrets (gitignored)
  nakama/
    local.yml            # Nakama config (non-secret defaults)
    modules/             # runtime modules (Phase 1+)
  scripts/
    smoke.ps1            # health check
  README.md
```

## How it fits together

1. **Postgres** stores all Nakama data (users, storage, leaderboards, …).
2. On Nakama start, `migrate up` applies schema, then the server process boots with `--config /nakama/data/local.yml`.
3. Secrets (DB password, console password, `server_key`) come from `.env` and override YAML via CLI flags.
4. `./nakama` is mounted at `/nakama/data` inside the container — put runtime modules in `nakama/modules/`.

## Environments (later)

| Env | Purpose |
|-----|---------|
| `dev` | This compose stack on your machine |
| `staging` | Separate host + separate Google OAuth clients (Phase 1/5) |
| `prod` | Separate keys, TLS/WSS, tightened CORS, backups |

Do not reuse `dev` passwords or `server_key` outside your machine.

## Troubleshooting

- **Docker errors / pull fails** — start Docker Desktop; wait until it is ready.
- **Port already in use** — stop the other process on 5432/7350/7351 or change host mappings in `docker-compose.yml`.
- **Nakama restart loop** — `docker compose logs nakama`; usually bad DB password or volume from an old password (`down -v` once, then `up` again).
- **Smoke fails** — wait ~20s after first pull/start, then re-run `.\scripts\smoke.ps1`.

## Next (Phase 4+)

Leaderboard: `nakama/modules/leaderboard.lua`. Smoke: `.\scripts\smoke_leaderboard.ps1`.
Rooms + matchmaker next.
