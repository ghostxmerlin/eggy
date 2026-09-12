extends SceneTree
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	game.frame_count=151
	game.autoplay=true
	game.start_race()
	if '--low-res' in OS.get_cmdline_user_args(): root.scaling_3d_scale = 0.65
	if '--original-quality' in OS.get_cmdline_user_args():
		root.msaa_3d = Viewport.MSAA_4X
		for child in game.get_children():
			if child is DirectionalLight3D and child.shadow_enabled:
				child.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				child.directional_shadow_max_distance = 110
	if '--capture-only' in OS.get_cmdline_user_args():
		game.autoplay = false
		game.player.external_control = false
		game.player.drive = Vector2.ZERO
		for i in range(90): await process_frame
		await game.screenshot('solo-responsive-start')
		game.player.position = Vector3(0,.08,-61)
		game.player.reset_physics_interpolation()
		for i in range(90): await process_frame
		await game.screenshot('solo-responsive-course')
		quit()
		return
	if '--no-hud' in OS.get_cmdline_user_args(): game.hud.hide()
	while game.rules.elapsed < 2: await process_frame
	var start := Time.get_ticks_usec()
	var physics:=0.0
	var proc:=0.0
	var draws := 0.0
	var samples := 0
	var frame_ms: Array[float] = []
	var tick := Time.get_ticks_usec()
	while game.rules.elapsed < 10:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now-tick)/1000.0)
		tick = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		samples += 1
		physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		proc+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
	frame_ms.sort()
	print('PERCENTILES p95=',frame_ms[int(samples*.95)],' p99=',frame_ms[int(samples*.99)])
	print('VIEWPORT ',root.size,' scale=',root.scaling_3d_scale)
	print('SHORT_PROFILE hud=',game.hud.visible,' avg_ms=',(Time.get_ticks_usec()-start)/(samples*1000.0),' process=',proc/samples,' physics=',physics/samples,' draws=',draws/samples)
	quit()
