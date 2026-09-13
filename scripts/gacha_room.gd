extends 'res://scripts/wardrobe.gd'
const Rules = preload('res://scripts/gacha_rules.gd')
var pool := 'season'
var balance: Label
var protection: Label
var ten_button: Button
var result_panel: Control
var info_panel: Control
var busy := false
var reveal_tween: Tween
var latest: Array = []
var result_cards: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = preload('res://assets/fonts/CloudSans-Medium.ttf')
	bold = preload('res://assets/fonts/CloudSans-Heavy.ttf')
	layout = Control.new()
	add_child(layout)
	label('盲盒工坊',Vector2(146,105),36,true)
	label('本期主题 · 断罪骑士',Vector2(147,153),20)
	button('返回岛屿',Rect2(1150,110,144,48),close).add_theme_font_size_override('font_size',19)
	button('常驻盲盒',Rect2(716,180,175,42),func(): switch_pool('basic')).add_theme_font_size_override('font_size',18)
	button('机甲赛季',Rect2(905,180,175,42),func(): switch_pool('season')).add_theme_font_size_override('font_size',18)
	button('概率说明',Rect2(1094,180,175,42),show_info).add_theme_font_size_override('font_size',18)
	build_preview()
	viewport.get_parent().size = Vector2(510,380)
	title_label = label('',Vector2(177,611),28,true)
	note_label = label('',Vector2(177,653),17)
	status_label = label('',Vector2(716,595),17)
	status_label.size.x = 552
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balance = label('',Vector2(716,111),25,true)
	protection = label('',Vector2(716,635),17)
	wear_button = button('抽一次 · 60',Rect2(716,699,267,59),func(): pull(1))
	ten_button = button('抽十次 · 540',Rect2(997,699,272,59),func(): pull(10))
	button('添加蛋币 · 回车',Rect2(177,713,265,45),func(): game.coin_console.open()).add_theme_font_size_override('font_size',18)
	button('衣柜',Rect2(455,713,175,45),func():
		close()
		game.wardrobe.open()
	).add_theme_font_size_override('font_size',18)
	resized.connect(rescale)
	rescale()
	switch_pool('season')
	hide()

func open() -> void:
	if game.screen != 'island' or game.paused or is_instance_valid(game.player.vehicle): return
	if not game.player.is_on_floor() or game.player.skills.controlled(): return
	game.release_mouse_drive()
	game.paused = true
	dragging = false
	preview.rotation = Vector3(0,-.25,0)
	refresh_balance()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	show()
	wear_button.grab_focus()
	game.hud.queue_redraw()

func switch_pool(value: String) -> void:
	if busy or is_instance_valid(result_panel) or is_instance_valid(info_panel): return
	pool = value
	for card in cards.values():
		card.hide()
		card.queue_free()
	cards.clear()
	var entries: Array = Catalog.SKINS.filter(func(s): return s.get('group','') == pool)
	if pool == 'season': entries.reverse()
	for i in range(entries.size()):
		var skin: Dictionary = entries[i]
		var card := button(skin.name+'\n'+skin.rarity,Rect2(716+(i%2)*282,241+floori(i/2.0)*111,270,101),func(): select_skin(skin.id))
		card.add_theme_font_size_override('font_size',21)
		cards[skin.id] = card
	select_skin(entries[0].id)
	refresh_balance()

func refresh_balance() -> void:
	if not balance: return
	balance.text = '蛋币  %d' % game.skin_store.coins
	protection.text = ('再抽 %d 次内必出典藏或至臻\n前三次高阶不重复 · 三套集齐' % (50-game.skin_store.pity)) if pool == 'season' else '基础 70% · 高级 20% · 稀有 10%\n重复外观自动返还蛋币'
	wear_button.text = '抽一次 · %d' % Rules.cost(pool,1)
	ten_button.text = '抽十次 · %d' % Rules.cost(pool,10)
	for id in cards:
		var skin := Catalog.get_skin(id)
		cards[id].text = skin.name+'\n'+skin.rarity+(' · 已拥有' if id in game.skin_store.owned else '')

func select_skin(id: String) -> void:
	selected_id = id
	Catalog.apply(preview,id)
	var skin := Catalog.get_skin(id)
	title_label.text = skin.name
	note_label.text = skin.note
	status_label.text = '已拥有 · 可前往衣柜穿上' if id in game.skin_store.owned else '点击卡片预览 · 拖动模型旋转'
	for key in cards:
		cards[key].add_theme_stylebox_override('normal',style(Catalog.rarity_color(key).lightened(.84),Catalog.rarity_color(key) if key == id else Color.TRANSPARENT))

func pull(count: int) -> void:
	if busy or not visible or is_instance_valid(result_panel) or is_instance_valid(info_panel): return
	var result: Dictionary = game.skin_store.draw(pool,count)
	if not result.ok:
		status_label.text = result.message
		return
	latest = result.rewards
	refresh_balance()
	show_rewards()

func overlay() -> Control:
	set_underlay_enabled(false)
	var control := Control.new()
	layout.add_child(control)
	control.size = Vector2(1440,900)
	var shade := ColorRect.new()
	shade.color = Color(.05,.12,.2,.85)
	shade.size = Vector2(1440,900)
	control.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(125,120)
	panel.size = Vector2(1190,660)
	panel.add_theme_stylebox_override('panel',style(Color('#fffdf3')))
	control.add_child(panel)
	return control

func move_to(node: Control, target: Control) -> void:
	node.reparent(target)

func show_rewards() -> void:
	result_panel = overlay()
	result_cards.clear()
	move_to(label('开启盲盒',Vector2(177,154),34,true),result_panel)
	move_to(label('已收入收藏 · 点击奖励可查看外观',Vector2(177,201),19),result_panel)
	for i in range(latest.size()):
		var reward: Dictionary = latest[i]
		var skin := Catalog.get_skin(reward.id)
		var suffix: String = '+%d 蛋币' % reward.refund if reward.duplicate else '新获得'
		var card := button(skin.rarity+'\n'+skin.name+'\n'+suffix+(' · 保底' if reward.guaranteed else ''),Rect2(177+(i%5)*219,271+floori(i/5.0)*179,209,161),func():
			dismiss_rewards()
			select_skin(reward.id)
		)
		card.add_theme_font_size_override('font_size',16)
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.text = ''
		var caption := Label.new()
		caption.text = skin.name+' · '+skin.rarity+'\n'+suffix+(' · 保底' if reward.guaranteed else '')
		caption.position = Vector2(4,100)
		caption.size = Vector2(201,43)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_override('font',bold)
		caption.add_theme_font_size_override('font_size',16)
		caption.add_theme_color_override('font_color',Color('#24455b'))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(caption)
		card.tooltip_text = caption.text
		add_thumbnail(card,reward.id)
		card.add_theme_stylebox_override('normal',style(Catalog.rarity_color(reward.id).lightened(.80),Catalog.rarity_color(reward.id)))
		move_to(card,result_panel)
		result_cards.append(card)
		card.modulate.a = 0
		card.disabled = true
	var done := button('收下 · 继续',Rect2(530,683,380,58),dismiss_rewards)
	move_to(done,result_panel)
	done.disabled = true
	busy = true
	reveal_tween = create_tween()
	for card in result_cards:
		reveal_tween.tween_property(card,'modulate:a',1.0,.09)
	reveal_tween.tween_callback(func():
		busy = false
		for card in result_cards: card.disabled = false
		done.disabled = false
		done.grab_focus()
		game.sound('checkpoint')
	)

func dismiss_rewards() -> void:
	if busy: return
	if is_instance_valid(result_panel):
		result_panel.hide()
		result_panel.queue_free()
		result_panel = null
	set_underlay_enabled(true)
	wear_button.grab_focus()

func show_info() -> void:
	if busy or is_instance_valid(result_panel) or is_instance_valid(info_panel): return
	info_panel = overlay()
	move_to(label('抽取概率与规则',Vector2(177,155),32,true),info_panel)
	var text := '常驻盲盒：基础 70% / 高级 20% / 稀有 10%\n机甲赛季：高级 63.99% / 稀有 23.89% / 典藏 10.49% / 至臻 1.63%\n同品质内等概率。以上为基础概率；保底与不重复保护会提高高阶实际占比。\n\n赛季至多 50 抽得典藏或至臻，提前获得则重置。\n首次集齐前，高阶奖励不重复；至多 150 抽集齐极、岚、烈。\n\n单抽 / 十连：常驻 10 / 90 蛋币，赛季 60 / 540 蛋币。\n重复返币：常驻基础 2、高级 3、稀有 5；赛季高级 5、稀有 10、典藏 30、至臻 60。\n\n品质概率参考官方台港澳 2023 公示，保底参考 2025 更新。\n本地机甲主题池：精简套装、返币和价格为本地设定，不含隐藏款与限时折扣。\n断罪骑士原为限定盲盒；此处按机甲主题编排，不是当期正式服奖池。'
	move_to(label(text,Vector2(177,223),19),info_panel)
	var done := button('知道了',Rect2(530,691,380,56),dismiss_info)
	move_to(done,info_panel)
	done.grab_focus()

func dismiss_info() -> void:
	if is_instance_valid(info_panel):
		info_panel.hide()
		info_panel.queue_free()
		info_panel = null
	set_underlay_enabled(true)
	wear_button.grab_focus()

func close() -> void:
	if busy: return
	if is_instance_valid(result_panel):
		dismiss_rewards()
		return
	if is_instance_valid(info_panel):
		dismiss_info()
		return
	super.close()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1440,900))
	draw_rect(Rect2(0,0,1440,900),Color(.04,.12,.22,.79))
	draw_style_box(style(Color('#f4f8fc')),Rect2(105,80,1230,722))
	draw_style_box(style(Color('#dce9f4')),Rect2(145,208,514,400))

func shutdown() -> void:
	if reveal_tween and reveal_tween.is_valid(): reveal_tween.kill()
	busy = false
	dismiss_rewards()
	dismiss_info()
	super.close()

func set_underlay_enabled(enabled: bool) -> void:
	for node in layout.get_children():
		if node is Button:
			node.disabled = not enabled
			node.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func add_thumbnail(card: Button, id: String) -> void:
	var container := SubViewportContainer.new()
	container.position = Vector2(42,4)
	container.size = Vector2(125,98)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(container)
	var view := SubViewport.new()
	view.size = Vector2i(125,98)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var model := preload('res://assets/models/racer.glb').instantiate()
	world.add_child(model)
	Catalog.apply(model,id)
	model.rotation.y = -.24
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30,-30,0)
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,135,0)
	fill.light_energy = .6
	world.add_child(fill)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,1.4,5.5)
	camera.look_at(Vector3(0,1.05,0))
	camera.fov = 27
