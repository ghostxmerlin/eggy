extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func frames(count: int):
	for i in range(count): await physics_frame
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await frames(4)
	if game.player.get_node_or_null('Skills') == null:
		print('SKILLS TEST: FAIL missing abilities')
		quit(1)
		return
	var player = game.player
	var kit = player.skills
	player.position = Vector3(0,.15,24)
	game.camera_yaw = 0
	await frames(35)
	var targets = get_nodes_in_group('combatants').filter(func(r): return r != player)
	check(targets.size() >= 3, 'Island supplies practice targets')
	var target = targets[0]
	target.position = player.position + Vector3(0,0,-2)
	await frames(2)
	check(kit.use_skill(3), 'Fish attack can start')
	check(kit.cooldown(3) > 3.9 and kit.cooldown(3) <= 4.0, 'Fish cooldown is four seconds')
	check(not kit.use_skill(3), 'Fish cannot bypass four-second cooldown')
	await frames(16)
	check(target.skills.knockback_left > 0, 'Fish swing actually hits nearby target')
	await frames(24)
	target.position = player.position + Vector3(0,0,-3)
	targets[1].position = player.position + Vector3(0,0,3)
	targets[2].position = player.position + Vector3(0,0,-8)
	target.velocity = Vector3.ZERO
	target.skills.knockback_left = 0
	check(kit.use_skill(4), 'Ice cone can cast')
	check(target.skills.frozen_left > 1.9 and target.skills.frozen_left <= 2.0, 'Ice freezes target in front for two seconds')
	check(targets[1].skills.frozen_left == 0 and targets[2].skills.frozen_left == 0, 'Ice excludes targets behind or beyond range')
	check(kit.cooldown(4) > 9.8, 'Ice cooldown is ten seconds')
	var anchor: Vector3 = target.position
	await frames(45)
	check(Vector2(target.position.x-anchor.x,target.position.z-anchor.z).length() < .05, 'Frozen target remains rooted')
	game.toggle_pause()
	var frozen: float = target.skills.frozen_left
	var cd: float = kit.cooldown(4)
	await frames(20)
	check(target.skills.frozen_left == frozen and kit.cooldown(4) == cd, 'Pause freezes statuses and cooldowns')
	game.toggle_pause()
	await frames(150)
	check(target.skills.frozen_left <= 0, 'Freeze expires')
	target.position = player.position + Vector3(0,0,-3)
	targets[1].position = player.position + Vector3(0,0,3)
	targets[2].position = player.position + Vector3(0,0,-9)
	check(kit.use_skill(5), 'Fear can cast')
	check(targets[1].skills.fear_left > 1.9 and targets[2].skills.fear_left == 0, 'Fear covers targets behind but excludes distant targets')
	check(kit.cooldown(5) > 14.8 and target.skills.fear_left > 1.9, 'Fear lasts two seconds with fifteen-second cooldown')
	anchor = target.position
	await frames(30)
	check(target.position.distance_to(anchor) > 1, 'Fear forces uncontrolled movement')
	await frames(100)
	check(target.skills.fear_left <= 0, 'Fear releases control after two seconds')
	check(kit.use_skill(2), 'Dive starts')
	anchor = player.position
	await frames(20)
	check(player.position.z < anchor.z-3, 'Dive lunges forward')
	player.respawn()
	check(kit.dive_left == 0 and kit.fear_left == 0, 'Respawn cancels movement and control effects')
	game.start_race()
	await frames(3)
	check(get_nodes_in_group('combatants').size() == 1, 'Training targets stay on island')
	print('SKILLS TEST: ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
