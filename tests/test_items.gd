extends SceneTree

var failures: Array[String] = []
var game
var items
var player
var target

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize(): call_deferred('run')

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		items._physics_process(1.0/60.0)

func reset() -> void:
	items.clear()
	items.enabled = true
	game.paused = false
	game.in_island = false
	game.practice = false
	game.screen = 'racing'
	game.rules.start(false)
	game.rules.advance(3.0)
	player.reset_to_start(Vector3(0,.12,-65))
	target.reset_to_start(Vector3(6,.12,-65))
	for racer in game.racers:
		racer.active = true
		racer.external_control = true
		racer.item_state.ai_wait = 99

func equip(id: String, racer = null) -> void:
	if racer == null: racer = player
	racer.item_state.held = id
	racer.item_state.ai_wait = 99
	items.sync_held(racer)

func run() -> void:
	game = load('res://main.tscn').instantiate()
	game.item_seed = 2026
	root.add_child(game)
	await process_frame
	check(not game.items.enabled and game.items.pickups.is_empty(),'Island has no race item boxes')
	game.ui_action('join')
	items = game.items
	check(items.pickups.size() == 44,'Competition supplies item boxes along ten safe rows')
	game.set_physics_process(false)
	items.set_physics_process(false)
	player = game.player
	target = game.racers[1]
	for racer in game.racers.slice(2):
		game.remove_child(racer)
		racer.queue_free()
	game.racers = [player,target]
	await process_frame
	reset()
	var box: Dictionary = items.add_pickup(player.position+Vector3.UP*.9)
	game.rules.start(false)
	check(not items.collect(player,box),'Countdown blocks pickup')
	game.rules.advance(3.0)
	check(items.collect(player,box),'Physical contact gives a random item')
	var held: String = player.item_state.held
	check(held in items.Catalog.IDS and not box.node.visible,'Pickup selects a known item and hides the box')
	target.position = player.position
	check(not items.collect(target,box),'One box cannot be collected twice')
	var another: Dictionary = items.add_pickup(player.position+Vector3.UP*.9)
	check(not items.collect(player,another) and player.item_state.held == held,'Full inventory does not overwrite an item')
	target.position.x = 6
	game.paused = true
	var remaining: float = box.remaining
	await frames(10)
	check(box.remaining == remaining and not items.use_item(player),'Pause freezes boxes and blocks item use')
	game.paused = false
	items._physics_process(4.1)
	check(box.remaining == 0 and box.node.visible,'Used boxes respawn after four seconds')
	var sample: Dictionary = {}
	items.bag.clear()
	for i in range(12): sample[items.next_item()] = true
	check(sample.size() == 12,'A shuffled bag makes all twelve items obtainable')

	reset()
	equip('boost')
	var start: Vector3 = player.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	check(player.item_state.boost > 0 and player.item_state.held == '' and player.position.z == start.z,'R uses the carried item without returning to a checkpoint')
	key.echo = true
	equip('clock')
	Input.parse_input_event(key)
	await frames(1)
	check(player.item_state.held == 'clock','Held-key repeat cannot spend another item')
	player.drive = Vector2(0,-1)
	await frames(20)
	check(absf(player.velocity.z) > 9.0,'Acceleration item changes real movement speed')
	player.item_state.boost = .01
	await frames(2)
	check(player.item_state.boost == 0 and is_equal_approx(player.item_state.speed_scale(),1),'Speed buff expires')
	player.skills.remaining.fill(8.0)
	player.roll_cooldown = 3
	check(items.use_item(player) and player.roll_cooldown == 0 and player.skills.remaining.all(func(v): return v == 0),'Stopwatch restores skill cooldowns')
	equip('jetpack')
	player.skills.apply_freeze()
	check(not items.use_item(player) and player.item_state.held == 'jetpack','Controlled racers keep their item instead of spending it')
	player.skills.reset()
	check(items.use_item(player),'Jetpack activates')
	await frames(24)
	check(player.position.y > 1.2,'Jetpack lifts the actual character body')
	key.physical_keycode = KEY_T
	key.echo = false
	Input.parse_input_event(key)
	await frames(1)
	check(player.item_state.jetpack == 0 and absf(player.position.z-game.course.CHECKPOINTS[player.checkpoint].z) < 1,'T respawns and clears item effects')

	reset()
	player.position = Vector3(4,.1,-67)
	target.position = Vector3(8.8,.1,-67)
	equip('ball')
	check(items.use_item(player,Vector3.RIGHT),'Ball launches')
	await frames(30)
	check(items.hits.get('ball',0) > 0 and target.position.x > 10,'Swept ball collision physically knocks a rival beyond the track edge')
	# Observe the actual recovery, before a later rotating hazard can hit again.
	var recovered := false
	for frame in range(180):
		await frames(1)
		var checkpoint: Vector3 = game.course.CHECKPOINTS[target.checkpoint]
		if target.position.distance_to(checkpoint) < 3 and target.position.y > -.2:
			recovered = true
			break
	check(recovered,'Knocked-out rival respawns safely')

	for kind in ['ink','bomb','smoke']:
		reset()
		target.position = Vector3(0,.1,-80)
		equip(kind)
		check(items.use_item(player,Vector3.FORWARD),kind+' throws successfully')
		await frames(65)
		if kind == 'ink':
			check(target.item_state.ink > 0 and player.item_state.ink == 0,'Ink projectile impairs a nearby rival, not its thrower')
		elif kind == 'bomb': check(items.hits.get('bomb',0) > 0,'Thrown bomb explodes and hits a rival')
		else: check(target.item_state.smoke > 0,'Smoke projectile creates an obstructing area')

	reset()
	equip('portal')
	check(items.use_item(player,Vector3.FORWARD),'Portal orb throws')
	await frames(80)
	check(items.portal_trips > 0 and player.position.z < -74.6 and player.position.y > -.5,'Portal crosses a gap to a supported platform')
	check(player.item_state.portal_lock > 0,'Portal cooldown prevents immediate retrigger')

	reset()
	player.position = Vector3(0,.1,-10)
	target.position = Vector3(4,.1,-10)
	equip('rope')
	check(items.use_item(player,Vector3.RIGHT),'Spring rope throws')
	await frames(12)
	check(items.hits.get('rope',0) > 0 and player.position.x > .2 and target.position.x < 4,'Rope draws both bodies together through physics')

	reset()
	equip('spring')
	check(items.use_item(player,Vector3.FORWARD),'Springboard deploys')
	target.position = Vector3(0,.2,-67.2)
	await frames(12)
	check(items.spring_launches > 0 and target.position.y > 1 and target.velocity.z < -8,'Springboard launches an actual racer in its facing direction')

	reset()
	equip('mine')
	check(items.use_item(player,Vector3.FORWARD),'Mine deploys')
	await frames(48)
	target.position = Vector3(0,.2,-67.2)
	await frames(5)
	check(items.hits.get('mine',0) > 0 and items.zones.is_empty(),'Armed mine explodes once when a rival steps on it')

	reset()
	equip('crate')
	check(items.use_item(player,Vector3.FORWARD),'Crate deploys')
	target.position = Vector3(0,2.5,-67.2)
	await frames(40)
	check(target.is_on_floor() and target.position.y > 1.2,'Crate supplies a solid standable surface')
	equip('mine')
	player.position = Vector3(40,.1,-65)
	check(not items.use_item(player) and player.item_state.held == 'mine','Unsupported placement fails without spending the item')

	reset()
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(.5,8,8)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	items.add_child(wall)
	wall.position = Vector3(2,3,-65)
	await frames(2)
	equip('portal')
	items.use_item(player,Vector3.RIGHT)
	await frames(30)
	check(items.zones.is_empty() and player.position.x < 1,'Portal hitting a wall cannot teleport through it')
	wall.position.x = 1.3
	await frames(2)
	equip('ball')
	check(not items.use_item(player,Vector3.RIGHT) and player.item_state.held == 'ball','Blocked throw cannot spawn a large projectile inside a wall')

	reset()
	target.position = Vector3(0,.1,-65)
	player.position.x = 6
	var ai_box: Dictionary = items.add_pickup(target.position+Vector3.UP*.9)
	check(items.collect(target,ai_box),'AI uses the same physical pickup rules')
	player.position = Vector3(0,.1,-80)
	equip('bomb',target)
	target.item_state.ai_wait = 0
	items.ai_try_use(target)
	check(items.used.get(1,0) > 0 and target.item_state.held == '' and items.projectiles.size() == 1,'AI spends its collected item on a real throw')
	game.paused = true
	var projectile_position: Vector3 = items.projectiles[0].node.position
	await frames(6)
	check(items.projectiles[0].node.position == projectile_position,'Pause freezes projectiles')
	game.paused = false
	equip('ink')
	player.item_state.ink = 2
	game.start_race()
	check(items.projectiles.is_empty() and items.zones.is_empty() and player.item_state.held == '' and player.item_state.ink == 0,'Restart clears inventory, projectiles and effects')
	game.enter_island()
	check(not items.enabled and items.pickups.is_empty() and items.get_child_count() == 0,'Returning to island removes every item object')
	print('ITEM SYSTEM: ', 'PASS' if failures.is_empty() else 'FAIL', ' ',failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
