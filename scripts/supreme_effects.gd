extends Node3D
const S = preload('res://scripts/outfit_models.gd')
var glint := ShaderMaterial.new()
var veil := ShaderMaterial.new()
var fire := ShaderMaterial.new()
var cape: MeshInstance3D
var particles: GPUParticles3D
var corona: Node3D
var racer: Node3D
var clock := 0.0
var motion := 0.0
var fold := 0.0
var last_position := Vector3.ZERO

func _ready() -> void:
	name = 'SupremeEffects'
	glint.shader = preload('res://assets/shaders/supreme_gold.gdshader')
	veil.shader = preload('res://assets/shaders/supreme_cape.gdshader')
	fire.shader = preload('res://assets/shaders/supreme_flames.gdshader')
	var parent := get_parent()
	while parent:
		if parent.is_in_group('combatants'):
			racer = parent
			break
		parent = parent.get_parent()
	build_cape()
	build_corona()
	build_particles()
	last_position = global_position

func build_cape() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for row in range(20):
			for column in range(10):
				for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					var uv := Vector2((column+corner.x)/10.0,(row+corner.y)/20.0)
					var width := lerpf(.43,.87,uv.y)
					var x: float = side*(.10+uv.x*width)
					var hem := .13*sin(uv.x*PI)
					var vertex := Vector3(x,1.38-uv.y*(1.35+hem),-.78-uv.y*.3)
					surface.set_uv(uv)
					surface.add_vertex(vertex)
	surface.generate_normals()
	cape = S.mesh(self,surface.commit(),Vector3.ZERO,Vector3.ONE,veil)
	cape.name = 'ParticleCape'
	cape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cape.extra_cull_margin = 1.0
	var clasp := S.mat(Color('#ffdc6c'),true)
	clasp.emission_energy_multiplier = 2.8
	for side in [-1,1]:
		S.ball(self,Vector3(side*.38,1.36,-.78),Vector3(.095,.08,.045),clasp)

func build_corona() -> void:
	corona = Node3D.new()
	corona.name = 'SolarCorona'
	corona.position = Vector3(0,1.30,-.86)
	add_child(corona)
	var light := S.mat(Color('#ffc329'),true)
	light.emission_energy_multiplier = 2.3
	var circle := S.ring(corona,Vector3.ZERO,.85,light)
	circle.mesh.inner_radius = .833
	circle.rotation.x = PI/2
	# Continuous tapered flame volumes project backwards from the halo, not radial ticks.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(18):
		var angle := TAU*i/18.0
		var anchor := Vector3(sin(angle)*.85,cos(angle)*.85,0)
		var length := .60+.32*(.5+.5*sin(i*2.4))
		for row in range(14):
			for column in range(8):
				for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					var uv := Vector2((column+corner.x)/8.0,(row+corner.y)/14.0)
					var radius := .073*pow(1.0-uv.y,.7)*(1.0+.30*sin(uv.y*PI))
					var radial := Vector3(cos(uv.x*TAU),sin(uv.x*TAU),0)
					surface.set_uv(uv)
					surface.set_color(Color(i/18.0,0,0,1))
					surface.add_vertex(anchor+radial*radius+Vector3(0,0,-uv.y*length))
	surface.generate_normals()
	var flames := S.mesh(corona,surface.commit(),Vector3.ZERO,Vector3.ONE,fire)
	flames.name = 'RearwardFlames'
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.extra_cull_margin = 1.0
	for child in corona.get_children():
		if child is GeometryInstance3D: child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_particles() -> void:
	particles = GPUParticles3D.new()
	particles.name = 'CapeSparks'
	particles.amount = 160
	particles.lifetime = 1.65
	particles.preprocess = .8
	particles.local_coords = false
	particles.position = Vector3(0,.66,-.92)
	particles.visibility_aabb = AABB(Vector3(-3,-2,-4),Vector3(6,6,7))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(.82,.55,.06)
	process.direction = Vector3(0,-.25,-1)
	process.spread = 32
	process.initial_velocity_min = .12
	process.initial_velocity_max = .65
	process.gravity = Vector3(0,.15,0)
	process.scale_min = .45
	process.scale_max = .95
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0,.12,.6,1])
	fade.colors = PackedColorArray([Color(1,1,1,0),Color.WHITE,Color(1,1,1,.85),Color(1,1,1,0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	var spectrum := Gradient.new()
	spectrum.offsets = PackedFloat32Array([0,.16,.33,.5,.66,.83,1])
	spectrum.colors = PackedColorArray([Color('#ff397c'),Color('#af50ff'),Color('#438bff'),Color('#26efff'),Color('#5bff97'),Color('#ffda5a'),Color('#ff6844')])
	var colors := GradientTexture1D.new()
	colors.gradient = spectrum
	process.color_initial_ramp = colors
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(.022,.022)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.3,1.3,1.3,1)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,.22,1])
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.65),Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	texture.width = 32
	texture.height = 32
	material.albedo_texture = texture
	quad.material = material
	particles.draw_pass_1 = quad
	add_child(particles)

func _process(delta: float) -> void:
	var paused: bool = is_instance_valid(racer) and racer.game.paused
	var viewport := get_viewport()
	if viewport is SubViewport and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		paused = true
	particles.speed_scale = 0.0 if paused else 1.0
	if paused: return
	clock += delta
	var speed: float = racer.velocity.length() if is_instance_valid(racer) else 1.0
	var rolling: bool = is_instance_valid(racer) and (racer.roll_left > 0 or racer.skills.dive_left > 0)
	motion = lerpf(motion,clampf(speed/14.0,0,1),1-exp(-delta*8))
	fold = lerpf(fold,1.0 if rolling else 0.0,1-exp(-delta*14))
	veil.set_shader_parameter('clock',clock)
	veil.set_shader_parameter('motion',motion)
	veil.set_shader_parameter('fold',fold)
	glint.set_shader_parameter('clock',clock)
	fire.set_shader_parameter('clock',clock)
	fire.set_shader_parameter('motion',motion)
	fire.set_shader_parameter('fold',fold)
	particles.amount_ratio = .3 if rolling else 1.0
	if is_instance_valid(racer):
		if global_position.distance_to(last_position) > 5: particles.restart()
		if is_instance_valid(racer.game.player) and racer.global_position.distance_to(racer.game.player.global_position) > 28:
			particles.amount_ratio = .2
	last_position = global_position
