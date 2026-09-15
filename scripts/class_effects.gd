extends Node3D
# Code-native spell silhouettes: travelling shafts, frost shards, dark wisps, metal sparks.
const Catalog = preload('res://scripts/class_catalog.gd')
var kit: Node3D
var transient: Array = []
var marks := {}
var label: Label3D
var clock := 0.0
var bow: Node3D
var casting: Node3D
var pause_state := false
func _ready():
	kit = get_parent()
	label = text_label('',Color.WHITE,24)
	label.position.y = 3.1
	add_child(label)
	for key in ['root','slow','stun','reflect','block','stealth','wound','storm']:
		var node := Node3D.new()
		add_child(node)
		marks[key] = node
		match key:
			'root':
				for i in range(7):
					var a := i*TAU/7
					var crystal = shard(node,Vector3(sin(a)*.78,.45,cos(a)*.78),.21,1.05,Color('#80eaff'))
					crystal.rotation.z = sin(a)*.4
			'slow': ring(node,Vector3(0,.15,0),.68,Color('#80d1e3'))
			'stun':
				for i in range(3):
					var star := Node3D.new()
					node.add_child(star)
					star.position = Vector3(cos(i*TAU/3)*.45,2.65,sin(i*TAU/3)*.45)
					star_mesh(star)
			'reflect':
				var shield = shard(node,Vector3(0,1.0,-.8),.65,.13,Color('#ffe8a3'))
				shield.rotation.x = PI/2
				var border = ring(node,Vector3(0,1,-.9),.7,Color('#ffca57'))
				border.rotation.x = PI/2
			'block':
				var crystal = shard(node,Vector3(0,1.05,0),1.0,2.5,Color(.32,.78,1,.56))
				crystal.mesh.top_radius = .64
				crystal.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				crystal.material_override.roughness = .16
				crystal.material_override.emission_energy_multiplier = .2
				for y in [.15,1.75]: ring(node,Vector3(0,y,0),.85,Color('#a6efff'))
				for i in range(6): shard(node,Vector3(sin(i)*.7,.25,cos(i)*.7),.15,.75,Color('#c3f4ff'))
			'stealth':
				for i in range(5):
					var wisp = shard(node,Vector3(sin(i*2)*.6,.2+i*.3,cos(i*2)*.6),.07,.35,Color('#8768bd'))
					wisp.rotation.z = .8
			'storm':
				for i in range(3):
					var a := i*TAU/3
					var blade = shard(node,Vector3(sin(a)*1.4,1.1,cos(a)*1.4),.17,2.0,Color('#ffe7a1'))
					blade.quaternion = Quaternion(Vector3.UP,Vector3(sin(a),0,cos(a)))
			'wound':
				for x in [-.16,0,.16]:
					var cut = shard(node,Vector3(x,2.5,0),.035,.4,Color('#ef865d'))
					cut.rotation.z = -.5
		node.hide()
	bow = Node3D.new()
	add_child(bow)
	var shapes = preload('res://scripts/outfit_models.gd')
	shapes.tube(bow,[Vector3(-.2,.68,0),Vector3(.05,.55,0),Vector3(.16,0,0),Vector3(.05,-.55,0),Vector3(-.2,-.68,0)],.055,shapes.mat(Color('#af7951')))
	shapes.tube(bow,[Vector3(-.2,.68,0),Vector3(-.2,0,.18),Vector3(-.2,-.68,0)],.012,mat(Color('#e8ffb5')))
	bow.position = Vector3(.5,1.1,-.8)
	casting = Node3D.new()
	add_child(casting)
	for side in [-1,1]:
		var glyph = ring(casting,Vector3(side*.6,1.1,-.65),.24,Color('#b5ecff'))
		glyph.rotation.x = PI/2
	bow.hide()
	casting.hide()
func star_mesh(parent: Node3D):
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(10):
		var a := i*TAU/10
		var b := (i+1)*TAU/10
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(Vector3(sin(a),cos(a),0)*(.22 if i%2 == 0 else .09))
		surface.add_vertex(Vector3(sin(b),cos(b),0)*(.22 if (i+1)%2 == 0 else .09))
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = mat(Color('#ffea74'))
	parent.add_child(mesh)
func mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(color,1)
	m.emission_energy_multiplier = .7
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
func shard(parent: Node3D, pos: Vector3, radius: float, length: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 5
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
func ring(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(.02,radius-.028)
	mesh.outer_radius = radius+.028
	mesh.rings = 32
	mesh.ring_segments = 5
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = mat(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
func text_label(text: String, color: Color, size: int) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font = preload('res://assets/fonts/CloudSans-Heavy.ttf')
	node.font_size = size
	node.pixel_size = .012
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.modulate = color
	node.outline_size = 5
	return node
func nearby(pos: Vector3) -> bool:
	return is_instance_valid(kit.racer.game.player) and pos.distance_to(kit.racer.game.player.position) < 30
func pulse(kind: String, pos: Vector3, color: Color, radius := 1.0, duration := .5):
	if not nearby(pos) or transient.size() >= 14: return
	var node := Node3D.new()
	add_child(node)
	node.top_level = true
	node.global_position = pos
	if kind in ['nova','trap','blink','charge','storm','shout','block','reflect','stealth']:
		ring(node,Vector3(0,.12,0),radius,color)
		if kind in ['nova','trap']:
			var flake := MeshInstance3D.new()
			flake.mesh = preload('res://scripts/skill_shapes.gd').snowflake(.09)
			flake.scale = Vector3.ONE*radius/6.0
			flake.material_override = mat(color)
			flake.position.y = .14
			node.add_child(flake)
		if kind == 'shout':
			for y in [.65,1.2]: ring(node,Vector3(0,y,0),radius*.8,color)
	var count := 12 if kind in ['nova','trap','storm','shout'] else 8
	for i in range(count):
		var angle := i*TAU/count
		var ray = shard(node,Vector3(cos(angle)*radius*.3,.3+(i%3)*.17,sin(angle)*radius*.3),.055,.4,color)
		ray.rotation = Vector3(sin(angle)*1.1,angle,cos(angle)*1.1)
	transient.append({'node':node,'age':0.0,'duration':duration,'kind':'pulse','radius':radius})
func number(value: String, color: Color):
	if not nearby(kit.racer.position) or transient.size() >= 14: return
	var node := text_label(value,color,40)
	add_child(node)
	node.top_level = true
	node.global_position = kit.racer.global_position+Vector3(.22,2.0,0)
	transient.append({'node':node,'age':0.0,'duration':.8,'kind':'number','radius':1.0})
func missile(kind: String, pos: Vector3, direction: Vector3, color: Color) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.top_level = true
	node.global_position = pos
	node.quaternion = Quaternion(Vector3.UP,direction.normalized())
	shard(node,Vector3(0,.25,0),.10 if kind in ['frostbolt','lance'] else .055,.7,color)
	shard(node,Vector3(0,-.3,0),.045,.7,Color('#fffbe5'))
	for i in range(3):
		shard(node,Vector3(sin(i*2)*.12,-.4-i*.2,cos(i*2)*.12),.045,.18,color)
	var particles := GPUParticles3D.new()
	particles.amount = 14
	particles.lifetime = .25
	particles.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = .1
	process.initial_velocity_max = .4
	process.scale_min = .025
	process.scale_max = .05
	particles.process_material = process
	var spark := SphereMesh.new()
	spark.radius = .5
	spark.height = 1
	spark.radial_segments = 5
	spark.rings = 3
	spark.material = mat(color)
	particles.draw_pass_1 = spark
	node.add_child(particles)
	return node
func tick(delta: float, states: Dictionary, career_id: String):
	clock += delta
	for key in marks: marks[key].visible = states.has(key)
	marks.block.visible = states.has('block') or states.has('trap')
	marks.storm.rotation.y = clock*TAU*2
	bow.visible = career_id == 'hunter' and kit.pose_left > 0
	casting.visible = career_id == 'mage' and kit.pose_left > 0
	var yaw: float = kit.racer.game.camera_yaw if kit.racer.is_player else kit.racer.pivot.rotation.y-PI
	bow.rotation.y = yaw
	bow.position = Vector3(.5,1.1,-.8).rotated(Vector3.UP,yaw)
	casting.rotation.y = yaw
	marks.stun.rotation.y = clock*2
	for star in marks.stun.get_children():
		if kit.racer.game.camera: star.look_at(kit.racer.game.camera.global_position,Vector3.UP,true)
	marks.stealth.rotation.y = clock*2
	marks.reflect.rotation.y = kit.racer.game.camera_yaw if kit.racer.is_player else kit.racer.pivot.rotation.y-PI
	label.text = status_text(states)
	label.visible = label.text != ''
	label.modulate = Color('#d5f7ff') if states.has('root') or states.has('slow') else Color('#fff0c0')
	# The owner sees a faint silhouette; distant enemies cannot see the body or status label.
	var hidden: bool = states.has('stealth')
	var concealed: bool = hidden and not kit.racer.is_player and kit.racer.position.distance_to(kit.racer.game.player.position) > 1.7
	if concealed:
		label.hide()
		marks.stealth.hide()
	var alpha := 1.0 if concealed else .82 if hidden else 0.0
	if alpha != kit.get_meta('ghost_alpha',-1.0):
		kit.set_meta('ghost_alpha',alpha)
		for mesh in kit.racer.model.find_children('*','GeometryInstance3D',true,false): mesh.transparency = alpha
	for i in range(transient.size()-1,-1,-1):
		var e: Dictionary = transient[i]
		e.age += delta
		var p: float = e.age/e.duration
		if p >= 1:
			e.node.queue_free()
			transient.remove_at(i)
			continue
		if e.kind == 'number':
			e.node.position.y += delta*.9
			e.node.modulate.a = minf(1,(1-p)*2)
		else:
			e.node.scale = Vector3.ONE*lerpf(.35,1.35,p)
			for child in e.node.get_children():
				if child is MeshInstance3D: child.material_override.albedo_color.a = 1-p
func status_text(states: Dictionary) -> String:
	var labels := {'root':'定身','slow':'减速','stun':'眩晕','reflect':'法术反射','block':'寒冰屏障','stealth':'潜行','wound':'重伤','trap':'冰冻','fear':'恐惧','storm':'剑刃风暴'}
	var lines: Array[String] = []
	for key in states:
		if key in labels: lines.append('%s %.1f' % [labels[key],states[key]])
	return ' · '.join(lines)
func clear():
	for e in transient: e.node.queue_free()
	transient.clear()
	for node in marks.values(): node.hide()
	label.hide()

func _process(_delta: float):
	if not is_instance_valid(kit) or kit.racer.game.paused == pause_state: return
	pause_state = kit.racer.game.paused
	for shot in kit.missiles:
		for child in shot.node.get_children():
			if child is GPUParticles3D: child.speed_scale = 0.0 if pause_state else 1.0
