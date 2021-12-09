#version 120

attribute vec4 mc_Entity;

varying vec4 color;
varying vec4 texcoord;
varying vec3 normal;
varying vec4 lmcoord;
varying float matId;

void main() {
    gl_Position = ftransform();
    gl_FogFragCoord = length(gl_ModelViewMatrix * gl_Vertex);
    texcoord = gl_MultiTexCoord0;
    color = gl_Color;
    normal = gl_NormalMatrix * gl_Normal;
    lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
    matId = mc_Entity.x;
}