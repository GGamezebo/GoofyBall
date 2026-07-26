# Blobby Valley

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

Правила проекта: `.cursor/rules/`.
