extends SceneTree
var failures: Array[String] = []
var visual := false
func _initialize(): call_deferred('run')
func frames(n: int):
	for i in range(n): await physics_frame
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func run():
	visual = '--visual' in OS.get_cmdline_user_args()
	var game = load('res://main.tscn').instantiate()
	game.skin_save_path = 'user://supreme-effects-isolated.cfg'
	root.add_child(game)
	game.set_process_input(false)
	await frames(50)
	game.gacha.open()
	game.gacha.select_skin('mecha')
	var preview_fx = game.gacha.preview.get_node_or_null('SkinAccessories/SupremeEffects')
	check(preview_fx != null,'Supreme preview contains its dedicated cape and effects')
	if preview_fx == null:
		print('SUPREME EFFECTS: FAIL ',failures)
		quit(1)
		return
	var clock_before: float = preview_fx.clock
	await frames(30)
	check(preview_fx.clock > clock_before,'Wardrobe effects animate while the game world is paused')
	for angle in [-.4,PI+.35]:
		game.gacha.preview.rotation.y = angle
		await frames(25)
		if visual: await game.screenshot('supreme-preview-'+('front' if angle < 0 else 'back'))
	game.gacha.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await frames(2)
	clock_before = preview_fx.clock
	await frames(10)
	check(preview_fx.clock == clock_before and preview_fx.particles.speed_scale == 0,'Hidden preview stops effects')
	game.gacha.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await frames(10)
	check(preview_fx.clock > clock_before,'Reopened preview resumes effects')
	game.gacha.select_skin('mecha_blaze')
	await frames(15)
	check(not is_instance_valid(preview_fx),'Switching preview destroys the previous cape and emitters')
	check(game.gacha.preview.get_node_or_null('SkinAccessories/SupremeEffects') == null,'Purple mech does not receive supreme effects')
	game.gacha.preview.rotation.y = -.4
	await frames(5)
	if visual: await game.screenshot('supreme-purple-comparison')
	game.gacha.shutdown()
	game.player.set_skin('mecha')
	var fx = game.player.model.get_node_or_null('SkinAccessories/SupremeEffects')
	check(fx != null and fx.racer == game.player,'Equipped effect follows the actual racer')
	check(game.player.collision_layer == 2 and game.player.collision_mask == 7,'Cosmetics preserve racer collision filters')
	var joined: Mesh = game.player.model.get_node('SkinAccessories/JoinedShell').mesh
	var polished := false
	for i in range(joined.get_surface_count()):
		var material = joined.surface_get_material(i)
		if material.clearcoat_enabled:
			polished = material.metallic >= .85 and material.roughness <= .15 and material.next_pass != null
	check(polished,'Compacted armor preserves polished metal, clearcoat and highlight pass')
	game.player.position = Vector3(-20,0,33)
	game.player.external_control = true
	game.player.drive = Vector2(0,-1)
	await frames(35)
	check(fx.motion > .35,'Real running velocity lifts and streams the cape')
	game.player.request_jump()
	await frames(10)
	check(not game.player.is_on_floor(),'Jump sample is actually airborne')
	if visual: await capture_character(game,'supreme-jump',Vector3(-3,2,5))
	await frames(55)
	game.player.skills.use_skill(1)
	await frames(15)
	check(fx.fold > .8 and fx.particles.amount_ratio <= .301,'Rolling folds the cape and reduces spark emission')
	if visual: await capture_character(game,'supreme-roll',Vector3(3,2,5))
	game.paused = true
	await frames(2)
	clock_before = fx.clock
	await frames(10)
	check(fx.clock == clock_before and fx.particles.speed_scale == 0,'Pause freezes shader time and GPU particles')
	game.paused = false
	game.player.drive = Vector2.ZERO
	game.player.roll_left = 0
	await frames(45)
	check(fx.fold < .05 and fx.particles.speed_scale == 1,'Cape unfolds and particles resume')
	if visual:
		game.player.position = Vector3(-20,0,30)
		game.player.reset_physics_interpolation()
		await frames(5)
		await capture_character(game,'supreme-island-front',Vector3(3,1.9,5))
		await capture_character(game,'supreme-island-back',Vector3(-3,2,-5))
	game.player.set_skin('classic')
	await frames(2)
	check(not is_instance_valid(fx),'Changing to a basic skin removes all supreme effects')
	game.player.set_skin('mecha')
	game.join_race()
	await frames(5)
	check(game.player.model.get_node_or_null('SkinAccessories/SupremeEffects') != null,'Effects survive race transition with the equipped skin')
	game.enter_island()
	game.queue_free()
	await process_frame
	print('SUPREME EFFECTS: ', 'PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
func capture_character(game, filename: String, offset: Vector3):
	var old_process: bool = game.is_processing()
	game.set_process(false)
	game.camera.position = game.player.position+offset
	game.camera.look_at(game.player.position+Vector3(0,1,0))
	game.camera.fov = 35
	await process_frame
	await game.screenshot(filename)
	game.set_process(old_process)
