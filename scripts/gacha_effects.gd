extends Control
const S = preload('res://scripts/outfit_models.gd')
const Catalog = preload('res://scripts/skin_catalog.gd')
var age := 0.0
var accent := Color('#62d8ff')
var glow: ShaderMaterial
var stage: SubViewport
var world: Node3D
var shell: Node3D
var top: Node3D
var bottom: Node3D
var prize: Node3D
var key_light: OmniLight3D
var particles: CPUParticles2D
var sparkles: CPUParticles2D
var opening := 0.0
var result_mode := false
var flash := 0.0
var prize_id := ''

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(1440,900)
	var background := ColorRect.new()
	background.size = size
	background.mouse_filter = MOUSE_FILTER_IGNORE
	glow = ShaderMaterial.new()
	glow.shader = preload('res://assets/shaders/gacha_glow.gdshader')
	background.material = glow
	add_child(background)
	var container := SubViewportContainer.new()
	container.position = Vector2(245,125)
	container.size = Vector2(950,650)
	container.stretch = true
	container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(container)
	stage = SubViewport.new()
	stage.size = Vector2i(950,650)
	stage.transparent_bg = true
	stage.own_world_3d = true
	stage.mesh_lod_threshold = 0.0
	stage.msaa_3d = Viewport.MSAA_2X
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(stage)
	world = Node3D.new()
	stage.add_child(world)
	var environment := WorldEnvironment.new()
	var env := preload('res://scripts/outfit_lighting.gd').environment()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color('#10214a')
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color('#b3ceff')
	env.ambient_light_energy = .5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = .85
	env.glow_bloom = .13
	environment.environment = env
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,1.6,6.2)
	camera.look_at(Vector3(0,1.04,0))
	camera.fov = 31
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-32,0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	world.add_child(light)
	key_light = OmniLight3D.new()
	key_light.position = Vector3(1.4,1.7,1.5)
	key_light.omni_range = 6
	key_light.light_energy = 1.4
	world.add_child(key_light)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2,2,-1.2)
	rim.omni_range = 5
	rim.light_color = Color('#8766ff')
	rim.light_energy = 2.4
	world.add_child(rim)
	shell = Node3D.new()
	world.add_child(shell)
	shell.position.y = 1.05
	top = Node3D.new()
	bottom = Node3D.new()
	shell.add_child(top)
	shell.add_child(bottom)
	var pearl := S.mat(Color('#d6e0f2'))
	pearl.metallic = .3
	pearl.roughness = .18
	var blue := S.mat(Color('#5268d9'))
	blue.roughness = .24
	for half in [top,bottom]:
		var dome := SphereMesh.new()
		dome.radius = .72
		dome.height = .72
		dome.is_hemisphere = true
		dome.radial_segments = 64
		dome.rings = 24
		S.mesh(half,dome,Vector3.ZERO,Vector3.ONE,pearl if half == top else blue)
		var disk := CylinderMesh.new()
		disk.top_radius = .70
		disk.bottom_radius = .70
		disk.height = .04
		disk.radial_segments = 64
		S.mesh(half,disk,Vector3.ZERO,Vector3.ONE,S.mat(Color('#172757')))
		S.ring(half,Vector3.ZERO,.745,S.mat(Color('#67e7ff'),true)).scale.y = .28
	bottom.rotation.z = PI
	var badge := S.ring(top,Vector3(0,.25,.71),.19,S.mat(Color('#74e7ff'),true))
	badge.rotation.x = PI/2
	S.ball(top,Vector3(0,.25,.73),Vector3(.13,.13,.035),pearl)
	prize = preload('res://assets/models/racer.glb').instantiate()
	world.add_child(prize)
	prize.hide()
	particles = emitter(100,1.9,170,460)
	particles.one_shot = true
	particles.explosiveness = .94
	sparkles = emitter(38,4.0,8,35)
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkles.emission_rect_extents = Vector2(560,320)
	sparkles.position = Vector2(720,470)
	sparkles.emitting = true

func emitter(count: int, lifetime: float, low: float, high: float) -> CPUParticles2D:
	var node := CPUParticles2D.new()
	node.amount = count
	node.lifetime = lifetime
	node.position = Vector2(720,460)
	node.direction = Vector2.UP
	node.spread = 180
	node.initial_velocity_min = low
	node.initial_velocity_max = high
	node.gravity = Vector2(0,15)
	node.scale_amount_min = .10
	node.scale_amount_max = .40
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	node.texture = texture
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0,.15,.7,1])
	fade.colors = PackedColorArray([Color(1,1,1,0),Color.WHITE,Color.WHITE,Color(1,1,1,0)])
	node.color_ramp = fade
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = material
	node.emitting = false
	add_child(node)
	return node

func set_prize(id: String) -> void:
	prize_id = id
	accent = Catalog.rarity_color(id).lightened(.28)
	if Catalog.get_skin(id).get('rarity') == '至臻': accent = Color('#ffcd69')
	Catalog.apply(prize,id)
	glow.set_shader_parameter('tint',accent)
	key_light.light_color = accent
	particles.color = accent
	sparkles.color = accent

func burst() -> void:
	flash = 1.0
	particles.restart()
	particles.emitting = true

func reveal() -> void:
	shell.hide()
	prize.show()
	prize.scale = Vector3.ONE*.02
	var tween := create_tween()
	tween.tween_property(prize,'scale',Vector3.ONE,.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst()

func settle() -> void:
	result_mode = true
	shell.hide()
	prize.hide()
	stage.get_parent().hide()
	stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	flash = .3

func _process(delta: float) -> void:
	age += delta
	flash = maxf(0,flash-delta*1.35)
	glow.set_shader_parameter('clock',age)
	glow.set_shader_parameter('flash',flash)
	glow.set_shader_parameter('power',.50 if result_mode else .65+opening*.9)
	if shell.visible:
		shell.rotation = Vector3(.08*sin(age*2),age*.9,.08*sin(age*8)*(1+opening))
		shell.position.y = 1.05+sin(age*3)*.06
		top.position.y = opening*.8
		top.rotation.z = opening*-.38
		bottom.position.y = -opening*.5
	if prize.visible: prize.rotation.y = -.25+sin(age*.65)*.16
	queue_redraw()

func _draw() -> void:
	var intensity := .35 if result_mode else .55
	for i in range(3):
		var r := 100.0+fmod(age*38+i*83,280)
		draw_arc(Vector2(720,480),r,0,TAU,100,Color(accent, intensity*(1-(r-100)/280)),1.2,true)
	if flash > 0:
		for i in range(20):
			var a := TAU*i/20.0+age*.04
			var inner := Vector2(720,440)+Vector2.from_angle(a)*80
			var outer := Vector2(720,440)+Vector2.from_angle(a)*(400+100*sin(i*3.0))
			draw_line(inner,outer,Color(accent,flash*.24),2,true)
