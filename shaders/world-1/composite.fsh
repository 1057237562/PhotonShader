#version 120

#define SHADOW_MAP_BIAS 0.85
#define SHADOW_STRENGTH 0.45
#define SUNLIGHT_INTENSITY 2

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

vec4 getBloomSource(vec4 color, vec4 positionInWorldCoord, float IsNight, float type) {
    vec4 bloom = color;
    float id = floor(texture2D(colortex3, texcoord.st).x * 255 + 0.1);
    float brightness = dot(bloom.rgb, vec3(0.2125, 0.7154, 0.0721));
    if (type == 1.0) {
        bloom.rgb *= 0.1;
    }else if (id == 50.0||id == 76.0) {// torch
        if (brightness < 0.5) {
            bloom.rgb = vec3(0);
        }
        bloom.rgb *= 7*pow(brightness, 2) * (1 + IsNight);
    }else if (isLightSource(id) == 1.0) {// glowing blocks
        bloom.rgb *= 3*vec3(1, 0.5, 0.5) * (1 + IsNight * 0.35);
    }
    else {
        bloom.rgb *= 0.1;
    }
    return bloom;
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
    
    float dis = length(positionInWorldCoord1.xyz) / far;
    
    gl_FragData[1] = getBloomSource(color, positionInWorldCoord1, isNight, type); //getBloomSource(color);
    if (dis < 1) {
        if (type != 1.0)
        if (matId == 41.0 || matId == 42.0 || matId == 57.0 || matId == 71.0 || matId == 20.0 || matId == 95.0 || matId == 102.0 || matId == 160.0 || matId == 90.0 || matId == 133.0 || matId == 79.0) {
            color.rgb = Reflection(color.rgb, positionInClipCoord0.xyz, normal);
        }
    }
    
    //gl_FragData[0] = vec4(vec3(transparency),1.0);
    gl_FragData[0] = color; //vec4(DecodeNormal(texture2D(colortex1, texcoord.st).yz), 1.0); //color; //vec4(attr,0,0,1);//vec4(normal,1.);//vec4(normalDecode(texture2D(colortex3,texcoord.st).rg),1.);// Problem From normals
    
}