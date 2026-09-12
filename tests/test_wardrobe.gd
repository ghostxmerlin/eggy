extends SceneTree

var failures: Array[String] = []
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func frames(count: int):
	for i in range(count): await physics_frame
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	if not game.get_script().get_script_property_list().any(func(p): return p.name == 'skin_save_path'):
		game.free()
		print('WARDROBE: FAIL no persisted player appearance')
		quit(1)
		return
	var path := 'user://test-wardrobe-isolated.cfg'
	DirAccess.remove_absolute(path)
	game.skin_save_path = path
	root.add_child(game)
	await frames(30)
	var player = game.player
	var wardrobe = game.wardrobe
	game.ui_action('wardrobe')
	check(wardrobe.visible and game.paused,'Opening wardrobe pauses world')
	wardrobe.select_skin('mint')
	check(player.skin_id == 'classic','Trying on does not change equipped skin')
	var origin: Vector3 = player.position
	Input.action_press('forward')
	Input.action_press('skill_2')
	await frames(10)
	Input.action_release('forward')
	Input.action_release('skill_2')
	check(player.position == origin and player.skills.cooldown(2) == 0,'Wardrobe blocks movement and combat')
	game.ui_action('join')
	check(game.screen == 'island','Wardrobe blocks underlying join button')
	wardrobe.close()
	check(not game.paused and player.skin_id == 'classic','Cancel returns unchanged')
	game.ui_action('wardrobe')
	wardrobe.select_skin('mint')
	wardrobe.confirm()
	check(not wardrobe.visible and not game.paused and player.skin_id == 'mint','Confirm equips and resumes play')
	check(load('res://scripts/skin_store.gd').new(path).load_skin() == 'mint','Confirmed skin survives new profile load')
	game.start_race()
	await frames(5)
	check(player.skin_id == 'mint','Race keeps selected skin')
	game.enter_island()
	await frames(20)
	check(player.skin_id == 'mint','Return to island keeps selected skin')
	var ride = game.course.get_node('Attractions/PlaneRide')
	ride.passenger = player
	player.board_vehicle(ride)
	wardrobe.open()
	check(not wardrobe.visible,'Cannot open wardrobe while aboard plane')
	player.respawn()
	await frames(20)
	game.ui_action('wardrobe')
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	check(not wardrobe.visible and not game.paused,'Escape closes wardrobe without opening pause menu')
	game.queue_free()
	await process_frame
	var next = load('res://main.tscn').instantiate()
	next.skin_save_path = path
	root.add_child(next)
	await frames(3)
	check(next.player.skin_id == 'mint','New game instance restores equipped skin')
	await frames(25)
	next.wardrobe.open()
	next.wardrobe.select_skin('peach')
	var focused = next.get_viewport().gui_get_focus_owner()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await frames(2)
	check(next.get_viewport().gui_get_focus_owner() != focused,'Tab reaches wardrobe buttons')
	for node in next.wardrobe.layout.get_children():
		if node is Button and node.text == '取消': node.grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await frames(2)
	enter.pressed = false
	Input.parse_input_event(enter)
	await frames(2)
	check(not next.wardrobe.visible and next.player.skin_id == 'mint','Enter activates focused Cancel without saving preview')
	next.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print('WARDROBE: ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	quit(0 if failures.is_empty() else 1)
