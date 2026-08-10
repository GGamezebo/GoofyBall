class_name OnlineProgress
extends RefCounted

## Cloud progress blob helpers — mirrors server merge policy (max on counters).

const SCHEMA_VERSION := 1
const ADDITIVE_KEYS: Array[String] = [
	"matches_played",
	"wins_two_player",
	"wins_vs_ai",
	"losses_vs_ai",
]


static func wrap_pdata(pdata: PData) -> Dictionary:
	var d: Dictionary = {}
	if pdata != null:
		d = pdata.to_dict()
	d["schema_version"] = SCHEMA_VERSION
	d["updated_at"] = int(Time.get_unix_time_from_system())
	return sanitize(d)


static func apply_to_pdata(pdata: PData, blob: Dictionary) -> void:
	if pdata == null or blob.is_empty():
		return
	pdata.apply_dict(blob)


static func merge(local_blob: Dictionary, remote_blob: Dictionary) -> Dictionary:
	var a := sanitize(local_blob)
	var b := sanitize(remote_blob)
	var out := {
		"schema_version": SCHEMA_VERSION,
		"updated_at": maxi(a.get("updated_at", 0), maxi(b.get("updated_at", 0), int(Time.get_unix_time_from_system()))),
	}
	for key in ADDITIVE_KEYS:
		out[key] = maxi(int(a.get(key, 0)), int(b.get(key, 0)))
	return out


static func sanitize(input: Dictionary) -> Dictionary:
	var out := {
		"schema_version": SCHEMA_VERSION,
		"updated_at": int(input.get("updated_at", 0)),
		"matches_played": maxi(0, int(input.get("matches_played", 0))),
		"wins_two_player": maxi(0, int(input.get("wins_two_player", 0))),
		"wins_vs_ai": maxi(0, int(input.get("wins_vs_ai", 0))),
		"losses_vs_ai": maxi(0, int(input.get("losses_vs_ai", 0))),
	}
	if int(out["updated_at"]) <= 0:
		out["updated_at"] = int(Time.get_unix_time_from_system())
	return out
