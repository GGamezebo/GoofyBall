class_name NetTuning
extends Resource

## Rollback knobs applied to SyncManager when an online match starts. Tune by playtests:
## more input delay = fewer rollbacks but a laggier own blob; bigger buffer = survives
## worse ping before the game has to stall.

## Local input is applied this many ticks later (2 ticks ≈ 33 ms).
@export_range(0, 10) var input_delay: int = 2
## Max ticks kept for rollback (60 ticks = 1 s). Phone Wi-Fi often stalls for 0.2–1 s:
## inside the buffer that is a catch-up rollback, beyond it the game has to freeze.
@export_range(4, 120) var max_buffer_size: int = 60
## Ticks of history used to compute who is ahead (time sync).
@export_range(10, 600) var ticks_to_calculate_advantage: int = 60
## Unacknowledged input ticks resent in every message (covers lost packets).
@export_range(1, 60) var max_input_frames_per_message: int = 5
## Messages per tick to a peer that fell behind: 5 × 5 = 25 ticks of catch-up at once.
@export_range(1, 10) var max_messages_at_once: int = 5
## While sync is lost every unacknowledged input is resent each tick (frames × messages
## ≥ buffer + stall), so a peer that missed a stretch catches up in one round trip.
@export_range(1, 60) var recovery_frames_per_message: int = 20
@export_range(1, 20) var recovery_messages_at_once: int = 8
## After this many ticks without regaining sync the match is aborted (600 ticks = 10 s).
@export_range(30, 1200) var max_ticks_to_regain_sync: int = 600
@export_range(1, 60) var min_lag_to_regain_sync: int = 5
## Consecutive state hash mismatches before the match is treated as desynced.
@export_range(1, 60) var max_state_mismatch_count: int = 10
## A lost-sync freeze shorter than this is not announced on screen (it is still logged).
@export var unstable_notice_sec: float = 0.4
## Seconds to wait for the opponent's scene before giving up.
@export var handshake_timeout_sec: float = 15.0


func apply_to(sync_manager: Node) -> void:
	sync_manager.input_delay = input_delay
	sync_manager.max_buffer_size = max_buffer_size
	sync_manager.ticks_to_calculate_advantage = ticks_to_calculate_advantage
	sync_manager.max_input_frames_per_message = max_input_frames_per_message
	sync_manager.max_messages_at_once = max_messages_at_once
	sync_manager.max_ticks_to_regain_sync = max_ticks_to_regain_sync
	sync_manager.min_lag_to_regain_sync = min_lag_to_regain_sync
	sync_manager.max_state_mismatch_count = max_state_mismatch_count
	sync_manager.interpolation = false
