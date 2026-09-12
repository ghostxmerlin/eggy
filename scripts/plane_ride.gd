extends Node3D

const DOCK := Vector3(36,11.9,13)
const SEAT := Vector3(0,.25,0)
const TAKEOFF_SECONDS := 5.0
const CRUISE_SECONDS := 20.0
const LANDING_SECONDS := 6.0
var game: Node3D
var builder: Node3D
var body: AnimatableBody3D
var canopy: Node3D
var canopy_open := 0.0
var propeller: Node3D
var entry_gate: CollisionShape3D
var label: Label3D
var passenger: CharacterBody3D
var state := 'parked'
var state_time := 0.0
var boarding_time := 0.0

func _ready() -> void:
	game = get_parent().get_parent().get_parent()
	builder = get_parent()
	build_aircraft()
	build_boarding_ramp()
	label = builder.lettering(self,'',DOCK+Vector3(0,3.4,0),36,Color('#264b68'))
	label.font = preload('res://assets/fonts/CloudSans-Heavy.ttf')
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	set_state('parked')

func collider(position: Vector3, size: Vector3) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	node.shape = shape
	node.position = position
	body.add_child(node)
	return node

func build_aircraft() -> void:
	body = AnimatableBody3D.new()
	body.name = 'LittlePlane'
	body.sync_to_physics = false
	add_child(body)
	body.position = DOCK
	builder.sphere(body,Vector3(0,.02,-2.0),Vector3(1.04,.77,1.45),'orange')
	builder.sphere(body,Vector3(0,-.05,2.0),Vector3(.82,.64,1.25),'orange')
	builder.block(body,Vector3(0,.15,0),Vector3(2.2,.24,2.4),'mint_dark')
	collider(Vector3(0,.15,0),Vector3(2.2,.24,2.4))
	builder.block(body,Vector3(0,-.05,.15),Vector3(8,.22,1.5),'yellow')
	collider(Vector3(0,-.05,.15),Vector3(8,.22,1.5))
	for z in [-1.16,1.16]:
		builder.block(body,Vector3(0,.46,z),Vector3(2.2,.40,.18),'orange')
		collider(Vector3(0,.46,z),Vector3(2.2,.40,.18))
	builder.block(body,Vector3(1.04,.46,0),Vector3(.18,.40,2.2),'orange')
	collider(Vector3(1.04,.46,0),Vector3(.18,.40,2.2))
	# The left side is the boarding opening, aligned with the ramp.
	entry_gate = collider(Vector3(-1.10,1.1,0),Vector3(.12,1.7,1.8))
	builder.block(body,Vector3(0,.12,2.55),Vector3(3.1,.18,.85),'mint')
	builder.block(body,Vector3(0,.80,2.6),Vector3(.18,1.5,.85),'mint')
	for side in [-1,1]:
		builder.sphere(body,Vector3(side*3.85,.03,.15),Vector3(.35,.22,.72),'pink')
		builder.rod(body,Vector3(side*.7,-.2,.5),Vector3(side*.85,-1.02,.5),.09,'mint_dark')
		builder.sphere(body,Vector3(side*.85,-1.05,.5),Vector3(.16,.27,.27),'dark')
		builder.sphere(body,Vector3(side*.95,-1.05,.5),Vector3(.06,.13,.13),'cream')
	propeller = Node3D.new()
	body.add_child(propeller)
	propeller.position.z = -3.5
	builder.block(propeller,Vector3.ZERO,Vector3(2.6,.15,.18),'cream')
	builder.block(propeller,Vector3.ZERO,Vector3(.15,2.6,.18),'cream')
	builder.sphere(propeller,Vector3.ZERO,Vector3.ONE*.25,'mint_dark')
	canopy = Node3D.new()
	canopy.name = 'HingedGrayCanopy'
	body.add_child(canopy)
	canopy.position = Vector3(1.10,.57,0)
	var glass := MeshInstance3D.new()
	glass.mesh = canopy_mesh()
	glass.position.x = -1.10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.43,.53,.60,.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = .16
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	canopy.add_child(glass)
	for i in range(32):
		var a := TAU*i/32.0
		var b := TAU*(i+1)/32.0
		builder.rod(canopy,Vector3(-1.10+cos(a)*1.16,0,sin(a)*1.35),Vector3(-1.10+cos(b)*1.16,0,sin(b)*1.35),.045,'dark')
	for z in [-.72,.72]:
		var width := 1.16*sqrt(1-pow(z/1.35,2))
		var height := 1.86*sqrt(1-pow(z/1.35,2))
		for i in range(12):
			var a := PI*i/12.0
			var b := PI*(i+1)/12.0
			builder.rod(canopy,Vector3(-1.10+cos(a)*width,sin(a)*height,z),Vector3(-1.10+cos(b)*width,sin(b)*height,z),.025,'cream')

func canopy_mesh() -> Mesh:
	# An open-bottom ellipsoidal shell that exactly follows the hinged rim and ribs.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for j in range(17):
		var latitude := float(j)/16*PI*.5
		for i in range(33):
			var angle := float(i)/32*TAU
			var unit := Vector3(cos(latitude)*cos(angle),sin(latitude),cos(latitude)*sin(angle))
			vertices.append(unit*Vector3(1.16,1.86,1.35))
			normals.append((unit/Vector3(1.16,1.86,1.35)).normalized())
	for j in range(16):
		for i in range(32):
			var a := j*33+i
			for index in [a,a+33,a+1,a+1,a+33,a+34]:
				surface.set_normal(normals[index])
				surface.add_vertex(vertices[index])
	return surface.commit()

func build_boarding_ramp() -> void:
	# A continuous slope avoids requiring step-up behavior in the character controller.
	var start := Vector3(29.4,10.60,13)
	var end := Vector3(31.4,12.17,13)
	var ramp = builder.block(self,(start+end)*.5-Vector3(0,.09,0),Vector3(start.distance_to(end),.18,1.6),'cream',true)
	ramp.rotation.z = atan2(end.y-start.y,end.x-start.x)
	for z in [-.87,.87]:
		builder.rod(self,start+Vector3(0,.08,z),end+Vector3(0,.08,z),.045,'yellow')
	# Reach wing height before its outer edge, then cross on a level gangway.
	builder.block(self,Vector3(33.3,12.08,13),Vector3(3.8,.18,1.6),'cream',true)
	builder.sign_at('环岛小飞机',Vector3(36,10.6,18.0))

func set_state(next: String) -> void:
	state = next
	state_time = 0
	boarding_time = 0
	var messages := {'parked':'靠近飞机，打开舱盖','opening':'正在开舱','boarding':'走进机舱，站稳出发','closing':'站稳啦，准备起飞','takeoff':'起飞啦！','cruise':'环岛观光中','landing':'准备降落','landed':'已停稳，正在开舱','disembark':'舱盖已打开，可以下机'}
	label.text = messages[next]

func player_near() -> bool:
	if not is_instance_valid(game.player): return false
	var p: Vector3 = body.to_local(game.player.global_position)
	return Vector2(p.x,p.z).length() < 8.0 and absf(p.y) < 3.0

func in_cabin(player: CharacterBody3D) -> bool:
	var p := body.to_local(player.global_position)
	return absf(p.x) < .73 and absf(p.z) < .77 and p.y > .12 and p.y < .55

func board() -> void:
	passenger = game.player
	passenger.board_vehicle(self)
	set_state('closing')

func passenger_position() -> Vector3:
	return body.to_global(SEAT)

func cancel_passenger(player: CharacterBody3D) -> void:
	if passenger == player: passenger = null
	player.remove_collision_exception_with(body)
	player.vehicle = null

func release_passenger() -> void:
	if is_instance_valid(passenger):
		var player := passenger
		cancel_passenger(player)
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()

func _exit_tree() -> void:
	release_passenger()

func bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float) -> Vector3:
	return a*pow(1-u,3)+b*3*pow(1-u,2)*u+c*3*(1-u)*u*u+d*u*u*u

func flight_point(phase: String, u: float) -> Vector3:
	u = clampf(u,0,1)
	if phase == 'takeoff': return bezier(DOCK,Vector3(36,24,-3),Vector3(60,34,-15.8),Vector3(60,34,13),u*u*(2-u))
	if phase == 'landing': return bezier(Vector3(60,34,13),Vector3(60,34,47.56),Vector3(36,24,29),DOCK,u+u*u-u*u*u)
	var angle := u*TAU
	return Vector3(cos(angle)*60,34+sin(angle)*2,13+sin(angle)*55)

func fly(phase: String, duration: float, delta: float) -> void:
	var u := minf(1,state_time/duration)
	var previous_yaw := body.rotation.y
	body.position = flight_point(phase,u)
	var direction := (flight_point(phase,minf(1,u+.003))-flight_point(phase,maxf(0,u-.003))).normalized()
	var desired_yaw := atan2(-direction.x,-direction.z)
	body.rotation.y = lerp_angle(body.rotation.y,desired_yaw,1-exp(-delta*7))
	body.rotation.x = lerpf(body.rotation.x,clampf(direction.y,-.18,.18),1-exp(-delta*3))
	body.rotation.z = lerpf(body.rotation.z,.10 if phase == 'cruise' else 0.0,1-exp(-delta*3))
	if is_instance_valid(passenger): game.camera_yaw += wrapf(body.rotation.y-previous_yaw,-PI,PI)

func _physics_process(delta: float) -> void:
	if game.paused: return
	state_time += delta
	var open_target := 1.0 if state in ['opening','boarding','disembark'] or (state == 'landed' and state_time > 1.0) else 0.0
	canopy_open = move_toward(canopy_open,open_target,delta)
	canopy.rotation.z = -1.83*canopy_open
	entry_gate.set_deferred('disabled',canopy_open > .98)
	propeller.rotation.z += delta*(35.0 if state in ['closing','takeoff','cruise','landing'] else 3.5)
	match state:
		'parked':
			if state_time > 2.0 and player_near(): set_state('opening')
		'opening':
			if canopy_open >= 1.0: set_state('boarding')
		'boarding':
			var player: CharacterBody3D = game.player
			if in_cabin(player) and player.is_on_floor() and not player.skills.controlled(): boarding_time += delta
			else: boarding_time = 0
			if boarding_time > .5: board()
			elif not player_near() and state_time > 3: set_state('parked')
		'closing':
			if state_time >= 1.5: set_state('takeoff')
		'takeoff':
			fly('takeoff',TAKEOFF_SECONDS,delta)
			if state_time >= TAKEOFF_SECONDS: set_state('cruise')
		'cruise':
			fly('cruise',CRUISE_SECONDS,delta)
			if state_time >= CRUISE_SECONDS: set_state('landing')
		'landing':
			fly('landing',LANDING_SECONDS,delta)
			if state_time >= LANDING_SECONDS:
				body.position = DOCK
				if is_instance_valid(passenger): game.camera_yaw += wrapf(-body.rotation.y,-PI,PI)
				body.rotation = Vector3.ZERO
				set_state('landed')
		'landed':
			if canopy_open >= 1.0:
				release_passenger()
				set_state('disembark')
		'disembark':
			var p: Vector3 = body.to_local(game.player.global_position)
			if Vector2(p.x,p.z).length() > 2.0 or absf(p.y) > 2.0: set_state('parked')
