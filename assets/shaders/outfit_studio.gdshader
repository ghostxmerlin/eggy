shader_type sky;
void sky() {
    vec3 d = normalize(EYEDIR);
    vec3 c = mix(vec3(.11,.16,.25),vec3(.70,.79,.95),smoothstep(-.75,.8,d.y));
    float key = pow(max(0.0,dot(d,normalize(vec3(-.7,.7,1.0)))),18.0);
    float strip = pow(max(0.0,dot(d,normalize(vec3(.8,.3,.9)))),55.0);
    float rim = pow(max(0.0,dot(d,normalize(vec3(.2,.6,-1.0)))),28.0);
    COLOR = c+vec3(2.2,2.1,2.0)*key+vec3(1.4,1.8,2.5)*strip+vec3(.5,.8,1.5)*rim;
}
