extends SceneTree
func _initialize() -> void:
	call_deferred('run')
func run() -> void:
	var game = load('res://main.tscn').instantiate()
	game.item_seed = 2026
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
	var ok: bool = game.rules.order.size() == 24 and game.player_place>0 and game.rules.elapsed < game.rules.TIME_LIMIT
	var ai_collectors: int = game.items.collected.keys().filter(func(id): return id != 0).size()
	var ai_users: int = game.items.used.keys().filter(func(id): return id != 0).size()
	ok = ok and ai_collectors >= 20 and ai_users >= 20 and game.items.used.get(0,0) > 0
	print('RACE ITEMS: AI collectors=',ai_collectors,' AI users=',ai_users,' player uses=',game.items.used.get(0,0),' hits=',game.items.hits,' portals=',game.items.portal_trips,' springs=',game.items.spring_launches)
	print('FULL RACE: ', 'PASS' if ok else 'FAIL', ' finishers=',game.rules.order.size(),' player=',game.player_place,' time=',game.rules.elapsed)
	if visual: await capture(game,'race-32-result')
	if not ok:
		for racer in game.racers:
			print('RACER ',racer.racer_id,' ',racer.position,' checkpoint=',racer.checkpoint)
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)

func capture(game, label: String) -> void:
	DisplayServer.window_move_to_foreground()
	game.hud.queue_redraw()
	for i in range(4): await process_frame
	await game.screenshot(label)
