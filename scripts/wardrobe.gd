extends Control

const Catalog = preload('res://scripts/skin_catalog.gd')
var game: Node3D
var layout: Control
var viewport: SubViewport
var preview: Node3D
var selected_id := 'classic'
var cards: Dictionary = {}
var title_label: Label
var note_label: Label
var status_label: Label
var wear_button: Button
var category := 'legacy'
var dragging := false
var bold: Font
var font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = preload('res://assets/fonts/CloudSans-Medium.ttf')
	bold = preload('res://assets/fonts/CloudSans-Heavy.ttf')
	layout = Control.new()
	add_child(layout)
	label('我的衣柜',Vector2(146,111),36,true)
	label('挑一套喜欢的，快乐出发。',Vector2(147,159),18)
	var close_button := button('返回岛屿',Rect2(1150,113,144,48),close)
	close_button.add_theme_font_size_override('font_size',19)
	build_preview()
	for i in range(3):
		var group: String = ['legacy','basic','season'][i]
		button(['基础外观','常驻套装','赛季套装'][i],Rect2(716+i*190,204,181,40),func(): show_category(group)).add_theme_font_size_override('font_size',18)
	title_label = label('',Vector2(716,156),28,true)
	note_label = label('',Vector2(719,608),19)
	status_label = label('',Vector2(719,643),17)
	button('左转',Rect2(263,704,126,48),func(): preview.rotation.y -= PI/6)
	button('右转',Rect2(411,704,126,48),func(): preview.rotation.y += PI/6)
	wear_button = button('穿上这套',Rect2(716,704,270,58),confirm)
	button('取消',Rect2(1000,704,269,58),close)
	label('拖动蛋仔可以旋转查看',Vector2(289,662),17)
	show_category('legacy')
	resized.connect(rescale)
	rescale()
	hide()

func rescale() -> void:
	layout.scale = size/Vector2(1440,900)
	queue_redraw()

func style(color: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(18)
	box.set_border_width_all(3)
	box.border_color = border
	return box

func label(text: String, position: Vector2, pixels: int, strong := false) -> Label:
	var node := Label.new()
	node.text = text
	node.position = position
	node.add_theme_font_override('font',bold if strong else font)
	node.add_theme_font_size_override('font_size',pixels)
	node.add_theme_color_override('font_color',Color('#24455b'))
	layout.add_child(node)
	return node

func button(text: String, rect: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override('font',bold)
	node.add_theme_font_size_override('font_size',23)
	node.add_theme_color_override('font_color',Color('#24455b'))
	node.add_theme_color_override('font_hover_color',Color('#167f86'))
	node.add_theme_color_override('font_focus_color',Color('#24455b'))
	node.add_theme_color_override('font_pressed_color',Color('#167f86'))
	node.add_theme_stylebox_override('normal',style(Color('#e7f0e9')))
	node.add_theme_stylebox_override('hover',style(Color('#f6faee'),Color('#75c3b5')))
	node.add_theme_stylebox_override('pressed',style(Color('#b9e3d7'),Color('#167f86')))
	node.add_theme_stylebox_override('focus',style(Color.TRANSPARENT,Color('#167f86')))
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(action)
	layout.add_child(node)
	return node

func build_preview() -> void:
	var container := SubViewportContainer.new()
	container.position = Vector2(147,210)
	container.size = Vector2(510,438)
	container.stretch = true
	container.mouse_default_cursor_shape = Control.CURSOR_DRAG
	layout.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(510,438)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color('#e5f2e6')
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color('#ffffff')
	settings.ambient_light_energy = .35
	settings.tonemap_mode = Environment.TONE_MAPPER_ACES
	settings.tonemap_exposure = .75
	environment.environment = settings
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-35,0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_energy = .35
	world.add_child(fill)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,1.55,5.7)
	camera.look_at(Vector3(0,1.02,0))
	camera.fov = 29
	preview = preload('res://assets/models/racer.glb').instantiate()
	world.add_child(preview)
	var base := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.05
	cylinder.bottom_radius = 1.05
	cylinder.height = .14
	cylinder.radial_segments = 64
	base.mesh = cylinder
	base.position.y = -.07
	base.material_override = Catalog.material(Color('#ccdfcc'))
	world.add_child(base)
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		if event is InputEventMouseMotion and dragging: preview.rotation.y += event.relative.x*.012
	)

func open() -> void:
	if game.screen != 'island' or game.paused or is_instance_valid(game.player.vehicle): return
	if not game.player.is_on_floor() or game.player.skills.controlled() or game.player.roll_left > 0 or game.player.skills.dive_left > 0 or game.player.skills.attack_left > 0: return
	game.release_mouse_drive()
	game.paused = true
	preview.rotation = Vector3.ZERO
	dragging = false
	show_category(Catalog.get_skin(game.skin_store.selected_id).get('group','legacy'))
	select_skin(game.skin_store.selected_id)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	show()
	wear_button.grab_focus()
	game.hud.queue_redraw()

func select_skin(id: String) -> void:
	selected_id = Catalog.get_skin(id).id
	Catalog.apply(preview,selected_id)
	var skin := Catalog.get_skin(selected_id)
	title_label.text = skin.name
	note_label.text = skin.note
	wear_button.disabled = selected_id not in game.skin_store.owned
	status_label.text = '未拥有 · 可预览，抽取后即可穿上' if wear_button.disabled else '当前正在穿着' if selected_id == game.skin_store.selected_id else '试穿中 · 穿上后自动保存'
	for key in cards:
		var entry := Catalog.get_skin(key)
		cards[key].add_theme_stylebox_override('normal',style(Color(entry.shell).lightened(.65),Color('#167f86') if key == selected_id else Color.TRANSPARENT))
	wear_button.text = '等待解锁' if wear_button.disabled else '穿着出发' if selected_id == game.skin_store.selected_id else '穿上这套'

func confirm() -> void:
	if not visible: return
	if game.skin_store.save_skin(selected_id) != OK:
		status_label.text = '暂时无法保存，请重试'
		return
	game.player.set_skin(selected_id)
	close()

func close() -> void:
	if not visible: return
	hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused and is_ancestor_of(focused): focused.release_focus()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	dragging = false
	game.paused = false
	game.release_mouse_drive()
	game.hud.queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1440,900))
	draw_rect(Rect2(0,0,1440,900),Color(.10,.20,.27,.55))
	draw_style_box(style(Color('#fffdf3')),Rect2(105,87,1230,711))
	draw_style_box(style(Color('#e6f0e5')),Rect2(145,208,514,442))

func show_category(group: String) -> void:
	category = group
	for card in cards.values():
		card.hide()
		card.queue_free()
	cards.clear()
	var entries: Array = Catalog.SKINS.filter(func(skin): return skin.get('group','legacy') == group)
	for i in range(entries.size()):
		var skin: Dictionary = entries[i]
		var owned: bool = skin.id in game.skin_store.owned
		var text: String = skin.name+'\n'+skin.get('rarity','基础')+(' · 已拥有' if owned else ' · 未拥有')
		var card := button(text,Rect2(716+(i%2)*287,254+floori(i/2.0)*109,269,99),func(): select_skin(skin.id))
		card.add_theme_font_size_override('font_size',20)
		cards[skin.id] = card
