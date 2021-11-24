#version 120

attribute vec4 mc_Entity;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
const int noiseTextureResolution = 64;
uniform sampler2D noisetex;

uniform vec3 cameraPosition;
uniform int frameCounter;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;
varying float attr;
varying vec4 position;

/*
 *  @function getBump          : 水面凹凸计算
 *  @param positionInViewCoord : 眼坐标系中的坐标
 *  @return                    : 计算凹凸之后的眼坐标
 */
vec4 getBump(vec4 positionInViewCoord) {
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;  // “我的世界坐标”
    positionInWorldCoord.xyz += cameraPosition; // 世界坐标（绝对坐标）

	/*float speed1 = float(frameCounter*0.25) / (noiseTextureResolution * 15);
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

	positionInWorldCoord.y += n2 * 0.2 - 0.1;*/
    positionInWorldCoord.y += sin(float(frameCounter*0.05) + positionInWorldCoord.z * 2) * 0.025 + cos(float(frameCounter*0.05) + positionInWorldCoord.x * 2) * 0.025;

    positionInWorldCoord.xyz -= cameraPosition; // 转回 “我的世界坐标”
    return gbufferModelView * positionInWorldCoord; // 返回眼坐标
}


void main()
{
	float blockId = mc_Entity.x;
	position = gl_ModelViewMatrix * gl_Vertex;
	if(mc_Entity.x == 8 || mc_Entity.x == 9){
		attr = 1.0;
		gl_Position = gbufferProjection * getBump(position);
	}else{
		if(mc_Entity.x == 79){
			attr = 0.35;
		}else{
			attr = 0.0;
		}
		
		gl_Position = gbufferProjection * position;
	}

	gl_FogFragCoord = length(position.xyz);
	color = gl_Color;
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	normal = gl_NormalMatrix * gl_Normal;
}