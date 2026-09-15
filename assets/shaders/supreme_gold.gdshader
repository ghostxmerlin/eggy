shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
uniform float clock = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
    vec3 n = normalize(world_normal);
    vec3 view = normalize(CAMERA_POSITION_WORLD - world_position);
    vec3 reflection = reflect(-view, n);
    // Warm softbox reflections supplement the blue island sky on polished gold.
    float key = pow(max(dot(reflection, normalize(vec3(-.45,.65,1.0))),0.0),36.0);
    float rim = pow(max(dot(reflection, normalize(vec3(.8,.3,-.6))),0.0),60.0);
    float sweep = exp(-pow((reflection.x + reflection.y*.32 - sin(clock*.65)*.75)/.075,2.0));
    sweep *= smoothstep(-.2,.8,reflection.z);
    float fresnel = pow(1.0-max(dot(n,view),0.0),4.0);
    ALBEDO = vec3(1.0,.77,.32)*(key*2.6+rim*1.8+sweep*.95+fresnel*.28);
    ALPHA = .72;
}
