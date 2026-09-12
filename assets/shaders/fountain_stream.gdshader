shader_type spatial;
render_mode cull_disabled;

uniform float flow_time = 0.0;
varying float flow;

void vertex() {
	flow = UV.y;
	float ripple = sin(UV.y * 47.0 - flow_time * 12.0 + UV.x * 12.566);
	VERTEX += NORMAL * ripple * 0.012 * sin(UV.y * 3.14159);
}

void fragment() {
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float streak = pow(0.5 + 0.5 * sin(UV.x * 25.133 + sin(flow * 18.0 - flow_time * 6.0) * 0.65), 12.0);
	float pulse = 0.6 + 0.4 * sin(flow * 36.0 - flow_time * 13.0);
	float foam = smoothstep(0.84, 1.0, flow) * 0.35;
	ALBEDO = mix(vec3(0.025, 0.48, 0.78), vec3(0.67, 0.96, 1.0), clamp(edge * 0.70 + streak * pulse * 0.55 + foam, 0.0, 1.0));
	ROUGHNESS = 0.16;
	SPECULAR = 0.8;
	METALLIC = 0.08;
	EMISSION = vec3(0.10, 0.40, 0.48) * (edge * 0.2 + streak * pulse * 0.1);
}
