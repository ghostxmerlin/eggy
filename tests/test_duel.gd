extends SceneTree
var failures: Array[String] = []
var game: Node
var visual := false
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func frames(count: int):
	for i in range(count): await physics_frame
func press(code: int):
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)
func click_action(action: String):
	await frames(3)
	if DisplayServer.get_name() == 'headless':
		game.ui_action(action)
		return
	var rect: Rect2 = game.hud.buttons.get(action,Rect2())
	check(rect.size != Vector2.ZERO,'Visible button: '+action)
	var position: Vector2 = rect.get_center()*game.hud.size/Vector2(1440,900)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await frames(3)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		await frames(3)
func _initialize(): call_deferred('run')
func run():
	visual = '--visual' in OS.get_cmdline_user_args()
	var path := 'user://test-duel-isolated.cfg'
	DirAccess.remove_absolute(path+'.career')
	game = load('res://main.tscn').instantiate()
	game.skin_save_path = path
	root.add_child(game)
	await frames(40)
	await click_action('duel_room')
	check(game.screen == 'career' and game.paused,'Duel entry requires first career selection')
	for i in range(4):
		await click_action('class_pick_'+str(i))
		check(game.class_room.selected == i,'Class card selected '+str(i))
	if visual: await game.screenshot('classes-ui-selection')
	await click_action('class_confirm')
	check(game.class_profile.class_id == 'hunter' and game.screen == 'duel_lobby','Class saved and duel lobby opened')
	await press(KEY_1)
	check(game.duel.selected_class == 3,'Room cannot change fixed profession')
	await click_action('duel_begin')
	var d = game.duel
	var p = game.player
	check(game.screen == 'duel' and game.racers.size() == 2 and get_nodes_in_group('combatants').size() == 2,'Exactly two combatants')
	check(d.health == {0:100,1:100} and not game.items.enabled,'Fresh duel health and no race items')
	check(not p.skills.use_skill(1),'Countdown blocks career attack')
	await press(KEY_ESCAPE)
	var remaining: float = d.countdown
	await frames(15)
	check(game.paused and d.countdown == remaining,'Countdown pause')
	await click_action('resume')
	if visual: await game.screenshot('classes-ui-countdown')
	await frames(190)
	d.ai_enabled = false
	d.opponent.drive = Vector2.ZERO
	p.reset_to_start(Vector3(0,.12,2))
	d.opponent.reset_to_start(Vector3(0,.12,0))
	p.active = true
	d.opponent.active = true
	await frames(20)
	await press(KEY_2)
	await frames(26)
	check(d.health[1] == 77,'Hunter key 2 performs raptor strike with damage talent')
	if visual: await game.screenshot('classes-ui-raptor')
	await press(KEY_ESCAPE)
	var hp: int = d.health[1]
	var elapsed: float = d.elapsed
	await press(KEY_1)
	await frames(20)
	check(d.health[1] == hp and d.elapsed == elapsed,'Pause blocks attacks and clock')
	await click_action('resume')
	d.damage(d.opponent,100)
	check(d.winner == 0 and game.screen == 'duel_result','Victory result')
	if visual: await game.screenshot('classes-ui-victory')
	await click_action('duel_begin')
	check(d.health == {0:100,1:100} and d.selected_class == 3,'Rematch keeps class and restores health')
	await press(KEY_ESCAPE)
	await click_action('island')
	await frames(15)
	check(game.screen == 'island' and game.racers.size() == 1 and d.health.is_empty(),'Return clears duel')
	await click_action('class_room')
	for row in range(3): await click_action('class_talent_%d_1' % row)
	if visual: await game.screenshot('classes-ui-talents')
	await click_action('class_confirm')
	check(game.class_profile.talents == [1,1,1] and game.player.skills.career.class_id == 'hunter','Talent buttons apply without changing class')
	await click_action('join')
	check(game.screen == 'racing' and game.racers.size() == 32 and game.player.skills.career.class_id == 'hunter','Race UI keeps profession')
	game.enter_island()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path+'.career')
	DirAccess.remove_absolute(path)
	print('DUEL TEST: ', 'PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
