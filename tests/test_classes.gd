extends SceneTree
const Catalog = preload('res://scripts/class_catalog.gd')
var game: Node
var failures: Array[String] = []
var visual := false
var cues := {}
func check(ok: bool, message: String):
	if not ok:
		failures.append(message)
		print('FAIL: ',message)
func frames(count: int):
	for i in range(count):
		await physics_frame
		if visual and is_instance_valid(game): game.hud.queue_redraw()
func setup_pair(id: String, distance := 2.0, enemy := 'warrior'):
	game.duel.phase = 'fighting'
	game.duel.elapsed = 0
	game.duel.selected_class = Catalog.index(id)
	game.duel.opponent_class = Catalog.index(enemy)
	game.screen = 'duel'
	game.duel.health = {0:100,1:100}
	game.duel.ai_enabled = false
	game.paused = false
	game.player.skills.career.configure(id,[1,1,1])
	game.duel.opponent.skills.career.configure(enemy,[1,1,1])
	game.player.reset_to_start(Vector3(0,.12,3))
	game.duel.opponent.reset_to_start(Vector3(0,.12,3-distance))
	for actor in game.racers:
		actor.active = true
		actor.external_control = true
	game.camera_yaw = 0
	if visual:
		game.set_process(false)
		game.camera.position = Vector3(5,6,12)
		game.camera.look_at(Vector3(0,1,0))
	game.duel.opponent.pivot.rotation.y = 0
	await frames(18)
func capture(name: String):
	if visual:
		await game.screenshot(name)
func _initialize(): call_deferred('run')
func run():
	visual = '--visual' in OS.get_cmdline_user_args()
	var path := 'user://test-classes-isolated.cfg'
	DirAccess.remove_absolute(path+'.career')
	game = load('res://main.tscn').instantiate()
	game.skin_save_path = path
	root.add_child(game)
	await frames(30)
	game.feedback.cue_played.connect(func(cue,_id): cues[cue] = cues.get(cue,0)+1)
	game.ui_action('duel_room')
	check(game.screen == 'career','Uncreated character enters career setup before duel')
	game.class_room.choose(3)
	await capture('classes-creation')
	game.class_room.confirm()
	check(game.class_profile.class_id == 'hunter' and game.screen == 'duel_lobby','Create persistent hunter and return to duel lobby')
	check(game.class_profile.save('mage',[0,0,0]) != OK,'Profession cannot be changed by talent save')
	var restored = preload('res://scripts/class_profile.gd').new(path+'.career')
	check(restored.class_id == 'hunter','Profession survives reload')
	game.duel.begin()
	await frames(190)
	var p = game.player
	var enemy = game.duel.opponent
	for career_id in Catalog.IDS:
		for slot in range(1,6):
			var id: String = Catalog.skill(career_id,slot)[0]
			var distance := 2.0
			if id in ['charge','shadowstep']: distance = 5
			if id in ['frostbolt','lance','arcane','aimed']: distance = 7
			await setup_pair(career_id,distance)
			if id in ['kidney','eviscerate']: p.skills.career.combo = 3
			check(p.skills.use_skill(slot),'Cast '+id)
			check(not p.skills.use_skill(slot),'Cooldown prevents repeat '+id)
			if id == 'trap': enemy.position = Vector3(0,.12,.7)
			if id in ['frostbolt','aimed']:
				check(game.duel.health[1] == 100,'Cast does not damage early '+id)
				await frames(20)
				check(game.duel.health[1] == 100,'Windup remains non-damaging '+id)
				await capture('classes-cast-'+id)
				await frames(65)
			elif id == 'storm': await frames(105)
			else: await frames(26 if id in ['mortal','sinister','eviscerate','raptor'] else 42)
			var career = p.skills.career
			var other = enemy.skills.career
			if id in ['mortal','storm','charge','frostbolt','lance','nova','sinister','eviscerate','arcane','raptor','aimed']:
				check(game.duel.health[1] < 100,'Actual hit damages '+id)
			if id == 'sinister': check(career.combo == 1,'Hit awards one combo point')
			if id == 'eviscerate': check(career.combo == 0 and game.duel.health[1] == 68,'Finisher consumes combo points for damage')
			if id == 'shout': check(enemy.skills.fear_left > 0,'Fear is active')
			if id == 'nova': check(other.states.has('root'),'Nova roots without full stun')
			if id == 'kidney': check(other.states.has('stun'),'Kidney displays stun')
			if id == 'trap': check(other.states.has('trap'),'Trap triggers on actual proximity')
			if id == 'reflect': check(career.states.has('reflect'),'Reflect buff active')
			if id == 'block': check(career.states.has('block') and not p.skills.use_skill(1),'Ice block blocks own attacks')
			if id == 'stealth': check(career.states.has('stealth') and not other.can_target(p,12),'Stealth hides from AI targeting')
			if id in ['blink','disengage','shadowstep']: check(absf(p.position.z-3) > 2,'Mobility changes position '+id)
			if id in ['shout','nova','kidney','trap','reflect','block','stealth','raptor','mortal']:
				await capture('classes-'+id)
			print('CLASS SKILL ',id,' hp=',game.duel.health,' statuses=',other.states)
	# Projectile collision must respect scenery and miss an off-axis target.
	await setup_pair('hunter',7)
	enemy.position.x = 4
	p.skills.use_skill(1)
	await frames(90)
	check(game.duel.health[1] == 100,'Off-axis arrow misses')
	await setup_pair('mage',7)
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3,4,.3)
	collider.shape = box
	wall.add_child(collider)
	game.add_child(wall)
	wall.position = Vector3(0,1,0)
	await frames(3)
	p.skills.use_skill(1)
	await frames(100)
	check(game.duel.health[1] == 100,'Wall blocks projectile')
	var start: Vector3 = p.position
	p.skills.use_skill(4)
	check(p.position.z > .6,'Blink cannot cross wall')
	wall.queue_free()
	await frames(3)
	await setup_pair('mage',7)
	enemy.skills.use_skill(5)
	p.skills.use_skill(1)
	await frames(80)
	check(game.duel.health[1] == 100 and game.duel.health[0] < 100,'Warrior reflects actual frost projectile')
	await setup_pair('hunter',7,'mage')
	enemy.skills.use_skill(5)
	p.skills.use_skill(1)
	await frames(30)
	check(game.duel.health[1] == 100,'Ice block prevents actual arrow damage')
	await setup_pair('mage',2)
	p.skills.use_skill(3)
	var hp: int = game.duel.health[1]
	p.skills.use_skill(2)
	await frames(18)
	check(hp-game.duel.health[1] == 26,'Ice lance deals double damage to rooted target')
	check(not p.skills.career.apply_control(enemy,'stun',2),'Control grace prevents chained lockout')
	await setup_pair('hunter',7)
	p.skills.use_skill(5)
	p.drive = Vector2(1,0)
	await frames(85)
	check(game.duel.health[1] == 100 and p.skills.career.pending.is_empty(),'Moving interrupts aimed shot')
	await setup_pair('mage',7)
	p.skills.use_skill(1)
	game.toggle_pause()
	var cast_time: float = p.skills.career.pending.time
	await frames(20)
	check(p.skills.career.pending.time == cast_time and game.duel.health[1] == 100,'Pause freezes cast and damage')
	game.toggle_pause()
	await frames(100)
	check(game.duel.health[1] < 100,'Cast resumes after pause')
	await setup_pair('hunter',8,'rogue')
	enemy.skills.use_skill(5)
	await frames(3)
	check(enemy.skills.career.get_meta('ghost_alpha') == 1.0 and not enemy.skills.career.fx.label.visible,'Enemy stealth conceals body and world label')
	p.skills.career.deal(enemy,1,'arcane')
	await frames(3)
	check(enemy.skills.career.get_meta('ghost_alpha') == 0.0,'Damage reveals stealthed enemy')
	await setup_pair('hunter',8,'mage')
	enemy.skills.use_skill(5)
	enemy.skills.apply_freeze()
	enemy.skills.apply_fear(p.position)
	check(enemy.skills.frozen_left == 0 and enemy.skills.fear_left == 0,'Ice block also rejects legacy crowd control')
	await setup_pair('hunter',8)
	enemy.position.x = 4
	p.skills.use_skill(1)
	await frames(2)
	check(not p.skills.career.missiles.is_empty(),'Live missile available for pause check')
	if not p.skills.career.missiles.is_empty():
		var shot: Dictionary = p.skills.career.missiles[0]
		game.toggle_pause()
		var location: Vector3 = shot.node.position
		await frames(4)
		check(shot.node.position == location,'Paused projectile does not move')
		for child in shot.node.get_children():
			if child is GPUParticles3D: check(child.speed_scale == 0,'GPU trail freezes during pause')
		game.toggle_pause()
		await frames(4)
		for child in shot.node.get_children():
			if child is GPUParticles3D: check(child.speed_scale == 1,'GPU trail resumes after pause')
	# Every profession's bot must be able to finish a passive opponent using skills.
	for id in Catalog.IDS:
		await setup_pair('warrior',8,id)
		game.duel.ai_enabled = true
		for i in range(6000):
			await frames(1)
			if game.duel.phase == 'ended': break
		check(game.duel.health[0] == 0 and game.duel.winner == 1,'Bot can win as '+id)
		print('CLASS AI ',id,' elapsed=',game.duel.elapsed,' hp=',game.duel.health)
	game.enter_island()
	game.player.skills.career.configure(game.class_profile.class_id,game.class_profile.talents)
	game.class_room.open()
	game.class_room.talent(0,1)
	game.class_room.talent(2,1)
	await capture('classes-talents')
	game.class_room.confirm()
	restored = preload('res://scripts/class_profile.gd').new(path+'.career')
	check(restored.class_id == 'hunter' and restored.talents == [1,0,1],'Talents persist without changing profession')
	check(is_equal_approx(game.player.skills.career.duration(1),1.64),'Talent changes actual skill cooldown')
	if visual:
		if game.music.transition: game.music.transition.kill()
		for track in game.music.tracks.values(): track.stop()
		var capture_audio := AudioEffectCapture.new()
		capture_audio.buffer_length = 1.0
		AudioServer.add_bus_effect(0,capture_audio)
		for cue in game.feedback.streams:
			if not cue.begins_with('class_'): continue
			game.feedback.reset()
			capture_audio.clear_buffer()
			check(game.feedback.play(cue,game.player),'Native mixer starts '+cue)
			await frames(12)
			var peak := 0.0
			for sample in capture_audio.get_buffer(capture_audio.get_frames_available()): peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
			check(peak > .005 and peak < 1,'Native audible unclipped '+cue)
			print('CLASS MIX ',cue,' peak=',peak)
		AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	game.join_race()
	check(game.racers.size() == 32 and game.player.skills.career.class_id == 'hunter','Same profession follows player into race')
	for actor in game.racers: check(not actor.skills.career.enabled(),'Light race suspends professions')
	game.enter_island()
	for career_id in Catalog.IDS:
		for data in Catalog.SKILLS[Catalog.index(career_id)]: check(cues.has('class_'+data[0]),'Audio cue reached playback '+data[0])
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path+'.career')
	DirAccess.remove_absolute(path)
	print('CLASSES TEST: ', 'PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
