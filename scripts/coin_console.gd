extends Control
var game: Node3D
var field: LineEdit
var message: Label
var panel: PanelContainer
var prior_pause := false
var prior_focus: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color('#f4f8fa')
	style.set_corner_radius_all(20)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override('panel',style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override('separation',12)
	panel.add_child(column)
	message = Label.new()
	message.add_theme_font_override('font',preload('res://assets/fonts/CloudSans-Medium.ttf'))
	message.add_theme_font_size_override('font_size',21)
	message.add_theme_color_override('font_color',Color('#24455b'))
	column.add_child(message)
	field = LineEdit.new()
	field.placeholder_text = '+500'
	field.max_length = 10
	field.custom_minimum_size = Vector2(550,48)
	field.add_theme_font_override('font',preload('res://assets/fonts/CloudSans-Medium.ttf'))
	field.add_theme_font_size_override('font_size',24)
	column.add_child(field)
	field.text_submitted.connect(submit)
	var hint := Label.new()
	hint.text = '回车确认 · Esc 关闭 · 仅增加本地蛋币'
	hint.add_theme_font_override('font',preload('res://assets/fonts/CloudSans-Medium.ttf'))
	hint.add_theme_color_override('font_color',Color('#496779'))
	column.add_child(hint)
	resized.connect(rescale)
	rescale()
	hide()

func rescale() -> void:
	panel.position = Vector2(400,330)*size/Vector2(1440,900)
	panel.scale = size/Vector2(1440,900)
	queue_redraw()

func open() -> void:
	if visible or game.screen != 'island': return
	prior_pause = game.paused
	prior_focus = get_viewport().gui_get_focus_owner()
	game.release_mouse_drive()
	game.paused = true
	message.text = '添加蛋币 · 当前余额 %d' % game.skin_store.coins
	field.text = ''
	show()
	field.grab_focus()
	game.hud.queue_redraw()

func submit(command: String) -> void:
	var result: Dictionary = game.skin_store.credit(command)
	message.text = result.message
	if result.ok:
		game.toast = result.message
		game.toast_time = 3
		close()
	else: field.select_all()

func close() -> void:
	if not visible: return
	hide()
	field.release_focus()
	game.paused = prior_pause
	if is_instance_valid(prior_focus) and prior_focus.is_visible_in_tree(): prior_focus.grab_focus()
	game.gacha.refresh_balance()
	game.hud.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.05,.12,.20,.65))
