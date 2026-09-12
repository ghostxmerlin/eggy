extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String):
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	game.start_race()
	for i in range(5): await physics_frame
	check(absf(11-game.course.FINISH_Z)>=318, 'Race distance is doubled')
	var space = game.get_world_3d().direct_space_state
	for z in [-152.3,-170.3,-183.3,-196.3,-225.5,-236.5,-247.5,-258.5,-275.4,-287.4]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(0,5,z),Vector3(0,-5,z),1)
		check(space.intersect_ray(query).is_empty(), 'Real falling gap at '+str(z))
	for checkpoint in game.course.CHECKPOINTS:
		var query := PhysicsRayQueryParameters3D.create(checkpoint+Vector3.UP*3,checkpoint-Vector3.UP*3,1)
		check(not space.intersect_ray(query).is_empty(), 'Checkpoint has solid floor '+str(checkpoint))
	game.player.position = Vector3(0,.1,-149)
	for i in range(5): await physics_frame
	check(game.screen=='racing', 'Original finish now leads into new track')
	game.player.position = Vector3(0,.1,game.course.FINISH_Z-1)
	for i in range(5): await physics_frame
	check(game.screen=='result', 'New finish ends the race')
	print('LONG COURSE ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
