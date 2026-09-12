extends 'res://scripts/course.gd'

const SPAWN := Vector3(0,.12,24)
var pushables: Array[RigidBody3D] = []

func build_world() -> void:
	# A soft cake-shaped floating island, with a flat, reliable walking surface.
	cylinder(self,Vector3(0,-1.5,0),48,2.6,'cream')
	cylinder(self,Vector3(0,-.12,0),47.7,.24,'mint')
	sphere(self,Vector3(0,-5,0),Vector3(47,4,47),'purple')
	var ground := StaticBody3D.new()
	add_child(ground)
	var shape := CylinderShape3D.new()
	shape.radius = 47.7
	shape.height = 2.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -1.3
	ground.add_child(collider)
	# Cream plaza and stepping-stone promenades.
	cylinder(self,Vector3(0,.025,-5),14,.05,'cream')
	for i in range(10):
		block(self,Vector3(0,.05,10+i*2.25),Vector3(3.5,.08,1.5),'cream')
	for side in [-1,1]:
		for i in range(4):
			var stone := block(self,Vector3(side*(10+i*2.7),.055,2+i*.5),Vector3(1.8,.09,2.8),'cream')
			stone.rotation.y = side*-.22
	build_monument()
	build_house(Vector3(-18,0,10),'pink','purple')
	build_house(Vector3(17,0,2),'yellow','orange')
	for data in [[-40,8,1.25],[-33,26,1.1],[-19,36,1.2],[8,40,1.1],[39,26,1.2],[43,-4,1.1],[-15,-37,1.4],[-40,-18,1.1],[0,-40,1.25]]:
		build_tree(Vector3(data[0],0,data[1]),data[2])
	for side in [-1,1]:
		build_bench(Vector3(side*12,0,9),side*-.5)
		for i in range(3):
			flower(Vector3(side*(9+i*1.1),.12,12+sin(i*1.5)), 'pink' if side<0 else 'yellow')
		for i in range(3):
			flower(Vector3(side*(8+i*1.2),.12,-13-i*.7),'yellow' if side<0 else 'pink')
		# Squishy egg-shaped welcome bollards.
		for z in [11,18]:
			sphere(self,Vector3(side*3.7,.55,z),Vector3(.45,.62,.45),'white')
			sphere(self,Vector3(side*3.7,1.17,z),Vector3(.20,.18,.20),'orange')
	var attractions = load('res://scripts/attractions.gd').new()
	attractions.name = 'Attractions'
	add_child(attractions)
	build_training_area()
	# Outlying miniature islets suggest a whole little world beyond the plaza.
	for i in range(7):
		var a := float(i)*TAU/7
		var pos := Vector3(cos(a)*68,-3,sin(a)*68)
		sphere(self,pos,Vector3(7,2.5,6),'cloud',false)
		sphere(self,pos+Vector3(2,-.4,1),Vector3(6,2.5,5),'cloud',false)
		if i%2==0:
			var balloon := Node3D.new()
			add_child(balloon)
			balloon.position = pos+Vector3(0,12,0)
			sphere(balloon,Vector3.ZERO,Vector3(2,2.6,2),'pink' if i==0 else 'yellow',false)
			block(balloon,Vector3(0,-3.4,0),Vector3(1.2,.8,1.2),'cream')
			for side in [-1,1]: cylinder(balloon,Vector3(side*.45,-2.8,0),.045,1.2,'cream')
			floaters.append(balloon)

func build_training_area() -> void:
	cylinder(self,Vector3(-9,.025,21),5.2,.05,'cream')
	var label := lettering(self,'技能练习区',Vector3(-9,2.7,16),52,Color('#167f86'))
	label.font = load('res://assets/fonts/CloudSans-Heavy.ttf')
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	for i in range(3):
		var dummy = preload('res://scripts/racer.gd').new()
		dummy.game = get_parent()
		dummy.racer_id = 40+i
		dummy.training_dummy = true
		dummy.training_jump = i == 2
		dummy.training_home = [Vector3(-7,.1,22),Vector3(-10,.1,20),Vector3(-7,.1,18)][i]
		add_child(dummy)
		dummy.reset_to_start(dummy.training_home)
		dummy.active = true
	for i in range(2):
		var box := RigidBody3D.new()
		box.name = 'PracticeBox'+str(i)
		box.mass = 1.0
		box.collision_layer = 4
		box.collision_mask = 7
		box.linear_damp = 1.0
		box.angular_damp = 2.0
		box.continuous_cd = true
		box.position = Vector3(-12-i*2,.65,24-i*2)
		box.set_meta('home',box.position)
		var friction := PhysicsMaterial.new()
		friction.friction = .45
		friction.bounce = .12
		box.physics_material_override = friction
		add_child(box)
		box.add_to_group('practice_pushables')
		block(box,Vector3.ZERO,Vector3.ONE*1.2,'pink' if i == 0 else 'yellow')
		for x in [-.23,.23]:
			sphere(box,Vector3(x,.15,.6),Vector3(.10,.12,.045),'dark',false)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE*1.2
		collision.shape = shape
		box.add_child(collision)
		pushables.append(box)

func solid_sphere(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> void:
	sphere(parent,pos,size,color)
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for ring in range(9):
		var latitude := PI*ring/8.0
		for segment in range(16):
			var longitude := TAU*segment/16.0
			points.append(Vector3(sin(latitude)*cos(longitude),cos(latitude),sin(latitude)*sin(longitude))*size)
	shape.points = points
	collider.shape = shape
	body.add_child(collider)

func build_monument() -> void:
	var monument := Node3D.new()
	monument.name = 'PartyBillboard'
	add_child(monument)
	monument.position = Vector3(0,0,-14)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color('#fff3a8')
	lamp.emission_enabled = true
	lamp.emission = Color('#ffda73')
	lamp.emission_energy_multiplier = 2.4
	palette['lamp'] = lamp
	for x in [-6.8,6.8]:
		solid_cylinder(monument,Vector3(x,4.4,0),.38,8.8,'mint_dark')
		block(monument,Vector3(x,.4,0),Vector3(2.1,.8,2.1),'orange',true)
		cylinder(monument,Vector3(x,2.1,0),.43,.25,'yellow')
	block(monument,Vector3(0,9,0),Vector3(18.6,9.8,1.2),'mint_dark',true)
	block(monument,Vector3(0,9,.68),Vector3(17.6,8.8,.3),'dark')
	var letters = load('res://assets/models/island_letters.glb').instantiate()
	monument.add_child(letters)
	letters.position = Vector3(0,4.1,1.0)
	var glyphs = letters.find_children('*','MeshInstance3D',true,false)
	if glyphs.size() == 6: glyphs[4].material_override = palette['cream']
	for x in range(-8,9,2):
		for y in [4.6,13.4]: sphere(monument,Vector3(x,y,.9),Vector3.ONE*.18,'lamp',false)
	for x in [-8.7,8.7]:
		for y in [6.4,8.6,10.8]: sphere(monument,Vector3(x,y,.9),Vector3.ONE*.18,'lamp',false)
	for x in [-6.8,6.8]:
		var light := OmniLight3D.new()
		monument.add_child(light)
		light.position = Vector3(x,11.8,2.4)
		light.light_color = Color('#ffe5a0')
		light.light_energy = .7
		light.omni_range = 6
		sphere(monument,Vector3(x,14.2,0),Vector3(.6,.5,.6),'lamp',false)

func build_tree(pos: Vector3, size_factor: float) -> void:
	var tree := Node3D.new()
	add_child(tree)
	tree.position = pos
	tree.scale = Vector3.ONE*size_factor
	solid_sphere(tree,Vector3(0,1.0,0),Vector3(.55,1.25,.55),'orange')
	solid_sphere(tree,Vector3(0,3.2,0),Vector3(2.1,2.1,1.9),'mint')
	sphere(tree,Vector3(-1.3,2.8,.2),Vector3(1.3,1.5,1.35),'mint')
	sphere(tree,Vector3(1.25,2.95,-.1),Vector3(1.4,1.5,1.4),'mint')
	for p in [Vector3(-.8,3.5,1.5),Vector3(.7,2.5,1.6)]: sphere(tree,p,Vector3.ONE*.35,'yellow')
	cylinder(tree,Vector3(0,.08,0),2.1,.16,'cream')

func build_house(pos: Vector3, body_color: String, roof_color: String) -> void:
	var house := Node3D.new()
	add_child(house)
	house.position = pos
	house.rotation.y = .3 if pos.x<0 else -.3
	cylinder(house,Vector3(0,.15,0),4.1,.3,'cream')
	solid_sphere(house,Vector3(0,2.3,0),Vector3(3.3,3.1,2.8),body_color)
	sphere(house,Vector3(0,4.45,0),Vector3(3.65,1.5,3.05),roof_color)
	sphere(house,Vector3(0,5.75,0),Vector3(.7,.7,.7),'cream')
	# A face-like doorway and two round windows make every house feel alive.
	sphere(house,Vector3(0,1.15,2.65),Vector3(.9,1.3,.18),'white')
	sphere(house,Vector3(0,1.1,2.82),Vector3(.66,1.05,.1),'mint_dark')
	for x in [-1.8,1.8]:
		sphere(house,Vector3(x,2.7,2.25),Vector3(.6,.65,.17),'white')
		sphere(house,Vector3(x,2.7,2.41),Vector3(.40,.44,.08),'mint_dark')
	block(house,Vector3(0,.18,3.45),Vector3(2.4,.35,1.6),'white',true)

func build_bench(pos: Vector3, angle: float) -> void:
	var bench := Node3D.new()
	add_child(bench)
	bench.position = pos
	bench.rotation.y = angle
	block(bench,Vector3(0,.7,0),Vector3(3.4,.4,1.2),'purple',true)
	block(bench,Vector3(0,1.25,-.48),Vector3(3.4,1.0,.35),'pink',true)
	for x in [-1.1,1.1]: cylinder(bench,Vector3(x,.3,0),.24,.6,'cream')

func flower(pos: Vector3, color: String) -> void:
	cylinder(self,pos+Vector3(0,.42,0),.08,.8,'mint_dark')
	for i in range(5):
		var a := float(i)*TAU/5
		sphere(self,pos+Vector3(cos(a)*.30,.95+sin(a)*.30,0),Vector3(.25,.25,.16),color,false)
	sphere(self,pos+Vector3(0,.95,.15),Vector3(.19,.19,.12),'cream',false)

func hazard_at(_pos: Vector3) -> Vector3:
	return Vector3.ZERO

func _physics_process(delta: float) -> void:
	for box in pushables:
		box.freeze = get_parent().paused
		if box.position.y < -6:
			box.position = box.get_meta('home')
			box.linear_velocity = Vector3.ZERO
			box.angular_velocity = Vector3.ZERO
			box.reset_physics_interpolation()
	if get_parent().paused: return
	t += delta
	for i in range(floaters.size()):
		floaters[i].rotation.z = sin(t*.55+i)*.06
