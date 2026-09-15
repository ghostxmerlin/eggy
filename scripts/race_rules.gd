extends RefCounted

const CAPACITY := 24
const TIME_LIMIT := 150.0
const FINISH_WINDOW := 30.0
var phase := "menu"
var practice := false
var countdown := 3.0
var elapsed := 0.0
var order: Array[int] = []
var first_finish := -1.0
var end_reason := ''

func deadline() -> float:
	return minf(TIME_LIMIT, first_finish + FINISH_WINDOW) if first_finish >= 0 else TIME_LIMIT

func time_left() -> float:
	return maxf(0.0, deadline() - elapsed)

func places_left() -> int:
	return maxi(0, CAPACITY - order.size())

func start(practice_mode := false) -> void:
	practice = practice_mode
	phase = "racing" if practice else "countdown"
	countdown = 0.0 if practice else 3.0
	elapsed = 0.0
	order.clear()
	first_finish = -1.0
	end_reason = ''

func advance(delta: float) -> void:
	if phase == "countdown":
		countdown = maxf(0.0, countdown - delta)
		if countdown == 0.0:
			phase = "racing"
	elif phase == "racing":
		elapsed = elapsed + delta if practice else minf(deadline(), elapsed + delta)
		if not practice and time_left() <= 0:
			phase = "ended"
			end_reason = 'finish_window' if first_finish >= 0 and first_finish + FINISH_WINDOW <= TIME_LIMIT else 'time_limit'

func finish(id: int) -> int:
	var existing := order.find(id)
	if existing >= 0:
		return existing + 1
	if phase != "racing":
		return 0
	order.append(id)
	if not practice and first_finish < 0: first_finish = elapsed
	if practice or order.size() >= CAPACITY:
		phase = "ended"
		end_reason = 'practice' if practice else 'capacity'
	return order.size()
