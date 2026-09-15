extends SceneTree
var failures: Array[String] = []
func _initialize(): call_deferred('run')
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func positions(game) -> Array:
	return game.racers.map(func(r): return r.position)
func run():
	var game = load('res://main.tscn').instantiate()
	game.skin_save_path = 'user://start-grid-isolated.cfg'
	game.start_seed = 2026
	game.item_seed = 2026
	root.add_child(game)
	game.set_process_input(false)
	game.player.external_control = true
	await physics_frame
	game.join_race()
	var identities: Array = game.racers.duplicate()
	var item_state: int = game.items.rng.state
	var valid_slots: Array[Vector3] = []
	for i in range(32): valid_slots.append(Vector3((i%8-3.5)*2.15,.08,2+floorf(i/8.0)*2.3))
	var rows := {}
	var player_slots := {}
	game.start_rng.seed = 7381
	game.reset_racers()
	var first := positions(game)
	game.start_rng.seed = 7381
	game.reset_racers()
	check(positions(game) == first,'A seed reproduces the entire grid')
	for trial in range(96):
		game.reset_racers()
		var occupied := {}
		for i in range(32):
			var racer = game.racers[i]
			check(racer == identities[i] and racer.racer_id == i,'Grid shuffle preserves racer identities')
			check(racer.position in valid_slots and not occupied.has(racer.position),'Every racer has a distinct valid grid slot')
			check(not racer.active and not racer.finished and racer.velocity == Vector3.ZERO,'Random grid preserves countdown reset state')
			occupied[racer.position] = true
		rows[roundi((game.player.position.z-2)/2.3)] = true
		player_slots[game.player.position] = true
	check(rows.size() == 4 and player_slots.size() > 20,'Player samples front, middle and rear rows across seeded restarts')
	check(game.items.rng.state == item_state,'Grid randomization does not consume item RNG')
	check(game.player == game.racers[0] and game.player.is_player,'Player remains racer zero')
	var before := positions(game)
	game.start_race()
	check(positions(game) != before and game.rules.phase == 'countdown','Rematch reshuffles before the countdown')
	if '--visual' in OS.get_cmdline_user_args():
		game.paused = true
		game.set_process(false)
		game.hud.hide()
		game.camera.position = Vector3(13,18,24)
		game.camera.look_at(Vector3(0,0,5))
		game.camera.fov = 48
		var captured := {}
		for sample in range(32):
			game.reset_racers()
			var row := roundi((game.player.position.z-2)/2.3)
			if captured.has(row): continue
			game.hud.queue_redraw()
			for frame in range(4): await physics_frame
			await game.screenshot('random-start-row-'+str(row+1))
			captured[row] = true
			if captured.size() == 4: break
	game.enter_island()
	check(game.racers.size() == 1 and game.player.position.is_equal_approx(game.Island.SPAWN),'Returning to the island keeps the island spawn')
	game.start_race()
	check(game.practice and game.player.position == Vector3(0,.08,11),'Solo practice keeps its centered start')
	print('START GRID: ','PASS' if failures.is_empty() else 'FAIL',failures,' player slots=',player_slots.size(),' rows=',rows.size())
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
