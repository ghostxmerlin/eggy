extends SceneTree
var failures: Array[String] = []
var game: Node
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func frames(count: int):
	for i in range(count):
		await physics_frame
		if game and DisplayServer.get_name() != 'headless': game.hud.queue_redraw()
func _initialize(): call_deferred('run')
func run():
	game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await frames(30)
	if DisplayServer.get_name() != 'headless':
		game.set_process(false)
		game.camera.position = Vector3(-6,4.5,32)
		game.camera.look_at(Vector3(0,1.0,24))
	if not game.player.skills.has_method('resolve_dive_collisions'):
		print('IMPACT TEST: FAIL missing dive collision transfer')
		quit(1)
		return
	var player = game.player
	var targets = get_nodes_in_group('combatants').filter(func(r): return r != player)
	var target = targets[0]
	for other in targets:
		other.training_home = Vector3(-30,.1,30+targets.find(other)*3)
		other.position = other.training_home
	player.reset_to_start(Vector3(0,.1,26))
	player.active = true
	target.training_home = Vector3(0,.1,23.6)
	target.position = target.training_home
	await frames(20)
	var start: Vector3 = target.position
	player.skills.use_skill(2)
	await frames(23)
	check(target.position.z < start.z-1.2, 'Dive pushes an equal-mass character out of the way')
	check(player.skills.dive_speed < 15, 'Diver gives up momentum at impact')
	if DisplayServer.get_name() != 'headless': await game.screenshot('impact-dive-character')
	player.reset_to_start(Vector3(0,.1,26))
	player.active = true
	target.skills.reset()
	target.velocity = Vector3.ZERO
	target.training_home = Vector3(0,.1,24)
	target.position = target.training_home
	await frames(20)
	player.skills.use_skill(3)
	await frames(20)
	check(target.skills.knockback_left > 0, 'Horizontal sweep hits a grounded character')
	check(target.position.y < .2, 'Grounded fish hit stays a ground knockback')
	player.reset_to_start(Vector3(0,.1,26))
	player.active = true
	target.skills.reset()
	target.position = Vector3(0,.1,24)
	target.velocity = Vector3.ZERO
	await frames(25)
	# A jumping target crosses the weapon at the moment of the frontal sweep.
	player.skills.use_skill(3)
	await frames(10)
	target.position.y = .65
	target.velocity.y = 3.0
	await frames(8)
	print('AIR HIT target=',target.position,' velocity=',target.velocity,' knockback=',target.skills.knockback_left)
	check(target.skills.knockback_left > 0 and target.velocity.y > 3.5, 'Airborne sweep adds upward launch from contact angle')
	if DisplayServer.get_name() != 'headless': await game.screenshot('impact-airborne-sweep')
	var apex: float = target.position.y
	for i in range(20):
		await frames(1)
		apex = maxf(apex,target.position.y)
	print('AIR FLIGHT target=',target.position,' velocity=',target.velocity)
	check(apex > 1.4, 'Launched target follows a visible airborne trajectory')
	# A target well above the horizontal weapon must not be hit by an invisible cone.
	player.reset_to_start(Vector3(0,.1,26))
	player.active = true
	target.skills.reset()
	target.position = Vector3(0,5,24)
	target.velocity = Vector3.ZERO
	player.skills.use_skill(3)
	await frames(18)
	check(target.skills.knockback_left == 0, 'Sweep respects actual vertical separation')
	var boxes = get_nodes_in_group('practice_pushables')
	check(boxes.size() >= 2, 'Practice area includes equal-mass movable objects')
	if boxes.size() > 0:
		target.position = Vector3(-30,.1,30)
		player.reset_to_start(Vector3(0,.1,26))
		player.active = true
		var box: RigidBody3D = boxes[0]
		box.position = Vector3(0,.65,23.6)
		box.linear_velocity = Vector3.ZERO
		box.angular_velocity = Vector3.ZERO
		box.sleeping = false
		await frames(20)
		start = box.position
		player.skills.use_skill(2)
		await frames(24)
		check(box.position.z < start.z-.8, 'Dive transfers impulse to an equal-mass rigid body')
		if DisplayServer.get_name() != 'headless': await game.screenshot('impact-dive-box')
		game.toggle_pause()
		await frames(3)
		start = box.position
		await frames(15)
		check(box.position.distance_to(start) < .01, 'Paused movable objects do not keep sliding')
		game.toggle_pause()
	print('IMPACT TEST: ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
