extends Control

var game: Node
var font: Font
var bold: Font
var buttons: Dictionary = {}
var styles: Dictionary = {}
var widths: Dictionary = {}
var pointer := Vector2.ZERO
const INK := Color('#24455b')
const TEAL := Color('#167f86')
const WHITE := Color('#fffdf3')
const Items = preload('res://scripts/item_catalog.gd')

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	font = load('res://assets/fonts/CloudSans-Medium.ttf')
	bold = load('res://assets/fonts/CloudSans-Heavy.ttf')

func panel(rect: Rect2, color: Color, radius := 20, shadow := false) -> void:
	var key := color.to_html()+str(radius)+str(shadow)
	if not styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		if shadow:
			style.shadow_color = Color(0.09,.20,.29,.14)
			style.shadow_size = 10
			style.shadow_offset = Vector2(0,5)
		styles[key] = style
	draw_style_box(styles[key],rect)

func txt(text: String, pos: Vector2, size_px := 22, color := INK, strong := false) -> void:
	draw_string(bold if strong else font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func centered(text: String, x: float, y: float, size_px: int, color := INK, strong := false) -> void:
	var f := bold if strong else font
	var key := text+str(size_px)+str(strong)
	if not widths.has(key):
		if widths.size()>2048: widths.clear()
		widths[key] = f.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
	var width: float = widths[key]
	txt(text,Vector2(x-width*.5,y),size_px,color,strong)

func button(id: String, rect: Rect2, text: String, primary := true) -> void:
	buttons[id] = rect
	var hover := rect.has_point(pointer)
	panel(Rect2(rect.position+Vector2(0,5),rect.size),Color('#0f636f') if primary else Color('#d3dfdf'),20)
	panel(rect,Color('#259ea0') if hover and primary else TEAL if primary else WHITE,20,true)
	centered(text,rect.get_center().x,rect.position.y+rect.size.y*.5+9,26,WHITE if primary else INK,true)

func _draw() -> void:
	if not game or not font or DisplayServer.get_name() == 'headless': return
	var scale_factor := size/Vector2(1440,900)
	draw_set_transform(Vector2.ZERO,0,scale_factor)
	buttons.clear()
	if not game.in_island: draw_item_obstruction()
	var menu: bool = game.screen == 'menu'
	if game.screen == 'island':
		draw_island()
	elif menu:
		# Light translucent editorial panel lets the world remain the hero.
		panel(Rect2(44,50,224,38),Color(1,.99,.94,.92),19)
		txt('CLOUD CLUB   /   01',Vector2(62,76),18,TEAL,true)
		draw_string_outline(bold,Vector2(48,192),'云端',HORIZONTAL_ALIGNMENT_LEFT,-1,86,10,Color(1,1,.96,.75))
		txt('云端',Vector2(48,192),86,INK,true)
		draw_string_outline(bold,Vector2(48,287),'冲冲赛',HORIZONTAL_ALIGNMENT_LEFT,-1,86,10,Color(1,1,.96,.75))
		txt('冲冲赛',Vector2(48,287),86,INK,true)
		txt('脚下是云，前方是终点。',Vector2(53,335),25,INK)
		panel(Rect2(52,372,280,39),Color(1,1,.96,.87),19)
		txt('单人练习  ·  第一关  ·  不限时' if game.practice else '巅峰派对  ·  第一关  ·  竞速',Vector2(67,398),18,TEAL,true)
		button('start',Rect2(52,672,296,70),'开始练习  →' if game.practice else '出发，冲向终点  →')
		txt('只有你一个人，随时重来、反复练习' if game.practice else '32 位选手出发，前 24 名晋级',Vector2(56,779),20,INK)
		panel(Rect2(1110,48,280,44),Color(1,.99,.95,.92),22)
		centered('单人操作   /   自由练习' if game.practice else '单机挑战   /   云端乐园',1250,77,19,INK,true)
		panel(Rect2(53,827,1030,38),Color(1,1,.96,.80),16)
		txt('W/S 前后   Q/E 平移   A/D 转向   空格 跳跃   1–5 技能   鼠标双键 前进   Esc 暂停',Vector2(70,853),18,INK)
		txt('一路向前  ·  放心起跳',Vector2(1135,854),17,INK)
	else:
		panel(Rect2(30,28,298,80),Color(1,.99,.96,.95),22,true)
		panel(Rect2(42,40,56,56),TEAL,17)
		centered('01',70,78,27,WHITE,true)
		txt('云端冲冲赛',Vector2(111,65),24,INK,true)
		txt('单人练习  ·  操作体验' if game.practice else '巅峰派对  ·  竞速晋级',Vector2(111,91),16,TEAL)
		panel(Rect2(1120,28,290,80),Color(1,.99,.96,.95),22,true)
		if game.practice:
			txt('自由练习',Vector2(1140,62),23,TEAL,true)
			txt('不限时',Vector2(1314,62),19,INK)
			txt('练习用时',Vector2(1140,91),15,INK)
			txt(game.format_time(game.rules.elapsed),Vector2(1262,91),20,INK,true)
		else:
			txt('已晋级',Vector2(1140,60),18,INK)
			txt('%02d / 24' % game.rules.order.size(),Vector2(1220,63),28,TEAL,true)
			var left: float = maxf(0,150-game.rules.elapsed)
			txt('剩余时间',Vector2(1140,91),15,INK)
			txt('%02d:%02d' % [int(left)/60,int(left)%60],Vector2(1285,91),20,INK,true)
		if game.screen == 'racing':
			panel(Rect2(31,128,130,42),Color(.13,.26,.34,.83),16)
			centered('自由练习' if game.practice else '第 %02d 名' % game.current_place(),96,157,21,WHITE,true)
			panel(Rect2(440,702,560,68),Color(1,.99,.96,.94),24,true)
			txt('起点',Vector2(461,731),15,TEAL,true)
			txt('终点',Vector2(943,731),15,TEAL,true)
			panel(Rect2(507,720,424,10),Color('#d8e8de'),5)
			var progress: float = clampf((game.course.START_Z-game.player.position.z)/(game.course.START_Z-game.course.FINISH_Z),0,1)
			panel(Rect2(507,720,maxf(10,424*progress),10),TEAL,5)
			for checkpoint in game.course.CHECKPOINTS.slice(1):
				var ratio: float = (game.course.START_Z-checkpoint.z)/(game.course.START_Z-game.course.FINISH_Z)
				draw_circle(Vector2(507+424*ratio,725),4,Color('#fff0b5'))
			txt('风车 / 门廊       高空窄桥       连续断桥',Vector2(552,754),15,INK)
			txt('W/S 前后 · Q/E 平移 · A/D 转向',Vector2(34,822),16,INK)
			txt('空格 跳跃 / R 道具 / T 回检查点',Vector2(34,846),17,INK)
			txt('Esc 暂停',Vector2(35,874),15,INK)
		if game.rules.phase == 'countdown':
			draw_rect(Rect2(0,0,1440,900),Color(.13,.27,.35,.10))
			panel(Rect2(570,260,300,245),Color(1,.99,.94,.93),40,true)
			centered('准备出发',720,313,27,TEAL,true)
			centered(str(maxi(1,ceili(game.rules.countdown))),720,445,112,INK,true)
			centered('越过障碍，抢先抵达终点',720,477,18,INK)
		elif game.go_time > 0 and game.screen == 'racing':
			centered('冲呀！',720,350,70,WHITE,true)
		if game.toast_time > 0 and game.screen == 'racing':
			panel(Rect2(514,125,412,49),Color(1,.97,.81,.95),24,true)
			centered(game.toast,720,158,20,INK,true)
		if game.screen == 'result':
			draw_rect(Rect2(0,0,1440,900),Color(.1,.23,.29,.24))
			panel(Rect2(463,206,514,466),WHITE,32,true)
			var qualified: bool = game.player_place > 0
			centered('PRACTICE' if game.practice else ('QUALIFIED' if qualified else 'TRY AGAIN'),720,270,21,TEAL,true)
			centered('练习完成！' if game.practice else ('成功晋级！' if qualified else '再冲一次吧'),720,339,47,INK,true)
			centered('到达终点' if game.practice else ('第 %d 名' % game.player_place if qualified else '终点在等你'),720,418,43,TEAL,true)
			centered('用时  %s' % game.format_time(game.finish_time) if qualified else '躲开转杆，跳过间隙，抓住滚动时机',720,461,21,INK)
			centered('第一关挑战完成' if qualified else '每一次起跳都会更熟练',720,501,18,INK)
			button('retry',Rect2(497,541,225,62),'再跑一局')
			button('island',Rect2(738,541,204,62),'返回岛屿',false)
			centered('Enter 重新出发    ·    Esc 返回岛屿',720,646,16,INK)
	if game.screen in ['island','racing']: draw_skills()
	if game.paused and not (game.wardrobe and game.wardrobe.visible):
		draw_rect(Rect2(0,0,1440,900),Color(.10,.20,.27,.40))
		panel(Rect2(465,230,510,400),WHITE,32,true)
		centered('歇一口气',720,304,42,INK,true)
		centered('岛上休息一下' if game.in_island else ('练习已暂停' if game.practice else '比赛已暂停'),720,347,21,TEAL)
		button('resume',Rect2(530,382,380,60),'继续逛逛' if game.in_island else '继续比赛')
		if game.in_island:
			button('join',Rect2(530,474,380,58),'参赛',false)
		else:
			button('restart',Rect2(530,464,182,58),'重新出发',false)
			button('island',Rect2(728,464,182,58),'返回岛屿',false)
		centered('Esc 继续  ·  右键拖动调整视角',720,598,17,INK)
	if game.items and game.items.enabled and game.screen == 'racing' and not game.paused: draw_item_slot()
	if game.show_metrics and not menu:
		panel(Rect2(34,184,280,96),Color(.09,.18,.24,.86),12)
		txt('%d FPS   /   %.2f ms' % [Engine.get_frames_per_second(),game.last_frame_ms],Vector2(48,217),20,WHITE,true)
		txt('渲染 %d 次  ·  %.1f 万三角形' % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)/10000],Vector2(48,246),15,WHITE)
		txt('F3 关闭性能面板',Vector2(48,269),14,WHITE)

func draw_island() -> void:
	panel(Rect2(30,28,378,94),WHITE,27,true)
	draw_circle(Vector2(74,73),26,Color('#ffcf65'))
	draw_circle(Vector2(66,70),3,INK)
	draw_circle(Vector2(82,70),3,INK)
	draw_arc(Vector2(74,72),10,.2,PI-.2,16,INK,2.5,true)
	txt('宜之有之派对',Vector2(114,69),30,INK,true)
	txt('蛋仔岛',Vector2(115,100),19,TEAL,true)
	panel(Rect2(1208,34,198,44),Color(1,.99,.96,.92),22)
	centered('今天也要开心玩',1307,63,19,TEAL,true)
	panel(Rect2(34,745,396,124),Color(1,.99,.96,.94),24,true)
	if is_instance_valid(game.player.vehicle):
		txt('环岛飞行中',Vector2(56,780),22,INK,true)
		txt('右键 看风景 · Esc 暂停',Vector2(56,814),16,TEAL)
		txt('落地开舱后即可下机',Vector2(56,845),16,TEAL)
	else:
		txt('到处逛逛，试试技能',Vector2(56,780),22,INK,true)
		txt('W/S 前后 · Q/E 平移 · A/D 转向',Vector2(56,814),16,TEAL)
		txt('空格 跳跃 · 鼠标双键 前进',Vector2(56,845),16,TEAL)
	if not is_instance_valid(game.player.vehicle): button('wardrobe',Rect2(1220,646,184,54),'衣柜 · B',false)
	panel(Rect2(1064,723,342,145),WHITE,28,true)
	txt('云端冲冲赛',Vector2(1087,757),23,INK,true)
	txt('第一关 · 32 位选手 · 前 24 名晋级',Vector2(1087,782),16,TEAL)
	button('join',Rect2(1085,799,300,53),'参赛')
	txt('Esc 休息一下  /  T 回到广场',Vector2(37,893),14,INK)

func draw_item_slot() -> void:
	var id: String = game.player.item_state.held
	var color := Items.color(id)
	panel(Rect2(1050,694,356,176),WHITE,24,true)
	panel(Rect2(1066,709,44,36),color,10)
	centered('R',1088,735,23,WHITE,true)
	txt(Items.title(id),Vector2(1124,738),25,INK,true)
	txt(Items.description(id),Vector2(1067,775),16,TEAL)
	txt('按 R 使用 · 右键转动镜头瞄准',Vector2(1067,809),16,INK)
	txt('一次携带一个 · 问号箱会重新出现',Vector2(1067,844),15,TEAL)
	var state = game.player.item_state
	if state.boost > 0 or state.jetpack > 0:
		var label := '加速 %.1f 秒' % state.boost if state.boost > 0 else '喷气 %.1f 秒' % state.jetpack
		panel(Rect2(1090,628,276,45),Color('#edbb37'),16)
		centered(label,1228,658,21,INK,true)

func draw_item_obstruction() -> void:
	var state = game.player.item_state
	if state.ink > 0:
		var alpha: float = minf(1.0,state.ink)*.80
		for entry in [[430,330,125],[1020,375,150],[770,220,90],[590,570,115],[1130,200,60]]:
			draw_circle(Vector2(entry[0],entry[1]),entry[2],Color(.12,.06,.18,alpha))
		for i in range(9):
			draw_circle(Vector2(320+i*94,460+sin(i*2.1)*150),20+i%3*8,Color(.15,.08,.22,alpha))
		panel(Rect2(550,184,340,42),Color('#563867'),16)
		centered('墨汁干扰 %.1f 秒' % state.ink,720,213,23,WHITE,true)
	if state.smoke > 0:
		draw_rect(Rect2(0,0,1440,690),Color(.68,.75,.81,.48))
		centered('云雾遮挡',720,255,23,INK,true)

func _gui_input(event: InputEvent) -> void:
	var factor := size/Vector2(1440,900)
	if event is InputEventMouseMotion:
		pointer = event.position/factor
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		for rect in buttons.values():
			if rect.has_point(pointer): mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not game.mouse_forward:
		pointer = event.position/factor
		for key in buttons:
			if buttons[key].has_point(pointer):
				game.ui_action(key)
				accept_event()
				break

func draw_skills() -> void:
	var kit = game.player.skills
	var colors := [Color('#167f86'),Color('#d67b30'),Color('#467d9a'),Color('#329aca'),Color('#9661b4')]
	for i in range(5):
		var x := 450.0+i*110
		var cd: float = kit.cooldown(i+1)
		var riding: bool = is_instance_valid(game.player.vehicle)
		var ready: bool = cd <= 0 and not kit.controlled() and game.player.active and not riding
		panel(Rect2(x,785,100,84),WHITE if ready else Color('#d6e2e3'),17,true)
		panel(Rect2(x+8,792,22,22),colors[i],7)
		centered(str(i+1),x+19,809,15,WHITE,true)
		centered(kit.NAMES[i],x+50,835,17,INK,true)
		centered('乘坐中' if riding else ('%.1f 秒' % cd if cd > 0 else ('受控' if kit.controlled() else '就绪')),x+50,858,14,colors[i],true)
		if cd > 0:
			draw_line(Vector2(x+10,873),Vector2(x+10+80*(1-cd/kit.COOLDOWNS[i]),873),colors[i],3,true)
