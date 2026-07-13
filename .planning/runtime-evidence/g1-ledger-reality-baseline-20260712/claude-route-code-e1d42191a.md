## MINT External Audit — `code` mode

**Scope:** removal of the coach-routing "prefill" facade (`673e67dfe..e1d42191a`, 276+/628−, well under budget).

### What the diff does
Deletes the `prefill`/`prefillFromProfile` machinery from `RouteDecision`, `ScreenEntry`, `RoutePlanner`, and `RouteSuggestionCard`, and rewrites `WidgetRenderer._buildRouteSuggestion` so the LLM supplies only `intent` + `confidence` + `context_message`; Flutter resolves the canonical route and readiness through `RoutePlanner`/`MintScreenRegistry` and navigates with no `GoRouter.extra` payload.

### Verification performed
- **Wiring is real, not a facade.** Backend `route_to_screen` schema (`coach_tools.py:319-352`) emits exactly `{intent, confidence, context_message}` with `additionalProperties: False`, matching the new Flutter consumer (`widget_renderer.dart:96-132`). No orphan contract.
- **Fail-closed paths confirmed by tests.** `flutter test` on the four affected suites → **74/74 pass**: invalid/NaN/out-of-range/missing confidence, absent profile, missing provider, unknown intent, and legacy `route`/`prefill` payloads all render no CTA.
- **Nullable provider read is correct.** `context.read<CoachProfileProvider?>()` (`widget_renderer.dart:108`) resolves the non-nullable `ChangeNotifierProvider<CoachProfileProvider>` registration (provider scope is `_InheritedProviderScope<T?>`) and returns `null` instead of throwing when absent — matching the "missing provider fails closed without throwing" test.
- **Privacy improved.** No domain data crosses `context.push(route)`; enforced by the new `no_domain_data_in_extra_test.dart` gate ("coach routing exposes no financial prefill facade").
- **Clean removal.** No dangling references to the removed API (`route_planner`/`screen_registry`/`route_suggestion_card`); remaining `prefill` hits are unrelated subsystems (sequence coordinator, per-screen badges, l10n). `flutter analyze` on the four files → **No issues found**.
- **No regression on route resolution.** The deleted `ChatToolDispatcher.resolveRouteFromIntent` already used the same `MintScreenRegistry.findByIntent`, and the backend already stopped emitting `route`, so behavior for valid intents is unchanged; ignoring `route`/`prefill` is a security hardening (LLM can no longer inject arbitrary routes).

### Findings

**P0 — none.**

**P1 — none.**

**P2 (non-blocking, pre-existing — not introduced by this diff)**
- **Backend↔Flutter intent-tag drift.** 7 tags in `ROUTE_TO_SCREEN_INTENT_TAGS` (`coach_tools.py:108`) have no `MintScreenRegistry` entry: `compound_interest` (vs `compound_interest_simulator`), `debt_check` (vs `debt_risk_check`), `life_event_unemployment` (vs `life_event_job_loss`), `patrimoine_overview` (vs `portfolio_overview`), `pillar_3a_overview` (vs `simulator_3a`), `leasing_simulation` (vs `leasing_simulator`), `expert_consultation` (vs `consult_specialist`). If the LLM emits one, `route_to_screen` silently renders nothing. This fails *safe* (coach handles inline) and pre-dates this change (the old path used the identical registry lookup), so it is not a regression. Recommend a cross-boundary test asserting `ROUTE_TO_SCREEN_INTENT_TAGS ⊆ {ScreenEntry.intentTag}` to prevent future façade-sans-câblage. Proof: `python3` set-diff run above against both source files.

### Verdict

**PASS**

The change removes a genuine data-transport facade, tightens the LLM→navigation boundary to fail-closed, and improves privacy — with backend schema, analyzer, and all 74 affected tests confirming the wiring. The only open item is a pre-existing, fail-safe intent-tag drift (P2) that this diff neither introduces nor worsens.
