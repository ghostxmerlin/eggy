extends SceneTree
func _initialize() -> void:
	call_deferred('run')
func run() -> void:
	var game = load('res://main.tscn').instantiate()
	game.practice = false
	root.add_child(game)
	await process_frame
	game.autoplay = true
	game.frame_count = 151
	game.start_race()
	for frame in range(9400):
		await physics_frame
		if game.rules.phase == 'ended': break
	var ok: bool = game.rules.order.size() == 24 and game.player_place>0
	print('FULL RACE: ', 'PASS' if ok else 'FAIL', ' finishers=',game.rules.order.size(),' player=',game.player_place,' time=',game.rules.elapsed)
	if not ok:
		for racer in game.racers:
			print('RACER ',racer.racer_id,' ',racer.position,' checkpoint=',racer.checkpoint)
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
