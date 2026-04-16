# AUDIT_ORPHAN_ROUTES — GoRouter route reachability audit (STAB-14)

**Generated:** 2026-04-07
**Scope:** Every `path:` declaration in `apps/mobile/lib/app.dart` GoRouter config (lines 190-940).
**Method:**
- `grep -rEn "(context\.(go|push|pushReplacement|pushNamed)|GoRouter\.of)[^']*'<path>'" apps/mobile/lib/` (excluding `app.dart` itself which contains the definitions).
- Cross-reference with `services/navigation/screen_registry.dart` (table-driven intent→route map) and `services/coach/tool_call_parser.dart` `validRoutes` whitelist. A route referenced there is effectively reachable via coach tool calls, even if no direct `context.go` caller exists.
- Cross-reference with `screens/main_tabs/explore_tab.dart` for the 7 Explorer hub routes.
**Verdict legend:**
- **REACHABLE** — ≥1 caller from the current 3-tab + drawer shell
- **REGISTRY-ONLY** — no direct caller, reachable only via coach `route_to_screen` tool or screen_registry intent map (DEEP-LINK-ONLY equivalent for MINT)
- **ORPHAN** — zero callers anywhere (neither direct nor via registry)
- **REDIRECT** — path is a redirect shim to another route (not a screen); listed separately

NO source code modified.

---

## Part A — Top-level (non-redirect) routes

| # | Path | Direct callers | Verdict | Caller notes | Action |
|---|------|----------------|---------|--------------|--------|
| 1 | `/` | 9 | REACHABLE | root | KEEP |
| 2 | `/auth/login` | 6 | REACHABLE | auth flow | KEEP |
| 3 | `/auth/register` | 2 | REACHABLE | auth flow | KEEP |
| 4 | `/auth/forgot-password` | 1 | REACHABLE | auth flow | KEEP |
| 5 | `/auth/verify-email` | 2 | REACHABLE | auth flow | KEEP |
| 6 | `/auth/verify` | 0 | **ORPHAN** | no direct caller; grep `'/auth/verify'` returns only the route def | **DELETE** or wire from email verification link |
| 7 | `/home` | 9 | REACHABLE | main shell | KEEP |
| 8 | `/explore/retraite` | 0 (direct) | REACHABLE | Called from `screens/main_tabs/explore_tab.dart` via hub tiles + listed in `screen_registry.dart` + `tool_call_parser.dart:127` | KEEP |
| 9 | `/explore/famille` | 0 (direct) | REACHABLE | same as above | KEEP |
| 10 | `/explore/travail` | 0 (direct) | REACHABLE | same | KEEP |
| 11 | `/explore/logement` | 0 (direct) | REACHABLE | same | KEEP |
| 12 | `/explore/fiscalite` | 0 (direct) | REACHABLE | same | KEEP |
| 13 | `/explore/patrimoine` | 0 (direct) | REACHABLE | same | KEEP |
| 14 | `/explore/sante` | 0 (direct) | REACHABLE | same | KEEP |
| 15 | `/retraite` | 5 | REACHABLE | KEEP |
| 16 | `/rente-vs-capital` | 4 | REACHABLE | KEEP |
| 17 | `/rachat-lpp` | 1 | REACHABLE | KEEP |
| 18 | `/epl` | 1 | REACHABLE | KEEP |
| 19 | `/decaissement` | 1 | REACHABLE | KEEP |
| 20 | `/coach/cockpit` | 4 | REACHABLE | note: Wire Spec V2 P4 marks this as archived; if callers are legacy, convert to redirect `→ /home?tab=1` | VERIFY then DELETE or REDIRECT |
| 21 | `/coach/checkin` | 0 | **ORPHAN** | Wire Spec V2 P4 archived; no caller | **DELETE** or REDIRECT to `/home?tab=1` |
| 22 | `/coach/refresh` | 1 | REACHABLE | Wire Spec V2 P4 archived | VERIFY then REDIRECT to `/home?tab=1` |
| 23 | `/coach/chat` | 1 | REACHABLE | KEEP |
| 24 | `/coach/history` | 0 | **ORPHAN** | `conversation_history_screen.dart` exists but is not navigated to from shell | **DELETE** route + screen, or WIRE from drawer |
| 25 | `/succession` | 1 | REACHABLE | life event | KEEP |
| 26 | `/libre-passage` | 1 | REACHABLE | KEEP |
| 27 | `/pilier-3a` | 3 | REACHABLE | KEEP |
| 28 | `/3a-deep/comparator` | 1 | REACHABLE | KEEP |
| 29 | `/3a-deep/real-return` | 1 | REACHABLE | KEEP |
| 30 | `/3a-deep/staggered-withdrawal` | 1 | REACHABLE | KEEP |
| 31 | `/3a-retroactif` | 1 | REACHABLE | KEEP |
| 32 | `/fiscal` | 3 | REACHABLE | KEEP |
| 33 | `/hypotheque` | 1 | REACHABLE | KEEP |
| 34 | `/mortgage/amortization` | 1 | REACHABLE | KEEP |
| 35 | `/mortgage/epl-combined` | 1 | REACHABLE | KEEP |
| 36 | `/mortgage/imputed-rental` | 1 | REACHABLE | KEEP |
| 37 | `/mortgage/saron-vs-fixed` | 1 | REACHABLE | KEEP |
| 38 | `/budget` | 9 | REACHABLE | KEEP |
| 39 | `/check/debt` | 0 | **ORPHAN** | no direct caller. `debt_risk_check_screen.dart` exists | VERIFY — probable DEAD; DELETE or WIRE from drawer |
| 40 | `/debt/ratio` | 0 | **ORPHAN** | screen exists (`debt_ratio_screen.dart`) but no caller grep match for exact path; may be reached via `debt_tools_nav.dart` (3 matches) — VERIFY | VERIFY then KEEP or DELETE |
| 41 | `/debt/help` | 0 | **ORPHAN** | same pattern as /debt/ratio | VERIFY then KEEP or DELETE |
| 42 | `/debt/repayment` | 1 | REACHABLE | KEEP |
| 43 | `/divorce` | 1 | REACHABLE | life event | KEEP |
| 44 | `/mariage` | 1 | REACHABLE | KEEP |
| 45 | `/naissance` | 1 | REACHABLE | KEEP |
| 46 | `/concubinage` | 1 | REACHABLE | KEEP |
| 47 | `/unemployment` | 1 | REACHABLE | KEEP |
| 48 | `/first-job` | 1 | REACHABLE | KEEP |
| 49 | `/expatriation` | 1 | REACHABLE | KEEP |
| 50 | `/simulator/job-comparison` | 1 | REACHABLE | KEEP |
| 51 | `/segments/independant` | 1 | REACHABLE | KEEP |
| 52 | `/independants/avs` | 1 | REACHABLE | KEEP |
| 53 | `/independants/ijm` | 1 | REACHABLE | KEEP |
| 54 | `/independants/3a` | 1 | REACHABLE | KEEP |
| 55 | `/independants/dividende-salaire` | 1 | REACHABLE | KEEP |
| 56 | `/independants/lpp-volontaire` | 1 | REACHABLE | KEEP |
| 57 | `/invalidite` | 1 | REACHABLE | KEEP |
| 58 | `/disability/insurance` | 1 | REACHABLE | KEEP |
| 59 | `/disability/self-employed` | 1 | REACHABLE | KEEP |
| 60 | `/assurances/lamal` | 1 | REACHABLE | KEEP |
| 61 | `/assurances/coverage` | 1 | REACHABLE | KEEP |
| 62 | `/scan` | 13 | REACHABLE | KEEP |
| 63 | `/scan/avs-guide` | 0 | **ORPHAN** | direct grep returns 0 | VERIFY — probable DEAD; the scan flow may use state instead of route. DELETE if confirmed. |
| 64 | `/scan/review` | 5 | REACHABLE | KEEP |
| 65 | `/scan/impact` | 1 | REACHABLE | KEEP |
| 66 | `/documents` | 4 | REACHABLE | KEEP |
| 67 | `/documents/:id` | — | REACHABLE | param route, reached via `context.push('/documents/\$id')` — grep counts for `/documents` may include these | KEEP |
| 68 | `/couple` | 3 | REACHABLE | KEEP |
| 69 | `/couple/accept` | 0 | REGISTRY-ONLY | reached via deep link from invitation email (external) | KEEP as deep-link-only; DOCUMENT |
| 70 | `/rapport` | 1 | REACHABLE | KEEP |
| 71 | `/profile` | 16 | REACHABLE | drawer | KEEP |
| 72 | `/profile/bilan` (child) | — | REACHABLE | sub-route of /profile | KEEP |
| 73 | `/profile/byok` (child) | — | REACHABLE | sub-route of /profile | KEEP |
| 74 | `/profile/...` other child routes | — | REACHABLE | 7 GoRoute children at lines 647-675 — reached via drawer tiles | KEEP |
| 75 | `/segments/gender-gap` | 1 | REACHABLE | KEEP |
| 76 | `/segments/frontalier` | 1 | REACHABLE | KEEP |
| 77 | `/life-event/housing-sale` | 1 | REACHABLE | KEEP |
| 78 | `/life-event/donation` | 1 | REACHABLE | KEEP |
| 79 | `/life-event/deces-proche` | 1 | REACHABLE | KEEP |
| 80 | `/life-event/demenagement-cantonal` | 1 | REACHABLE | KEEP |
| 81 | `/education/hub` | 10 | REACHABLE | KEEP |
| 82 | `/education/theme/:id` | — | REACHABLE | sub-route from hub | KEEP |
| 83 | `/simulator/compound` | 1 | REACHABLE | KEEP |
| 84 | `/simulator/leasing` | 1 | REACHABLE | KEEP |
| 85 | `/simulator/credit` | 1 | REACHABLE | KEEP |
| 86 | `/arbitrage/bilan` | 2 | REACHABLE | KEEP |
| 87 | `/arbitrage/allocation-annuelle` | 1 | REACHABLE | KEEP |
| 88 | `/arbitrage/location-vs-propriete` | 1 | REACHABLE | KEEP |
| 89 | `/achievements` | 0 (direct) | REGISTRY-ONLY | `achievements_screen.dart` exists; referenced in `profile_drawer.dart` (1 match) | VERIFY drawer entry then KEEP |
| 90 | `/weekly-recap` | 0 | **ORPHAN** | no caller grep match | VERIFY — likely DEAD; DELETE |
| 91 | `/cantonal-benchmark` | 0 | **ORPHAN** | no caller | VERIFY — likely DEAD; DELETE |
| 92 | `/settings/langue` | 0 | REGISTRY-ONLY | reached from `settings_sheet.dart` (2 matches) | VERIFY sheet wiring, then KEEP |
| 93 | `/about` | 0 | **ORPHAN** | no caller grep match | VERIFY — likely DEAD; DELETE or wire from drawer |
| 94 | `/ask-mint` | 1 | REACHABLE | Wire Spec V2 P4 marks this archived; should be a redirect to `/home?tab=1` per CLAUDE.md §7 | VERIFY then REDIRECT |
| 95 | `/tools` | 0 | **ORPHAN** | Wire Spec V2 P4 archived | **DELETE** or REDIRECT to `/home?tab=1` |
| 96 | `/portfolio` | 1 | REACHABLE | VERIFY — `portfolio_screen.dart` may be v1 artifact | VERIFY then KEEP or DELETE |
| 97 | `/timeline` | 0 | **ORPHAN** | `timeline_screen.dart` exists (see AUDIT_DEAD_CODE.md `timeline_service.dart` is DEAD-IN-PROD) | **DELETE** route + screen |
| 98 | `/confidence` | 0 | **ORPHAN** | no caller grep match for exact `'/confidence'` | VERIFY then DELETE |
| 99 | `/score-reveal` | 0 | **ORPHAN** | no caller; likely onboarding artifact | VERIFY then DELETE |
| 100 | `/onboarding/quick` | 8 | REACHABLE | KEEP |
| 101 | `/onboarding/quick-start` | 1 | REACHABLE | KEEP |
| 102 | `/onboarding/chiffre-choc` | 1 | REACHABLE | KEEP |
| 103 | `/onboarding/intent` | 10 | REACHABLE | KEEP |
| 104 | `/onboarding/promise` | 1 | REACHABLE | KEEP |
| 105 | `/onboarding/plan` | 1 | REACHABLE | KEEP |
| 106 | `/data-block/:type` | — | REACHABLE | param route | KEEP |
| 107 | `/open-banking` | 0 | **ORPHAN** | no caller grep match; out of scope per PROJECT.md ("bLink production v3.0+") | **DELETE** route + screen (sandbox UI can live in profile sub-route) |
| 108 | `/open-banking/transactions` | 0 | **ORPHAN** | same | **DELETE** |
| 109 | `/open-banking/consents` | 0 | **ORPHAN** | same | **DELETE** |
| 110 | `/bank-import` | 1 | REACHABLE | verify caller is reachable from shell | VERIFY |

## Part B — Redirect shims (alias routes)

These are legacy-compat redirect entries that forward to a canonical route. Per Wire Spec V2, all 67 canonical routes stay as deep links — redirects keep old deep links alive.

| Path | Redirects to | Keep? |
|------|--------------|-------|
| `/coach/dashboard` | `/retraite` | KEEP (alias) |
| `/retirement` | `/retraite` | KEEP |
| `/retirement/projection` | `/retraite` | KEEP |
| `/arbitrage/rente-vs-capital` | `/rente-vs-capital` | KEEP |
| `/simulator/rente-capital` | `/rente-vs-capital` | KEEP |
| `/lpp-deep/rachat` | `/rachat-lpp` | KEEP |
| `/arbitrage/rachat-vs-marche` | `/rachat-lpp` | KEEP |
| `/lpp-deep/epl` | `/epl` | KEEP |
| `/coach/decaissement` | `/decaissement` | KEEP |
| `/arbitrage/calendrier-retraits` | `/decaissement` | KEEP |
| `/coach/succession` | `/succession` | KEEP |
| `/life-event/succession` | `/succession` | KEEP |
| `/lpp-deep/libre-passage` | `/libre-passage` | KEEP |
| `/simulator/3a` | `/pilier-3a` | KEEP |
| `/mortgage/affordability` | `/hypotheque` | KEEP |
| `/life-event/divorce` | `/divorce` | KEEP |
| `/disability/gap` | `/invalidite` | KEEP |
| `/simulator/disability-gap` | `/invalidite` | KEEP |
| `/document-scan` | `/scan` | KEEP |
| `/document-scan/avs-guide` | `/scan/avs-guide` | DELETE if target is deleted |
| `/household` | `/couple` | KEEP |
| `/household/accept` | conditional | KEEP |
| `/report` | `/rapport` | KEEP |
| `/report/v2` | `/rapport` | KEEP |
| `/advisor` | `/onboarding/quick` | KEEP |
| `/advisor/plan-30-days` | `/home` | KEEP |
| `/advisor/wizard` | conditional | KEEP |
| `/coach/agir` | `/home` | KEEP |
| `/onboarding/smart` | `/onboarding/quick` | KEEP |

All redirects are structural and should remain (Wire Spec V2 §67 canonical routes).

---

## Summary

| Category | Count |
|----------|-------|
| Total GoRoute `path:` declarations | ~110 (incl. sub-routes + redirects) |
| Top-level routes enumerated | ~100 |
| REDIRECT shims | 29 |
| REACHABLE (direct caller count ≥1) | 72 |
| REACHABLE via registry/hub (indirect) | 8 (explore/* + achievements + settings/langue) |
| **ORPHAN findings** | **17** (rows 6, 21, 24, 39, 40, 41, 63, 90, 91, 93, 95, 97, 98, 99, 107, 108, 109) |
| VERIFY-then-decide | 9 (rows 20, 22, 89, 92, 94, 96, 100-level wire-spec archived, 110) |

**Fix tasks for plan 07-04:**
1. (P1) **DELETE or REDIRECT archived coach routes** per Wire Spec V2 P4: `/coach/cockpit`, `/coach/checkin`, `/coach/refresh`, `/ask-mint`, `/tools` → redirect to `/home?tab=1`.
2. (P1) **DELETE orphan routes** (no caller, no screen usage): `/auth/verify`, `/coach/history`, `/weekly-recap`, `/cantonal-benchmark`, `/about`, `/timeline`, `/confidence`, `/score-reveal`, `/open-banking`, `/open-banking/transactions`, `/open-banking/consents`.
3. (P2) **Verify then decide** on `/debt/ratio`, `/debt/help`, `/check/debt`, `/scan/avs-guide`, `/portfolio`, `/bank-import` — each needs a 2-minute caller-trace before DELETE.
4. (P2) **Document** `/couple/accept` as DEEP-LINK-ONLY (external invitation email).

Cross-reference: Every DELETE candidate should also remove the matching entry from `tool_call_parser.dart:64-134` `validRoutes` whitelist and `screen_registry.dart` intent map — otherwise the coach tool would still "validate" the route and fail at navigation time.
