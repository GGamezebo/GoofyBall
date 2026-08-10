extends Node

## F6 smoke: device auth → health_ext → get_account_view. Requires local Nakama.

@export var config: OnlineConfig

@onready var _service: OnlineService = $OnlineService


func _ready() -> void:
	if config:
		_service.config = config
	print("[online_smoke] starting…")
	await get_tree().process_frame
	var session := await _service.authenticate_guest_async()
	if session == null:
		push_error("[online_smoke] auth failed")
		return
	print("[online_smoke] user_id=", session.user_id, " platform=", session.platform_id)
	var health := await _service.health_ext_async()
	print("[online_smoke] health_ext=", health)
	var view := await _service.refresh_account_view_async()
	print("[online_smoke] account_view=", view)
	print("[online_smoke] OK")
