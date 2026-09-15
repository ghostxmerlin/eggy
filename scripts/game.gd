extends Node3D

const Rules = preload('res://scripts/race_rules.gd')
const Course = preload('res://scripts/course.gd')
const Island = preload('res://scripts/island.gd')
var in_island := false
const Racer = preload('res://scripts/racer.gd')
const RACE_SIZE := 32
const HUD = preload('res://scripts/hud.gd')
@export var practice := true
var rules = Rules.new()
var course: Node3D
var racers: Array = []
var player: CharacterBody3D
var camera: Camera3D
var hud: Control
var screen := 'menu'
var paused := false
var camera_yaw := 0.0
var camera_pitch := 0.0
var player_place := 0
var finish_time := 0.0
var toast := ''
var toast_time := 0.0
var go_time := 0.0
var last_tick := 4
var show_metrics := false
var last_frame_ms := 0.0
var audio: Dictionary = {}
var music: Node
var feedback: Node
var mouse_forward := false
var frame_times: Array[float] = []
var frame_count := 0
var elapsed_real := 0.0
var autoplay := false
var capture_run := false
var profile_finished := false
var profile_run := false
var last_screen := ''
var result_age := 0.0
var hud_refresh := 0.0
var confetti: GPUParticles3D
@export var skin_save_path := 'user://appearance.cfg'
var skin_store: RefCounted
var wardrobe: Control
var gacha: Control
var coin_console: Control
var items: Node3D
var duel: Node
@export var item_seed := -1
@export var start_seed := -1
var start_rng := RandomNumberGenerator.new()

func _ready() -> void:
	if start_seed >= 0: start_rng.seed = start_seed
	else: start_rng.randomize()
	var args := OS.get_cmdline_user_args()
	practice = practice and not '--race' in args
	get_window().title = '宜之有之派对'
	in_island = practice and not ('--practice' in args or '--autoplay' in args or '--profile' in args)
	skin_store = preload('res://scripts/skin_store.gd').new(skin_save_path)
	skin_store.load_skin()
	configure_inputs()
	configure_render_scale()
	build_lighting()
	course = Island.new() if in_island else Course.new()
	add_child(course)
	for i in range(1 if practice else RACE_SIZE):
		add_racer(i)
	player = racers[0]
	player.set_skin(skin_store.selected_id)
	reset_racers()
	player.pivot.rotation.y = .22
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 53
	camera.near = .1
	camera.far = 420
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.position = Vector3(6.2,4.1,17)
	camera.look_at(Vector3(-1.8,1.0,5.8))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = HUD.new()
	hud.game = self
	canvas.add_child(hud)
	wardrobe = preload('res://scripts/wardrobe.gd').new()
	wardrobe.game = self
	canvas.add_child(wardrobe)
	gacha = preload('res://scripts/gacha_room.gd').new()
	gacha.game = self
	canvas.add_child(gacha)
	coin_console = preload('res://scripts/coin_console.gd').new()
	coin_console.game = self
	canvas.add_child(coin_console)
	for cue in ['jump','roll','checkpoint','finish','tick','go','fall']:
		var channel := AudioStreamPlayer.new()
		channel.stream = load('res://assets/audio/'+cue+'.wav')
		channel.volume_db = -9
		add_child(channel)
		audio[cue] = channel
	music = preload('res://scripts/background_music.gd').new()
	music.name = 'BackgroundMusic'
	add_child(music)
	music.play_theme('island' if in_island else 'race')
	feedback = preload('res://scripts/gameplay_audio.gd').new()
	feedback.game = self
	add_child(feedback)
	create_confetti()
	items = preload('res://scripts/race_items.gd').new()
	items.game = self
	add_child(items)
	duel = preload('res://scripts/duel.gd').new()
	duel.game = self
	add_child(duel)
	autoplay = '--autoplay' in args
	capture_run = '--capture' in args
	profile_run = '--profile' in args
	show_metrics = '--metrics' in args
	print('READY: ', 'solo practice' if practice else 'race', ', racers=',racers.size())
	if in_island:
		screen = 'island'
		rules.phase = 'island'
		player.reset_to_start(Island.SPAWN)
		player.active = true
		camera.position = player.position+Vector3(0,8.8,16)
		camera.look_at(player.position+Vector3(0,5.2,-5))
	elif '--practice' in args: call_deferred('start_race')

func configure_render_scale() -> void:
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if in_island else Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = .9 if in_island else 1.0

func configure_inputs() -> void:
	var bindings := {'left':[KEY_Q],'right':[KEY_E],'turn_left':[KEY_A,KEY_LEFT],'turn_right':[KEY_D,KEY_RIGHT],'forward':[KEY_W,KEY_UP],'back':[KEY_S,KEY_DOWN],'jump':[KEY_SPACE],'roll':[KEY_SHIFT]}
	for slot in range(1,6): bindings['skill_'+str(slot)] = [KEY_1+slot-1]
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)

func build_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color('#58add0')
	material.sky_horizon_color = Color('#b9e4fa')
	material.ground_bottom_color = Color('#739fbb')
	material.ground_horizon_color = Color('#b9e4fa')
	material.sky_curve = .22
	material.sun_angle_max = 12
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color('#c6e7ed')
	env.ambient_light_energy = .38
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = .72
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.22
	env.tonemap_white = 2.5
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.glow_enabled = true
	env.glow_intensity = .3
	env.fog_enabled = true
	env.fog_light_color = Color('#b9ddf4')
	env.fog_density = .0008
	env.fog_sky_affect = .10
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-28,0)
	sun.light_color = Color('#fff3d8')
	sun.light_energy = 1.4
	sun.light_angular_distance = 0.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 2.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,150,0)
	fill.light_color = Color('#b8dfe9')
	fill.light_energy = .16
	add_child(fill)

func add_racer(id: int) -> void:
	var racer := Racer.new()
	racer.game = self
	racer.racer_id = id
	racer.is_player = id == 0
	add_child(racer)
	racers.append(racer)

func join_race() -> void:
	practice = false
	start_race()

func reset_racers() -> void:
	var slots := range(racers.size())
	# Shuffle slot assignment, not racer identity or the item/gacha random streams.
	if not practice:
		for i in range(slots.size()-1,0,-1):
			var j := start_rng.randi_range(0,i)
			var old: int = slots[i]
			slots[i] = slots[j]
			slots[j] = old
	for i in range(racers.size()):
		var slot: int = slots[i]
		var p := Vector3((slot%8-3.5)*2.15,.08,2+floorf(slot/8.0)*2.3)
		if practice: p = Vector3(0,.08,11)
		racers[i].reset_to_start(p)

func start_race() -> void:
	if duel and (duel.in_arena() or screen == 'duel_lobby'):
		enter_island()
	close_modals()
	feedback.reset()
	release_mouse_drive()
	music.play_theme('race')
	if in_island:
		in_island = false
		configure_render_scale()
		replace_world(Course.new())
	for i in range(racers.size(), 1 if practice else RACE_SIZE):
		add_racer(i)
	paused = false
	screen = 'racing'
	rules.start(practice)
	player_place = 0
	finish_time = 0
	camera_yaw = 0
	camera_pitch = 0
	last_tick = 4
	toast_time = 0
	result_age = 0
	frame_times.clear()
	reset_racers()
	items.setup_race()
	if autoplay: player.external_control = true
	confetti.emitting = false

func replace_world(next_world: Node3D) -> void:
	remove_child(course)
	course.queue_free()
	course = next_world
	add_child(course)

func enter_island() -> void:
	if duel: duel.clear()
	close_modals()
	feedback.reset()
	items.clear()
	release_mouse_drive()
	music.play_theme('island')
	paused = false
	autoplay = false
	if not in_island:
		in_island = true
		configure_render_scale()
		replace_world(Island.new())
	for racer in racers:
		if racer != player:
			remove_child(racer)
			racer.queue_free()
	racers = [player]
	practice = true
	rules.start(true)
	rules.phase = 'island'
	screen = 'island'
	camera_yaw = 0
	camera_pitch = 0
	player.external_control = false
	player.reset_to_start(Island.SPAWN)
	player.active = true
	player_place = 0
	finish_time = 0
	toast_time = 0
	go_time = 0
	result_age = 0
	confetti.emitting = false
	frame_times.clear()
	camera.position = player.position+Vector3(0,8.8,16)
	camera.look_at(player.position+Vector3(0,5.2,-5))

func _physics_process(delta: float) -> void:
	if paused: return
	if duel and duel.in_arena():
		duel.tick(delta)
		return
	if in_island:
		player.active = true
		return
	var old_phase: String = rules.phase
	rules.advance(delta)
	if rules.phase == 'countdown':
		var tick := ceili(rules.countdown)
		if tick != last_tick:
			last_tick = tick
			sound('tick')
	if old_phase == 'countdown' and rules.phase == 'racing':
		go_time = 1.0
		sound('go')
		feedback.race_start()
	for racer in racers:
		racer.active = rules.phase == 'racing'
	if rules.phase == 'ended' and screen != 'result':
		player.respawn()
		screen = 'result'
		finish_time = rules.elapsed
	if autoplay and rules.phase == 'racing' and not player.finished:
		player.race_ai.tick(delta)

func _process(delta: float) -> void:
	frame_count += 1
	elapsed_real += delta
	last_frame_ms = delta*1000
	if (profile_run or capture_run) and screen == 'racing' and rules.phase == 'racing' and not paused:
		frame_times.append(last_frame_ms)
	if not paused:
		toast_time = maxf(0,toast_time-delta)
		go_time = maxf(0,go_time-delta)
		update_camera(delta)
	hud_refresh += delta
	if hud_refresh >= 1.0/30.0:
		hud.queue_redraw()
		hud_refresh = 0.0
	if capture_run and frame_count == 90: screenshot('01-menu')
	if autoplay and frame_count == 150: start_race()
	if capture_run and frame_count == 650: screenshot('02-race')
	if capture_run and frame_count == 1450: screenshot('03-course')
	if screen == 'result':
		result_age += delta
		if result_age > 1.5 and (capture_run or profile_run) and not profile_finished:
			if capture_run: screenshot('04-result')
			write_profile()
			profile_finished = true
		if autoplay and (capture_run or profile_run) and result_age > 4:
			get_tree().quit()
	if autoplay and (capture_run or profile_run) and elapsed_real > 170:
		write_profile()
		get_tree().quit()

func update_camera(delta: float) -> void:
	var p := player.get_global_transform_interpolated().origin
	var riding := is_instance_valid(player.vehicle)
	var desired: Vector3
	var focus: Vector3
	if screen in ['duel','duel_result']:
		desired = p+Vector3(0,8.4+camera_pitch*5,11).rotated(Vector3.UP,camera_yaw)
		focus = p+Vector3(0,1.0,0)
	elif screen == 'menu':
		desired = p + Vector3(6.2+sin(elapsed_real*.16)*.45,3.8,7.6)
		focus = p + Vector3(-1.9,1.0,-4.8)
	elif screen == 'result':
		desired = p+Vector3(5.3,3.4,7)
		focus = p+Vector3(0,1,0)
	else:
		var base_offset := Vector3(0,8.8+camera_pitch*5,16) if in_island else Vector3(0,7.4+camera_pitch*5,11.3)
		if riding: base_offset = Vector3(-10,8+camera_pitch*5,15)
		var offset := base_offset.rotated(Vector3.UP,camera_yaw)
		desired = p+offset
		var focus_offset := Vector3(0,5.2,-5) if in_island else Vector3(0,1.1,-3)
		if riding: focus_offset = Vector3(0,.8,0)
		focus = p+focus_offset.rotated(Vector3.UP,camera_yaw)
		var query := PhysicsRayQueryParameters3D.create(p+Vector3(0,.5 if in_island else 1.6,0),desired,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired = hit.position+hit.normal*.45
	var follow_rate := 24.0 if screen in ['racing','island','duel'] else 6.8
	if riding: follow_rate = 12.0
	camera.position = camera.position.lerp(desired,1-exp(-delta*follow_rate))
	if camera.position.distance_to(focus)>.1: camera.look_at(focus)
	var target_fov := (63.0 if in_island else 60.0) if player.roll_left>0 else (58.0 if in_island else 53.0)
	if riding: target_fov = 64.0
	camera.fov = lerpf(camera.fov,target_fov,1-exp(-delta*4))

func _input(event: InputEvent) -> void:
	if screen == 'duel_lobby':
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4: duel.select_class(event.physical_keycode-KEY_1)
			elif event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER]: duel.begin()
			elif event.physical_keycode == KEY_ESCAPE: enter_island()
			get_viewport().set_input_as_handled()
		return
	if coin_console and coin_console.visible:
		if event is InputEventKey and event.physical_keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			coin_console.close()
			get_viewport().set_input_as_handled()
		return
	if gacha and gacha.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				gacha.close()
				get_viewport().set_input_as_handled()
			elif event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER] and not gacha.result_panel and not gacha.info_panel:
				coin_console.open()
				get_viewport().set_input_as_handled()
		return
	if wardrobe and wardrobe.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			wardrobe.close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var both: bool = (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) == (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)
		mouse_forward = both and screen in ['island','racing','duel'] and not paused and player.active and not player.finished
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_forward else Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER,KEY_KP_ENTER:
				if screen == 'island' and not paused:
					coin_console.open()
					get_viewport().set_input_as_handled()
				elif screen == 'duel_result': duel.begin()
				elif screen in ['menu','result'] and not paused: start_race()
			KEY_ESCAPE:
				if screen in ['result','duel_result']: enter_island()
				elif screen in ['racing','island','duel']: toggle_pause()
			KEY_R:
				items.use_item(player)
			KEY_T:
				if screen in ['racing','island'] and not paused: player.respawn()
			KEY_B: wardrobe.open()
			KEY_G: gacha.open()
			KEY_J: duel.open_room()
			KEY_F3: show_metrics = not show_metrics
			KEY_F12: screenshot('manual-%d' % Time.get_ticks_msec())
	if event is InputEventMouseMotion and (mouse_forward or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and screen in ['racing','island','duel'] and not paused:
		# Screen-space delta stays consistent when viewport stretch or window size changes.
		var movement: Vector2 = event.screen_relative if event.screen_relative != Vector2.ZERO else event.relative
		camera_yaw -= movement.x*.005
		camera_pitch = clampf(camera_pitch+movement.y*.004,-.5,.6)

func toggle_pause() -> void:
	if screen in ['racing','island','duel']: paused = not paused
	if paused: release_mouse_drive()

func release_mouse_drive() -> void:
	mouse_forward = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release_mouse_drive()

func modal_open() -> bool:
	return (wardrobe and wardrobe.visible) or (gacha and gacha.visible) or (coin_console and coin_console.visible)

func ui_action(action: String) -> void:
	if modal_open(): return
	if action.begins_with('duel_class_'):
		duel.select_class(int(action.trim_prefix('duel_class_')))
		return
	match action:
		'duel_room': duel.open_room()
		'duel_begin': duel.begin()
		'join': join_race()
		'start','retry','restart': start_race()
		'wardrobe': wardrobe.open()
		'gacha': gacha.open()
		'coins': coin_console.open()
		'island': enter_island()
		'resume': paused = false

func sound(cue: String) -> void:
	if audio.has(cue): audio[cue].play()

func action_sound(cue: String, racer, strength := 1.0, reaction := false) -> void:
	if is_instance_valid(feedback): feedback.event(cue,racer,strength,reaction)

func checkpoint_reached(index: int) -> void:
	sound('checkpoint')
	toast = '检查点 %d 已点亮  ·  掉落后从这里继续' % index
	toast_time = 2.5

func cross_finish(racer: CharacterBody3D) -> void:
	var place: int = rules.finish(racer.racer_id)
	if place == 0: return
	racer.finished = true
	racer.clear_item()
	racer.collision_layer = 0
	racer.velocity *= .2
	print('FINISH id=',racer.racer_id,' place=',place,' time=',snappedf(rules.elapsed,.01))
	if racer.is_player:
		release_mouse_drive()
		player_place = place
		finish_time = rules.elapsed
		screen = 'result'
		sound('finish')
		feedback.finish()
		confetti.position = player.position+Vector3(0,3,-1)
		confetti.restart()
		confetti.emitting = true

func current_place() -> int:
	if player.finished: return player_place
	var place := 1
	for racer in racers:
		if racer != player and (racer.finished or racer.position.z<player.position.z): place+=1
	return place

func format_time(seconds: float) -> String:
	return '%02d:%05.2f' % [int(seconds)/60,fmod(seconds,60)]

func create_confetti() -> void:
	confetti = GPUParticles3D.new()
	confetti.emitting = false
	confetti.amount = 160
	confetti.lifetime = 3
	confetti.one_shot = true
	confetti.explosiveness = .95
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 100
	process.initial_velocity_min = 3
	process.initial_velocity_max = 8
	process.gravity = Vector3(0,-6,0)
	process.angular_velocity_min = -220
	process.angular_velocity_max = 220
	var gradient := Gradient.new()
	gradient.set_color(0,Color('#ff986f'))
	gradient.set_color(1,Color('#55ccc7'))
	gradient.add_point(.5,Color('#ffdc7c'))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	process.color_initial_ramp = texture
	confetti.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.16,.035,.28)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	confetti.draw_pass_1 = mesh
	add_child(confetti)

func screenshot(label: String) -> void:
	if DisplayServer.get_name() == 'headless': return
	await RenderingServer.frame_post_draw
	var captured := get_viewport().get_texture().get_image()
	if get_viewport().use_hdr_2d:
		captured.convert(Image.FORMAT_RGBA8)
		captured.linear_to_srgb()
	captured.save_png(output_path(label+'.png'))
	print('CAPTURE ',label)

func write_profile() -> void:
	if frame_times.is_empty(): return
	var sorted := frame_times.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted: total += value
	var data := {'frames':sorted.size(),'average_ms':total/sorted.size(),'p95_ms':sorted[int(sorted.size()*.95)],'p99_ms':sorted[int(sorted.size()*.99)],'max_ms':sorted[-1],'player_place':player_place,'race_time':finish_time,'finishers':rules.order.size(),'renderer':RenderingServer.get_current_rendering_method(),'viewport':str(get_viewport().get_visible_rect().size)}
	var file := FileAccess.open(output_path('performance.json'),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,'  '))
	print('PROFILE ',JSON.stringify(data))

func output_path(filename: String) -> String:
	var path := ProjectSettings.globalize_path('res://captures')
	if not DirAccess.dir_exists_absolute(path):
		path = OS.get_user_data_dir().path_join('captures')
		DirAccess.make_dir_recursive_absolute(path)
	return path.path_join(filename)

func close_modals() -> void:
	if coin_console: coin_console.close()
	if gacha: gacha.shutdown()
	if wardrobe: wardrobe.close()
