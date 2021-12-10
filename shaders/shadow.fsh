#version 120

#define COLOR_SHADOW

uniform sampler2D texture;
varying vec4 texcoord;
varying vec4 color;
varying float isTransparent;

void main() {
    #ifdef COLOR_SHADOW
    vec3 fragColor = color.rgb * texture2D(texture, texcoord.st).rgb;
    fragColor = mix(vec3(0), fragColor, isTransparent);
    
    gl_FragData[0] = vec4(fragColor, texture2D(texture, texcoord.st).a);
    #else
    gl_FragData[0] = vec4(vec3(0), 1);
    #endif
}