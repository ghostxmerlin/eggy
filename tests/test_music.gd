extends SceneTree

var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize(): call_deferred('run')
func settle(): await create_timer(1.5).timeout
func run():
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, capture)
	var game = load('res://main.tscn').instantiate()
	root.add_child(game)
	await process_frame
	var music = game.get_node_or_null('BackgroundMusic')
	if music == null:
		print('MUSIC TEST: FAIL missing background music')
		quit(1)
		return
	await settle()
	check(music.tracks['island'].playing, 'Island music starts on launch')
	game.start_race()
	await settle()
	check(music.tracks['race'].playing and not music.tracks['island'].playing, 'Race replaces island music')
	game.enter_island()
	game.start_race()
	game.enter_island()
	await settle()
	check(music.tracks['island'].playing and not music.tracks['race'].playing, 'Rapid transitions leave only correct track playing')
	for track in music.tracks.values():
		check(track.stream.loop, 'Music loops')
		check(track.stream.get_length() > 45, 'Track contains a full musical phrase')
	for theme in ['island', 'race']:
		music.play_theme(theme)
		await settle()
		var track: AudioStreamPlayer = music.tracks[theme]
		track.seek(track.stream.get_length() - 0.2)
		await create_timer(0.65).timeout
		check(track.playing and track.get_playback_position() < 2, theme + ' plays through the loop boundary')
		capture.clear_buffer()
		await create_timer(0.08).timeout
		var peak := 0.0
		for sample in capture.get_buffer(capture.get_frames_available()):
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		print('MUSIC OUTPUT ', theme, ' peak=', peak)
		if DisplayServer.get_name() != 'headless':
			check(peak > 0.005, theme + ' produces audible output in the native audio mixer')
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	print('MUSIC TEST: ', 'PASS' if failures.is_empty() else 'FAIL', failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
