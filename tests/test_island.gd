extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await process_frame
	check(game.screen == 'island', 'Default launch enters the island')
	if game.screen != 'island':
		game.queue_free()
		await process_frame
		quit(1)
		return
	check(game.racers.size() == 1, 'Island has one controllable player')
	for i in range(30): await physics_frame
	var origin: Vector3 = game.player.position
	Input.action_press('left')
	for i in range(30): await physics_frame
	Input.action_release('left')
	check(game.player.position.x < origin.x-2, 'Island supports normal movement')
	check(game.rules.elapsed == 0, 'Island does not run a race timer')
	game.player.position = Vector3(60,-10,0)
	for i in range(5): await physics_frame
	check(game.player.position.y > -1 and game.player.position.z > 0, 'Island fall respawns on island')
	var island_id: int = game.course.get_instance_id()
	game.ui_action('join')
	for i in range(5): await physics_frame
	check(game.screen == 'racing' and game.rules.phase == 'racing', 'Join enters existing solo race')
	check(game.course.get_instance_id() != island_id, 'Island world replaced by race world')
	game.player.position = Vector3(0,.1,game.course.FINISH_Z-1)
	for i in range(5): await physics_frame
	check(game.screen == 'result', 'Existing race can finish')
	game.ui_action('island')
	for i in range(5): await physics_frame
	check(game.screen == 'island' and not game.player.finished, 'Result returns to usable island')
	check(game.rules.order.is_empty() and game.rules.elapsed == 0, 'Return clears result and timer')
	check(game.racers.size() == 1, 'Returning does not duplicate racers')
	game.ui_action('join')
	for i in range(5): await physics_frame
	game.toggle_pause()
	game.ui_action('island')
	for i in range(5): await physics_frame
	check(game.screen == 'island' and not game.paused, 'Paused race can return to island')
	for i in range(20): await physics_frame
	check(game.player.is_on_floor(), 'Island spawn rests on solid ground')
	print('ISLAND FLOW TEST: ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
