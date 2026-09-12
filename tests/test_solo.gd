extends SceneTree
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	call_deferred('run')
func run() -> void:
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await process_frame
	check(game.racers.size() == 1, 'Default practice must contain only the player')
	game.start_race()
	check(game.rules.phase == 'racing', 'Practice starts immediately')
	game.rules.advance(180)
	check(game.rules.phase == 'racing', 'Practice must not time out')
	var player = game.player
	player.position = Vector3(0,.08,-6)
	for i in range(25): await physics_frame
	var start: Vector3 = player.position
	Input.action_press('forward')
	for i in range(30): await physics_frame
	Input.action_release('forward')
	check(player.position.z < start.z-2, 'W input moves forward')
	for i in range(20): await physics_frame
	check(Vector2(player.velocity.x,player.velocity.z).length() < .05, 'Releasing input stops movement')
	player.request_jump()
	for i in range(10): await physics_frame
	check(player.position.y > .5, 'Jump leaves the ground')
	for i in range(55): await physics_frame
	check(player.is_on_floor(), 'Jump lands back on track')
	player.request_roll()
	check(player.roll_left>0, 'Roll starts')
	var cooldown: float = player.roll_cooldown
	player.request_roll()
	check(is_equal_approx(player.roll_cooldown,cooldown), 'Rolling cannot bypass cooldown')
	game.camera_yaw = PI/2
	start = player.position
	Input.action_press('forward')
	for i in range(15): await physics_frame
	Input.action_release('forward')
	check(player.position.x < start.x-1, 'Movement follows rotated camera')
	game.toggle_pause()
	start = player.position
	var elapsed: float = game.rules.elapsed
	for i in range(12): await physics_frame
	check(player.position.is_equal_approx(start) and game.rules.elapsed == elapsed, 'Pause freezes character and timer')
	game.toggle_pause()
	player.position = Vector3(30,-10,-20)
	for i in range(5): await physics_frame
	check(player.position.y>0 and absf(player.position.x)<9, 'Falling restores checkpoint')
	game.start_race()
	check(game.racers.size()==1 and game.rules.phase=='racing' and game.rules.elapsed<.1, 'Restart resets solo practice')
	player.position = Vector3(0,.1,game.course.FINISH_Z-1)
	for i in range(5): await physics_frame
	check(game.screen=='result' and player.finished, 'Finish completes practice')
	print('SOLO INPUT TESTS: ', 'PASS' if failures.is_empty() else 'FAIL', ' failures=',failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
