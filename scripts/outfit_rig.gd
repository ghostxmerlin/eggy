extends Node3D
# Sleeves/struts bridge the torso and the ORIGINAL animated limb transforms.
var links: Array = []

func connect_limb(limb: Node3D, anchor: Vector3, offset: Vector3, radius: float, material: Material) -> void:
	var strut := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1
	cylinder.bottom_radius = 1
	cylinder.height = 1
	cylinder.radial_segments = 16
	strut.mesh = cylinder
	strut.material_override = material
	add_child(strut)
	links.append({'limb':limb,'anchor':anchor,'offset':offset,'radius':radius,'strut':strut})
	sync()

func sync() -> void:
	for link in links:
		var end: Vector3 = to_local(link.limb.to_global(link.offset))
		var delta: Vector3 = end-link.anchor
		var strut: Node3D = link.strut
		strut.position = (end+link.anchor)*.5
		strut.basis = Basis(Quaternion(Vector3.UP,delta.normalized())) if delta.length() > .0001 else Basis.IDENTITY
		strut.scale = Vector3(link.radius,maxf(.01,delta.length())+.14,link.radius)
