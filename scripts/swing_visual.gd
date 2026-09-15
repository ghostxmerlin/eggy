extends Node3D
const Motion = preload('res://scripts/swing_motion.gd')
const Shapes = preload('res://scripts/outfit_models.gd')
var kit: Node3D
var club: Node3D
var saber: Node3D
var trail: MeshInstance3D
var flash: Node3D
var laser := false
var visual_time := 0.0
var hit_pause := 0.0
var flash_left := 0.0
var impacted := false
var arm_links: Array[MeshInstance3D] = []

func _ready() -> void:
	kit = get_parent()
	club = Node3D.new()
	club.name = 'FishAppearance'
	add_child(club)
	var silver = kit.material(Color('#a6dfdd'))
	var blue = kit.material(Color('#4e91b0'))
	var cream = kit.material(Color('#fff1c2'))
	kit.ellipsoid(club,Vector3(0,.63,0),Vector3(.24,.66,.16),silver)
	kit.ellipsoid(club,Vector3(0,.80,.11),Vector3(.19,.35,.08),cream)
	for side in [-1,1]:
		var tail = kit.ellipsoid(club,Vector3(side*.14,-.06,0),Vector3(.17,.27,.075),blue)
		tail.rotation.z = side*.65
		var fin = kit.ellipsoid(club,Vector3(side*.23,.51,0),Vector3(.18,.08,.09),blue)
		fin.rotation.z = side*.5
		kit.ellipsoid(club,Vector3(side*.115,1.03,.14),Vector3(.071,.082,.052),cream)
		kit.ellipsoid(club,Vector3(side*.115,1.04,.185),Vector3(.033,.041,.025),kit.material(Color('#264b68')))
	kit.ellipsoid(club,Vector3(0,1.22,.04),Vector3(.10,.045,.10),blue)
	for i in range(2):
		var link := Shapes.mesh(self,CylinderMesh.new(),Vector3.ZERO,Vector3.ONE,Shapes.mat(Color.WHITE))
		link.mesh.top_radius = 1
		link.mesh.bottom_radius = 1
		link.mesh.height = 1
		link.mesh.radial_segments = 12
		link.top_level = true
		arm_links.append(link)
	build_saber()
	trail = MeshInstance3D.new()
	trail.name = 'DescendingSlashTrail'
	add_child(trail)
	trail.top_level = true
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash = Node3D.new()
	add_child(flash)
	flash.top_level = true
	var light = kit.material(Color(3,1.9,.7,.9),true)
	for i in range(6):
		var ray = kit.ellipsoid(flash,Vector3.ZERO,Vector3(.028,.28,.028),light)
		ray.rotation = Vector3(i*.83,i*1.7,i*.62)
	flash.hide()
	hide()

func build_saber() -> void:
	saber = Node3D.new()
	saber.name = 'PinkLaserSword'
	add_child(saber)
	var grip := Shapes.mat(Color('#352641'))
	var gold := Shapes.mat(Color('#ffdc75'))
	Shapes.tube(saber,[Vector3(0,-.16,0),Vector3(0,.18,0)],.052,grip)
	for y in [-.1,-.035,.03,.095]: Shapes.ring(saber,Vector3(0,y,0),.058,gold)
	Shapes.box(saber,Vector3(0,.2,0),Vector3(.24,.065,.10),gold)
	var core := Shapes.mat(Color('#ffe4fb'),true)
	core.emission = Color('#ff70c8')
	core.emission_energy_multiplier = 3.0
	Shapes.tube(saber,[Vector3(0,.23,0),Vector3(0,1.25,0)],.036,core)
	var aura = kit.material(Color(2.4,.06,.8,.30),true)
	Shapes.tube(saber,[Vector3(0,.23,0),Vector3(0,1.25,0)],.070,aura)
	saber.hide()

func begin() -> void:
	laser = kit.racer.skin_id == 'mecha'
	for link in arm_links:
		link.material_override.albedo_color = Color(preload('res://scripts/skin_catalog.gd').get_skin(kit.racer.skin_id).shell)
	club.visible = not laser
	saber.visible = laser
	trail.material_override = kit.material(Color(1.7,.12,.8,.42) if laser else Color(1,.82,.38,.40),true)
	visual_time = 0
	hit_pause = 0
	flash_left = 0
	impacted = false
	flash.hide()
	show()
	advance(0,0)

func advance(elapsed: float, delta: float) -> void:
	if hit_pause > 0: hit_pause = maxf(0,hit_pause-delta)
	else: visual_time = move_toward(visual_time,elapsed,delta*2.0)
	var points := Motion.pose(kit.attack_forward,visual_time)
	var direction := (points[1]-points[0]).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	var grip := points[0]+direction*.23
	var length_scale := grip.distance_to(points[1])/1.27
	transform = Transform3D(Basis(side*1.5,direction*length_scale,side.cross(direction)*1.5),grip)
	update_trail()
	flash_left = maxf(0,flash_left-delta)
	flash.visible = flash_left > 0
	if flash.visible: flash.scale = Vector3.ONE*(.4+sin((1.0-flash_left/.13)*PI)*.7)

func update_trail() -> void:
	var end := Motion.phase(visual_time)
	var start := Motion.phase(maxf(Motion.WINDUP,visual_time-.075))
	trail.visible = end > start+.005
	if not trail.visible: return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(14):
		var a := Motion.shaft(kit.attack_forward,lerpf(start,end,i/14.0))
		var b := Motion.shaft(kit.attack_forward,lerpf(start,end,(i+1)/14.0))
		var inside_a := a[0].lerp(a[1],.50)
		var inside_b := b[0].lerp(b[1],.50)
		for vertex in [inside_a,a[1],inside_b,a[1],b[1],inside_b]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	trail.mesh = surface.commit()
	trail.global_transform = kit.global_transform

func impact(point: Vector3) -> void:
	# A brief visual catch on first contact; gameplay clock and impulses keep running.
	if not impacted:
		visual_time = Motion.DURATION-kit.attack_left
		hit_pause = .045
		impacted = true
	flash.global_position = point
	flash_left = .13
	flash.show()

func cancel() -> void:
	hit_pause = 0
	flash_left = 0
	trail.hide()
	flash.hide()
	hide()

func sync_hands() -> void:
	var racer = kit.racer
	for i in range(2):
		var part := 'ArmL' if i == 0 else 'ArmR'
		if not racer.limbs.has(part): continue
		var arm: Node3D = racer.limbs[part][0]
		var grip := to_global(Vector3(0,-.04-i*.12,0))
		arm.position = racer.model.to_local(grip)-arm.basis*Vector3(0,-.12,.035)
		var link := arm_links[i]
		link.visible = not racer.model.has_node('SkinAccessories/OutfitRig')
		if not link.visible: continue
		var shoulder: Vector3 = racer.model.to_global(racer.limbs[part][1]+Vector3(.1 if i == 0 else -.1,.14,0))
		var offset := grip-shoulder
		var aligned := Basis(Quaternion(Vector3.UP,offset.normalized()))
		link.global_transform = Transform3D(Basis(aligned.x*.085,aligned.y*maxf(.01,offset.length()),aligned.z*.085),(shoulder+grip)*.5)
