extends SceneTree
const Motion = preload('res://scripts/swing_motion.gd')
var failures: Array[String] = []
var game: Node
var visual := false
func _initialize(): call_deferred('run')
func frames(n: int):
	for i in range(n): await physics_frame
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func capture(label: String):
	if visual:
		game.paused = true
		await frames(2)
		await game.screenshot(label)
		game.paused = false
func run():
	visual = '--visual' in OS.get_cmdline_user_args()
	game = load('res://main.tscn').instantiate()
	game.skin_save_path = 'user://swing-visual-isolated.cfg'
	root.add_child(game)
	game.set_process_input(false)
	game.player.external_control = true
	await frames(45)
	var player = game.player
	var kit = player.skills
	var targets = get_nodes_in_group('combatants').filter(func(r): return r != player)
	var target = targets[0]
	for other in targets:
		other.training_home = Vector3(-35,0,0)
		other.position = other.training_home
		other.set_physics_process(false)
	game.set_process(false)
	game.camera_yaw = 0
	game.camera.position = Vector3(-15,3.6,25)
	game.camera.look_at(Vector3(-20,1.1,29))
	game.camera.fov = 43
	var high := Motion.shaft(Vector3.FORWARD,0)[1]
	var low := Motion.shaft(Vector3.FORWARD,1)[1]
	check(high.y-low.y > 1.0 and high.x*low.x < 0,'Strike tip descends and crosses to the other side')
	check(Motion.phase(.13)-Motion.phase(.10) < Motion.phase(.26)-Motion.phase(.23),'Strike accelerates after the windup')
	var impulses: Array[Vector3] = []
	for id in ['classic','mecha','mecha_blaze']:
		player.reset_to_start(Vector3(-20,0,30))
		player.set_skin(id)
		player.active = true
		player.external_control = true
		player.drive = Vector2.ZERO
		target.position = Vector3(-20,0,28)
		target.velocity = Vector3.ZERO
		target.skills.reset()
		await frames(4)
		if kit.fish.has_meta('captured'): kit.fish.remove_meta('captured')
		check(kit.use_skill(3),'Strike starts for '+id)
		check(kit.fish.saber.visible == (id == 'mecha') and kit.fish.club.visible == (id != 'mecha'),'Only gold supreme equips the pink laser sword')
		check(is_equal_approx(kit.cooldown(3),4.0),'Weapon appearance preserves four-second cooldown')
		await frames(4)
		for hand_index in range(2):
			var arm: Node3D = player.limbs['ArmL' if hand_index == 0 else 'ArmR'][0]
			check(arm.to_global(Vector3(0,-.12,.035)).distance_to(kit.fish.to_global(Vector3(0,-.04-hand_index*.12,0))) < .01,'Animated hand stays on the grip')
			var link: MeshInstance3D = kit.fish.arm_links[hand_index]
			if link.visible:
				check(absf(link.global_basis.x.dot(link.global_basis.y)) < .001,'Arm bridge scales along its own axis without shear')
		await capture('swing-'+id+'-windup')
		await frames(8)
		await capture('swing-'+id+'-slash')
		var saw_stop := false
		for i in range(12):
			await frames(1)
			saw_stop = saw_stop or kit.fish.hit_pause > 0
			if kit.fish.hit_pause > 0 and visual and not kit.fish.has_meta('captured'):
				kit.fish.set_meta('captured',true)
				await capture('swing-'+id+'-impact')
		check(kit.swing_hits.size() == 1 and saw_stop,'Real contact produces one hit and visual impact pause')
		impulses.append(target.velocity)
		var once: Vector3 = target.velocity
		kit.sweep_contacts(0,1)
		check(target.velocity == once,'The same swing never hits its victim twice')
		await capture('swing-'+id+'-follow')
		await frames(20)
		check(not kit.fish.visible and not kit.fish.trail.visible,'Recovery removes weapon and slash trail')
	check(impulses[0].is_equal_approx(impulses[1]) and impulses[0].is_equal_approx(impulses[2]),'Fish and laser apply identical impulses')
	kit.reset(true)
	player.set_skin('mecha')
	target.position = Vector3(-35,0,0)
	kit.use_skill(3)
	await frames(11)
	game.paused = true
	var time: float = kit.fish.visual_time
	var attack: float = kit.attack_left
	await frames(10)
	check(time == kit.fish.visual_time and attack == kit.attack_left,'Pause freezes the slash and its visual clock')
	game.paused = false
	kit.apply_freeze()
	check(not kit.fish.visible and not kit.fish.trail.visible and kit.fish.hit_pause == 0,'Status interruption removes blade, trail and hit pause')
	kit.reset(true)
	check(kit.use_skill(3),'Can attack after reset')
	player.respawn()
	check(not kit.fish.visible and kit.attack_left == 0,'Respawn cancels the slash')
	game.queue_free()
	await process_frame
	print('SWING VISUAL: ','PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
