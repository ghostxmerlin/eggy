shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 tint : source_color = vec4(.3,.65,1.0,1.0);
void fragment() {
    vec2 p = UV-vec2(.5,.36);
    float halo = exp(-dot(p,p)*20.0)*.17;
    float streak = pow(max(0.0,1.0-abs(UV.x+UV.y*.45-mod(TIME*.13,2.1)+.4)*10.0),3.0)*.10;
    float rounded = length(max(abs(UV-.5)-vec2(.42,.42),vec2(0.0)))-.08;
    COLOR = vec4(tint.rgb,(halo+streak)*(1.0-smoothstep(-.004,.003,rounded)));
}
