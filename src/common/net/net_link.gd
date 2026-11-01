class_name NetLink
extends Resource

## Live hand-over between the App/Online context and the battle (shared `.tres`, like
## PlatformCaps): the online context puts the room's direct transport here, the battle gives it
## to the rollback session. Null = relay only.

var transport: PeerTransport
