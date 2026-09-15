extends SceneTree

var failures: Array[String] = []
var game
var bot
var rival
var visual := false

func _initialize() -> void: call_deferred('run')

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func reset() -> void:
	game.items.clear()
	game.rules.start(false)
	game.rules.advance(3)
	game.paused = false
	for racer in game.racers:
		racer.reset_to_start(Vector3(8,.1,5+racer.racer_id*2))
		racer.set_physics_process(false)
		racer.external_control = true

func place(racer, position: Vector3, automatic := false) -> void:
	racer.reset_to_start(position)
	racer.active = true
	racer.external_control = not automatic
	racer.set_physics_process(true)
	racer.race_ai.reset()

func equip(kind: String) -> void:
	bot.item_state.held = kind
	bot.item_state.ai_wait = 0
	game.items.sync_held(bot)

func capture(label: String) -> void:
	game.camera.position = Vector3(10,18,-276)
	game.camera.look_at(Vector3(0,0,-298))
	DisplayServer.window_move_to_foreground()
	game.hud.queue_redraw()
	for i in range(4): await process_frame
	await game.screenshot(label)

func run() -> void:
	game = load('res://main.tscn').instantiate()
	game.item_seed = 91
	root.add_child(game)
	await process_frame
	game.join_race() # Career selection UI is covered by test_duel.gd.
	game.set_physics_process(false)
	game.items.set_physics_process(false)
	visual = '--visual' in OS.get_cmdline_user_args()
	if visual: game.set_process(false)
	bot = game.racers[1]
	rival = game.player
	reset()
	# Reproduce a stopped leader and a nose-to-tail queue on the finish platform.
	place(rival,Vector3(0,.1,-302))
	for i in range(1,9):
		place(game.racers[i],Vector3(0,.1,-299+(i-1)*1.15),true)
		game.racers[i].checkpoint = 6
	var widest := 0.0
	var falls := 0
	for frame in range(600):
		await physics_frame
		if visual and frame == 45: await capture('ai-finish-queue-bypass')
		for racer in game.racers.slice(1,9):
			widest = maxf(widest,absf(racer.position.x))
			if racer.position.y < -2: falls += 1
	check(game.rules.order.size() == 8,'All eight queued bots pass a stationary leader and finish within ten seconds')
	check(widest > 2.5 and falls == 0,'Finish traffic spreads across the platform without falling')
	check(not rival.finished and absf(rival.position.z+302) < .2,'The stationary leader remains a real physical blocker')
	print('AI QUEUE: finishers=',game.rules.order.size(),' spread=',widest,' falls=',falls)

	reset()
	game.items.enabled = true
	place(rival,Vector3(0,.1,-296.8))
	rival.item_state.held = 'crate'
	check(game.items.use_item(rival,Vector3.FORWARD),'Set up a real solid crate before finish')
	rival.position.x = 8
	for i in range(1,7):
		place(game.racers[i],Vector3(0,.1,-296+(i-1)*1.15),true)
		game.racers[i].lane = 0
		game.racers[i].checkpoint = 6
	await frames(45)
	if visual: await capture('ai-finish-crate-bypass')
	await frames(555)
	check(game.rules.order.size() == 6,'Six bots sharing a preferred lane bypass a crate and finish')

	reset()
	for i in range(1,8):
		place(game.racers[i],Vector3((i%3-1)*1.4,.1,-266+(i/3)*1.4),true)
		game.racers[i].lane = float(i%7-3)*2.25
		game.racers[i].checkpoint = 5
	falls = 0
	for frame in range(1000):
		await physics_frame
		for racer in game.racers.slice(1,8):
			if racer.position.y < -2: falls += 1
	check(game.rules.order.size() == 7 and falls == 0,'All seven bots cross the final narrow bridge and gaps without falling')
	print('AI FINAL BRIDGE: finishers=',game.rules.order.size(),' falls=',falls)

	reset()
	for i in range(1,15):
		place(game.racers[i],Vector3((i%5-2)*1.8,.1,-145+(i/5)*1.5),true)
		game.racers[i].lane = float(i%7-3)*2.25
		game.racers[i].checkpoint = 3
	var respawns := 0
	var last_positions: Dictionary = {}
	for frame in range(2700):
		await physics_frame
		for racer in game.racers.slice(1,15):
			if last_positions.has(racer.racer_id) and racer.position.z-last_positions[racer.racer_id] > 8: respawns += 1
			last_positions[racer.racer_id] = racer.position.z
	check(game.rules.order.size() == 14 and respawns < 14,'A fourteen-bot pack crosses every offset deck and finishes without repeated fall loops')
	print('AI OFFSET DECKS: finishers=',game.rules.order.size(),' respawns=',respawns)

	reset()
	game.items.enabled = true
	place(bot,Vector3(0,.1,-65))
	await frames(4)
	equip('bomb')
	game.items.ai_try_use(bot)
	check(bot.item_state.held == 'bomb' and game.items.projectiles.is_empty(),'No target: hold an attack item')
	place(rival,Vector3(0,.1,-80))
	equip('bomb')
	game.items.ai_try_use(bot)
	check(bot.item_state.held == '' and game.items.projectiles.size() == 1,'A target in the actual lob range triggers an attack')
	for i in range(65):
		await physics_frame
		game.items.tick_projectiles(1.0/60.0)
	check(game.items.hits.get('bomb',0) > 0,'The timed AI bomb physically hits its target')

	reset()
	game.items.enabled = true
	place(bot,Vector3(0,.1,-293))
	place(rival,Vector3(0,.1,-304))
	await frames(4)
	rival.velocity = Vector3(3,0,-4)
	var aim: Vector3 = game.items.ai_attack_direction(bot,'ball',Vector3.FORWARD)
	check(aim.x > .05 and aim.z < -.9,'An attack leads a moving opponent rather than aiming at stale coordinates')
	rival.velocity = Vector3.ZERO
	var wall := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5,4,1)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	game.items.add_child(wall)
	wall.position = Vector3(0,2,-298)
	await frames(2)
	equip('ball')
	game.items.ai_try_use(bot)
	check(bot.item_state.held == 'ball' and game.items.projectiles.is_empty(),'A solid wall blocks the AI attack decision')

	reset()
	game.items.enabled = true
	place(bot,Vector3(0,.1,-10))
	place(rival,Vector3(0,.1,-3))
	await frames(4)
	equip('rope')
	game.items.ai_try_use(bot)
	check(bot.item_state.held == 'rope','Rope does not pull its owner backwards toward a pursuer')
	equip('mine')
	game.items.ai_try_use(bot)
	check(bot.item_state.held == '' and game.items.zones.size() == 1 and game.items.zones[0].node.position.z > bot.position.z,'Mine is placed behind for a pursuer')
	equip('clock')
	game.items.ai_try_use(bot)
	check(bot.item_state.held == 'clock','Ready skills do not waste the stopwatch')
	bot.roll_cooldown = 2.5
	bot.item_state.ai_wait = 0
	game.items.ai_try_use(bot)
	check(bot.item_state.held == '' and bot.roll_cooldown == 0,'Stopwatch restores a spent sprint cooldown')

	reset()
	game.items.enabled = true
	place(bot,Vector3(0,.1,-270))
	await frames(4)
	equip('boost')
	game.items.ai_try_use(bot)
	check(bot.item_state.held == 'boost','Boost waits when a gap interrupts the runway')
	place(bot,Vector3(0,.1,-293))
	await frames(4)
	equip('boost')
	game.items.ai_try_use(bot)
	check(bot.item_state.boost > 0 and bot.item_state.held == '','A clear finish straight triggers acceleration')
	equip('jetpack')
	game.items.ai_try_use(bot)
	check(bot.item_state.held == 'jetpack','Jetpack does not fly over the finish trigger')
	bot.skills.apply_freeze()
	equip('boost')
	game.items.ai_try_use(bot)
	check(bot.item_state.held == 'boost','Control effects prevent AI item use')
	bot.race_ai.stuck_time = 2
	bot.respawn()
	check(bot.race_ai.stuck_time == 0,'Respawn clears stale stuck recovery')
	print('RACE AI: ', 'PASS' if failures.is_empty() else 'FAIL', ' ',failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
