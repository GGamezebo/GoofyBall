class_name RootEvents
extends Resource

## App-wide events (shared `.tres`, no autoload). AppRoot bridges them into the HFSM.

## Payload: {"match_setup": MatchSetup}.
@warning_ignore("unused_signal")
signal ev_start_game(data: Dictionary)
## Payload: match result (see game.gd `_build_result`).
@warning_ignore("unused_signal")
signal ev_exit_game(data: Dictionary)
@warning_ignore("unused_signal")
signal ev_return_to_menu(data: Dictionary)
