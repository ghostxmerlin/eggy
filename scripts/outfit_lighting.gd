extends RefCounted
static var studio: Sky

static func environment() -> Environment:
	if studio == null:
		studio = Sky.new()
		var material := ShaderMaterial.new()
		material.shader = preload('res://assets/shaders/outfit_studio.gdshader')
		studio.sky_material = material
	var settings := Environment.new()
	settings.sky = studio
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.background_mode = Environment.BG_COLOR
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = .35
	settings.tonemap_mode = Environment.TONE_MAPPER_ACES
	settings.tonemap_exposure = .8
	settings.glow_enabled = true
	settings.glow_intensity = .55
	return settings
