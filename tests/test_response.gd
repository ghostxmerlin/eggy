extends SceneTree
var errors: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await process_frame
	game.start_race()
	var p = game.player
	p.position = Vector3(0,.08,-6)
	for i in range(30): await physics_frame
	Input.action_press('forward')
	for i in range(6): await physics_frame
	check(-p.velocity.z >= 7.5, 'Reach running speed within 100ms')
	for i in range(12): await physics_frame
	Input.action_release('forward')
	Input.action_press('back')
	for i in range(6): await physics_frame
	check(p.velocity.z >= 6.0, 'Reverse direction within 100ms')
	Input.action_release('back')
	for i in range(5): await physics_frame
	check(absf(p.velocity.z) < .1, 'Stop within 83ms after release')
	game.camera.position = p.position+Vector3(0,7.4,8.3)
	p.position.z -= 2
	game.update_camera(.1)
	var expected_z: float = p.get_global_transform_interpolated().origin.z+11.3
	check(absf(game.camera.position.z-expected_z) < .4,'Camera settles close to target within 100ms')
	print('RESPONSE TEST: ', 'PASS' if errors.is_empty() else 'FAIL',errors)
	game.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
