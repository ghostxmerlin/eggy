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
	game = load('res://main.tscn').instantiate()
	game.skin_save_path = 'user://test-duel-isolated.cfg'
	root.add_child(game)
	await frames(40)
	await click_action('duel_room')
	check(game.screen == 'duel_lobby' and game.paused,'Island opens class room')
	for i in range(4):
		await click_action('duel_class_'+str(i))
		check(game.duel.selected_class == i,'Select profession '+str(i))
	game.duel.select_class(9)
	check(game.duel.selected_class == 3,'Invalid class rejected')
	if visual: await game.screenshot('duel-class-room')
	await click_action('duel_begin')
	var d = game.duel
	var p = game.player
	check(game.screen == 'duel' and game.racers.size() == 2 and get_nodes_in_group('combatants').size() == 2,'Exactly player and one bot')
	check(not game.items.enabled and d.health == {0:100,1:100},'Full health, no race items')
	check(not p.active and not p.skills.use_skill(3),'Countdown blocks attacks')
	await press(KEY_ESCAPE)
	var remaining: float = d.countdown
	await frames(15)
	check(game.paused and d.countdown == remaining,'Countdown can pause')
	await click_action('resume')
	if visual: await game.screenshot('duel-countdown')
	await frames(190)
	d.ai_enabled = false
	d.opponent.drive = Vector2.ZERO
	Input.action_press('forward')
	var start: Vector3 = p.position
	await frames(15)
	Input.action_release('forward')
	check(p.position.z < start.z-.5,'Normal player movement works in duel')
	p.request_jump()
	await frames(12)
	check(p.position.y > .5,'Jump remains available')
	await frames(60)
	await press(KEY_SHIFT)
	await press(KEY_2)
	check(p.roll_left == 0 and p.skills.dive_left == 0,'Keyboard roll and dive disabled')
	p.external_control = true
	p.drive = Vector2(1,0)
	await frames(120)
	check(p.position.x < 11.3 and p.position.y > -.2,'Arena boundary retains moving player')
	p.drive = Vector2.ZERO
	check(d.phase == 'fighting' and p.active and d.opponent.active,'Countdown activates both fighters')
	check(not p.skills.use_skill(1) and not p.skills.use_skill(2),'Reserved skills cannot roll or dive')
	p.request_roll()
	check(p.roll_left == 0 and p.skills.cooldown(1) == 0,'Direct roll bypass also blocked')
	p.reset_to_start(Vector3(0,.12,2))
	d.opponent.reset_to_start(Vector3(0,.12,0))
	p.active = true
	d.opponent.active = true
	await frames(20)
	check(p.skills.use_skill(4) and d.opponent.skills.frozen_left > 0,'Ice freezes opponent')
	await frames(15)
	check(d.health == {0:100,1:100},'Freeze does not inflict damage')
	check(p.skills.use_skill(5) and d.opponent.skills.fear_left > 0,'Roar frightens opponent')
	await frames(15)
	check(d.health == {0:100,1:100},'Fear does not inflict damage')
	for strike in range(5):
		if strike == 2: p.set_skin('mecha')
		p.reset_to_start(Vector3(0,.12,2))
		d.opponent.reset_to_start(Vector3(0,.12,0))
		p.active = true
		d.opponent.active = true
		await frames(20)
		check(p.skills.use_skill(3),'Melee starts')
		await frames(24)
		check(d.health[1] == 100-(strike+1)*20,'Each real swing hits exactly once: '+str(strike))
		if strike == 0:
			if visual: await game.screenshot('duel-hit')
			await press(KEY_ESCAPE)
			var elapsed: float = d.elapsed
			d.register_hit(p,d.opponent)
			await frames(20)
			check(d.elapsed == elapsed and d.health[1] == 80,'Pause freezes clock and rejects damage')
			await click_action('resume')
			await press(KEY_T)
			check(d.health[1] == 80 and d.phase == 'fighting','T cannot reset duel')
		if strike < 4: await frames(35)
	check(d.winner == 0 and game.screen == 'duel_result' and not p.active,'Zero enemy HP ends in victory')
	d.damage(p,100)
	check(d.health[0] == 100,'Ended round cannot reverse winner')
	if visual: await game.screenshot('duel-victory')
	await click_action('duel_room')
	await press(KEY_2)
	await press(KEY_ENTER)
	check(d.selected_class == 1 and d.health == {0:100,1:100} and game.racers.size() == 2,'Keyboard class change and fresh round')
	p.external_control = true
	p.drive = Vector2.ZERO
	d.rng.seed = 42
	for i in range(6000):
		await frames(1)
		if d.phase == 'ended': break
	print('DUEL AI elapsed=',d.elapsed,' health=',d.health)
	check(d.winner == 1 and d.health[0] == 0,'Active bot defeats a passive player through real attacks')
	if visual: await game.screenshot('duel-defeat')
	await click_action('duel_begin')
	check(d.health == {0:100,1:100} and not p.finished and p.roll_visual.rotation.z == 0,'Rematch restores health and pose')
	await press(KEY_ESCAPE)
	await click_action('island')
	await frames(15)
	check(game.screen == 'island' and game.racers.size() == 1 and d.health.is_empty(),'Return cleans arena state')
	check(p.skills.use_skill(1),'Island rolling restored')
	game.join_race()
	check(game.racers.size() == 32 and game.items.enabled and game.screen == 'racing','Race remains 32 participants with items')
	game.enter_island()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute('user://test-duel-isolated.cfg')
	print('DUEL TEST: ', 'PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
