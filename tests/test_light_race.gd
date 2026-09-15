extends 'res://tests/test_duel.gd'

# Reuse native key/click helpers; this scenario owns an isolated profile.
func run():
	visual = '--visual' in OS.get_cmdline_user_args()
	var path := 'user://test-light-race-isolated.cfg'
	DirAccess.remove_absolute(path+'.career')
	game = load('res://main.tscn').instantiate()
	game.skin_save_path = path
	root.add_child(game)
	await frames(30)
	await click_action('join')
	check(game.screen == 'racing' and game.class_profile.class_id == '', 'Race needs no profession creation')
	game.enter_island()
	game.class_room.open()
	game.class_room.choose(1)
	game.class_room.confirm()
	check(game.player.skills.career.enabled(), 'Mage works on island')
	await click_action('join')
	game.set_physics_process(false)
	game.rules.advance(3)
	game._physics_process(0)
	for actor in game.racers:
		actor.external_control = true
		check(not actor.skills.career.enabled(), 'Every competitor uses race movement')
	game.player.external_control = false
	game.player.reset_to_start(Vector3(0,.1,-65))
	game.player.active = true
	await frames(20)
	await press(KEY_SHIFT)
	check(game.player.roll_left > 0, 'Shift really rolls for a saved mage')
	await frames(100)
	await press(KEY_2)
	check(game.player.skills.dive_left > 0, 'Key 2 really dives for a saved mage')
	await frames(35)
	for slot in range(3,6):
		await press(KEY_1+slot-1)
		check(not game.player.skills.use_skill(slot), 'Combat slot disabled '+str(slot))
	check(game.player.skills.career.cast_count.is_empty(), 'No profession cast leaks into race')
	check(not game.items.enabled and game.items.pickups.is_empty(), 'Light race has no random items')
	game.player.external_control = true
	game.player.reset_to_start(Vector3(3,.1,-297))
	game.player.active = true
	game.rules.elapsed = 45
	game.cross_finish(game.racers[1])
	check(game.rules.time_left() == 30, 'First finisher starts 30 seconds')
	game.paused = true
	game._physics_process(10)
	check(game.rules.time_left() == 30, 'Pause freezes sprint countdown')
	game.paused = false
	if visual:
		await frames(8)
		await game.screenshot('light-race-30-seconds')
	game._physics_process(22)
	game.cross_finish(game.racers[2])
	check(game.rules.time_left() == 8 and game.rules.places_left() == 22, 'Later finish consumes a place without resetting clock')
	if visual:
		await frames(8)
		await game.screenshot('light-race-urgent')
	game._physics_process(8)
	check(game.screen == 'result' and game.player_place == 0 and game.rules.end_reason == 'finish_window', 'Timeout eliminates unfinished player')
	game.cross_finish(game.player)
	check(game.player_place == 0, 'Post-deadline finish cannot qualify')
	if visual:
		await frames(8)
		await game.screenshot('light-race-timeout')
	await click_action('retry')
	check(game.rules.first_finish == -1 and game.rules.time_left() == 150, 'Restart clears sprint clock')
	game.rules.advance(3)
	game.cross_finish(game.player)
	check(game.player_place == 1 and game.screen == 'result' and game.rules.time_left() == 30, 'Player can trigger sprint and qualify first')
	game._physics_process(30)
	check(game.player_place == 1 and game.player.finished, 'Qualified player stays qualified at deadline')
	game.start_race()
	game.rules.advance(3)
	for i in range(1,25): game.cross_finish(game.racers[i])
	game._physics_process(0)
	check(game.rules.end_reason == 'capacity' and game.player_place == 0, 'Full qualification list ends immediately')
	if visual:
		await frames(8)
		await game.screenshot('light-race-full')
	game.enter_island()
	check(game.class_profile.class_id == 'mage' and game.player.skills.career.enabled(), 'Island restores saved profession')
	game.duel.open_room()
	game.duel.begin()
	check(game.player.skills.career.enabled() and not game.light_race(), 'Duel still uses profession')
	game.enter_island()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path+'.career')
	print('LIGHT RACE: ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	quit(0 if failures.is_empty() else 1)
