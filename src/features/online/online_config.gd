class_name OnlineConfig
extends Resource

## Where the Nakama server is. Defaults below → `res://online_local.tres` (an OnlineConfig with the
## developer's own server: git-ignored, exported with every build like any resource) →
## `user://online.cfg` (written when the player saves an address; an empty address removes it)
## → env vars GOOFY_NAKAMA_HOST / _PORT / _KEY.
## The server key must match NAKAMA_SERVER_KEY in server/.env.

const LOCAL_DEFAULTS_PATH := "res://online_local.tres"
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


var _build_host: String = ""
var _build_port: int = 0
var _build_key: String = ""


func load_overrides() -> void:
	if ResourceLoader.exists(LOCAL_DEFAULTS_PATH):
		var local := load(LOCAL_DEFAULTS_PATH) as OnlineConfig
		if local != null:
			host = local.host
			port = local.port
			server_key = local.server_key
			p2p_enabled = local.p2p_enabled
	_build_host = host
	_build_port = port
	_build_key = server_key
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
## An empty text forgets the saved address and goes back to the build's default.
func set_address(text: String) -> bool:
	var clean := text.strip_edges()
	if clean.is_empty():
		reset_address()
		return true
	var parts := clean.rsplit(":", true, 1)
	var new_host := parts[0].strip_edges()
	var new_port := port
	if parts.size() == 2:
		if not parts[1].is_valid_int():
			return false
		new_port = int(parts[1])
	if new_host.is_empty() or new_port <= 0 or new_port > 65535 or not _is_valid_host(new_host):
		return false
	host = new_host
	port = new_port
	var file := ConfigFile.new()
	file.load(OVERRIDE_PATH)
	file.set_value("nakama", "host", host)
	file.set_value("nakama", "port", port)
	file.save(OVERRIDE_PATH)
	return true


func reset_address() -> void:
	if _build_host.is_empty():
		_build_host = host
		_build_port = port
		_build_key = server_key
	host = _build_host
	port = _build_port
	server_key = _build_key
	var file := ConfigFile.new()
	if file.load(OVERRIDE_PATH) == OK and file.has_section("nakama"):
		file.erase_section("nakama")
		file.save(OVERRIDE_PATH)


## Digits-and-dots must be a full IPv4 address (catches typos like "127.0.01").
static func _is_valid_host(text: String) -> bool:
	if text.contains(" "):
		return false
	var looks_numeric := true
	for c in text:
		if not (c == "." or c.is_valid_int()):
			looks_numeric = false
			break
	return not looks_numeric or text.is_valid_ip_address()
