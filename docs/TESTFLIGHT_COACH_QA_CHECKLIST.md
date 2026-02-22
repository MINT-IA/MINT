# TestFlight Coach QA Checklist (Prod Readiness)

Date: 2026-02-21
Scope: Onboarding, Dashboard, Agir, Profil, Auth (local-first + cloud optional)

## 1) Preflight build
- Build uses release API URL (`https://api.mint.ch/api/v1`) or explicit `--dart-define=API_BASE_URL=...`.
- App launches without gray screen on:
  - `/advisor`
  - `/advisor/wizard`
  - `/home`
  - `/profile`
- No raw technical exception shown to user (SocketException/ClientException stack traces).

## 2) Onboarding quality
- Persona single:
  - Step 1 -> 4 works end-to-end.
  - Completion shows coach intro + priorities.
- Persona couple/family:
  - Partner fields required before step 3 continue.
  - Civil status choice is explicit (marie/concubinage if applicable).
- Persona single parent:
  - Household option available.
  - Summary/coach priorities adapted.
- CTA check:
  - "Diagnostic complet" opens `/advisor/wizard`.
  - "Completer mon diagnostic" from plan 30 jours opens wizard (no gray screen).

## 3) Dashboard as coach
- Header greeting is personalized.
- Coach Pulse visible with narrative mode toggle.
- Score section shows narrative summary when available.
- Milestone chip appears only when meaningful.
- Scenario narrations visible:
  - BYOK off: static fallback shown.
  - BYOK on: LLM narration shown.
- "Reprendre mon plan 30 jours" card:
  - progress and resume route update correctly.

## 4) Agir and Check-in loop
- Agir partial state appears when profile incomplete.
- Agir CTA routes to correct wizard section.
- Check-in submit:
  - score delta shown,
  - "+CHF X ce mois" equals validated monthly contributions sum,
  - milestone celebration sheet appears when triggered.

## 5) Profil intelligence
- FactFind sections route to wizard with correct `section` extra.
- Coach monthly summary card visible.
- Guidance card shows recommended section + quality %.
- "Enrichir mon profil" never leads to gray screen.

## 6) Auth local-first UX
- Register screen explains optional account value clearly.
- Register + Login both provide "Continuer en mode local" path.
- Cloud outage scenario:
  - user sees friendly message,
  - local mode path still works.
- Delete cloud account flow works and keeps local-data message coherent.

## 7) Regression gates before external testing
- `flutter analyze` -> 0 errors.
- Run at minimum:
  - `test/screens/core_app_screens_smoke_test.dart`
  - `test/screens/core_screens_smoke_test.dart`
  - `test/screens/auth_screens_smoke_test.dart`
  - `test/screens/coach/navigation_shell_test.dart`
  - `test/screens/coach/coach_dashboard_test.dart`
  - `test/screens/coach/coach_agir_test.dart`
  - `test/screens/coach/coach_checkin_test.dart`
  - `test/screens/cta_navigation_regression_test.dart`

## 8) Release acceptance criteria
- No blocker on route navigation.
- No blocker on onboarding completion.
- No blocker on login/register local fallback.
- Coach narrative visible in Dashboard and Profil.
- Budget/score/check-in numbers coherent and non-contradictory.
