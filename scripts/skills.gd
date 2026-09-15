extends Node3D

const Swing = preload('res://scripts/swing_motion.gd')
const COOLDOWNS := [3.3, 3.0, 4.0, 10.0, 15.0]
const NAMES := ['滚动', '飞扑', '咸鱼棒', '冰锥术', '破胆怒吼']
const FREEZE_SECONDS := 2.0
var racer: CharacterBody3D
var remaining: Array[float] = [0,0,0,0,0]
var frozen_left := 0.0
var fear_left := 0.0
var fear_origin := Vector3.ZERO
var dive_left := 0.0
var dive_direction := Vector3.ZERO
var dive_speed := 16.0
var dive_hits: Dictionary = {}
var swing_hits: Dictionary = {}
var attack_forward := Vector3.FORWARD
var attack_left := 0.0
var attack_pending := false
var knockback_left := 0.0
var knockback := Vector3.ZERO
var fish: Node3D
var ice: MeshInstance3D
var status: Label3D
var skull: Node3D
var effects: Array[Dictionary] = []

func _ready() -> void:
	racer = get_parent()
	build_visuals()

func cooldown(slot: int) -> float:
	return racer.roll_cooldown if slot == 1 else remaining[slot-1]

func controlled() -> bool:
	return frozen_left > 0 or fear_left > 0

func forward() -> Vector3:
	return Vector3(0,0,-1).rotated(Vector3.UP,racer.game.camera_yaw) if racer.is_player else Vector3(sin(racer.pivot.rotation.y),0,cos(racer.pivot.rotation.y))

func use_skill(slot: int) -> bool:
	if racer.game.duel and racer.game.duel.in_arena() and slot in [1,2]: return false
	if is_instance_valid(racer.vehicle): return false
	if slot < 1 or slot > 5 or racer.game.paused or not racer.active or racer.finished or controlled(): return false
	if cooldown(slot) > 0 or dive_left > 0 or attack_left > 0 or racer.roll_left > 0: return false
	remaining[slot-1] = COOLDOWNS[slot-1]
	match slot:
		1: racer.request_roll()
		2:
			dive_left = .48
			dive_speed = 16.0
			dive_hits.clear()
			dive_direction = forward()
			racer.velocity.y = 4.2 if racer.is_on_floor() else maxf(racer.velocity.y,1.4)
			racer.jump_buffer = 0
			burst('dive', Color('#fff1a2'), 1.6, .45)
			racer.game.action_sound('dive',racer)
		3:
			attack_left = Swing.DURATION
			attack_pending = true
			swing_hits.clear()
			attack_forward = forward()
			fish.begin()
		4:
			for target in targets(6.0, deg_to_rad(65)):
				target.skills.apply_freeze()
			burst('ice', Color('#168bc9'), 6.0, .95)
			racer.game.action_sound('freeze',racer)
		5:
			for target in targets(6.0, PI):
				target.skills.apply_fear(racer.global_position)
			burst('fear', Color('#cb88ee'), 6.0, .7)
			racer.game.action_sound('fear',racer)
	return true

func targets(radius: float, half_angle: float) -> Array:
	var found := []
	var facing := forward()
	for target in get_tree().get_nodes_in_group('combatants'):
		if target == racer or not target.active or target.finished: continue
		var offset: Vector3 = target.global_position - racer.global_position
		if absf(offset.y) > 2.5: continue
		offset.y = 0
		if offset.length() > radius: continue
		if offset.length_squared() > .01 and facing.dot(offset.normalized()) < cos(half_angle): continue
		# Solid scenery shields targets; characters do not block area effects.
		var query := PhysicsRayQueryParameters3D.create(racer.global_position+Vector3.UP, target.global_position+Vector3.UP, 1)
		if not racer.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		found.append(target)
	return found

func cancel_action() -> void:
	dive_left = 0
	attack_left = 0
	attack_pending = false
	racer.roll_left = 0
	racer.jump_buffer = 0
	knockback_left = 0
	dive_hits.clear()
	swing_hits.clear()
	fish.cancel()

func apply_freeze() -> void:
	if frozen_left <= 0: racer.game.action_sound('freeze',racer,1.0,true)
	cancel_action()
	frozen_left = FREEZE_SECONDS
	fear_left = 0
	racer.velocity.x = 0
	racer.velocity.z = 0
	ice.show()
	status.show()
	skull.hide()

func apply_fear(origin: Vector3) -> void:
	if fear_left <= 0: racer.game.action_sound('fear',racer,1.0,true)
	cancel_action()
	frozen_left = 0
	fear_left = 2.0
	fear_origin = origin
	ice.hide()
	status.hide()
	skull.show()

func reset(clear_cooldowns := false) -> void:
	cancel_action()
	frozen_left = 0
	fear_left = 0
	ice.hide()
	status.hide()
	skull.hide()
	if clear_cooldowns: remaining.fill(0.0)
	for effect in effects: effect.node.queue_free()
	effects.clear()

func tick(delta: float) -> void:
	if frozen_left > 0 and frozen_left <= delta: racer.game.action_sound('thaw',racer)
	for i in range(remaining.size()): remaining[i] = maxf(0, remaining[i]-delta)
	frozen_left = maxf(0,frozen_left-delta)
	fear_left = maxf(0,fear_left-delta)
	dive_left = maxf(0,dive_left-delta)
	knockback_left = maxf(0,knockback_left-delta)
	var previous_attack := attack_left
	attack_left = maxf(0,attack_left-delta)
	if attack_pending and attack_left <= .42:
		attack_pending = false
		racer.game.action_sound('swing',racer)
	if attack_left > 0:
		var old_phase := Swing.phase(Swing.DURATION-previous_attack)
		var phase := Swing.phase(Swing.DURATION-attack_left)
		if phase > old_phase: sweep_contacts(old_phase,phase)
		fish.advance(Swing.DURATION-attack_left,delta)
	else: fish.cancel()
	ice.visible = frozen_left > 0
	status.visible = frozen_left > 0
	status.text = '冻结 %.1f' % frozen_left
	status.modulate = Color('#c0f7ff')
	skull.visible = fear_left > 0
	if skull.visible:
		skull.position.y = 2.7+sin(fear_left*11)*.10
		if racer.game.camera: skull.look_at(racer.game.camera.global_position,Vector3.UP,true)
	for i in range(effects.size()-1,-1,-1):
		var effect: Dictionary = effects[i]
		effect.age += delta
		var progress: float = effect.age/effect.duration
		if progress >= 1:
			effect.node.queue_free()
			effects.remove_at(i)
			continue
		effect.node.scale = Vector3.ONE * lerpf(.2,1.0,minf(1.0,progress*1.8))
		var fade := 1.0-progress
		if effect.kind == 'ice': fade = 1.0-smoothstep(.6,1.0,progress)
		effect.material.albedo_color.a = fade*(.95 if effect.kind == 'ice' else .7)
		if effect.has('core'): effect.core.albedo_color.a = fade*.9

func receive_impulse(impulse: Vector3, duration: float) -> void:
	if frozen_left > 0: return
	if impulse.length() >= 4.0: racer.game.action_sound('knockdown' if impulse.length() >= 8.0 else 'bump',racer)
	# Keep the vertical component in normal gravity integration, never reset it every frame.
	racer.velocity += impulse / maxf(.1,racer.body_mass)
	knockback = Vector3(racer.velocity.x,0,racer.velocity.z)
	knockback_left = duration
	racer.jump_buffer = 0
	racer.squash = .76

func resolve_dive_collisions(incoming: Vector3) -> void:
	for i in range(racer.get_slide_collision_count()):
		var collision := racer.get_slide_collision(i)
		var target = collision.get_collider()
		if not is_instance_valid(target) or dive_hits.has(target.get_instance_id()): continue
		var mass := 0.0
		var target_velocity := Vector3.ZERO
		if target.is_in_group('combatants'):
			if not target.active or target.finished or target.skills.frozen_left > 0: continue
			mass = target.body_mass
			target_velocity = target.velocity
		elif target is RigidBody3D:
			if target.freeze: continue
			mass = target.mass
			target_velocity = target.linear_velocity
		else: continue
		var normal := -collision.get_normal()
		if absf(normal.y) > .75: continue
		var closing := maxf(0,(incoming-target_velocity).dot(normal))
		if closing < .5: continue
		dive_hits[target.get_instance_id()] = true
		racer.game.action_sound('hit',racer)
		# Equal masses share the closing momentum; heavy props move less and slow us more.
		var impulse: Vector3 = normal * (1.25*closing/(1.0/racer.body_mass+1.0/maxf(.1,mass)))
		if target is RigidBody3D: target.apply_impulse(impulse,collision.get_position()-target.global_position)
		else: target.skills.receive_impulse(impulse,.5)
		var after: Vector3 = incoming-impulse/racer.body_mass
		racer.velocity.y = after.y
		after.y = 0
		dive_speed = after.length()
		if dive_speed > .1: dive_direction = after.normalized()
		incoming = after

func sweep_contacts(from_phase: float, to_phase: float) -> void:
	var count := maxi(1,ceili((to_phase-from_phase)*3.0/.07))
	for sample in range(count+1):
		var phase := lerpf(from_phase,to_phase,float(sample)/count)
		var radial := attack_forward.rotated(Vector3.UP,lerpf(-1.5,1.5,phase))
		var shaft := Swing.shaft(attack_forward,phase)
		var a := racer.global_position+shaft[0]
		var b := racer.global_position+shaft[1]
		for target in get_tree().get_nodes_in_group('combatants'):
			if target == racer or not target.active or target.finished or swing_hits.has(target.get_instance_id()): continue
			# Both appearances use the same descending shaft against a vertical capsule.
			var closest := Geometry3D.get_closest_points_between_segments(a,b,target.global_position+Vector3.UP*.54,target.global_position+Vector3.UP*1.22)
			var point: Vector3 = closest[0]
			var center: Vector3 = closest[1]
			var contact := center-point
			if contact.length_squared() > .74*.74: continue
			var query := PhysicsRayQueryParameters3D.create(racer.global_position+Vector3.UP*1.05,center,5)
			if not racer.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
			swing_hits[target.get_instance_id()] = true
			fish.impact(point)
			racer.game.action_sound('hit',racer)
			var normal := contact.normalized() if contact.length_squared() > .001 else radial
			var tangent := Vector3.UP.cross(radial)
			var airborne: bool = not target.is_on_floor()
			var launch := (normal*.8+tangent*.30+radial*.30).normalized()
			if airborne:
				# A descending blade can meet the capsule at equal height: retain the jump launch.
				launch.y = maxf(launch.y,.42)
				launch = launch.normalized()
			else:
				launch.y = 0
				launch = launch.normalized()
			target.skills.receive_impulse(launch*(12.0 if airborne else 9.0)*racer.body_mass,.85 if airborne else .42)
			if racer.game.duel: racer.game.duel.register_hit(racer,target)

func movement(direction: Vector3) -> Vector3:
	if frozen_left > 0: return Vector3.ZERO
	if fear_left > 0:
		var away := racer.global_position-fear_origin
		away.y = 0
		if away.length_squared() < .01: away = Vector3.FORWARD
		return away.normalized().rotated(Vector3.UP,sin(fear_left*8+racer.racer_id)*.7)
	if dive_left > 0: return dive_direction
	return direction

func material(color: Color, transparent := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .32
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	obj.mesh = preload('res://assets/meshes/unit_sphere.tres')
	obj.material_override = mat
	obj.position = pos
	obj.scale = size
	parent.add_child(obj)
	return obj

func build_visuals() -> void:
	fish = preload('res://scripts/swing_visual.gd').new()
	fish.name = 'SaltedFishClub'
	add_child(fish)
	ice = MeshInstance3D.new()
	var crystal := CylinderMesh.new()
	crystal.top_radius = .48
	crystal.bottom_radius = .78
	crystal.height = 2.15
	crystal.radial_segments = 6
	ice.mesh = crystal
	ice.material_override = material(Color(.28,.85,1,.43),true)
	ice.position.y = 1.02
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ice)
	ice.hide()
	status = Label3D.new()
	status.font = preload('res://assets/fonts/CloudSans-Heavy.ttf')
	status.font_size = 32
	status.pixel_size = .012
	status.position.y = 2.75
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(status)
	status.hide()
	build_skull()

func build_skull() -> void:
	skull = Node3D.new()
	skull.name = 'FearSkull'
	skull.position.y = 2.7
	add_child(skull)
	var bone := material(Color('#fff3d9'))
	bone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var socket := material(Color('#503067'))
	socket.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ellipsoid(skull,Vector3(0,.03,0),Vector3(.29,.27,.13),bone)
	ellipsoid(skull,Vector3(0,-.19,0),Vector3(.18,.12,.105),bone)
	for side in [-1,1]:
		ellipsoid(skull,Vector3(side*.108,.035,.12),Vector3(.082,.094,.033),socket)
	ellipsoid(skull,Vector3(0,-.09,.13),Vector3(.036,.045,.024),socket)
	ellipsoid(skull,Vector3(0,-.21,.105),Vector3(.14,.035,.018),socket)
	for x in [-.085,0,.085]:
		ellipsoid(skull,Vector3(x,-.22,.13),Vector3(.025,.039,.018),bone)
	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .35
	ring.outer_radius = .395
	ring.rings = 32
	ring.ring_segments = 6
	halo.mesh = ring
	halo.material_override = material(Color('#d294fa'))
	halo.rotation.x = PI/2
	halo.position.z = -.045
	skull.add_child(halo)
	skull.hide()

func burst(kind: String, color: Color, radius: float, duration: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.top_level = true
	root.global_position = racer.global_position+Vector3(0,.15,0)
	root.rotation.y = atan2(-forward().x,-forward().z)
	var mat := material(Color(color,.7),true)
	var core: StandardMaterial3D
	if kind == 'ice':
		var query := PhysicsRayQueryParameters3D.create(racer.global_position+Vector3.UP,racer.global_position+Vector3.DOWN*20,1)
		var ground := racer.get_world_3d().direct_space_state.intersect_ray(query)
		if not ground.is_empty(): root.global_position.y = ground.position.y+.065
		var flake := MeshInstance3D.new()
		flake.name = 'ExpandingSnowflake'
		flake.mesh = preload('res://scripts/skill_shapes.gd').snowflake(.24)
		flake.material_override = mat
		root.add_child(flake)
		core = material(Color('#e9fcff'),true)
		var lines := MeshInstance3D.new()
		lines.mesh = preload('res://scripts/skill_shapes.gd').snowflake(.055)
		lines.material_override = core
		lines.position.y = .006
		root.add_child(lines)
	else:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = radius-.10
		mesh.outer_radius = radius+.10
		mesh.rings = 48
		mesh.ring_segments = 6
		ring.mesh = mesh
		ring.material_override = mat
		root.add_child(ring)
	var effect := {'node':root,'material':mat,'age':0.0,'duration':duration,'kind':kind}
	if core: effect['core'] = core
	effects.append(effect)
