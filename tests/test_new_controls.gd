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
	for entry in [[KEY_Q,'left'],[KEY_E,'right'],[KEY_A,'turn_left'],[KEY_D,'turn_right']]:
		var key := InputEventKey.new()
		key.physical_keycode = entry[0]
		check(InputMap.has_action(entry[1]) and InputMap.event_is_action(key,entry[1]), 'Physical key binding '+str(entry))
	if not InputMap.has_action('turn_left'):
		quit(1)
		return
	for i in range(30): await physics_frame
	var origin: Vector3 = game.player.position
	Input.action_press('turn_left')
	for i in range(30): await physics_frame
	Input.action_release('turn_left')
	check(game.camera_yaw > .8, 'A rotates heading to the left')
	check(game.player.position.distance_to(origin)<.15, 'Turning in place does not strafe')
	var yaw: float = game.camera_yaw
	Input.action_press('left')
	for i in range(30): await physics_frame
	Input.action_release('left')
	check(is_equal_approx(game.camera_yaw,yaw), 'Q strafes without rotating heading')
	check(game.player.position.distance_to(origin)>2, 'Q produces lateral movement')
	game.toggle_pause()
	Input.action_press('turn_right')
	for i in range(20): await physics_frame
	Input.action_release('turn_right')
	check(is_equal_approx(game.camera_yaw,yaw), 'Pause freezes keyboard rotation')
	print('NEW CONTROLS ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
