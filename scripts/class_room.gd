extends Node
const Catalog = preload('res://scripts/class_catalog.gd')
var game: Node
var selected := 0
var choices := [0,0,0]
var previous := 'island'
var next_mode := ''
var error := ''
func open(after := ''):
	if game.screen not in ['island','menu','duel_result'] or is_instance_valid(game.player.vehicle) or game.modal_open(): return
	previous = game.screen
	next_mode = after
	selected = maxi(0,Catalog.index(game.class_profile.class_id))
	choices = game.class_profile.talents.duplicate()
	error = ''
	game.release_mouse_drive()
	game.feedback.reset()
	game.paused = true
	game.screen = 'career'
	game.hud.queue_redraw()
func choose(index: int):
	if game.screen == 'career' and game.class_profile.class_id == '' and index in range(4): selected = index
func talent(row: int, option: int):
	if game.screen != 'career': return
	if row in range(3) and option in [0,1]: choices[row] = option
func confirm():
	if game.screen != 'career': return
	if game.class_profile.save(Catalog.IDS[selected],choices) != OK:
		error = '保存失败，请重试'
		return
	game.player.skills.career.configure(game.class_profile.class_id,choices)
	close()
	if next_mode == 'duel': game.duel.open_room()
	elif next_mode == 'race': game.join_race()
func close():
	if game.screen != 'career': return
	game.screen = previous
	game.paused = false
	game.hud.queue_redraw()
func draw(h):
	var locked: bool = game.class_profile.class_id != ''
	h.draw_rect(Rect2(0,0,1440,900),Color(.06,.10,.18,.65))
	h.panel(Rect2(85,55,1270,790),h.WHITE,30,true)
	h.txt('职业与天赋' if locked else '创建你的职业角色',Vector2(130,117),36,h.INK,true)
	h.txt('职业随角色保存 · 岛屿、巅峰赛、决斗场共用五个技能',Vector2(132,156),21,h.TEAL)
	if not locked:
		for i in range(4):
			var x := 130+i*300
			h.panel(Rect2(x,188,277,287),Catalog.COLORS[i].lightened(.65) if i == selected else Color('#e7edef'),20)
			h.centered(Catalog.NAMES[i],x+138,232,30,h.INK,true)
			for j in range(5): h.txt(str(j+1)+'  '+Catalog.SKILLS[i][j][1],Vector2(x+24,270+j*29),21,h.INK)
			h.button('class_pick_'+str(i),Rect2(x+20,426,237,40),'已选择' if i == selected else '选择',i == selected)
		for j in range(5): h.txt(Catalog.SKILLS[selected][j][1]+'：'+Catalog.SKILLS[selected][j][4],Vector2(135,520+j*36),22,h.INK)
		h.txt('创建后职业固定；天赋可在岛上调整。皮肤、蛋币与收藏保留。',Vector2(135,724),20,h.TEAL)
	else:
		h.txt(Catalog.NAMES[selected]+' · 固定职业',Vector2(135,207),28,Catalog.COLORS[selected].darkened(.4),true)
		for j in range(5): h.txt(str(j+1)+'  '+Catalog.SKILLS[selected][j][1]+'：'+Catalog.SKILLS[selected][j][4],Vector2(135,249+j*30),21,h.INK)
		for row in range(3):
			for option in range(2):
				var x := 135+option*595
				var y := 423+row*98
				h.button('class_talent_%d_%d' % [row,option],Rect2(x,y,560,48),Catalog.TALENT_NAMES[selected][row][option]+(' ✓' if choices[row] == option else ''),choices[row] == option)
				h.txt(Catalog.TALENT_HINTS[row][option],Vector2(x+15,y+75),19,h.TEAL)
		h.txt('每行二选一，修改只影响原有技能；对局中不能更换。',Vector2(135,748),19,h.TEAL)
	h.button('class_confirm',Rect2(880,770,425,52),'保存天赋' if locked else '创建'+Catalog.NAMES[selected]+'角色')
	h.button('class_close',Rect2(135,770,210,52),'返回',false)
	if error != '': h.txt(error,Vector2(440,805),21,Color('#b45464'))
