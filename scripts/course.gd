extends Node3D

const UNIT_SPHERE = preload('res://assets/meshes/unit_sphere.tres')
const UNIT_CYLINDER = preload('res://assets/meshes/unit_cylinder.tres')
const START_Z := 11.0
const FINISH_Z := -307.0
const CHECKPOINTS := [Vector3(0, 0.1, 5), Vector3(0, 0.1, -49), Vector3(0, 0.1, -97), Vector3(0, 0.1, -139), Vector3(0, 0.1, -205), Vector3(0, 0.1, -263), Vector3(0, 0.1, -295)]
const GAP_EDGES := [-61.0, -72.0, -83.0, -151.0, -169.0, -182.0, -195.0, -224.0, -235.0, -246.0, -257.0, -274.0, -286.0]
# Shared by geometry and AI: start, end, width, color, center.
const TRACK_DECKS := [
	[14,-18,20,'mint',0],
	[-18,-54,22,'mint',0],
	[-54,-61,20,'purple',0],
	[-63.6,-72,20,'orange',0],
	[-74.6,-83,20,'purple',0],
	[-85.6,-96,20,'orange',0],
	[-96,-133,20,'mint',0],
	[-133,-151,18,'yellow',0],
	[-153.8,-169,6,'mint',0],
	[-171.8,-182,6,'purple',-2.5],
	[-184.8,-195,6,'orange',2.5],
	[-197.8,-213,8,'mint',0],
	[-213,-224,14,'yellow',0],
	[-227,-235,5,'purple',-1.8],
	[-238,-246,5,'orange',1.8],
	[-249,-257,5,'purple',-1.8],
	[-260,-274,12,'yellow',0],
	[-276.8,-286,5,'mint',0],
	[-288.8,-320,22,'yellow',0]
]
var palette: Dictionary = {}
var rounded: Mesh
var spinners: Array[Node3D] = []
var gates: Array[Node3D] = []
var floaters: Array[Node3D] = []
var t := 0.0

func _ready() -> void:
	for entry in [['mint','#38bcae'],['mint_dark','#147c91'],['cream','#fff0cb'],['orange','#ff9565'],['pink','#ee789d'],['purple','#9b90d7'],['yellow','#ffcf65'],['white','#fffdf1'],['dark','#264b68'],['cloud','#f7f1ef']]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(entry[1])
		mat.roughness = 0.52
		palette[entry[0]] = mat
	var resource = load('res://assets/models/rounded.glb').instantiate()
	rounded = find_mesh(resource)
	resource.free()
	build_world()

func find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return node.mesh
	for child in node.get_children():
		var found := find_mesh(child)
		if found: return found
	return null

func block(parent: Node3D, pos: Vector3, size: Vector3, color: String, solid := false) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(root)
	root.position = pos
	var visual := MeshInstance3D.new()
	visual.mesh = rounded
	visual.scale = size
	visual.material_override = palette[color]
	root.add_child(visual)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	return root

func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: String, shadow := true) -> MeshInstance3D:
	var mesh := UNIT_SPHERE
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.scale = size
	obj.position = pos
	obj.material_override = palette[color]
	if not shadow: obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(obj)
	return obj

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var mesh := UNIT_CYLINDER
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.position = pos
	obj.scale = Vector3(radius,height,radius)
	obj.material_override = palette[color]
	parent.add_child(obj)
	return obj

func solid_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	cylinder(body,Vector3.ZERO,radius,height,color)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	return body

func lettering(parent: Node3D, text: String, pos: Vector3, size: int, color := Color('#ffffff')) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.012
	label.position = pos
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
	return label

func deck(z0: float, z1: float, width: float, color: String, x_offset := 0.0) -> void:
	var center := (z0+z1)*0.5
	var length := absf(z1-z0)
	block(self, Vector3(x_offset,-0.6,center), Vector3(width,1.2,length), color, true)
	block(self, Vector3(x_offset,-1.35,center), Vector3(width-0.4,0.6,length-0.2),'cream')
	block(self, Vector3(x_offset,-1.72,center), Vector3(width-1.0,0.22,length-0.7),'mint_dark')
	# A restrained lane pattern gives speed and scale without noisy textures.
	for z in range(int(z1+2),int(z0-1),5):
		for x in [-width*.28, width*.28]:
			block(self,Vector3(x+x_offset,0.018,z),Vector3(.12,.025,1.35),'white')
	for x in [-width*.5+.18,width*.5-.18]:
		block(self,Vector3(x+x_offset,.12,center),Vector3(.26,.27,length-.6),'cream')

func arch(z: float, title: String, color: String, width := 19.0) -> void:
	for x in [-width*.5,width*.5]:
		block(self, Vector3(x,2.8,z),Vector3(.9,5.7,1.1), color)
		sphere(self,Vector3(x,5.5,z),Vector3(.48,.48,.55),color)
		block(self,Vector3(x,.28,z),Vector3(1.45,.6,1.6),'cream')
	block(self, Vector3(0,5.6,z),Vector3(width,1.25,1.1),color)
	lettering(self,title,Vector3(0,5.62,z+.58),78)
	for x in [-7.0,-5.0,5.0,7.0]:
		sphere(self,Vector3(x,5.62,z+.61),Vector3(.12,.12,.08),'yellow')

func rails(z0: float, z1: float, width: float) -> void:
	for x in [-width*.5,width*.5]:
		block(self,Vector3(x,.65,(z0+z1)*.5),Vector3(.32,.3,absf(z1-z0)),'white',true)
		for z in range(int(z1),int(z0)+1,4):
			block(self,Vector3(x,.35,z),Vector3(.32,.7,.32),'orange')

func arrow(z: float, x := 0.0, color := 'cream') -> void:
	for side in [-1,1]:
		var b := block(self,Vector3(x+side*.40,.028,z),Vector3(.22,.025,1.15),color)
		b.rotation.y = side * -0.75

func build_world() -> void:
	for section in TRACK_DECKS:
		deck(section[0],section[1],section[2],section[3],section[4])
	rails(13,-17,20)
	rails(-19,-53,22)
	rails(-97,-132,20)
	arch(0,'CLOUD  /  CLUB','orange')
	arch(FINISH_Z,'FINISH','mint_dark',21)
	for x in range(-9,10):
		for row in range(2):
			block(self,Vector3(x,.035,FINISH_Z+1-row),Vector3(.97,.04,.97),'cream' if (x+row)%2==0 else 'mint_dark')
	for z in [4,-10,-20,-47,-56,-67,-78,-90,-99,-130,-140]: arrow(z)
	for i in range(3):
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = Vector3([-4.0,4.0,-2.0][i],.68,-25-i*10)
		pivot.rotation.y = i*1.8
		cylinder(pivot,Vector3(0,-.1,0),.85,1.5,'cream')
		cylinder(pivot,Vector3(0,.67,0),.95,.3,'yellow')
		block(pivot,Vector3.ZERO,Vector3(12.8,.52,.65),'orange')
		for x in [-6.1,6.1]: sphere(pivot,Vector3(x,0,0),Vector3(.55,.55,.55),'pink')
		spinners.append(pivot)
	for i in range(2):
		var gate := Node3D.new()
		add_child(gate)
		gate.position = Vector3(0,0,-109-i*13)
		for x in [-10,10]:
			block(gate,Vector3(x,2,0),Vector3(.7,4,.7),'cream')
		block(gate,Vector3(0,4.1,0),Vector3(20.5,.6,.75),'purple')
		var slider := AnimatableBody3D.new()
		gate.add_child(slider)
		slider.name = 'Slider'
		slider.sync_to_physics = false
		block(slider,Vector3(0,1.1,0),Vector3(8,2.2,1.0),'pink')
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(8,2.2,1)
		collision.shape = shape
		collision.position.y = 1.1
		slider.add_child(collision)
		for x in [-2.5,0,2.5]:
			block(slider,Vector3(x,1.1,.52),Vector3(.16,1.5,.04),'cream').rotation.z = -.3
		gates.append(gate)
	for i in range(1,CHECKPOINTS.size()):
		var z: float = CHECKPOINTS[i].z
		var half_width := 3.5 if z == -205 else (5.5 if z == -263 else 8.5)
		block(self,Vector3(0,.04,z),Vector3(half_width*2,.05,.3),'yellow')
		for x in [-half_width,half_width]:
			cylinder(self,Vector3(x,1.2,z),.09,2.4,'cream')
			var flag := block(self,Vector3(x+.55,2.0,z),Vector3(1.05,.60,.08),'yellow')
			flag.rotation.z = -.08
	# Track-side distance pylons.
	for entry in [[-18,'01','SPIN'],[-54,'02','HOP'],[-96,'03','SLIDE'],[-151,'04','BALANCE'],[-224,'05','LEAP'],[-274,'06','FINAL']]:
		var z: float = entry[0]
		block(self,Vector3(-12.5,2.0,z),Vector3(3.0,4,.6),'cream')
		lettering(self,entry[1],Vector3(-12.5,2.45,z+.34),120,Color('#187c8f'))
		lettering(self,entry[2],Vector3(-12.5,1.20,z+.34),36,Color('#187c8f'))
	# Clouds, distant islands and tethered balloons frame the playable silhouette.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7352
	for i in range(50):
		var side: float = -1 if i%2==0 else 1
		var pos := Vector3(side*rng.randf_range(20,95),rng.randf_range(-15,-6),rng.randf_range(-345,40))
		for j in range(3):
			sphere(self,pos+Vector3(j*3, sin(j)*1.1,0),Vector3(rng.randf_range(4,8),rng.randf_range(2,3.5),rng.randf_range(3,6)),'cloud',false)
	for i in range(12):
		var side := -1.0 if i%2==0 else 1.0
		var island := Vector3(side*(24+i%3*7),-2-i%3,-12-i*25)
		sphere(self,island-Vector3(0,2,0),Vector3(7,3.5,6),'purple')
		cylinder(self,island,6.6,.8,'mint')
		for j in range(3):
			var p := island+Vector3((j-1)*3,2.0,j*1.3-1)
			cylinder(self,p-Vector3(0,.7,0),.20,2.8,'cream')
			sphere(self,p+Vector3(0,1.2,0),Vector3(1.6,2.0,1.6),'pink' if j%2 else 'yellow')
	for i in range(5):
		var balloon := Node3D.new()
		add_child(balloon)
		balloon.position = Vector3((-1 if i%2==0 else 1)*(25+i*5),10+i%3*5,-18-i*34)
		sphere(balloon,Vector3.ZERO,Vector3(3,3.8,3),'orange' if i%2==0 else 'mint')
		for angle in range(0,360,60):
			var rad := deg_to_rad(angle)
			sphere(balloon,Vector3(sin(rad)*.75,.05,cos(rad)*.75),Vector3(2.4,3.8,2.4),'cream' if angle%120==0 else ('orange' if i%2==0 else 'mint'),false)
		block(balloon,Vector3(0,-5.4,0),Vector3(1.9,1.0,1.4),'yellow')
		for x in [-.7,.7]: block(balloon,Vector3(x,-4.3,0),Vector3(.07,2,.07),'cream')
		floaters.append(balloon)
	# Pennant garlands in the starting area.
	for side in [-1,1]:
		for i in range(7):
			var z := 10-i*3.7
			cylinder(self,Vector3(side*11.5,2.6,z),.055,5.2,'cream')
			block(self,Vector3(side*11.5,4.9,z),Vector3(.09,.1,3.9),'cream')
			var flag := block(self,Vector3(side*11.5,4.4,z-1.6),Vector3(.07,.85,1.1),'pink' if i%2 else 'yellow')
			flag.rotation.x = .15

func _physics_process(delta: float) -> void:
	var game := get_parent()
	if game.paused: return
	t += delta
	for i in range(spinners.size()):
		spinners[i].rotation.y += delta * (1.0+i*.15) * (1 if i%2==0 else -1)
	for i in range(gates.size()):
		gates[i].get_node('Slider').position.x = sin(t*1.2+i*2)*5.4
	for i in range(floaters.size()):
		floaters[i].rotation.z = sin(t*.45+i)*.045

func hazard_at(pos: Vector3) -> Vector3:
	for pivot in spinners:
		var local: Vector3 = pivot.to_local(pos + Vector3(0,.6,0))
		if absf(local.x)<6.5 and absf(local.z)<.72 and absf(local.y)<.9:
			var radial := pos-pivot.position
			var spin_sign := 1.0 if spinners.find(pivot)%2 == 0 else -1.0
			return Vector3(radial.z,0,-radial.x).normalized()*11.0*spin_sign + Vector3.UP*5.5
	return Vector3.ZERO

# A gap uses the upcoming landing platform; margins include the racer radius.
func ai_bounds(z: float) -> Vector2:
	for section in TRACK_DECKS:
		if z >= section[1]:
			var half: float = section[2]*.5-.85
			return Vector2(section[4]-half,section[4]+half)
	return Vector2(-10.15,10.15)

func supported_at(pos: Vector3, margin := .85) -> bool:
	for section in TRACK_DECKS:
		if pos.z <= section[0] and pos.z >= section[1]:
			return absf(pos.x-section[4]) <= section[2]*.5-margin
	return false

func ai_route_bounds(pos: Vector3) -> Vector2:
	var landing := ai_bounds(pos.z-4)
	if pos.y > .4 or not supported_at(pos): return landing
	var current := ai_bounds(pos.z)
	var overlap := Vector2(maxf(current.x,landing.x),minf(current.y,landing.y))
	if overlap.x <= overlap.y: return overlap
	# Offset decks can have no overlap after body margins. Approach the takeoff
	# edge on this deck, then steer across once airborne instead of walking off it.
	var takeoff := current.y if landing.x > current.y else current.x
	return Vector2(takeoff,takeoff)

func ai_target(pos: Vector3, lane: float, id: int) -> Vector3:
	var bounds := ai_route_bounds(pos)
	var center := (bounds.x+bounds.y)*.5
	var spread := minf(1.0,(bounds.y-bounds.x)/16.0)
	var x := center + (lane + sin(-pos.z*.075+id)*.35)*spread
	for gate in gates:
		if absf(pos.z-gate.position.z)<10:
			var gx: float = gate.get_node('Slider').position.x
			x = -7.0 if gx>0 else 7.0
	return Vector3(clampf(x,bounds.x,bounds.y),0,pos.z-4)

func path_center(z: float) -> float:
	var bounds := ai_bounds(z)
	return (bounds.x+bounds.y)*.5
