extends 'res://tests/test_gacha_ui.gd'
const Catalog = preload('res://scripts/skin_catalog.gd')
const Shapes = preload('res://scripts/outfit_models.gd')

func run():
	visual = '--visual' in OS.get_cmdline_user_args()
	var game = load('res://main.tscn').instantiate()
	game.skin_save_path = 'user://test-presentation-isolated.cfg'
	DirAccess.remove_absolute(game.skin_save_path)
	root.add_child(game)
	await frames(45)
	game.skin_store.credit('+50000')
	game.gacha.open()
	game.gacha.select_skin('mecha')
	for angle in [0.0,PI/2,PI,-.5]:
		game.gacha.preview.rotation.y = angle
		await frames(8)
		if visual: await game.screenshot('knight-structure-'+str(roundi(angle*100)))
	# Cover actual walking and rolling animation pivots; the connector endpoint must
	# follow the animated limb every time, not only the rest pose in the wardrobe.
	game.gacha.close()
	game.player.set_skin('mecha')
	game.player.set_physics_process(false)
	for phase in [0.0,PI/2,PI,PI*1.5]:
		game.player.roll_left = 1.0 if phase > PI else 0.0
		game.player.velocity = Vector3(0,0,-8)
		game.player.bob = phase
		game.player.animate(.016)
		var rig = game.player.model.get_node('SkinAccessories/OutfitRig')
		check(rig.links.size() == 4,'All four animated limbs have torso connections')
		for link in rig.links:
			var end: Vector3 = rig.to_local(link.limb.to_global(link.offset))
			var mid: Vector3 = (end+link.anchor)*.5
			check(link.strut.position.distance_to(mid) < .00001,'Joint bridge tracks animated limb without a one-frame gap')
	game.player.velocity = Vector3.ZERO
	game.player.roll_left = 0.0
	game.player.animate(.016)
	game.player.set_physics_process(true)
	await frames(15)
	game.gacha.open()
	game.skin_store.pity = 49
	game.skin_store.rng.seed = 42
	var draws: int = game.skin_store.total_draws
	game.gacha.pull(10)
	var after: int = game.skin_store.coins
	check(game.gacha.reveal_phase == 'charge' and game.gacha.busy,'Successful purchase starts capsule charge')
	check(game.skin_store.total_draws == draws+10,'Rewards commit before animation')
	var restored = load('res://scripts/skin_store.gd').new(game.skin_save_path)
	restored.load_skin()
	check(restored.coins == after and restored.total_draws == draws+10,'Interrupting animation cannot lose committed rewards')
	await frames(30)
	if visual: await game.screenshot('gacha-charge')
	await frames(35)
	check(game.gacha.reveal_phase == 'opening','Charge advances to shell opening')
	if visual: await game.screenshot('gacha-opening')
	await frames(35)
	check(game.gacha.reveal_phase == 'hero','Prize has a dedicated hero reveal')
	if visual: await game.screenshot('gacha-hero')
	await press(KEY_ESCAPE)
	check(game.gacha.reveal_phase == 'cards','Escape skips to the same purchased results')
	for i in range(120):
		await frames(1)
		if not game.gacha.busy: break
	check(game.skin_store.coins == after and game.skin_store.total_draws == draws+10,'Skip never rerolls or repurchases')
	if visual: await game.screenshot('gacha-results-polished')
	game.gacha.dismiss_rewards()
	game.gacha.pull(1)
	await frames(15)
	game.gacha.finish_reveal()
	await frames(50)
	check(game.gacha.result_cards.size() == 1,'Single draw uses one large result card')
	if visual: await game.screenshot('gacha-single-polished')
	game.gacha.dismiss_rewards()
	game.gacha.pull(1)
	await frames(5)
	game.enter_island()
	await frames(10)
	check(not game.gacha.visible and not game.paused and not is_instance_valid(game.gacha.effects),'Scene transition stops VFX, sound and pending callbacks')
	# Concave plate front + bevels + back form a watertight mesh.
	var holder := Node3D.new()
	root.add_child(holder)
	Shapes.plate(holder,[Vector2(-1,1),Vector2(0,.4),Vector2(1,1),Vector2(.6,-1),Vector2(-.6,-1)],.5,.2,Shapes.mat(Color.WHITE))
	var mesh: Mesh = holder.get_child(0).mesh
	var data := mesh.surface_get_arrays(0)
	check(data[Mesh.ARRAY_NORMAL][0].dot(Vector3.BACK) > .99,'Front plate normals point toward the face, not into the helmet')
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in range(vertices.size()): indices.append(i)
	var edges := {}
	for i in range(0,indices.size(),3):
		for j in range(3):
			var a := str(vertices[indices[i+j]].snapped(Vector3.ONE*.00001))
			var b := str(vertices[indices[i+(j+1)%3]].snapped(Vector3.ONE*.00001))
			var key: String = a+'|'+b if a < b else b+'|'+a
			edges[key] = edges.get(key,0)+1
	check(edges.values().all(func(count): return count == 2),'Every armor edge has exactly two incident triangles; no open backs')
	holder.queue_free()
	# Verify batching preserves lighting under non-uniform scale and reduces surfaces.
	var batch := Node3D.new()
	root.add_child(batch)
	var finish := Shapes.mat(Color.WHITE)
	var source := Shapes.ball(batch,Vector3.ZERO,Vector3(.2,.7,.4),finish)
	source.rotation = Vector3(.2,.4,.1)
	var normal: Vector3 = source.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][30]
	var expected := (source.basis.inverse().transposed()*normal).normalized()
	Shapes.box(batch,Vector3.ONE,Vector3.ONE,finish)
	Shapes.compact(batch)
	var joined: Mesh = batch.get_child(0).mesh
	check(batch.get_child_count() == 1 and joined.get_surface_count() == 1,'Two static meshes sharing material become one draw surface')
	# ArrayMesh packs normals; allow sub-degree quantization, not lighting distortion.
	var normal_error: float = joined.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][30].distance_to(expected)
	print('BATCH NORMAL ERROR: ',normal_error)
	check(normal_error < .001,'Batching preserves inverse-transpose normals under non-uniform scale')
	batch.queue_free()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute('user://test-presentation-isolated.cfg')
	print('GACHA PRESENTATION: ', 'PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
