extends SceneTree
const Store = preload('res://scripts/skin_store.gd')
const Rules = preload('res://scripts/gacha_rules.gd')
const Catalog = preload('res://scripts/skin_catalog.gd')
var failures: Array[String] = []
func check(value: bool, message: String):
	if not value: failures.append(message)
func _initialize(): call_deferred('run')
func run():
	var path := 'user://test-gacha-isolated.cfg'
	DirAccess.remove_absolute(path)
	var store = Store.new(path)
	check(store.load_skin() == 'classic' and store.coins == 0,'Fresh profile has no paid unlocks or coins')
	for bad in ['', '500','-500','+0','+1.5','+500x','+1000000000','++500','+５００']:
		check(not store.credit(bad).ok,'Reject malformed credit: '+bad)
	check(store.credit(' +500 ').ok and store.coins == 500,'Credit exact integer amount')
	check(not store.draw('season',10).ok and store.coins == 500 and store.total_draws == 0,'Insufficient funds make no partial draw')
	check(store.save_skin('mecha') == ERR_UNAUTHORIZED,'Locked skin cannot equip')
	check(not store.draw('season',2).ok and not store.draw('bad',1).ok,'Invalid draw requests rejected')
	check(store.credit('+10000').ok,'Fund test collection')
	store.rng.seed = 7381
	var before: int = store.coins
	var result: Dictionary = store.draw('season',10)
	var refunds := 0
	for reward in result.rewards: refunds += reward.refund
	check(result.ok and result.rewards.size() == 10 and store.coins == before-540+refunds,'Ten pull deducts once and applies exact duplicate refunds')
	var restored = Store.new(path)
	restored.load_skin()
	check(restored.coins == store.coins and restored.owned == store.owned and restored.pity == store.pity and restored.history == store.history,'Wallet, ownership, protection and results survive restart together')
	var owned_id: String = result.rewards[0].id
	check(restored.save_skin(owned_id) == OK,'Award can equip')
	var again = Store.new(path)
	check(again.load_skin() == owned_id and again.coins == restored.coins and again.pity == restored.pity,'Equipping preserves wallet and pity')
	# Exact ticket coverage, plus seeded sampling through the production roll path.
	for pool in ['basic','season']:
		var weights: Array = Rules.BASIC_WEIGHTS if pool == 'basic' else Rules.SEASON_WEIGHTS
		var actual: Array = []
		actual.resize(weights.size())
		actual.fill(0)
		for ticket in range(10000): actual[Rules.tier_for_ticket(pool,ticket)] += 1
		check(actual == weights,'Every integer ticket matches published base distribution '+pool)
	var rng := RandomNumberGenerator.new()
	rng.seed = 29061
	var supreme := 0
	for i in range(100000):
		if Rules.roll('season',rng,Rules.HIGH,0).id == 'mecha': supreme += 1
	check(absf(supreme/100000.0-.0163) < .002,'Seeded production sample is near 1.63 percent without protection')
	print('GACHA SAMPLE supreme=',supreme,' / 100000')
	for seed in range(500):
		rng.seed = seed
		var owned: Array = []
		var pity := 0
		var high_count := 0
		for i in range(150):
			var reward := Rules.roll('season',rng,owned,pity)
			pity = reward.pity
			if reward.id in Rules.HIGH:
				if high_count < 3: check(reward.id not in owned,'First three high awards do not repeat')
				high_count += 1
			owned.append(reward.id)
			check(pity <= 49,'Pity never exceeds 49 misses')
		check(Rules.HIGH.all(func(id): return id in owned),'All three mechs within 150 draws')
	# Force a low base ticket at the protection boundary.
	rng.seed = 42
	var forced := Rules.roll('season',rng,[],49)
	check(forced.id in Rules.HIGH and forced.pity == 0,'50th roll guarantees a high-tier award')
	var old_pity: int = store.pity
	store.draw('basic',10)
	check(store.pity == old_pity,'Basic pool cannot reset season progress')
	var broken = Store.new('user://missing-gacha-directory/profile.cfg')
	broken.coins = 1000
	var rng_state: int = broken.rng.state
	check(not broken.draw('season',10).ok and broken.coins == 1000 and broken.owned == Store.LEGACY and broken.total_draws == 0 and broken.rng.state == rng_state,'Failed persistence rolls back the full transaction and RNG')
	check(not broken.credit('+500').ok and broken.coins == 1000,'Failed credit does not change balance')
	var legacy := ConfigFile.new()
	legacy.set_value('appearance','skin','mint')
	legacy.save(path)
	check(store.load_skin() == 'mint' and store.owned == Store.LEGACY and store.coins == 0,'Old appearance-only saves migrate without locking legacy skins')
	var model = preload('res://assets/models/racer.glb').instantiate()
	root.add_child(model)
	Catalog.apply(model,'mecha')
	for limb in ['ArmL','ArmR','FootL','FootR']:
		check(model.find_child(limb,true,false).get_node_or_null('OutfitLimb') != null,'Mecha armor follows animated '+limb)
	Catalog.apply(model,'mint')
	for limb in ['Body','ArmL','ArmR','FootL','FootR']:
		check(model.find_child(limb,true,false).layers == 1 and model.find_child(limb,true,false).get_node_or_null('OutfitLimb') == null,'Returning to basic restores '+limb)
	model.queue_free()
	DirAccess.remove_absolute(path)
	await process_frame
	print('GACHA: ', 'PASS' if failures.is_empty() else 'FAIL',failures)
	quit(0 if failures.is_empty() else 1)
