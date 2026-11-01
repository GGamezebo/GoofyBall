class_name PlatformCaps
extends Resource

## What the running platform allows. Written only by platform HFSM contexts,
## read by game UI (shared live `.tres`). Defaults = most restrictive (mobile).

@export var local_multiplayer: bool = false
