shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled;
uniform float clock = 0.0;
uniform float motion = 0.0;
uniform float fold = 0.0;
void vertex() {
    float phase = COLOR.r*41.0;
    float free = UV.y*UV.y;
    VERTEX.z -= UV.y*(motion*.45 + sin(clock*9.0+phase)*.07);
    VERTEX.z *= 1.0-fold*.55;
    VERTEX.x += sin(UV.y*13.0-clock*13.0+phase)*free*.045;
    VERTEX.y += cos(UV.y*11.0-clock*10.0+phase)*free*.045;
}
void fragment() {
    float wave = .65+.35*sin(UV.y*22.0-clock*16.0+COLOR.r*41.0+sin(UV.x*18.0)*1.8);
    float tail = 1.0-smoothstep(.55,1.0,UV.y);
    vec3 gold = mix(vec3(2.4,1.05,.025),vec3(1.8,.27,.005),UV.y);
    ALBEDO = gold*(.65+wave*.45);
    ALPHA = (.68+wave*.24)*tail;
}
