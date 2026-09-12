extends 'res://scripts/course.gd'

const WHEEL_CENTER := Vector3(-27,12,-17)
var wheel: Node3D
var cabins: Array[AnimatableBody3D] = []
var lift: AnimatableBody3D
var plane: Node3D
var propeller: Node3D
var water: Node3D
var giant_arm: Node3D

func build_world() -> void:
	build_wheel()
	build_fountain()
	build_lift()
	build_plane()
	build_giant()

func rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: String) -> void:
	var part := cylinder(parent,(start+end)*.5,radius,start.distance_to(end),color)
	part.quaternion = Quaternion(Vector3.UP,(end-start).normalized())

func ring(parent: Node3D, pos: Vector3, radius: float, tube: float, color: String, upright := false) -> void:
	var visual := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-tube
	mesh.outer_radius = radius+tube
	mesh.rings = 64
	mesh.ring_segments = 8
	visual.mesh = mesh
	visual.material_override = palette[color]
	parent.add_child(visual)
	visual.position = pos
	if upright: visual.rotation.x = PI/2

func platform(parent: Node3D, pos: Vector3, size: Vector3, color: String, label: String) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = label
	body.sync_to_physics = false
	parent.add_child(body)
	body.position = pos
	block(body,Vector3.ZERO,size,color)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func sign_at(text: String, pos: Vector3) -> void:
	block(self,pos+Vector3(0,1.3,0),Vector3(5.2,1.3,.35),'cream')
	for x in [-1.8,1.8]: cylinder(self,pos+Vector3(x,.55,0),.12,1.1,'orange')
	var label := lettering(self,text,pos+Vector3(0,1.34,.2),55,Color('#164764'))
	label.font = load('res://assets/fonts/CloudSans-Heavy.ttf')

func build_wheel() -> void:
	block(self,Vector3(-27,.18,-17),Vector3(20,.36,10),'purple',true)
	for z in [-18.4,-16.2]:
		for side in [-1,1]:
			rod(self,Vector3(-27+side*5,.4,z),Vector3(-27,12,z),.38,'mint_dark')
			block(self,Vector3(-27+side*5,.35,z),Vector3(2.2,.7,2.2),'cream',true)
	wheel = Node3D.new()
	wheel.name = 'FerrisWheel'
	add_child(wheel)
	wheel.position = WHEEL_CENTER
	ring(wheel,Vector3.ZERO,9,.27,'orange',true)
	ring(wheel,Vector3(0,0,-.7),9,.18,'yellow',true)
	for i in range(10):
		var a := TAU*i/10.0-PI/2
		rod(wheel,Vector3.ZERO,Vector3(cos(a)*9,sin(a)*9,0),.12,'cream')
		rod(wheel,Vector3(cos(a)*9,sin(a)*9,0),Vector3(cos(a)*9,sin(a)*9,2.8),.10,'yellow')
		sphere(wheel,Vector3(cos(a)*9,sin(a)*9,.1),Vector3.ONE*.32,'yellow',false)
		var cabin := platform(self,Vector3.ZERO,Vector3(2.8,.28,2.4),'orange' if i%2==0 else 'pink','Cabin'+str(i))
		for x in [-1.18,1.18]:
			rod(cabin,Vector3(x,.1,-.9),Vector3(x,2.2,-.9),.09,'cream')
			block(cabin,Vector3(x,.45,0),Vector3(.18,.8,2.2),'mint')
		block(cabin,Vector3(0,.45,-1),Vector3(2.6,.8,.18),'mint')
		for data in [[Vector3(-1.18,.45,0),Vector3(.18,.8,2.2)],[Vector3(1.18,.45,0),Vector3(.18,.8,2.2)],[Vector3(0,.45,-1),Vector3(2.6,.8,.18)]]:
			var guard := CollisionShape3D.new()
			var guard_shape := BoxShape3D.new()
			guard_shape.size = data[1]
			guard.shape = guard_shape
			guard.position = data[0]
			cabin.add_child(guard)
		sphere(cabin,Vector3(0,2.15,0),Vector3(1.6,.4,1.35),'yellow' if i%2 else 'purple')
		cabins.append(cabin)
	sphere(wheel,Vector3(0,0,.15),Vector3(1.1,1.1,.6),'yellow')
	sign_at('摩天轮',Vector3(-27,0,-9))
	animate_wheel()

func animate_wheel() -> void:
	wheel.rotation.z = t*.12
	for i in range(cabins.size()):
		var angle := t*.12+TAU*i/cabins.size()-PI/2
		cabins[i].position = WHEEL_CENTER+Vector3(cos(angle)*9,sin(angle)*9-2.5,2.8)

func build_fountain() -> void:
	var center := Vector3(0,0,3)
	cylinder(self,center+Vector3(0,.18,0),5.3,.36,'cream')
	ring(self,center+Vector3(0,.45,0),4.7,.45,'purple')
	solid_cylinder(self,center+Vector3(0,.95,0),.65,1.5,'cream')
	sphere(self,center+Vector3(0,1.65,0),Vector3(1.8,.35,1.8),'mint')
	sphere(self,center+Vector3(0,2.2,0),Vector3(.8,.7,.8),'yellow')
	water = preload('res://scripts/fountain.gd').new()
	water.name = 'FountainWater'
	water.position = center
	add_child(water)
	# Low collision base allows jumping onto the fountain without an invisible wall.
	var ground := StaticBody3D.new()
	add_child(ground)
	ground.position = center+Vector3(0,.15,0)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 5.2
	shape.height = .3
	collision.shape = shape
	ground.add_child(collision)
	animate_water()

func animate_water() -> void:
	water.animate(t)

func build_lift() -> void:
	lift = platform(self,Vector3(26,.35,13),Vector3(6,.5,6),'orange','Lift')
	for x in [-2.7,2.7]:
		block(lift,Vector3(x,.55,0),Vector3(.15,1.0,5.8),'cream')
	for x in [22.5,29.5]:
		cylinder(self,Vector3(x,6.1,10.2),.22,12.2,'purple')
		sphere(self,Vector3(x,12.3,10.2),Vector3(.4,.4,.4),'yellow')
	block(self,Vector3(26,12,10.2),Vector3(7.7,.45,.45),'purple')
	block(self,Vector3(36,10,13),Vector3(12,1.2,10),'mint',true)
	for x in [31.2,40.8]:
		cylinder(self,Vector3(x,4.8,13),.4,9.6,'mint_dark')
		if x > 35:
			block(self,Vector3(x,11.1,13),Vector3(.25,1,9.8),'cream',true)
		else:
			for z in [9.65,16.35]: block(self,Vector3(x,11.1,z),Vector3(.25,1,3.1),'cream',true)
	block(self,Vector3(36,11.1,8.2),Vector3(10,.9,.25),'cream',true)
	block(self,Vector3(36,11.1,17.8),Vector3(10,.9,.25),'cream',true)
	block(self,Vector3(30.2,10.48,13),Vector3(2.4,.24,2.4),'cream',true)
	sign_at('升降观景台',Vector3(26,0,18))

func build_plane() -> void:
	var ride = preload('res://scripts/plane_ride.gd').new()
	ride.name = 'PlaneRide'
	add_child(ride)
	plane = ride.body
	propeller = ride.propeller

func build_giant() -> void:
	var giant := Node3D.new()
	giant.name = 'GiantEgg'
	add_child(giant)
	giant.position = Vector3(23,1.0,-27)
	solid_cylinder(self,Vector3(23,.5,-27),9,1,'purple')
	var model = load('res://assets/models/racer.glb').instantiate()
	giant.add_child(model)
	model.scale = Vector3.ONE*14
	model.rotation.y = -.18
	giant_arm = model.find_child('ArmR',true,false)
	var body := StaticBody3D.new()
	giant.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 6.2
	shape.height = 23
	collider.shape = shape
	collider.position.y = 11.5
	body.add_child(collider)
	sign_at('大大的拥抱',Vector3(23,0,-17))

func _physics_process(delta: float) -> void:
	if get_parent().get_parent().paused: return
	t += delta
	animate_wheel()
	animate_water()
	lift.position.y = .35+(1-cos(t*.55))*5
	if giant_arm: giant_arm.rotation.z = -.3+sin(t*.9)*.18
