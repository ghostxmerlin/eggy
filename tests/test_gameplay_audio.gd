extends SceneTree
var failures: Array[String] = []
var events: Array = []
var lines: Array = []
var game
var native := false
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func frames(count: int):
	for i in range(count): await physics_frame
func count_cue(cue: String) -> int:
	return events.filter(func(e): return e[0] == cue and e[1] == 0).size()
func _initialize(): call_deferred('run')
func run():
	native = DisplayServer.get_name() != 'headless'
	game = load('res://main.tscn').instantiate()
	game.skin_save_path = 'user://test-action-audio-isolated.cfg'
	DirAccess.remove_absolute(game.skin_save_path)
	root.add_child(game)
	game.set_process_input(false)
	await frames(45)
	var audio = game.feedback
	audio.cue_played.connect(func(cue,id): events.append([cue,id]))
	audio.line_spoken.connect(func(id): lines.append(id))
	var player = game.player
	player.external_control = true
	var ai = get_nodes_in_group('combatants').filter(func(r): return r != player)
	for target in ai: target.set_physics_process(false)
	player.reset_to_start(Vector3(0,.1,26))
	player.active = true
	await frames(25)
	var before: int = count_cue('jump')
	player.request_jump()
	await frames(3)
	check(count_cue('jump') == before+1,'One real takeoff produces one jump cue')
	player.request_jump()
	await frames(12)
	check(count_cue('jump') == before+1,'Airborne jump requests are silent')
	await frames(65)
	check(count_cue('land') >= 1,'Real landing produces its own cue')
	var lands: int = count_cue('land')
	await frames(25)
	check(count_cue('land') == lands,'Standing on the floor does not repeat landing sounds')
	for slot in range(1,6):
		player.skills.reset(true)
		player.roll_cooldown = 0
		player.reset_to_start(Vector3(0,.1,26))
		player.active = true
		await frames(20)
		check(player.skills.use_skill(slot),'Skill activates for audio integration '+str(slot))
		check(not player.skills.use_skill(slot),'Cooldown rejects repeated skill '+str(slot))
		await frames(40)
	for cue in ['roll','dive','swing','freeze','fear']:
		check(count_cue(cue) > 0,'Distinct skill sound: '+cue)
	player.reset_to_start(Vector3(0,.1,26))
	player.active = true
	ai[0].skills.reset(true)
	ai[0].position = Vector3(0,.1,24)
	await frames(20)
	player.skills.use_skill(3)
	await frames(30)
	check(count_cue('hit') > 0,'Actual fish contact produces a hit sound separate from its swing')
	ai[0].position = Vector3(-30,.1,30)
	player.skills.reset(true)
	player.reset_to_start(Vector3(0,.1,26))
	player.active = true
	await frames(20)
	player.skills.receive_impulse(Vector3(0,5,9),.5)
	check(count_cue('knockdown') > 0,'Strong knockback has a knockdown cue')
	await frames(35)
	player.skills.apply_freeze()
	await frames(125)
	check(count_cue('thaw') > 0,'Thaw plays on expiry, not on reset')
	# Actual wall contact, then sustained pressure: no sound every physics frame.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6,4,.3)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = Vector3(0,1,22)
	player.reset_to_start(Vector3(0,.1,25))
	player.active = true
	player.drive = Vector2(0,-1)
	await frames(55)
	check(count_cue('bump') > 0,'Physical wall collision triggers impact audio')
	before = count_cue('bump')
	await frames(30)
	check(count_cue('bump') <= before+1,'Pushing against a wall does not machine-gun collision audio')
	player.drive = Vector2.ZERO
	wall.queue_free()
	# Independent RNG, voice cooldown, no immediate repeats and pause cleanup.
	var race_rng: int = player.rng.state
	var gacha_rng: int = game.skin_store.rng.state
	audio.reset()
	audio.voice_wait = 0
	print('VOICE READY screen=',game.screen,' paused=',game.paused,' finished=',player.finished,' vehicle=',is_instance_valid(player.vehicle),' playing=',audio.voice.playing)
	check(audio.speak('hurry'),'Requested hurry line is an actual audio clip')
	check(audio.voice.stream != null and audio.voice.stream.get_length() > .4 and audio.subtitle.visible,'Speech has nonempty audio and matching subtitle')
	check(not audio.speak('hurry'),'Speech cannot overlap or bypass cooldown')
	await frames(10)
	check(game.music.voice_duck,'Music ducks during dialogue')
	if native: await game.screenshot('character-voice-subtitle')
	game.toggle_pause()
	await frames(2)
	check(audio.voice.stream_paused and not audio.subtitle.visible,'Pause freezes speech and hides its subtitle')
	var wait_before: float = audio.voice_wait
	await frames(10)
	check(is_equal_approx(audio.voice_wait,wait_before),'Pause does not consume chatter cooldown')
	game.toggle_pause()
	await frames(2)
	check(not audio.voice.stream_paused,'Unpause resumes speech')
	audio.voice.stop()
	audio.voice_wait = 0
	check(audio.speak('hurry') and lines[-1] != lines[-2],'Consecutive hurry lines cannot repeat')
	check(player.rng.state == race_rng and game.skin_store.rng.state == gacha_rng,'Audio RNG is isolated from gameplay and gacha')
	audio.reset()
	var target = ai[0]
	target.position = player.position+Vector3(100,0,0)
	check(not audio.play('jump',target),'Distant NPC audio is culled')
	target.position = player.position+Vector3(2,0,0)
	check(audio.play('jump',target),'Nearby NPC has spatial audio')
	check(not audio.play('jump',target),'Same-frame duplicate NPC cues are suppressed')
	# Capture the actual native mixer with BGM stopped; distinguish playback from loading.
	if game.music.transition: game.music.transition.kill()
	for track in game.music.tracks.values(): track.stop()
	audio.reset()
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0,capture)
	for cue in audio.CUES:
		audio.reset()
		capture.clear_buffer()
		check(audio.play(cue,player),'Cue can enter the mixer: '+cue)
		await create_timer(.22).timeout
		var peak := peak_of(capture)
		print('ACTION MIX ',cue,' peak=',peak)
		if native: check(peak > .005 and peak < 1.0,'Audible unclipped native cue: '+cue)
	audio.reset()
	audio.voice_wait = 0
	capture.clear_buffer()
	audio.speak('hurry')
	await create_timer(.5).timeout
	var voice_peak := peak_of(capture)
	print('VOICE MIX peak=',voice_peak)
	if native: check(voice_peak > .01 and voice_peak < 1.0,'Synthesized speech reaches the native mixer')
	game.enter_island()
	check(not audio.voice.playing and not audio.subtitle.visible,'Scene transition cancels old speech')
	check(audio.local_channels.all(func(c): return not c.playing) and audio.world_channels.all(func(c): return not c.playing),'Scene transition clears all action channels')
	game.join_race()
	await frames(195)
	check(audio.LINES[lines[-1]][0] == 'start','Countdown completion triggers a start line')
	audio.voice.stop()
	audio.voice_wait = 0
	game.rules.elapsed = 121.0
	await frames(3)
	check(audio.urgent_spoken and audio.LINES[lines[-1]][0] == 'hurry','Final thirty seconds trigger urgency')
	var spoken: int = lines.size()
	audio.voice.stop()
	audio.voice_wait = 0
	await frames(3)
	check(lines.size() == spoken,'Deadline line occurs only once per race')
	game.cross_finish(game.player)
	check(audio.LINES[lines[-1]][0] == 'win','Actual finish event produces a celebration')
	game.enter_island()
	audio.reset()
	audio.voice_wait = 0
	audio.chatter_wait = 0
	game.player.velocity = Vector3(0,0,-4)
	audio._process(.016)
	check(audio.LINES[lines[-1]][0] == 'move','Moving around the island triggers occasional chatter')
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute('user://test-action-audio-isolated.cfg')
	print('GAMEPLAY AUDIO: ', 'PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
func peak_of(capture: AudioEffectCapture) -> float:
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()): peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	return peak
