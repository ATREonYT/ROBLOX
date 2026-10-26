// GLSL for render13 (README.md explains the model). All lighting is linear, in Roblox light units, before exposure.

// Shared by the sky and the world shader: the sky colour in a direction (no clouds), used for the background, the
// Atmosphere's fog colour and reflections.
export const SKY_GLSL = /* glsl */`
uniform vec3 uZenith, uHorizon, uAtmCol, uDecay, uSunDir, uSunCol, uCloudCol;
uniform float uHaze, uGlare, uDensity, uOffset, uSkyDim, uCloudCover, uCloudDensity, uSunSize, uSkyK;
vec3 skyBase(vec3 d) {
  float y = max(d.y, 0.0);
  vec3 c = mix(uHorizon, uZenith, pow(y, 0.32));
  float hz = exp(-y * (10.0 - 7.0 * min(1.0, uHaze / 3.0)));
  c = mix(c, uAtmCol * 1.05, min(1.0, hz * min(1.0, uHaze * 0.7 + uDensity * 0.9)));
  // Decay: with Haze and Glare the half of the sky away from the sun drifts toward Decay; Glare brightens around the sun.
  float cs = dot(d, uSunDir);
  if (uHaze > 0.0 && uGlare > 0.0) {
    c = mix(c, uDecay, 0.35 * min(1.0, uHaze) * uGlare * (0.5 - 0.5 * cs) * hz);
    c += uAtmCol * uGlare * 0.6 * pow(max(cs, 0.0), 8.0);
  }
  if (d.y < 0.0) c *= 1.0 - 0.45 * min(1.0, -d.y * 3.0);
  return c * uSkyDim * uSkyK;
}
// LIGHT2: Roblox's tone curve is filmic (ACES, Narkowicz's fit): the Studio frames user_30..32 fit it 5x better than a
// linear curve (dark saturated colours lose their low channels, light ones whiten). acesInv gives the HDR value that
// tone-maps to y (Neon: Studio shows a Neon part at about its Color3, a little brighter, then Bloom).
vec3 acesInv(vec3 y) {
  y = min(y, vec3(0.985));
  vec3 A = y * 2.43 - 2.51, B = y * 0.59 - 0.03, C = y * 0.14;
  return (-B - sqrt(max(B * B - 4.0 * A * C, 0.0))) / (2.0 * A);
}
vec3 srgbToLin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 linToSrgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(1e-6)), vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
  vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + vec2(17.1, 9.2); a *= 0.5; } return s; }
`;

export const SKY_VERT = /* glsl */`
uniform mat4 uInvViewProj;
varying vec3 vDir;
void main() {
  vec4 a = uInvViewProj * vec4(position.xy, -1.0, 1.0), b = uInvViewProj * vec4(position.xy, 1.0, 1.0);
  vDir = b.xyz / b.w - a.xyz / a.w;
  gl_Position = vec4(position.xy, 0.9999, 1.0);
}`;

// The sky: the default skybox's blue gradient, Terrain Clouds (Cover, Density, Color) as a cumulus layer, the sun disc.
export const SKY_FRAG = /* glsl */`
uniform float uExposure;
varying vec3 vDir;
void main() {
  vec3 d = normalize(vDir);
  vec3 c = skyBase(d);
  // sun disc and its glow (SunAngularSize)
  float cs = dot(d, uSunDir), r = radians(uSunSize * 0.25);
  float ang = acos(clamp(cs, -1.0, 1.0));
  c += uSunCol * 12.0 * (1.0 - smoothstep(r * 0.55, r * 0.6, ang)) + uSunCol * 0.35 * exp(-ang / (r * 1.6));
  // cloud layer (Terrain Clouds): puffy cumulus on a plane far overhead; white tops, grey-blue undersides toward the horizon
  if (uCloudCover > 0.0 && d.y > 0.0) {
    vec2 p = d.xz / (d.y + 0.05) * 0.32 + vec2(0.37, 0.81);
    float n = fbm(p * 2.2) * 0.75 + vnoise(p * 0.9) * 0.25;
    // like the default skybox, clouds bunch toward the horizon
    float t = mix(0.74, 0.34, uCloudCover) - 0.07 * (1.0 - smoothstep(0.02, 0.35, d.y));
    float m = smoothstep(t, t + 0.07, n);
    vec2 outward = normalize(p - vec2(0.37, 0.81) + 1e-4) * 0.06;
    float nb = fbm((p + outward) * 2.2) * 0.75 + vnoise((p + outward) * 0.9) * 0.25;
    float lit = clamp(0.7 + (nb - n) * 7.0 - (n - t) * 0.6, 0.0, 1.0);
    float a = m * mix(0.6, 1.0, min(1.0, uCloudDensity * 2.5)) * smoothstep(0.0, 0.04, d.y);
    vec3 cl = uCloudCol * mix(vec3(0.66, 0.71, 0.82), vec3(1.25), lit) * uSkyDim * uSkyK;
    cl = mix(cl, skyBase(d), (1.0 - smoothstep(0.01, 0.2, d.y)) * 0.3);
    c = mix(c, cl, a);
  }
  gl_FragColor = vec4(c * uExposure, 1.0);
}`;

export const WORLD_VERT = /* glsl */`
invariant gl_Position;
attribute vec3 acol;
attribute vec4 amat;
varying vec3 vWorld;
varying vec3 vNormal;
varying vec3 vCol;
varying vec2 vUv;
varying vec4 vMat;
void main() {
  vec4 wp = modelMatrix * vec4(position, 1.0);
  vWorld = wp.xyz; vNormal = normalize(mat3(modelMatrix) * normal); vCol = acol; vUv = uv; vMat = amat;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

export const WORLD_FRAG = /* glsl */`
uniform vec3 uCam, uBotCol, uAmb, uOut, uEnvUp, uEnvSide, uEnvDown;
uniform float uEnvSpec, uExposure, uNeon, uFogK, uHazeK, uFogOn, uLFall, uTone, uStudB, uStudD;
uniform sampler2D uShadowMap0, uShadowMap1; uniform mat4 uShadowMat0, uShadowMat1; uniform float uShadowRange0, uShadowRange1, uShadowTexel0, uShadowTexel1, uShadowSoft, uShadowOn;
uniform sampler2D uSkyMap0, uSkyMap1, uSkyMap2, uSkyMap3, uSkyMap4;
uniform mat4 uSkyMat[5]; uniform float uSkyRange, uSkyTexel, uSkyOn;
uniform int uLightCount; uniform vec3 uLightPos[MAXL]; uniform vec3 uLightCol[MAXL]; uniform float uLightRange[MAXL];
uniform float uOpacity; uniform vec3 uTint; uniform sampler2D uMap; uniform vec4 uMapXf;
varying vec3 vWorld;
varying vec3 vNormal;
varying vec3 vCol;
varying vec2 vUv;
varying vec4 vMat;

const vec2 PD[16] = vec2[](vec2(-0.94201624, -0.39906216), vec2(0.94558609, -0.76890725), vec2(-0.094184101, -0.92938870), vec2(0.34495938, 0.29387760),
  vec2(-0.91588581, 0.45771432), vec2(-0.81544232, -0.87912464), vec2(-0.38277543, 0.27676845), vec2(0.97484398, 0.75648379),
  vec2(0.44323325, -0.97511554), vec2(0.53742981, -0.47373420), vec2(-0.26496911, -0.41893023), vec2(0.79197514, 0.19090188),
  vec2(-0.24188840, 0.99706507), vec2(-0.81409955, 0.91437590), vec2(0.19984126, 0.78641367), vec2(0.14383161, -0.14100790));

// Sun shadow: PCSS-style, the penumbra grows with the distance to the blocker (ShadowSoftness; LightingStyle Soft >= 0.35).
float cascadeShadow(sampler2D smap, vec3 c, float texel, float range, float ndl) {
  float uvPerStud = 1.0 / (texel * float(SHADOW_RES));
  float ang = 6.2831853 * fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
  mat2 rot = mat2(cos(ang), sin(ang), -sin(ang), cos(ang));
  float tanA = clamp(sqrt(max(1.0 - ndl * ndl, 0.0)) / max(ndl, 0.08), 0.0, 8.0);
  float sr = (0.4 + 5.0 * uShadowSoft) * uvPerStud;
  float blk = 0.0, nb = 0.0;
  float b0 = (0.05 + tanA * (0.4 + 5.0 * uShadowSoft) * 0.5) / range;
  for (int i = 0; i < 12; i++) { float d = texture2D(smap, c.xy + rot * PD[i] * sr).r; if (d < c.z - b0) { blk += d; nb += 1.0; } }
  if (nb < 0.5) return 1.0;
  blk /= nb;
  float dist = (c.z - blk) * range;
  float pen = max(0.06 + dist * uShadowSoft * 0.16, texel * 1.2);
  float pr = pen * uvPerStud;
  float bias = (0.05 + tanA * pen * 0.7) / range;
  float lit = 0.0;
  for (int i = 0; i < 16; i++) { float d = texture2D(smap, c.xy + rot * PD[i] * pr).r; lit += d < c.z - bias ? 0.0 : 1.0; }
  return lit / 16.0;
}
// Sun shadow: PCSS-style, the penumbra grows with the distance to the blocker (ShadowSoftness; LightingStyle Soft >= 0.35).
// Near cascade first (the first 60 studs), the far one beyond.
float sunShadow(vec3 wp, vec3 n, float ndl) {
  vec4 s0 = uShadowMat0 * vec4(wp + n * (uShadowTexel0 * 1.5 + 0.03), 1.0);
  vec3 c0 = s0.xyz / s0.w;
  if (c0.x > 0.03 && c0.x < 0.97 && c0.y > 0.03 && c0.y < 0.97 && c0.z < 1.0) return cascadeShadow(uShadowMap0, c0, uShadowTexel0, uShadowRange0, ndl);
  vec4 s1 = uShadowMat1 * vec4(wp + n * (uShadowTexel1 * 1.5 + 0.03), 1.0);
  vec3 c1 = s1.xyz / s1.w;
  if (c1.x <= 0.0 || c1.x >= 1.0 || c1.y <= 0.0 || c1.y >= 1.0 || c1.z >= 1.0) return 1.0;
  return cascadeShadow(uShadowMap1, c1, uShadowTexel1, uShadowRange1, ndl);
}
// Sky visibility (Roblox's voxel lighting decides indoor vs outdoor per 4-stud voxel): depth maps seen from straight up and
// from four 55-degree directions, sampled with a ~1.5-stud blur at the open air beside the surface.
float skyTap(sampler2D m, mat4 M, vec3 p, float rStud, float bStud) {
  vec4 s = M * vec4(p, 1.0); vec3 c = s.xyz / s.w;
  if (c.x <= 0.0 || c.x >= 1.0 || c.y <= 0.0 || c.y >= 1.0) return 1.0;
  float r = rStud / (uSkyTexel * 1024.0), b = bStud / uSkyRange;
  // per-pixel rotated taps: steps between tap counts become a fine grain
  float ang = 6.2831853 * fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))) + 0.37);
  vec2 e1 = vec2(cos(ang), sin(ang)) * r, e2 = vec2(-e1.y, e1.x);
  float v = 0.0;
  v += step(c.z - b, texture2D(m, c.xy + e1).r);
  v += step(c.z - b, texture2D(m, c.xy + e2).r);
  v += step(c.z - b, texture2D(m, c.xy - e1).r);
  v += step(c.z - b, texture2D(m, c.xy - e2).r);
  return v * 0.25;
}
float skyVis(vec3 wp, vec3 n) {
  if (uSkyOn < 0.5) return 1.0;
  // the open air beside the surface; the slanted maps see their own wall at a grazing angle, so they get a bigger bias
  vec3 p = wp + n * 2.5 + vec3(0.0, 0.5, 0.0);
  float v = 0.4 * skyTap(uSkyMap0, uSkyMat[0], p, 0.6, 0.4);
  v += 0.15 * (skyTap(uSkyMap1, uSkyMat[1], p, 0.9, 1.3) + skyTap(uSkyMap2, uSkyMat[2], p, 0.9, 1.3) + skyTap(uSkyMap3, uSkyMat[3], p, 0.9, 1.3) + skyTap(uSkyMap4, uSkyMat[4], p, 0.9, 1.3));
  return v;
}
vec3 envIrr(vec3 n) { return n.y >= 0.0 ? mix(uEnvSide, uEnvUp, n.y) : mix(uEnvSide, uEnvDown, -n.y); }

// Classic stud (the Studs surface): a raised rounded square about 0.55 studs wide whose bevel takes the light, with a
// thin groove round its foot. Returns a tangent-space normal; ao darkens the groove. Fades out when a stud gets small.
vec3 studNormal(vec2 uv, out float ao) {
  vec2 fw = fwidth(uv);
  float fade = 1.0 - smoothstep(0.16, 0.42, max(fw.x, fw.y));
  ao = 1.0;
  if (fade <= 0.0) return vec3(0.0, 0.0, 1.0);
  vec2 f = fract(uv) - 0.5;
  float h = 0.27, rr = 0.07, bw = 0.06;
  vec2 q = abs(f) - (h - rr);
  float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
  vec2 g = (q.x > 0.0 && q.y > 0.0) ? sign(f) * normalize(q) : (q.x > q.y ? vec2(sign(f.x), 0.0) : vec2(0.0, sign(f.y)));
  float px = min(max(fw.x, fw.y), 0.04);
  float ring = smoothstep(-bw - px * 0.5, -bw + px * 0.5, sd) * (1.0 - smoothstep(-px * 0.5, px * 0.5, sd));
  float groove = smoothstep(-px * 0.5, px * 0.5, sd) * (1.0 - smoothstep(0.03, 0.03 + px, sd));
  ao = 1.0 - 0.08 * groove * fade;
  return normalize(vec3(g * 1.15 * ring * fade, 1.0));
}

// LIGHT3 (BRIEF23): Roblox's Studs surface as the user's Studio shows it (ours_studio_spawn.png): a baked texture, not a lit
// bump. Each stud is a rounded square ~0.58 wide whose edge carries a light stroke on its upper and right sides and a dark
// stroke (the "7" seen on floors) on its lower and left sides, the same in sun and shade; Roblox turns the texture 180
// degrees on top faces (the dark "7" sits on a floor's north and east edges). Returns a colour multiplier; the strokes fade
// out (to an average of about 1) once a stud is smaller than ~3 pixels, as the mipmapped texture does.
float studBaked(vec2 uv, float kind) {
  if (kind > 1.5 && kind < 2.5) uv = -uv;
  vec2 fw = fwidth(uv);
  float fade = 1.0 - smoothstep(0.16, 0.42, max(fw.x, fw.y));
  if (fade <= 0.0) return 1.0;
  vec2 f = fract(uv) - 0.5;
  float h = 0.29, rr = 0.08;
  vec2 q = abs(f) - (h - rr);
  float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
  vec2 g = (q.x > 0.0 && q.y > 0.0) ? sign(f) * normalize(q) : (q.x > q.y ? vec2(sign(f.x), 0.0) : vec2(0.0, sign(f.y)));
  float s = dot(g, vec2(0.70710678));
  float bw = s > 0.0 ? 0.12 : 0.07; // the light stroke is the wider one
  float px = min(max(fw.x, fw.y), 0.05);
  float ring = smoothstep(-bw - px * 0.5, -bw + px * 0.5, sd) * (1.0 - smoothstep(-px * 0.5, px * 0.5, sd));
  float groove = smoothstep(-px * 0.5, px * 0.5, sd) * (1.0 - smoothstep(0.03, 0.03 + px, sd));
  float m = s > 0.0 ? 1.0 + uStudB * s * 1.41421356 : 1.0 - uStudD * min(-s * 1.41421356, 1.0);
  m = mix(1.0, m, ring) * (1.0 - 0.12 * groove);
  return mix(1.0, m, fade);
}

// Material patterns: albedo multipliers drawn from uv (in studs), like the 2022 material textures at a glance.
float matPattern(float id, vec2 uv) {
  if (id < 2.5) return 1.0;
  if (id > 8.5 && id < 9.5) { // Brick: 2 x 0.66 bricks, lighter mortar
    float row = floor(uv.y / 0.666); vec2 b = vec2(uv.x + mod(row, 2.0) * 1.0, uv.y);
    vec2 fb = vec2(fract(b.x / 2.0) * 2.0, fract(b.y / 0.666) * 0.666);
    float mortar = 1.0 - step(0.07, fb.x) * step(0.07, fb.y);
    return mix(0.94 + 0.12 * hash12(vec2(floor(b.x / 2.0), row)), 1.25, mortar);
  }
  if (id > 7.5 && id < 8.5) { float l = step(0.94, fract(uv.y)); return mix(0.95 + 0.1 * hash12(vec2(floor(uv.y), 3.0)), 0.72, l); } // WoodPlanks
  if (id > 6.5 && id < 7.5) return 0.93 + 0.1 * vnoise(vec2(uv.x * 0.5, uv.y * 9.0)); // Wood grain
  if (id > 3.5 && id < 4.5) { // DiamondPlate: raised diagonal bars alternating direction
    vec2 f = fract(uv * 1.5) - 0.5; float ch = mod(floor(uv.x * 1.5) + floor(uv.y * 1.5), 2.0);
    float d = ch > 0.5 ? abs(f.x - f.y) : abs(f.x + f.y);
    return 0.92 + 0.18 * (1.0 - smoothstep(0.05, 0.1, d)) * step(abs(f.x) + abs(f.y), 0.55);
  }
  if (id > 2.5 && id < 3.5) return 0.95 + 0.07 * vnoise(vec2(uv.x * 0.3, uv.y * 14.0)); // Metal, brushed
  if (id > 4.5 && id < 5.5) return 0.85 + 0.3 * vnoise(uv * 5.0); // Foil
  if (id > 13.5 && id < 14.5) return 0.95 + 0.05 * step(0.5, fract(uv.x * 6.0)) * step(0.5, fract(uv.y * 6.0)); // Fabric
  if (id > 10.5 && id < 11.5) return 0.88 + 0.22 * fbm(uv * 2.0); // Grass
  return 0.9 + 0.16 * fbm(uv * 1.7); // concrete, asphalt, slate, stone, sand ...
}

void main() {
  float id = floor(vMat.x + 0.5), rough = vMat.y, metal = vMat.z;
  vec3 N = normalize(vNormal);
  if (!gl_FrontFacing) N = -N;
  vec3 albedo = vCol;
  float alpha = 1.0;
#ifdef DECAL
  vec4 tx = texture2D(uMap, vUv * uMapXf.xy + uMapXf.zw);
  albedo = tx.rgb * uTint; alpha = tx.a;
#endif
  albedo *= matPattern(id, vUv);
  float ao = 1.0, studMul = 1.0;
  if (vMat.w > 0.5) {
    if (uStudB + uStudD > 0.0) studMul = studBaked(vUv, vMat.w);
    else {
      vec3 dp1 = dFdx(vWorld), dp2 = dFdy(vWorld); vec2 duv1 = dFdx(vUv), duv2 = dFdy(vUv);
      vec3 dp2perp = cross(dp2, N), dp1perp = cross(N, dp1);
      vec3 T = dp2perp * duv1.x + dp1perp * duv2.x, B = dp2perp * duv1.y + dp1perp * duv2.y;
      float im = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-12));
      vec3 tn = studNormal(vUv, ao);
      N = normalize(T * im * tn.x + B * im * tn.y + N * tn.z);
    }
  }
  vec3 V = normalize(uCam - vWorld);
  float dist = length(uCam - vWorld);
  vec3 col;
  if (id > 1.5 && id < 2.5) {
    // Neon: emissive and unlit; bright enough that the tone curve whitens its core and Bloom haloes it.
    col = uTone > 0.5 ? acesInv(srgbToLin(min(linToSrgb(albedo) * uNeon, vec3(1.0)))) / uExposure : albedo * uNeon;
  } else {
    vec3 L = uSunDir;
    float ndl = dot(N, L), nGeo = dot(normalize(vNormal) * (gl_FrontFacing ? 1.0 : -1.0), L);
    float sh = (uShadowOn > 0.5 && nGeo > 0.0) ? sunShadow(vWorld, normalize(vNormal) * (gl_FrontFacing ? 1.0 : -1.0), nGeo) : (nGeo > 0.0 ? 1.0 : 0.0);
    float vis = skyVis(vWorld, normalize(vNormal) * (gl_FrontFacing ? 1.0 : -1.0));
    vec3 diffuseLight = uSunCol * max(ndl, 0.0) * sh + uBotCol * max(-ndl, 0.0) * vis
      + (mix(uAmb, uOut, vis) + envIrr(N) * vis) * ao;
    for (int i = 0; i < MAXL; i++) {
      if (i >= uLightCount) break;
      vec3 ld = uLightPos[i] - vWorld; float d = length(ld), r = uLightRange[i];
      if (d >= r) continue;
      float att = pow(max(1.0 - d / r, 0.0), uLFall);
      diffuseLight += uLightCol[i] * att * max(dot(N, ld / d), 0.0);
    }
    vec3 F0 = mix(vec3(0.04), albedo, metal);
    col = albedo * diffuseLight * (1.0 - 0.5 * metal) * ao;
    // sun highlight (Blinn-Phong matched to roughness) and sky reflection (EnvironmentSpecularScale)
    vec3 Hh = normalize(L + V);
    float a2 = rough * rough * rough * rough;
    float shin = min(2.0 / max(a2, 1e-4) - 2.0, 4096.0);
    float D = (shin + 8.0) / 25.13 * pow(max(dot(N, Hh), 0.0), shin);
    vec3 F = F0 + (1.0 - F0) * pow(1.0 - max(dot(Hh, V), 0.0), 5.0);
    col += F * D * uSunCol * max(ndl, 0.0) * sh * (1.0 - rough * 0.6);
    float nv = max(dot(N, V), 0.0);
    vec3 R = reflect(-V, N);
    vec3 Fe = F0 + (1.0 - F0) * pow(1.0 - nv, 5.0) * (1.0 - rough) * (1.0 - rough);
    col += skyBase(R) * Fe * uEnvSpec * (0.35 + 0.65 * vis) * (1.0 - rough * 0.7);
    col *= studMul;
  }
#ifdef TRANSPARENT
  alpha *= uOpacity;
  if (id > 5.5 && id < 6.5) { vec3 R = reflect(-V, N); float fr = 0.08 + 0.6 * pow(1.0 - max(dot(N, V), 0.0), 5.0); col = mix(col * 0.7, skyBase(R), fr * 0.6); alpha = clamp(alpha + fr, 0.0, 1.0); }
  if (id > 17.5) { col = albedo * 1.6; }
#endif
  // Atmosphere: distant parts fade into the horizon sky (Density), Haze adds a light veil, Offset keeps far silhouettes.
  if (uFogOn > 0.5) {
    vec3 vd = -V;
    vec3 fogCol = skyBase(normalize(vec3(vd.x, max(vd.y, 0.0) * 0.25, vd.z))) * mix(1.0, 0.86, uOffset);
    float f1 = 1.0 - exp(-dist * uFogK * uDensity);
    float f2 = 1.0 - exp(-dist * uHazeK * uHaze);
    float f = (1.0 - (1.0 - f1) * (1.0 - f2)) * (1.0 - 0.3 * uOffset);
    col = mix(col, fogCol, f);
  }
  gl_FragColor = vec4(col * uExposure, alpha);
}`;

export const DEPTH_VERT = /* glsl */`void main() { gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`;
export const DEPTH_FRAG = /* glsl */`void main() { gl_FragColor = vec4(1.0); }`;
export const FULL_VERT = /* glsl */`varying vec2 vUv; void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;
export const BRIGHT_FRAG = /* glsl */`
uniform sampler2D tHdr; uniform float uThreshold; varying vec2 vUv;
void main() {
  vec3 c = texture2D(tHdr, vUv).rgb;
  float l = max(c.r, max(c.g, c.b));
  float k = max(l - uThreshold, 0.0) / max(l, 1e-4);
  gl_FragColor = vec4(c * k, 1.0);
}`;
export const BLUR_FRAG = /* glsl */`
uniform sampler2D tSrc; uniform vec2 uDir; uniform float uSigma; varying vec2 vUv;
void main() {
  vec3 s = vec3(0.0); float w = 0.0;
  for (int i = -12; i <= 12; i++) { float x = float(i); float g = exp(-x * x / (2.0 * uSigma * uSigma)); s += texture2D(tSrc, vUv + uDir * x * max(1.0, uSigma / 4.0)).rgb * g; w += g; }
  gl_FragColor = vec4(s / w, 1.0);
}`;
// Bloom added in HDR, then the tone curve (linear mids, soft shoulder per channel, so bright colours whiten like Roblox's
// neon), then sRGB.
export const COMPOSITE_FRAG = /* glsl */`
uniform sampler2D tHdr, tBloomA, tBloomB; uniform float uBloom, uKnee, uAlphaOut, uTone; varying vec2 vUv;
vec3 tone(vec3 x) {
  if (uTone > 1.5) return clamp(x, 0.0, 1.0); // RQ="&out=linear" (LIGHT3): component passes, the ACES constants, no tone curve
  if (uTone > 0.5) return clamp(x * (2.51 * x + 0.03) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0); // ACES (LIGHT2)
  vec3 k = vec3(uKnee); vec3 o = max(x - k, 0.0); return min(x, k) + (1.0 - k) * (1.0 - exp(-o / (1.0 - k)));
}
vec3 toSRGB(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(1e-6)), vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
void main() {
  vec4 h = texture2D(tHdr, vUv);
  vec3 c = h.rgb;
  if (uBloom > 0.0) c += uBloom * (texture2D(tBloomA, vUv).rgb * 0.7 + texture2D(tBloomB, vUv).rgb * 0.8);
  c = toSRGB(tone(max(c, 0.0)));
  gl_FragColor = vec4(c, uAlphaOut > 0.5 ? h.a : 1.0);
}`;
// ColorCorrectionEffect in display space: Brightness adds, Contrast scales about mid grey, Saturation scales chroma, Tint multiplies.
export const GRADE_FRAG = /* glsl */`
uniform sampler2D tSrc; uniform float uB, uC, uS; uniform vec3 uTint; varying vec2 vUv;
void main() {
  vec4 t = texture2D(tSrc, vUv);
  vec3 c = t.rgb + uB;
  c = (c - 0.5) * (1.0 + uC) + 0.5;
  float l = dot(c, vec3(0.299, 0.587, 0.114));
  c = mix(vec3(l), c, 1.0 + uS) * uTint;
  gl_FragColor = vec4(clamp(c, 0.0, 1.0), t.a);
}`;
