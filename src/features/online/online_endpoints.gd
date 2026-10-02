class_name OnlineEndpoints
extends RefCounted

## Nakama endpoints. Defaults target a local server; override per device without
## touching the repo:
##   1. env `GOOFY_NAKAMA_HOST` / `GOOFY_NAKAMA_PORT` / `GOOFY_NAKAMA_KEY`
##   2. `user://online.cfg` → [nakama] host / port / server_key
## On a phone, point `host` at your PC's LAN IP (`ipconfig`) or a public server.

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 7350
const DEFAULT_CONSOLE_PORT := 7351
const DEFAULT_SCHEME := "http"
## Must match NAKAMA_SERVER_KEY in server/.env.
const DEFAULT_SERVER_KEY := "goofyballs_dev_server_key"
const USER_CONFIG_PATH := "user://online.cfg"


static func host() -> String:
	return _read("host", "GOOFY_NAKAMA_HOST", DEFAULT_HOST)


static func port() -> int:
	return int(_read("port", "GOOFY_NAKAMA_PORT", str(DEFAULT_PORT)))


static func console_port() -> int:
	return DEFAULT_CONSOLE_PORT


static func scheme() -> String:
	return DEFAULT_SCHEME


static func server_key() -> String:
	return _read("server_key", "GOOFY_NAKAMA_KEY", DEFAULT_SERVER_KEY)


static func base_url() -> String:
	return "%s://%s:%d" % [scheme(), host(), port()]


static func console_url() -> String:
	return "%s://%s:%d" % [scheme(), host(), console_port()]


static func _read(key: String, env_name: String, fallback: String) -> String:
	var from_env := OS.get_environment(env_name)
	if not from_env.is_empty():
		return from_env
	var cfg := ConfigFile.new()
	if cfg.load(USER_CONFIG_PATH) == OK and cfg.has_section_key("nakama", key):
		return str(cfg.get_value("nakama", key))
	return fallback
