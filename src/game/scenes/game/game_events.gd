class_name GameEvents
extends Resource

## Battle context events (shared `.tres` inside the battle). The game scene emits,
## the HUD and other battle widgets listen. Nothing outside the battle uses them.

## Per-team names and colors, local teams, online or not.
@warning_ignore("unused_signal")
signal ev_match_started(info: Dictionary)
@warning_ignore("unused_signal")
signal ev_score_changed(scores: Array)
## A team scored; `reason` = VolleySim.Reason.
@warning_ignore("unused_signal")
signal ev_point(team: int, reason: int)
## Final whistle in the sim (before the results screen).
@warning_ignore("unused_signal")
signal ev_match_over(winner_team: int)
## Short status line ("" hides it).
@warning_ignore("unused_signal")
signal ev_status(text: String)
## HUD → game.
@warning_ignore("unused_signal")
signal ev_pause_requested
@warning_ignore("unused_signal")
signal ev_resume_requested
@warning_ignore("unused_signal")
signal ev_exit_requested
