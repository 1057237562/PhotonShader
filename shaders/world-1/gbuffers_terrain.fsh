#version 120

#define SUNRISE 23200
#define SUNSET 12800
#define TORCHLIGHT.4

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform float nightVision;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
varying vec4 color;
varying vec4 texcoord;
varying vec3 normal;
varying vec4 lmcoord;
varying float matId;

vec2 normalEncode(vec3 n) {
    float p = sqrt(normal.z * 8.0 + 8.0);
    return vec2(normal.xy / p + 0.5);
}

float isLightBlock(float id) {
    if (id == 124.0||id == 50.0||id == 76.0||id == 89.0||id == 91.0||id == 169.0||id == 62.0) {
        return 1.0;
    }
    return 0.0;
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
    
    float depth = texture2D(depthtex1, texcoord.st).x;
    vec4 positionInNdcCoord = vec4(texcoord.st * 2-1, depth * 2-1, 1);
    vec4 positionInClipCoord = gbufferProjectionInverse * positionInNdcCoord;
    vec4 positionInViewCoord = vec4(positionInClipCoord.xyz / positionInClipCoord.w, 1.0);
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;
    
    float lm = lmcoord.x;
    float id = floor(matId + 0.1);
    lm += nightVision;
    
    float lightSky = lmcoord.y;
    lightSky = pow(lightSky, 2);
    lightSky *= (1 - isNight * 0.8);
    
    vec4 blockColor = texture2D(texture, texcoord.st) * color;
    blockColor.rgb *= max(lm, lightSky);
    //blockColor += vec4(0.8,1.0,1.0,1.0)*isNight*0.1;
    
    gl_FragData[0] = blockColor; //vec4(vec3(dot(normalize(sunPosition),normal)),1.0f);
    if (id == 20.0) {
        gl_FragData[1] = vec4(normalEncode(normal), 0.0, dot(normalize(sunPosition), normal));
    }else if (worldTime < SUNSET||worldTime > SUNRISE) {
        gl_FragData[1] = vec4(normalEncode(normal), max(0, 1.0 - lm * 0.6f), dot(normalize(sunPosition), normal));
    }else {
        gl_FragData[1] = vec4(normalEncode(normal), max(0, 1.0 - lm), dot(normalize(moonPosition), normal));
    }
    //float dist = pow(pow(abs(positionInWorldCoord.x),2)+pow(abs(positionInWorldCoord.z),2)+pow(abs(positionInWorldCoord.y),2),1.0/3.0)/27;
    gl_FragData[2] = vec4(matId / 255, 0.0, 0.0, 0.0);
}