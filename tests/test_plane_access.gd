extends SceneTree
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	await physics_frame
	var lift = game.course.get_node('Attractions/Lift')
	game.player.position = lift.global_position+Vector3(0,.35,0)
	game.player.velocity = Vector3.ZERO
	for i in range(1000):
		await physics_frame
		if lift.position.y > 10.25: break
	Input.action_press('right')
	for i in range(250):
		await physics_frame
		if is_instance_valid(game.player.vehicle): break
	Input.action_release('right')
	var boarded := is_instance_valid(game.player.vehicle)
	print('PLANE ACCESS: ', 'PASS' if boarded else 'FAIL', ' player=',game.player.position)
	game.queue_free()
	await process_frame
	quit(0 if boarded else 1)
