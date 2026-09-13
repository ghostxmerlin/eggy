extends RefCounted

const Catalog = preload('res://scripts/item_catalog.gd')
static var materials: Dictionary = {}

static func material(color: Color, glow := false) -> StandardMaterial3D:
	var key := color.to_html()+str(glow)
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .34
	if color.a < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = .35
	materials[key] = mat
	return mat

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = pos
	node.material_override = material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := mesh(parent,preload('res://assets/meshes/unit_sphere.tres'),pos,color)
	node.scale = size
	return node

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent,shape,pos,color)

static func ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius-.06
	shape.outer_radius = radius+.06
	shape.rings = 24
	shape.ring_segments = 6
	return mesh(parent,shape,Vector3.ZERO,color)

static func item(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = 'Item_'+id
	var color := Catalog.color(id)
	var cream := Color('#fff5d4')
	var dark := Color('#26364c')
	match id:
		'portal':
			ring(root,.42,color).rotation.x = PI/2
			sphere(root,Vector3.ZERO,Vector3(.30,.30,.10),Color('#80eeef'))
		'ball':
			sphere(root,Vector3.ZERO,Vector3.ONE*.82,color)
			for p in [Vector3(-.20,.27,.73),Vector3(.17,.27,.74),Vector3(0,.01,.80)]:
				sphere(root,p,Vector3.ONE*.11,dark)
		'ink':
			sphere(root,Vector3.ZERO,Vector3(.42,.40,.42),color)
			for i in range(6):
				var a := i*TAU/6
				sphere(root,Vector3(sin(a)*.32,-.28,cos(a)*.32),Vector3(.13,.16,.13),color)
			for x in [-.13,.13]: sphere(root,Vector3(x,.09,.36),Vector3(.09,.11,.06),cream)
		'spring':
			box(root,Vector3(0,-.1,0),Vector3(1.9,.15,2.0),dark)
			box(root,Vector3(0,.05,0),Vector3(1.8,.18,1.9),color)
			for side in [-1,1]:
				box(root,Vector3(side*.21,.16,-.10),Vector3(.10,.035,.75),cream).rotation.y = side*-.65
		'mine':
			sphere(root,Vector3.ZERO,Vector3(.65,.18,.65),dark)
			sphere(root,Vector3(0,.14,0),Vector3(.38,.13,.38),color)
			sphere(root,Vector3(0,.29,0),Vector3.ONE*.11,cream)
		'smoke':
			for i in range(3): sphere(root,Vector3((i-1)*.18,i%2*.22,0),Vector3.ONE*.3,color)
		'bomb':
			sphere(root,Vector3.ZERO,Vector3.ONE*.40,color)
			box(root,Vector3(0,.43,0),Vector3(.08,.26,.08),dark).rotation.z = -.3
			sphere(root,Vector3(.07,.58,0),Vector3.ONE*.08,cream)
		'crate':
			box(root,Vector3.ZERO,Vector3.ONE*1.4,color)
			for z in [-.72,.72]:
				for side in [-1,1]: box(root,Vector3(0,0,z),Vector3(1.65,.13,.055),cream).rotation.z = side*.7
		'boost':
			for side in [-1,1]:
				sphere(root,Vector3(side*.25,0,.15),Vector3(.2,.18,.43),color)
				box(root,Vector3(side*.25,-.17,.15),Vector3(.4,.08,.75),cream)
		'rope':
			ring(root,.35,color).rotation.x = PI/2
			box(root,Vector3(.3,.3,0),Vector3(.1,.45,.1),cream)
		'jetpack':
			for side in [-1,1]:
				sphere(root,Vector3(side*.23,0,0),Vector3(.19,.5,.19),color)
				sphere(root,Vector3(side*.23,-.52,0),Vector3(.13,.25,.13),Color('#ffc957'))
		'clock':
			sphere(root,Vector3.ZERO,Vector3(.45,.45,.14),color)
			sphere(root,Vector3(0,0,.12),Vector3(.35,.35,.04),cream)
			box(root,Vector3(0,.12,.18),Vector3(.055,.28,.04),dark)
			box(root,Vector3(.10,0,.18),Vector3(.25,.055,.04),dark)
			box(root,Vector3(0,.50,0),Vector3(.2,.16,.12),dark)
	return root

static func pickup() -> Node3D:
	var root := Node3D.new()
	box(root,Vector3.ZERO,Vector3.ONE*.95,Color('#ffd25f'))
	box(root,Vector3.ZERO,Vector3(1.02,.18,1.02),Color('#38bbbf'))
	var label := Label3D.new()
	label.text = '?'
	label.font = preload('res://assets/fonts/CloudSans-Heavy.ttf')
	label.font_size = 64
	label.pixel_size = .013
	label.position = Vector3(0,.05,.53)
	label.modulate = Color('#ffffff')
	label.outline_modulate = Color('#17767e')
	root.add_child(label)
	ring(root,.78,Color('#5adcd1')).position.y = -.6
	return root

static func portal() -> Node3D:
	var root := Node3D.new()
	ring(root,1.08,Color('#936ee8')).rotation.x = PI/2
	var inner := ring(root,.88,Color('#6ce9ed'))
	inner.rotation.x = PI/2
	sphere(root,Vector3.ZERO,Vector3(.81,.95,.04),Color(.27,.17,.65,.48))
	return root
