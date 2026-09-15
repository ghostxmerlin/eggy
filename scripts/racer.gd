extends CharacterBody3D

const MODEL = preload('res://assets/models/racer.glb')
const Skins = preload('res://scripts/skin_catalog.gd')
var skin_id := 'classic'
const SPEED := 8.0
const JUMP_SPEED := 9.3
const GRAVITY := 24.0
var game: Node3D
var racer_id := 0
var is_player := false
var active := false
var finished := false
var external_control := false
var drive := Vector2.ZERO
var checkpoint := 0
var roll_left := 0.0
var roll_cooldown := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var hit_cooldown := 0.0
var invulnerable := 0.0
var lane := 0.0
var ai_speed := 5.0
var race_ai = preload('res://scripts/race_ai.gd').new()
var model: Node3D
var pivot: Node3D
var roll_visual: Node3D
var bob := 0.0
var squash := 1.0
var was_grounded := false
var limbs: Dictionary = {}
var rng := RandomNumberGenerator.new()
var furthest := 5.0
var skills: Node3D
var vehicle: Node3D
var training_dummy := false
var training_home := Vector3.ZERO
var training_jump := false
var training_jump_clock := 1.2
var item_state = preload('res://scripts/item_state.gd').new()
var item_display: Node3D
var jet_display: Node3D
var item_ink_visible := false
@export_range(.1,100,.1) var body_mass := 1.0

func _ready() -> void:
	add_to_group('combatants')
	rng.seed = racer_id*17+987
	lane = float(racer_id%7-3)*2.25
	ai_speed = rng.randf_range(6.4,8.0)
	race_ai.setup(self)
	collision_layer = 2
	collision_mask = 7
	floor_snap_length = .35
	floor_max_angle = deg_to_rad(48)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .51
	shape.height = 1.7
	collider.shape = shape
	collider.position.y = .88
	add_child(collider)
	pivot = Node3D.new()
	add_child(pivot)
	pivot.position.y = .85
	roll_visual = Node3D.new()
	pivot.add_child(roll_visual)
	model = MODEL.instantiate()
	model.position.y = -.85
	roll_visual.add_child(model)
	for part in ['ArmL','ArmR','FootL','FootR']:
		var node := model.find_child(part,true,false)
		if node: limbs[part] = [node,node.position]
	set_skin('classic' if is_player else Skins.SKINS[racer_id%Skins.SKINS.size()].id)
	if is_player:
		var marker := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = .69
		mesh.outer_radius = .75
		mesh.rings = 32
		mesh.ring_segments = 8
		marker.mesh = mesh
		marker.position.y = .045
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color('#ffffd6')
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = mat
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)
		var tag := Label3D.new()
		tag.text = '▼'
		tag.position.y = 2.55
		tag.font_size = 32
		tag.pixel_size = .012
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color('#fff5a0')
		tag.outline_size = 5
		add_child(tag)
	pivot.rotation.y = PI
	skills = preload('res://scripts/skills.gd').new()
	skills.name = 'Skills'
	add_child(skills)

func set_skin(id: String) -> void:
	skin_id = Skins.get_skin(id).id
	Skins.apply(model,skin_id)

func request_jump() -> void:
	if active and not finished and not game.paused and not is_instance_valid(vehicle) and not skills.controlled() and skills.dive_left <= 0: jump_buffer = .14

func request_roll() -> void:
	if active and not finished and not game.paused and not is_instance_valid(vehicle) and not skills.controlled() and skills.dive_left <= 0 and skills.attack_left <= 0 and roll_cooldown <= 0:
		roll_left = .85
		roll_cooldown = 3.3
		game.action_sound('roll',self)

func board_vehicle(ride: Node3D) -> void:
	leave_vehicle()
	vehicle = ride
	skills.reset()
	velocity = Vector3.ZERO
	drive = Vector2.ZERO
	add_collision_exception_with(ride.body)
	global_position = ride.passenger_position()
	game.release_mouse_drive()
	reset_physics_interpolation()

func leave_vehicle() -> void:
	if is_instance_valid(vehicle): vehicle.cancel_passenger(self)
	vehicle = null

func reset_to_start(pos: Vector3) -> void:
	leave_vehicle()
	clear_item()
	if skills: skills.reset(true)
	position = pos
	race_ai.reset()
	velocity = Vector3.ZERO
	checkpoint = 0
	finished = false
	collision_layer = 2
	active = false
	drive = Vector2.ZERO
	roll_left = 0
	roll_cooldown = 0
	hit_cooldown = 0
	jump_buffer = 0
	coyote = 0
	invulnerable = .5
	pivot.rotation = Vector3(0,PI,0)
	roll_visual.rotation = Vector3.ZERO
	squash = 1.0
	was_grounded = false
	bob = 0.0
	furthest = pos.z
	reset_physics_interpolation()

func respawn() -> void:
	leave_vehicle()
	clear_item()
	skills.reset()
	position = training_home if training_dummy else (game.Island.SPAWN if game.in_island else game.course.CHECKPOINTS[checkpoint] + Vector3(lane*.25 if not is_player else 0, .3, 0))
	race_ai.reset()
	velocity = Vector3.ZERO
	roll_left = 0
	jump_buffer = 0
	coyote = 0
	roll_visual.rotation = Vector3.ZERO
	squash = 1.0
	was_grounded = false
	bob = 0.0
	hit_cooldown = .6
	invulnerable = 1.0
	reset_physics_interpolation()
	game.action_sound('fall',self)

func clear_item() -> void:
	item_state.clear()
	if is_instance_valid(item_display): item_display.queue_free()
	item_display = null
	update_item_visuals()

func update_item_visuals() -> void:
	if not is_instance_valid(model): return
	var inked: bool = item_state.ink > 0
	if inked != item_ink_visible:
		item_ink_visible = inked
		var overlay: Material = preload('res://scripts/item_visuals.gd').material(Color(.14,.06,.20,.82)) if inked else null
		for mesh in model.find_children('*','MeshInstance3D',true,false): mesh.material_overlay = overlay
	if item_state.jetpack > 0 and not is_instance_valid(jet_display):
		jet_display = preload('res://scripts/item_visuals.gd').item('jetpack')
		pivot.add_child(jet_display)
		jet_display.position = Vector3(0,.2,-.65)
		jet_display.scale = Vector3.ONE*.7
	elif item_state.jetpack <= 0 and is_instance_valid(jet_display):
		jet_display.queue_free()
		jet_display = null

func _physics_process(delta: float) -> void:
	if game.paused: return
	update_item_visuals()
	skills.tick(delta)
	roll_cooldown = maxf(0,roll_cooldown-delta)
	roll_left = maxf(0,roll_left-delta)
	hit_cooldown = maxf(0,hit_cooldown-delta)
	invulnerable = maxf(0,invulnerable-delta)
	jump_buffer = maxf(0,jump_buffer-delta)
	coyote = .12 if is_on_floor() else maxf(0,coyote-delta)
	if is_instance_valid(vehicle):
		global_position = vehicle.passenger_position()
		velocity = Vector3.ZERO
		drive = Vector2.ZERO
		animate(delta)
		pivot.basis = vehicle.body.global_basis * Basis(Vector3.UP,PI)
		return
	if active and not finished:
		if is_player and not external_control:
			game.camera_yaw += Input.get_axis('turn_right','turn_left')*2.2*delta
			drive = Input.get_vector('left','right','forward','back')
			if game.mouse_forward: drive = Vector2(0,-1)
			if Input.is_action_just_pressed('jump'): request_jump()
			for slot in range(1,6):
				if Input.is_action_just_pressed('skill_'+str(slot)): skills.use_skill(slot)
			if Input.is_action_just_pressed('roll'): skills.use_skill(1)
		elif training_dummy:
			var to_home := training_home-position
			to_home.y = 0
			drive = Vector2(to_home.x,to_home.z).normalized() if to_home.length() > .3 else Vector2.ZERO
			if training_jump and not skills.controlled() and skills.knockback_left <= 0:
				training_jump_clock -= delta
				if training_jump_clock <= 0 and is_on_floor():
					request_jump()
					training_jump_clock = 3.0
		elif not is_player and not external_control:
			race_ai.tick(delta)
	else:
		drive = Vector2.ZERO
	var direction := Vector3(drive.x,0,drive.y)
	if is_player and not external_control: direction = direction.rotated(Vector3.UP,game.camera_yaw)
	if roll_left > 0 and direction.length_squared() < .01: direction = skills.forward()
	direction = skills.movement(direction)
	var speed := SPEED if is_player else ai_speed
	if training_dummy: speed = 2.5
	if roll_left>0: speed = 14.0
	speed *= item_state.speed_scale()
	if skills.dive_left > 0: speed = skills.dive_speed
	if skills.fear_left > 0: speed = 5.0
	if direction.length_squared()>0.01 or (is_player and active):
		var facing: float = game.camera_yaw+PI if is_player and not external_control else atan2(direction.x,direction.z)
		if skills.fear_left > 0: facing = atan2(direction.x,direction.z)
		var turn_rate := 28.0 if is_player else 14.0
		pivot.rotation.y = lerp_angle(pivot.rotation.y,facing,1-exp(-delta*turn_rate))
	var acceleration := 40.0 if is_on_floor() else 19.0
	if is_player:
		acceleration = 96.0 if is_on_floor() else 42.0
		if is_on_floor():
			var planar_velocity := Vector3(velocity.x,0,velocity.z)
			if direction.length_squared() < .01:
				acceleration = 140.0
			elif planar_velocity.dot(direction) < 0.0:
				acceleration = 200.0
	if hit_cooldown>.30: acceleration = 5
	velocity.x = move_toward(velocity.x,direction.x*speed,acceleration*delta)
	velocity.z = move_toward(velocity.z,direction.z*speed,acceleration*delta)
	if skills.dive_left > 0:
		velocity.x = direction.x*speed
		velocity.z = direction.z*speed
	if skills.knockback_left > 0:
		velocity.x = skills.knockback.x * minf(1.0,skills.knockback_left/.15)
		velocity.z = skills.knockback.z * minf(1.0,skills.knockback_left/.15)
	if skills.frozen_left > 0:
		velocity.x = 0
		velocity.z = 0
	if not is_on_floor(): velocity.y -= GRAVITY*delta
	if item_state.jetpack > 0 and active and not finished and not skills.controlled():
		velocity.y = move_toward(velocity.y,6.0,38.0*delta)
	if jump_buffer>0 and coyote>0:
		velocity.y = JUMP_SPEED
		jump_buffer = 0
		coyote = 0
		squash = 1.18
		game.action_sound('jump',self)
	var incoming_velocity := velocity
	var floor_before := is_on_floor()
	move_and_slide()
	if is_instance_valid(game.feedback): game.feedback.movement(self,floor_before,incoming_velocity)
	if skills.dive_left > 0: skills.resolve_dive_collisions(incoming_velocity)
	if active and not finished:
		var impulse: Vector3 = game.course.hazard_at(position)
		if impulse.length_squared()>0 and hit_cooldown<=0 and invulnerable<=0:
			velocity = impulse
			hit_cooldown = .8
			squash = .75
			game.action_sound('knockdown',self)
		if position.y < -6: respawn()
		if not game.in_island and position.y > -.2 and position.y < 2.5 and absf(position.x)<9.3:
			for i in range(1,game.course.CHECKPOINTS.size()):
				if position.z < game.course.CHECKPOINTS[i].z and i > checkpoint:
					checkpoint = i
					if is_player: game.checkpoint_reached(i)
		if not game.in_island and position.z < game.course.FINISH_Z and absf(position.x) < 10.7 and position.y > -.2 and position.y < 2.5:
			game.cross_finish(self)
		furthest = minf(furthest,position.z)
	animate(delta)

func animate(delta: float) -> void:
	var grounded := is_on_floor()
	if grounded and not was_grounded: squash = .81
	was_grounded = grounded
	squash = lerpf(squash,1.0,1-exp(-delta*15))
	var moving := Vector2(velocity.x,velocity.z).length()
	bob += delta*moving*1.55
	var walk_weight := minf(moving/4.0,1.0) if grounded and roll_left <= 0 and skills.dive_left <= 0 else 0.0
	pivot.rotation.z = lerpf(pivot.rotation.z,sin(bob)*.13*walk_weight,1-exp(-delta*18))
	pivot.rotation.x = lerpf(pivot.rotation.x,(.04+cos(bob*2)*.035)*walk_weight,1-exp(-delta*18))
	pivot.scale = Vector3(1.0/sqrt(squash),squash,1.0/sqrt(squash))
	pivot.position.y = .85+absf(sin(bob))*.075*walk_weight
	pivot.position.x = sin(bob)*.055*walk_weight*cos(pivot.rotation.y)
	pivot.position.z = -sin(bob)*.055*walk_weight*sin(pivot.rotation.y)
	if skills.dive_left > 0:
		roll_visual.rotation.x = lerp_angle(roll_visual.rotation.x, PI*.48, 1-exp(-delta*30))
	elif roll_left > 0:
		roll_visual.rotation.x -= delta*17
	else:
		roll_visual.rotation.x = lerp_angle(roll_visual.rotation.x,0,1-exp(-delta*18))
	for part in limbs:
		var node: Node3D = limbs[part][0]
		var base: Vector3 = limbs[part][1]
		var sign_value := -1 if part.ends_with('L') else 1
		var phase := sin(bob)*sign_value*minf(moving/4,1)
		node.position = base + Vector3(0,maxf(0,phase)*.13 if part.begins_with('Foot') and grounded else 0,phase*.12)
		node.rotation.x = phase*.35
		if not grounded and part.begins_with('Arm'): node.rotation.z = sign_value*-.65
		else: node.rotation.z = sign_value*(.12+sin(bob)*.12)*walk_weight if part.begins_with('Arm') else 0
	var slash_pose := Vector3.ZERO
	if skills.attack_left > 0:
		var elapsed: float = skills.fish.visual_time
		var progress := preload('res://scripts/swing_motion.gd').phase(elapsed)
		var weight := sin(PI*clampf(elapsed/.52,0,1))
		pivot.rotation.y = atan2(skills.attack_forward.x,skills.attack_forward.z)
		slash_pose = Vector3(lerpf(-.13,.22,progress),lerpf(-.28,.32,progress),lerpf(.13,-.18,progress))*weight
		for part in ['ArmL','ArmR']:
			if limbs.has(part):
				limbs[part][0].rotation.x += lerpf(-.7,.35,progress)*weight
	model.rotation = model.rotation.lerp(slash_pose,1-exp(-delta*28))
	if skills.attack_left > 0: skills.fish.sync_hands()
	var outfit_rig := model.get_node_or_null('SkinAccessories/OutfitRig')
	if outfit_rig: outfit_rig.sync()
