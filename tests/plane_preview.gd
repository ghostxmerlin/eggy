extends SceneTree
var game: Node
func frames(count: int):
	for i in range(count):
		await physics_frame
		game.hud.queue_redraw()
func _initialize(): call_deferred('run')
func run():
	game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await frames(100)
	var ride = game.course.get_node('Attractions/PlaneRide')
	game.set_process(false)
	game.camera.position = Vector3(24,20,24)
	game.camera.look_at(Vector3(36,12.8,13))
	await frames(10)
	await game.screenshot('plane-docked-closed')
	game.player.position = Vector3(29.2,10.75,13)
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	await frames(110)
	await game.screenshot('plane-canopy-open')
	Input.action_press('right')
	for i in range(180):
		await frames(1)
		if is_instance_valid(game.player.vehicle): break
	Input.action_release('right')
	if not is_instance_valid(game.player.vehicle):
		push_error('Native boarding failed: '+str(game.player.position))
		quit(1)
		return
	await frames(85)
	await game.screenshot('plane-passenger-canopy-closed')
	if '--canopy-only' in OS.get_cmdline_user_args():
		print('CANOPY PREVIEW: PASS')
		quit()
		return
	game.set_process(true)
	await frames(420)
	await game.screenshot('plane-island-flight')
	# Run the rest of the flight with the regular player camera and native physics.
	for i in range(1900):
		await frames(1)
		if ride.state == 'disembark': break
	game.set_process(false)
	game.camera.position = Vector3(24,20,24)
	game.camera.look_at(Vector3(36,12.8,13))
	await frames(15)
	await game.screenshot('plane-return-open')
	print('PLANE PREVIEW: ',ride.state)
	quit(0 if ride.state == 'disembark' else 1)
