#version 120

#define BLOOM_CONSTANT.5

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform ivec2 eyeBrightnessSmooth;
uniform float viewWidth;
uniform float viewHeight;
varying float isNight;

void Vignette(inout vec3 color) {
    float dis = distance(texcoord.st, vec2(0.5)) * 2.0 / 1.5142f;
    
    dis = pow(dis, 1.1);
    color.rgb *= min(1.0, 1.f - dis * 0.60);
}

vec3 ConvertToHDR(in vec3 color) {
    vec3 HDRImage;
    
    vec3 overExposed = color;
    vec3 underExposed = color / 1.1f;
    
    HDRImage = mix(underExposed, overExposed, color);
    
    return HDRImage;
}

vec4 getScaleInverse(sampler2D src, vec2 pos, vec2 anchor, int fact) {
    return texture2D(src, pos / pow(2, fact) + anchor);
}

vec4 getScaleInverseN(sampler2D src, vec2 pos, vec2 anchor, int fact) {
    return texture2D(src, pos / fact + anchor);
}

vec3 saturation(vec3 color, float factor) {
    float brightness = dot(color, vec3(0.2125, 0.7154, 0.0721));
    return mix(vec3(brightness), color, factor);
}

/*
*  @function exposure : 曝光调节
*  @param color       : 原颜色
*  @param factor      : 调整因子 范围 0~1
*  @explain           : factor越大则暗处越亮
*/
vec3 exposure(vec3 color, float factor,float skylight) {
    skylight = pow(skylight, 6.0) * factor + (1.0f-factor);
    return color / skylight;
}

/*
*  @function ACESToneMapping : 色调映射
*  @param color              : 原颜色
*  @param adapted_lum        : 亮度调整因子
*  @return                   : 色调映射之后的值
*  @explain                  : 感谢知乎大佬：@叛逆者
*                            : 源码地址 https://zhuanlan.zhihu.com/p/21983679
*/
vec3 ACESToneMapping(vec3 color, float adapted_lum) {
    const float A = 2.51f;
    const float B = 0.03f;
    const float C = 2.43f;
    const float D = 0.59f;
    const float E = 0.14f;
    color *= adapted_lum;
    return (color * (A * color + B)) / (color * (C * color + D) + E);
}


/* DRAWBUFFERS:0 */
void main() {
    vec3 color = texture2D(gcolor, texcoord.st).rgb;
    
    //vec4 basebloom = getBloomOriginColor(getScaleInverseN(colortex1, texcoord.st, vec2(0.0, 0), 4));
    
    vec4 bloom = vec4(vec3(0), 1);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.0, 0), 2).rgb * pow(7, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.3, 0), 3).rgb * pow(6, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.5, 0), 4).rgb * pow(5, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.6, 0), 5).rgb * pow(4, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.7, 0), 6).rgb * pow(3, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.8, 0), 7).rgb * pow(2, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.9, 0), 8).rgb * pow(1, 0.25);
    bloom.rgb = pow(bloom.rgb, vec3(1 / 2.2));
    
    float skylight = float(eyeBrightnessSmooth.y) / 240;
    
    float mixlight = max(float(eyeBrightnessSmooth.x) * 0.8f, float(eyeBrightnessSmooth.y)) / 240;
    
    color.rgb += bloom.rgb * max(skylight * 0.3, 0.1);
    
    color = ConvertToHDR(color);
    // 色调映射
    color.rgb = exposure(color.rgb, 0.65, mixlight);
    color.rgb = mix(ACESToneMapping(color.rgb, 0.5) * 1.15f, color.rgb, 1 - mixlight);
    color.rgb = saturation(color.rgb, 1.25f);
    Vignette(color);
    
    gl_FragData[0] = vec4(color.rgb, 1.f);
}