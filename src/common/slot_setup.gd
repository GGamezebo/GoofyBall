class_name SlotSetup
extends Resource

## One player slot in a team. Where its input comes from is data, not code:
## `peer_id` = network peer that owns the slot (0 = this machine), `local_input` = InputMap
## prefix on this machine (`p1`, `p2`; empty = remote or bot), `is_bot` = AI drives it.

@export var player_id: String = ""
@export var display_name: String = ""
@export var character_id: StringName = &"blob"
@export var is_bot: bool = false
@export var peer_id: int = 0
@export var local_input: StringName = &""
