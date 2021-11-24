#version 120

#define SHADOW_MAP_BIAS.85
#define SHADOW_STRENGTH.45
#define SUNLIGHT_INTENSITY 2

uniform mat4 gbufferProjectionInverse;
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
uniform sampler2D noisetex;
uniform sampler2D shadowcolor1;
uniform sampler2D gnormal;
uniform sampler2D shadowtex1;
uniform sampler2D colortex3;

uniform float viewHeight;
uniform float viewWidth;

uniform sampler2D texture;

varying vec4 texcoord;
varying float extShadow;
varying float isNight;

const float sunPathRotation=-25.;
const int shadowMapResolution=2048;
const int noiseTextureResolution=64;
const bool shadowHardwareFiltering=true;
const float PI=3.14159265359;

vec2 getFishEyeCoord(vec2 positionInNdcCoord){
    return positionInNdcCoord/(1+SHADOW_MAP_BIAS*(length(positionInNdcCoord.xy)-1));
}

mat2 getRotationMatrix(vec2 coord){
    float theta=texture2D(noisetex,coord*vec2(viewWidth/noiseTextureResolution,viewHeight/noiseTextureResolution)).r;
    return mat2(cos(theta),-sin(theta),sin(theta),cos(theta));
}

float isLightSource(float id){
    if(id==10.||id==11.||id==50.||id==76.||id==51.||id==124.||id==89.||id==91.||id==169.||id==62.){
        return 1.;
    }
    return 0.;
}

vec4 getBloomSource(vec4 color,vec4 positionInWorldCoord,float IsNight){
    vec4 bloom=color;
    float id=floor(texture2D(colortex3,texcoord.st).x*255+.1);
    float brightness=dot(bloom.rgb,vec3(.2125,.7154,.0721));
    
    if(id==50.||id==76.){// torch
        if(brightness<.5){
            bloom.rgb=vec3(0);
        }
        bloom.rgb*=7*pow(brightness,2)*(1+IsNight);
    }else if(isLightSource(id)==1.){// glowing blocks
        bloom.rgb*=6*vec3(1,.5,.5)*(1+IsNight*.35);
    }
    else{
        bloom.rgb*=.1;
    }
    return bloom;
}

vec4 getShadow(vec4 color,vec4 positionInWorldCoord,vec3 normal){
    float dis=length(positionInWorldCoord.xyz)/far;
    float shade=0;
    vec3 shadowColor=vec3(0);
    // Minecraft to sun coord
    vec4 positionInLightViewCoord=shadowModelView*positionInWorldCoord;
    // sun coord to sun clip coord
    vec4 positionInLightClipCoord=shadowProjection*positionInLightViewCoord;
    // clip coord to ndc coord
    vec4 positionInLightNdcCoord=vec4(positionInLightClipCoord.xyz/positionInLightClipCoord.w,1.);
    positionInLightNdcCoord.xy=getFishEyeCoord(positionInLightNdcCoord.xy);
    // ndc to sun camera coord
    vec4 positionInLightScreenCoord=positionInLightNdcCoord*.5+.5;
    
    float currentDepth=positionInLightScreenCoord.z;
    mat2 rot=getRotationMatrix(positionInWorldCoord.xy);
    
    float dist=sqrt(positionInLightNdcCoord.x*positionInLightNdcCoord.x+positionInLightNdcCoord.y*positionInLightNdcCoord.y);
    
    float diffthresh=dist*1.f+.10f;
    diffthresh*=1f/(shadowMapResolution/2048.f);
    //diffthresh /= shadingStruct.direct + 0.1f;
    
    for(int i=-1;i<2;i++){
        for(int j=-1;j<2;j++){
            vec2 offset=vec2(i,j)/shadowMapResolution;
            offset=rot*offset;
            float solidDepth=texture2DLod(shadowtex1,positionInLightScreenCoord.st,0).x;
            float solidShadow=1.-clamp((positionInLightScreenCoord.z-solidDepth)*1200.,0.,1.);
            shadowColor+=texture2DLod(shadowcolor1,positionInLightScreenCoord.xy+offset,0).rgb*solidShadow;
            shade+=shadow2D(shadow,vec3(positionInLightScreenCoord.st+offset,positionInLightScreenCoord.z-.0008*diffthresh)).z*SUNLIGHT_INTENSITY;
        }
    }
    shade*=.111;
    shadowColor*=.75;
    shadowColor=mix(shadowColor,vec3(0.),isNight*.90);//vec4(shadowColor*0.111,1.0);//
    color=mix(vec4(shadowColor*.111,1.),color,clamp(shade,clamp(dis*(isNight*.4+1),SHADOW_STRENGTH,1),1));
    return color;
}

vec3 normalDecode(vec2 enc){
    vec4 nn=vec4(2.*enc-1.,1.,-1.);
    float l=dot(nn.xyz,-nn.xyw);
    nn.z=l;
    nn.xy*=sqrt(l);
    return nn.xyz*2.+vec3(0.,0.,-1.);
}

/*
*  @function screenDepthToLinerDepth   : 深度缓冲转线性深度
*  @param screenDepth                  : 深度缓冲中的深度
*  @return                             : 真实深度 -- 以格为单位
*/
float screenDepthToLinerDepth(float screenDepth) {
    return 2 * near * far / ((far + near) - screenDepth * (far - near));
}

/*
*  @function getUnderWaterFadeOut  : 计算水下淡出系数
*  @param d0                       : 深度缓冲0中的原始数值
*  @param d1                       : 深度缓冲1中的原始数值
*  @param positionInViewCoord      : 眼坐标包不包含水面均可，因为我们将其当作视线方向向量
*  @param normal                   : 眼坐标系下的法线
*  @return                         : 淡出系数
*/
float getUnderWaterFadeOut(float d0, float d1, vec4 positionInViewCoord, vec3 normal) {
    d0 = screenDepthToLinerDepth(d0);
    d1 = screenDepthToLinerDepth(d1);
    
    float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal));
    cosine = clamp(abs(cosine), 0, 1);
    
    return clamp(1.0 - (d1 - d0) * cosine * 0.1, 0, 1);
}


/* DRAWBUFFERS:01 */
void main(){
    vec3 normal=normalDecode(texture2D(gnormal,texcoord.st).rg);
    float transparency=texture2D(gnormal,texcoord.st).z;
    float angle=texture2D(gnormal,texcoord.st).a;
    
    vec4 color=texture2D(texture,texcoord.st);
    
    float depth0=texture2D(depthtex0,texcoord.st).x;
    float depth1=texture2D(depthtex1,texcoord.st).x;
    
    vec4 positionInNdcCoord0=vec4(texcoord.st*2-1,depth0*2-1,1);
    vec4 positionInClipCoord0=gbufferProjectionInverse*positionInNdcCoord0;
    vec4 positionInViewCoord0=vec4(positionInClipCoord0.xyz/positionInClipCoord0.w,1.);
    vec4 positionInWorldCoord0=gbufferModelViewInverse*positionInViewCoord0;
    
    vec4 positionInNdcCoord1=vec4(texcoord.st*2-1,depth1*2-1,1);
    vec4 positionInClipCoord1=gbufferProjectionInverse*positionInNdcCoord1;
    vec4 positionInViewCoord1=vec4(positionInClipCoord1.xyz/positionInClipCoord1.w,1.);
    vec4 positionInWorldCoord1=gbufferModelViewInverse*(positionInViewCoord1+vec4(normal*.05*sqrt(abs(positionInViewCoord1.z)),0.));
    
    gl_FragData[1]=getBloomSource(color,positionInWorldCoord1,isNight);//getBloomSource(color);
    
    if(isLightSource(floor(texture2D(colortex3,texcoord.st).x*255.f+.1))<1.){
        
        color*=1-isNight*.4;
        
        if(transparency>0.){
            //float underWaterFadeOut = getUnderWaterFadeOut(depth0, depth1, positionInViewCoord0, normal);
            if(angle<=.1&&extShadow==0.){
                if(angle<=0){
                    color=mix(color,color*SHADOW_STRENGTH,transparency);
                }else{
                    color=mix(color,color*SHADOW_STRENGTH,min(transparency,1-angle*10));
                }
            }else{
                color=mix(color,mix(getShadow(color,positionInWorldCoord1,normal),color*SHADOW_STRENGTH,extShadow),transparency);
            }
        }
    }
    //gl_FragData[0] = vec4(vec3(transparency),1.0);
    gl_FragData[0]=vec4(vec3(angle),1.);// Problem From normals
    
}