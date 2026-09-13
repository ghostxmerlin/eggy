extends SceneTree
var failures: Array[String] = []
var visual := false
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func frames(count: int):
	for i in range(count): await physics_frame
func key(code: int, pressed: bool):
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func press(code: int):
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)
func type_credit():
	for code in [43,53,48,48]:
		var event := InputEventKey.new()
		event.unicode = code
		event.keycode = code
		event.pressed = true
		Input.parse_input_event(event)
		await frames(1)
		event.pressed = false
		Input.parse_input_event(event)
func click(position: Vector2):
	if DisplayServer.get_name() == 'headless':
		# Dummy rendering has no GUI hover/hit testing; native run below verifies clicks.
		var game = root.get_child(root.get_child_count()-1)
		if position.y > 700: game.gacha.pull(10)
		else: game.gacha.show_info()
		return
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
func _initialize(): call_deferred('run')
func run():
	visual = '--visual' in OS.get_cmdline_user_args()
	var game = load('res://main.tscn').instantiate()
	game.skin_save_path = 'user://test-gacha-ui-isolated.cfg'
	DirAccess.remove_absolute(game.skin_save_path)
	root.add_child(game)
	await frames(60)
	await press(KEY_ENTER)
	check(game.coin_console.visible and game.paused and game.screen == 'island','Enter opens coin console without joining race')
	await press(KEY_TAB)
	check(game.get_viewport().gui_get_focus_owner() == game.coin_console.field,'Coin input retains focus on Tab')
	await type_credit()
	check(game.coin_console.field.text == '+500','Actual text events reach input field')
	if visual: await game.screenshot('gacha-coin-input')
	await press(KEY_ENTER)
	check(game.skin_store.coins == 500 and not game.coin_console.visible and not game.paused,'Enter submits credit once and resumes island')
	await press(KEY_G)
	check(game.gacha.visible and game.paused,'G opens workshop')
	var start: Vector3 = game.player.position
	await press(KEY_2)
	game.ui_action('join')
	check(game.player.position == start and game.screen == 'island' and game.player.skills.cooldown(2) == 0,'Workshop blocks movement, skills and underlying HUD actions')
	await press(KEY_ENTER)
	await type_credit()
	await press(KEY_ENTER)
	check(game.skin_store.coins == 1000 and game.gacha.visible and game.paused,'Credit overlay restores workshop pause and exact balance')
	if visual:
		await game.screenshot('gacha-workshop')
		for id in ['scarf','goggles','aviator','mecha_gale']:
			game.gacha.switch_pool('season' if id == 'mecha_gale' else 'basic')
			game.gacha.select_skin(id)
			await frames(5)
			await game.screenshot('outfit-'+id)
		game.gacha.switch_pool('season')
	game.skin_store.pity = 49
	game.skin_store.rng.seed = 42
	await click(Vector2(1120,729))
	await frames(90)
	check(game.gacha.latest.size() == 10 and game.skin_store.total_draws == 10,'Mouse ten pull awards exactly ten')
	check(is_instance_valid(game.gacha.result_panel),'Results appear after purchase')
	check(game.gacha.ten_button.disabled,'Reward overlay disables purchases underneath')
	game.gacha.pull(10)
	check(game.skin_store.total_draws == 10,'Reward overlay rejects accidental repeated purchase')
	if visual: await game.screenshot('gacha-ten-results')
	await press(KEY_ESCAPE)
	check(game.gacha.visible and not is_instance_valid(game.gacha.result_panel) and game.paused,'Escape dismisses results without closing workshop')
	await click(Vector2(1170,201))
	check(is_instance_valid(game.gacha.info_panel),'Probability button opens rules')
	if visual: await game.screenshot('gacha-probabilities')
	await press(KEY_ESCAPE)
	await press(KEY_ESCAPE)
	check(not game.gacha.visible and not game.paused,'Second Escape returns to island')
	game.wardrobe.open()
	game.wardrobe.show_category('season')
	game.wardrobe.select_skin('mecha')
	if 'mecha' not in game.skin_store.owned:
		check(game.wardrobe.wear_button.disabled,'Unowned mecha is preview-only')
		game.wardrobe.confirm()
		check(game.player.skin_id == 'classic','Locked skin cannot bypass equip via direct action')
	game.wardrobe.close()
	game.skin_store.credit('+50000')
	for i in range(15):
		if 'mecha' in game.skin_store.owned: break
		game.skin_store.draw('season',10)
	check('mecha' in game.skin_store.owned,'Season protection unlocks featured mecha')
	game.wardrobe.open()
	game.wardrobe.show_category('season')
	game.wardrobe.select_skin('mecha')
	game.wardrobe.preview.rotation.y = -.28
	await frames(10)
	if visual: await game.screenshot('wardrobe-mecha')
	game.wardrobe.confirm()
	check(game.player.skin_id == 'mecha' and not game.paused,'Unlocked mecha equips')
	var restore = load('res://scripts/skin_store.gd').new(game.skin_save_path)
	check(restore.load_skin() == 'mecha' and restore.coins == game.skin_store.coins,'Restart restores outfit and wallet')
	game.join_race()
	check(game.player.skin_id == 'mecha' and game.racers.size() == 32,'Equipped mecha survives race transition')
	game.enter_island()
	await frames(30)
	if visual:
		game.set_process(false)
		game.camera.position = game.player.position+Vector3(2.9,1.8,4.9)
		game.player.pivot.rotation.y = 0
		game.player.active = false
		game.player.set_physics_process(false)
		game.camera.look_at(game.player.position+Vector3(0,1,0))
		game.camera.fov = 32
		await frames(20)
		await game.screenshot('mecha-island')
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute('user://test-gacha-ui-isolated.cfg')
	print('GACHA UI: ', 'PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
