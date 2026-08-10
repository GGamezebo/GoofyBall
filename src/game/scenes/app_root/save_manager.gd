extends Node

const SAVE_DEBOUNCE_SEC := 4.0
const PROFILE: String = "save"

@export var _pdata: PData
@export var _root_events: RootEvents
## Optional Phase 2 cloud sync — leave empty for pure offline.
@export var _online_service: OnlineService

@onready var _save = $Save

var _dirty: bool = false
var _in_battle: bool = false
var _shutting_down: bool = false
var _debounce_timer: Timer
var _skip_cloud_once: bool = false


func _ready() -> void:
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_debounce_timer.timeout.connect(_flush)
	add_child(_debounce_timer)

	load_pdata()
	_root_events.ev_reset_account_progress.connect(_on_reset_account_progress)
	_root_events.ev_save_progress.connect(save)
	_root_events.ev_battle_started.connect(_on_battle_started)
	_root_events.ev_battle_finished.connect(_on_battle_finished)
	if _online_service:
		_online_service.ev_progress_synced.connect(_on_cloud_progress_synced)


func save_pdata() -> void:
	_save.save_data(_pdata.to_dict(), PROFILE)


func load_pdata() -> void:
	var dict: Dictionary = _save.edit_data(PROFILE)
	_pdata.apply_dict(dict)


func save() -> void:
	_dirty = true
	if _shutting_down:
		_flush()
		return
	if _in_battle:
		return
	_debounce_timer.start(SAVE_DEBOUNCE_SEC)


func _flush() -> void:
	if not _dirty:
		return
	_write_to_disk()


func _write_to_disk() -> void:
	_dirty = false
	if _debounce_timer:
		_debounce_timer.stop()
	save_pdata()
	if _skip_cloud_once:
		_skip_cloud_once = false
		return
	_request_cloud_sync()


func _request_cloud_sync() -> void:
	if _online_service == null or not is_instance_valid(_online_service):
		return
	_online_service.push_progress_after_local_save()


func _on_cloud_progress_synced(_progress: Dictionary) -> void:
	# Shared PData already updated by OnlineService — persist disk only.
	_skip_cloud_once = true
	_dirty = true
	_write_to_disk()


func _on_battle_started() -> void:
	_in_battle = true


func _on_battle_finished() -> void:
	_in_battle = false
	_flush.call_deferred()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			_shutting_down = true
			_flush()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_flush()


func _on_reset_account_progress() -> void:
	_pdata.reset_to_defaults()
	_write_to_disk()
