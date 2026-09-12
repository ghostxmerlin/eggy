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
	var ride = game.course.get_node_or_null('Attractions/PlaneRide')
	if ride == null:
		print('PLANE TEST: FAIL missing boardable airplane')
		quit(1)
		return
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var player = game.player
	await frames(150)
	check(ride.state == 'parked' and ride.canopy_open < .01, 'Empty plane waits on its platform with canopy closed')
	# Walk from the platform up the physical ramp, not directly into a seat by script.
	player.position = Vector3(29.2,10.75,13)
	player.velocity = Vector3.ZERO
	game.camera_yaw = 0
	await frames(100)
	check(ride.canopy_open > .95, 'Approaching egg opens canopy')
	Input.action_press('right')
	for i in range(180):
		await physics_frame
		if is_instance_valid(player.vehicle): break
	Input.action_release('right')
	check(is_instance_valid(player.vehicle), 'Walking up the ramp boards the cockpit')
	if not is_instance_valid(player.vehicle):
		print('BOARD DEBUG position=',player.position,' state=',ride.state)
		print('PLANE TEST: FAIL ',failures)
		quit(1)
		return
	await frames(150)
	check(ride.state == 'takeoff' and ride.body.position.y > ride.DOCK.y+.3, 'Boarding closes canopy and launches plane')
	check(not player.skills.use_skill(2), 'Passenger cannot dive out through the closed canopy')
	game.toggle_pause()
	var parked_transform: Transform3D = ride.body.transform
	var passenger_position: Vector3 = player.position
	await frames(30)
	check(ride.body.transform.is_equal_approx(parked_transform) and player.position.is_equal_approx(passenger_position), 'Pause freezes plane and passenger together')
	game.toggle_pause()
	var maximum_drift := 0.0
	for i in range(2300):
		await physics_frame
		if ride.state == 'disembark': break
		if is_instance_valid(player.vehicle): maximum_drift = maxf(maximum_drift,player.global_position.distance_to(ride.passenger_position()))
	check(maximum_drift < .06, 'Passenger stays attached throughout flight without accumulating drift')
	check(ride.state == 'disembark' and ride.body.position.distance_to(ride.DOCK) < .01, 'Plane returns to the same platform')
	check(ride.canopy_open > .95 and not is_instance_valid(player.vehicle), 'Canopy opens before free movement is restored')
	await frames(180)
	check(ride.state == 'disembark', 'Remaining inside after landing does not immediately relaunch')
	game.camera_yaw = 0
	Input.action_press('left')
	await frames(40)
	Input.action_release('left')
	check(player.position.x < 34.0, 'Passenger can walk out onto the boarding ramp')
	Input.action_press('right')
	for i in range(360):
		await physics_frame
		if is_instance_valid(player.vehicle): break
	Input.action_release('right')
	check(is_instance_valid(player.vehicle), 'A passenger who stepped out can board again')
	await frames(150)
	player.respawn()
	await frames(3)
	check(not is_instance_valid(player.vehicle) and not is_instance_valid(ride.passenger), 'Returning to plaza during flight detaches passenger')
	check(player.position.distance_to(game.Island.SPAWN) < .35, 'Mid-flight reset returns safely to plaza')
	game.start_race()
	game.enter_island()
	await frames(5)
	ride = game.course.get_node('Attractions/PlaneRide')
	player.position = Vector3(29.2,10.75,13)
	player.velocity = Vector3.ZERO
	await frames(200)
	Input.action_press('right')
	for i in range(240):
		await physics_frame
		if is_instance_valid(player.vehicle): break
	Input.action_release('right')
	check(is_instance_valid(player.vehicle), 'Passenger is aboard before scene-change cleanup check')
	game.start_race()
	await frames(5)
	check(not is_instance_valid(player.vehicle) and player.collision_mask == 7, 'Changing worlds clears passenger state')
	check(player.get_collision_exceptions().is_empty(), 'Scene changes remove aircraft collision exceptions')
	print('PLANE TEST: ', 'PASS' if failures.is_empty() else 'FAIL', failures,' maximum_drift=',maximum_drift)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
