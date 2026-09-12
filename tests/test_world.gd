extends SceneTree
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failed = true

func _initialize() -> void:
	call_deferred('run')

func run() -> void:
	var scene = load('res://main.tscn')
	check(scene != null, 'Main scene must load')
	var game = scene.instantiate()
	game.practice = false
	root.add_child(game)
	await process_frame
	check(game.racers.size() == 32, '32 racers must exist in real scene')
	game.start_race()
	game.rules.advance(3.0)
	var player = game.player
	player.position = Vector3(0,.08,-10)
	for i in range(45): await physics_frame
	check(player.is_on_floor(), 'Player must stand on starting platform')
	player.drive = Vector2(0,-1)
	player.external_control = true
	var origin: Vector3 = player.position
	for i in range(60): await physics_frame
	check(player.position.z < origin.z - 5.0, 'Forward input must move along track')
	player.request_jump()
	for i in range(10): await physics_frame
	check(player.position.y > 0.5, 'Jump must lift player off track')
	player.request_roll()
	check(player.roll_left > 0, 'Roll should start')
	player.request_roll()
	check(player.roll_cooldown > 0, 'Roll cooldown must remain active')
	player.position = Vector3(30,-10,-20)
	for i in range(4): await physics_frame
	check(player.position.y > -2 and absf(player.position.x) < 10, 'Fall must restore safe checkpoint')
	game.toggle_pause()
	check(game.paused, 'Pause activated')
	game.toggle_pause()
	check(not game.paused, 'Pause released')
	player.drive = Vector2.ZERO
	player.position = Vector3(10,0.1,game.course.FINISH_Z-.5)
	for i in range(4): await physics_frame
	check(game.player_place > 0, 'Outer finish lane must qualify')
	game.start_race()
	game.rules.advance(3.0)
	player.position = Vector3(28,-3,-20)
	player.velocity = Vector3(0,-12,0)
	game.rules.elapsed = 149.99
	for i in range(4): await physics_frame
	check(game.rules.phase == 'ended', 'Time limit ends native race')
	for i in range(90): await physics_frame
	check(player.position.y > -2, 'Eliminated player must not fall forever behind results')
	game.start_race()
	check(game.rules.order.is_empty() and game.rules.phase == 'countdown', 'Retry resets round')
	print('WORLD TESTS: ', 'FAIL' if failed else 'PASS')
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
