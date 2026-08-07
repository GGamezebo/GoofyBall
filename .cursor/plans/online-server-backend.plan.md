---
name: Online server backend
overview: >-
  Nakama-based server for Goofy Balls — auth (guest + Google first), cloud progress,
  leaderboards, friend rooms, matchmaker. Focus Google Play + HTML; architecture
  ready for Steam/Apple later. Offline AI and local 2P stay offline-first.
todos:
  - id: infra
    content: "Phase 0 — Docker Compose (Nakama + Postgres), env/secrets, healthcheck CI"
    status: completed
  - id: identity
    content: "Phase 1 — Device + Google auth (Android & Web clients), account view RPCs, IPlatformAuth contract"
    status: pending
  - id: progress-sync
    content: "Phase 2 — Cloud progress Storage schema + progress_pull/push/merge RPCs"
    status: pending
  - id: leaderboard
    content: "Phase 3 — Leaderboard + submit_match_result (server-authoritative)"
    status: pending
  - id: rooms-mm
    content: "Phase 4 — Room codes + ranked matchmaker + relayed match smoke"
    status: pending
  - id: hardening
    content: "Phase 5 — Rate limits, backups, staging, RPC/schema versioning"
    status: pending
  - id: auth-extensibility
    content: "Phase 6 — Stub path for Steam/Apple via same IPlatformAuth (no Storage rewrite)"
    status: pending
isProject: true
---

# Online server backend (Goofy Balls)

## Goals

- Cross-platform accounts with **one-click** platform login + **account linking**
- All **persistent data** in the cloud (with **offline-first** local disk)
- Leaderboards, matchmaker, **friend rooms with short codes**
- Primary targets: **Google Play** and **HTML5**
- Architecture: new platforms (Steam, Apple, …) plug in without rewriting core

Offline always works: **vs AI** and **local same-screen 2P** need no internet.

## Stack

| Layer | Choice |
|---|---|
| Backend | **Nakama** + Postgres (Docker / Heroic Cloud) |
| Client | `nakama-godot` + `NakamaMultiplayerBridge` |
| Game sync | Godot HLAPI `@rpc` over Nakama relay (authoritative later) |
| Local saves | Existing `SaveManager` → GodotSaves → `PData` (keep) |
| Cloud mirror | Nakama Storage / RPCs |

Do **not** split into Firebase Auth + custom lobby + Steam-only lobbies.

## Architecture

```
[Godot client]
  online/auth/*          ← IPlatformAuth adapters
  online/session         ← single Nakama session
  online/sync, rooms, mm
        │  REST + WebSocket (WSS for HTML)
        ▼
[Nakama]
  Auth (device, google, …)
  Storage (progress)
  Leaderboards
  Matchmaker / Matches
  Runtime modules (Go or TypeScript)
        │
        ▼
[Postgres]
```

**Extensibility rule:** Runtime and client key everything by Nakama `user_id`. Providers only matter at authenticate/link time. No per-platform Storage collections.

### Client auth contract

```
IPlatformAuth
  get_platform_id() -> "google" | "html_google" | "device" | "steam" | …
  authenticate(client) -> Session
  can_link() / link(session)
```

| Adapter | Platform | When |
|---|---|---|
| `DeviceAuth` | all (guest) | Phase 1 |
| `GoogleAuth` | Android + HTML | Phase 1–2 |
| `SteamAuth` / `AppleAuth` | later | same interface |

Placement (project conventions):

- `src/features/online/` — client feature (auth, mm, rooms, bridge)
- Cloud sync hooks next to `SaveManager` / `RootEvents.ev_save_progress`
- `core/` must not depend on Nakama

## Auth UX (modern)

- **Guest first** — play immediately; no registration wall
- Soft prompt on value: save across devices / online / ranked
- One-tap: Google (Play + HTML); Steam/Apple later
- Email+password is fallback only (prefer OTP/magic link if needed)
- Link/unlink providers in settings; never drop progress silently — merge UI

## Offline-first + cloud

```
progress change → PData → SaveManager disk → if online+session → cloud push
```

Boot: load disk first; pull/merge in background when online.

Conflict policy (Phase 2):

- `schema_version` required
- Additive counters: start with `max()` + timestamp; move to match-result log when needed
- Settings: last-write-wins by timestamp

| Mode | Internet |
|---|---|
| vs AI | no |
| Local 2P (same PC) | no |
| Room code / ranked | yes |
| Live leaderboard | yes |
| Cloud sync | yes for push/pull; play without it OK |

## Phases

### Phase 0 — Infra

- Docker Compose: Nakama + Postgres
- Envs: `dev` / `staging` / `prod` (separate Google OAuth clients)
- Secrets out of repo
- CI smoke: `/healthcheck`
- Postgres backups from first prod day

**Artifacts:** `docker-compose.yml`, `nakama.yml`, local run docs

### Phase 1 — Identity foundation

- Enable **device** + **Google** auth
- Google: separate OAuth clients for **Android** and **Web/HTML**; both in Nakama config
- Runtime RPCs: `health_ext`, `get_account_view`, `link_status`
- Client smoke: guest → session → account view
- **Done when:** Android and HTML can link to one `user_id`

### Phase 2 — Persistent data in cloud

Storage contract:

```
collection: "player"
key: "progress"
value: { ...PData..., "schema_version": 1, "updated_at": unix }
```

RPCs: `progress_pull`, `progress_push`, `progress_merge`

Prefer RPC writes over raw client Storage for validation.

**Done when:** offline match → disk → online merge → second client (HTML) sees wins

### Phase 3 — Leaderboard

- Leaderboard e.g. `global_wins` (ELO later)
- RPC `submit_match_result` (server-side): validate session; update aggregates + board
- Decide policy: vs_ai/local usually **not** on global ranked board
- Rate-limit client-submitted casual results

### Phase 4 — Rooms + matchmaker

Rooms first (friend codes):

| RPC | Behavior |
|---|---|
| `room_create` | match/party → code `A7K2`, TTL 30–60 min |
| `room_join` | code → match_id |
| `room_close` | host |

Rules: 2 players, case-insensitive code, brute-force rate limit.

Matchmaker: pool `ranked_1v1`, properties `skill` / `region`, count = 2.

Realtime: **relayed** via bridge first; stub authoritative `MatchInit`/`MatchLoop` for later.

**Done when:** Android creates code → HTML joins; separately two clients matchmake

### Phase 5 — Hardening

- Separate Google clients Play vs Web
- Rate limits on auth, room_join, progress_push, submit_match_result
- HTML: WSS only, restrict origins
- RPC / Storage schema versioning + migrations
- Staging + backups + no tokens in logs

### Phase 6 — More platforms (no core rewrite)

Checklist per provider (Steam / Apple / …):

1. Credentials in Nakama config
2. New `IPlatformAuth` adapter
3. Link/unlink docs
4. **Zero** new Storage collections
5. Smoke: guest → link → same `user_id` → progress/leaderboard intact

## Google Play + HTML emphasis

**Play:** Google Sign-In / Play Games → id token → Nakama; package + SHA-1; guest offline + sync on reconnect.

**HTML:** WSS only; Google Identity One Tap / button; separate Web Client ID; cloud sync critical (fragile local storage); large room-code UI.

Shared: one leaderboard, one progress schema, one room/matchmaker API.

## Backlog order

| # | Task | Depends |
|---|---|---|
| 1 | Compose + Nakama config + env | — |
| 2 | Runtime skeleton + CI smoke | 1 |
| 3 | Device + Google auth (Android & Web) | 1 |
| 4 | progress_pull/push/merge + schema_version | 2–3 |
| 5 | Leaderboard + submit_match_result | 4 |
| 6 | room_create/join + TTL/rate limit | 2–3 |
| 7 | Matchmaker ranked_1v1 | 6 |
| 8 | Relayed match smoke (2 clients) | 6–7 |
| 9 | Hardening, backups, staging | 4–8 |
| 10 | Stub authoritative match module | 8 |
| 11 | (Later) Steam/Apple adapters | Phase 1 contract |

## Explicitly out of MVP

- Separate auth + lobby + score microservices
- Dedicated Godot game servers
- Password registration as primary path
- Per-platform progress tables
- Blocking offline AI / local 2P on server availability

## MVP Definition of Done

1. Guest + Google login on **Android and HTML**
2. Link Google to guest → one `user_id`
3. Progress sync across two clients
4. Leaderboard (at least online wins)
5. 4–6 char room code for 2 players
6. Ranked 1v1 matchmaker
7. Staging + backups + env docs
8. Auth interface ready for Steam/Apple without Storage/RPC redesign

## Related project hooks

- Battle payload today: `{ "custom_battle": GameConfig }` (`vs_ai`); extend with online session data without breaking local FSM
- Progress writes: `RootEvents.ev_save_progress` → `SaveManager` (+ cloud sync side path)
- Scenes must still run alone offline (scene isolation)
