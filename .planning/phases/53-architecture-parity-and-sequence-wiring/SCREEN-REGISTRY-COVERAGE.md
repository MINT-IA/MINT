# Phase 53-01 — ScreenRegistry × app.dart coverage map

**Source of truth (extracted 2026-05-04):**
- `apps/mobile/lib/app.dart` — 153 `path:` literals
- `apps/mobile/lib/services/navigation/screen_registry.dart` — 105 `ScreenEntry` routes (after query-param normalization)

After `_NOT_CHAT_ROUTABLE` (13) + `_NESTED_PROFILE_CHILDREN` (7) exemptions: **41 paths in app.dart absent from MintScreenRegistry**, **0 ghost ScreenEntries**.

**Classification target:**
- **ROUTABLE** — needs full `ScreenEntry` row (chat-routable surface)
- **NOT_CHAT_ROUTABLE** — needs `ScreenEntry` with `preferFromChat: false` (LLM should know about it but not surface it)
- **ALLOWLIST** — add to `_NOT_CHAT_ROUTABLE` in the lint (intentionally absent from registry — auth, shell, dev-only)
- **DEFER_DEAD** — orphan / dead route; flag for Phase 55+ deletion plan

## Triage table

| # | Route | Class | Proposed `intentTag` | Proposed `behavior` | Notes |
|---|---|---|---|---|---|
| 1 | `/about` | ALLOWLIST | — | — | About / legal screen; not chat-routable |
| 2 | `/advisor` | ROUTABLE | `advisor_handoff` | `decisionCanvas` | Human-advisor handoff; chat may surface |
| 3 | `/advisor/plan-30-days` | ROUTABLE | `advisor_30_day_plan` | `decisionCanvas` | Coach can route after action plan generation |
| 4 | `/advisor/wizard` | ROUTABLE | `advisor_wizard` | `progressiveDisclosure` | Wizard for handoff |
| 5 | `/arbitrage/calendrier-retraits` | ROUTABLE | `withdrawal_calendar` | `decisionCanvas` | Multi-year withdrawal planning |
| 6 | `/arbitrage/rachat-vs-marche` | ROUTABLE | `lpp_buyback_vs_market` | `decisionCanvas` | LPP rachat vs market arbitrage |
| 7 | `/arbitrage/rente-vs-capital` | ROUTABLE | `rente_vs_capital_arbitrage` | `decisionCanvas` | Sibling of `/rente-vs-capital`; arbitrage variant |
| 8 | `/budget/setup` | ROUTABLE | `budget_setup` | `progressiveDisclosure` | First-time budget config from chat |
| 9 | `/coach/agir` | NOT_CHAT_ROUTABLE | `coach_action_log` | `conversationPure` | « Agir » tab — surfaced by tab bar, not chat |
| 10 | `/coach/dashboard` | NOT_CHAT_ROUTABLE | `coach_dashboard` | `conversationPure` | Coach overview dashboard — tab |
| 11 | `/coach/decaissement` | ROUTABLE | `decaissement_plan` | `decisionCanvas` | Coach-driven decaissement planning |
| 12 | `/coach/succession` | ROUTABLE | `succession_planning` | `decisionCanvas` | Coach-driven succession planning |
| 13 | `/disability/gap` | ROUTABLE | `disability_gap_check` | `decisionCanvas` | Invalidité gap analysis |
| 14 | `/document-scan` | ROUTABLE | `document_scan_entry` | `progressiveDisclosure` | Doc scan entry surface (post-auth) |
| 15 | `/document-scan/avs-guide` | ROUTABLE | `avs_extract_guide` | `progressiveDisclosure` | AVS extract guided scan |
| 16 | `/explore` | NOT_CHAT_ROUTABLE | `explore_tab` | `conversationPure` | Shell tab — tab bar surfaces it |
| 17 | `/household` | ROUTABLE | `household_overview` | `decisionCanvas` | Couple/household management |
| 18 | `/household/accept` | ROUTABLE | `household_accept_invite` | `progressiveDisclosure` | Partner-invite acceptance flow |
| 19 | `/life-event/divorce` | ROUTABLE | `life_event_divorce_v2` | `decisionCanvas` | High-priority life-event canvas (`_v2` suffix avoids collision with existing `/divorce` entry) |
| 20 | `/life-event/succession` | ROUTABLE | `life_event_succession` | `decisionCanvas` | Sibling of `/coach/succession`; verify dedup |
| 21 | `/lpp-deep/epl` | ROUTABLE | `lpp_deep_epl` | `decisionCanvas` | EPL deep-dive (LPP tier) |
| 22 | `/lpp-deep/libre-passage` | ROUTABLE | `lpp_deep_libre_passage` | `decisionCanvas` | Libre-passage deep-dive |
| 23 | `/mon-argent` | NOT_CHAT_ROUTABLE | `mon_argent_tab` | `conversationPure` | Shell tab |
| 24 | `/mortgage/affordability` | ROUTABLE | `mortgage_affordability_v2` | `decisionCanvas` | Sibling of `/affordability`; verify dedup or supersedes |
| 25 | `/onboarding/enrichment` | ALLOWLIST | — | — | Onboarding flow — not chat-routable post-onboard |
| 26 | `/onboarding/intent` | ALLOWLIST | — | — | Onboarding intent capture — pre-chat |
| 27 | `/onboarding/minimal` | ALLOWLIST | — | — | Minimal onboarding — pre-chat |
| 28 | `/onboarding/plan` | ALLOWLIST | — | — | Onboarding plan presentation |
| 29 | `/onboarding/promise` | ALLOWLIST | — | — | Onboarding promise screen |
| 30 | `/onboarding/quick-start` | ALLOWLIST | — | — | Quick-start onboarding |
| 31 | `/onboarding/smart` | ALLOWLIST | — | — | Smart onboarding variant |
| 32 | `/report` | ROUTABLE | `report_overview` | `progressiveDisclosure` | Report aperçu surface |
| 33 | `/report/v2` | ROUTABLE | `report_v2` | `progressiveDisclosure` | Report v2 (aperçu financier) |
| 34 | `/retirement` | ROUTABLE | `retirement_overview` | `decisionCanvas` | Retirement-overview surface (sibling of `/retraite`) |
| 35 | `/retirement/projection` | ROUTABLE | `retirement_projection` | `decisionCanvas` | Retirement projection variant |
| 36 | `/settings/confidentialite` | NOT_CHAT_ROUTABLE | `settings_privacy` | `conversationPure` | Phase 52 privacy settings — chat may DEEPLINK from a privacy nudge but tab is canonical |
| 37 | `/settings/langue` | NOT_CHAT_ROUTABLE | `settings_language` | `conversationPure` | Settings → language |
| 38 | `/simulator/3a` | ROUTABLE | `simulator_3a` | `decisionCanvas` | 3a simulator (sibling of `/pilier-3a` deep) |
| 39 | `/simulator/disability-gap` | ROUTABLE | `simulator_disability_gap` | `decisionCanvas` | Disability simulator (sibling of `/disability/gap`) |
| 40 | `/simulator/rente-capital` | ROUTABLE | `simulator_rente_capital` | `decisionCanvas` | Sibling of `/rente-vs-capital` |
| 41 | `/tools` | NOT_CHAT_ROUTABLE | `tools_tab` | `conversationPure` | Shell tab — surfaced by tab bar |

## Counts

| Class | Count | Action in T-53-01-03 |
|---|---|---|
| ROUTABLE | 24 | Add `ScreenEntry` rows with `preferFromChat: true`, fill `requiredFields` per code-read |
| NOT_CHAT_ROUTABLE | 9 | Add `ScreenEntry` rows with `preferFromChat: false` (mirrors existing `_authLogin` pattern) |
| ALLOWLIST | 8 | Add to `_NOT_CHAT_ROUTABLE` set in `screen_registry_parity.py` + document in KNOWN-MISSES.md |
| DEFER_DEAD | 0 | None identified in this audit |
| **Total** | **41** | — |

## Sibling deduplication candidates

Several ROUTABLE entries are siblings of existing entries (different paths, same intent). Two reasonable resolutions:

| Existing entry | New sibling | Resolution |
|---|---|---|
| `/rente-vs-capital` (`rente_vs_capital`) | `/arbitrage/rente-vs-capital`, `/simulator/rente-capital` | Different intentTags above (`*_arbitrage` vs `simulator_*`) — keep as separate registry entries; map via redirect in app.dart only if product confirms semantic dedup |
| `/affordability` (`mortgage_affordability`) | `/mortgage/affordability` | New entry uses `mortgage_affordability_v2` to disambiguate |
| `/retraite` (`retirement_choice`) | `/retirement`, `/retirement/projection` | Different intent surfaces — keep separate |
| `/coach/succession` | `/life-event/succession` | Same intent split across two paths — flag for product review post-T-53-01-03 |

The dedup decision is OUT OF SCOPE for Plan 53-01 (registry-only audit). Flagged here for Phase 55+ navigation cleanup.

## What this map does NOT do

- **Does NOT delete any route** — registry audit only; orphan-route deletion is Phase 55+.
- **Does NOT verify the proposed `requiredFields`** — that requires reading each screen's `initState` / `Provider` consumers. T-53-01-03 will use placeholder `requiredFields: []` + `// TODO 53-01: classify` for surfaces not obviously mapped, and a follow-up plan addresses the placeholders.
- **Does NOT add new `ScreenIntent` enum values** — proposed `intentTag` strings are free-form (the field type is `String`, see `screen_registry.dart:64`). If any proposed intentTag collides with an existing one, T-53-01-03 will resolve by adding a `_v2` suffix and flagging for Phase 55+ rationalization.
