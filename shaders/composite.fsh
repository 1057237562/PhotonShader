#version 120

#define SHADOW_MAP_BIAS.85
#define SHADOW_STRENGTH.45
#define SUNLIGHT_INTENSITY 2

#define BISEARCH(SEARCHPOINT,DIRVEC,SIGN)DIRVEC*=.5;\
SEARCHPOINT+=DIRVEC*SIGN;\
uv=getScreenCoordByViewCoord(SEARCHPOINT);\
sampleDepth=linearizeDepth(texture2DLod(depthtex0,uv,0.).x);\
testDepth=getLinearDepthOfViewCoord(SEARCHPOINT);\
SIGN=sign(sampleDepth-testDepth);

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

vec4 getBloomSource(vec4 color,vec4 positionInWorldCoord,float IsNight,float type){
    vec4 bloom=color;
    float id=floor(texture2D(colortex3,texcoord.st).x*255+.1);
    float brightness=dot(bloom.rgb,vec3(.2125,.7154,.0721));
    if(type==1.){
        bloom.rgb*=.1;
    }else if(id==50.||id==76.){// torch
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

vec2 getScreenCoordByViewCoord(vec3 viewCoord){
    vec4 p=vec4(viewCoord,1.);
    p=gbufferProjection*p;
    p/=p.w;
    if(p.z<-1||p.z>1)
    return vec2(-1.);
    p=p*.5f+.5f;
    return p.st;
}

float linearizeDepth(float depth){
    return(2.*near)/(far+near-depth*(far-near));
}

float getLinearDepthOfViewCoord(vec3 viewCoord){
    vec4 p=vec4(viewCoord,1.);
    p=gbufferProjection*p;
    p/=p.w;
    return linearizeDepth(p.z*.5+.5);
}

vec3 waterRayTarcing(vec3 startPoint,vec3 direction,vec3 color,float fresnel){
    const float stepBase=.025;
    vec3 testPoint=startPoint;
    direction*=stepBase;
    bool hit=false;
    vec4 hitColor=vec4(0.);
    vec3 lastPoint=testPoint;
    for(int i=0;i<40;i++)
    {
        testPoint+=direction*pow(float(i+1),1.46);
        vec2 uv=getScreenCoordByViewCoord(testPoint);
        if(uv.x<0.||uv.x>1.||uv.y<0.||uv.y>1.)
        {
            hit=true;
            break;
        }
        float sampleDepth=texture2DLod(depthtex0,uv,0.).x;
        sampleDepth=linearizeDepth(sampleDepth);
        float testDepth=getLinearDepthOfViewCoord(testPoint);
        if(sampleDepth<testDepth&&testDepth-sampleDepth<(1./2048.)*(1.+testDepth*200.+float(i)))
        {
            vec3 finalPoint=lastPoint;//finalPoint为二分搜索后的最终位置
            float _sign=1.;
            direction=testPoint-lastPoint;
            BISEARCH(finalPoint,direction,_sign);
            BISEARCH(finalPoint,direction,_sign);
            BISEARCH(finalPoint,direction,_sign);
            BISEARCH(finalPoint,direction,_sign);
            uv=getScreenCoordByViewCoord(finalPoint);
            hitColor=vec4(texture2DLod(texture,uv,0.).rgb,1.);
            hitColor.a=clamp(1.-pow(distance(uv,vec2(.5))*2.,2.),0.,1.);
            hit=true;
            break;
        }
        lastPoint=testPoint;
    }
    if(!hit)
    {
        vec2 uv=getScreenCoordByViewCoord(lastPoint);
        float testDepth=getLinearDepthOfViewCoord(lastPoint);
        float sampleDepth=texture2DLod(depthtex0,uv,0.).x;
        sampleDepth=linearizeDepth(sampleDepth);
        if(testDepth-sampleDepth<.5)
        {
            hitColor=vec4(texture2DLod(gcolor,uv,0.).rgb,1.);
            hitColor.a=clamp(1.-pow(distance(uv,vec2(.5))*2.,2.),0.,1.);
        }
    }
    return mix(color,hitColor.rgb,hitColor.a*fresnel);
}

vec3 waterReflection(vec3 color,vec2 uv,vec3 viewPos,float attr){
    if(attr==0.){
        vec3 normal=normalDecode(texture2D(colortex1,texcoord.st).gb);
        vec3 viewRefRay=reflect(normalize(viewPos),normal);
        float fresnel=.02+.98*pow(1.-dot(viewRefRay,normal),3.);
        color=waterRayTarcing(viewPos+normal*(-viewPos.z/far*.2+.05),viewRefRay,color,fresnel);
    }
    return color;
}

/* DRAWBUFFERS:01 */
void main(){
    
    float type=texture2D(colortex3,texcoord.st).w;
    float attr=texture2D(colortex1,texcoord.st).x;
    
    vec3 normal=normalDecode(texture2D(gnormal,texcoord.st).rg);
    float transparency=texture2D(gnormal,texcoord.st).z;
    float angle=texture2D(gnormal,texcoord.st).a;
    
    if(type==1.){
        normal=normalDecode(texture2D(colortex3,texcoord.st).rg);
        angle=texture2D(colortex3,texcoord.st).b;
    }
    
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
    
    gl_FragData[1]=getBloomSource(color,positionInWorldCoord1,isNight,type);//getBloomSource(color);
    
    if(isLightSource(floor(texture2D(colortex3,texcoord.st).x*255.f+.1))<1.||type==1.){
        
        color*=1-isNight*.4;
        
        if(transparency>0.||type==1.){
            transparency=max(transparency,type);
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
    
    color.rgb=waterReflection(color.rgb,texcoord.st,positionInClipCoord1.xyz,attr);
    //gl_FragData[0] = vec4(vec3(transparency),1.0);
    gl_FragData[0]=color;//vec4(attr,0,0,1);//vec4(normal,1.);//vec4(normalDecode(texture2D(colortex3,texcoord.st).rg),1.);// Problem From normals
    
}