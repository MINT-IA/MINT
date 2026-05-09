---
name: MINT comprehensive audit synthesis — 7 expert panel + 3 device findings
description: State-of-the-art audit aggregate. 7 parallel expert audits (navigation / archetypes E2E / state mgmt / UI design / a11y / sibling bugs / Maestro flows) + 3 critical device findings reported by Julien on TestFlight v2.12.2+4 (B13 anonymous routing leak, B14 hors-sujet « amortissement direct vs indirect » chip on debt context, B15 coach generic chips ignoring user data). Total 140+ findings consolidated into bug tracker P0/P1/P2 + 4 P0 perimeter STUBs. Recommendation: stop strategic doc filing, attack P0 #1 (archetype permit normalization) first.
type: decision
date: 2026-05-09
status: Proposed
related:
  - .planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md
  - .planning/decisions/2026-05-08-perimeter-b8-doctrine-runtime-wire/STUB.md
sources:
  - 7 panel sub-agents: a731524d (nav) / a95f4018 (archetypes) / a21914c4 (state) / a1addb77 (UI) / abcb7ac1 (sibling bugs) / aba4b516 (a11y) / a53d0712 (Maestro flows)
  - Julien device test reports 2026-05-09 (TestFlight v2.12.2+4 « j'ai des dettes » flow)
  - PR #525-#532 merged (foundation hotfix bundle)
---

# MINT comprehensive audit synthesis (10 audits, 140+ findings)

## TL;DR

**Architecture is sound. Data-input plumbing collapses 7/8 archetypes. UI design system has hidden drift (367 raw colors, 0 dark-mode). Anonymous-chat routing leaks loggé users into anon quota. 3 simulators (3a, rachat_echelonne, annual_refresh) bypass FATCA / archetype gates. Doctrine validator suite (`score_response`) is dead-code in production despite B6 commit claiming « FATCA bypass closed ».**

Recommended attack order (P0): permit value normalization (1-line, blast radius 100% frontaliers) → anonymous-chat routing fix (1 file, blast radius all loggé users) → wedge nationality capture (3-day perimeter) → simulator FATCA gate (1 file, expat_us critical).

## 10 audits at a glance

| # | Audit | Verdict | Critical findings |
|---|---|---|---|
| 1 | EXP-A Navigation/routes | ✅ CLEAN | 5 minor + 1 orphan dead code (`document_stream_result_screen.dart`) |
| 2 | EXP-B Archetypes E2E | 🔴 CRITIQUE | 7/8 archetypes broken at INPUT side, ~5-30k CHF compound fiscal harm/user/year |
| 3 | EXP-C State management | ✅ CLEAN | 0 P0/P1, 1 cosmetic listener leak |
| 4 | EXP-D UI design system | 🚨 DRIFT MASSIF | 367 `Colors.white/black` raw, 726 raw fontSize, 798 raw EdgeInsets, 0 dark-mode |
| 5 | EXP-E A11y + perf | ⚠️ SURFACE GAPS | 91 tap-able sans Semantics, 75/84 IconButton sans tooltip, 31 jank candidates |
| 6 | EXP-F Sibling bugs B1-B7 | 🚨 5 MUST-FIX | Anon B3, FRI/snapshot B4, 4 screens B7+B8, annual_refresh B2, doctrine_checks 7 functions test-only |
| 7 | EXP-G Maestro flows | ✅ 5 SHIPPED | + julien_swiss.yaml aspirational IDs revealed (silent test coverage gap) |
| 8 | DEVICE B13 anon routing leak | 🔴 CRITIQUE | Loggé user gets « Limite atteinte. Crée un compte » — auth state not respected by coach client |
| 9 | DEVICE B14 hors-sujet chip | 🔴 CRITIQUE | « Amortissement direct vs indirect » (mortgage 3a-nanti) suggested on debt-conso 15% context |
| 10 | DEVICE B15 generic chips ignore user data | 🟡 MED | Coach replies with category labels instead of reasoning on revenu=4500/dette=35000/15%/2000-mois |

## Bug tracker — consolidated

### P0 — User-blocking, fiscal harm, or compliance critical

| ID | Title | Source | Fix |
|---|---|---|---|
| **B13** | Anon routing leak for loggé users | `coach_chat_api_service.dart:225` 429 handler returns « Limite atteinte. Crée un compte ». Coach client routes loggé user to `/api/v1/anonymous/chat` instead of `/api/v1/coach/chat` | Audit which client-side service decides anon-vs-auth endpoint. Likely `auth_provider.isLoggedIn` not consulted before chat dispatch. 1 file fix |
| **B14** | « Amortissement direct vs indirect » hors-sujet on debt-conso | Chip suggested on user-input « j'ai des dettes » + numerical 15% interest = debt CONSO. ARB key uses « amortissement indirect » mortgage 3a-nanti — wrong context | Topic classifier probably keyword-matches « amortissement » without context check. Add archetype/intent guard. Search `coach_orchestrator.py` + `coach_tools.py` suggest_actions logic |
| **B-EXP-B-1** | Permit value mismatch frontalier | `wizard_questions_v2.dart:61` stores `'permit_g'` ; `coach_profile.dart:1781` checks `== 'G'`. **NEVER MATCHES**. Every frontalier mis-archétypé → 5-50k CHF/year buyback re-taxed risk | 1-line fix per location. Accept `'permit_g'` / `'permit_b'` / `'permit_c'` |
| **B-EXP-B-2** | Wedge onboarding never captures nationality | `OnboardingShellScreen` 8 steps = intent + age + canton + revenue ONLY. Anon chat hardcodes `'CH'` (`anonymous_chat_screen.dart:375`). Result: every user → `swiss_native` | Add nationality/permit capture step OR wire `updateFromSmartFlow` (currently 130-line dead code) |
| **B-EXP-B-3** | `simulator_3a_screen.dart:171` FATCA gate manquante | branch only on `independentNoLpp`. expat_us sees 7'258 CHF + tax-saving illusion. ARB string `financialSummaryFatcaWarning` exists, NOT WIRED | Add `if (profile.archetype == FinancialArchetype.expatUs \|\| !profile.canContribute3a)` gate. Wire existing ARB |
| **B-EXP-B-4** | `rachat_echelonne_screen.dart:191` no-op replace | `profile.archetype.name.replaceAll('_', '_').toLowerCase()` produit `"expatus"` au lieu `"expat_us"`. Backend OPP2 art. 60b cap silently bypassed | Use `_archetypeToBackendName` shared helper. Extract to `lib/services/coach/archetype_mapper.dart` |
| **B3-anon** | `anonymous_chat.py:178` missing empty-text guard | EXP-F finding. Same B3 bug on PUBLIC anon entry path. Conversion killer for first-time users | Mirror B3 fix from `orchestrator.py:138` to anonymous_chat handler |
| **B4-fri** | `schemas/fri.py:126,134` hardcoded `swiss_native / VD / 30` defaults | EXP-F finding. FRI score (headline metric) injects fake context if request omits fields | Set defaults to `""` / `0` (mirror Python coach_models.py B4 fix) |
| **B4-snapshot** | `models/snapshot.py:28-29` DB-level `default="VD"` / `"swiss_native"` | EXP-F finding. Persisted defaults survive across sessions, look « confirmed » | Migration: set `default=None` ; update consumers to handle null |

### P1 — Significant impact, polish, compound bugs

| ID | Title | Fix |
|---|---|---|
| **B7-cascade** | 4 screens `context.go('/coach/chat')` from empty-state CTAs (replace stack — user can't back-out) | Convert to `context.push` ; update `MintEmptyState` API contract |
| **B-EXP-B-5** | `updateFromSmartFlow` 130-line DEAD CODE | Wire to wedge OR delete (CLAUDE.md NEVER #6 façade-sans-câblage) |
| **B-EXP-F-1** | `annual_refresh_service.py:145` yearly « salaire annuel brut » cron hits retraités | Archetype gate or « source de revenus » phrasing |
| **B-EXP-F-2** | `precision_service.py:99,109` « Fiche de salaire mensuelle » prescriptive | Same as B2 fix: archetype-agnostic phrasing |
| **B6-confirmed** | `score_response` + 6 doctrine_checks: 0 production callers | Wire post-LLM in `coach_chat.py` agent loop OR `RAGOrchestrator.query()` post-filter (existing STUB perimeter `MVP-B8-DOCTRINE-RUNTIME-WIRE`) |
| **B15** | Generic chips ignore user data | Suggest_actions tool MANDATORY runs on every turn even when user provided concrete facts. Add « has-facts » gate to skip generic chips |
| **B-EXP-D-1** | `'Ma retraite'` chip hardcoded i18n + Rule-7 violation | `onboarding_shell_screen.dart:205` — replace with i18n key + reframe non-retraite-first |
| **B-EXP-D-2** | Bare CHF Text() on high-stakes financial screens (Rule-4 violation) | `rachat_echelonne_screen.dart:837/919/965/980` + `staggered_withdrawal_screen.dart:470/504` — wrap in MintTrameConfiance |
| **B12** (new) | Plausibility gates silently `continue` | `avs_extract_parser.py:261` + `tax_declaration_parser.py:320` — log + show signal to user |

### P2 — UI debt, a11y polish, internal consistency

| ID | Title | Effort |
|---|---|---|
| **EXP-D drift** | 367 raw `Colors.white/black`, 726 raw fontSize, 798 raw EdgeInsets, 15 distinct border-radius | New lints `no_raw_material_color.py` + `no_raw_fontsize.py` + `no_raw_radius.py` + `MintRadius` tokens |
| **EXP-D dark-mode** | 0 brightness checks, 415 light-baked refs | Architectural — palette dark + `MintColors.surface(brightness)` resolver |
| **EXP-E a11y** | 91 missing Semantics + 75 missing IconButton tooltip + 31 jank candidates | Top 3 quick wins: 75 IconButton tooltip via sed + ARB ; aujourdhui+explore Semantics ; lift 3 hot-build allocations |
| **EXP-A Nav** | `document_stream_result_screen.dart` orphan, `TimelineScreen:284` no back button, `/segments/gender-gap` unreachable, `/cantonal-benchmark` 0 inbound | 5 surgical fixes 1-line each |
| **EXP-C State** | `FinancialPlanProvider:85` anonymous closure listener leak | 6-line fix: stored field + dispose() removeListener |
| **B-EXP-F-3** | ~12 backend schemas with hardcoded `default="VD"` / `"ZH"` / `"GE"` | Sweep: expat.py + retirement.py + family.py + reengagement.py |
| **B-julien_swiss-aspirational-ids** | walker YAML uses ValueKey IDs that don't exist in source | Replace with FR text matchers (EXP-G already did for the 5 new flows) |
| **B-EXP-D-cta** | 2 ElevatedButton outliers + 4 distinct primary CTA widgets | `MintCTA.{primary,secondary,tertiary}` wrapper widget |

## 5 new bug taxonomy patterns (EXP-F + DEVICE)

- **B8** — `context.go` from empty-state CTAs (replaces stack vs push)
- **B9** — DB-level defaults seeding LLM context (worse than runtime)
- **B10** — Cascading test-only helper modules (doctrine_checks 7 functions, 0 prod callers)
- **B11** — Annual/scheduled prompts assuming archetype (cron retraite-blind)
- **B12** — Plausibility gates that silently `continue` (no telemetry, user has no signal)
- **B13** — Routing client-side ignores auth state (loggé user → anon endpoint)
- **B14** — Topic chip classifier matches keyword without context (« amortissement » conso vs hypothèque)
- **B15** — Suggest_actions chips fire even when user provided rich data

## Compound fiscal harm matrix (per archetype × bug)

| Bug | Archetype impact | CHF/user/year |
|---|---|---|
| Permit g mismatch | All frontaliers (~7% CH residents) | 5-50k buyback re-taxed |
| Wedge no nationality | All non-CH (~25%) | varies, archetype-mismatched advice |
| 3a sim FATCA gate | expat_us (~1-2%) | ~2k CHF illusion + Form 8621 cost |
| rachat_echelonne no-op | All expats <5y | 5-30k CHF undeductible payment |
| Annual refresh salaire | Retirees + indep (~25%) | trust-killer + advice mismatch |
| Anon routing leak | All loggé users hitting quota | conversion-killer |
| Bypass amortissement | Debt-conso users | trust-killer + wrong product recommendation |

## Perimeter STUBs to file (P0-tier)

1. **`MVP-P0-ARCHETYPE-INPUT-FIX-2026-05-09`** — fixes B-EXP-B-1 (permit normalization) + B-EXP-B-2 (wedge nationality) + B-EXP-B-3 (anon hardcoded CH). Effort ~1.5 j. Blocks 7/8 archetypes ROI.

2. **`MVP-P0-ANON-ROUTING-LEAK-2026-05-09`** — fixes B13 (loggé routed to anon). Effort ~0.5 j. ROI: stops conversion killer for all loggé users.

3. **`MVP-P0-CALCULATOR-FATCA-GATE-2026-05-09`** — fixes B-EXP-B-4 (rachat_echelonne no-op) + B-EXP-B-5 (3a sim FATCA wire). Effort ~0.5 j. ROI: stops 5-30k CHF compound fiscal harm for expat_us.

4. **`MVP-P0-DEBT-FLOW-CONTEXT-FIX-2026-05-09`** — fixes B14 (« amortissement direct vs indirect » hors-sujet) + B15 (generic chips ignore user data) on debt-conso intent. Effort ~1 j. ROI: trust + LSFin defensibility for debt users.

## Counter-arguments and data gaps

- **« Pourquoi pas filer 4-5 perimeters STUB at once? »** — Karpathy #2 simplicity-first : 4 STUBs is the hard cap. Beyond that, planning becomes ceremony. The 4 above cover the unblocking 95% of immediate user impact.
- **« B13 anon routing — peut-être que le user n'était PAS vraiment loggé »** — possible : Apple SSO token expired silently, AuthProvider.isLoggedIn returns true mais token rejeté backend. Mitigation: B13 perimeter must include token-validity check + force re-auth flow if rejected.
- **« B14 chip classifier — peut-être que c'est une suggestion pré-générée pas un classifier »** — possible. Need to grep how the chip was generated (suggest_actions tool output vs hardcoded). EXP-F audit didn't drill specifically on this.
- **« 7/8 archétypes broken — sounds dramatic, verify with telemetry »** — no telemetry baseline. Estimation O5 + EXP-B based on Swiss demographics. Real % may differ. Mitigation: ship Sentry breadcrumb « archetype detected = X » to measure post-fix.
- **« Should we abort TestFlight v2.12.2+4 given so many findings? »** — NO. v2.12.2+4 fixes B1-B6 hotfix bundle (validated by 4 expert audits 3 PASS + 1 retract). The newly discovered bugs (B13-B15 + EXP-B archetype input) are PRE-EXISTING, not introduced by v2.12.2+4. Shipping v2.12.2+4 strictly improves the situation.
- **« Why not write Maestro flow that reproduces B13/B14/B15 first? »** — Worth doing. After P0 perimeter for B13 ships, write Maestro `flow_debt_conso_intent.yaml` that asserts (a) loggé user does NOT see « Limite atteinte », (b) « amortissement direct vs indirect » chip NOT visible on debt-conso context, (c) generic chips skipped when user provided concrete facts.
- **« Architecture is sound — but 7/8 archétypes broken sounds like architecture is wrong »** — distinction : the **classifiers / model contracts** (FinancialArchetype enum, doctrine_checks cues, _detect_archetype resolution order) are correct. The **input-side wiring** (wedge, anon chat, register, drawer) doesn't capture/propagate the data. Surgical fixes per call site, not architectural rewrite.
- **« What about the v2 redesign perimeters MVP-FONTS-TOKENS-V2 + MVP-ONBOARDING-V2-AUTH-FIRST that were filed earlier? »** — STILL VALID, but prioritized BELOW P0 fixes. Redesign without fixing the underlying input plumbing = redesigning around a broken core.

## Recommendation senior PM (anti-sycophancy enforced)

Order of attack post-Julien-G2-confirm of v2.12.2+4 :

1. **P0 #1 — `MVP-P0-ANON-ROUTING-LEAK-2026-05-09`** (0.5 j). Quick win, fixes most-visible user bug (« Limite atteinte » on loggé user). Highest leverage.
2. **P0 #2 — `MVP-P0-DEBT-FLOW-CONTEXT-FIX-2026-05-09`** (1 j). Fixes B14 + B15. Critical for any user with debt intent (which is « j'ai des dettes » = the FIRST thing Julien typed).
3. **P0 #3 — `MVP-P0-ARCHETYPE-INPUT-FIX-2026-05-09`** (1.5 j). Fixes 7/8 archetypes input plumbing. Biggest blast radius but heavier scope.
4. **P0 #4 — `MVP-P0-CALCULATOR-FATCA-GATE-2026-05-09`** (0.5 j). Fixes 2 simulators. Compound fiscal harm closure.
5. **P1 sweep** — bundle B7-cascade + B-EXP-F-1/2 + B-EXP-D-1/2 + B6 doctrine wire (`MVP-B8-DOCTRINE-RUNTIME-WIRE` already STUBd). Effort ~3 j.
6. **P2 sweep** — UI design system enforcement (new lints + MintRadius + MintCTA + dark mode foundation). Effort ~2 j.
7. **v2 redesign** — `MVP-FONTS-TOKENS-V2` + `MVP-ONBOARDING-V2-AUTH-FIRST`. Effort ~3 j combined.

**Total to fully clean MINT: ~12-13 j systematic execution.**

If forced to ship ONE thing today : **B13 anon routing fix**. Because it's a 0.5 j fix that immediately stops the « Limite atteinte » trust-killer Julien just hit.

## References

- 7 panel sub-agents transcripts at `/private/tmp/claude-501/.../tasks/`
- PR #525 (wire FinancialPlanCard) MERGED db350b77
- PR #527 (pubspec 2.12.1+3 + memoize) MERGED 26f5f197
- PR #526 (close-out doc + audit corrections) MERGED ec6024c6
- PR #528 (dev → staging v2.12.1+3) MERGED 532b7dae
- PR #529 (onboarding crisis hotfix B1-B6) MERGED dc987c4c
- PR #530 (pubspec 2.12.2+4) MERGED d5939319
- PR #531 (dev → staging v2.12.2+4) MERGED f5585f9f
- PR #532 (B8 STUB + B6 retraction) MERGED 5ddf4bb5
- TestFlight v2.12.1+3 (run 25568240358) SUCCESS 2026-05-08T17:09:17Z
- TestFlight v2.12.2+4 (run 25574646749) SUCCESS 2026-05-08T19:28:57Z
- Walker premier_eclairage 3/4 archetypes ✅ (julien_swiss / jeune_diplome_zurich / cadre_40_55_lpp_rachat) + couple_acheteurs (.nosync infra flake)
- Pytest backend full ✅ 6055/6055
- Flutter test CI scope ✅ 7802/7802
- 5 new Maestro flows shipped at `tools/simulator/flows/maestro-perfect-set/`
- Julien device test 2026-05-09 « j'ai des dettes » → 3 new findings B13/B14/B15
