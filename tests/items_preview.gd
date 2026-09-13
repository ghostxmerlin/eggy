extends 'res://tests/test_items.gd'

func snapshot(label: String, eye: Vector3, focus: Vector3) -> void:
	game.paused = false
	game.camera.position = eye
	game.camera.look_at(focus)
	game.hud.queue_redraw()
	DisplayServer.window_move_to_foreground()
	for i in range(4): await process_frame
	await game.screenshot(label)

func run() -> void:
	game = load('res://main.tscn').instantiate()
	game.item_seed = 2026
	root.add_child(game)
	await process_frame
	game.ui_action('join')
	game.set_physics_process(false)
	game.set_process(false)
	items = game.items
	items.set_physics_process(false)
	player = game.player
	target = game.racers[1]
	for racer in game.racers.slice(2):
		game.remove_child(racer)
		racer.queue_free()
	game.racers = [player,target]
	await process_frame

	reset()
	items.bag.clear()
	items.bag.append('ball')
	items.add_pickup(player.position+Vector3.UP*.9)
	await frames(2)
	check(player.item_state.held == 'ball','Native collision pickup puts a ball in the R slot')
	await snapshot('items-picked-ball',Vector3(6,5,-55),Vector3(0,1,-65))
	player.position = Vector3(4,.1,-67)
	target.position = Vector3(8.8,.1,-67)
	game.camera_yaw = -PI/2
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await frames(24)
	check(target.position.x > 10 and player.item_state.held == '','Native R throw knocks the target beyond the track')
	await snapshot('items-ball-knockout',Vector3(18,7,-58),Vector3(8,1,-67))

	reset()
	equip('portal')
	items.use_item(player,Vector3.FORWARD)
	await frames(65)
	check(items.portal_trips > 0,'Native portal transports the racer')
	await snapshot('items-portals',Vector3(17,14,-57),Vector3(0,1,-74))

	reset()
	target.position = Vector3(0,.1,-50)
	equip('ink',target)
	items.use_item(target,Vector3.FORWARD)
	await frames(62)
	check(player.item_state.ink > 0,'Native ink projectile applies player vision obstruction')
	await snapshot('items-ink-hit',Vector3(5,4,-57),Vector3(0,1,-65))

	reset()
	equip('spring')
	items.use_item(player,Vector3.FORWARD)
	target.position = Vector3(0,.2,-67.2)
	await frames(12)
	check(target.position.y > 1,'Native springboard launches target')
	await snapshot('items-springboard',Vector3(8,6,-57),Vector3(0,2,-68))

	reset()
	equip('jetpack')
	items.use_item(player)
	await frames(22)
	check(is_instance_valid(player.jet_display),'Jetpack remains visible while the boost is active')
	await snapshot('items-jetpack',Vector3(-4,5,-72),Vector3(0,2,-65))
	print('ITEM VISUALS: ', 'PASS' if failures.is_empty() else 'FAIL', ' ',failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
