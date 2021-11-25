#version 120

#define SUNRISE 23200
#define SUNSET 12800
#define FADE_START 500
#define FADE_END 250

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;

varying float extShadow;
varying mat3 normalMatrix;
varying float isNight;
varying vec3 lightPosition;
varying vec4 texcoord;

void main(){
    gl_Position = ftransform();
    texcoord = gl_TextureMatrix[0]*gl_MultiTexCoord0;

	isNight = 0;
    if(12000<worldTime && worldTime<13000) {
        isNight = 1.0 - (13000-worldTime) / 1000.0;
    }
    else if(13000<=worldTime && worldTime<=23000) {
        isNight = 1;
    }
    else if(23000<worldTime) {
        isNight = (24000-worldTime) / 1000.0;
    }

    if(worldTime >= SUNRISE - FADE_START && worldTime <= SUNRISE + FADE_START)
	{
		extShadow = 1.0;
		if(worldTime < SUNRISE - FADE_END) extShadow -= float(SUNRISE - FADE_END - worldTime) / float(FADE_END); else if(worldTime > SUNRISE + FADE_END)
			extShadow -= float(worldTime - SUNRISE - FADE_END) / float(FADE_END);
	}
	else if(worldTime >= SUNSET - FADE_START && worldTime <= SUNSET + FADE_START)
	{
		extShadow = 1.0;
		if(worldTime < SUNSET - FADE_END) extShadow -= float(SUNSET - FADE_END - worldTime) / float(FADE_END); else if(worldTime > SUNSET + FADE_END)
			extShadow -= float(worldTime - SUNSET - FADE_END) / float(FADE_END);
	}
	else
		extShadow = 0.0;
}