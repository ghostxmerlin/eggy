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
	await process_frame
	var lift = game.course.get_node_or_null('Attractions/Lift')
	check(lift != null, 'Island includes a working lift')
	if lift == null:
		quit(1)
		return
	game.player.position = lift.global_position+Vector3(0,.32,0)
	game.player.velocity = Vector3.ZERO
	for i in range(30): await physics_frame
	var initial_y: float = game.player.position.y
	for i in range(150): await physics_frame
	check(game.player.position.y > initial_y+3, 'Lift carries a standing player upward')
	check(absf(game.player.position.y-lift.global_position.y-.25)<.3,'Player remains on lift floor')
	game.toggle_pause()
	var lift_y: float = lift.position.y
	for i in range(30): await physics_frame
	check(is_equal_approx(lift.position.y,lift_y), 'Pause stops lift motion')
	game.toggle_pause()
	var cabin = game.course.get_node('Attractions/Cabin0')
	game.player.position = cabin.global_position+Vector3(0,.25,0)
	game.player.velocity = Vector3.ZERO
	for i in range(30): await physics_frame
	var cabin_start: Vector3 = game.player.position
	for i in range(120): await physics_frame
	check(game.player.position.distance_to(cabin_start)>1, 'Ferris cabin carries its passenger')
	check(absf(game.player.position.y-cabin.global_position.y-.14)<.3, 'Passenger stays on cabin floor')
	print('LIFT ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
