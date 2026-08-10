class_name OnlineConfig
extends Resource

## Connection settings for Nakama. Scene/feature ships defaults; parents override.

@export var host: String = "127.0.0.1"
@export var port: int = 7350
@export var server_key: String = "goofyballs_dev_server_key"
@export var use_ssl: bool = false
@export var scheme: String = "http"
## AUTO picks Device / Google / Steam / Yandex from OS features.
@export var preferred_platform: OnlinePlatforms.Kind = OnlinePlatforms.Kind.AUTO
@export var auto_authenticate_on_ready: bool = false
@export var request_timeout_sec: float = 15.0


func base_url() -> String:
	var s := scheme.strip_edges()
	if s.is_empty():
		s = "https" if use_ssl else "http"
	return "%s://%s:%d" % [s, host, port]
