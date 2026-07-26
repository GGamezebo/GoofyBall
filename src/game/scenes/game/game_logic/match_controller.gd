class_name MatchController
extends Node

## Owns score, serve side, touch faults, and court resets. Driven by GameManager FSM.

signal ev_point_scored(side: int)

@export var game_events: GameEvents
@export var ball: RigidBody3D
@export var player_left: CharacterBody3D
@export var player_right: CharacterBody3D

var game_config: GameConfig
var score_left: int = 0
var score_right: int = 0
var serving_left: bool = true
var round_active: bool = false
var _match_finished: bool = false
## Consecutive touches on the current side (resets when the other side hits).
var _touch_side: int = -1
var _touch_count: int = 0
## Optional override for the next apply_point() banner.
var pending_point_message: String = ""


func initialize(config: GameConfig) -> void:
	game_config = config
	score_left = 0
	score_right = 0
	serving_left = true
	round_active = false
	_match_finished = false
	pending_point_message = ""
	_reset_touches()
	if ball:
		if ball.has_signal("landed") and not ball.landed.is_connected(_on_ball_landed):
			ball.landed.connect(_on_ball_landed)
		if ball.has_signal("touched") and not ball.touched.is_connected(_on_ball_touched):
			ball.touched.connect(_on_ball_touched)
	_emit_score()


func set_round_active(active: bool) -> void:
	round_active = active


## Place players and hold the ball frozen mid-air until release_serve().
func begin_serve() -> void:
	round_active = false
	_reset_touches()
	_reset_actors()


func apply_point(side: int) -> void:
	if side == 0:
		score_right += 1
		serving_left = false
	else:
		score_left += 1
		serving_left = true

	if game_events:
		var msg := pending_point_message
		pending_point_message = ""
		if msg.is_empty():
			msg = "Point for Red!" if side == 0 else "Point for Blue!"
		game_events.ev_message.emit(msg)
		game_events.ev_point_scored.emit(side)
	_emit_score()


## Round clock hit zero: explode ball; side under the ball loses.
func resolve_timeout_explosion() -> void:
	if not round_active or _match_finished:
		return
	round_active = false
	_reset_touches()

	var side := 0
	if ball:
		side = 0 if ball.global_position.x < 0.0 else 1
		if ball is Ball:
			(ball as Ball).explode()
		elif "freeze" in ball:
			ball.freeze = true

	var who := "Blue" if side == 0 else "Red"
	if game_config and game_config.vs_ai:
		who = "You" if side == 0 else "AI"
	pending_point_message = "Time's up! %s exploded!" % who
	ev_point_scored.emit(side)


func is_match_over() -> bool:
	if game_config == null:
		return false
	return score_left >= game_config.win_score or score_right >= game_config.win_score


func get_winner_side() -> int:
	if score_left > score_right:
		return 0
	if score_right > score_left:
		return 1
	return -1


func finish_match(winner_side: int) -> void:
	_match_finished = true
	round_active = false
	if game_events:
		var winner_name := "Blue" if winner_side == 0 else "Red"
		if game_config and game_config.vs_ai:
			winner_name = "You" if winner_side == 0 else "AI"
		game_events.ev_message.emit("%s wins!" % winner_name)
		game_events.ev_match_over.emit(winner_side)


func build_result_payload() -> Dictionary:
	return {
		"game_config": game_config,
		"score_left": score_left,
		"score_right": score_right,
		"winner_side": get_winner_side(),
		"vs_ai": game_config.vs_ai if game_config else false,
	}


func _on_ball_landed(side: int) -> void:
	if not round_active or _match_finished:
		return
	ev_point_scored.emit(side)


func _on_ball_touched(side: int) -> void:
	if not round_active or _match_finished:
		return

	if side != _touch_side:
		_touch_side = side
		_touch_count = 1
	else:
		_touch_count += 1

	var max_touches: int = game_config.max_touches if game_config else 3
	if _touch_count > max_touches:
		_fault_too_many_touches(side)


func _fault_too_many_touches(side: int) -> void:
	# Same convention as floor land: the faulting side "loses" the rally.
	round_active = false
	_reset_touches()
	if ball and "freeze" in ball:
		ball.freeze = true
	if game_events:
		var who := "Blue" if side == 0 else "Red"
		if game_config and game_config.vs_ai:
			who = "You" if side == 0 else "AI"
		game_events.ev_message.emit("%s: too many touches!" % who)
	ev_point_scored.emit(side)


func _reset_touches() -> void:
	_touch_side = -1
	_touch_count = 0


func _reset_actors() -> void:
	if player_left:
		player_left.global_position = Vector3(-3.2, 0.42, 0.0)
		player_left.velocity = Vector3.ZERO
	if player_right:
		player_right.global_position = Vector3(3.2, 0.42, 0.0)
		player_right.velocity = Vector3.ZERO

	if ball and ball.has_method("hold_ball"):
		var serve_x := -2.2 if serving_left else 2.2
		var height := game_config.serve_height if game_config else 5.0
		ball.hold_ball(Vector3(serve_x, height, 0.0))


func _emit_score() -> void:
	if game_events:
		game_events.ev_score_changed.emit(score_left, score_right)


## Called when entering Play: the held ball simply drops.
func release_serve() -> void:
	_reset_touches()
	if ball and ball.has_method("release_ball"):
		ball.release_ball()
	round_active = true
	if game_events:
		game_events.ev_message.emit("")
