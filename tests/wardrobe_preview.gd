extends SceneTree
var failures: Array[String] = []
func key(code: int, pressed: bool):
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func click(position: Vector2):
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await frames(3)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(3)
func frames(count: int):
	for i in range(count): await physics_frame
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	game.skin_save_path = 'user://wardrobe-preview-isolated.cfg'
	DirAccess.remove_absolute(game.skin_save_path)
	root.add_child(game)
	await frames(100)
	key(KEY_B,true)
	await frames(2)
	key(KEY_B,false)
	if not game.wardrobe.visible: failures.append('B opens wardrobe')
	await frames(70)
	await game.screenshot('wardrobe-classic')
	game.wardrobe.select_skin('berry')
	game.wardrobe.preview.rotation.y = -.45
	await frames(40)
	await game.screenshot('wardrobe-berry')
	game.wardrobe.select_skin('royal')
	await frames(40)
	await game.screenshot('wardrobe-royal')
	await click(Vector2(1128,734))
	if game.wardrobe.visible: failures.append('Mouse clicks Cancel')
	key(KEY_B,true)
	await frames(2)
	key(KEY_B,false)
	await click(Vector2(849,386))
	if game.wardrobe.selected_id != 'mint': failures.append('Mouse selects mint skin')
	await click(Vector2(849,734))
	if game.player.skin_id != 'mint' or game.wardrobe.visible: failures.append('Mouse confirms and equips skin')
	key(KEY_B,true)
	await frames(2)
	key(KEY_B,false)
	await click(Vector2(849,266))
	await click(Vector2(849,734))
	await frames(30)
	game.set_process(false)
	game.camera.position = game.player.position+Vector3(2.9,1.8,4.9)
	game.player.pivot.rotation.y = 0
	game.player.active = false
	game.player.set_physics_process(false)
	game.camera.look_at(game.player.position+Vector3(0,1,0))
	game.camera.fov = 32
	await frames(20)
	await game.screenshot('character-island-closeup')
	DirAccess.remove_absolute(game.skin_save_path)
	print('WARDROBE PREVIEW: ', 'PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
