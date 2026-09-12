extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func frames(count: int):
	for i in range(count): await physics_frame
func key(code: int, pressed: bool):
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func mouse(button: int, pressed: bool, mask: int):
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.button_mask = mask
	Input.parse_input_event(event)
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await frames(30)
	for slot in range(1,6):
		game.player.reset_to_start(Vector3(0,.1,24))
		game.player.active = true
		key(KEY_1+slot-1,true)
		await frames(2)
		key(KEY_1+slot-1,false)
		check(game.player.skills.cooldown(slot) > 0, 'Number key '+str(slot)+' triggers its skill')
		await frames(2)
	game.player.reset_to_start(Vector3(0,.1,24))
	game.player.active = true
	await frames(20)
	mouse(MOUSE_BUTTON_RIGHT,true,MOUSE_BUTTON_MASK_RIGHT)
	await frames(3)
	check(not game.mouse_forward, 'Right mouse alone does not walk')
	mouse(MOUSE_BUTTON_LEFT,true,MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_RIGHT)
	var start: Vector3 = game.player.position
	await frames(30)
	check(game.mouse_forward and game.player.position.z < start.z-2, 'Both mouse buttons move forward')
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100,0)
	motion.screen_relative = Vector2(100,0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion)
	start = game.player.position
	await frames(20)
	print('MOUSE STEER yaw=',game.camera_yaw,' before=',start,' after=',game.player.position,' drive=',game.mouse_forward)
	check(game.camera_yaw < -.4 and game.player.position.x > start.x+.5, 'Mouse direction steers forward movement')
	mouse(MOUSE_BUTTON_LEFT,false,MOUSE_BUTTON_MASK_RIGHT)
	await frames(15)
	check(not game.mouse_forward and Vector2(game.player.velocity.x,game.player.velocity.z).length() < .1, 'Release either button brakes movement')
	mouse(MOUSE_BUTTON_LEFT,true,MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_RIGHT)
	await frames(2)
	game.toggle_pause()
	check(not game.mouse_forward and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, 'Pause releases captured mouse')
	var cd: float = game.player.skills.cooldown(5)
	key(KEY_5,true)
	await frames(3)
	key(KEY_5,false)
	check(game.player.skills.cooldown(5) == cd, 'Paused number keys cannot cast')
	game.toggle_pause()
	mouse(MOUSE_BUTTON_LEFT,false,MOUSE_BUTTON_MASK_RIGHT)
	mouse(MOUSE_BUTTON_RIGHT,false,0)
	print('SKILL INPUT TEST: ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
