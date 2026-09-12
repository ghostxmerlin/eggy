extends SceneTree
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	for i in range(150): await process_frame
	await game.screenshot('expanded-island-spawn')
	game.set_process(false)
	game.hud.hide()
	game.camera.position = Vector3(66,55,78)
	game.camera.look_at(Vector3(0,5,-4))
	for i in range(40): await process_frame
	await game.screenshot('expanded-island-overview')
	game.camera.position = Vector3(-8,15,10)
	game.camera.look_at(Vector3(-27,10,-17))
	for i in range(40): await process_frame
	await game.screenshot('expanded-ferris-wheel')
	game.camera.position = Vector3(46,20,30)
	game.camera.look_at(Vector3(27,7,13))
	for i in range(40): await process_frame
	await game.screenshot('expanded-lift')
	game.start_race()
	game.player.position = Vector3(0,.1,-218)
	game.player.reset_physics_interpolation()
	game.camera.position = Vector3(15,18,-200)
	game.camera.look_at(Vector3(0,-1,-250))
	for i in range(40): await process_frame
	await game.screenshot('expanded-course-gaps')
	quit()
