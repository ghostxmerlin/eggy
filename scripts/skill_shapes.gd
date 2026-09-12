extends RefCounted

static func strip(surface: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
	var side := (b-a).normalized().cross(Vector3.UP)*width*.5
	for vertex in [a-side,a+side,b-side,b-side,a+side,b+side]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)

static func snowflake(width: float) -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0,0,-2.8)
	for i in range(6):
		var direction := Vector3(sin(i*TAU/6),0,cos(i*TAU/6))
		strip(surface,center,center+direction*3.0,width)
		for distance in [1.25,2.05]:
			var joint: Vector3 = center+direction*distance
			for side in [-1,1]:
				strip(surface,joint,joint+direction.rotated(Vector3.UP,side*PI/3)*.74,width*.8)
	return surface.commit()

static func sweep_arc() -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var a := lerpf(-1.5,1.5,float(i)/32)
		var b := lerpf(-1.5,1.5,float(i+1)/32)
		strip(surface,Vector3(sin(a),0,-cos(a))*2.2,Vector3(sin(b),0,-cos(b))*2.2,.15)
	return surface.commit()
