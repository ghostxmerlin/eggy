extends RefCounted
const Catalog = preload('res://scripts/class_catalog.gd')
var path: String
var class_id := ''
var talents := [0,0,0]
func _init(save_path: String):
	path = save_path
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK: return
	var value = cfg.get_value('character','class','')
	if value is String and value in Catalog.IDS: class_id = value
	var choices = cfg.get_value('character','talents',[0,0,0])
	if choices is Array and choices.size() == 3:
		for i in range(3):
			if choices[i] is int and choices[i] in [0,1]: talents[i] = choices[i]
func save(id: String, choices: Array) -> Error:
	if id not in Catalog.IDS or (class_id != '' and id != class_id): return ERR_INVALID_PARAMETER
	if choices.size() != 3: return ERR_INVALID_PARAMETER
	for value in choices:
		if not value is int or value not in [0,1]: return ERR_INVALID_PARAMETER
	var cfg := ConfigFile.new()
	cfg.set_value('character','class',id)
	cfg.set_value('character','talents',choices)
	var error := cfg.save(path+'.tmp')
	if error == OK: error = DirAccess.rename_absolute(path+'.tmp',path)
	if error == OK:
		class_id = id
		talents = choices.duplicate()
	return error
