extends Node3D

const Catalog = preload('res://scripts/item_catalog.gd')
const Visuals = preload('res://scripts/item_visuals.gd')
const PICKUP_RESPAWN := 4.0
const MAX_PROJECTILES := 64
const MAX_ZONES := 48
var game: Node3D
var rng := RandomNumberGenerator.new()
var pickups: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var collected: Dictionary = {}
var used: Dictionary = {}
var hits: Dictionary = {}
var portal_trips := 0
var spring_launches := 0
var enabled := false
var clock := 0.0
var bag: Array[String] = []

func _ready() -> void:
	if game.item_seed >= 0: rng.seed = game.item_seed
	else: rng.randomize()

func clear() -> void:
	enabled = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	pickups.clear()
	projectiles.clear()
	zones.clear()
	effects.clear()
	bag.clear()
	for racer in game.racers:
		if is_instance_valid(racer): racer.clear_item()

func setup_race() -> void:
	clear()
	collected.clear()
	used.clear()
	hits.clear()
	portal_trips = 0
	spring_launches = 0
	clock = 0
	enabled = not game.practice and not game.in_island
	if not enabled: return
	# Wide platforms and checkpoint approaches, never unsupported gaps.
	for z in [-8.0,-17.0,-51.0,-89.0,-101.0,-135.0,-201.0,-216.0,-264.0,-294.0]:
		var lanes := [-6.0,-3.0,0.0,3.0,6.0] if z > -150 or z < -289 else [-2.0,0.0,2.0]
		for x in lanes: add_pickup(Vector3(x,1.05,z))

func add_pickup(pos: Vector3) -> Dictionary:
	var node := Visuals.pickup()
	add_child(node)
	node.position = pos
	var entry := {'node':node,'position':pos,'remaining':0.0,'phase':rng.randf_range(0,TAU)}
	pickups.append(entry)
	return entry

func next_item() -> String:
	if bag.is_empty():
		for id in Catalog.IDS: bag.append(id)
		for i in range(bag.size()-1,0,-1):
			var j := rng.randi_range(0,i)
			var swap := bag[i]
			bag[i] = bag[j]
			bag[j] = swap
	return bag.pop_back()

func can_act(racer) -> bool:
	return enabled and not game.in_island and not game.paused and game.rules.phase == 'racing' and racer.active and not racer.finished and not is_instance_valid(racer.vehicle)

func collect(racer, pickup: Dictionary) -> bool:
	if not can_act(racer) or racer.skills.controlled() or racer.item_state.held != '' or racer.item_state.pickup_lock > 0 or pickup.remaining > 0: return false
	if racer.global_position.distance_to(pickup.position-Vector3.UP*.4) > 1.5: return false
	racer.item_state.held = next_item()
	racer.item_state.ai_wait = rng.randf_range(.35,.95)
	pickup.remaining = PICKUP_RESPAWN
	pickup.node.hide()
	collected[racer.racer_id] = collected.get(racer.racer_id,0)+1
	sync_held(racer)
	if racer.is_player:
		game.toast = '拾取 '+Catalog.title(racer.item_state.held)+' · 按 R 使用'
		game.toast_time = 2.0
		game.sound('checkpoint')
	return true

func sync_held(racer) -> void:
	if is_instance_valid(racer.item_display): racer.item_display.queue_free()
	racer.item_display = null
	if racer.item_state.held == '': return
	var node := Visuals.item(racer.item_state.held)
	racer.add_child(node)
	node.position = Vector3(.95,1.35,.05)
	node.scale = Vector3.ONE*.45
	racer.item_display = node

func use_item(racer, direction := Vector3.ZERO) -> bool:
	var state = racer.item_state
	if not can_act(racer) or state.held == '' or racer.skills.controlled() or racer.skills.dive_left > 0 or racer.skills.attack_left > 0: return false
	var kind: String = state.held
	var facing: Vector3 = racer.skills.forward() if direction.length_squared() < .01 else direction.normalized()
	facing.y = 0
	if facing.length_squared() < .01: return false
	facing = facing.normalized()
	var success := true
	match kind:
		'boost': state.boost = 4.0
		'jetpack':
			state.jetpack = 2.2
			racer.velocity.y = maxf(racer.velocity.y,5.0)
		'clock':
			racer.skills.remaining.fill(0.0)
			racer.roll_cooldown = 0
		'spring','mine','crate': success = deploy(kind,racer,facing)
		_: success = throw_item(kind,racer,facing)
	if not success:
		if racer.is_player:
			game.toast = '这里无法使用，换个位置再试'
			game.toast_time = 1.5
		return false
	state.held = ''
	state.pickup_lock = .7
	used[racer.racer_id] = used.get(racer.racer_id,0)+1
	sync_held(racer)
	if kind in ['boost','jetpack','clock']: burst(racer.global_position+Vector3.UP,Catalog.color(kind),1.8)
	if racer.is_player: game.sound('roll')
	return true

func throw_item(kind: String, racer, facing: Vector3) -> bool:
	if projectiles.size() >= MAX_PROJECTILES: return false
	var shape := SphereShape3D.new()
	shape.radius = .82 if kind == 'ball' else .23
	var origin: Vector3 = racer.global_position+Vector3.UP*1.1
	var spawn: Vector3 = origin+facing*.85
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = spawn
	query.collision_mask = 5
	var ray := PhysicsRayQueryParameters3D.create(origin,spawn,5)
	var space := get_world_3d().direct_space_state
	if not space.intersect_ray(ray).is_empty() or not space.intersect_shape(query,1).is_empty(): return false
	var body := CharacterBody3D.new()
	body.name = 'Thrown_'+kind
	body.collision_layer = 0
	body.collision_mask = 7
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.add_child(Visuals.item(kind))
	add_child(body)
	body.global_position = spawn
	body.add_collision_exception_with(racer)
	var speed := 22.0 if kind in ['ball','rope'] else 16.0
	var lift := 1.0 if kind == 'ball' else 0.0 if kind == 'rope' else 7.2
	projectiles.append({'node':body,'kind':kind,'owner':racer.racer_id,'velocity':facing*speed+Vector3.UP*lift,'age':0.0,'life':5.0,'hits':{},'direction':facing})
	return true

func floor_at(pos: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.6,pos-Vector3.UP*3.0,5)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < .7: return {}
	return hit

func clear_landing(foot: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .54
	capsule.height = 1.75
	query.shape = capsule
	query.transform.origin = foot+Vector3.UP*.95
	query.collision_mask = 5
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func deploy(kind: String, racer, facing: Vector3) -> bool:
	if zones.size() >= MAX_ZONES: return false
	var spot: Vector3 = racer.global_position+facing*2.2
	var ground := floor_at(spot)
	if ground.is_empty() or not clear_landing(ground.position+Vector3.UP*.1): return false
	spot = ground.position+Vector3.UP*.15
	var node: Node3D
	if kind == 'crate':
		node = StaticBody3D.new()
		node.collision_layer = 4
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE*1.4
		collision.shape = shape
		node.add_child(collision)
		node.add_child(Visuals.item(kind))
		spot.y += .57
	else: node = Visuals.item(kind)
	add_child(node)
	node.global_position = spot
	node.rotation.y = atan2(-facing.x,-facing.z)
	zones.append({'node':node,'kind':kind,'owner':racer.racer_id,'age':0.0,'life':10.0,'direction':facing,'locks':{}})
	return true

func owner_of(entry: Dictionary):
	return game.racers[entry.owner] if entry.owner >= 0 and entry.owner < game.racers.size() else null

func register_hit(kind: String) -> void:
	hits[kind] = hits.get(kind,0)+1

func explode(kind: String, pos: Vector3, owner_id: int) -> void:
	burst(pos,Catalog.color(kind),4.0)
	for racer in game.racers:
		if not racer.active or racer.finished or racer.racer_id == owner_id: continue
		var offset: Vector3 = racer.global_position+Vector3.UP*.8-pos
		if offset.length() > 4.0: continue
		var ray := PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.2,racer.global_position+Vector3.UP,5)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		if kind == 'ink': racer.item_state.ink = 3.5
		else:
			offset.y = 0
			if offset.length_squared() < .01: offset = Vector3.RIGHT
			racer.skills.receive_impulse(offset.normalized()*16+Vector3.UP*7,.8)
		register_hit(kind)

func land_projectile(entry: Dictionary, collision: KinematicCollision3D) -> void:
	var pos := collision.get_position()
	var kind: String = entry.kind
	var target = collision.get_collider()
	var owner = owner_of(entry)
	match kind:
		'ink','bomb': explode(kind,pos,entry.owner)
		'smoke':
			if zones.size() >= MAX_ZONES: return
			var cloud := Node3D.new()
			add_child(cloud)
			cloud.global_position = pos+Vector3.UP
			for i in range(5):
				var a := i*TAU/5
				Visuals.sphere(cloud,Vector3(sin(a)*1.3,i%2*.5,cos(a)*1.3),Vector3.ONE*1.8,Color(.7,.78,.84,.42))
			zones.append({'node':cloud,'kind':'smoke','age':0.0,'life':5.0})
		'portal':
			if not is_instance_valid(owner) or owner.finished or zones.size() >= MAX_ZONES or collision.get_normal().y < .7: return
			var start := floor_at(owner.global_position)
			var destination := pos+Vector3.UP*.12
			if start.is_empty() or not clear_landing(destination): return
			var entrance := Visuals.portal()
			var exit_portal := Visuals.portal()
			var node := Node3D.new()
			add_child(node)
			node.add_child(entrance)
			node.add_child(exit_portal)
			entrance.global_position = start.position+Vector3.UP*1.1
			exit_portal.global_position = destination+Vector3.UP*1.1
			entrance.rotation.y = atan2(-entry.direction.x,-entry.direction.z)
			exit_portal.rotation.y = entrance.rotation.y
			zones.append({'node':node,'kind':'portal','age':0.0,'life':8.0,'entry':start.position,'exit':destination})
		'rope':
			if not is_instance_valid(owner) or not owner.active or owner.finished: return
			var delta: Vector3 = pos-owner.global_position
			if delta.length() > 28 or delta.length() < 1: return
			owner.skills.receive_impulse(delta.normalized()*12+Vector3.UP*3,.7)
			if target is CharacterBody3D and target.is_in_group('combatants') and target.active and not target.finished:
				target.skills.receive_impulse(-delta.normalized()*9+Vector3.UP*3,.6)
			register_hit(kind)
			var node := Node3D.new()
			add_child(node)
			var beam := Visuals.box(node,Vector3.ZERO,Vector3(.08,.08,delta.length()),Catalog.color('rope'))
			beam.global_position = owner.global_position+delta*.5+Vector3.UP
			beam.look_at(pos+Vector3.UP)
			effects.append({'node':node,'age':0.0,'life':.35,'grow':false})

func burst(pos: Vector3, color: Color, radius: float) -> void:
	if effects.size() >= 32: return
	var node := Node3D.new()
	add_child(node)
	node.global_position = pos
	Visuals.ring(node,radius,Color(color,.55))
	for i in range(5):
		var a := i*TAU/5
		Visuals.sphere(node,Vector3(sin(a)*radius*.5,.25,cos(a)*radius*.5),Vector3.ONE*.25,color)
	effects.append({'node':node,'age':0.0,'life':.45,'grow':true})

func _physics_process(delta: float) -> void:
	if enabled and game.rules.phase == 'ended':
		clear()
		return
	if not enabled or game.paused or game.in_island or game.rules.phase != 'racing': return
	clock += delta
	for racer in game.racers:
		racer.item_state.tick(delta)
	for pickup in pickups:
		pickup.remaining = maxf(0,pickup.remaining-delta)
		pickup.node.visible = pickup.remaining == 0
		if pickup.remaining > 0: continue
		pickup.node.position.y = pickup.position.y+sin(clock*2+pickup.phase)*.16
		pickup.node.rotation.y = sin(clock+pickup.phase)*.4
		var nearest = null
		var distance := 1.5
		for racer in game.racers:
			if not can_act(racer) or racer.item_state.held != '' or racer.item_state.pickup_lock > 0 or racer.skills.controlled(): continue
			var d: float = racer.global_position.distance_to(pickup.position-Vector3.UP*.4)
			if d < distance:
				distance = d
				nearest = racer
		if nearest: collect(nearest,pickup)
	for racer in game.racers:
		if not racer.is_player or game.autoplay: ai_try_use(racer)
	tick_projectiles(delta)
	tick_zones(delta)
	for i in range(effects.size()-1,-1,-1):
		var effect: Dictionary = effects[i]
		effect.age += delta
		if effect.age >= effect.life:
			effect.node.queue_free()
			effects.remove_at(i)
		elif effect.grow: effect.node.scale = Vector3.ONE*lerpf(.3,1.0,effect.age/effect.life)

func ai_try_use(racer) -> void:
	var state = racer.item_state
	if not can_act(racer) or state.held == '' or state.ai_wait > 0 or racer.skills.controlled() or racer.skills.knockback_left > 0: return
	state.ai_wait = rng.randf_range(.25,.55)
	var direction: Vector3 = racer.race_ai.forward()
	var gap: float = racer.race_ai.gap_distance()
	var finish_distance: float = racer.position.z-game.course.FINISH_Z
	match state.held:
		'ball','ink','bomb','rope','smoke':
			direction = ai_attack_direction(racer,state.held,direction)
			if direction.length_squared() < .01: return
		'boost':
			if state.boost > 0 or racer.roll_left > 0 or not racer.is_on_floor(): return
			if not racer.race_ai.clear_runway(12,direction) or racer.race_ai.traffic_cost(racer.position+direction*5) > 3: return
		'jetpack':
			if state.jetpack > 0 or finish_distance < 36: return
			if not (gap >= 2 and gap < 8) and racer.race_ai.stuck_time < .6: return
		'clock':
			if racer.roll_cooldown < 1.2 and not racer.skills.remaining.any(func(value): return value > 3): return
		'mine','crate':
			# Drop obstacles behind into a pursuer's route, not in our own way.
			var pursuer = null
			for other in game.racers:
				if other == racer or not other.active or other.finished: continue
				var offset: Vector3 = other.position-racer.position
				if offset.z > 3 and offset.z < 10 and absf(offset.x) < 2.8 and absf(offset.y) < 1.5:
					pursuer = other
					break
			if pursuer == null or not racer.is_on_floor(): return
			direction = Vector3.BACK
		'spring':
			if not racer.is_on_floor() or gap < 4 or gap > 9 or absf(direction.x) > .2 or finish_distance < 26: return
			if not game.course.supported_at(racer.position+direction*18,1.0): return
		'portal':
			if not racer.is_on_floor() or finish_distance < 22: return
			if gap > 16 and racer.race_ai.stuck_time < .5: return
			var destination: Vector3 = racer.position+direction*16
			if not game.course.supported_at(destination,1.2) or floor_at(destination).is_empty() or not clear_landing(destination+Vector3.UP*.1): return
	use_item(racer,direction)

func ai_attack_direction(racer, kind: String, forward: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_score := INF
	var lobbed: bool = kind in ['ink','bomb','smoke']
	for other in game.racers:
		if other == racer or other.finished or not other.active: continue
		var offset: Vector3 = other.position-racer.position
		if absf(offset.y) > 2.0: continue
		offset.y = 0
		var distance := offset.length()
		if distance < 1.8 or distance > 23: continue
		var alignment := forward.dot(offset.normalized())
		if kind == 'rope' and alignment < .65: continue
		if alignment < -.2 and (lobbed or distance > 6): continue
		# Lead moving opponents using the same projectile speed and arc as players.
		var flight := .85 if lobbed else minf(.8,distance/22.0)
		var predicted: Vector3 = other.position+Vector3(other.velocity.x,0,other.velocity.z)*flight
		var aim: Vector3 = predicted-racer.position
		aim.y = 0
		var reach := aim.length()
		if lobbed and (reach < 11 or reach > 18): continue
		if not lobbed and reach > 20: continue
		if reach < .1: continue
		var direction := aim.normalized()
		if kind == 'rope' and not racer.race_ai.clear_runway(reach,direction): continue
		var ray := PhysicsRayQueryParameters3D.create(racer.global_position+Vector3.UP,other.global_position+Vector3.UP,5)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		var score := absf(reach-14.5) if lobbed else reach
		score += (1.0-alignment)*3.0
		if score < best_score:
			best_score = score
			best = direction
	return best

func tick_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var entry: Dictionary = projectiles[i]
		var body: CharacterBody3D = entry.node
		entry.age += delta
		entry.velocity.y -= (0.0 if entry.kind == 'rope' else 18.0)*delta
		var collision := body.move_and_collide(entry.velocity*delta)
		var remove: bool = entry.age > entry.life or body.position.y < -12
		if collision:
			var target = collision.get_collider()
			if entry.kind == 'ball':
				if target is CharacterBody3D and target.is_in_group('combatants'):
					if target.active and not target.finished and not entry.hits.has(target.racer_id):
						var launch: Vector3 = entry.velocity
						launch.y = 0
						target.skills.receive_impulse(launch.normalized()*24+Vector3.UP*7.5,.95)
						entry.hits[target.racer_id] = true
						register_hit('ball')
					body.add_collision_exception_with(target)
				else:
					entry.velocity = entry.velocity.bounce(collision.get_normal())*.78
					if collision.get_normal().y > .7:
						entry.velocity.x /= .78
						entry.velocity.z /= .78
						entry.velocity.y = maxf(entry.velocity.y,1.2)
			else:
				land_projectile(entry,collision)
				remove = true
		if remove:
			body.queue_free()
			projectiles.remove_at(i)

func tick_zones(delta: float) -> void:
	for i in range(zones.size()-1,-1,-1):
		var zone: Dictionary = zones[i]
		zone.age += delta
		var remove: bool = zone.age >= zone.life
		if not remove:
			for racer in game.racers:
				if not racer.active or racer.finished: continue
				var point: Vector3 = zone.entry if zone.kind == 'portal' else zone.node.global_position
				var offset: Vector3 = racer.global_position-point
				var height: float = absf(offset.y)
				offset.y = 0
				match zone.kind:
					'portal':
						if height < 1.7 and offset.length() < 1.1 and racer.item_state.portal_lock <= 0 and clear_landing(zone.exit):
							racer.global_position = zone.exit
							racer.velocity = Vector3.ZERO
							racer.skills.knockback_left = 0
							racer.item_state.portal_lock = 1.5
							racer.reset_physics_interpolation()
							portal_trips += 1
					'spring':
						if height < 1.2 and offset.length() < 1.3 and zone.age >= zone.locks.get(racer.racer_id,0.0):
							racer.skills.receive_impulse(zone.direction*16+Vector3.UP*12,.7)
							zone.locks[racer.racer_id] = zone.age+2.0
							spring_launches += 1
							burst(point, Catalog.color('spring'),1.6)
					'mine':
						if zone.age > .7 and height < 1.5 and offset.length() < 1.3 and racer.racer_id != zone.owner:
							explode('mine',point+Vector3.UP*.3,zone.owner)
							remove = true
							break
					'smoke':
						if height < 3.2 and offset.length() < 3.2: racer.item_state.smoke = .2
		if remove:
			remove_child(zone.node)
			zone.node.queue_free()
			zones.remove_at(i)
