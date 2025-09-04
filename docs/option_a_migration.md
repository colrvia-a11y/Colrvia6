# Option A Migration Notes

This branch migrates the app toward the four tab "Create‑First" IA.

* Added **Create**, **Projects**, **Search**, **Account** tabs with adaptive landing.
* Renamed Story screens to Color Plan terminology.
* Introduced `ColorPlanService` as a façade over existing story engines.
* Created placeholder `CreateScreen` and `ProjectOverviewScreen`.

## Assumptions

* Only a subset of legacy "Story" references were renamed; deeper model
  refactors are deferred.
* `ColorPlanService.generate` currently returns stub data pending backend
  alignment.
