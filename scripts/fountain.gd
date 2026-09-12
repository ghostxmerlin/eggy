extends Node3D

# Continuous geometry is built once. Only water shading and secondary spray animate.
const SEGMENTS := 48
const SIDES := 10
var stream_material: ShaderMaterial
var pool_material: ShaderMaterial
var spray: MultiMesh

func _ready() -> void:
	stream_material = ShaderMaterial.new()
	stream_material.shader = preload('res://assets/shaders/fountain_stream.gdshader')
	pool_material = ShaderMaterial.new()
	pool_material.shader = preload('res://assets/shaders/fountain_pool.gdshader')
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var angle := TAU * i / 8.0
		var path := PackedVector3Array()
		for j in range(SEGMENTS + 1):
			var s := float(j) / SEGMENTS
			var radius := 0.70 + s * 3.10
			path.append(Vector3(cos(angle) * radius, 2.50 + 6.0 * s - 8.10 * s * s, sin(angle) * radius))
		append_tube(surface, path, 0.34, 0.25, Vector3(-sin(angle), 0, cos(angle)), 0.16)
	# A strong central jet, with a small crown flowing back into the upper bowl.
	var main_path := PackedVector3Array()
	for j in range(SEGMENTS + 1):
		var s := float(j) / SEGMENTS
		main_path.append(Vector3(0, 2.75 + 2.60 * s, 0))
	append_tube(surface, main_path, 0.30, 0.22, Vector3.RIGHT, 0.24)
	for i in range(6):
		var angle := TAU * i / 6.0
		var path := PackedVector3Array()
		for j in range(SEGMENTS + 1):
			var s := float(j) / SEGMENTS
			path.append(Vector3(cos(angle) * s * 1.24, 5.29 + 0.70 * s - 4.15 * s * s, sin(angle) * s * 1.24))
		append_tube(surface, path, 0.20, 0.15, Vector3(-sin(angle), 0, cos(angle)), 0.18)
	add_visual('ContinuousWaterJets', surface.commit(), stream_material)
	var pool := CylinderMesh.new()
	pool.top_radius = 4.4
	pool.bottom_radius = 4.4
	pool.height = 0.055
	pool.radial_segments = 96
	var basin := add_visual('RipplingWater', pool, pool_material)
	basin.position.y = 0.40
	var drop := SphereMesh.new()
	drop.radius = 0.065
	drop.height = 0.13
	drop.radial_segments = 8
	drop.rings = 4
	spray = MultiMesh.new()
	spray.transform_format = MultiMesh.TRANSFORM_3D
	spray.mesh = drop
	spray.instance_count = 48
	var splashes := MultiMeshInstance3D.new()
	splashes.name = 'LandingSpray'
	splashes.multimesh = spray
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color('#c5f6ff')
	foam.roughness = 0.22
	splashes.material_override = foam
	splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(splashes)
	animate(0.0)

func add_visual(label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	return visual

func append_tube(surface: SurfaceTool, path: PackedVector3Array, start_radius: float, end_radius: float, width_axis: Vector3, flatness: float) -> void:
	# The broad face runs around the fountain, perpendicular to each radial arc.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for j in range(path.size()):
		var tangent := (path[mini(j + 1, path.size() - 1)] - path[maxi(j - 1, 0)]).normalized()
		var sideways := width_axis
		var up := tangent.cross(sideways).normalized()
		var s := float(j) / (path.size() - 1)
		var radius := lerpf(start_radius, end_radius, s) * (1.0 + 0.055 * sin(s * 23.0))
		for k in range(SIDES + 1):
			var a := TAU * k / SIDES
			var normal := (sideways * cos(a) + up * sin(a) / flatness).normalized()
			vertices.append(path[j] + (sideways * cos(a) + up * sin(a) * flatness) * radius)
			normals.append(normal)
	for j in range(path.size() - 1):
		for k in range(SIDES):
			var a := j * (SIDES + 1) + k
			var b := a + SIDES + 1
			for index in [a, b, a + 1, a + 1, b, b + 1]:
				surface.set_normal(normals[index])
				surface.set_uv(Vector2(float(index % (SIDES + 1)) / SIDES, float(index / (SIDES + 1)) / (path.size() - 1)))
				surface.add_vertex(vertices[index])

func animate(time: float) -> void:
	stream_material.set_shader_parameter('flow_time', time)
	pool_material.set_shader_parameter('flow_time', time)
	for i in range(spray.instance_count):
		var angle := TAU * (i / 6) / 8.0
		var phase := fmod(time * 1.55 + float(i % 6) / 6.0, 1.0)
		var direction := float(i % 6) * TAU / 6.0 + angle
		var landing := Vector3(cos(angle) * 3.8, 0.44, sin(angle) * 3.8)
		var offset := Vector3(cos(direction) * 0.42 * phase, sin(phase * PI) * 0.48, sin(direction) * 0.42 * phase)
		var size := (1.0 - phase * 0.75)
		spray.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 1.6, size)), landing + offset))
