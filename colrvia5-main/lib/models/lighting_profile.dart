// lib/models/lighting_profile.dart

/// Lighting profiles that influence color rendering.
/// Defaults to [LightingProfile.mixed].
///
enum LightingProfile {
  mixed,
  warm,
  cool,
}

/// User-facing labels for each profile.
const Map<LightingProfile, String> lightingProfileLabels = {
  LightingProfile.mixed: 'Mixed',
  LightingProfile.warm: 'Warm',
  LightingProfile.cool: 'Cool',
};

LightingProfile lightingProfileFromString(String? value) {
  switch (value) {
    case 'warm':
      return LightingProfile.warm;
    case 'cool':
      return LightingProfile.cool;
    case 'mixed':
    default:
      return LightingProfile.mixed;
  }
}

extension LightingProfileX on LightingProfile {
  String get label => lightingProfileLabels[this] ?? name;
}

