#version 120

#define SUNRISE 23200
#define SUNSET 12800
#define SHADOW_STRENGTH 0.8

varying vec4 color;
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform float nightVision;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;

vec2 normalEncode(vec3 n) {
    float p = sqrt(normal.z * 8.0 + 8.0);
    return vec2(normal.xy / p + 0.5);
}

vec3 saturation(vec3 color, float factor) {
    float brightness = dot(color, vec3(0.2125, 0.7154, 0.0721));
    return mix(vec3(brightness), color, factor);
}

/* DRAWBUFFERS:023 */
void main() {
    float isNight = 0;
    if (12000 < worldTime&&worldTime < 13000) {
        isNight = 1.0 - (13000 - worldTime) / 1000.0;
    }
    else if (13000 <= worldTime&&worldTime <= 23000) {
        isNight = 1;
    }
    else if (23000 < worldTime) {
        isNight = (24000 - worldTime) / 1000.0;
    }
    
    float lm = lmcoord.x;
    lm *= max(0.4f, isNight * 0.6);
    lm += nightVision;
    
    float lightSky = lmcoord.y;
    lightSky = pow(lightSky, 2);
    lightSky *= (1 - isNight * 0.8);
    
    vec4 Screencolor = texture2D(texture, texcoord.st) * color;
    
    float angle;
    if (worldTime < SUNSET||worldTime > SUNRISE) {
        gl_FragData[1] = vec4(normalEncode(normal), 0.0, 1.0);
        angle = dot(normalize(sunPosition), normal);
    }else {
        gl_FragData[1] = vec4(normalEncode(normal), 0.0, 1.0);
        angle = dot(normalize(moonPosition), normal);
    }
    if (angle <= 0.1) {
        Screencolor.rgb *= max(lm, lightSky * SHADOW_STRENGTH);
    }else {
        if (angle < 0.3) {
            Screencolor.rgb *= max(lm, lightSky * mix(SHADOW_STRENGTH, 1, (angle - 0.1) * 5));
        }else {
            Screencolor.rgb *= max(lm, lightSky);
        }
    }
    
    Screencolor.rgb = saturation(Screencolor.rgb, 1.5);
    
    gl_FragData[0] = Screencolor;
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, 0.0);
}