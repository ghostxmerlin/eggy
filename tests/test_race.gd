extends SceneTree
func _initialize() -> void:
	call_deferred('run')
func run() -> void:
	var game = load('res://main.tscn').instantiate()
	game.skin_save_path = 'user://test-career-race-isolated.cfg'
	DirAccess.remove_absolute(game.skin_save_path+'.career')
	game.item_seed = 2026
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with('--seed='): game.item_seed = int(argument.trim_prefix('--seed='))
	game.start_seed = game.item_seed
	root.add_child(game)
	await process_frame
	var visual := '--visual' in OS.get_cmdline_user_args()
	if visual: await capture(game,'race-32-island-entry')
	game.ui_action('join')
	if game.racers.size() != 32 or game.practice:
		print('FULL RACE: FAIL island entry did not create 32-player competition')
		game.queue_free()
		await process_frame
		quit(1)
		return
	game.autoplay = true
	game.frame_count = 151
	game.player.external_control = true
	if visual: await capture(game,'race-32-countdown')
	for frame in range(9400):
		await physics_frame
		if visual and frame == 360: await capture(game,'race-32-running')
		if game.rules.phase == 'ended': break
	var ok: bool = game.rules.order.size() > 0 and game.rules.order.size() <= 24 and game.rules.phase == 'ended' and game.rules.elapsed < game.rules.TIME_LIMIT
	# Competitive opponents may eliminate the autoplay player; qualification is earned.
	ok = ok and game.player.finished == (game.player_place > 0)
	ok = ok and not game.items.enabled and game.items.pickups.is_empty()
	ok = ok and game.rules.first_finish >= 0 and game.rules.elapsed <= game.rules.deadline()
	ok = ok and (game.rules.order.size() == 24 or game.rules.end_reason == 'finish_window')
	for actor in game.racers: ok = ok and not actor.skills.career.enabled()
	print('FULL RACE: ', 'PASS' if ok else 'FAIL', ' finishers=',game.rules.order.size(),' player=',game.player_place,' time=',game.rules.elapsed,' seed=',game.item_seed)
	if visual: await capture(game,'race-32-result')
	if not ok:
		for racer in game.racers:
			print('RACER ',racer.racer_id,' ',racer.position,' checkpoint=',racer.checkpoint)
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute('user://test-career-race-isolated.cfg.career')
	quit(0 if ok else 1)

func capture(game, label: String) -> void:
	DisplayServer.window_move_to_foreground()
	game.hud.queue_redraw()
	for i in range(4): await process_frame
	await game.screenshot(label)
