# Phase 6: Calculator Wiring - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Every calculator screen opened via a coach suggestion arrives pre-filled with data MINT already knows. Users are never asked to re-enter information the app has. Calculator results are written back to CoachProfile, keeping the data loop closed and triggering plan staleness detection.

</domain>

<decisions>
## Implementation Decisions

### Prefill Data Flow
- Backend tool enriches prefill — `route_to_screen` tool reads CoachProfile context and populates prefill map with relevant fields (avoirLppTotal, salaireBrutMensuel, etc.)
- All whitelisted calculator routes in `validRoutes` that have matching CoachProfile fields get prefilled
- Prefill keys match CoachProfile field names directly — `avoirLppTotal`, `salaireBrutMensuel`, `tauxConversion`, etc.
- Pass what's available, screen shows partial warning — `isPartial: true` on RouteSuggestionCard (already exists), screen pre-fills known fields, leaves others empty

### Calculator Screen Updates
- Screens consume prefill by reading `GoRouterState.extra` in `initState()` — existing pattern from `simulator_3a_screen.dart:71-79`, apply to all calculator screens
- Direct field mapping per screen:
  - `/rente-vs-capital`: avoirLppTotal, tauxConversion, salaireBrutMensuel, ageRetraite
  - `/pilier-3a`: salaireBrutMensuel, canton
  - `/hypotheque`: salaireBrutMensuel, epargneLiquide, avoirLppTotal
  - `/rachat-lpp`: salaireBrutMensuel, rachatMaximum, avoirLppTotal
  - `/3a-retroactif`: salaireBrutMensuel, canton
  - `/epl`: avoirLppTotal, salaireBrutMensuel
- Fields are editable defaults — prefilled values populate TextControllers but user can change any field freely
- Subtle "MINT" badge or filled state indicator — differentiates auto-filled from user-entered, matching MintColors.primary

### Result Write-Back
- Write-back happens on simulation completion — when user taps "Calculer" / "Simuler" and result is displayed, key outputs auto-saved to CoachProfile
- Primary computed outputs written back per calculator:
  - `/rente-vs-capital`: projected LPP capital at retirement, monthly rente amount
  - `/pilier-3a`: optimal 3a contribution, tax savings estimate
  - `/hypotheque`: mortgage capacity, monthly payments
  - `/rachat-lpp`: buyback impact on rente
- Silent write-back with subtle "Profil mis a jour" snackbar — no modal, appears briefly
- FinancialPlanProvider detects stale plan via existing profileHashAtGeneration mechanism

### Claude's Discretion
- Exact snackbar duration and animation
- Additional calculator field mappings beyond the 6 screens listed
- Error handling for write-back failures (silent retry vs user notification)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RouteSuggestionCard` (lib/widgets/coach/route_suggestion_card.dart): accepts route, prefill Map, isPartial
- `ToolCallParser.validRoutes` (lib/services/coach/tool_call_parser.dart): 40+ whitelisted routes
- `CoachProfile` (lib/models/coach_profile.dart): comprehensive financial data fields
- `FormPrefillService` (lib/services/form_prefill_service.dart): compliance-safe field extraction
- `FinancialPlanProvider` (lib/providers/financial_plan_provider.dart): stale plan detection via profile hash
- `CoachProfileProvider` (lib/providers/coach_profile_provider.dart): centralized profile access

### Established Patterns
- GoRouter extras: screens read `GoRouterState.of(context).extra` in initState (simulator_3a_screen.dart:71-79)
- Tool dispatch: coach sends `route_to_screen` → WidgetRenderer validates → RouteSuggestionCard rendered
- Profile update: `context.read<CoachProfileProvider>().updateField()` pattern

### Integration Points
- WidgetRenderer (widget_renderer.dart): already handles `route_to_screen` tool
- Calculator screens: need initState() prefill consumption + result write-back
- CoachProfile: fields for prefill source + write-back destination
- Backend coach_tools.py: `route_to_screen` tool needs prefill population logic

</code_context>

<specifics>
## Specific Ideas

- Golden couple test: Julien opening /rente-vs-capital should see 70,377 CHF pre-filled
- The isPartial flag on RouteSuggestionCard already handles missing data gracefully
- Write-back must use CoachProfileProvider.updateField(), not direct SharedPreferences writes

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
