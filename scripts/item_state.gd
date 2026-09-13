extends RefCounted

var held := ''
var pickup_lock := 0.0
var ai_wait := 0.0
var ink := 0.0
var smoke := 0.0
var boost := 0.0
var jetpack := 0.0
var portal_lock := 0.0

func clear() -> void:
	held = ''
	pickup_lock = 0
	ai_wait = 0
	ink = 0
	smoke = 0
	boost = 0
	jetpack = 0
	portal_lock = 0

func tick(delta: float) -> void:
	pickup_lock = maxf(0,pickup_lock-delta)
	ai_wait = maxf(0,ai_wait-delta)
	ink = maxf(0,ink-delta)
	smoke = maxf(0,smoke-delta)
	boost = maxf(0,boost-delta)
	jetpack = maxf(0,jetpack-delta)
	portal_lock = maxf(0,portal_lock-delta)

func speed_scale() -> float:
	return (1.45 if boost > 0 else 1.0) * (.72 if ink > 0 else .85 if smoke > 0 else 1.0)
