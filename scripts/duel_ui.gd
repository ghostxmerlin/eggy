extends RefCounted
const COLORS := [Color('#db8651'),Color('#8b70cb'),Color('#bf609b'),Color('#3c9d8a')]

static func draw(h) -> void:
	var game = h.game
	var duel = game.duel
	if game.screen == 'duel_lobby':
		h.draw_rect(Rect2(0,0,1440,900),Color(.08,.15,.25,.55))
		h.panel(Rect2(120,100,1200,690),h.WHITE,30,true)
		h.txt('蛋仔决斗场',Vector2(170,167),40,h.INK,true)
		h.txt('选择你的职业',Vector2(172,211),25,h.TEAL,true)
		h.txt('1V1 · 对战人机 · 生命归零判负',Vector2(826,177),22,h.TEAL)
		for i in range(4):
			var x := 170.0+i*279
			var chosen: bool = i == duel.selected_class
			h.panel(Rect2(x,252,255,288),COLORS[i].lightened(.79) if chosen else Color('#eef2f3'),24)
			h.draw_circle(Vector2(x+127,328),43,COLORS[i])
			h.centered(duel.CLASSES[i].left(1),x+127,343,36,h.WHITE,true)
			h.centered(duel.CLASSES[i],x+127,409,31,h.INK,true)
			h.centered('专属技能 1 / 2 · 待定',x+127,449,18,h.TEAL)
			h.button('duel_class_'+str(i),Rect2(x+22,477,211,45),'已选择' if chosen else '选择',chosen)
		h.txt('首版共用 100 生命与三个基础技能，职业专属招式稍后加入。',Vector2(172,594),22,h.INK)
		h.txt('3 咸鱼棒：命中扣 20 生命    4 冰锥术：冻结    5 破胆怒吼：恐惧',Vector2(172,631),20,h.TEAL)
		h.button('duel_begin',Rect2(828,684,430,64),'以%s身份进入决斗' % duel.CLASSES[duel.selected_class])
		h.button('island',Rect2(172,684,220,64),'返回岛屿',false)
		h.centered('1–4 选择职业 · Enter 开始',606,729,17,h.INK)
		return
	health_bar(h,Rect2(38,30,468,106),'你 · '+duel.CLASSES[duel.selected_class],0,Color('#229da0'))
	health_bar(h,Rect2(934,30,468,106),'对手 · '+duel.CLASSES[duel.opponent_class],1,Color('#df7192'))
	h.panel(Rect2(560,30,320,96),h.WHITE,22,true)
	h.centered('蛋仔决斗场 · 1V1',720,70,25,h.INK,true)
	h.centered(game.format_time(duel.elapsed),720,106,23,h.TEAL,true)
	h.txt('W/S 前后 · Q/E 平移 · A/D 转向',Vector2(35,811),16,h.INK)
	h.txt('空格 跳跃 · 右键 调整朝向',Vector2(35,839),16,h.INK)
	h.txt('Esc 暂停 / 返回岛屿',Vector2(35,867),16,h.INK)
	h.panel(Rect2(1043,777,362,97),h.WHITE,20)
	h.txt('击败眼前的对手',Vector2(1065,810),22,h.INK,true)
	h.txt('1 / 2 职业技能待定',Vector2(1065,838),17,h.TEAL)
	h.txt('3 攻击  ·  4 冻结  ·  5 恐惧',Vector2(1065,863),17,h.TEAL)
	h.draw_skills()
	if duel.phase == 'countdown' and not game.paused:
		h.panel(Rect2(560,287,320,220),h.WHITE,30,true)
		h.centered('准备开战',720,337,28,h.TEAL,true)
		h.centered(str(maxi(1,ceili(duel.countdown))),720,443,88,h.INK,true)
		h.centered('双方 100 生命',720,479,19,h.INK)
	elif game.screen == 'duel_result':
		h.draw_rect(Rect2(0,0,1440,900),Color(.08,.15,.25,.30))
		h.panel(Rect2(443,247,554,393),h.WHITE,30,true)
		h.centered('决斗胜利！' if duel.winner == 0 else '本局落败',720,322,44,h.TEAL if duel.winner == 0 else COLORS[2],true)
		h.centered('对手生命归零' if duel.winner == 0 else '你的生命归零',720,375,24,h.INK)
		h.centered('战斗用时 '+game.format_time(duel.elapsed),720,416,20,h.TEAL)
		h.button('duel_begin',Rect2(480,457,223,58),'再战一局')
		h.button('duel_room',Rect2(737,457,223,58),'选择职业',false)
		h.button('island',Rect2(480,540,480,56),'返回岛屿',false)
	elif game.paused:
		h.draw_rect(Rect2(0,0,1440,900),Color(.08,.15,.25,.4))
		h.panel(Rect2(465,250,510,355),h.WHITE,30,true)
		h.centered('决斗已暂停',720,315,36,h.INK,true)
		h.button('resume',Rect2(513,355,414,56),'继续决斗')
		h.button('duel_begin',Rect2(513,438,193,56),'重新决斗',false)
		h.button('island',Rect2(734,438,193,56),'返回岛屿',false)
		h.centered('Esc 继续',720,560,18,h.TEAL)

static func health_bar(h, rect: Rect2, title: String, id: int, color: Color) -> void:
	var duel = h.game.duel
	var hp: int = duel.health.get(id,100)
	h.panel(rect,h.WHITE,22,true)
	h.txt(title,rect.position+Vector2(20,34),24,h.INK,true)
	h.txt('%d / 100' % hp,rect.position+Vector2(344,34),22,color,true)
	var bar := Rect2(rect.position+Vector2(20,54),Vector2(rect.size.x-40,29))
	h.panel(bar,Color('#d9e3e8'),12)
	if hp > 0:
		h.panel(Rect2(bar.position,Vector2(bar.size.x*hp/100.0,bar.size.y)),color.lightened(.25) if duel.hurt.get(id,0) > 0 else color,12)
