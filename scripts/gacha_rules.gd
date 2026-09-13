extends RefCounted

# Integer weights avoid rounding gaps. Rates are base rates before protection.
const SEASON_WEIGHTS := [6399,2389,1049,163]
const BASIC_WEIGHTS := [7000,2000,1000]
const HIGH := ['mecha_gale','mecha_blaze','mecha']
const POOLS := {
	'basic':[['scarf'],['goggles'],['aviator']],
	'season':[['worker','safety'],['rover'],['mecha_gale','mecha_blaze'],['mecha']],
}
const REFUNDS := {'scarf':2,'goggles':3,'aviator':5,'worker':5,'safety':5,'rover':10,'mecha_gale':30,'mecha_blaze':30,'mecha':60}

static func cost(pool: String, count: int) -> int:
	if not POOLS.has(pool) or count not in [1,10]: return -1
	return (10 if pool == 'basic' else 60)*count*(9 if count == 10 else 10)/10

static func tier_for_ticket(pool: String, ticket: int) -> int:
	var weights: Array = BASIC_WEIGHTS if pool == 'basic' else SEASON_WEIGHTS
	var accumulated := 0
	for i in range(weights.size()):
		accumulated += weights[i]
		if ticket < accumulated: return i
	return weights.size()-1

static func roll(pool: String, rng: RandomNumberGenerator, owned: Array, pity: int) -> Dictionary:
	var tier := tier_for_ticket(pool,rng.randi_range(0,9999))
	var guaranteed := pool == 'season' and pity >= 49 and tier < 2
	if guaranteed: tier = 3 if rng.randf() < 163.0/1212.0 else 2
	var candidates: Array = POOLS[pool][tier]
	var id: String = candidates[rng.randi_range(0,candidates.size()-1)]
	if pool == 'season' and tier >= 2:
		# The first three high-grade awards cannot repeat, including natural rolls.
		var missing: Array = HIGH.filter(func(value): return value not in owned)
		if not missing.is_empty() and id in owned:
			id = missing[rng.randi_range(0,missing.size()-1)]
		pity = 0
	elif pool == 'season': pity += 1
	return {'id':id,'pity':pity,'guaranteed':guaranteed}
