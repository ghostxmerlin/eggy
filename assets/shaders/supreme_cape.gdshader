shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
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
    vec2 cell = fract(vec2(UV.x*21.0,UV.y*32.0+clock*.6))-.5;
    float dust = (1.0-smoothstep(.035,.13,length(cell)))*(.5+.5*sin(UV.x*72.0+clock));
    float dissolve = 1.0-smoothstep(.82,1.0,UV.y);
    float hem = exp(-pow((UV.y-.9)/.013,2.0));
    ALBEDO = vec3(1.0,.58,.10)*(.3+seam*.65+flow*.75+dust*1.4)
             + vec3(1.0,.89,.50)*(border*3.2+hem*1.3);
    ALPHA = (.23+border*.65+seam*.16+dust*.28)*dissolve;
}
