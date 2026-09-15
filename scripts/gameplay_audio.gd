extends Node
# Separate cosmetic RNG: audio must never alter race AI or gacha outcomes.
signal cue_played(cue: String, source_id: int)
signal line_spoken(id: String)
const CUES := ['jump','land','bump','knockdown','fall','roll','dive','swing','hit','freeze','thaw','fear','pickup','item']
const LINES := {
	'late': ['hurry','来不及了！'], 'faster': ['hurry','搞快点，搞快点！'],
	'go': ['start','冲呀，出发！'], 'ready': ['start','准备好了吗？我先走啦！'],
	'catch': ['move','嘿嘿，追不上我吧！'], 'ahead': ['move','向前冲，别停下！'],
	'fun': ['move','今天也要玩个痛快！'], 'steady': ['down','哎哟！稳住，稳住！'],
	'again': ['down','没关系，再来一次！'], 'watch': ['skill','看我的！'],
	'move': ['skill','让一让，我来啦！'], 'win': ['win','耶，我到终点啦！'],
	'nice': ['win','这把跑得真不错！'],
}
var game: Node
var rng := RandomNumberGenerator.new()
var streams := {}
var speech := {}
var local_channels: Array = []
var world_channels: Array = []
var voice: AudioStreamPlayer
var subtitle: Label3D
var recent_lines: Array = []
var cooldowns := {}
var clock := 0.0
var voice_wait := 8.0
var chatter_wait := 18.0
var blocked := false
var urgent_spoken := false

func _ready() -> void:
	rng.randomize()
	for cue in CUES: streams[cue] = load('res://assets/audio/actions/'+cue+'.wav')
	for cue in ['mortal','storm','shout','charge','reflect','frostbolt','lance','nova','blink','block','sinister','eviscerate','kidney','shadowstep','stealth','arcane','raptor','trap','disengage','aimed','stun','immune','freeze','thaw','impact_frost','impact_shadow','impact_arrow','impact_metal']:
		streams['class_'+cue] = load('res://assets/audio/classes/'+cue+'.wav')
	for id in LINES: speech[id] = load('res://assets/audio/voice/'+id+'.wav')
	for i in range(4):
		var channel := AudioStreamPlayer.new()
		add_child(channel)
		local_channels.append(channel)
	for i in range(6):
		var channel := AudioStreamPlayer3D.new()
		channel.unit_size = 10.0
		channel.max_distance = 42.0
		channel.max_db = -12
		add_child(channel)
		world_channels.append(channel)
	voice = AudioStreamPlayer.new()
	voice.volume_db = -2.0
	add_child(voice)
	subtitle = Label3D.new()
	subtitle.font = preload('res://assets/fonts/CloudSans-Heavy.ttf')
	subtitle.font_size = 36
	subtitle.pixel_size = .018
	subtitle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	subtitle.no_depth_test = true
	subtitle.outline_size = 7
	subtitle.modulate = Color('#fff7d9')
	game.player.add_child(subtitle)
	subtitle.position.y = 3.0
	subtitle.hide()
	voice.finished.connect(func(): subtitle.hide())

func play(cue: String, racer, strength := 1.0) -> bool:
	if not streams.has(cue) or game.paused or game.screen not in ['island','racing','duel']: return false
	if not is_instance_valid(racer) or not is_instance_valid(game.player): return false
	var own: bool = racer.is_player
	if not own and racer.global_position.distance_to(game.player.global_position) > 20: return false
	var key := str(racer.get_instance_id())+':'+cue
	if clock < cooldowns.get(key,0.0): return false
	# Nearby crowds cannot stack six identical jump/impact sounds in one frame.
	if not own and clock < cooldowns.get('crowd:'+cue,0.0): return false
	var channels: Array = local_channels if own else world_channels
	var channel = null
	for candidate in channels:
		if not candidate.playing or clock >= candidate.get_meta('available_at',0.0):
			channel = candidate
			break
	if channel == null: return false
	cooldowns[key] = clock+(.42 if cue in ['bump','knockdown'] else .12)
	if not own: cooldowns['crowd:'+cue] = clock+.16
	channel.stream = streams[cue]
	channel.pitch_scale = rng.randf_range(.94,1.07)
	channel.set_meta('available_at',clock+channel.stream.get_length()/channel.pitch_scale+.04)
	channel.volume_db = (-7.0 if own else -16.0)+linear_to_db(clampf(strength,.35,1.0))
	if not own: channel.global_position = racer.global_position+Vector3.UP
	channel.play()
	cue_played.emit(cue,racer.racer_id)
	return true

func event(cue: String, racer, strength := 1.0, reaction := false) -> void:
	play(cue,racer,strength)
	if racer.is_player:
		if reaction or cue in ['fall','knockdown']: speak('down',.65)
		elif cue in ['roll','dive','freeze','fear']: speak('skill',.22)

func movement(racer, floor_before: bool, incoming: Vector3) -> void:
	if not racer.active or racer.finished: return
	if not floor_before and racer.is_on_floor() and incoming.y < -2.0:
		event('knockdown' if incoming.y < -12 else 'land',racer,clampf(-incoming.y/10,.4,1))
	for i in range(racer.get_slide_collision_count()):
		var hit: KinematicCollision3D = racer.get_slide_collision(i)
		if absf(hit.get_normal().y) > .65: continue
		var speed: float = -(incoming-hit.get_collider_velocity()).dot(hit.get_normal())
		if speed > 2.5:
			play('bump',racer,clampf(speed/10,.4,1))
			break

func speak(context: String, chance := 1.0) -> bool:
	if game.paused or voice.playing or voice_wait > 0 or is_instance_valid(game.player.vehicle): return false
	if context == 'win':
		if not game.player.finished: return false
	elif game.screen not in ['island','racing','duel'] or game.player.finished: return false
	if rng.randf() > chance: return false
	var choices: Array = LINES.keys().filter(func(id): return LINES[id][0] == context and id not in recent_lines)
	if choices.is_empty(): choices = LINES.keys().filter(func(id): return LINES[id][0] == context and (recent_lines.is_empty() or id != recent_lines.back()))
	if choices.is_empty(): return false
	var id: String = choices[rng.randi_range(0,choices.size()-1)]
	voice.stream = speech[id]
	voice.pitch_scale = rng.randf_range(1.04,1.10)
	voice.play()
	subtitle.text = LINES[id][1]
	subtitle.show()
	recent_lines.append(id)
	if recent_lines.size() > 2: recent_lines.pop_front()
	voice_wait = voice.stream.get_length()+rng.randf_range(10,18)
	chatter_wait = rng.randf_range(18,30)
	line_spoken.emit(id)
	return true

func race_start() -> void:
	voice_wait = 0
	speak('start')

func finish() -> void:
	voice.stop()
	voice_wait = 0
	speak('win')

func reset() -> void:
	for channel in local_channels+world_channels: channel.stop()
	voice.stop()
	subtitle.hide()
	cooldowns.clear()
	voice_wait = 8
	chatter_wait = rng.randf_range(18,30)
	urgent_spoken = false
	game.music.set_voice_duck(false)

func _process(delta: float) -> void:
	if game.paused != blocked:
		blocked = game.paused
		for channel in local_channels+world_channels: channel.stream_paused = blocked
		voice.stream_paused = blocked
		subtitle.visible = voice.playing and not blocked
	game.music.set_voice_duck(voice.playing and not game.paused)
	if game.paused: return
	clock += delta
	voice_wait = maxf(0,voice_wait-delta)
	chatter_wait -= delta
	# Expire source IDs after sounds finish; repeated races keep this map bounded.
	if cooldowns.size() > 128:
		for key in cooldowns.keys():
			if cooldowns[key] < clock: cooldowns.erase(key)
	if not game.player.active or game.player.finished or is_instance_valid(game.player.vehicle): return
	if game.screen == 'racing' and game.rules.phase == 'racing' and not game.practice and game.rules.time_left() < 30 and not urgent_spoken:
		if speak('hurry'): urgent_spoken = true
	elif chatter_wait <= 0 and game.player.velocity.length() > 2:
		var context := 'hurry' if game.screen == 'racing' and game.player.position.z < -250 else 'move'
		if not speak(context): chatter_wait = 2.0
