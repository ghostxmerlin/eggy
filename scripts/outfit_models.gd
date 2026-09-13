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

# Closed beveled plates. Triangulation supports the concave brow and cheek shapes.
static func plate(parent: Node3D, outline: Array, z: float, depth: float, material: Material) -> void:
	var polygon := PackedVector2Array(outline)
	if Geometry2D.is_polygon_clockwise(polygon): polygon.reverse()
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty(): return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var center := Vector2.ZERO
	for point in polygon: center += point
	center /= polygon.size()
	var bevel := minf(.022,depth*.20)
	var inner := PackedVector2Array()
	for point in polygon: inner.append(point.lerp(center,.065))
	for i in range(0,indices.size(),3):
		for index in [indices[i+2],indices[i+1],indices[i]]: surface.add_vertex(Vector3(inner[index].x,inner[index].y,z))
		for index in [indices[i],indices[i+1],indices[i+2]]: surface.add_vertex(Vector3(inner[index].x,inner[index].y,z-depth))
	for i in range(polygon.size()):
		var j := (i+1)%polygon.size()
		var rings: Array = []
		for k in [i,j]:
			rings.append([Vector3(inner[k].x,inner[k].y,z),Vector3(polygon[k].x,polygon[k].y,z-bevel),Vector3(polygon[k].x,polygon[k].y,z-depth+bevel),Vector3(inner[k].x,inner[k].y,z-depth)])
		for k in range(3):
			for vertex in [rings[0][k],rings[1][k],rings[1][k+1],rings[0][k],rings[1][k+1],rings[0][k+1]]: surface.add_vertex(vertex)
	surface.generate_normals()
	var finish: StandardMaterial3D = material.duplicate()
	finish.cull_mode = BaseMaterial3D.CULL_BACK
	var node := mesh(parent,surface.commit(),Vector3.ZERO,Vector3.ONE,finish)
	node.set_meta('closed_armor',true)

static func tube(parent: Node3D, points: Array, radius: float, material: Material) -> void:
	for i in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var shape := CylinderMesh.new()
		shape.top_radius = radius
		shape.bottom_radius = radius
		shape.height = a.distance_to(b)
		shape.radial_segments = 12
		var segment := mesh(parent,shape,(a+b)*.5,Vector3.ONE,material)
		segment.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	for point in points: ball(parent,point,Vector3.ONE*radius,material)

static func strap(parent: Node3D, side: float, material: Material) -> void:
	var points: Array = []
	for i in range(13):
		var angle := TAU*i/12.0
		points.append(Vector3(side*.47,1.0+.575*cos(angle),.51*sin(angle)))
	tube(parent,points,.043,material)

static func build(model: Node3D, root: Node3D, skin: Dictionary) -> void:
	var armor := mat(Color(skin.shell))
	var dark := mat(Color('#243a54'))
	var accent := mat(Color('#079de8') if skin.accessory == 'knight' else Color(skin.accent),true)
	var silver := mat(Color('#e6edf1'))
	var kind: String = skin.accessory
	if kind in ['knight','gale','blaze']:
		load('res://scripts/knight_model.gd').build(model,root,skin)
		compact(root)
		for limb in ['ArmL','ArmR','FootL','FootR']:
			compact(model.find_child(limb,true,false).get_node('OutfitLimb'))
		return
	# Everyday outfits preserve the original expressive face and animated limbs.
	if kind == 'scarf':
		ring(root,Vector3(0,.66,0),.68,mat(Color('#ea6b5b'))).scale = Vector3(1,.90,.84)
		box(root,Vector3(.28,.48,.51),Vector3(.21,.40,.075),mat(Color('#ea6b5b'))).rotation.z = -.2
		strap(root,-1,dark)
		box(root,Vector3(-.57,.62,.32),Vector3(.30,.36,.23),dark)
	elif kind in ['goggles','aviator']:
		strap(root,-1,dark)
		strap(root,1,dark)
		box(root,Vector3(0,.99,-.46),Vector3(.62,.55,.25),dark)
		var band := ring(root,Vector3(0,1.49,0),.53,dark)
		band.scale = Vector3(1,.35,.91)
		for side in [-1,1]:
			ball(root,Vector3(side*.22,1.51,.34),Vector3(.24,.17,.13),dark)
			ball(root,Vector3(side*.22,1.51,.43),Vector3(.18,.11,.07),accent)
			ball(root,Vector3(side*.23,.95,-.57),Vector3(.15,.42,.16),silver)
		if kind == 'goggles':
			tube(root,[Vector3(.38,1.47,.35),Vector3(.57,1.48,.23),Vector3(.59,1.88,.13),Vector3(.52,1.88,.13)],.047,accent)
		else:
			ball(root,Vector3(0,1.61,-.02),Vector3(.58,.16,.53),mat(Color('#925a43')))
			for side in [-1,1]: ball(root,Vector3(side*.62,1.18,0),Vector3(.09,.30,.28),mat(Color('#925a43')))
	else:
		belt(root,dark,accent)
		if kind == 'safety':
			strap(root,-1,dark)
			strap(root,1,dark)
			box(root,Vector3(0,1.0,-.51),Vector3(.57,.6,.28),dark)
			ball(root,Vector3(0,1.25,-.7),Vector3(.16,.085,.04),accent)
			ball(root,Vector3(0,1.66,0),Vector3(.61,.25,.52),mat(Color('#ffce55')))
			ball(root,Vector3(0,1.54,.2),Vector3(.65,.045,.54),mat(Color('#ffce55')))
		elif kind == 'worker':
			box(root,Vector3(.59,.85,.14),Vector3(.08,.53,.08),silver).rotation.z = -.32
			ring(root,Vector3(.67,1.10,.14),.15,silver).rotation.x = PI/2
		elif kind == 'rover':
			strap(root,-1,dark)
			strap(root,1,dark)
			box(root,Vector3(0,1.0,-.54),Vector3(.90,.74,.25),armor)
			box(root,Vector3(.38,1.64,-.44),Vector3(.055,.55,.055),silver)
			ball(root,Vector3(.38,1.94,-.44),Vector3(.13,.07,.13),accent)
			for side in [-1,1]:
				ball(root,Vector3(side*.71,.77,0),Vector3(.22,.25,.30),dark)
				box(root,Vector3(side*.52,1.35,.28),Vector3(.28,.12,.15),silver)

	compact(root)

static func belt(root: Node3D, dark: Material, accent: Material) -> void:
	ring(root,Vector3(0,.61,0),.64,dark).scale.z = .85
	box(root,Vector3(0,.58,.62),Vector3(.18,.15,.08),accent)
	for side in [-1,1]: box(root,Vector3(side*.49,.61,.4),Vector3(.22,.23,.17),dark)

# Static pieces share draw surfaces. Normal inverse-transpose is necessary for
# non-uniform scales (spheres/cylinders); append_from alone distorted old assets.
static func compact(parent: Node3D) -> void:
	var groups := {}
	var sources: Array = []
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		var material: StandardMaterial3D = child.material_override
		if not material: continue
		var key := str([material.albedo_color,material.metallic,material.roughness,material.emission_enabled,material.emission,material.emission_energy_multiplier,material.cull_mode])
		if not groups.has(key): groups[key] = {'material':material,'vertices':PackedVector3Array(),'normals':PackedVector3Array(),'indices':PackedInt32Array()}
		var group: Dictionary = groups[key]
		var transform: Transform3D = child.transform
		var normal_basis := transform.basis.inverse().transposed()
		for surface in range(child.mesh.get_surface_count()):
			var data: Array = child.mesh.surface_get_arrays(surface)
			var offset: int = group.vertices.size()
			for v in data[Mesh.ARRAY_VERTEX]: group.vertices.append(transform*v)
			for n in data[Mesh.ARRAY_NORMAL]: group.normals.append((normal_basis*n).normalized())
			if data[Mesh.ARRAY_INDEX] == null or data[Mesh.ARRAY_INDEX].is_empty():
				for i in range(data[Mesh.ARRAY_VERTEX].size()): group.indices.append(offset+i)
			else:
				for i in data[Mesh.ARRAY_INDEX]: group.indices.append(offset+i)
		sources.append(child)
	if sources.is_empty(): return
	var combined := ArrayMesh.new()
	for group in groups.values():
		var data := []
		data.resize(Mesh.ARRAY_MAX)
		data[Mesh.ARRAY_VERTEX] = group.vertices
		data[Mesh.ARRAY_NORMAL] = group.normals
		data[Mesh.ARRAY_INDEX] = group.indices
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
		combined.surface_set_material(combined.get_surface_count()-1,group.material)
	for child in sources:
		parent.remove_child(child)
		child.queue_free()
	var result := MeshInstance3D.new()
	result.name = 'JoinedShell'
	result.mesh = combined
	parent.add_child(result)
