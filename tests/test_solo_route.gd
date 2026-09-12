extends SceneTree
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	game.autoplay = true
	game.frame_count = 151
	game.start_race()
	var furthest := 11.0
	for i in range(10800):
		await physics_frame
		furthest = minf(furthest,game.player.position.z)
		if game.player.finished: break
	var ok: bool = game.player.finished
	print('SOLO ROUTE ', 'PASS' if ok else 'FAIL', ' time=',game.rules.elapsed,' furthest=',furthest,' checkpoint=',game.player.checkpoint,' position=',game.player.position)
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
