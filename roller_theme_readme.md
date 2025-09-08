# Roller Theme — Feature README

A concise guide to the **Theme** filter for the Roller screen: what it is, how it works, how to tune it, and where the code lives.

---

## TL;DR (Product + UX)
- **What users see:** one new **Theme** dropdown in the Roller top nav (next to Style / Brand / Count). It’s **single-select**: *All Themes (default), Modern Farmhouse, Coastal, Cottagecore, Quiet Luxury, Bohemian*, etc.
- **What it does:** filters the feed to palettes that match the selected interior design theme. No extra knobs (no strict/loose). Just pick a theme and scroll.
- **Behind the scenes:** we prefilter candidate paints by LCH windows, generate palettes as usual, then score and keep only on-theme results. If results get too sparse, we **quietly auto-relax** to keep the feed alive.

---

## Architecture Overview

```text
Roller Screen (UI)
  └─ Top Nav "Theme" (single-select)
      └─ Passes ThemeSpec -> Isolate args
          └─ Isolate pipeline
              1) Prefilter paints by ThemeSpec (LCH windows)
              2) rollPalette(...) using existing generator
              3) scorePalette(...) and gate by threshold
              4) Return best / threshold-cleared palette(s)
```

**Key pieces**
- **ThemeSpec** (data-only): JSON (or Firestore) rules that define each theme: allowed LCH windows for neutrals/accents, optional role lightness targets, forbidden hue bands, harmony bias, and scoring weights.
- **ThemeEngine** (pure functions): `prefilter`, `slotLrvHintsFor`, `scorePalette`, `explain`.
- **Isolate integration**: extends `_RollArgs` to optionally include `themeSpec`, `themeThreshold`, `attempts`. Prefilters paints, reuses `PaletteGenerator.rollPalette`, scores outputs.
- **UI**: a new **Theme** dropdown panel with chip-like choices; selecting a theme updates the button label and refreshes the feed.

---

## File Map & Touchpoints

**Existing code we reuse**
- `lib/screens/roller_screen.dart` – top nav UI, feed/roll triggers.
- `lib/utils/palette_generator.dart` – palette generation, undertone filter, harmony modes, diversify brands.
- `lib/utils/palette_isolate.dart` – compute() worker that generates palettes off the UI thread.
- `lib/firestore/firestore_data_schema.dart` – `Paint` model with `lab` and `lch`.
- `lib/utils/color_utils.dart` – LAB/LCH helpers, contrast ratio.

**New files added for Theme**
- `lib/roller_theme/theme_spec.dart` – data model, (de)serialization.
- `lib/roller_theme/theme_service.dart` – load/serve ThemeSpecs (from asset; optional remote override later).
- `lib/roller_theme/theme_engine.dart` – prefilter + hints + scoring + small explain string.

**Assets**
- `assets/themes/themes.json` – editable theme definitions (see schema below).
- `pubspec.yaml` – include `assets/themes/themes.json` in `flutter.assets`.

---

## ThemeSpec JSON Schema (v1)

```jsonc
{
  "id": "coastal",                  // required
  "label": "Coastal",               // required
  "aliases": ["seaside", "beachy"],

  // Allowed windows for individual paints in candidate pool
  "neutrals": { "L": [82,96], "C": [0,8], "H": [/* either [min,max] or [[min,max],[min,max]] */] },
  "accents":  { "L": [55,90], "C": [10,25], "H": [170,210] },

  // Optional role-level guidance; used to create slot LRV hints
  "roleTargets": {
    "anchor":    { "L": [82,95], "C": [0,8] },
    "secondary": { "L": [70,88], "C": [0,12] },
    "accent":    { "L": [60,85], "C": [10,24], "H": [170,210] }
  },

  // Hue regions we discourage outright
  "forbiddenHues": [[0,20], [300,360]],

  // Preference nudges; used in the scoring phase
  "harmonyBias": ["analogous", "neutral-plus-accent"],

  // Feature weights (0..1). Missing keys default to 0.
  "weights": {
    "neutralShare": 0.20,
    "saturationDiscipline": 0.20,
    "accentContrast": 0.10,
    "harmonyMatch": 0.20,
    "coolBias": 0.20,
    "forbiddenHuePenalty": 0.10
  }
}
```

**Notes**
- `H` can be a single band `[min,max]` or multiple `[[min,max],[min,max]]`. ThemeEngine handles wraparound (e.g., `[340,360]` + `[0,10]`).
- Ranges are **inclusive**; values outside are filtered out at the *prefilter* stage.
- `roleTargets` are soft hints (not hard constraints). If omitted, generation proceeds without slot LRV hints.

---

## How the Pipeline Works (Step-by-Step)

1) **User selects a theme** → Roller stores `themeId` and retrieves the `ThemeSpec` via `ThemeService`.
2) **Prefilter** paints: keep a paint if its `LCH` falls in **neutrals OR accents** windows.
3) **Slot hints** (optional): derive `slotLrvHints` from `roleTargets` (e.g., bright anchor for Coastal).
4) **Generate**: call the existing `PaletteGenerator.rollPalette(...)` with the (possibly) prefiltered paint list and optional hints.
5) **Score**: compute a 0..1 score using the spec’s `weights` (see **Scoring Metrics** below).
6) **Gate** by a fixed threshold (default `0.6`). Try multiple attempts (default `10`) to find a qualifying palette; otherwise return the best.
7) **Auto-relax (silent)**: if prefilter yields too few paints (e.g., < ~120 after brand filters), fall back to the broader set to avoid an empty feed.

---

## Scoring Metrics (v1)

Each metric returns 0..1; the final score is a weighted sum using `spec.weights`.

- **neutralShare** – ratio of colors with chroma ≤ `neutrals.C.max` (default fallback ≈ 12 when missing).
- **hueAllowed** – penalty applied per color inside `forbiddenHues` bands.
- **saturationDiscipline** – how well each color’s C fits the allowed envelope (role-aware if `roleTargets` present; otherwise uses neutrals/accents envelope).
- **harmonyMatch** – rewards if hue pattern matches theme’s bias (e.g., ‘analogous’ → hue span ≤ ~60°; ‘neutral-plus-accent’ → ≥1 neutral and ≥1 non-neutral).
- **accentContrast** – normalized `min(contrast/7.0, 1.0)` using WCAG contrast between darkest and lightest colors.
- **warmBias / coolBias** – share of hues in warm (~[330,360]∪[0,90]) vs cool (~[90,270]) bands, included only if the corresponding weight is present.
- **brandDiversity** – unique brand ratio (optional; respects existing “diversify brands” flow).

> The `explain(...)` helper composes a short reason string (✓ on-vibe traits, ✕ penalties). We keep it out of UI in v1 but it’s helpful for QA and logs.

---

## Adding a New Theme (Checklist)

1. **Edit** `assets/themes/themes.json` → append a new theme object.
2. **pubspec** already includes the asset; no changes needed after first setup.
3. **Run** the app; when Roller loads, it calls `ThemeService.loadFromAssetIfNeeded()` and picks up the new theme.
4. **QA pass** (see below). If results are sparse, widen L/C/H windows *slightly* first before changing weights.

**Starter ranges (rule of thumb)**
- **Neutrals:** `L ≈ 70–95`, `C ≈ 0–12`, `H` aligned to warm (30–90) for warm/neutrals, or omit `H` to allow all.
- **Accents:** `L ≈ 40–85`, `C ≈ 8–25`, `H` bands that express the theme (e.g., 170–210 for sea-glass).

---

## Tuning a Theme (Fast Playbook)

- **Brighter / airier** → raise neutral `L.max` (e.g., 90 → 95).
- **Moodier / cozier** → lower anchor `L` range via `roleTargets.anchor.L`.
- **More neutral** → lower `neutrals.C.max` and bump `weights.saturationDiscipline`.
- **Punchier accents** → raise `accents.C.max` and `weights.accentContrast`.
- **Shift warm/cool vibe** → adjust `H` bands (warm: ~20–70; sea-glass: ~170–210).
- **Kill an off-vibe hue** → add `[min,max]` to `forbiddenHues` and/or increase `weights.forbiddenHuePenalty`.

Make changes in **small steps** (±3–5 L units, ±2–4 C units, ±10–20° H range), roll again, and observe.

---

## QA Checklist (Manual)

- [ ] **UI**: Theme dropdown shows *All Themes* + all entries from JSON. Selecting a theme updates the button label and refreshes the feed.
- [ ] **Performance**: With a theme selected, first page appears in a similar timeframe (prefilter should help, not hurt).
- [ ] **Results make sense**: Randomly sample 10–15 palettes per theme; 80%+ should feel on-vibe.
- [ ] **Edge case**: Theme + strict brand filter still produces output (auto-relax kicks in silently when needed).
- [ ] **No crashes**: Try palette sizes 3–6 and different harmony modes; scoring handles them all.

---

## Troubleshooting

- **Empty or repetitive feed**
  - Check if prefilter is too tight: try temporarily widening `neutrals.C.max` or `accents.H` bands.
  - Verify brand filters aren’t starving the pool; try *All Brands*.
- **Off-vibe brights slipping in**
  - Lower `accents.C.max` and raise `weights.saturationDiscipline`.
  - Add or widen `forbiddenHues`.
- **Too monochrome for a lively theme**
  - Add a second accent `H` band; bump `weights.harmonyMatch` for ‘triad’/‘analogous’ as appropriate.
- **Coastal showing blacks**
  - Reduce `weights.accentContrast`, keep forbidden reds, ensure accents `L`/`C` are set for airy sea-glass.

---

## Defaults & Tunables (v1)

- **Threshold:** `0.6`
- **Attempts per roll:** `10`
- **Auto-relax trigger:** if post-brand prefilter < ~120 paints → fall back to broader pool.
- **UI Surface:** single-select only; no strict/loose control. (All strictness via JSON ranges/weights.)

---

## Example Theme Objects (condensed)

```json
{
  "id": "modern_farmhouse",
  "label": "Modern Farmhouse",
  "neutrals": { "L": [78,93], "C": [0,10], "H": [30,90] },
  "accents":  { "L": [8,35],  "C": [0,20], "H": [[0,10],[340,360]] },
  "forbiddenHues": [[190,220]],
  "harmonyBias": ["neutral-plus-accent","analogous"],
  "weights": { "neutralShare": 0.25, "warmBias": 0.15, "saturationDiscipline": 0.15, "accentContrast": 0.15, "brandDiversity": 0.05, "forbiddenHuePenalty": 0.15, "harmonyMatch": 0.10 }
}
```

```json
{
  "id": "coastal",
  "label": "Coastal",
  "neutrals": { "L": [82,96], "C": [0,8] },
  "accents":  { "L": [55,90], "C": [10,25], "H": [170,210] },
  "forbiddenHues": [[0,20],[300,360]],
  "harmonyBias": ["analogous","split-complement","neutral-plus-accent"],
  "weights": { "neutralShare": 0.2, "coolBias": 0.2, "accentContrast": 0.1, "saturationDiscipline": 0.2, "harmonyMatch": 0.2, "forbiddenHuePenalty": 0.1 }
}
```

---

## Implementation Notes

- **Isolate contract** (`lib/utils/palette_isolate.dart`)
  - Extend `_RollArgs` with `themeSpec: Map?`, `themeThreshold: double?` (default 0.6), `attempts: int?` (default 10).
  - When `themeSpec != null`:
    1. Rehydrate `ThemeSpec` from the map.
    2. Prefilter paints via `ThemeEngine.prefilter`.
    3. Loop up to `attempts`, track best by `ThemeEngine.scorePalette`.
    4. Early-exit when `score >= themeThreshold`.

- **UI integration** (`lib/screens/roller_screen.dart`)
  - Add `_NavMenu.theme` and a `_ThemePanelHost` that renders chips from `ThemeService.instance.all()`.
  - Store `String? _selectedThemeId` and `ThemeSpec? _selectedThemeSpec`.
  - On selection: set, close menu, **reset feed**, and pass `themeSpec.toJson()` + hints to the isolate args.

- **Services**
  - Call `ThemeService.instance.loadFromAssetIfNeeded()` during Roller init so the menu is ready.

---

## Future-Friendly (Optional)
- **Remote overrides** via Firestore for rapid iteration in dev/internal builds.
- **Theme Lab** dev screen for live tuning (disabled in production).
- **Analytics loop**: log palette saves/likes with `{ themeId, score, neutralShare, hueSpan, maxContrast }` to refine ranges.

---

## Changelog (fill as you iterate)
- **v1** – Single-select Theme filter, asset-backed specs, prefilter + score gating, silent auto-relax.

