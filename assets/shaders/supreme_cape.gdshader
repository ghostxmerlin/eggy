shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float clock = 0.0;
uniform float motion = 0.0;
uniform float fold = 0.0;
void vertex() {
    float free = UV.y*UV.y;
    VERTEX.z += sin(UV.y*8.0 + UV.x*4.0 - clock*3.4)*.10*free;
    VERTEX.x += sin(UV.y*5.0 - clock*2.1)*.075*free;
    VERTEX.z -= motion*free*.65;
    VERTEX.y += motion*free*.18;
    VERTEX.y = mix(VERTEX.y,1.38+(VERTEX.y-1.38)*.27,fold);
    VERTEX.z = mix(VERTEX.z,-.78+(VERTEX.z+.78)*.3,fold);
}
void fragment() {
    float side = min(UV.x,1.0-UV.x);
    float border = 1.0-smoothstep(.008,.025,side);
    float seam = pow(max(0.0,cos(UV.x*31.4159)),22.0);
    float flow = pow(max(0.0,sin(UV.y*17.0-clock*2.2+UV.x*3.0)),10.0);
    float dissolve = 1.0-smoothstep(.82,1.0,UV.y);
    float hem = exp(-pow((UV.y-.9)/.013,2.0));
    vec3 cloth = mix(vec3(.19,.035,.52),vec3(.045,.16,.62),UV.y);
    vec3 embroidery = mix(vec3(.68,.28,1.0),vec3(.18,.80,1.0),UV.y);
    ALBEDO = cloth + embroidery*(border*1.25+seam*.13+flow*.14+hem*.35);
    ALPHA = (.76+border*.18)*dissolve;
}
