class_name OnlineConfig
extends Resource

## Connection settings for Nakama. Defaults from OnlineEndpoints; parents may override.

@export var host: String = OnlineEndpoints.host()
@export var port: int = OnlineEndpoints.port()
@export var server_key: String = OnlineEndpoints.server_key()
@export var use_ssl: bool = false
@export var scheme: String = OnlineEndpoints.scheme()
## AUTO picks Device / Google / Steam / Yandex from OS features.
@export var preferred_platform: OnlinePlatforms.Kind = OnlinePlatforms.Kind.AUTO
@export var auto_authenticate_on_ready: bool = false
@export var request_timeout_sec: float = 15.0
## Nakama Console (HTTP).
@export var console_port: int = OnlineEndpoints.console_port()


func base_url() -> String:
	var s := scheme.strip_edges()
	if s.is_empty():
		s = "https" if use_ssl else "http"
	return "%s://%s:%d" % [s, host, port]


func console_url() -> String:
	var s := scheme.strip_edges()
	if s.is_empty():
		s = "https" if use_ssl else "http"
	return "%s://%s:%d" % [s, host, console_port]
