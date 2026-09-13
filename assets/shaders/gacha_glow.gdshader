shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(0.15,0.65,1.0,1.0);
uniform float power = 0.3;
uniform float flash = 0.0;
uniform float clock = 0.0;
void fragment() {
    vec2 p = UV-vec2(0.5,0.49);
    p.x *= 1.6;
    float r = length(p);
    float angle = atan(p.y,p.x);
    float rays = pow(max(0.0,cos(angle*12.0+clock*.3)),18.0);
    float ring = exp(-abs(r-(0.22+flash*.23))*85.0)*flash;
    vec3 base = mix(vec3(.018,.028,.09),vec3(.035,.12,.25),max(0.0,1.0-r));
    vec3 glow = tint.rgb*(exp(-r*5.8)*power+(rays*exp(-r*3.0)*.17*power)+ring*.65);
    COLOR = vec4(base+glow+flash*exp(-r*2.5)*.22,1.0);
}
