extends Node

const LEVEL_DB := -12.0
const FADE_SECONDS := 1.2
var tracks: Dictionary = {}
var theme := ''
var transition: Tween

func _ready() -> void:
	for key in ['island', 'race']:
		var player := AudioStreamPlayer.new()
		player.name = key.capitalize() + 'Music'
		var stream: AudioStreamOggVorbis = load('res://assets/audio/bgm_' + key + '.ogg')
		stream.loop = true
		player.stream = stream
		player.volume_linear = 0.0
		add_child(player)
		tracks[key] = player

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
