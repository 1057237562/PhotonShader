#version 120

#define SHADOW_MAP_BIAS 0.85
#define SHADOW_STRENGTH 0.45
#define SUNLIGHT_INTENSITY 2
#define ENABLE_WATERREFLECTION
#define ENABLE_BLOCKREFLECTION

#define BLOOM_EFFECT

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform float far;
uniform float near;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;
uniform sampler2DShadow shadow;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gcolor;
uniform sampler2D noisetex;
uniform sampler2D shadowcolor1;
uniform sampler2D gnormal;
uniform sampler2D shadowtex1;
uniform sampler2D colortex3;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform float wetness;
uniform float rainStrength;
uniform int isEyeInWater;
uniform vec3 cameraPosition;
uniform int frameCounter;

uniform float viewHeight;
uniform float viewWidth;
uniform ivec2 eyeBrightnessSmooth;
uniform float nightVision;

uniform sampler2D texture;

varying vec4 texcoord;
varying vec3 lightPosition;
varying float extShadow;
varying float isNight;

const float sunPathRotation = -25.0;
const int shadowMapResolution = 2048;
const int noiseTextureResolution = 128;
const bool shadowHardwareFiltering = true;
const float PI = 3.14159265359;
const int RGBA16 = 0;
const int colortex4Format = RGBA16;
const int gnormalFormat = RGBA16;
const float wetnessHalflife = 250.0f;
const float drynessHalflife = 150.0f;

vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (1 + SHADOW_MAP_BIAS * (length(positionInNdcCoord.xy) - 1));
}

mat2 getRotationMatrix(vec2 coord) {
    float theta = texture2D(noisetex, coord * vec2(viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).r;
    return mat2(cos(theta), - sin(theta), sin(theta), cos(theta));
}

float isLightSource(float id) {
    if (id == 10.0||id == 11.0||id == 50.0||id == 76.0||id == 51.0||id == 124.0||id == 89.0||id == 91.0||id == 169.0||id == 62.0) {
        return 1.0;
    }
    return 0.0;
}

float screenDepthToLinerDepth(float screenDepth) {
    return 2 * near * far / ((far + near) - screenDepth * (far - near));
}

float getUnderWaterFadeOut(float d0, float d1, vec4 positionInViewCoord, vec3 normal) {
    // 转线性深度
    d0 = screenDepthToLinerDepth(d0);
    d1 = screenDepthToLinerDepth(d1);
    
    // 计算视线和法线夹角余弦值
    float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal));
    cosine = clamp(abs(cosine), 0, 1);
    
    return clamp(1.0 - (d1 - d0) * cosine * 0.1, 0, 1);
}

vec4 getBloomSource(vec4 color, vec4 positionInWorldCoord, float IsNight, float type) {
    vec4 bloom = color;
    float id = floor(texture2D(colortex3, texcoord.st).x * 255 + 0.1);
    float brightness = dot(bloom.rgb, vec3(0.2125, 0.7154, 0.0721));
    if (type == 1.0) {
        bloom.rgb *= 0.1 * (1 - IsNight);
    }else if (id == 50.0||id == 76.0) {// torch
        if (brightness < 0.5) {
            bloom.rgb = vec3(0);
        }
        bloom.rgb *= 7*pow(brightness, 2) * (1 + IsNight * 0.15);
    }else if (isLightSource(id) == 1.0) {// glowing blocks
        bloom.rgb *= 6*vec3(1, 0.5, 0.5) * (1 + IsNight * 0.05);
    }
    else {
        bloom.rgb *= 0.1 * (1 - IsNight);
    }
    return bloom;
}

vec4 getShadow(vec4 color, vec4 positionInWorldCoord, vec3 normal, float dis) {
    float shade = 0;
    vec3 shadowColor = vec3(0);
    // Minecraft to sun coord
    vec4 positionInLightViewCoord = shadowModelView * positionInWorldCoord;
    // sun coord to sun clip coord
    vec4 positionInLightClipCoord = shadowProjection * positionInLightViewCoord;
    // clip coord to ndc coord
    vec4 positionInLightNdcCoord = vec4(positionInLightClipCoord.xyz / positionInLightClipCoord.w, 1.0);
    positionInLightNdcCoord.xy = getFishEyeCoord(positionInLightNdcCoord.xy);
    // ndc to sun camera coord
    vec4 positionInLightScreenCoord = positionInLightNdcCoord * 0.5 + 0.5;
    
    float currentDepth = positionInLightScreenCoord.z;
    mat2 rot = getRotationMatrix(positionInWorldCoord.xy);
    
    float dist = sqrt(positionInLightNdcCoord.x * positionInLightNdcCoord.x + positionInLightNdcCoord.y * positionInLightNdcCoord.y);
    
    float diffthresh = dist * 1.f + 0.10f;
    diffthresh *= 1f / (shadowMapResolution / 2048.f);
    //diffthresh /= shadingStruct.direct + 0.1f;
    
    for(int i =- 1; i < 2; i ++ ) {
        for(int j =- 1; j < 2; j ++ ) {
            vec2 offset = vec2(i, j) / shadowMapResolution;
            offset = rot * offset;
            float solidDepth = texture2DLod(shadowtex1, positionInLightScreenCoord.st, 0).x;
            float solidShadow = 1.0 - clamp((positionInLightScreenCoord.z - solidDepth) * 1200.0, 0.0, 1.0);
            shadowColor += texture2DLod(shadowcolor1, positionInLightScreenCoord.xy + offset, 0).rgb * solidShadow;
            shade += shadow2D(shadow, vec3(positionInLightScreenCoord.st + offset, positionInLightScreenCoord.z - 0.0008 * diffthresh)).z * SUNLIGHT_INTENSITY;
        }
    }
    shade *= 0.111;
    shadowColor *= 0.75;
    shadowColor = mix(shadowColor, vec3(0.0), isNight * 0.90); //vec4(shadowColor*0.111,1.0);//
    color = mix(vec4(shadowColor * 0.111, 1.0), color, clamp(shade, clamp(dis * (isNight * 0.4 + 1), SHADOW_STRENGTH, 1), 1));
    return color;
}

vec3 normalDecode(vec2 enc) {
    vec2 fenc = enc * 4.0 - 2.0;
    float f = dot(fenc, fenc);
    float g = sqrt(1.0 - f / 4.0);
    vec3 normal;
    normal.xy = fenc * g;
    normal.z = 1.0 - f / 2.0;
    return normal;
}

float getWave(vec4 positionInWorldCoord) {
    
    float speed1 = float(frameCounter * 0.3) / (noiseTextureResolution * 15);
    vec3 coord1 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord1.x *= 3;
    coord1.x += speed1;
    coord1.z += speed1 * 0.2;
    float noise1 = texture2D(noisetex, coord1.xz).x;
    
    float speed2 = float(frameCounter * 0.3) / (noiseTextureResolution * 7);
    vec3 coord2 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord2.x *= 0.5;
    coord2.x -= speed2 * 0.15 + noise1 * 0.05; // 加入第一个波浪的噪声
    coord2.z -= speed2 * 0.7 - noise1 * 0.05;
    float noise2 = texture2D(noisetex, coord2.xz).x;
    
    return noise2 * 0.6 + 0.4;
}

vec3 convertScreenSpaceToWorldSpace(vec2 co) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(co, texture2DLod(depthtex0, co, 0).x) * 2.0 - 1.0, 1.0);
    fragposition /= fragposition.w;
    return fragposition.xyz;
}

vec3 convertCameraSpaceToScreenSpace(vec3 cameraSpace) {
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
    screenSpace.z = 0.1f;
    return screenSpace;
}

vec4 ComputeRaytraceReflection(vec3 normal, bool edgeClamping)
{
    float initialStepAmount = 1.0 - clamp(0.1f / 100.0, 0.0, 0.99);
    
    vec2 screenSpacePosition2D = texcoord.st;
    vec3 cameraSpacePosition = convertScreenSpaceToWorldSpace(screenSpacePosition2D);
    
    //vec3 cameraSpaceNormal = normalize(normal + (rand(texcoord.st + sin(frameTimeCounter)).xyz * 2.0 - 1.0) * 0.05);
    vec3 cameraSpaceNormal = normal;
    
    vec3 cameraSpaceViewDir = normalize(cameraSpacePosition);
    vec3 cameraSpaceVector = initialStepAmount * normalize(reflect(cameraSpaceViewDir, cameraSpaceNormal));
    vec3 cameraSpaceVectorFar = far * normalize(reflect(cameraSpaceViewDir, cameraSpaceNormal));
    vec3 oldPosition = cameraSpacePosition;
    vec3 cameraSpaceVectorPosition = oldPosition + cameraSpaceVector;
    vec3 currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
    
    const int maxRefinements = 5;
    int numRefinements = 0;
    int count = 0;
    vec2 finalSamplePos = vec2(0.f);
    
    int numSteps = 0;
    
    float finalSampleDepth = 0.0;
    
    for(int i = 0; i < 40; i ++ )
    {
        if (
            
            - cameraSpaceVectorPosition.z > far * 1.4f||
        - cameraSpaceVectorPosition.z < 0.f)
        {
            break;
        }
        
        vec2 samplePos = currentPosition.xy;
        float sampleDepth = convertScreenSpaceToWorldSpace(samplePos).z;
        
        float currentDepth = cameraSpaceVectorPosition.z;
        float diff = sampleDepth - currentDepth;
        float error = length(cameraSpaceVector / pow(2.f, numRefinements));
        
        //If a collision was detected, refine raymarch
        if (diff >= 0&&diff <= error * 2.f&&numRefinements <= maxRefinements)
        {
            //Step back
            cameraSpaceVectorPosition -= cameraSpaceVector / pow(2.f, numRefinements);
            ++ numRefinements;
            //If refinements run out
        }
        else if (diff >= 0&&diff <= error * 4.f&&numRefinements > maxRefinements)
        {
            finalSamplePos = samplePos;
            finalSampleDepth = sampleDepth;
            break;
        }
        
        cameraSpaceVectorPosition += cameraSpaceVector / pow(2.f, numRefinements);
        
        if (numSteps > 1)
        cameraSpaceVector *= 1.375f; //Each step gets bigger
        
        currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
        
        if (edgeClamping)
        {
            currentPosition = clamp(currentPosition, vec3(0.001), vec3(0.999));
        }
        else
        {
            if (currentPosition.x < 0||currentPosition.x > 1||
                currentPosition.y < 0||currentPosition.y > 1||
            currentPosition.z < 0||currentPosition.z > 1)
            {
                break;
            }
        }
        
        count ++ ;
        numSteps ++ ;
    }
    
    vec4 color = vec4(1.0);
    color.rgb = pow(texture2DLod(texture, finalSamplePos, 0).rgb, vec3(2.2f));
    
    if (finalSamplePos.x == 0.f||finalSamplePos.y == 0.f) {
        color.a = 0.f;
    }
    
    //if (-finalSampleDepth >= far * 0.5)
    //	color.a = 0.0;
    
    //if (GetSkyMask(finalSamplePos))
    //color.a = 0.0f;
    
    return color;
}

vec3 Reflection(vec3 color, vec3 viewPos, vec3 normal) {
    vec3 viewRefRay = reflect(normalize(viewPos), normal);
    float fresnel = 0.02 + 0.98 * pow(1.0 - dot(viewRefRay, normal), 3.0);
    vec4 reflectColor = ComputeRaytraceReflection(normal, false);
    
    //reflectColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5)) * 2.0, 2.0), 0.0, 1.0);
    color = mix(color, reflectColor.rgb, reflectColor.a * fresnel);
    return color;
}

vec3 drawWater(vec3 color, vec4 positionInWorldCoord, vec4 positionInViewCoord, vec3 viewPos, vec3 normal) {
    positionInWorldCoord.xyz += cameraPosition; // 转为世界坐标（绝对坐标）
    
    // 波浪系数
    float wave = getWave(positionInWorldCoord);
    vec3 finalColor = color;
    finalColor *= wave; // 波浪纹理
    
    // 透射
    float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal)); // 计算视线和法线夹角余弦值
    cosine = clamp(abs(cosine), 0, 1);
    float factor = pow(1.0 - cosine, 4); // 透射系数
    finalColor = mix(color, finalColor, factor); // 透射计算
    
    // 按照波浪对法线进行偏移
    vec3 newNormal = normal;
    newNormal.z += 0.05 * (((wave - 0.4) / 0.6) * 2-1);
    newNormal = normalize(newNormal);
    
    //finalColor.rgb*=CalculateWaterCaustics(positionInViewCoord,newNormal)*0.5;
    #ifdef ENABLE_WATERREFLECTION
    finalColor.rgb = Reflection(finalColor.rgb, viewPos, newNormal);
    #endif
    
    return finalColor;
}

float GetDepthLinear(in vec2 coord) {
    //return 2.0f * near * far / (far + near - (2.0f * texture2D(depthtex1, coord).x - 1.0f) * (far - near));
    return (near * far) / (texture2D(depthtex1, coord).x * (near - far) + far);
}

void CalculateUnderwaterFog(inout vec3 finalComposite) {
    vec3 fogColor = vec3(0.2f, 0.5f, 0.95f);
    // float fogDensity = 0.045f;
    // float fogFactor = exp(GetDepthLinear(texcoord.st) * fogDensity) - 1.0f;
    // 	  fogFactor = min(fogFactor, 1.0f);
    float fogFactor = GetDepthLinear(texcoord.st) / 100.0f;
    fogFactor = min(fogFactor, 0.7f);
    fogFactor = sin(fogFactor * 3.1415 / 2.0f);
    fogFactor = pow(fogFactor, 0.5f);
    
    finalComposite.rgb = mix(finalComposite.rgb, fogColor * 0.002f, vec3(fogFactor));
    finalComposite.rgb *= mix(vec3(1.0f), vec3(0.0016f, 0.0625f, 0.814506f), vec3(fogFactor));
    //finalComposite.rgb = vec3(0.1f);
}

float getCaustics(vec4 positionInWorldCoord) {
    positionInWorldCoord.xyz += cameraPosition;
    
    // 波纹1
    float speed1 = float(frameCounter * 0.3) / (noiseTextureResolution * 15);
    vec3 coord1 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord1.x *= 4;
    coord1.x += speed1 * 2 + coord1.z;
    coord1.z -= speed1;
    float noise1 = texture2D(noisetex, coord1.xz).x;
    noise1 = noise1 * 2 - 1.0;
    
    // 波纹2
    float speed2 = float(frameCounter * 0.3) / (noiseTextureResolution * 15);
    vec3 coord2 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord2.z *= 4;
    coord2.z += speed2 * 2 + coord2.x;
    coord2.x -= speed2;
    float noise2 = texture2D(noisetex, coord2.xz).x;
    noise2 = noise2 * 2 - 1.0;
    
    return noise1 + noise2; // 叠加
}

/* DRAWBUFFERS:01 */
void main() {
    
    float type = texture2D(colortex3, texcoord.st).w;
    float matId = floor(texture2D(colortex3, texcoord.st).x * 255 + 0.1);
    float attr = texture2D(colortex1, texcoord.st).x;
    
    vec3 normal = normalDecode(texture2D(gnormal, texcoord.st).rg);
    float transparency = texture2D(gnormal, texcoord.st).z;
    float angle = texture2D(gnormal, texcoord.st).a;
    
    if (type == 1.0) {
        normal = normalDecode(texture2D(colortex3, texcoord.st).rg);
        angle = texture2D(colortex3, texcoord.st).b;
    }
    
    vec4 color = texture2D(texture, texcoord.st);
    
    float depth0 = texture2D(depthtex0, texcoord.st).x;
    float depth1 = texture2D(depthtex1, texcoord.st).x;
    
    vec4 positionInNdcCoord0 = vec4(texcoord.st * 2-1, depth0 * 2-1, 1);
    vec4 positionInClipCoord0 = gbufferProjectionInverse * positionInNdcCoord0;
    vec4 positionInViewCoord0 = vec4(positionInClipCoord0.xyz / positionInClipCoord0.w, 1.0);
    vec4 positionInWorldCoord0 = gbufferModelViewInverse * positionInViewCoord0;
    
    vec4 positionInNdcCoord1 = vec4(texcoord.st * 2-1, depth1 * 2-1, 1);
    vec4 positionInClipCoord1 = gbufferProjectionInverse * positionInNdcCoord1;
    vec4 positionInViewCoord1 = vec4(positionInClipCoord1.xyz / positionInClipCoord1.w, 1.0);
    vec4 positionInWorldCoord1 = gbufferModelViewInverse * (positionInViewCoord1 + vec4(normal * 0.05 * sqrt(abs(positionInViewCoord1.z)), 0.0));
    
    float underWaterFadeOut = 1-getUnderWaterFadeOut(depth0, depth1, positionInViewCoord0, normal);
    
    float dis = length(positionInWorldCoord1.xyz) / far;
    
    #ifdef BLOOM_EFFECT
    gl_FragData[1] = getBloomSource(color, positionInWorldCoord1, isNight, type);
    #endif
    //getBloomSource(color);
    if (dis < 1) {
        
        if (isLightSource(floor(texture2D(colortex3, texcoord.st).x * 255.f + 0.1)) < 1.0||type == 1.0) {
            
            color *= 1-isNight * 0.6;
            
            if (transparency > 0.0||type == 1.0) {
                transparency = max(transparency, type);
                //float underWaterFadeOut = getUnderWaterFadeOut(depth0, depth1, positionInViewCoord0, normal);
                if (angle <= 0.1) {
                    color = mix(color, color * SHADOW_STRENGTH, max(extShadow * 0.4, transparency));
                }else {
                    if (angle < 0.2) {
                        color = mix(color, mix(getShadow(color, positionInWorldCoord1, normal, dis), color * SHADOW_STRENGTH, max(max(extShadow * 0.4, underWaterFadeOut), 1 - (angle - 0.1) * 10)), transparency);
                    }else {
                        color = mix(color, mix(getShadow(color, positionInWorldCoord1, normal, dis), color * SHADOW_STRENGTH, max(extShadow * 0.4, underWaterFadeOut)), transparency);
                    }
                }
            }
        }
        
        if (isEyeInWater == 1.0 && positionInViewCoord0 == positionInViewCoord1) {
            color.rgb *= 1.0 + getCaustics(positionInWorldCoord1) * 0.25 * (1 - underWaterFadeOut);
        }
        
        if (type != 1.0)
        if (attr == 0.0) {
            color.rgb *= 1.0 + getCaustics(positionInWorldCoord1) * 0.25 * (1 - underWaterFadeOut);
            color.rgb = drawWater(color.rgb, positionInWorldCoord0, positionInViewCoord0, positionInClipCoord0.xyz, (texture2D(colortex4, texcoord.st).rgb - 0.5) * 2);
        }else {
            #ifdef ENABLE_BLOCKREFLECTION
            if (matId == 41.0 || matId == 42.0 || matId == 20.0 || matId == 57.0 || matId == 71.0 || matId == 95.0 || matId == 102.0 || matId == 160.0 || matId == 90.0 || matId == 133.0 || matId == 79.0) {
                color.rgb = Reflection(color.rgb, positionInClipCoord0.xyz, normal);
            }else {
                color.rgb = mix(color.rgb, Reflection(color.rgb, positionInClipCoord0.xyz, normal), pow(wetness, 2));
            }
            #endif
        }
    }
    
    if (isEyeInWater == 1.0 && nightVision == 0.0) {
        CalculateUnderwaterFog(color.rgb);
    }
    
    //gl_FragData[0] = vec4(vec3(transparency),1.0);
    gl_FragData[0] = color; // Problem From normals
    //gl_FragData[0] = vec4(normal, 1);
}