extends Node
const CLASSES := ['战士','法师','刺客','猎人']
const MAX_HEALTH := 100
const SWING_DAMAGE := 20
var game: Node3D
var selected_class := 0
var opponent_class := 1
var phase := 'idle'
var countdown := 3.0
var elapsed := 0.0
var health := {}
var hurt := {}
var winner := -1
var opponent: CharacterBody3D
var rng := RandomNumberGenerator.new()
var think_left := 0.0
var ai_enabled := true
var strafe_side := 1.0

func _ready() -> void:
	rng.randomize()

func in_arena() -> bool:
	return game.screen in ['duel','duel_result']

func open_room() -> void:
	if game.screen not in ['island','duel_result'] or is_instance_valid(game.player.vehicle): return
	if game.class_profile.class_id == '':
		game.class_room.open('duel')
		return
	selected_class = preload('res://scripts/class_catalog.gd').index(game.class_profile.class_id)
	game.close_modals()
	game.release_mouse_drive()
	game.feedback.reset()
	game.paused = true
	game.screen = 'duel_lobby'
	phase = 'selection'
	game.hud.queue_redraw()

func select_class(index: int) -> void:
	if phase == 'selection' and index >= 0 and index < CLASSES.size():
		selected_class = preload('res://scripts/class_catalog.gd').index(game.class_profile.class_id)
		game.hud.queue_redraw()

func begin() -> void:
	if game.class_profile.class_id == '': return
	if game.screen not in ['duel_lobby','duel','duel_result']: return
	game.close_modals()
	game.feedback.reset()
	game.items.clear()
	game.release_mouse_drive()
	game.player.leave_vehicle()
	for racer in game.racers:
		if racer != game.player:
			game.remove_child(racer)
			racer.queue_free()
	game.racers = [game.player]
	game.replace_world(preload('res://scripts/duel_arena.gd').new())
	game.in_island = false
	game.configure_render_scale()
	game.practice = false
	game.add_racer(1)
	opponent = game.racers[1]
	opponent.external_control = true
	opponent.ai_speed = game.player.SPEED
	opponent_class = rng.randi_range(0,CLASSES.size()-1)
	opponent.skills.career.configure(preload('res://scripts/class_catalog.gd').IDS[opponent_class],[1,1,1])
	selected_class = preload('res://scripts/class_catalog.gd').index(game.class_profile.class_id)
	opponent.set_skin(['royal','sky','berry','mint'][opponent_class])
	game.player.external_control = false
	game.player.reset_to_start(Vector3(0,.12,6))
	opponent.reset_to_start(Vector3(0,.12,-6))
	opponent.pivot.rotation.y = 0
	game.player.pivot.rotation.y = PI
	game.player.model.rotation = Vector3.ZERO
	game.camera_yaw = 0
	game.camera_pitch = 0
	game.camera.position = Vector3(0,9,17)
	game.camera.look_at(Vector3(0,1,0))
	game.camera.fov = 55
	game.autoplay = false
	game.confetti.emitting = false
	game.screen = 'duel'
	game.rules.phase = 'duel'
	game.paused = false
	game.toast_time = 0
	game.music.play_theme('race')
	phase = 'countdown'
	countdown = 3.0
	elapsed = 0
	winner = -1
	health = {0:MAX_HEALTH,1:MAX_HEALTH}
	hurt = {0:0.0,1:0.0}
	think_left = .45
	ai_enabled = true
	game.hud.queue_redraw()

func tick(delta: float) -> void:
	if game.paused: return
	for id in hurt: hurt[id] = maxf(0,hurt[id]-delta)
	if phase == 'countdown':
		var before := ceili(countdown)
		countdown = maxf(0,countdown-delta)
		if ceili(countdown) != before and countdown > 0: game.sound('tick')
		if countdown <= 0:
			phase = 'fighting'
			for racer in game.racers: racer.active = true
			game.sound('go')
		return
	if phase != 'fighting': return
	elapsed += delta
	if ai_enabled: drive_opponent(delta)

func drive_opponent(delta: float) -> void:
	var offset: Vector3 = game.player.position-opponent.position
	offset.y = 0
	var distance := offset.length()
	var direction := offset.normalized()
	var tangent := Vector3(-direction.z,0,direction.x)*strafe_side
	var kit = opponent.skills
	if kit.career.enabled():
		var ranged: bool = kit.career.class_id in ['mage','hunter']
		var advance: Vector3 = direction if distance > (7.0 if ranged else 2.1) else -direction if distance < (4.0 if ranged else 1.3) else Vector3.ZERO
		if kit.career.pending.get('id','') == 'aimed': advance = Vector3.ZERO
		if game.player.skills.career.states.has('stealth') and distance > 1.7: advance = tangent*.15
		opponent.drive = Vector2(advance.x,advance.z)
		opponent.pivot.rotation.y = atan2(direction.x,direction.z)
		kit.career.ai(delta)
		return
	var move := direction
	if distance < 1.65: move = -direction*.6+tangent*.4
	elif distance < 3.2 and kit.cooldown(3) > 1.0: move = tangent*.7-direction*.3
	opponent.drive = Vector2(move.x,move.z).limit_length()
	# Aim at the player even while circling; skills snapshot this direction on cast.
	opponent.pivot.rotation.y = atan2(direction.x,direction.z)
	think_left -= delta
	if think_left > 0 or kit.controlled() or kit.attack_left > 0: return
	think_left = rng.randf_range(.20,.38)
	if rng.randf() < .12: strafe_side *= -1
	if distance < 2.65 and kit.cooldown(3) <= 0:
		kit.use_skill(3)
	elif distance < 4.8 and kit.cooldown(3) < .8 and game.player.skills.frozen_left <= 0:
		kit.use_skill(4)
	elif distance < 3.0 and kit.cooldown(3) > 1.5:
		kit.use_skill(5)
	if game.player.skills.attack_left > .3 and distance < 3 and rng.randf() < .28:
		opponent.request_jump()

func register_hit(attacker, target) -> void:
	if phase != 'fighting' or game.paused or not in_arena(): return
	if attacker not in game.racers or target not in game.racers or attacker == target: return
	if not attacker.active or not target.active: return
	damage(target,SWING_DAMAGE)

func damage(target, amount: int) -> void:
	if phase != 'fighting' or game.paused or target not in game.racers or amount <= 0: return
	var id: int = target.racer_id
	health[id] = maxi(0,health[id]-amount)
	hurt[id] = .22
	game.hud.queue_redraw()
	if health[id] == 0: finish(1-id)

func finish(winner_id: int) -> void:
	if phase != 'fighting': return
	winner = winner_id
	phase = 'ended'
	game.screen = 'duel_result'
	game.release_mouse_drive()
	for racer in game.racers:
		racer.skills.reset()
		racer.active = false
		racer.drive = Vector2.ZERO
		racer.velocity = Vector3.ZERO
		racer.finished = racer.racer_id != winner
		if racer.finished: racer.roll_visual.rotation.z = -1.15
	game.sound('finish')
	game.hud.queue_redraw()

func fell(racer) -> void:
	if phase == 'fighting': damage(racer,MAX_HEALTH)

func clear() -> void:
	phase = 'idle'
	health.clear()
	hurt.clear()
	opponent = null
	winner = -1
