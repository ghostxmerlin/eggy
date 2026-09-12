extends SceneTree
func _initialize(): call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	var env: Environment
	for child in game.get_children():
		if child is WorldEnvironment: env = child.environment
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.5
	env.tonemap_exposure = 1.05
	for i in range(150): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png('res://captures/filmic-preview.png')
	quit()
