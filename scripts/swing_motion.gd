extends RefCounted
const DURATION := .52
const WINDUP := .10
const STRIKE := .28

static func phase(elapsed: float) -> float:
	var t := clampf((elapsed-WINDUP)/STRIKE,0,1)
	return t*t*(3.0-2.0*t)

static func shaft(forward: Vector3, progress: float) -> Array[Vector3]:
	var radial := forward.rotated(Vector3.UP,lerpf(-1.5,1.5,progress))
	var slope := .26*cos(progress*PI)
	var origin := Vector3(0,1.05+slope*.65,0)
	# Same horizontal reach for both weapons; the tip descends through the sweep.
	var direction := radial+Vector3.UP*slope
	return [origin+direction*.4,origin+direction*2.3]

static func pose(forward: Vector3, elapsed: float) -> Array[Vector3]:
	var points := shaft(forward,phase(elapsed))
	if elapsed < WINDUP:
		var t := smoothstep(0.0,WINDUP,elapsed)
		for i in range(2): points[i] += Vector3.UP*(t-1)*(.15+i*.3)
	elif elapsed > WINDUP+STRIKE:
		var t := smoothstep(WINDUP+STRIKE,DURATION,elapsed)
		points[0] += forward*(-.16*t)+Vector3.UP*.10*t
		points[1] += forward*(-.32*t)+Vector3.UP*.24*t
	return points
