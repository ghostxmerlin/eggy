extends Node3D
const Catalog = preload('res://scripts/class_catalog.gd')
var base: Node3D
var racer: CharacterBody3D
var class_id := ''
var talents := [0,0,0]
var states := {}
var combo := 0
var pending := {}
var missiles: Array = []
var traps: Array = []
var melee := {}
var fx: Node3D
var control_grace := 0.0
var ai_clock := 0.0
var storm_tick := 0.0
var pose_left := 0.0
var spin_angle := 0.0
var cast_count := {}
var hit_count := {}
func _ready():
	base = get_parent()
	racer = base.racer
	fx = preload('res://scripts/class_effects.gd').new()
	add_child(fx)
func enabled() -> bool: return class_id in Catalog.IDS
func configure(id: String, choices := [0,0,0]):
	reset()
	class_id = id if id in Catalog.IDS else ''
	talents = choices.duplicate()
	base.remaining.fill(0.0)
func color() -> Color:
	return Catalog.COLORS[Catalog.index(class_id)] if enabled() else Color('#ffdfa2')
func duration(slot: int) -> float:
	var value: float = Catalog.skill(class_id,slot)[2]
	if talents[0] == 1 and slot in [1,2]: value *= .82
	if talents[2] == 1 and slot == 4: value *= .8
	return value
func blocked() -> bool: return states.has('stun') or states.has('block') or states.has('trap')
func busy() -> bool: return not pending.is_empty() or states.has('storm')
func can_target(target, radius: float, cone := PI) -> bool:
	if not is_instance_valid(target) or target == racer or not target.active or target.finished: return false
	var offset: Vector3 = target.global_position-racer.global_position
	if absf(offset.y) > 2.5 or offset.length() > radius: return false
	if target.skills.career.states.has('stealth') and offset.length() > 1.7: return false
	if base.forward().dot(offset.normalized()) < cos(cone): return false
	var ray := PhysicsRayQueryParameters3D.create(racer.global_position+Vector3.UP,target.global_position+Vector3.UP,5)
	return racer.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func targets(radius: float, cone := PI) -> Array:
	var result: Array = []
	for target in get_tree().get_nodes_in_group('combatants'):
		if can_target(target,radius,cone): result.append(target)
	result.sort_custom(func(a,b): return racer.position.distance_squared_to(a.position) < racer.position.distance_squared_to(b.position))
	return result
func use(slot: int) -> bool:
	if slot < 1 or slot > 5 or racer.game.paused or not racer.active or racer.finished or is_instance_valid(racer.vehicle): return false
	var data: Array = Catalog.skill(class_id,slot)
	var id: String = data[0]
	# Ice Block breaks control, Blink breaks roots; other hard control prevents actions.
	if (blocked() or base.controlled()) and id != 'block': return false
	if base.remaining[slot-1] > 0 or base.attack_left > 0 or busy() or base.dive_left > 0: return false
	if states.has('root') and id in ['charge','shadowstep','disengage']: return false
	var found := targets(12.0,deg_to_rad(55))
	var target = found[0] if not found.is_empty() else null
	if id in ['charge','shadowstep','kidney'] and target == null: return false
	if id in ['kidney','eviscerate'] and combo == 0: return false
	if id == 'kidney' and not can_target(target,3.0,deg_to_rad(70)): return false
	if id == 'charge' and (racer.position.distance_to(target.position) < 2 or racer.position.distance_to(target.position) > 9*(1.2 if talents[2] == 0 else 1.0)): return false
	if id in ['blink','disengage','shadowstep']:
		var length := 5.0*(1.2 if talents[2] == 0 else 1.0)
		var destination: Vector3 = racer.position+base.forward()*length*(-1 if id == 'disengage' else 1)
		if id == 'shadowstep':
			if racer.position.distance_to(target.position) > length+1: return false
			destination = target.position-target.skills.forward()*1.5
		if not relocate(destination,id): return false
		if id == 'shadowstep':
			var facing: Vector3 = target.position-racer.position
			if racer.is_player: racer.game.camera_yaw = atan2(-facing.x,-facing.z)
			else: racer.pivot.rotation.y = atan2(facing.x,facing.z)
	base.remaining[slot-1] = duration(slot)
	cast_count[id] = cast_count.get(id,0)+1
	var ambush := states.has('stealth')
	states.erase('stealth')
	var strength: float = data[3]*(1.15 if talents[0] == 0 else 1.0)
	if ambush: strength *= 1.3
	var factor := 1.25 if talents[1] == 0 else 1.0
	match id:
		'mortal','sinister','eviscerate','raptor':
			if id == 'eviscerate':
				strength += combo*8*(1.15 if talents[0] == 0 else 1.0)
				combo = 0
			melee = {'id':id,'damage':strength}
			base.attack_forward = base.forward()
			base.attack_left = base.Swing.DURATION
			base.attack_pending = true
			base.swing_hits.clear()
			base.fish.begin()
		'storm':
			states.storm = 1.6
			storm_tick = 0
			fx.pulse(id,racer.position,color(),2.8,1.0)
		'shout':
			for victim in targets(5): apply_control(victim,'fear',1.7*factor)
			fx.pulse(id,racer.position,color(),5,.65)
		'charge':
			var offset: Vector3 = target.position-racer.position
			offset.y = 0
			base.dive_left = minf(.5,offset.length()/22)
			base.dive_direction = offset.normalized()
			base.dive_speed = 22
			pending = {'id':id,'time':base.dive_left,'target':target,'damage':strength,'control':factor}
			fx.pulse(id,racer.position,color(),1,.5)
		'reflect':
			states.reflect = 2.0
			fx.pulse(id,racer.position,color())
		'frostbolt','aimed':
			pose_left = 1.25
			pending = {'id':id,'time':.65 if id == 'frostbolt' else 1.0,'duration':.65 if id == 'frostbolt' else 1.0,'damage':strength,'direction':base.forward()}
			fx.pulse('cast',racer.position+Vector3.UP,color(),.5,.65)
		'lance','arcane': launch(id,strength,base.forward())
		'nova':
			for victim in targets(4.8):
				deal(victim,strength,id)
				apply_control(victim,'root',1.5*factor)
			fx.pulse(id,racer.position,color(),4.8,.75)
		'block':
			base.cancel_action()
			base.frozen_left = 0
			base.fear_left = 0
			states.clear()
			states.block = 2.2
			fx.pulse(id,racer.position,color())
		'kidney':
			apply_control(target,'stun',(.45+combo*.35)*factor)
			combo = 0
			fx.pulse('hit',target.position+Vector3.UP,color())
		'stealth': states.stealth = 5.0
		'trap':
			var pos: Vector3 = racer.position+base.forward()*2.3
			var ray := PhysicsRayQueryParameters3D.create(pos+Vector3.UP*2,pos+Vector3.DOWN*5,1)
			var floor_hit := racer.get_world_3d().direct_space_state.intersect_ray(ray)
			if not floor_hit.is_empty(): pos.y = floor_hit.position.y+.08
			var node := Node3D.new()
			add_child(node)
			node.top_level = true
			node.global_position = pos
			fx.ring(node,Vector3.ZERO,.72,Color('#9ce8ff'))
			for i in range(8): fx.shard(node,Vector3(sin(i*TAU/8)*.65,.12,cos(i*TAU/8)*.65),.07,.25,Color('#dffaff'))
			traps.append({'node':node,'left':8.0,'arm':.6,'control':2.0*factor})
		_:
			if id == 'blink': states.erase('root')
	if id not in ['mortal','sinister','eviscerate','raptor']: sound(id)
	return true
func relocate(destination: Vector3, id: String) -> bool:
	var from := racer.position
	var travel := destination-from
	travel.y = 0
	var collision := KinematicCollision3D.new()
	var mask := racer.collision_mask
	if id in ['blink','shadowstep']: racer.collision_mask = 5
	if racer.test_move(racer.global_transform,travel,collision): travel = collision.get_travel()* .95
	racer.collision_mask = mask
	if travel.length() < .4: return false
	var pos := from+travel
	var ray := PhysicsRayQueryParameters3D.create(pos+Vector3.UP*1.5,pos+Vector3.DOWN*3,1)
	var floor_hit := racer.get_world_3d().direct_space_state.intersect_ray(ray)
	if floor_hit.is_empty() or absf(floor_hit.position.y-from.y) > 1.0: return false
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .52
	capsule.height = 1.7
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,pos+Vector3.UP*.9)
	query.collision_mask = 2
	query.exclude = [racer.get_rid()]
	if not racer.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	fx.pulse(id,from,color(),.85,.65)
	if id == 'disengage':
		base.dive_left = .36
		base.dive_direction = travel.normalized()
		base.dive_speed = travel.length()/.36
		racer.velocity.y = 4.2
	else:
		racer.position = Vector3(pos.x,maxf(from.y,floor_hit.position.y+.08),pos.z)
		racer.velocity = Vector3.ZERO
	racer.reset_physics_interpolation()
	fx.pulse(id,racer.position,color(),.85,.65)
	return true
func sound(id: String): racer.game.feedback.play('class_'+id,racer)
func on_melee(victim):
	if melee.is_empty(): return
	var id: String = melee.id
	if deal(victim,melee.damage,id) and racer.active:
		if id == 'sinister': combo = mini(3,combo+1)
		if id == 'mortal' and victim.active: victim.skills.career.states.wound = 3.0
		var direction: Vector3 = victim.position-racer.position
		direction.y = 0
		victim.skills.receive_impulse(direction.normalized()*(8 if id == 'raptor' else 3),.3)
func apply_control(victim, kind: String, seconds: float) -> bool:
	var other = victim.skills.career
	if not victim.active or victim.finished or other.states.has('block') or other.states.has('storm'): return false
	if other.control_grace > 0:
		other.fx.number('抵抗',Color('#dce2ec'))
		return false
	if racer.game.screen in ['racing','result']: seconds = minf(seconds,.65)
	if other.enabled() and other.talents[1] == 1: seconds *= .75
	other.control_grace = seconds+1.4
	other.states[kind] = seconds
	if kind != 'root':
		victim.skills.cancel_action()
		other.pending.clear()
	if kind == 'fear':
		victim.skills.apply_fear(racer.position)
		victim.skills.fear_left = seconds
	if kind == 'trap': victim.skills.frozen_left = seconds
	other.fx.pulse('nova' if kind in ['root','trap'] else 'hit',victim.position,Color('#91dcff') if kind in ['root','trap'] else Color('#e6b7ff'),.9)
	other.sound('stun' if kind == 'stun' else 'freeze' if kind in ['root','trap'] else 'shout')
	return true
func deal(victim, amount: float, id: String, reflected := false) -> bool:
	if not is_instance_valid(victim) or not victim.active or victim.finished or racer.game.paused: return false
	var other = victim.skills.career
	if other.states.has('block'):
		other.fx.number('免疫',Color('#b1efff'))
		other.sound('immune')
		return false
	if id in ['frostbolt','lance','arcane'] and other.states.has('reflect') and not reflected:
		other.states.erase('reflect')
		other.fx.number('反射',Color('#ffe598'))
		other.fx.pulse('reflect',victim.position,Color('#ffe598'))
		other.sound('reflect')
		other.deal(racer,amount,id,true)
		return false
	if id == 'lance' and (other.states.has('root') or other.states.has('trap')): amount *= 2
	other.states.erase('stealth')
	other.states.erase('fear')
	other.states.erase('trap')
	victim.skills.fear_left = 0
	victim.skills.frozen_left = 0
	if id == 'frostbolt': other.states.slow = 2.0
	hit_count[id] = hit_count.get(id,0)+1
	var duel = racer.game.duel
	if duel and duel.in_arena() and duel.phase != 'fighting': return false
	other.fx.number('-'+str(roundi(amount)) if duel and duel.in_arena() else '命中',color())
	other.fx.pulse('hit',victim.position+Vector3.UP,color(),.7,.28)
	victim.squash = .78
	other.sound('impact_frost' if id in ['frostbolt','lance','nova'] else 'impact_shadow' if id in ['sinister','eviscerate'] else 'impact_arrow' if id in ['arcane','aimed'] else 'impact_metal')
	if duel and duel.in_arena():
		duel.damage(victim,roundi(amount))
	else:
		# Racing has no health-elimination rule; attacks yield short physical feedback.
		var push: Vector3 = victim.position-racer.position
		push.y = 0
		victim.skills.receive_impulse(push.normalized()*minf(3,amount*.10),.16)
	return true
func launch(id: String, amount: float, direction: Vector3):
	pose_left = .45
	var pos := racer.global_position+Vector3.UP*1.05+direction*.65
	var node = fx.missile(id,pos,direction,color())
	missiles.append({'node':node,'direction':direction,'left':1.2,'damage':amount,'id':id})
func tick(delta: float):
	pose_left = maxf(0,pose_left-delta)
	if states.has('storm'): spin_angle += delta*TAU*2
	control_grace = maxf(0,control_grace-delta)
	for id in states.keys():
		states[id] -= delta
		if states[id] <= 0:
			states.erase(id)
			if id in ['root','trap','block']: sound('thaw')
	if not pending.is_empty():
		if blocked() or base.controlled() or (pending.id == 'aimed' and Vector2(racer.velocity.x,racer.velocity.z).length() > .6):
			pending.clear()
			fx.number('中断',Color('#ffb998'))
		else:
			pending.time -= delta
			if pending.time <= 0:
				var action: Dictionary = pending.duplicate()
				pending.clear()
				if action.id == 'charge':
					if can_target(action.target,3.0):
						deal(action.target,action.damage,'charge')
						apply_control(action.target,'stun',.55*action.control)
				else: launch(action.id,action.damage,action.direction)
	if states.has('storm'):
		storm_tick -= delta
		if storm_tick <= 0:
			storm_tick = .4
			for victim in targets(2.9): deal(victim,7*(1.15 if talents[0] == 0 else 1.0),'storm')
			fx.pulse('storm',racer.position,color(),2.8,.4)
			racer.model.rotation.y += 1.6
	elif enabled(): racer.model.rotation.y = lerp_angle(racer.model.rotation.y,0,minf(1,delta*20))
	for i in range(missiles.size()-1,-1,-1):
		if i >= missiles.size(): continue # A lethal impact resets all kits synchronously.
		var shot: Dictionary = missiles[i]
		var from: Vector3 = shot.node.global_position
		var to: Vector3 = from+shot.direction*(30 if shot.id in ['arcane','aimed'] else 19)*delta
		shot.left -= delta
		var ray := PhysicsRayQueryParameters3D.create(from,to,5)
		var hit := racer.get_world_3d().direct_space_state.intersect_ray(ray)
		var stop: bool = not hit.is_empty() or shot.left <= 0
		if not hit.is_empty(): to = hit.position
		var victim = null
		var distance := INF
		for target in get_tree().get_nodes_in_group('combatants'):
			if target == racer or not target.active or target.finished: continue
			var center: Vector3 = target.global_position+Vector3.UP
			var point := Geometry3D.get_closest_point_to_segment(center,from,to)
			if center.distance_to(point) < .68 and from.distance_to(point) < distance:
				victim = target
				distance = from.distance_to(point)
		shot.node.global_position = to
		if victim != null:
			# Remove before damage: a fatal hit may clear this entire list.
			missiles.remove_at(i)
			shot.node.queue_free()
			deal(victim,shot.damage,shot.id)
		elif stop:
			missiles.remove_at(i)
			shot.node.queue_free()
	for i in range(traps.size()-1,-1,-1):
		var trap: Dictionary = traps[i]
		trap.left -= delta
		trap.arm -= delta
		if trap.arm <= 0:
			for target in get_tree().get_nodes_in_group('combatants'):
				if target == racer or not target.active or target.finished: continue
				if target.position.distance_to(trap.node.position) < 1.1:
					apply_control(target,'trap',trap.control)
					fx.pulse('trap',trap.node.position,Color('#96e7ff'),1.3,.7)
					trap.left = 0
					break
		if trap.left <= 0:
			trap.node.queue_free()
			traps.remove_at(i)
	fx.tick(delta,states,class_id)
func movement(direction: Vector3) -> Vector3:
	if blocked() or states.has('root'): return Vector3.ZERO
	if pending.get('id','') == 'frostbolt': return direction*.45
	if states.has('slow'): return direction*.55
	if states.has('stealth'): return direction*.75
	return direction
func reset():
	states.clear()
	pending.clear()
	melee.clear()
	combo = 0
	pose_left = 0
	spin_angle = 0
	control_grace = 0
	for shot in missiles: shot.node.queue_free()
	missiles.clear()
	for trap in traps: trap.node.queue_free()
	traps.clear()
	if is_instance_valid(fx):
		fx.tick(0,states,class_id)
		fx.clear()
func ai(delta: float, racing := false):
	ai_clock -= delta
	if ai_clock > 0 or not enabled() or not racer.active or racer.finished: return
	ai_clock = .3+float(racer.racer_id%4)*.06
	var found := targets(12,deg_to_rad(70))
	if found.is_empty():
		if class_id == 'rogue' and not racing: use(5)
		return
	var target = found[0]
	var distance: float = racer.position.distance_to(target.position)
	match class_id:
		'warrior':
			if not racing and distance > 4 and use(4): return
			if target.skills.career.pending.get('id','') == 'frostbolt' and use(5): return
			if distance < 2.8:
				if use(1): return
				if use(2): return
				use(3)
		'mage':
			if not racing and racer.game.duel.in_arena() and racer.game.duel.health.get(racer.racer_id,100) < 30 and distance < 3 and use(5): return
			if distance < 3 and use(3): return
			if distance < 3 and not racing and use(4): return
			if target.skills.career.states.has('root') and use(2): return
			if use(1): return
			use(2)
		'rogue':
			if distance > 3 and not racing and use(4): return
			if distance < 2.8:
				if combo >= 2 and use(2): return
				if use(1): return
				if combo > 0: use(3)
		'hunter':
			if distance < 3:
				if use(2): return
				if use(3): return
				if not racing and use(4): return
			if distance > 4 and not racing and use(5): return
			use(1)
