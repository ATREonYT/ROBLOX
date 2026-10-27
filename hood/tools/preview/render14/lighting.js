// Lighting presets (copied from hood/src/ServerStorage/HoodLighting.lua as of 2026-10-10 (LIGHT3), Color3s as 0-255 arrays;
// re-copy when HALL changes a preset) and Roblox's sun formula.
import * as THREE from 'three';

const P = (lighting, atmosphere, grade, bloom, clouds, sky) => ({ ...lighting, atmosphere, grade, bloom, clouds, sky });
export const LIGHTING_PRESETS = {
  FrontPage: P(
    { LightingStyle: 'Soft', ClockTime: 13, GeographicLatitude: 30, Brightness: 3, ExposureCompensation: 0.2,
      Ambient: [128, 130, 158], OutdoorAmbient: [162, 168, 200], ColorShift_Top: [255, 238, 210], ColorShift_Bottom: [130, 160, 225],
      EnvironmentDiffuseScale: 0.5, EnvironmentSpecularScale: 0.15, ShadowSoftness: 0.2, GlobalShadows: true },
    { Density: 0.22, Offset: 0.6, Haze: 0.2, Glare: 0, Color: [196, 228, 255], Decay: [140, 180, 255] },
    { Brightness: 0.04, Contrast: 0.1, Saturation: 0.08, TintColor: [255, 255, 255] },
    { Intensity: 0.65, Size: 28, Threshold: 1.1 },
    { Cover: 0.55, Density: 0.25, Color: [255, 255, 255] },
    { SunAngularSize: 16 }),
  HoodSoft: P(
    { LightingStyle: 'Soft', ClockTime: 13, GeographicLatitude: 30, Brightness: 2.8, ExposureCompensation: 0.15,
      Ambient: [140, 142, 150], OutdoorAmbient: [164, 168, 182], ColorShift_Top: [255, 240, 220], ColorShift_Bottom: [146, 156, 186],
      EnvironmentDiffuseScale: 0.45, EnvironmentSpecularScale: 0.12, ShadowSoftness: 0.25, GlobalShadows: true },
    { Density: 0.2, Offset: 0.55, Haze: 0.15, Glare: 0, Color: [210, 226, 242], Decay: [160, 180, 218] },
    { Brightness: 0.03, Contrast: 0.08, Saturation: -0.04, TintColor: [255, 255, 255] },
    { Intensity: 0.45, Size: 26, Threshold: 1.15 },
    { Cover: 0.55, Density: 0.25, Color: [255, 255, 255] },
    { SunAngularSize: 16 }),
  // HoodSun as HoodLighting.lua has it since LIGHT3 (BRIEF23): simulator daylight. A high sun (65 degrees) from behind a
  // player walking north, a bright neutral ambient (~70% of the light: shade only ~10% darker), EnvironmentDiffuse 0.2,
  // ExposureCompensation 0, a mild grade, a light blue-white Atmosphere, Bloom on Neon. Voxel lighting (HoodLighting asks
  // for it through Technology, LightingStyle Soft and PrioritizeLightingQuality false).
  HoodSun: P(
    { LightingStyle: 'Soft', ClockTime: 12.4, GeographicLatitude: 48.5, Brightness: 0.5, ExposureCompensation: 0,
      Ambient: [172, 172, 180], OutdoorAmbient: [172, 172, 180], ColorShift_Top: [255, 240, 220], ColorShift_Bottom: [150, 165, 200],
      EnvironmentDiffuseScale: 0.2, EnvironmentSpecularScale: 0.1, ShadowSoftness: 0.5, GlobalShadows: true },
    { Density: 0.18, Offset: 0.25, Haze: 0.1, Glare: 0, Color: [215, 230, 250], Decay: [190, 210, 240] },
    { Brightness: 0, Contrast: 0.1, Saturation: 0.65, TintColor: [255, 255, 255] },
    { Intensity: 0.5, Size: 24, Threshold: 1.1 },
    { Cover: 0.5, Density: 0.35, Color: [255, 255, 255] },
    { SunAngularSize: 14 }),
  // HoodToy (B31 LOOK): ShadowMap sun (copied from HoodLighting.lua; technology drives index.html's shadow softness).
  HoodToy: P(
    { technology: 'ShadowMap', LightingStyle: 'Soft', ClockTime: 13, GeographicLatitude: 23, Brightness: 1.6, ExposureCompensation: 0.1,
      Ambient: [140, 140, 152], OutdoorAmbient: [196, 200, 214], ColorShift_Top: [255, 238, 214], ColorShift_Bottom: [150, 165, 200],
      EnvironmentDiffuseScale: 0.7, EnvironmentSpecularScale: 0.25, ShadowSoftness: 0.25, GlobalShadows: true },
    { Density: 0.08, Offset: 0.5, Haze: 0, Glare: 0, Color: [160, 205, 255], Decay: [80, 160, 245] },
    { Brightness: 0, Contrast: 0.15, Saturation: 0.5, TintColor: [255, 255, 255] },
    { Intensity: 0.4, Size: 24, Threshold: 1.6 },
    { Cover: 0.3, Density: 0.7, Color: [255, 255, 255] },
    { SunAngularSize: 14 }),
  // HoodSun20: LIGHT2's HoodSun (BRIEF20-22), what the user's Studio showed on 2026-10-10 (brief/ref23/ours_studio_spawn.png): the same sun direction and ColorShift_Top, a little more sun
  // (0.36), a high neutral-warm ambient so shade stays light, little blue sky fill, +0.3 exposure, saturation +0.45 and a
  // touch of contrast (Roblox's ACES tone curve: index.html K), a thin Atmosphere with no haze, bloom on Neon only.
  HoodSun20: P(
    { LightingStyle: 'Soft', ClockTime: 9.85, GeographicLatitude: 43, Brightness: 0.36, ExposureCompensation: 0.3,
      Ambient: [178, 176, 172], OutdoorAmbient: [178, 176, 172], ColorShift_Top: [255, 236, 210], ColorShift_Bottom: [120, 130, 160],
      EnvironmentDiffuseScale: 0.1, EnvironmentSpecularScale: 0.15, ShadowSoftness: 0.3, GlobalShadows: true },
    { Density: 0.1, Offset: 0.5, Haze: 0, Glare: 0, Color: [205, 222, 240], Decay: [140, 165, 210] },
    { Brightness: 0, Contrast: 0.14, Saturation: 0.45, TintColor: [255, 255, 255] },
    { Intensity: 0.5, Size: 24, Threshold: 1.3 },
    { Cover: 0.6, Density: 0.6, Color: [255, 255, 255] },
    { SunAngularSize: 16 }),
  // The HoodSun of light17 (BRIEF17-19; the user's Studio frames brief/ref20/user_30..32 show it: "still too dark").
  HoodSun17: P(
    { LightingStyle: 'Soft', ClockTime: 9.85, GeographicLatitude: 43, Brightness: 0.32, ExposureCompensation: 0,
      Ambient: [140, 143, 155], OutdoorAmbient: [146, 151, 170], ColorShift_Top: [255, 236, 210], ColorShift_Bottom: [120, 130, 160],
      EnvironmentDiffuseScale: 0.2, EnvironmentSpecularScale: 0.15, ShadowSoftness: 0.3, GlobalShadows: true },
    { Density: 0.12, Offset: 0.5, Haze: 0, Glare: 0, Color: [205, 222, 240], Decay: [140, 165, 210] },
    { Brightness: 0, Contrast: 0.1, Saturation: 0.08, TintColor: [255, 255, 255] },
    { Intensity: 0.6, Size: 24, Threshold: 1.25 },
    { Cover: 0.6, Density: 0.6, Color: [255, 255, 255] },
    { SunAngularSize: 16 }),
  // The HoodSun of BRIEF13-16 (the user's Studio frame user_24 shows it: far too bright).
  HoodSun16: P(
    { LightingStyle: 'Soft', ClockTime: 9.85, GeographicLatitude: 43, Brightness: 2.0, ExposureCompensation: 0,
      Ambient: [90, 93, 104], OutdoorAmbient: [100, 105, 122], ColorShift_Top: [255, 236, 210], ColorShift_Bottom: [120, 130, 160],
      EnvironmentDiffuseScale: 0.4, EnvironmentSpecularScale: 0.15, ShadowSoftness: 0.3, GlobalShadows: true },
    { Density: 0.2, Offset: 0.5, Haze: 0.1, Glare: 0, Color: [210, 226, 242], Decay: [150, 170, 210] },
    { Brightness: 0.02, Contrast: 0.1, Saturation: 0.05, TintColor: [255, 255, 255] },
    { Intensity: 0.5, Size: 24, Threshold: 1.2 },
    { Cover: 0.6, Density: 0.6, Color: [255, 255, 255] },
    { SunAngularSize: 16 }),
  HoodCalm: P(
    { LightingStyle: 'Soft', ClockTime: 14.5, GeographicLatitude: 30, Brightness: 2.4, ExposureCompensation: 0.15,
      Ambient: [150, 142, 132], OutdoorAmbient: [160, 154, 146], ColorShift_Top: [255, 235, 210], ColorShift_Bottom: [110, 104, 98],
      EnvironmentDiffuseScale: 0.35, EnvironmentSpecularScale: 0.1, ShadowSoftness: 0.35, GlobalShadows: true },
    { Density: 0.22, Offset: 0.3, Haze: 0.3, Glare: 0, Color: [226, 216, 200], Decay: [170, 160, 148] },
    { Brightness: 0.02, Contrast: 0.06, Saturation: -0.1, TintColor: [255, 248, 238] },
    { Intensity: 0.3, Size: 24, Threshold: 1.25 },
    { Cover: 0.5, Density: 0.22, Color: [255, 252, 246] },
    { SunAngularSize: 14 }),
  GoldenBlock: P(
    { LightingStyle: 'Soft', ClockTime: 16.3, GeographicLatitude: 30, Brightness: 2.8, ExposureCompensation: 0.3,
      Ambient: [130, 112, 160], OutdoorAmbient: [176, 150, 196], ColorShift_Top: [255, 200, 150], ColorShift_Bottom: [140, 130, 220],
      EnvironmentDiffuseScale: 0.5, EnvironmentSpecularScale: 0.2, ShadowSoftness: 0.2, GlobalShadows: true },
    { Density: 0.26, Offset: 0.45, Haze: 0.9, Glare: 0.35, Color: [255, 196, 170], Decay: [150, 120, 220] },
    { Brightness: 0.05, Contrast: 0.12, Saturation: 0.3, TintColor: [255, 250, 245] },
    { Intensity: 0.9, Size: 32, Threshold: 1 },
    { Cover: 0.5, Density: 0.3, Color: [255, 214, 200] },
    { SunAngularSize: 16 }),
  // A new Baseplate's Lighting (Studio 2023+), for comparisons with plain Roblox.
  StudioDefault: P(
    { LightingStyle: 'Soft', ClockTime: 14.5, GeographicLatitude: 0, Brightness: 2, ExposureCompensation: 0,
      Ambient: [70, 70, 70], OutdoorAmbient: [70, 70, 70], ColorShift_Top: [0, 0, 0], ColorShift_Bottom: [0, 0, 0],
      EnvironmentDiffuseScale: 1, EnvironmentSpecularScale: 1, ShadowSoftness: 0.2, GlobalShadows: true, autoFlip: false },
    { Density: 0.3, Offset: 0.25, Haze: 0, Glare: 0, Color: [199, 199, 199], Decay: [106, 112, 125] },
    null,
    { Intensity: 1, Size: 24, Threshold: 2 },
    null,
    { SunAngularSize: 21 }),
};
LIGHTING_PRESETS.Day = LIGHTING_PRESETS.FrontPage;
LIGHTING_PRESETS.BlockParty = LIGHTING_PRESETS.GoldenBlock;

// Lighting:GetSunDirection() as Roblox computes it (Nevermore SunPositionUtils.getSunPositionData, which reproduces the
// engine: GetSunDirection at ClockTime 12, latitude 41.733 is (0, 0.9498, 0.3129)). The sun rises at +X, sets at -X, and
// at noon leans toward +Z by (latitude - 23.5) degrees (a fixed summer-solstice tilt).
export function robloxSunDirection(clockTime, latitude) {
  const DAY = 86400, YEAR = 365.2564 * DAY, HALFYEAR = 182.6282, TILT = 23.5 * Math.PI / 180;
  const seconds = clockTime * 3600;
  const mod = seconds - Math.floor(seconds / DAY) * DAY;
  const a = 2 * Math.PI * mod / DAY;
  const sun = new THREE.Vector3(Math.sin(a), -Math.cos(a), 0);
  const dayOfYear = (seconds - seconds * Math.floor(seconds / YEAR)) / DAY;
  const offset = -TILT * Math.cos(Math.PI * (dayOfYear - HALFYEAR) / HALFYEAR) - latitude * Math.PI / 180;
  const axis = new THREE.Vector3(0, 0, 1).cross(sun).normalize();
  return sun.applyAxisAngle(axis, offset).normalize();
}
