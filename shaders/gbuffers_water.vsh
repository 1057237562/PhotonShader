#version 120

attribute vec4 mc_Entity;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
const int noiseTextureResolution=64;
uniform sampler2D noisetex;

uniform vec3 cameraPosition;
uniform int frameCounter;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;
varying float attr;
varying vec4 position;

float getWave(vec4 position){
	return sin(float(frameCounter*.05)+position.z*2)*.025+cos(float(frameCounter*.05)+position.x*2)*.025;
}

vec4 getBump(vec4 position){
	vec4 positionInWorldCoord=gbufferModelViewInverse*position;// “我的世界坐标”
	positionInWorldCoord.xyz+=cameraPosition;// 世界坐标（绝对坐标）
	positionInWorldCoord.y+=getWave(position);
	
	positionInWorldCoord.xyz-=cameraPosition;// 转回 “我的世界坐标”
	return gbufferModelView*positionInWorldCoord;// 返回眼坐标
}

void main()
{
	float blockId=mc_Entity.x;
	position=gl_ModelViewMatrix*gl_Vertex;
	if(mc_Entity.x==8||mc_Entity.x==9){
		attr=1.;
		gl_Position=gbufferProjection*getBump(position);
	}else{
		if(mc_Entity.x==79){
			attr=.35;
		}else{
			attr=0.;
		}
		
		gl_Position=gbufferProjection*position;
	}
	
	gl_FogFragCoord=length(position.xyz);
	color=gl_Color;
	texcoord=gl_TextureMatrix[0]*gl_MultiTexCoord0;
	lmcoord=gl_TextureMatrix[1]*gl_MultiTexCoord1;
	normal=gl_NormalMatrix*gl_Normal;
}