extends TestCase

## Rollback correction offsets: small ones vanish fast, big ones glide at a capped speed.

const FRAME := 1.0 / 60.0


func test_small_correction_fades_fast() -> void:
	var smoother := _smoother(1)
	smoother.add(0, Vector2(0.2, 0.0))
	expect(_seconds_to_fade(smoother) <= 0.12, "0.2 m is gone within 0.12 s")


func test_big_correction_glides() -> void:
	var smoother := _smoother(1)
	smoother.add(0, Vector2(-3.0, 1.0))
	var previous := smoother.offset(0).length()
	var fastest := 0.0
	var seconds := 0.0
	while smoother.offset(0).length() > 0.01 and seconds < 2.0:
		smoother.step(FRAME)
		seconds += FRAME
		var length := smoother.offset(0).length()
		fastest = maxf(fastest, (previous - length) / FRAME)
		previous = length
	expect(fastest <= smoother.max_speed, "never faster than max_speed (got %.1f m/s)" % fastest)
	expect(seconds > 0.2 and seconds < 0.5, "3.2 m takes 0.2–0.5 s (got %.2f s)" % seconds)


func test_offsets_add_up_and_clear() -> void:
	var smoother := _smoother(2)
	smoother.add(1, Vector2(0.5, 0.0))
	smoother.add(1, Vector2(0.25, 0.0))
	expect_eq(smoother.offset(1), Vector2(0.75, 0.0), "second rollback adds to the first")
	expect_eq(smoother.offset(0), Vector2.ZERO, "other entities untouched")
	smoother.clear()
	expect_eq(smoother.offset(1), Vector2.ZERO, "clear snaps to the true place")


func _smoother(count: int) -> CorrectionSmoother:
	var smoother := CorrectionSmoother.new()
	smoother.resize(count)
	return smoother


func _seconds_to_fade(smoother: CorrectionSmoother) -> float:
	var seconds := 0.0
	while smoother.offset(0).length() > 0.01 and seconds < 2.0:
		smoother.step(FRAME)
		seconds += FRAME
	return seconds
