extends RefCounted
# Code-built geometry; no official game mesh is downloaded or embedded.
static func mat(color: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = .55
	m.roughness = .3
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = .65
		m.metallic = .05
	return m

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.position = pos
	n.scale = scale
	n.material_override = material
	parent.add_child(n)
	return n

static func ball(parent: Node3D, pos: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 1
	shape.height = 2
	shape.radial_segments = 20
	shape.rings = 12
	return mesh(parent,shape,pos,scale,material)

static func box(parent: Node3D, pos: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
	return mesh(parent,BoxMesh.new(),pos,scale,material)

static func ring(parent: Node3D, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius*.79
	shape.outer_radius = radius
	shape.rings = 24
	shape.ring_segments = 8
	return mesh(parent,shape,pos,Vector3.ONE,material)

# Extruded convex plate with a raised centre: crisp, faceted armor surfaces.
static func plate(parent: Node3D, outline: Array, z: float, depth: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var center := Vector2.ZERO
	for point in outline: center += point
	center /= outline.size()
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var front_a := Vector3(a.x,a.y,z)
		var front_b := Vector3(b.x,b.y,z)
		var back_a := Vector3(a.x,a.y,z-depth)
		var back_b := Vector3(b.x,b.y,z-depth)
		for vertex in [Vector3(center.x,center.y,z+.055),front_b,front_a,front_a,front_b,back_b,front_a,back_b,back_a]: surface.add_vertex(vertex)
	surface.generate_normals()
	var material_copy: StandardMaterial3D = material.duplicate()
	material_copy.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh(parent,surface.commit(),Vector3.ZERO,Vector3.ONE,material_copy)

static func build(model: Node3D, root: Node3D, skin: Dictionary) -> void:
	var armor := mat(Color(skin.shell))
	var dark := mat(Color('#243a54'))
	var accent := mat(Color('#079de8') if skin.accessory == 'knight' else Color(skin.accent),true)
	var silver := mat(Color('#e6edf1'))
	var kind: String = skin.accessory
	if kind in ['knight','gale','blaze']:
		model.find_child('Body',true,false).layers = 0
		ball(root,Vector3(0,.99,0),Vector3(.63,.62,.5),dark)
		# Dark face window, swept brow, pointed jaw and nested cheek armor.
		ball(root,Vector3(0,1.19,.42),Vector3(.51,.25,.14),dark)
		plate(root,[Vector2(-.59,1.53),Vector2(-.42,1.72),Vector2(0,1.55),Vector2(.42,1.72),Vector2(.59,1.53),Vector2(0,1.18)],.53,.27,armor)
		plate(root,[Vector2(-.39,1.09),Vector2(.39,1.09),Vector2(.28,.62),Vector2(0,.48),Vector2(-.28,.62)],.58,.3,armor)
		plate(root,[Vector2(-.16,1.05),Vector2(.16,1.05),Vector2(.12,.76),Vector2(0,.68),Vector2(-.12,.76)],.66,.07,dark)
		for side in [-1,1]:
			plate(root,[Vector2(side*.10,1.20),Vector2(side*.41,1.39),Vector2(side*.38,1.18),Vector2(side*.23,1.14)],.595,.035,accent)
			plate(root,[Vector2(side*.43,1.40),Vector2(side*.64,1.53),Vector2(side*.67,.92),Vector2(side*.32,.65)],.47,.3,silver)
			# Horn fins and separate armor profile for each variant.
			var height := 2.12 if kind == 'knight' else (1.91 if kind == 'gale' else 1.77)
			plate(root,[Vector2(side*.23,1.48),Vector2(side*.79,height),Vector2(side*.64,1.61),Vector2(side*.46,1.36)],.38,.17,armor)
			plate(root,[Vector2(side*.39,1.58),Vector2(side*.76,height-.04),Vector2(side*.52,1.62)],.45,.035,accent)
			var shoulder := .98 if kind == 'blaze' else .87
			plate(root,[Vector2(side*.59,1.28),Vector2(side*shoulder,1.56),Vector2(side*(shoulder+.13),1.19),Vector2(side*.80,.96)],.08,.38,armor)
			plate(root,[Vector2(side*.68,1.29),Vector2(side*shoulder,1.45),Vector2(side*.89,1.16)],.145,.04,accent)
			var pod := ball(root,Vector3(side*.43,.92,-.52),Vector3(.20,.43,.22),dark)
			pod.rotation.z = side*.2
			ring(root,Vector3(side*.47,.65,-.54),.16,silver)
			ball(root,Vector3(side*.47,.54,-.54),Vector3(.115,.19,.115),accent)
			if kind in ['knight','gale']:
				plate(root,[Vector2(side*.5,1.16),Vector2(side*1.13,1.50),Vector2(side*.74,.70)],-.4,.08,silver)
				plate(root,[Vector2(side*.59,1.1),Vector2(side*1.03,1.38),Vector2(side*.75,.82)],-.32,.03,accent)
			for prefix in ['Arm','Foot']:
				var original: MeshInstance3D = model.find_child(prefix+('L' if side == -1 else 'R'),true,false)
				original.layers = 0
				var attachment := Node3D.new()
				attachment.name = 'OutfitLimb'
				original.add_child(attachment)
				if prefix == 'Arm':
					ball(attachment,Vector3.ZERO,Vector3(.17,.18,.17),dark)
					box(attachment,Vector3(0,-.12,.04),Vector3(.29,.30,.31),armor).rotation.z = side*.15
					box(attachment,Vector3(0,-.13,.21),Vector3(.16,.06,.04),accent)
				else:
					box(attachment,Vector3(0,0,.03),Vector3(.37,.28,.47),dark)
					plate(attachment,[Vector2(-.2,.14),Vector2(.20,.14),Vector2(.18,-.13),Vector2(0,-.17),Vector2(-.18,-.13)],.31,.4,armor)
					box(attachment,Vector3(0,.09,.34),Vector3(.20,.045,.035),accent)
		plate(root,[Vector2(-.11,.98),Vector2(.11,.98),Vector2(0,.84)],.74,.02,accent)
		if kind == 'knight': plate(root,[Vector2(-.18,1.61),Vector2(0,1.95),Vector2(.18,1.61),Vector2(0,1.47)],.49,.13,silver)
		return
	# Everyday outfits preserve the original expressive face and animated limbs.
	if kind == 'scarf':
		ring(root,Vector3(0,.57,0),.65,mat(Color('#ea6b5b')))
		box(root,Vector3(.28,.42,.59),Vector3(.21,.43,.075),mat(Color('#ea6b5b'))).rotation.z = -.2
		box(root,Vector3(-.57,.62,.32),Vector3(.30,.36,.23),dark)
	elif kind in ['goggles','aviator']:
		for side in [-1,1]:
			ball(root,Vector3(side*.22,1.51,.34),Vector3(.24,.17,.13),dark)
			ball(root,Vector3(side*.22,1.51,.43),Vector3(.18,.11,.07),accent)
			ball(root,Vector3(side*.23,.95,-.57),Vector3(.15,.42,.16),silver)
		if kind == 'goggles':
			box(root,Vector3(.64,1.5,.01),Vector3(.09,.70,.1),accent)
		else:
			ball(root,Vector3(0,1.61,-.02),Vector3(.58,.16,.53),mat(Color('#925a43')))
			for side in [-1,1]: ball(root,Vector3(side*.62,1.18,0),Vector3(.09,.30,.28),mat(Color('#925a43')))
	else:
		belt(root,dark,accent)
		if kind == 'safety':
			ball(root,Vector3(0,1.66,0),Vector3(.61,.25,.52),mat(Color('#ffce55')))
			ball(root,Vector3(0,1.54,.2),Vector3(.65,.045,.54),mat(Color('#ffce55')))
		elif kind == 'worker':
			box(root,Vector3(.69,.88,.04),Vector3(.08,.53,.08),silver).rotation.z = -.32
			ring(root,Vector3(.77,1.16,.04),.15,silver).rotation.x = PI/2
		elif kind == 'rover':
			box(root,Vector3(0,1.0,-.54),Vector3(.90,.74,.25),armor)
			box(root,Vector3(.38,1.64,-.44),Vector3(.055,.55,.055),silver)
			ball(root,Vector3(.38,1.94,-.44),Vector3(.13,.07,.13),accent)
			for side in [-1,1]:
				ball(root,Vector3(side*.71,.77,0),Vector3(.22,.25,.30),dark)
				box(root,Vector3(side*.52,1.35,.28),Vector3(.28,.12,.15),silver)

static func belt(root: Node3D, dark: Material, accent: Material) -> void:
	ring(root,Vector3(0,.57,0),.64,dark)
	box(root,Vector3(0,.58,.62),Vector3(.18,.15,.08),accent)
	for side in [-1,1]: box(root,Vector3(side*.49,.61,.4),Vector3(.22,.23,.17),dark)
