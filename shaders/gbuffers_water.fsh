#version 120

uniform int fogMode;
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform int worldTime;
uniform float nightVision;
uniform mat4 gbufferModelViewInverse;
const int noiseTextureResolution = 64;
uniform sampler2D noisetex;
uniform sampler2D colortex3;
uniform int frameCounter;
uniform vec3 cameraPosition;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;
varying vec4 position;
varying float attr;

vec2 normalEncode(vec3 n) {
    float p = sqrt(normal.z * 8.0 + 8.0);
    return vec2(normal.xy / p + 0.5);
}

/*vec3 getWave(vec3 color, vec4 positionInWorldCoord) {
    
    // 小波浪
    float speed1 = float(frameCounter*0.25) / (noiseTextureResolution * 15);
    vec3 coord1 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord1.x *= 3;
    coord1.x += speed1;
    coord1.z += speed1 * 0.2;
    float n1 = texture2D(noisetex, coord1.xz).x;
    
    // 混合波浪
    float speed2 = float(frameCounter*0.25) / (noiseTextureResolution * 7);
    vec3 coord2 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord2.x *= 0.5;
    coord2.x -= speed2 * 0.15 + n1 * 0.05;  // 加入第一个波浪的噪声
    coord2.z -= speed2 * 0.7 - n1 * 0.05;
    float n2 = texture2D(noisetex, coord2.xz).x;
    
    color *= n2 * 0.3 + 0.7;
    return color;
}*/

/* DRAWBUFFERS:0214 */

void main() {
    vec4 positionInWorldCoord = gbufferModelViewInverse * position;   // “我的世界坐标”
    positionInWorldCoord.xyz += cameraPosition;
    
    float isNight = 0;
    if(12000<worldTime && worldTime<13000) {
        isNight = 1.0 - (13000-worldTime) / 1000.0;
    }
    else if(13000<=worldTime && worldTime<=23000) {
        isNight = 1;
    }
    else if(23000<worldTime) {
        isNight = (24000-worldTime) / 1000.0;
    }
    
    float lm = lmcoord.x*0.4f;
    lm += nightVision;
    
    float lightSky = lmcoord.y;
    lightSky = pow(lightSky, 2);
    lightSky *= (1-isNight*0.8);
    
    vec4 blockColor = texture2D(texture, texcoord.st) * color;
    blockColor.rgb *= max(lm,lightSky);
    
    if(floor(attr+0.1) == 1.0){
        // 计算视线和法线夹角余弦值
        float cosine = dot(normalize(position.xyz), normalize(normal));
        cosine = clamp(abs(cosine), 0, 1);
        float factor = pow(1.0 - cosine, 4);    // 透射系数
        gl_FragData[0] = vec4(blockColor.rgb, factor*0.80 + 0.15);
        gl_FragData[2]=vec4(1-attr,normalEncode(normal),1);
        gl_FragData[3]=vec4(normal*0.5+0.5,1);
    }else{
        gl_FragData[0] = blockColor;
        gl_FragData[1] = vec4(normalEncode(normal),max(0,attr-lm*0.6f),1.0);
        gl_FragData[2]=vec4(1-attr,normalEncode(normal),1);
    }
    
    /*
    if(fogMode == 9729)
    gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp((gl_Fog.end - gl_FogFragCoord) / (gl_Fog.end - gl_Fog.start), 0.0, 1.0));
    else if(fogMode == 2048)
    gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp(exp(-gl_FogFragCoord * gl_Fog.density), 0.0, 1.0));
    */
}