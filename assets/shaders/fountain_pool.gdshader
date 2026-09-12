shader_type spatial;
uniform float flow_time = 0.0;
varying vec2 pool_position;

void vertex() {
	pool_position = VERTEX.xz;
}

void fragment() {
	vec2 p = pool_position;
	float rings = 0.0;
	float foam = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		float d = length(p - vec2(cos(a), sin(a)) * 3.8);
		float wave = pow(0.5 + 0.5 * cos(d * 24.0 - flow_time * 8.0), 12.0);
		rings += wave * exp(-d * 2.0) * smoothstep(0.07, 0.20, d);
		foam += (1.0 - smoothstep(0.08, 0.32, d)) * (0.75 + 0.20 * sin(flow_time * 10.0 + a));
	}
	float shimmer = sin(p.x * 6.0 + flow_time * 1.2) * cos(p.y * 7.0 - flow_time * 1.5);
	ALBEDO = mix(vec3(0.015, 0.36, 0.63), vec3(0.64, 0.94, 1.0), clamp(rings * 0.65 + foam + shimmer * 0.045, 0.0, 1.0));
	NORMAL_MAP = vec3(0.5 + sin(p.x * 8.0 + flow_time * 1.6) * 0.07, 0.5 + cos(p.y * 9.0 - flow_time * 1.8) * 0.07, 1.0);
	ROUGHNESS = 0.19;
	SPECULAR = 0.75;
	METALLIC = 0.12;
}
