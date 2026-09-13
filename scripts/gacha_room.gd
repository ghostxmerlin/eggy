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
var effects: Control
var reveal_phase := 'idle'
var hero_title: Label
var hero_note: Label
var skip_button: Button
var cues: Dictionary = {}

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
	for cue in ['charge','open','rare']:
		var player := AudioStreamPlayer.new()
		player.stream = load('res://assets/audio/gacha_'+cue+'.wav')
		player.volume_db = -8
		add_child(player)
		cues[cue] = player
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
	start_reveal()

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

func start_reveal() -> void:
	set_underlay_enabled(false)
	busy = true
	reveal_phase = 'charge'
	result_panel = Control.new()
	result_panel.size = Vector2(1440,900)
	layout.add_child(result_panel)
	effects = preload('res://scripts/gacha_effects.gd').new()
	result_panel.add_child(effects)
	var featured: String = latest[0].id
	var ranks := {'基础':0,'高级':1,'稀有':2,'典藏':3,'至臻':4}
	for reward in latest:
		if ranks[Catalog.get_skin(reward.id).rarity] > ranks[Catalog.get_skin(featured).rarity]: featured = reward.id
	effects.set_prize(featured)
	hero_title = label('正在开启盲盒',Vector2(310,95),40,true)
	hero_title.size.x = 820
	hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_title.add_theme_color_override('font_color',Color('#f3f8ff'))
	move_to(hero_title,result_panel)
	hero_note = label('惊喜即将揭晓',Vector2(310,718),24,true)
	hero_note.size.x = 820
	hero_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_note.add_theme_color_override('font_color',Color('#a7d7ff'))
	move_to(hero_note,result_panel)
	skip_button = button('跳过动画',Rect2(1200,45,176,46),finish_reveal)
	skip_button.add_theme_font_size_override('font_size',18)
	move_to(skip_button,result_panel)
	skip_button.grab_focus()
	cues.charge.play()
	reveal_tween = create_tween()
	reveal_tween.tween_interval(.85)
	reveal_tween.tween_callback(func():
		reveal_phase = 'opening'
		effects.burst()
		cues.open.play()
	)
	reveal_tween.tween_property(effects,'opening',1.0,.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	reveal_tween.tween_callback(func():
		reveal_phase = 'hero'
		effects.reveal()
		hero_title.text = Catalog.get_skin(featured).rarity+'外观登场'
		hero_title.add_theme_color_override('font_color',effects.accent)
		hero_note.text = Catalog.get_skin(featured).name
		cues.rare.play()
	)
	reveal_tween.tween_interval(1.75 if ranks[Catalog.get_skin(featured).rarity] >= 3 else 1.10)
	reveal_tween.tween_callback(finish_reveal)

func finish_reveal() -> void:
	if reveal_phase not in ['charge','opening','hero']: return
	if reveal_tween and reveal_tween.is_valid(): reveal_tween.kill()
	cues.charge.stop()
	cues.open.stop()
	hero_title.hide()
	hero_note.hide()
	skip_button.hide()
	effects.settle()
	reveal_phase = 'cards'
	show_rewards()

func show_rewards() -> void:
	result_cards.clear()
	var title := label('恭喜获得',Vector2(310,113),42,true)
	title.size.x = 820
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override('font_color',Color('#fff3cf'))
	move_to(title,result_panel)
	var note := label('已收入收藏 · 点击奖励查看外观',Vector2(310,176),18)
	note.size.x = 820
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override('font_color',Color('#bed7f8'))
	move_to(note,result_panel)
	for i in range(latest.size()):
		var reward: Dictionary = latest[i]
		var skin := Catalog.get_skin(reward.id)
		var suffix: String = '重复 · +%d 蛋币' % reward.refund if reward.duplicate else '新获得'
		var rect := Rect2(177+(i%5)*219,242+floori(i/5.0)*196,209,180)
		if latest.size() == 1: rect = Rect2(590,254,260,315)
		var card := button('',rect,func():
			dismiss_rewards()
			select_skin(reward.id)
		)
		var tint := Catalog.rarity_color(reward.id).lightened(.22)
		var skin_style := style(Color('#1a294d').lerp(tint,.16),tint)
		skin_style.shadow_color = Color(tint,.24)
		skin_style.shadow_size = 9
		card.add_theme_stylebox_override('normal',skin_style)
		card.add_theme_stylebox_override('disabled',skin_style)
		card.add_theme_stylebox_override('hover',style(Color('#344e72'),Color('#fff2c2')))
		card.clip_contents = true
		var shine := ColorRect.new()
		shine.size = rect.size
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = preload('res://assets/shaders/gacha_card.gdshader')
		material.set_shader_parameter('tint',tint)
		shine.material = material
		card.add_child(shine)
		add_thumbnail(card,reward.id)
		var caption := Label.new()
		caption.text = skin.name+'\n'+skin.rarity+' · '+suffix+(' · 保底' if reward.guaranteed else '')
		caption.position = Vector2(4,116 if latest.size() > 1 else 246)
		caption.size = Vector2(rect.size.x-8,53)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_override('font',bold)
		caption.add_theme_font_size_override('font_size',16 if latest.size() > 1 else 20)
		caption.add_theme_color_override('font_color',Color('#f4f7ff'))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(caption)
		card.tooltip_text = caption.text
		move_to(card,result_panel)
		result_cards.append(card)
		card.pivot_offset = rect.size*.5
		card.scale = Vector2(.86,.86)
		card.modulate.a = 0
		card.disabled = true
	var done := button('收下 · 继续',Rect2(530,715,380,58),dismiss_rewards)
	done.add_theme_stylebox_override('normal',style(Color('#ffe2a0'),Color('#fff1bf')))
	move_to(done,result_panel)
	done.disabled = true
	busy = true
	reveal_tween = create_tween().set_parallel(true)
	for i in range(result_cards.size()):
		var card: Control = result_cards[i]
		reveal_tween.tween_property(card,'modulate:a',1.0,.22).set_delay(i*.055)
		reveal_tween.tween_property(card,'scale',Vector2.ONE,.38).set_delay(i*.055).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal_tween.chain().tween_callback(func():
		busy = false
		reveal_phase = 'results'
		for card in result_cards: card.disabled = false
		done.disabled = false
		done.grab_focus()
	)

func dismiss_rewards() -> void:
	if busy: return
	if is_instance_valid(result_panel):
		result_panel.hide()
		result_panel.queue_free()
		result_panel = null
	effects = null
	reveal_phase = 'idle'
	for cue in cues.values(): cue.stop()
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
	if busy:
		finish_reveal()
		return
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
	for cue in cues.values(): cue.stop()
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
	container.position = Vector2(24,5) if latest.size() > 1 else Vector2(10,12)
	container.size = Vector2(161,112) if latest.size() > 1 else Vector2(240,234)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(container)
	var view := SubViewport.new()
	view.size = Vector2i(container.size)
	view.transparent_bg = true
	view.own_world_3d = true
	# Auto-LOD simplifies the fitted face independently of the shell at card size.
	view.mesh_lod_threshold = 0.0
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var lighting := WorldEnvironment.new()
	lighting.environment = preload('res://scripts/outfit_lighting.gd').environment()
	world.add_child(lighting)
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
