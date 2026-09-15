extends 'res://scripts/course.gd'

func build_world() -> void:
	block(self,Vector3(0,-.65,0),Vector3(24,1.3,24),'cream',true)
	block(self,Vector3(0,-1.6,0),Vector3(23,.8,23),'purple')
	block(self,Vector3(0,.018,0),Vector3(22,.025,22),'mint')
	cylinder(self,Vector3(0,.04,0),6.5,.035,'cream')
	cylinder(self,Vector3(0,.065,0),6.2,.018,'mint_dark')
	cylinder(self,Vector3(0,.08,0),5.85,.018,'mint')
	for side in [-1,1]:
		cylinder(self,Vector3(0,.04,side*6),1.45,.045,'pink' if side < 0 else 'yellow')
		# Tall invisible collision walls retain players; camera rays ignore layer four.
		for axis in range(2):
			var pos := Vector3(side*11.8,6,0) if axis == 0 else Vector3(0,6,side*11.8)
			var size := Vector3(.4,12,24) if axis == 0 else Vector3(24,12,.4)
			var boundary := StaticBody3D.new()
			boundary.collision_layer = 4
			add_child(boundary)
			boundary.position = pos
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = size
			collider.shape = shape
			boundary.add_child(collider)
			block(self,Vector3(pos.x,.25,pos.z),Vector3(.35,.5,24) if axis == 0 else Vector3(24,.5,.35),'cream')
	for x in [-11,11]:
		for z in [-11,11]:
			cylinder(self,Vector3(x,1,z),.45,2,'purple')
			sphere(self,Vector3(x,2.15,z),Vector3(.62,.62,.62),'yellow',false)
	block(self,Vector3(0,3.1,-12.4),Vector3(9,2,.3),'dark')
	var title := lettering(self,'蛋仔决斗场',Vector3(0,3.3,-12.15),65,Color('#fff0b4'))
	title.font = preload('res://assets/fonts/CloudSans-Heavy.ttf')
	var subtitle := lettering(self,'1 V 1',Vector3(0,2.65,-12.14),34,Color('#78e6df'))
	subtitle.font = title.font
	for side in [-1,1]:
		for i in range(5):
			block(self,Vector3(side*15,1+i*.15,-8+i*4),Vector3(3,.7,2.5),'purple' if i%2 else 'pink')

func hazard_at(_pos: Vector3) -> Vector3:
	return Vector3.ZERO
