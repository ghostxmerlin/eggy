extends SceneTree
func _initialize():
	var font = load('res://assets/fonts/NotoSansSC.ttf')
	print('FONT AXES ', font.get_supported_variation_list())
	quit()
