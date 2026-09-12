extends SceneTree

var failures: Array[String] = []
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func _initialize(): call_deferred('run')
func run():
	check(ResourceLoader.exists('res://scripts/skin_catalog.gd'), 'Skin catalogue is available')
	check(ResourceLoader.exists('res://scripts/skin_store.gd'), 'Skin selection can be saved')
	if not failures.is_empty():
		print('SKINS: FAIL ', failures)
		quit(1)
		return
	var catalog = load('res://scripts/skin_catalog.gd')
	var storage = load('res://scripts/skin_store.gd')
	var path := 'user://test-skins-isolated.cfg'
	DirAccess.remove_absolute(path)
	var store = storage.new(path)
	check(store.load_skin() == 'classic', 'Fresh profile starts with classic yellow')
	check(store.save_skin('mint') == OK, 'Skin can be saved')
	check(storage.new(path).load_skin() == 'mint', 'A new session restores saved selection')
	check(store.save_skin('unknown') == ERR_INVALID_PARAMETER, 'Unknown skin cannot replace selection')
	check(storage.new(path).load_skin() == 'mint', 'Invalid selection does not overwrite saved skin')
	var cfg := ConfigFile.new()
	cfg.set_value('appearance','skin','retired_skin')
	cfg.save(path)
	check(storage.new(path).load_skin() == 'classic', 'Retired skin falls back safely')
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string('not a valid configuration [')
	file.close()
	check(storage.new(path).load_skin() == 'classic', 'Damaged profile falls back safely')
	var model_scene = load('res://assets/models/racer.glb')
	var first = model_scene.instantiate()
	var second = model_scene.instantiate()
	root.add_child(first)
	root.add_child(second)
	catalog.apply(first,'classic')
	catalog.apply(second,'mint')
	var body = first.find_child('Body',true,false)
	var other_body = second.find_child('Body',true,false)
	var found_shell := false
	for i in range(body.mesh.get_surface_count()):
		if body.mesh.surface_get_material(i).resource_name == 'Shell':
			found_shell = true
			check(body.get_active_material(i).albedo_color != other_body.get_active_material(i).albedo_color, 'Player and NPC retain independent shell colours')
	check(found_shell,'Model exposes a recolourable shell material')
	for skin in catalog.SKINS:
		catalog.apply(first,skin.id)
		check(first.get_node_or_null('SkinAccessories') != null,'Skin has one replaceable accessory root')
	check(first.get_children().filter(func(n): return n.name == 'SkinAccessories').size() == 1,'Repeated switching does not accumulate accessories')
	first.queue_free()
	second.queue_free()
	DirAccess.remove_absolute(path)
	await process_frame
	print('SKINS: ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	quit(0 if failures.is_empty() else 1)
