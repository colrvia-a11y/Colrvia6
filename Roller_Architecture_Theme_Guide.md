Roller Theme — v2 Spec & Implementation Guide

A definitive guide to the Theme feature in the Roller screen—what it is, how it behaves in the new Roller design, how it’s scored, and exactly where it lives in code.

Scope: This document reflects the new Roller architecture (Riverpod controller + isolate pipeline) with Theme-based sorting/filtering integrated end-to-end.

TL;DR

What users see

A single-select Theme control in the Roller top bar (default: All Themes).

Optional: mirrored Theme chips in the Edit panel’s Filters sheet.

Changing the Theme immediately refreshes the feed with palettes on-vibe for that theme.

What it does

Prefilters the paint pool by the theme’s LCH windows (neutrals & accents).

Rolls palettes using the existing generator.

Scores each candidate with ThemeEngine.scorePalette(...).

Returns the best palette per roll; if the score is below threshold, we still return the best but log a low-score analytics event.

If the theme-filtered pool is too small, we auto-relax (fall back to a wider pool) to keep the feed alive.

Where it is (code pointers)

assets/themes/themes.json – Data for all themes.

lib/roller_theme/theme_spec.dart – Data model (Range types, ThemeSpec).

lib/roller_theme/theme_engine.dart – Prefilter, scoring, slot hints, explain.

lib/roller_theme/theme_service.dart – Load + expose themes, labels.

lib/features/roller/paint_repository.dart – Brand + theme pool caching.

lib/features/roller/palette_service.dart – Marshals args for the isolate.

lib/utils/palette_isolate.dart – Theme-aware rolling + scoring loop.

lib/features/roller/roller_controller.dart – Exposes setTheme(...), passes spec into generation.

lib/features/roller/widgets/roller_topbar.dart – UI surface for Theme (TopBar).

test/theme_engine_test.dart – Unit tests for the engine.

Product & UX Behavior
Surfaces

Top Bar: Theme

Label shows: Theme: All (default), or Theme: <Label>.

Tap opens a list: All Themes + every label from ThemeService.instance.themeLabels().

Edit panel (optional polish)

In the Filters sheet, a first row of single-select Theme chips mirrors the same choices.

Selection model

Single-select. There is always exactly one Theme active: All (null spec) or a single concrete theme.

Changing the Theme clears alternates and refreshes the feed immediately.

No “strict/loose” UI; strictness is handled internally via scoring and auto-relax.

Empty / failure states

If the theme asset fails to load, the Theme control gracefully degrades to All Themes (null spec); the feed continues without theming.

Data Model (ThemeSpec)
File format

assets/themes/themes.json

{
  "themes": [
    {
      "id": "modern",
      "label": "Modern",
      "aliases": ["contemporary", "modern minimal"],
      "neutrals": { "L": [10, 95], "C": [0, 10] },
      "accents":  { "L": [20, 70], "C": [6, 18], "H": [[0,20],[40,60],[180,240]] },
      "roleTargets": {
        "anchor":    { "L": [72, 92], "C": [0, 8] },
        "secondary": { "L": [65, 85], "C": [0, 10] },
        "accent":    { "L": [30, 60], "C": [8, 16] }
      },
      "forbiddenHues": [[270, 330]],
      "harmonyBias": ["neutral-plus-accent","monochrome"],
      "allowedHueRanges": [[0,20],[40,60],[180,240]],
      "variety_controls": {
        "min_colors": 3, "max_colors": 5,
        "must_include_neutral": true, "must_include_accent": true
      },
      "weights": {
        "neutralShare": 0.35,
        "saturationDiscipline": 0.20,
        "accentContrast": 0.15,
        "harmonyMatch": 0.20,
        "forbiddenHuePenalty": 0.10,
        "accentHueFit": 0.15,
        "varietyFitness": 0.10
      }
    }
  ]
}

Types (Dart)

Range1 { double min, max }

RangeH { List<List<double>> bands } (hue bands, supports wrap-around)

Range3 { Range1? L, C; RangeH? H }

RoleTarget { Range1? L, C } (per role: anchor, secondary, accent)

ThemeSpec fields:

id, label, aliases

neutrals: Range3?, accents: Range3?

roleTargets: { anchor?, secondary?, accent? }

forbiddenHues: List<List<double>>

harmonyBias: List<String> (e.g., analogous, neutral-plus-accent, triad, complementary)

allowedHueRanges: List<List<double>> (bands for accent hue fitness)

varietyControls (min/max colors, must include neutral/accent)

weights: Map<String,double> (see Scoring)

Architecture & Data Flow
UI (TopBar / Edit chips)
  ↓ (select Theme)
RollerController.setTheme(...)
  ↓ (update state.themeSpec, refresh feed)
PaintRepository.getPool(brandIds, themeSpec?)
  ↓ (brand cache, then optional theme cache via ThemeEngine.prefilter)
PaletteService.generate(...)
  ↓ compute(...)
Isolate.rollPipelineInIsolate(...)
  ├─ if no themeSpec → _pipeRollBase(...)
  └─ else → _pipeMaybeScoreTheme(...)
        1) Prefilter by LCH windows (neutrals/accents)
        2) Pick pool (auto-relax if too small)
        3) rollPalette(...) → candidate
        4) scorePalette(...) → score
        5) keep best over N attempts, return

Key files

Theme loading: lib/roller_theme/theme_service.dart

loadFromAssetIfNeeded() reads JSON once; themeLabels() exposes UI entries (All Themes + labels).

State: lib/features/roller/roller_state.dart

RollerState.themeSpec (nullable). Default = null = All Themes.

Controller: lib/features/roller/roller_controller.dart

setTheme(ThemeSpec? spec) updates state and re-rolls.

Generation methods always pass themeSpec into the pipeline.

Repository: lib/features/roller/paint_repository.dart

Caches by brand and theme: key theme.id|brandKey; prefers ThemeEngine.prefilter(...) when theme is present.

Isolate: lib/utils/palette_isolate.dart

_pipeRollBase(...) (no theme).

_pipeMaybeScoreTheme(...) (theme aware), with prefilter + attempts + scoring + threshold.

Engine: lib/roller_theme/theme_engine.dart

prefilter, slotLrvHintsFor, scorePalette, explain.

Generation & Scoring (How a “Theme-fit” palette is chosen)
Prefilter

ThemeEngine.prefilter(paints, spec) keeps paints that fall inside either the neutral or accent LCH windows defined by the theme. This shrinks search space and nudges the generator toward on-vibe results.

Auto-relax (feed resilience)

Compute pre = prefilter(available).

If pre is too small, we fall back to the wider pool to avoid starving the feed.

Typical heuristic: use pre if it’s “large enough”, otherwise use the unfiltered available.

Tunable constants (see below) control what “large enough” means in your build.

Rolling loop (per page / per reroll)

For each roll, the isolate:

Picks the working pool (prefiltered or relaxed).

Calls rollPalette(...) to propose a candidate palette (honors anchors & mode).

Calls scorePalette(candidate, spec); larger is better.

Keeps the best over attempts iterations.

Returns the best palette (even if below threshold); logs a low-score analytics event if needed.

Slot LRV hints

ThemeEngine.slotLrvHintsFor(size, spec) derives optional [min,max] L ranges for slots, based on roleTargets (anchor/secondary/accent). Passed into the generator to encourage the right tonal structure without hard-locking.

Scoring features (selected highlights)

neutralShare – proportion of neutrals (C ≤ neutral max).

saturationDiscipline – penalizes oversaturated candidates vs allowed C.

harmonyMatch – matches analogous, neutral-plus-accent, etc.

accentContrast – contrast ratio proxy between the darkest & lightest items.

forbiddenHuePenalty – penalizes accents falling in forbidden bands.

accentHueFit – how many accent hues land in allowedHueRanges.

brandDiversity / varietyFitness – encourage varied yet coherent palettes.

Optional warmBias / coolBias knobs.

Weights are per-theme in JSON (weights{...}).

Tunables (and where to change them)

These defaults are sensible and can be revised per product testing.

Theme threshold: minimum “good enough” score for the roll loop to consider “passing”.

Passed from PaletteService.generate(themeThreshold: ...) to the isolate.

Default if omitted (in isolate): 0.68.

Attempts: how many candidate palettes to try per roll.

PaletteService.generate(..., attempts: N) → isolate.

Typical range: 5–10 (trade-off: quality vs. latency). Service default is 6.

Auto-relax cutover: when to abandon the prefiltered pool because it’s too small.

Implemented in the isolate by comparing pre.length vs a cutover threshold.

Current heuristic uses the unfiltered pool when the prefiltered size is small (e.g., < ~200). You can lower this (e.g., 120) if you want stronger theme bias at the cost of more “feed empty” risks.

Theme cache key: PaintRepository caches by theme.id|brandKey. If you add strictness levels later, fold them into the key.

Analytics

roll_next (controller) – when a new page is rolled.

Payload: { pageCount, visible, elapsedMs, poolSize, brandCount, themeId, lockedCount }

reroll_current (controller) – re-roll current page.

Payload: { pageIndex, elapsedMs, poolSize, brandCount, themeId, lockedCount }

reroll_strip (controller) – alternate a specific strip.

Payload: { strip, elapsedMs, poolSize, brandCount, themeId, lockedCount }

theme_roll_low_score (isolate) – best candidate score fell below threshold.

Payload: { themeId, score, explain }

theme_selected (recommended) – fire when the user picks a theme.

Payload: { themeId }

Add in controller alongside setTheme(...).

Use these to assess theme quality, pool health, and user engagement.

UI Implementation Notes
TopBar control

Where: lib/features/roller/widgets/roller_topbar.dart

Model: Read the chosen ThemeSpec? from rollerControllerProvider state.

Behavior

Label: “Theme: All” when null; “Theme: {label}” when not null.

Menu items: ThemeService.instance.themeLabels(); first = { id: all, label: All Themes }.

On selection: resolve spec (null for “all”), then call controller.

Controller

Where: lib/features/roller/roller_controller.dart

API: Future<void> setTheme(ThemeSpec? spec)

Updates state.themeSpec and re-rolls.

Clears any alternates cache when theme changes.

Emits theme_selected (recommended).

Note: Generation methods already pass themeSpec and include the theme in analytics payloads.

Adding or Editing Themes

Edit JSON: assets/themes/themes.json

Add a new object under "themes".

Provide: id, label, neutrals, accents, roleTargets, forbiddenHues, harmonyBias, allowedHueRanges, variety_controls, weights.

Register asset: ensure pubspec.yaml includes assets/themes/themes.json.

Reload: ThemeService.loadFromAssetIfNeeded() runs once; hot-restart picks up changes.

QA: Sample rolls under the new Theme; validate vibe; adjust bands/weights.

Authoring tips

Keep neutrals.C.max realistic for the style (e.g., ≤ 12 for true neutrals).

Use allowedHueRanges to define which accent hue families are in-vibe.

Use forbiddenHues to quickly push out unwanted families for that style.

Start with broader windows; tighten after qualitative testing.

Testing & QA

Unit tests: test/theme_engine_test.dart

Extend with cases that validate:

prefilter admits only on-window paints.

scorePalette prefers expected structures (e.g., neutral-plus-accent).

accentHueFit and forbiddenHuePenalty behave as expected.

Controller tests (add): test/roller/roller_controller_test.dart

Fake a small paint set; set a theme; roll; assert results are on-vibe.

Verify auto-relax keeps rolls alive on tiny pools.

Manual QA checklist

Theme control shows All Themes + labels from JSON.

Switching Theme updates the label and immediately refreshes the feed.

With tight brand filters + Theme, the feed still rolls (auto-relax).

80%+ of sampled palettes per theme feel on-vibe.

Performance: no noticeable latency regressions vs. All Themes.

Run: flutter test and flutter run for smoke checks.

Troubleshooting

Theme list is empty

Check pubspec.yaml asset path.

Ensure ThemeService.loadFromAssetIfNeeded() is called (e.g., when the Roller screen appears).

“Too neutral / too saturated” complaints

Adjust neutrals.C.max and accents.C bands; tune saturationDiscipline weight.

Accents feel off-style

Refine allowedHueRanges and forbiddenHues; increase accentHueFit weight.

Feed starves under Theme + Brand

Raise the auto-relax threshold (i.e., relax earlier), or broaden theme bands slightly.

Extensibility Roadmap (nice-to-have)

Strict mode (UI toggle): require score ≥ threshold; re-roll until pass or max attempts.

Multi-theme blend: combine two ThemeSpecs (intersection of windows + weighted scores).

Per-theme slot roles: expose role targets to UI for slot labeling (Anchor / Accent).

Remote themes: move JSON to Firestore with a local cache.

Quick Dev Runbook

flutter pub get

flutter run (open Roller)

Select a Theme → validate UX & analytics

flutter test (theme engine + controller tests)

Tune themes.json as needed

Appendix: Key Methods & Signatures

ThemeService

Future<void> loadFromAssetIfNeeded()

List<Map<String,String>> themeLabels() // [{id:'all',label:'All Themes'}, ...]

ThemeSpec? byId(String id)

PaletteService

Future<List<Paint>> generate({ ..., ThemeSpec? themeSpec, double? themeThreshold, int attempts = 6 })

Isolate

List<Map<String,dynamic>> rollPipelineInIsolate(Map<String,dynamic> args)

_pipeMaybeScoreTheme({ ..., ThemeSpec spec, double threshold = 0.68, int attempts = 5 })

Engine

List<Paint> prefilter(List<Paint> paints, ThemeSpec spec)

double scorePalette(List<Paint> palette, ThemeSpec spec)

List<List<double>>? slotLrvHintsFor(int size, ThemeSpec spec)

Map<String,dynamic> explain(List<Paint> palette, ThemeSpec spec)

