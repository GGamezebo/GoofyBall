class_name PlatformAuthFactory
extends RefCounted

## Builds the right PlatformAuth for host / preferred kind.


static func create(client: OnlineClient, preferred: OnlinePlatforms.Kind = OnlinePlatforms.Kind.AUTO) -> PlatformAuth:
	var kind := preferred
	if kind == OnlinePlatforms.Kind.AUTO:
		kind = OnlinePlatforms.detect_host_kind()
	match kind:
		OnlinePlatforms.Kind.GOOGLE_ANDROID:
			return GoogleAuth.new(client, "google_android")
		OnlinePlatforms.Kind.GOOGLE_WEB:
			return GoogleAuth.new(client, "google_web")
		OnlinePlatforms.Kind.STEAM:
			return SteamAuth.new(client)
		OnlinePlatforms.Kind.YANDEX:
			return YandexAuth.new(client)
		_:
			return DeviceAuth.new(client)


static func create_device(client: OnlineClient) -> DeviceAuth:
	return DeviceAuth.new(client)
