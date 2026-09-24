package com.edgard.tunel.render

import android.opengl.GLES20

class ShaderProgram {
    var id: Int = 0
        private set
    var aPos: Int = 0
    var aNormal: Int = 0
    var aColor: Int = 0
    var uMvp: Int = 0
    var uModel: Int = 0
    var uLightPos: Int = 0
    var uCamPos: Int = 0
    var uTint: Int = 0
    var uLightColor: Int = 0

    fun compile() {
        val vs = compile(GLES20.GL_VERTEX_SHADER, VERT)
        val fs = compile(GLES20.GL_FRAGMENT_SHADER, FRAG)
        id = GLES20.glCreateProgram()
        GLES20.glAttachShader(id, vs)
        GLES20.glAttachShader(id, fs)
        GLES20.glBindAttribLocation(id, 0, "aPos")
        GLES20.glBindAttribLocation(id, 1, "aNormal")
        GLES20.glBindAttribLocation(id, 2, "aColor")
        GLES20.glLinkProgram(id)
        aPos = 0
        aNormal = 1
        aColor = 2
        uMvp = GLES20.glGetUniformLocation(id, "uMvp")
        uModel = GLES20.glGetUniformLocation(id, "uModel")
        uLightPos = GLES20.glGetUniformLocation(id, "uLightPos")
        uCamPos = GLES20.glGetUniformLocation(id, "uCamPos")
        uTint = GLES20.glGetUniformLocation(id, "uTint")
        uLightColor = GLES20.glGetUniformLocation(id, "uLightColor")
    }

    fun use() = GLES20.glUseProgram(id)

    private fun compile(type: Int, src: String): Int {
        val s = GLES20.glCreateShader(type)
        GLES20.glShaderSource(s, src)
        GLES20.glCompileShader(s)
        return s
    }

    companion object {
        private const val VERT = """
attribute vec3 aPos;
attribute vec3 aNormal;
attribute vec4 aColor;
uniform mat4 uMvp;
uniform mat4 uModel;
varying vec3 vN;
varying vec3 vW;
varying vec4 vC;
void main() {
  vec4 w = uModel * vec4(aPos, 1.0);
  vW = w.xyz;
  vN = mat3(uModel) * aNormal;
  vC = aColor;
  gl_Position = uMvp * vec4(aPos, 1.0);
}
"""
        private const val FRAG = """
precision mediump float;
uniform vec3 uLightPos;
uniform vec3 uCamPos;
uniform vec4 uTint;
uniform vec3 uLightColor;
varying vec3 vN;
varying vec3 vW;
varying vec4 vC;
void main() {
  vec3 n = normalize(vN);
  vec3 l = normalize(uLightPos - vW);
  float diff = max(dot(n, l), 0.0);
  vec3 col = vC.rgb * uTint.rgb * (0.32 + diff * 0.78) * uLightColor;
  float dist = length(uCamPos - vW);
  float fog = clamp((dist - 10.0) / 36.0, 0.0, 0.5);
  col = mix(col, vec3(0.05, 0.06, 0.08), fog);
  gl_FragColor = vec4(col, vC.a * uTint.a);
}
"""
    }
}
