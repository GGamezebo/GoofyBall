class_name OnlineEndpoints
extends RefCounted

## LAN Nakama endpoints for local multiplayer testing (PC + phones).
## Change HOST when your PC's Wi‑Fi IP changes (`ipconfig`).

const HOST := "192.168.1.71"
const PORT := 7350
const CONSOLE_PORT := 7351
const SCHEME := "http"
const SERVER_KEY := "goofyballs_dev_server_key"


static func base_url() -> String:
	return "%s://%s:%d" % [SCHEME, HOST, PORT]


static func console_url() -> String:
	return "%s://%s:%d" % [SCHEME, HOST, CONSOLE_PORT]
