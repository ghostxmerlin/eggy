extends Node

const LEVEL_DB := -12.0
const FADE_SECONDS := 1.2
var tracks: Dictionary = {}
var theme := ''
var transition: Tween
var voice_duck := false
var duck_db := 0.0
var mix_bus: StringName

func _ready() -> void:
	mix_bus = StringName('PartyMusic'+str(get_instance_id()))
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count-1,mix_bus)
	for key in ['island', 'race']:
		var player := AudioStreamPlayer.new()
		player.name = key.capitalize() + 'Music'
		player.bus = mix_bus
		var stream: AudioStreamOggVorbis = load('res://assets/audio/bgm_' + key + '.ogg')
		stream.loop = true
		player.stream = stream
		player.volume_linear = 0.0
		add_child(player)
		tracks[key] = player

func set_voice_duck(speaking: bool) -> void:
	voice_duck = speaking

func _process(delta: float) -> void:
	duck_db = lerpf(duck_db,-7.0 if voice_duck else 0.0,1-exp(-delta*(16 if voice_duck else 4)))
	var index := AudioServer.get_bus_index(mix_bus)
	if index >= 0: AudioServer.set_bus_volume_db(index,duck_db)

func _exit_tree() -> void:
	var index := AudioServer.get_bus_index(mix_bus)
	if index > 0: AudioServer.remove_bus(index)

func play_theme(next: String) -> void:
	if next == theme: return
	theme = next
	if transition: transition.kill()
	transition = create_tween().set_parallel(true)
	for key in tracks:
		var player: AudioStreamPlayer = tracks[key]
		if key == theme:
			if not player.playing: player.play()
			transition.tween_property(player, 'volume_linear', db_to_linear(LEVEL_DB), FADE_SECONDS)
		else:
			transition.tween_property(player, 'volume_linear', 0.0, FADE_SECONDS)
	# Killing the previous tween also cancels its pending stop callback on rapid joins.
	transition.chain().tween_callback(stop_inactive)

func stop_inactive() -> void:
	for key in tracks:
		if key != theme: tracks[key].stop()
