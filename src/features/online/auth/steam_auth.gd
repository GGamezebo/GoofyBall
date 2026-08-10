class_name SteamAuth
extends PlatformAuth

## Steam session ticket → Nakama authenticate_steam / link_steam.
## Requires GodotSteam (or equivalent) to mint the ticket; Phase 1 accepts injection.

var _session_ticket: String = ""


func get_platform_id() -> String:
	return "steam"


func set_session_ticket(ticket: String) -> void:
	_session_ticket = ticket.strip_edges()


func can_authenticate() -> bool:
	if not _session_ticket.is_empty():
		return true
	# Optional singleton from GodotSteam when the addon is present.
	return Engine.has_singleton("Steam")


func authenticate_async() -> OnlineSession:
	if client == null:
		await _yield_frame()
		return null
	var ticket := _resolve_ticket()
	if ticket.is_empty():
		await _yield_frame()
		return null
	return await client.authenticate_steam_async(ticket, true)


func link_async() -> bool:
	if client == null or not client.has_session():
		await _yield_frame()
		return false
	var ticket := _resolve_ticket()
	if ticket.is_empty():
		await _yield_frame()
		return false
	await client.link_steam_async(ticket)
	return true


func _resolve_ticket() -> String:
	if not _session_ticket.is_empty():
		return _session_ticket
	if not Engine.has_singleton("Steam"):
		return ""
	# GodotSteam API varies by version; keep soft-fail until wired in export.
	return ""
