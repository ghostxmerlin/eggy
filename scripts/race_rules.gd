extends RefCounted

const CAPACITY := 24
const TIME_LIMIT := 150.0
var phase := "menu"
var practice := false
var countdown := 3.0
var elapsed := 0.0
var order: Array[int] = []

func start(practice_mode := false) -> void:
	practice = practice_mode
	phase = "racing" if practice else "countdown"
	countdown = 0.0 if practice else 3.0
	elapsed = 0.0
	order.clear()

func advance(delta: float) -> void:
	if phase == "countdown":
		countdown = maxf(0.0, countdown - delta)
		if countdown == 0.0:
			phase = "racing"
	elif phase == "racing":
		elapsed = elapsed + delta if practice else minf(TIME_LIMIT, elapsed + delta)
		if not practice and elapsed >= TIME_LIMIT:
			phase = "ended"

func finish(id: int) -> int:
	var existing := order.find(id)
	if existing >= 0:
		return existing + 1
	if phase != "racing":
		return 0
	order.append(id)
	if practice or order.size() >= CAPACITY:
		phase = "ended"
	return order.size()
