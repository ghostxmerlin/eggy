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
	var player = game.player
	var skin: String = player.skin_id
	game.ui_action('join')
	for i in range(5): await physics_frame
	check(game.screen == 'racing' and game.rules.phase == 'countdown', 'Join starts the competition countdown')
	check(not game.practice and not game.rules.practice, 'Join enables timed qualification rules')
	check_roster(game)
	check(game.player == player and player.skin_id == skin, 'Join keeps the player and equipped skin')
	check(game.course.get_instance_id() != island_id, 'Island world replaced by race world')
	check(game.racers.all(func(r): return not r.active), 'Countdown holds every racer at the start')
	for i in range(185): await physics_frame
	check(game.rules.phase == 'racing' and game.racers.all(func(r): return r.active), 'Countdown releases all 32 racers')
	game.toggle_pause()
	var elapsed: float = game.rules.elapsed
	var bot_position: Vector3 = game.racers[1].position
	for i in range(12): await physics_frame
	check(game.rules.elapsed == elapsed and game.racers[1].position == bot_position, 'Pause freezes the race timer and AI')
	game.toggle_pause()
	game.player.position = Vector3(0,.1,game.course.FINISH_Z-1)
	for i in range(5): await physics_frame
	check(game.screen == 'result', 'Existing race can finish')
	check(game.player_place == 1, 'Player finish records a qualification place')
	game.ui_action('retry')
	check_roster(game)
	check(game.rules.order.is_empty() and game.rules.phase == 'countdown' and not player.finished, 'Retry resets the 32-player round')
	var old_bot = weakref(game.racers[1])
	game.ui_action('island')
	for i in range(5): await physics_frame
	check(game.screen == 'island' and not game.player.finished, 'Result returns to usable island')
	check(game.rules.order.is_empty() and game.rules.elapsed == 0, 'Return clears result and timer')
	check(game.racers.size() == 1, 'Returning does not duplicate racers')
	check(old_bot.get_ref() == null, 'Returning removes previous AI racers from the scene')
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	for i in range(5): await physics_frame
	check_roster(game)
	check(game.rules.phase == 'countdown' and not game.practice, 'Island Enter starts another 32-player race')
	game.toggle_pause()
	game.ui_action('island')
	for i in range(5): await physics_frame
	check(game.screen == 'island' and not game.paused, 'Paused race can return to island')
	for i in range(20): await physics_frame
	check(game.player.is_on_floor(), 'Island spawn rests on solid ground')
	game.toggle_pause()
	game.ui_action('join')
	check_roster(game)
	check(not game.paused and game.rules.phase == 'countdown', 'Paused island join resumes into a fresh competition')
	print('ISLAND FLOW TEST: ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func check_roster(game) -> void:
	check(game.racers.size() == 32, 'Competition contains exactly 32 racers')
	check(game.racers.filter(func(r): return r.is_player).size() == 1, 'Exactly one racer is player-controlled')
	check(game.racers.filter(func(r): return not r.is_player and not r.external_control).size() == 31, 'Exactly 31 racers use AI control')
	var ids: Array[int] = []
	for racer in game.racers:
		check(not racer.racer_id in ids, 'Racer IDs remain unique after joining or restarting')
		ids.append(racer.racer_id)
