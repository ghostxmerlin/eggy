extends RefCounted

const Catalog = preload('res://scripts/skin_catalog.gd')
var path: String
var selected_id := 'classic'

func _init(save_path := 'user://appearance.cfg') -> void:
	path = save_path

func load_skin() -> String:
	selected_id = 'classic'
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var value = config.get_value('appearance','skin','classic')
		if value is String and Catalog.has_skin(value): selected_id = value
	return selected_id

func save_skin(id: String) -> Error:
	if not Catalog.has_skin(id): return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	config.set_value('appearance','skin',id)
	var error := config.save(path+'.tmp')
	if error != OK: return error
	error = DirAccess.rename_absolute(path+'.tmp',path)
	if error == OK: selected_id = id
	return error
