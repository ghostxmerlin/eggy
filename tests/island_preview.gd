extends SceneTree
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	if '--full-res' in OS.get_cmdline_user_args(): root.scaling_3d_scale = 1.0
	if '--scale-90' in OS.get_cmdline_user_args(): root.scaling_3d_scale = .9
	if '--low-res' in OS.get_cmdline_user_args(): root.scaling_3d_scale = .7
	for i in range(150): await process_frame
	if '--static-rides' in OS.get_cmdline_user_args(): game.course.get_node('Attractions').set_physics_process(false)
	if '--capture-only' in OS.get_cmdline_user_args():
		await game.screenshot('island-front')
		game.player.position = Vector3(14,.12,7)
		game.player.reset_physics_interpolation()
		game.camera_yaw = .65
		for i in range(90): await process_frame
		await game.screenshot('island-side')
		game.ui_action('join')
		for i in range(90): await process_frame
		await game.screenshot('island-to-race')
	else:
		var frames: Array[float] = []
		var physics := 0.0
		var draws := 0.0
		var now := Time.get_ticks_usec()
		var end := now+8000000
		while now < end:
			var before := now
			await process_frame
			now = Time.get_ticks_usec()
			frames.append((now-before)/1000.0)
			physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		frames.sort()
		var total := 0.0
		for value in frames: total += value
		print('ISLAND PERFORMANCE frames=',frames.size(),' avg_ms=',total/frames.size(),' p95=',frames[int(frames.size()*.95)],' p99=',frames[int(frames.size()*.99)],' physics=',physics/frames.size(),' draws=',draws/frames.size())
	quit()
