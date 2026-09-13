extends RefCounted

# Short local plans preserve individual lanes while reacting to racers and props.
var racer: CharacterBody3D
var think_left := 0.0
var action_left := 0.0
var stuck_time := 0.0
var previous_z := 0.0
var route_x := 0.0
var pass_side := 1.0

func setup(owner_racer: CharacterBody3D) -> void:
	racer = owner_racer
	reset()

func reset() -> void:
	if not is_instance_valid(racer): return
	think_left = float(racer.racer_id%6)*.03
	action_left = .3+float(racer.racer_id%7)*.11
	stuck_time = 0
	previous_z = racer.position.z
	route_x = racer.position.x
	pass_side = -1.0 if racer.racer_id%2 == 0 else 1.0

func forward() -> Vector3:
	return Vector3(racer.drive.x,0,racer.drive.y).normalized() if racer.drive.length_squared() > .01 else Vector3.FORWARD

func gap_distance() -> float:
	var distance := INF
	for edge in racer.game.course.GAP_EDGES:
		var ahead: float = racer.position.z-edge
		if ahead >= 0: distance = minf(distance,ahead)
	return distance

# Sprinting and utility items require an actual supported route, including landings.
func clear_runway(distance: float, direction := Vector3.ZERO) -> bool:
	if direction.length_squared() < .01: direction = forward()
	if direction.z > -.7: return false
	for step in range(1,ceili(distance)+1):
		var point: Vector3 = racer.position+direction*float(step)
		if not racer.game.course.supported_at(point,1.0): return false
	return not solid_ahead(direction,distance)

func solid_ahead(direction: Vector3, distance: float) -> bool:
	var origin: Vector3 = racer.global_position+Vector3.UP*.85
	var ray := PhysicsRayQueryParameters3D.create(origin,origin+direction*distance,5)
	return not racer.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func tick(delta: float) -> void:
	var can_steer: bool = not racer.skills.controlled() and racer.skills.knockback_left <= 0 and racer.hit_cooldown <= .3
	if can_steer and racer.is_on_floor() and previous_z-racer.position.z < delta*.6:
		stuck_time += delta
	else:
		stuck_time = maxf(0,stuck_time-delta*3)
	previous_z = racer.position.z
	think_left -= delta
	action_left -= delta
	if think_left <= 0:
		plan_route()
		think_left = .16+float(racer.racer_id%4)*.025
	var direction := Vector3(route_x-racer.position.x,0,-3.4).normalized()
	racer.drive = Vector2(direction.x,direction.z)
	if not can_steer: return
	var jump_lead: float = clampf(-racer.velocity.z*.21,1.55,2.8)
	for edge in racer.game.course.GAP_EDGES:
		if racer.position.z < edge+jump_lead and racer.position.z > edge-.2 and racer.is_on_floor(): racer.request_jump()
	if racer.game.course.hazard_at(racer.position+direction*1.4).length_squared() > 0 and racer.is_on_floor(): racer.request_jump()
	if stuck_time > .65 and racer.is_on_floor():
		racer.request_jump()
		if stuck_time > 1.4:
			pass_side *= -1
			think_left = 0
			stuck_time = .3
	if action_left <= 0:
		action_left = racer.rng.randf_range(.45,.9)
		if racer.is_on_floor() and stuck_time < .2 and absf(direction.x) < .22 and clear_runway(14) and traffic_cost(racer.position+direction*5) < 2:
			racer.skills.use_skill(1)

func plan_route() -> void:
	var course = racer.game.course
	var desired: Vector3 = course.ai_target(racer.position,racer.lane,racer.racer_id)
	var bounds: Vector2 = course.ai_route_bounds(racer.position)
	var best_score := INF
	var best_x: float = clampf(desired.x,bounds.x,bounds.y)
	for offset in [0.0,pass_side*1.5,-pass_side*1.5,pass_side*3.0,-pass_side*3.0,pass_side*4.5,-pass_side*4.5]:
		var x := clampf(desired.x+offset,bounds.x,bounds.y)
		var target := Vector3(x,racer.position.y,desired.z)
		var score := absf(x-desired.x)*.24+absf(x-route_x)*.16
		score += traffic_cost(target)
		var direction := (target-racer.position).normalized()
		if solid_ahead(direction,minf(4.0,racer.position.distance_to(target))): score += 14
		if score < best_score:
			best_score = score
			best_x = x
	route_x = best_x

func traffic_cost(target: Vector3) -> float:
	var cost := 0.0
	for other in racer.game.racers:
		if other == racer or other.finished or not other.active: continue
		if absf(other.position.y-racer.position.y) > 2.0: continue
		var offset: Vector3 = other.position-racer.position
		if offset.z > .7 or offset.length_squared() > 64: continue
		# A moving rival vacates space; a stopped rival needs a full passing lane.
		var predicted: Vector3 = other.position+Vector3(other.velocity.x,0,other.velocity.z)*.25
		cost += obstacle_cost(target,predicted,1.3)*1.8
	for zone in racer.game.items.zones:
		if zone.kind not in ['crate','mine']: continue
		if zone.kind == 'mine' and zone.owner == racer.racer_id: continue
		cost += obstacle_cost(target,zone.node.global_position,1.65)*2.2
	return cost

func obstacle_cost(target: Vector3, obstacle: Vector3, clearance: float) -> float:
	var start := Vector2(racer.position.x,racer.position.z)
	var end := Vector2(target.x,target.z)
	var point := Vector2(obstacle.x,obstacle.z)
	if obstacle.z > racer.position.z+.7 or absf(obstacle.y-racer.position.y) > 2.5: return 0
	var closest := Geometry2D.get_closest_point_to_segment(point,start,end)
	var distance := point.distance_to(closest)
	return maxf(0,clearance-distance)*8.0
