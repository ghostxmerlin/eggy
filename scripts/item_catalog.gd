extends RefCounted

# Original models and locally balanced versions of familiar party-race items.
const DATA := {
	'portal': ['传送球', '投向地面，生成单向传送门', '#6f65dc'],
	'ink': ['墨汁炸弹', '抛出墨汁，干扰附近对手视野', '#563867'],
	'ball': ['弹球', '扔出大球，撞飞前方对手', '#e77aaf'],
	'spring': ['弹板', '部署弹板，向前弹飞踩中者', '#35b9cf'],
	'bomb': ['炸弹', '抛物线投掷，爆炸击飞对手', '#f18550'],
	'mine': ['地雷', '放置陷阱，对手踩中后爆炸', '#e75d6e'],
	'smoke': ['云雾弹', '抛出烟雾，遮挡区域内的视野', '#91a8bc'],
	'boost': ['加速', '四秒内提高跑步和滚动速度', '#edbb37'],
	'crate': ['垫脚箱', '放置实体箱子，跳上去垫脚', '#bc8052'],
	'rope': ['弹簧绳', '抛出钩绳，将自己与目标拉近', '#50bda9'],
	'jetpack': ['喷气背包', '短时喷气升空，继续控制方向', '#499bd5'],
	'clock': ['冷却秒表', '立即恢复全部技能的冷却', '#e8a65b'],
}
const IDS := ['portal','ink','ball','spring','bomb','mine','smoke','boost','crate','rope','jetpack','clock']

static func title(id: String) -> String:
	return DATA[id][0] if DATA.has(id) else '空道具槽'

static func description(id: String) -> String:
	return DATA[id][1] if DATA.has(id) else '碰触赛道上的问号箱随机拾取'

static func color(id: String) -> Color:
	return Color(DATA[id][2]) if DATA.has(id) else Color('#93b2b6')
