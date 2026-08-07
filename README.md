# Goofy Balls

Лёгкий прототип side-view волейбола на рельсах **quizmatik**: HFSM + FSM + GodotSavesAddon.

## Запуск

Откройте проект в Godot 4.7+ → **F5**.

## Меню

- **Play Together** — двое на одном экране
- **Play vs AI** — бот справа (красный)
- **Esc** в матче — в меню

## Управление

| Игрок | Ход | Прыжок |
|-------|-----|--------|
| Синий / вы | `A` / `D` | `W` |
| Красный | `←` / `→` | `↑` |

## Архитектура

```
main.tscn → HFSM (App → Menu | Battle | PostBattle)
src/game/scenes/     orchestration
src/features/        blob_player, ball, ai_opponent
src/common/          GameConfig
core/lib/            hfsm, fsm, EventListener, ResourceUtils
addons/GodotSavesAddon
```

Матч: `GameManager` FSM `Serve → Play → Point → (Serve | MatchEnd)`.

Прогресс: `PData` через `SaveManager` + `RootEvents.ev_save_progress`.

## Backend (online)

Локальный Nakama + Postgres: см. [`server/README.md`](server/README.md).

```powershell
cd server
copy .env.example .env   # первый раз
docker compose up -d
.\scripts\smoke.ps1
```

Правила проекта: `.cursor/rules/`.
План online: `.cursor/plans/online-server-backend.plan.md`.
