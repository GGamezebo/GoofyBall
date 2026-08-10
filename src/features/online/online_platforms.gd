class_name OnlinePlatforms
extends RefCounted

## Stable platform ids — match server/provider naming, not store brands.

enum Kind {
	AUTO,
	DEVICE,
	GOOGLE_ANDROID,
	GOOGLE_WEB,
	STEAM,
	YANDEX,
}


static func kind_to_id(kind: Kind) -> String:
	match kind:
		Kind.DEVICE:
			return "device"
		Kind.GOOGLE_ANDROID:
			return "google_android"
		Kind.GOOGLE_WEB:
			return "google_web"
		Kind.STEAM:
			return "steam"
		Kind.YANDEX:
			return "yandex"
		_:
			return "device"


static func detect_host_kind() -> Kind:
	# Yandex Games HTML builds should set this feature / custom flag in export.
	if OS.has_feature("yandex_games") or OS.has_feature("yandex"):
		return Kind.YANDEX
	if OS.has_feature("steam"):
		return Kind.STEAM
	if OS.has_feature("android"):
		return Kind.GOOGLE_ANDROID
	if OS.has_feature("web"):
		# Default HTML export: Google Identity. Override to Yandex via feature tag.
		return Kind.GOOGLE_WEB
	return Kind.DEVICE
