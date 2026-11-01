# Goofy Ball

Онлайн-волейбол слаймов в духе Blobby Volley, где каждый розыгрыш превращается в безумие из бафов и событий. Godot 4.7, 2D, сначала мобильные, затем веб и PC.

> Статус: итерация 1 — сетевой срез: против AI, вдвоём на одном ПК, с другом по коду комнаты через свой сервер Nakama. Как играть и проверять — [`docs/iteration-1.md`](docs/iteration-1.md).

![Concept](concept/gameplay.png)

## Документация

| Что | Где |
|---|---|
| Геймдизайн, бафы, режимы, монетизация | [`docs/design/GDD.md`](docs/design/GDD.md) |
| Архитектура симуляции, сети и сервера | [`docs/tech/architecture.md`](docs/tech/architecture.md) |
| Итерации разработки | [`docs/roadmap.md`](docs/roadmap.md) |
| Итерация 1: что сделано и как пользоваться | [`docs/iteration-1.md`](docs/iteration-1.md) |
| Свой сервер Nakama | [`server/README.md`](server/README.md) |
| Арт-направление и концепты | [`concept/art-direction.md`](concept/art-direction.md) |
| Правила кода для Claude Code | [`.claude/rules/`](.claude/rules/) |

## Быстрый старт

1. Установить [Godot 4.7](https://godotengine.org/) и [Git LFS](https://git-lfs.com/).
2. `git lfs install`, затем `git clone https://github.com/GGamezebo/GoofyBall.git`.
3. Открыть проект в Godot 4.7.1 и нажать F5. Каждая сцена запускается отдельно по F6.
4. Тесты: `godot --headless --path . --script res://tests/run_all.gd`.
5. Игра с другом: поднять сервер ([`server/README.md`](server/README.md)), в игре «С другом» → адрес сервера → «Создать» / «Войти по коду».

## Участие в разработке

См. [CONTRIBUTING.md](CONTRIBUTING.md): ветки, коммиты, Pull Request.

Старый 3D-прототип — ветка `prototype-3d`.
