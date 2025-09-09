# Pop Accent Constraints Implementation Summary

## Overview
Successfully implemented "Pop Accent" constraints (≤1) + detection to enforce the blueprint's "0 or 1 pop accent" rule using chroma, with preference for muted accents when the palette is overall muted.

## Changes Made

### 1. ThemeSpec.VarietyControls (lib/roller_theme/theme_spec.dart)
Added three new optional fields:
- `double? popChromaMin` (default ~18) - Minimum chroma to consider a color a "pop"
- `int? maxPops` (default 1) - Maximum number of pop accents allowed
- `bool? mutedPalettePrefersMutedPop` (default true) - Whether muted palettes should prefer muted pops

### 2. ThemeEngine Validation (lib/roller_theme/theme_engine.dart)
Enhanced `validatePaletteRules()` with:
- `_countPops()` helper function to count colors with C >= popChromaMin
- `_isMutedPalette()` helper function to detect muted palettes
- Hard gate returning 'too_many_pops' when pops > maxPops

### 3. ThemeEngine Scoring (lib/roller_theme/theme_engine.dart)
Added `popDiscipline` metric in `scorePalette()`:
- Score of 1.0 if pops ≤ 1
- Linear penalty for additional pops: max(0, 1 - 0.5*(pops-1))
- Penalty for vivid pops (C > 24) in muted palettes when enabled
- Integrated into fallback average (updated divisor from 12 to 13)

### 4. PaletteGenerator Enhancement (lib/utils/palette_generator.dart)
Modified `localScore()` function to prefer muted accents when a pop already exists:
- Enhanced function signature to accept current result state
- Added pop bonus logic: 1.2x bonus for muted colors (C ≈ 14-18), 0.8x penalty for high chroma (C > 24)
- Updated call site to pass current palette state

## Acceptance Criteria Met

✅ **Theme path**: With `max_pops: 1`, any palette with 2+ colors C ≥ popChromaMin gets score 0 (hard gate) or low score if only soft-weighted.

✅ **Colrvia path (no theme)**: When both Primary & Secondary are high-C, the second tends to be chosen near C ≈ 14–18 (muted), not 25+.

## Example Usage

```dart
final themeSpec = ThemeSpec(
  id: 'muted-theme',
  label: 'Muted Theme',
  varietyControls: const VarietyControls(
    minColors: 3,
    maxColors: 5,
    mustIncludeNeutral: false,
    mustIncludeAccent: false,
    popChromaMin: 18.0,        // Colors with C >= 18 are "pops"
    maxPops: 1,                // Allow maximum 1 pop accent
    mutedPalettePrefersMutedPop: true,  // Prefer muted pops in muted palettes
  ),
);
```

## Implementation Notes
- All changes are backward-compatible (new fields are optional)
- Pop detection uses chroma threshold (default 18.0)
- Muted palette detection uses median chroma < 14.0 of non-pop colors
- Scoring penalties can be weighted via `weights['popDiscipline']` (default off)
- PaletteGenerator prefers muted accents automatically when a pop exists

The implementation successfully enforces the "0 or 1 pop accent" rule while providing flexibility for different palette aesthetics and maintaining backward compatibility with existing theme configurations.
