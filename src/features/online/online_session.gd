class_name OnlineSession
extends RefCounted

## Thin game-facing session wrapper over NakamaSession.

var user_id: String = ""
var username: String = ""
var token: String = ""
var refresh_token: String = ""
var expires_at_unix: int = 0
var platform_id: String = ""
## Underlying SDK session — used by OnlineClient / OnlineRealtime.
var nakama_session: NakamaSession = null


func is_valid() -> bool:
	if nakama_session != null:
		return nakama_session.valid and not nakama_session.is_expired()
	if token.is_empty() or user_id.is_empty():
		return false
	if expires_at_unix <= 0:
		return true
	return Time.get_unix_time_from_system() < expires_at_unix - 30


static func from_nakama(nk: NakamaSession, p_platform_id: String = "") -> OnlineSession:
	var s := OnlineSession.new()
	if nk == null or nk.is_exception() or not nk.valid:
		return s
	s.nakama_session = nk
	s.token = nk.token
	s.refresh_token = nk.refresh_token
	s.user_id = nk.user_id
	s.username = nk.username
	s.expires_at_unix = nk.expire_time
	s.platform_id = p_platform_id
	return s
