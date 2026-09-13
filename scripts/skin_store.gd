extends RefCounted

const Catalog = preload('res://scripts/skin_catalog.gd')
const Rules = preload('res://scripts/gacha_rules.gd')
const LEGACY := ['classic','peach','mint','sky','berry','royal']
const MAX_COINS := 999999999
var path: String
var selected_id := 'classic'
var coins := 0
var owned: Array = LEGACY.duplicate()
var pity := 0
var total_draws := 0
var history: Array = []
var rng := RandomNumberGenerator.new()

func _init(save_path := 'user://appearance.cfg') -> void:
	path = save_path
	rng.randomize()

func load_skin() -> String:
	selected_id = 'classic'
	coins = 0
	owned = LEGACY.duplicate()
	pity = 0
	total_draws = 0
	history = []
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var collection = config.get_value('collection','owned',[])
		if collection is Array:
			for id in collection:
				if id is String and Catalog.has_skin(id) and id not in owned: owned.append(id)
		var value = config.get_value('appearance','skin','classic')
		if value is String and value in owned: selected_id = value
		coins = valid_int(config.get_value('collection','coins',0),0,MAX_COINS)
		pity = valid_int(config.get_value('collection','pity',0),0,49)
		total_draws = valid_int(config.get_value('collection','draws',0),0,2147483647)
		var records = config.get_value('collection','history',[])
		if records is Array:
			for entry in records:
				if entry is Dictionary and entry.get('id') is String and Catalog.has_skin(entry.id) and entry.get('pool') in ['basic','season']:
					history.append(entry)
			history = history.slice(maxi(0,history.size()-50))
	return selected_id

func valid_int(value: Variant, low: int, high: int) -> int:
	return clampi(value,low,high) if value is int else low

func persist(next_id: String, next_coins: int, next_owned: Array, next_pity: int, next_total: int, next_history: Array) -> Error:
	var config := ConfigFile.new()
	config.set_value('appearance','skin',next_id)
	config.set_value('collection','coins',next_coins)
	config.set_value('collection','owned',next_owned)
	config.set_value('collection','pity',next_pity)
	config.set_value('collection','draws',next_total)
	config.set_value('collection','history',next_history)
	var error := config.save(path+'.tmp')
	if error != OK: return error
	error = DirAccess.rename_absolute(path+'.tmp',path)
	if error == OK:
		selected_id = next_id
		coins = next_coins
		owned = next_owned
		pity = next_pity
		total_draws = next_total
		history = next_history
	return error

func save_skin(id: String) -> Error:
	if not Catalog.has_skin(id): return ERR_INVALID_PARAMETER
	if id not in owned: return ERR_UNAUTHORIZED
	return persist(id,coins,owned,pity,total_draws,history)

func credit(command: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile('^\\+[0-9]{1,9}$')
	var value := command.strip_edges()
	if regex.search(value) == null or value.substr(1).to_int() <= 0:
		return {'ok':false,'message':'请输入 +500 这样的正整数指令'}
	var amount := value.substr(1).to_int()
	if amount > MAX_COINS-coins: return {'ok':false,'message':'蛋币余额已达上限'}
	if persist(selected_id,coins+amount,owned,pity,total_draws,history) != OK:
		return {'ok':false,'message':'保存失败，蛋币未增加，请重试'}
	return {'ok':true,'message':'已增加 %d 蛋币 · 余额 %d' % [amount,coins]}

func draw(pool: String, count: int) -> Dictionary:
	var price := Rules.cost(pool,count)
	if price < 0: return {'ok':false,'message':'无效的抽取方式'}
	if coins < price: return {'ok':false,'message':'蛋币不足 · 按回车输入 +500 即可添加'}
	var next_coins := coins-price
	var next_owned := owned.duplicate()
	var next_pity := pity
	var next_history := history.duplicate(true)
	var rewards: Array = []
	var old_rng := rng.state
	for i in range(count):
		var result := Rules.roll(pool,rng,next_owned,next_pity)
		next_pity = result.pity
		var duplicate: bool = result.id in next_owned
		var refund: int = Rules.REFUNDS[result.id] if duplicate else 0
		next_coins = mini(MAX_COINS,next_coins+refund)
		if not duplicate: next_owned.append(result.id)
		result.merge({'duplicate':duplicate,'refund':refund,'pool':pool})
		rewards.append(result)
		next_history.append(result.duplicate())
	next_history = next_history.slice(maxi(0,next_history.size()-50))
	if persist(selected_id,next_coins,next_owned,next_pity,total_draws+count,next_history) != OK:
		rng.state = old_rng
		return {'ok':false,'message':'保存失败，本次未扣币，请重试'}
	return {'ok':true,'rewards':rewards,'cost':price}
