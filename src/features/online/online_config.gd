class_name OnlineConfig
extends Resource

## Where the Nakama server is. Defaults below → `res://online_local.cfg` (developer's own server,
## git-ignored, shipped inside builds) → `user://online.cfg` (written when the player saves an
## address) → env vars GOOFY_NAKAMA_HOST / _PORT / _KEY. Both files: section [nakama] with
## host / port / server_key, optional [p2p] enabled.
## The server key must match NAKAMA_SERVER_KEY in server/.env.

const LOCAL_DEFAULTS_PATH := "res://online_local.cfg"
const OVERRIDE_PATH := "user://online.cfg"

@export var host: String = "127.0.0.1"
@export var port: int = 7350
@export var server_key: String = "goofyball_dev_key"
@export var use_ssl: bool = false
@export var timeout_sec: int = 5
@export_group("Direct link (WebRTC)")
## Play over a direct UDP link when it can be set up; the relay stays as the fallback.
@export var p2p_enabled: bool = true
## STUN servers help both sides find a path through home routers.
@export var stun_servers: PackedStringArray = ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]
## The host starts on the relay if the direct link is not open by then.
@export var p2p_timeout_sec: float = 4.0


func address() -> String:
	return "%s:%d" % [host, port]


func scheme() -> String:
	return "https" if use_ssl else "http"


func load_overrides() -> void:
	_apply_file(LOCAL_DEFAULTS_PATH)
	_apply_file(OVERRIDE_PATH)
	if not OS.get_environment("GOOFY_NAKAMA_HOST").is_empty():
		host = OS.get_environment("GOOFY_NAKAMA_HOST")
	if not OS.get_environment("GOOFY_NAKAMA_PORT").is_empty():
		port = int(OS.get_environment("GOOFY_NAKAMA_PORT"))
	if not OS.get_environment("GOOFY_NAKAMA_KEY").is_empty():
		server_key = OS.get_environment("GOOFY_NAKAMA_KEY")
	if OS.get_environment("GOOFY_P2P") == "0":
		p2p_enabled = false


func _apply_file(path: String) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	host = str(file.get_value("nakama", "host", host))
	port = int(file.get_value("nakama", "port", port))
	server_key = str(file.get_value("nakama", "server_key", server_key))
	p2p_enabled = bool(file.get_value("p2p", "enabled", p2p_enabled))


## Parses "host[:port]" and saves it; returns false when the text is not an address.
func set_address(text: String) -> bool:
	var clean := text.strip_edges()
	if clean.is_empty():
		return false
	var parts := clean.rsplit(":", true, 1)
	var new_host := parts[0].strip_edges()
	var new_port := port
	if parts.size() == 2:
		if not parts[1].is_valid_int():
			return false
		new_port = int(parts[1])
	if new_host.is_empty() or new_port <= 0 or new_port > 65535:
		return false
	host = new_host
	port = new_port
	var file := ConfigFile.new()
	file.load(OVERRIDE_PATH)
	file.set_value("nakama", "host", host)
	file.set_value("nakama", "port", port)
	file.save(OVERRIDE_PATH)
	return true
