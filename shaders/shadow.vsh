#version 120

#define SHADOW_MAP_BIAS 0.85

attribute vec4 mc_Entity;
varying vec4 color;
varying vec4 texcoord;
varying float isTransparent;

float getIsTransparent(float matId){
    if(matId == 160.0 || matId == 95.0){ // stained glass
        return 1.0;
    }
    if(matId == 79.0 || matId == 174.0){ // ice
        return 0.25;
    }
    if(matId == 90.0){
        return 1.0;
    }
    return 0.0;
}

vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (1 + SHADOW_MAP_BIAS*(length(positionInNdcCoord.xy)-1));
}

void main(){
    gl_Position = ftransform();
    gl_Position.xy = getFishEyeCoord(gl_Position.xy);
    texcoord = gl_MultiTexCoord0;
    color = gl_Color;
    float id = mc_Entity.x;
    if (id == 8.0 || id == 9.0)
	{
		gl_Position.xyz += 10000.0;
	}
    isTransparent = getIsTransparent(id);
}