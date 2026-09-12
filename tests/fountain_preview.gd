extends SceneTree

func _initialize(): call_deferred('run')

func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	for i in range(120): await process_frame
	await game.screenshot('fountain-spawn')
	game.set_process(false)
	game.hud.hide()
	game.camera.position = Vector3(9, 7.8, 15)
	game.camera.look_at(Vector3(0, 2.2, 3))
	for i in range(60): await process_frame
	await game.screenshot('fountain-close')
	for i in range(45): await process_frame
	await game.screenshot('fountain-flow')
	game.camera.position = Vector3(-7, 4.6, 11)
	game.camera.look_at(Vector3(0, 2.5, 3))
	for i in range(40): await process_frame
	await game.screenshot('fountain-side')
	var water = game.course.find_child('FountainWater', true, false)
	game.toggle_pause()
	var frozen: float = water.stream_material.get_shader_parameter('flow_time')
	for i in range(12): await physics_frame
	if water.stream_material.get_shader_parameter('flow_time') != frozen:
		push_error('Fountain must freeze while paused')
		quit(1)
		return
	game.toggle_pause()
	for i in range(12): await physics_frame
	if water.stream_material.get_shader_parameter('flow_time') <= frozen:
		push_error('Fountain must resume after pause')
		quit(1)
		return
	print('PASS: fountain animation pauses and resumes')
	print('PASS: fountain render views captured')
	quit()
