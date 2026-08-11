class_name DevAccounts
extends RefCounted

## Fixed guest/device accounts for local multi-client testing.
## Pick one in the Menu dropdown — Nakama creates the account on first login.

const ACCOUNTS: Array[Dictionary] = [
	{
		"label": "Player A",
		"device_id": "gd_dev_account_player_a_01",
		"username": "PlayerA",
	},
	{
		"label": "Player B",
		"device_id": "gd_dev_account_player_b_02",
		"username": "PlayerB",
	},
	{
		"label": "Player C",
		"device_id": "gd_dev_account_player_c_03",
		"username": "PlayerC",
	},
	{
		"label": "Player D",
		"device_id": "gd_dev_account_player_d_04",
		"username": "PlayerD",
	},
]


static func count() -> int:
	return ACCOUNTS.size()


static func get_account(index: int) -> Dictionary:
	if index < 0 or index >= ACCOUNTS.size():
		return ACCOUNTS[0] if not ACCOUNTS.is_empty() else {}
	return ACCOUNTS[index]


static func device_id(index: int) -> String:
	return str(get_account(index).get("device_id", ""))


static func username(index: int) -> String:
	return str(get_account(index).get("username", ""))


static func label(index: int) -> String:
	return str(get_account(index).get("label", "Player"))
