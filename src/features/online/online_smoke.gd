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
	var progress := await _service.sync_progress_async({
		"matches_played": 1,
		"wins_two_player": 0,
		"wins_vs_ai": 1,
		"losses_vs_ai": 0,
		"schema_version": 1,
		"updated_at": int(Time.get_unix_time_from_system()),
	})
	print("[online_smoke] progress_merge=", progress)
	var ranked := await _service.submit_match_result_async({
		"mode": "ranked",
		"winner_side": 0,
		"local_side": 0,
		"score_left": 5,
		"score_right": 2,
	})
	print("[online_smoke] submit_match_result=", ranked)
	var board := await _service.fetch_leaderboard_top_async(5)
	print("[online_smoke] leaderboard_top=", board)
	print("[online_smoke] OK")
