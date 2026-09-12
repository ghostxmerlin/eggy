extends RefCounted

const SKINS := [
	{'id':'classic','name':'经典小黄','note':'圆滚滚，就是最初的快乐。','shell':'#ffce35','face':'#ffdbac','shoe':'#fffdf6','sole':'#ece6d9','accent':'#ffae24','accessory':''},
	{'id':'peach','name':'蜜桃软糖','note':'像一颗蹦蹦跳跳的桃子糖。','shell':'#f59ab5','face':'#ffe0c4','shoe':'#fff6f6','sole':'#dc8fbc','accent':'#eb7099','accessory':''},
	{'id':'mint','name':'薄荷汽水','note':'清清凉凉，出发去兜风。','shell':'#66d3b2','face':'#ffe1b8','shoe':'#f5fff5','sole':'#4ba99a','accent':'#1ab78c','accessory':''},
	{'id':'sky','name':'晴空蓝蓝','note':'把一小片晴天穿在身上。','shell':'#7fc3fa','face':'#ffdfbc','shoe':'#fcfcff','sole':'#689dd3','accent':'#468cd4','accessory':''},
	{'id':'berry','name':'草莓贝雷','note':'小红帽一歪，今天也很可爱。','shell':'#f6becb','face':'#ffe0c1','shoe':'#fff6e8','sole':'#dc6686','accent':'#d94e70','accessory':'beret'},
	{'id':'royal','name':'金冠派对','note':'戴上小皇冠，快乐地登场。','shell':'#b69ae5','face':'#ffe0bc','shoe':'#fff8df','sole':'#9071b8','accent':'#ffd256','accessory':'crown'},
]

static func has_skin(id: String) -> bool:
	for skin in SKINS:
		if skin.id == id: return true
	return false

static func get_skin(id: String) -> Dictionary:
	for skin in SKINS:
		if skin.id == id: return skin
	return SKINS[0]

static func apply(model: Node3D, id: String) -> void:
	var skin := get_skin(id)
	var colors := {'Shell':Color(skin.shell),'Face':Color(skin.face),'White':Color(skin.shoe),'Sole':Color(skin.sole)}
	var materials := {}
	for mesh_node in model.find_children('*','MeshInstance3D',true,false):
		for index in range(mesh_node.mesh.get_surface_count()):
			var original: Material = mesh_node.mesh.surface_get_material(index)
			if original and colors.has(original.resource_name):
				var key: String = original.resource_name
				if not materials.has(key):
					var material: StandardMaterial3D = original.duplicate()
					material.albedo_color = colors[key]
					materials[key] = material
				mesh_node.set_surface_override_material(index,materials[key])
	var old := model.get_node_or_null('SkinAccessories')
	if old:
		model.remove_child(old)
		old.queue_free()
	var accessories := Node3D.new()
	accessories.name = 'SkinAccessories'
	model.add_child(accessories)
	if skin.accessory == 'beret':
		accessories.rotation.z = -.13
		part(accessories,Vector3(0,1.74,.04),Vector3(.60,.15,.52),Color(skin.accent))
		part(accessories,Vector3(.08,1.89,.04),Vector3(.065,.11,.065),Color('#934356'))
		part(accessories,Vector3(-.08,1.88,.04),Vector3(.15,.035,.075),Color('#69af70'))
	elif skin.accessory == 'crown':
		var gold := Color(skin.accent)
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = .34
		mesh.outer_radius = .41
		mesh.rings = 24
		mesh.ring_segments = 8
		ring.mesh = mesh
		ring.position.y = 1.62
		ring.material_override = material(gold)
		accessories.add_child(ring)
		for i in range(5):
			var angle := TAU*i/5.0
			var post := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = .018
			cone.bottom_radius = .13
			cone.height = .28
			cone.radial_segments = 12
			post.mesh = cone
			post.position = Vector3(sin(angle)*.35,1.74,cos(angle)*.35)
			post.material_override = ring.material_override
			accessories.add_child(post)
			part(accessories,post.position+Vector3(0,.14,0),Vector3.ONE*.045,Color('#fff0a2'))

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = .4
	return result

static func part(parent: Node3D, position: Vector3, scale: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 24
	sphere.rings = 12
	node.mesh = sphere
	node.position = position
	node.scale = scale
	node.material_override = material(color)
	parent.add_child(node)
