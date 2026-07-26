class_name GameEvents
extends Resource

@warning_ignore("unused_signal") signal ev_game_state_changed(from_state: String, to_state: String)
@warning_ignore("unused_signal") signal ev_score_changed(score_left: int, score_right: int)
@warning_ignore("unused_signal") signal ev_point_scored(side: int)
@warning_ignore("unused_signal") signal ev_match_over(winner_side: int)
@warning_ignore("unused_signal") signal ev_message(text: String)
