class_name CorrectionSmoother
extends RefCounted

## Rollback corrections as on-screen offsets that fade out, so what was drawn stays continuous
## and glides to the corrected place:
## - small fixes fade with `tau` (≈ gone in 0.1 s);
## - big ones never move faster than `max_speed`, so a deep rollback reads as fast motion, not a jump
##   (2 m ≈ 0.27 s, 4 m ≈ 0.37 s).

var tau: float = 0.035
var max_speed: float = 25.0

var _offsets: Array[Vector2] = []


func resize(count: int) -> void:
	_offsets.resize(count)
	clear()


## Keeps a jump of `jump` (old − new place) as an offset added on top of earlier ones.
func add(index: int, jump: Vector2) -> void:
	_offsets[index] += jump


func offset(index: int) -> Vector2:
	return _offsets[index]


## Real teleports (a new serve) are shown as they are.
func clear() -> void:
	_offsets.fill(Vector2.ZERO)


func step(delta: float) -> void:
	for i in _offsets.size():
		var length := _offsets[i].length()
		if length < 0.0001:
			_offsets[i] = Vector2.ZERO
			continue
		# d|e|/dt = −|e| / (tau + |e| / max_speed): exponential when small, ≤ max_speed when big.
		_offsets[i] *= exp(-delta / (tau + length / max_speed))
