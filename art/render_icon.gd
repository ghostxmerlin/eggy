extends SceneTree
func _initialize():
	var image := Image.load_from_file('res://icon.svg')
	image.save_png('res://art/icon-512.png')
	quit()
