# Goofy Balls

Лёгкий прототип side-view волейбола на рельсах **quizmatik**: HFSM + детерминированная симуляция + rollback netcode + GodotSavesAddon.

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
src/game/scenes/     orchestration (game.gd → MatchRunner → VolleySim, MatchView рисует состояние)
src/features/        volley_sim, blob_view, ball_view, ai_opponent, player_input, virtual_controls, online
src/common/          GameConfig
core/lib/            hfsm, fsm, EventListener, ResourceUtils
addons/              GodotSavesAddon, nakama, godot-rollback-netcode
tests/               headless-тесты (запускаются в CI)
```

Матч целиком — детерминированная симуляция `VolleySim` (фазы `Serve → Play → Point → (Serve | MatchEnd)`),
60 тиков/с, без движковой физики. Онлайн: оба клиента гоняют одну и ту же симуляцию и обмениваются
только вводом; при позднем вводе `SyncManager` откатывается и пересчитывает (rollback netcode).
Подробности: `.cursor/docs/simulation.md`, `.cursor/docs/online.md`.

Прогресс: `PData` через `SaveManager` + `RootEvents.ev_save_progress`.

## Тесты

```
godot --headless --path . --script res://tests/run_all.gd
```

CI (GitHub Actions) прогоняет тесты и собирает debug-APK (артефакт `goofy-balls-apk`).

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
