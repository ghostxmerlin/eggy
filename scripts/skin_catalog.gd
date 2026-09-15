extends RefCounted

const SKINS := [
	{'id':'classic','name':'经典小黄','note':'圆滚滚，就是最初的快乐。','shell':'#ffce35','face':'#ffdbac','shoe':'#fffdf6','sole':'#ece6d9','accent':'#ffae24','accessory':''},
	{'id':'peach','name':'蜜桃软糖','note':'像一颗蹦蹦跳跳的桃子糖。','shell':'#f59ab5','face':'#ffe0c4','shoe':'#fff6f6','sole':'#dc8fbc','accent':'#eb7099','accessory':''},
	{'id':'mint','name':'薄荷汽水','note':'清清凉凉，出发去兜风。','shell':'#66d3b2','face':'#ffe1b8','shoe':'#f5fff5','sole':'#4ba99a','accent':'#1ab78c','accessory':''},
	{'id':'sky','name':'晴空蓝蓝','note':'把一小片晴天穿在身上。','shell':'#7fc3fa','face':'#ffdfbc','shoe':'#fcfcff','sole':'#689dd3','accent':'#468cd4','accessory':''},
	{'id':'berry','name':'草莓贝雷','note':'小红帽一歪，今天也很可爱。','shell':'#f6becb','face':'#ffe0c1','shoe':'#fff6e8','sole':'#dc6686','accent':'#d94e70','accessory':'beret'},
	{'id':'royal','name':'金冠派对','note':'戴上小皇冠，快乐地登场。','shell':'#b69ae5','face':'#ffe0bc','shoe':'#fff8df','sole':'#9071b8','accent':'#ffd256','accessory':'crown'},
	{'id': 'scarf', 'name': '暖绒围巾', 'note': '针织围巾和小挎包，出门兜兜风。', 'shell': '#eeb64e', 'face': '#ffdbac', 'shoe': '#eef3f6', 'sole': '#425770', 'accent': '#eb685c', 'accessory': 'scarf', 'rarity': '基础', 'group': 'basic'},
	{'id': 'goggles', 'name': '汽水潜水员', 'note': '护目镜、呼吸管和双气瓶。', 'shell': '#60c4b7', 'face': '#ffdbac', 'shoe': '#eef3f6', 'sole': '#425770', 'accent': '#faf297', 'accessory': 'goggles', 'rarity': '高级', 'group': 'basic'},
	{'id': 'aviator', 'name': '云端飞行员', 'note': '飞行帽和飞行背包，准备起飞。', 'shell': '#d79c77', 'face': '#ffdbac', 'shoe': '#eef3f6', 'sole': '#425770', 'accent': '#925a43', 'accessory': 'aviator', 'rarity': '稀有', 'group': 'basic'},
	{'id': 'worker', 'name': '工坊学徒', 'note': '工具腰带与扳手，今天也要开工。', 'shell': '#eaaf45', 'face': '#ffdbac', 'shoe': '#eef3f6', 'sole': '#425770', 'accent': '#705847', 'accessory': 'worker', 'rarity': '高级', 'group': 'season'},
	{'id': 'safety', 'name': '巡检员', 'note': '安全帽与信号背包，巡检开始。', 'shell': '#84b9d8', 'face': '#ffdbac', 'shoe': '#eef3f6', 'sole': '#425770', 'accent': '#ffd55f', 'accessory': 'safety', 'rarity': '高级', 'group': 'season'},
	{'id': 'rover', 'name': '履带探险家', 'note': '雷达天线与装甲背包，探索未知。', 'shell': '#86aba0', 'face': '#ffdbac', 'shoe': '#eef3f6', 'sole': '#425770', 'accent': '#f3c861', 'accessory': 'rover', 'rarity': '稀有', 'group': 'season'},
	{'id': 'mecha_gale', 'name': '断罪骑士·岚', 'note': '碧蓝轻甲、侧翼与双推进器。', 'shell': '#3daee2', 'face': '#ffdbac', 'shoe': '#eef3f6', 'sole': '#425770', 'accent': '#68eaff', 'accessory': 'gale', 'rarity': '典藏', 'group': 'season'},
	{'id': 'mecha_blaze', 'name': '断罪骑士·烈', 'note': '紫色重甲、厚肩盾与能量核心。', 'shell': '#8b67c7', 'face': '#ffdbac', 'shoe': '#eef3f6', 'sole': '#425770', 'accent': '#e28bff', 'accessory': 'blaze', 'rarity': '典藏', 'group': 'season'},
	{'id': 'mecha', 'name': '断罪骑士·极', 'note': '镜面金甲、日冕光环与流金粒子披风。', 'shell': '#ffbd38', 'face': '#ffdbac', 'shoe': '#eef3f6', 'sole': '#425770', 'accent': '#ffe69a', 'accessory': 'knight', 'rarity': '至臻', 'group': 'season'},
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
	for limb in model.find_children('*','MeshInstance3D',true,false):
		limb.visible = true
		limb.layers = 1
		var attachment := limb.get_node_or_null('OutfitLimb')
		if attachment:
			limb.remove_child(attachment)
			attachment.queue_free()
	var accessories := Node3D.new()
	accessories.name = 'SkinAccessories'
	model.add_child(accessories)
	if skin.get('group','') != '':
		preload('res://scripts/outfit_models.gd').build(model,accessories,skin)
	elif skin.accessory == 'beret':
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

static func rarity_color(id: String) -> Color:
	return {'基础':Color('#82969f'),'高级':Color('#3a967b'),'稀有':Color('#398dc3'),'典藏':Color('#9160c9'),'至臻':Color('#be8030')}.get(get_skin(id).get('rarity','基础'),Color.WHITE)
