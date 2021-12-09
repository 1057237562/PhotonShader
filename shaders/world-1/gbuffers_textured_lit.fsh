#version 120

#define SUNRISE 23200
#define SUNSET 12800

varying vec4 color;
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;

vec2 normalEncode(vec3 n) {
    float p = sqrt(normal.z * 8.0 + 8.0);
    return vec2(normal.xy / p + 0.5);
}

/* DRAWBUFFERS:02 */
void main() {
    vec4 blockColor = texture2D(texture, texcoord.st) * color;
    blockColor *= texture2D(lightmap, lmcoord.st);
    
    gl_FragData[0] = blockColor;
    if (worldTime < SUNSET||worldTime > SUNRISE)
    gl_FragData[1] = vec4(normalEncode(normal), 1.0, dot(normalize(sunPosition), normal));
    else
    gl_FragData[1] = vec4(normalEncode(normal), 1.0, dot(normalize(moonPosition), normal));
}