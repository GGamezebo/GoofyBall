# Goofy Balls — project docs

Human-oriented documentation (diagrams, entity map, how systems fit).  
Agent rules (short must/never) live in [../rules/](../rules/).

| Doc | Contents |
|-----|----------|
| [architecture.md](architecture.md) | Layers, folders, contracts, high-level diagrams |
| [entities.md](entities.md) | Key types / Resources / scenes and who owns what |
| [navigation-hfsm.md](navigation-hfsm.md) | App HFSM, screens, RootEvents |
| [gameplay.md](gameplay.md) | Match FSM, scoring, features (blob / ball / AI / touch) |
| [online.md](online.md) | Nakama client, rooms/MM, CS listen-server sync |
| [server.md](server.md) | Docker, Lua modules, ports, smoke scripts |

Related:

- Plan: [../plans/online-server-backend.plan.md](../plans/online-server-backend.plan.md)
- Feature README: `src/features/online/README.md`
- Art (if present): `concepts/ART_DIRECTION.md`

## Maintenance

When structure, contracts, or flows change, update the **relevant** doc in the **same** task  
(see rule `maintain-architecture-rules.mdc`). Prefer patch over rewrite; keep diagrams truthful.
