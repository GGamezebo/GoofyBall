class_name ButtonWindowBack
extends Node

## Back navigation: pressing button pops the current window via WindowStackManager.
## Prefer this over opening MainMenu directly — the stack restores the previous window.

@export var button: BaseButton
