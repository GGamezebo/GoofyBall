# Architecture principles (always)
Scenes:
- Every scene runs standalone (F6). Defaults live in an exported `.tres`; when the full game runs, the parent that instantiates the scene passes data via `initialize(data)`, which overrides the defaults (`ResourceUtils.update_resource`).
- Static UI (all elements known upfront) is authored in the `.tscn`, never built in code. Code only instantiates dynamic/repeated items.
HFSM:
- Large contexts, platforms, and features (onboarding, server-driven features) are separate scenes mounted by HFSM states.
- Each HFSM scene keeps its main game events as Resources.
Components:
- Follow SOLID. Split big objects into small components along logical boundaries.
- A component never holds a reference to its parent. The parent creates children (Godot scene tree), calls their methods directly, and subscribes to their `ev_*` signals; children only emit.
- Prefer reusable components, but no over-engineering (no abstraction without a second use).
- Project-agnostic code goes to `core/` as reusable utilities for future projects.
Misc:
- Follow Godot best practices (scene composition, signals up / calls down, typed GDScript, `@export`).
- No singletons (incl. autoloads and static global state); only third-party plugins may bring them.
