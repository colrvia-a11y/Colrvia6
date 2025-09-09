# Roller – Architecture & Build Guide

This README documents the Roller feature and the surrounding app architecture so you can onboard fast, ship safely, and iterate confidently.

> **Scope:** Reflects the Phase 1–5 re‑architecture: controller/service pattern with Riverpod, isolate‑backed generation pipeline, Explore/Edit UX, favorites + export, analytics shim, tests, and benchmarking.

---
## Table of Contents
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Architecture Overview](#architecture-overview)
  - [Data Flow](#data-flow)
  - [Key Modules](#key-modules)
- [Roller Feature](#roller-feature)
  - [State Model](#state-model)
  - [Controller Responsibilities](#controller-responsibilities)
  - [Generation Pipeline](#generation-pipeline)
  - [Alternates Cache](#alternates-cache)
  - [Explore ↔ Edit UX](#explore-↔-edit-ux)
  - [Favorites & Export](#favorites--export)
  - [Analytics & Error Handling](#analytics--error-handling)
  - [Accessibility](#accessibility)
- [Development](#development)
  - [Run / Debug](#run--debug)
  - [Testing](#testing)
  - [Benchmarking](#benchmarking)
  - [Performance Budgets](#performance-budgets)
- [Extending Roller](#extending-roller)
  - [Add a New Theme](#add-a-new-theme)
  - [Add a Filter](#add-a-filter)
  - [Add a New Generation Strategy](#add-a-new-generation-strategy)
- [Conventions](#conventions)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)

---
## Quick Start

```bash
# 1) Install deps
flutter pub get

# 2) (If using favorites) ensure shared_preferences is present
flutter pub add shared_preferences

# 3) Run the app
flutter run

# 4) Run tests
flutter test

# 5) Optional: run generation benchmark
dart run tool/bench_generate.dart
```

**Minimums:** Flutter 3.x, Dart 3.x.

---
## Project Structure

```text
lib/
├─ features/
│  ├─ roller/
│  │  ├─ roller_state.dart               # RollerState, RollerPage, RollerFilters, RollerStatus
│  │  ├─ roller_controller.dart          # AsyncNotifier<T> with Riverpod; orchestrates UI ↔ pipeline
│  │  ├─ paint_repository.dart           # Loads/caches paints; brand/theme pools
│  │  ├─ palette_service.dart            # Facade calling top-level isolate entrypoints
│  │  ├─ roller_ui_mode.dart            # Explore/Edit mode provider
│  │  └─ widgets/
│  │      ├─ roller_feed.dart           # Vertical PageView feed; locks; filters; error view
│  │      ├─ roller_topbar.dart         # AppBar with Explore/Edit toggle, Help, Favorite, Copy
│  │      └─ editor_panel.dart          # Slide-up quick actions panel (Edit mode)
│  └─ favorites/
│     ├─ favorites_repository.dart      # Local persistence (shared_preferences)
│     └─ favorites_screen.dart          # (Optional) browse/delete favorites
│
├─ roller_theme/
│  ├─ theme_spec.dart                   # Theme specification model
│  └─ theme_engine.dart                 # Prefiltering, slot hints, scoring helpers
│
├─ utils/
│  └─ palette_isolate.dart              # Isolate entrypoints + pipeline helpers
│
├─ services/
│  └─ analytics_service.dart            # No-op logger (replace with Firebase/Segment later)
│
├─ screens/
│  └─ roller_screen.dart                # Thin wrapper: TopBar + Feed + Editor overlay
│
└─ widgets/
   └─ paint_column.dart                 # PaintStripe / swatch widget(s)

test/
├─ roller/
│  ├─ roller_controller_test.dart       # Controller unit tests with fakes/mocks
│  └─ palette_service_smoke_test.dart   # (Optional) isolate wiring smoke test
└─ favorites/
   └─ favorites_repository_test.dart    # Favorites round-trip

tool/
└─ bench_generate.dart                  # Simple local performance harness
```

---
## Tech Stack
- **Flutter** (Material 3)
- **Riverpod** for state management (`AsyncNotifier`, providers)
- **Dart isolates** for CPU‑bound palette generation (`compute()`)
- **shared_preferences** for local favorites
- **mocktail** + `flutter_test` for unit tests

---
## Architecture Overview

### Data Flow

```text
UI (Feed / TopBar / Editor)
   │    user gestures (tap, double‑tap, scroll, buttons)
   ▼
RollerController (AsyncNotifier<RollerState>)
   │ orchestrates state, prefetch, alternates, filters, favorites
   ▼
PaletteService (facade)
   │ marshals args to isolate
   ▼
Isolate entrypoints (rollPipelineInIsolate / alternatesForSlotInIsolate)
   │ call PaletteGenerator + ThemeEngine
   ▼
Results (List<Paint>) → Controller → RollerState → UI
```

**Providers for DI:**
- `paintRepositoryProvider : Provider<PaintRepository>`
- `paletteServiceProvider : Provider<PaletteService>`

These allow overriding in tests and future swaps (e.g., remote data).

### Key Modules
- **PaintRepository**: loads all paints once, caches brand pools and theme‑prefiltered pools.
- **PaletteService**: single surface to generate a full palette or per‑strip alternates.
- **Isolate (palette_isolate.dart)**: pure functions; top‑level entrypoints required by `compute()`.
- **ThemeEngine**: optional scoring, slot hints, and prefiltering by theme.
- **RollerController**: single source of truth for pages, locks, filters, theme, alternates prefetch, favorites, analytics.

---
## Roller Feature

### State Model
- **RollerState**
  - `pages : List<RollerPage>` – rolling history with retention window
  - `visiblePage : int` – current index in the feed
  - `filters : RollerFilters` – brand IDs, diversify toggle, optional undertones
  - `themeSpec : ThemeSpec?` – optional theme to guide generation
  - `status : RollerStatus` – `idle | loading | rolling | error`
  - `generatingPages : Set<int>` – protect re‑entrancy per page
  - `error : String?` – surfaced to UI by `_ErrorView`
- **RollerPage**: `strips : List<Paint>`, `locks : List<bool>`, `createdAt`.

### Controller Responsibilities
- Bootstraps first page on entry; **prefetches** one ahead
- **Reroll current** respecting locks
- **Single‑strip reroll** and **alternates** (double‑tap)
- Applies **filters** and optional **theme** via repository pool
- **Retains** up to N pages in memory (`_retainWindow`)
- **Favorites** (toggle + query) and **export** (copy hex in multiple formats)
- **Error handling** with retry; **analytics** instrumentation

### Generation Pipeline
- **Prefilter → Base roll → (Optional) Theme scoring**
- Top‑level isolate entrypoints:
  - `rollPipelineInIsolate(Map args)` – generates a full palette
  - `alternatesForSlotInIsolate(Map args)` – returns distinct options for one slot
- Pipeline picks between simple base roll vs. theme‑scored best‑of‑N, using `ThemeEngine` for hints and scoring.

**Sequence (simplified):**
```text
UI: Roll/Next → Controller → Repository.getPool(brandIds, theme) → PaletteService.generate()
     → compute(rollPipelineInIsolate) → List<Paint> → Controller updates page → UI rebuild
```

### Alternates Cache
- Controller primes a small **per‑strip alternates queue** for the visible page.
- Eviction: LRU cap to prevent unbounded memory (configurable).
- Double‑tap consumes the next alternate; fallback to reroll when queue is empty.

### Explore ↔ Edit UX
- **Explore** keeps browsing light (vertical feed).
- **Edit** slides up an **EditorPanel** with quick actions:
  - Roll, Next, Unlock all
  - Per‑strip: Lock/Unlock, Alternate, Reroll
- **TopBar**: Explore/Edit segmented toggle, Help dialog with gesture hints, Favorite, Copy HEX menu.

### Favorites & Export
- `FavoritesRepository` stores palettes locally (id list + HEX list + timestamp).
- Favorite status is reactive (provider) so the heart icon updates instantly.
- Export supports **comma**, **newline**, and **labeled** formats.

### Analytics & Error Handling
- `AnalyticsService` is a no‑op shim; events are logged with context:
  - `roll_next`, `reroll_current`, `reroll_strip`, `toggle_lock`, `alternate_applied`
  - Include timing (`elapsedMs`) and pool metrics for performance tracking.
- `_ErrorView` shows a friendly message with **Try Again**.

### Accessibility
- `Semantics` on strips (locked/unlocked, index), tooltips for gestures.
- Editor controls use Material 3 components with labels and hit targets.

---
## Development

### Run / Debug
- Ensure app is wrapped by `ProviderScope` in `main.dart`.
- Hot‑reload friendly: generation runs in an isolate; controller state is stable.

### Testing
```bash
# Unit tests
flutter test test/roller/roller_controller_test.dart

# Optional smoke test (isolate)
flutter test test/roller/palette_service_smoke_test.dart

# Favorites tests
flutter test test/favorites/favorites_repository_test.dart
```
**Tips**
- Use provider overrides for DI:
  - `paintRepositoryProvider.overrideWithValue(FakeRepo())`
  - `paletteServiceProvider.overrideWithValue(FakeSvc())`
- Mock with `mocktail`.

### Benchmarking
```bash
dart run tool/bench_generate.dart
```
Outputs per‑run timings and average. Track in PR descriptions to spot regressions.

### Performance Budgets
- **Generation (device):** target < **120ms** average for a full roll
- **First paint:** prefetch on entry; cache pools early
- **Memory:** retained pages ≤ 50; alternates cache capped (LRU)

---
## Extending Roller

### Add a New Theme
1. Define a `ThemeSpec` with weights/targets in `roller_theme/theme_spec.dart`.
2. Teach `ThemeEngine` to `prefilter` and `score` for the new spec.
3. UI: expose a theme picker, then call `controller.setTheme(spec)`.

### Add a Filter
1. Extend `RollerFilters` (e.g., undertones, brand families).
2. Update `PaintRepository.getPool()` to apply fast prefilters and cache by key.
3. Expose filter controls in `EditorPanel` or a dedicated sheet.

### Add a New Generation Strategy
- Add a new `modeIndex` branch in the isolate pipeline that calls into a strategy function.
- Keep the `PaletteService` API stable; only the isolate internals change.
- Add tests for the new strategy and benchmark.

---
## Conventions
- **State lives in controllers** (Riverpod). Widgets are thin, reactive views.
- **All generation goes through `PaletteService`** → isolate. No widget‑level generation.
- **Top‑level isolate functions** only (required by `compute`).
- **Small PRs** aligned to phases; each with smoke tests + benchmark numbers.
- **Naming**: prefer explicit (`rerollStrip`, `useNextAlternateForStrip`) over generic.

---
## Troubleshooting
- **UI doesn’t render first page**: ensure `initIfNeeded()` is called (Feed `initState`) and `ProviderScope` wraps the app.
- **Isolate errors**: verify entrypoints are top‑level and args are JSON‑serializable (no complex classes crossing isolate boundary).
- **Favorites not persisting**: check `shared_preferences` is installed and device storage is available.
- **Alternates feel slow**: confirm `_primeAlternatesForVisible()` runs after rolls; increase target count cautiously.
- **High GC or jank**: lower `_retainWindow`, cap alternates cache, and verify theme prefilter reduces pool size.

---
## Roadmap
- **Remote config / A/B** for strategies and thresholds.
- **Cloud sync** for favorites.
- **Better theme designer** (visual constraints & live scoring explainer).
- **Deeper analytics** (session funnels, scores distribution).
- **Snapshot export** (PNG of palette + metadata).

---
*Maintainers:* Keep this README updated when you add pipelines, strategies, or UI surfaces. If the isolate API changes, reflect it here and in the tests/benchmarks.*

