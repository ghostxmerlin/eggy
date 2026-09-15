extends RefCounted
const S = preload('res://scripts/outfit_models.gd')

static func build(model: Node3D, root: Node3D, skin: Dictionary) -> void:
	var kind: String = skin.accessory
	var white := S.mat(Color(skin.shell))
	white.roughness = .22 if kind == 'knight' else .24
	white.metallic = .62 if kind == 'knight' else .72
	var edge := S.mat(Color('#b77518') if kind == 'knight' else Color(skin.shell).lightened(.36))
	var silver := S.mat(Color('#ffe29a') if kind == 'knight' else Color('#f2f5ff'))
	var dark := S.mat(Color('#241d19') if kind == 'knight' else Color('#16283e'))
	var rubber := S.mat(Color('#382f26') if kind == 'knight' else Color('#26334b'))
	rubber.metallic = .08
	rubber.roughness = .65
	var blue := S.mat(Color(skin.accent) if kind == 'knight' else Color('#6ae7ff') if kind == 'gale' else Color('#c66dff'),true)
	blue.emission_energy_multiplier = .85 if kind == 'knight' else 1.15
	if kind == 'knight':
		var effects = load('res://scripts/supreme_effects.gd').new()
		root.add_child(effects)
		white.metallic = .88
		white.roughness = .14
		white.clearcoat_enabled = true
		white.clearcoat = .85
		white.clearcoat_roughness = .10
		white.next_pass = effects.glint
		silver.next_pass = effects.glint
		edge.next_pass = effects.glint
		blue.emission_energy_multiplier = 4.2
	model.find_child('Body',true,false).layers = 0
	# A closed continuous shell supports the front panels and carries the backpack.
	S.ball(root,Vector3(0,1.02,-.035),Vector3(.625,.645,.50),white)
	S.ball(root,Vector3(0,.60,0),Vector3(.43,.23,.35),rubber)
	S.plate(root,[Vector2(-.35,.68),Vector2(.35,.68),Vector2(.32,.42),Vector2(0,.35),Vector2(-.32,.42)],.35,.51,edge)
	S.plate(root,[Vector2(-.20,.58),Vector2(.20,.58),Vector2(.14,.39),Vector2(-.14,.39)],.39,.08,white)
	# Recessed visor wraps under a two-piece swept brow. Each eye is framed and inset.
	S.ball(root,Vector3(0,1.24,.443),Vector3(.515,.225,.115),dark)
	for side in [-1,1]:
		S.plate(root,[Vector2(side*.015,1.58),Vector2(side*.39,1.73),Vector2(side*.61,1.55),Vector2(side*.50,1.32),Vector2(side*.02,1.20)],.58,.29,white)
		S.tube(root,[Vector3(side*.025,1.215,.587),Vector3(side*.27,1.34,.587),Vector3(side*.50,1.47,.59)],.013,edge)
		var eye: Array = [Vector2(side*.09,1.24),Vector2(side*.425,1.42),Vector2(side*.385,1.19),Vector2(side*.22,1.15)]
		S.plate(root,eye,.573,.035,blue)
		# Curved illuminated eye segments give the visor depth instead of a flat triangle.
		for j in range(7):
			var t := j/6.0
			S.ball(root,Vector3(side*(.14+.23*t),1.205+.035*sin(t*PI),.586),Vector3(.019,.027,.012),silver if j == 6 else blue)
		S.plate(root,[Vector2(side*.45,1.42),Vector2(side*.66,1.53),Vector2(side*.68,.98),Vector2(side*.39,.64),Vector2(side*.33,.94)],.52,.38,edge)
		S.plate(root,[Vector2(side*.46,1.30),Vector2(side*.615,1.43),Vector2(side*.59,.99),Vector2(side*.39,.76)],.554,.075,white)
		S.tube(root,[Vector3(side*.42,.73,.55),Vector3(side*.55,.96,.56),Vector3(side*.62,1.28,.55)],.016,blue)
		# Bolted temple hinge, physically buried into both shell and cheek.
		S.ball(root,Vector3(side*.59,1.15,.23),Vector3(.13,.13,.17),dark)
		var hinge := S.ring(root,Vector3(side*.65,1.15,.26),.085,silver)
		hinge.rotation.z = PI/2
		S.ball(root,Vector3(side*.69,1.15,.26),Vector3(.022,.047,.047),blue)
	S.plate(root,[Vector2(-.067,1.68),Vector2(0,1.75),Vector2(.067,1.68),Vector2(.055,1.34),Vector2(0,1.21),Vector2(-.055,1.34)],.602,.20,white)
	# Layered chin mask with a continuous luminous V rather than separate floating shards.
	S.plate(root,[Vector2(-.365,1.065),Vector2(.365,1.065),Vector2(.26,.66),Vector2(0,.52),Vector2(-.26,.66)],.61,.28,dark)
	S.plate(root,[Vector2(-.355,1.075),Vector2(-.235,1.03),Vector2(-.15,.70),Vector2(0,.60),Vector2(-.25,.69)],.648,.065,silver)
	S.plate(root,[Vector2(.355,1.075),Vector2(.235,1.03),Vector2(.15,.70),Vector2(0,.60),Vector2(.25,.69)],.648,.065,silver)
	S.tube(root,[Vector3(-.24,1.035,.664),Vector3(-.16,.73,.668),Vector3(0,.615,.654),Vector3(.16,.73,.668),Vector3(.24,1.035,.664)],.016,blue)
	for row in range(2):
		for side in [-1,1]:
			var x: float = side*.064
			var y := .95-row*.085
			S.plate(root,[Vector2(x-.025,y-.018),Vector2(x+.025,y-.018),Vector2(x,y+.029)],.642,.025,blue)
	# Helmet fins grow directly out of the brow and shell; closed side/back walls.
	for side in [-1,1]:
		var tip := 2.17 if kind == 'knight' else 1.98 if kind == 'gale' else 1.85
		S.plate(root,[Vector2(side*.19,1.53),Vector2(side*.38,1.73),Vector2(side*.82,tip),Vector2(side*.60,1.65),Vector2(side*.47,1.39)],.39,.24,edge)
		S.plate(root,[Vector2(side*.30,1.57),Vector2(side*.78,tip-.035),Vector2(side*.52,1.67)],.416,.04,silver)
		S.tube(root,[Vector3(side*.31,1.58,.433),Vector3(side*.51,1.70,.435),Vector3(side*.76,tip-.06,.43)],.012,blue)
		S.plate(root,[Vector2(side*.55,1.05),Vector2(side*.77,.85),Vector2(side*.54,.63),Vector2(side*.36,.57)],.26,.48,white)
		# Backpack mounting rail / nozzle housing / inner turbine are all intersecting solids.
		S.box(root,Vector3(side*.31,1.0,-.48),Vector3(.32,.64,.22),rubber)
		S.ball(root,Vector3(side*.38,.99,-.57),Vector3(.19,.39,.20),edge)
		S.ball(root,Vector3(side*.38,.96,-.66),Vector3(.15,.28,.14),white)
		S.ring(root,Vector3(side*.39,.70,-.57),.17,dark)
		S.ring(root,Vector3(side*.39,.685,-.57),.145,silver)
		S.ball(root,Vector3(side*.39,.66,-.57),Vector3(.105,.042,.105),blue)
		# Wing roots overlap the back mounting rail and expose a two-layer blade.
		if kind != 'blaze':
			S.plate(root,[Vector2(side*.26,1.18),Vector2(side*1.03,1.57),Vector2(side*.73,.97),Vector2(side*.44,.76)],-.45,.14,edge)
			S.plate(root,[Vector2(side*.40,1.16),Vector2(side*.99,1.52),Vector2(side*.69,1.00)],-.42,.035,blue)
			S.plate(root,[Vector2(side*.43,1.03),Vector2(side*.82,.97),Vector2(side*1.06,.39),Vector2(side*.52,.76)],-.49,.09,white)
		else:
			S.box(root,Vector3(side*.40,1.16,-.64),Vector3(.32,.42,.22),dark)
			for j in range(3): S.box(root,Vector3(side*.40,1.04+j*.09,-.766),Vector3(.20,.027,.02),blue)
	# Shoulder cap and elbow now overlap; limb skin is attached at its animation pivot.
	var rig := preload('res://scripts/outfit_rig.gd').new()
	rig.name = 'OutfitRig'
	root.add_child(rig)
	for side in [-1,1]:
		var arm: Node3D = model.find_child('Arm'+('L' if side == -1 else 'R'),true,false)
		var foot: Node3D = model.find_child('Foot'+('L' if side == -1 else 'R'),true,false)
		for original in [arm,foot]: original.layers = 0
		var gauntlet := Node3D.new()
		gauntlet.name = 'OutfitLimb'
		arm.add_child(gauntlet)
		S.ball(gauntlet,Vector3(0,.065,0),Vector3(.165,.25,.165),rubber)
		S.plate(gauntlet,[Vector2(-.19,.08),Vector2(.19,.08),Vector2(.20,-.23),Vector2(.10,-.29),Vector2(-.16,-.24)],.20,.34,edge)
		S.plate(gauntlet,[Vector2(-.15,.045),Vector2(.15,.045),Vector2(.13,-.18),Vector2(-.12,-.18)],.224,.035,white)
		for j in range(3): S.box(gauntlet,Vector3(-.10+j*.09,-.245,.20),Vector3(.067,.075,.065),dark)
		S.box(gauntlet,Vector3(0,-.01,.244),Vector3(.18,.032,.025),blue)
		var spread := 1.01 if kind == 'blaze' else .94
		S.ball(root,Vector3(side*.65,.94,-.04),Vector3(.21,.23,.23),rubber)
		S.plate(root,[Vector2(side*.53,1.20),Vector2(side*spread,1.40),Vector2(side*(spread+.04),1.11),Vector2(side*.74,.85),Vector2(side*.56,.95)],.15,.40,edge)
		S.plate(root,[Vector2(side*.62,1.19),Vector2(side*(spread-.045),1.33),Vector2(side*.85,1.11),Vector2(side*.69,.99)],.183,.042,white)
		S.tube(root,[Vector3(side*.68,1.20,.204),Vector3(side*.88,1.31,.20)],.014,blue)
		var boot := Node3D.new()
		boot.name = 'OutfitLimb'
		foot.add_child(boot)
		S.ball(boot,Vector3(0,.17,-.045),Vector3(.13,.21,.14),rubber)
		S.plate(boot,[Vector2(-.20,.12),Vector2(-.12,.26),Vector2(.13,.26),Vector2(.22,.10),Vector2(.19,-.14),Vector2(-.18,-.14)],.28,.46,edge)
		S.plate(boot,[Vector2(-.18,.12),Vector2(.18,.12),Vector2(.15,-.12),Vector2(0,-.16),Vector2(-.15,-.12)],.34,.09,white)
		S.plate(boot,[Vector2(-.105,.27),Vector2(.105,.27),Vector2(.12,.14),Vector2(0,.085),Vector2(-.12,.14)],.22,.13,silver)
		S.tube(boot,[Vector3(-.11,.10,.355),Vector3(0,.015,.36),Vector3(.11,.10,.355)],.011,blue)
		rig.connect_limb(arm,Vector3(side*.54,1.0,-.01),Vector3(0,.04,0),.12,rubber)
		rig.connect_limb(foot,Vector3(side*.29,.53,-.025),Vector3(0,.17,-.035),.115,dark)
	if kind == 'knight':
		S.plate(root,[Vector2(-.16,1.61),Vector2(0,1.94),Vector2(.16,1.61),Vector2(0,1.48)],.455,.24,edge)
		S.plate(root,[Vector2(-.075,1.65),Vector2(0,1.82),Vector2(.075,1.65),Vector2(0,1.57)],.481,.028,blue)
	# Rear centre spine ties both booster rails together and closes the rear silhouette.
	S.box(root,Vector3(0,1.02,-.51),Vector3(.29,.71,.15),dark)
	for row in range(4): S.box(root,Vector3(0,.80+row*.13,-.60),Vector3(.23,.065,.06),edge)
