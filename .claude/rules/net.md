---
paths:
  - "src/features/online/**"
  - "server/**"
---
# Online / server
- Clients send inputs only `{x:-100..100, j, a}`; never positions/score.
- MatchSession: Local | Rollback (SyncManager; transport per message: P2P if ready, else Nakama relay) | Authoritative (future, same sim headless). Game code session-agnostic.
- Friend rooms: rollback traffic over WebRTC P2P (UDP, `WebRTCTransport`, webrtc-native GDExtension); signaling, room RPCs and fallback over the relay. P2P link reaches the battle via `NetLink` (.tres).
- Server owns: seed, MatchSetup, tick numbering, input log (rated), result + rating (Glicko-2).
- One matchmaking queue, always rated (stake from rating gap); no separate casual/ranked queues, no cups.
- Rated formats: 1×1 and 2×2 (party, or two solos after 20 s); one shared rating, 2×2 stake from team average. Rated conditions fixed: Classic + weekly rule, to 7, random arena from the rated pool. 3×3 / 3+ teams: rooms and AI only.
- Queue (rated) matches always relay (server input log, hidden IPs); P2P only for friend rooms.
- Cost: inputs 30Hz×2 ticks, protobuf, relayed by default; authoritative handler only for disputed rated matches.
- Reuse: `server/` + nakama addon from branch `prototype-3d`; `online_rollback.gd` from `claude/mobile-game-build-run-le59yg`.
