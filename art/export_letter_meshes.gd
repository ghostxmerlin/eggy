extends SceneTree
func _initialize(): call_deferred('run')
func run():
	var sculpture := Node3D.new()
	root.add_child(sculpture)
	var entries = [['宜',-5.1,4.2,0,'#ff9565'],['之',-1.7,4.2,0,'#38bcae'],['有',1.7,4.2,0,'#ee789d'],['之',5.1,4.2,0,'#ffcf65'],['派',-1.8,1.25,.5,'#147c91'],['对',1.8,1.25,.5,'#ff9565']]
	for entry in entries:
		var mesh := TextMesh.new()
		mesh.font = load('res://assets/fonts/CloudSans-Heavy.ttf')
		mesh.font_size = 128
		mesh.pixel_size = 3.1/128
		mesh.depth = .55
		mesh.text = entry[0]
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(entry[4])
		material.roughness = .38
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = material
		sculpture.add_child(visual)
		visual.owner = sculpture
		visual.position = Vector3(entry[1],entry[2]-mesh.get_aabb().position.y,entry[3])
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(sculpture,state)
	if error == OK: error = document.write_to_filesystem(state,'res://art/island_letters_raw.glb')
	print('LETTERS EXPORT ',error)
	quit(error)
