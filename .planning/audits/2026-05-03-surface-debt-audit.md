# MINT — Surface-Code Debt Audit

**Date:** 2026-05-03
**Branch:** `feat/anonymous-chat-handoff2-appbar`
**Scope:** Code that looks done but isn't wired, tested, or honest about its state.
**Methodology:** Mechanical scans (grep / lint runs / file-cross-ref) anchored to the documented MINT failure patterns (W14 doctrine, ARB i18n, banned LSFin terms, financial_core source-of-truth). No subjective design judgments — only counts and file:line.

---

## TL;DR (2-minute read)

| Category | Count | Severity | Hours to clean |
|---|---|---|---|
| 1 — Façade without wiring | ~0 visible | LOW | 0 |
| 2 — Dead screens / orphan routes | 1 new orphan + 28 KNOWN-MISSES | MEDIUM | 2 |
| 3 — Tests that don't test | 3 placeholder tests + 12 hard-coded `skip:true` | HIGH | 4 |
| 4 — Calculator duplication outside `financial_core/` | 28 mobile + 33 backend matches across 9+11 files | HIGH | 24 |
| 5 — Hardcoded user-facing strings | **4 994** lint hits | BLOCKER | 60 |
| 6 — Hardcoded colors | 2 `Color(0xFF…)` outside theme; ~0 raw `Colors.*` | LOW | 0.25 |
| 7 — Banned LSFin terms in product code | 2 backend schema descriptions; rest are guard registries | MEDIUM | 1 |
| 8 — Tools/checks not in lefthook or CI | **9 of 27** scripts unwired | HIGH | 3 |
| 9 — TODO / FIXME / HACK density | 30 in mobile lib, 7 in backend | LOW | — |
| 10 — Phase deferred items still open | ~23 active DEFERRED markers | MEDIUM | n/a (process) |
| 11 — Recent fix:feature ratio | 50 fix : 71 feat (last 200) ≈ 0.70 | MEDIUM | n/a (process) |

**Surface-debt score: 41 / 100.** The two BLOCKER/HIGH stones that move the most lucidity for the least effort are **(a) i18n debt** and **(b) un-wired lints** — see Pareto section.

The codebase is stronger than the « 72 files deleted in W14 » trauma suggests. Façade widgets, raw colors and Navigator.push are essentially gone. The remaining debt lives in **content + tooling discipline**, not in stub UI.

---

## Category 1 — Façade without wiring (W14 doctrine)

### Findings

- **Empty `() {}` callbacks in user-facing widgets:** `0` matches with the strict pattern `(onTap|onPressed):\s*\(\)\s*\{\s*\}`.
- **Empty `() => null` callbacks:** `0` matches.
- **`Navigator.push(...)` (anti-pattern vs go_router):** `1` match — and it is intentional with a documented exemption:
  - `apps/mobile/lib/widgets/fullscreen_chart_wrapper.dart:48` — `// GoRouter: intentional overlay — Navigator.push is intentional here,`
- **`UnimplementedError`:** `0` thrown anywhere in mobile.
- **`raise NotImplementedError`:** `3` in `services/backend/app/services/open_banking/blink_connector.py:213,246,275` — Blink connector stubs (open banking integration is feature-flagged off; per memory `BYOK out-of-scope`, deliberate).
- **« Coming soon » / `bient.t` user copy:** `0` matches in screens or widgets.
- **Placeholder widgets (`// Placeholder`):** `1` match (`apps/mobile/lib/screens/document_detail_screen.dart:72` — fallback empty-state, not a stub).
- **Pattern `_handleX()` with `// TODO` body:** `0` matches.

### Verdict

**Severity: LOW.** This is the cleanest category and the W14 doctrine has held. The mobile app does not ship buttons that lie about doing something.

The one Navigator.push call is documented. The three `NotImplementedError`s in blink_connector are honest stubs guarded by feature flag.

### Top 5 offenders

| File:Line | Description |
|---|---|
| `apps/mobile/lib/widgets/fullscreen_chart_wrapper.dart:48` | Documented intentional Navigator.push exemption |
| `services/backend/app/services/open_banking/blink_connector.py:213` | Blink open-banking stub (feature-flagged off) |
| `services/backend/app/services/open_banking/blink_connector.py:246` | Blink open-banking stub |
| `services/backend/app/services/open_banking/blink_connector.py:275` | Blink open-banking stub |
| `apps/mobile/lib/screens/document_detail_screen.dart:72` | Empty-state placeholder, real fallback not a stub |

**Estimated cleanup:** 0 h (nothing actionable; flag the blink connector stubs in the open-banking phase plan if/when feature flag flips on).

---

## Category 2 — Dead screens / orphan routes

### Findings

- **Total `*Screen` classes in `apps/mobile/lib/screens/`:** 100 unique class names across 108 files.
- **Total `path:` declarations in `app.dart`:** 153.
- **Registry coverage (Plan 53-01 lint):** 125 routes parity OK + 21 not-chat-routable + 7 nested-profile = full coverage **after exemptions**.
- **Route registry parity (Plan 32-04 lint):** 145 routes OK + 1 admin-conditional + 7 nested-profile = full coverage.

### NEW orphan since last lint baseline

- `apps/mobile/lib/screens/document_scan/document_stream_result_screen.dart` — `class DocumentStreamResultScreen` (Phase 28-04). **Zero references** in `app.dart`, `screen_registry.dart`, any other `.dart` file, or test fixture. The class is constructed nowhere in the build graph.

This is a **textbook W14 leftover**: phase landed, screen was never wired, file survived the cleanup. Cost to fix: 1 commit `git rm` + close-out note.

### Other low-reference screens (referenced once outside themselves — likely tab-shell wrappers, verified safe)

`AboutScreen`, `ArbitrageBilanScreen`, `BudgetContainerScreen`, `ComprendreHubScreen`, `ConfidentialiteSettingsScreen`, `DocumentDetailScreen`, `ExplorerScreen`, `OpenBankingHubScreen`, `TimelineScreen` — each has exactly one constructor call from `app.dart`, normal for terminal-leaf screens.

### Routes intentionally exempted from parity (documented in `tools/checks/*-KNOWN-MISSES.md`)

- 21 routes flagged `_NOT_CHAT_ROUTABLE` (auth flows, onboarding, admin, chat-itself).
- 7 nested `/profile/*` children (regex Category 5 limitation).
- 1 admin-conditional route `/admin/routes` (compile-time gated).

These are documented; not debt.

### Top 5 actions

| File | Action |
|---|---|
| `apps/mobile/lib/screens/document_scan/document_stream_result_screen.dart` | Delete file (dead since Phase 28-04) |
| `tools/checks/screen_registry_parity-KNOWN-MISSES.md` | Audit Phase 53-01 §SCREEN-REGISTRY-COVERAGE.md to confirm none of the 21 « NOT_CHAT_ROUTABLE » entries are actually orphan-deletes-in-disguise |
| `apps/mobile/lib/screens/anonymous/` | Verify `/anonymous/intent` & `/anonymous/chat` are genuinely surfaced; both exist in app.dart |
| `.planning/phases/53-architecture-parity-and-sequence-wiring/SCREEN-REGISTRY-COVERAGE.md` | Surface dedup decision (currently « OUT OF SCOPE for Plan 53-01, flagged for Phase 55+ ») |
| `apps/mobile/lib/screens/admin/` | OK as-is — `if (AdminGate.isAvailable)` tree-shake doctrine documented |

**Severity: MEDIUM** (1 verified orphan, no critical UX impact).
**Estimated cleanup:** 2 h (delete + one regression test that fails on un-referenced `*Screen` class names).

---

## Category 3 — Tests that don't test

### Findings

- **Tautology tests (`expect(true, isTrue)`):** **3 hits** — all in the same file:
  - `apps/mobile/test/providers/auth_provider_test.dart:164` — `// Placeholder — actual integration in e2e tests`
  - `apps/mobile/test/providers/auth_provider_test.dart:168` — bare `expect(true, isTrue);`
  - `apps/mobile/test/providers/auth_provider_test.dart:172` — bare `expect(true, isTrue);`
- **Test files with `0` `expect(` calls:** 10 files, but **9 of them are helpers/golden harnesses** that use `expectLater + matchesGolden` or `meetsGuideline` (counted by my naive grep). One real risk: `apps/mobile/test/accessibility/wcag_aa_all_touched_test.dart` uses `meetsGuideline` ✅ — fine.
- **Hard-coded `skip: true` in tests:** **10 tests skipped permanently**.
  - `apps/mobile/test/screens/coach/coach_chat_test.dart` — 5 skipped tests (lines 226, 251, 290, 313, 404).
  - `apps/mobile/test/goldens/s4_response_card_golden_test.dart` — 3 skipped (deferred Plan 04-02 race).
  - `apps/mobile/test/screens/lpp_deep_screens_smoke_test.dart:266` — scroll offset issue.
  - `apps/mobile/test/navigation_verify_test.dart:34` — full nav flow.
- **`pytest.skip(...)` calls in backend:** **5 hits**, all conditional (missing fixtures or path-traversal guards) — legitimate.
- **Mockito-pattern usage in mobile:** `0` files import `mockito` — the « mock and assert against the mock » anti-pattern is absent in mobile. Backend has 48 test files using `Mock` / `monkeypatch`, normal density given 196 backend test files.
- **Golden snapshot tests:** present (`golden_screenshot_test.dart`, `mtc_golden_test.dart`, etc.). No commit history showing blanket-update via `--update-goldens` in the last 50 commits (only `7a0336d8 test(49-07): add 6 golden baselines + canvas_visual_fidelity_golden_test (VISUAL-M10)` — additive, not a regen).

### Top 10 worst offenders

| File:Line | Description |
|---|---|
| `apps/mobile/test/providers/auth_provider_test.dart:164` | `expect(true, isTrue)` placeholder for « error mapping covers network errors » |
| `apps/mobile/test/providers/auth_provider_test.dart:168` | Same — duplicate email |
| `apps/mobile/test/providers/auth_provider_test.dart:172` | Same — wrong credentials |
| `apps/mobile/test/screens/coach/coach_chat_test.dart:226` | `skip: true` |
| `apps/mobile/test/screens/coach/coach_chat_test.dart:251` | `skip: true` |
| `apps/mobile/test/screens/coach/coach_chat_test.dart:290` | `skip: true` |
| `apps/mobile/test/screens/coach/coach_chat_test.dart:313` | `skip: true` |
| `apps/mobile/test/screens/coach/coach_chat_test.dart:404` | `skip: true` |
| `apps/mobile/test/goldens/s4_response_card_golden_test.dart:34,…` | `skip: true` (3×, Plan 04-02 race deferred) |
| `apps/mobile/test/screens/lpp_deep_screens_smoke_test.dart:266` | `skip: true` for scroll offset |
| `apps/mobile/test/navigation_verify_test.dart:34` | `skip: true` for « Full Navigation Flow Verification » |

The 5 `coach_chat_test.dart` skips are the worst — chat is the heart of the product, the assertions exist (the test bodies are real), but the runner never executes them.

### Verdict

**Severity: HIGH.** The three `expect(true, isTrue)` hits are documented placeholders for e2e tests that don't exist yet. The 5 chat skips are a silent-fail risk.

**Estimated cleanup:** 4 h (write 3 real auth-error-mapping tests + un-skip 5 coach_chat tests, fix what they reveal).

---

## Category 4 — Calculator duplication (rule #4)

### Findings

`financial_core/` source-of-truth lives at `apps/mobile/lib/services/financial_core/` (17 calculator files: avs, lpp, tax, mortgage, monte_carlo, etc.).

#### Mobile (`_calculate*` / `_calc*` outside `financial_core/`)

**28 occurrences across 9 files:**

| File | Calc methods (count) |
|---|---|
| `apps/mobile/lib/services/financial_fitness_service.dart` | 6 — `_calculateBudget`, `_calculatePrevoyance`, `_calculatePatrimoine`, etc. |
| `apps/mobile/lib/services/circle_scoring_service.dart` | 5 — `_calculateAvsGaps`, `_calculateSpouseAvsGaps` |
| `apps/mobile/lib/services/simulators/real_interest_calculator.dart` | 4 — `_calculateCAGR` |
| `apps/mobile/lib/services/financial_report_service.dart` | 4 — `_calculateAvsGaps`, `_calculateSpouseAvsGaps` (DUPLICATES `circle_scoring_service.dart`) |
| `apps/mobile/lib/services/wizard_service.dart` | 2 — `_calculateDebtRatio` |
| `apps/mobile/lib/services/unemployment_service.dart` | 2 — `_calculateDuration` |
| `apps/mobile/lib/services/tax_estimator_service.dart` | 2 — `_calculateFromScales` (DUPLICATES backend `cantonal_comparator._calculate_federal_tax`) |
| `apps/mobile/lib/services/first_job_service.dart` | 2 — `_calculateFranchiseOptions` |
| `apps/mobile/lib/services/tax_scales_loader.dart` | 1 (helper, OK) |
| `apps/mobile/lib/widgets/interactive_simulations.dart` | 1 — `_calculateFutureValue` (compound-interest, also in `widgets/simulation_widgets.dart`) |
| `apps/mobile/lib/widgets/simulation_widgets.dart` | 1 — `_calculateFutureValue` (DUPLICATE of above) |

#### Backend (`_calculate*` outside any single source-of-truth)

**33 occurrences across 11 files:**

| File | Notable methods |
|---|---|
| `services/backend/app/services/document_parser/lpp_certificate_parser.py:528` | `_calculate_overall_confidence` (also in `tax_declaration_parser.py:356` and `avs_extract_parser.py:484`) — **3-way duplicate** |
| `services/backend/app/services/arbitrage/{rachat_vs_marche,rente_vs_capital,location_vs_propriete}.py` | All three define their own `_calculate_breakeven` — **3-way duplicate**, identical signatures |
| `services/backend/app/services/fiscal/cantonal_comparator.py:444` | `_calculate_federal_tax` — re-implements progressive-bracket math instead of importing from `app.constants.social_insurance` (which itself contains the **anti-duplication warning** at line 368: « Do NOT create local _calculate_progressive_tax() copies. ») |
| `services/backend/app/services/expat/frontalier_service.py:271` | `_calculate_source_tax_progressive` — yet another federal-tax variant |
| `services/backend/app/routes/wizard.py:231` | `_calculate_precision` (route-level, OK if routing-only) |

The **most damaging** is `cantonal_comparator._calculate_federal_tax` which violates the explicit warning written in the canonical constants file. That's a documented rule#4 break.

### Top 10 worst offenders

| File:Line | Issue |
|---|---|
| `services/backend/app/services/fiscal/cantonal_comparator.py:444` | `_calculate_federal_tax` — explicit-warning violation |
| `services/backend/app/services/expat/frontalier_service.py:271` | Third federal-tax implementation |
| `services/backend/app/services/arbitrage/rachat_vs_marche.py:177` | `_calculate_breakeven` (1/3) |
| `services/backend/app/services/arbitrage/rente_vs_capital.py:321` | `_calculate_breakeven` (2/3) |
| `services/backend/app/services/arbitrage/location_vs_propriete.py:226` | `_calculate_breakeven` (3/3) |
| `services/backend/app/services/document_parser/lpp_certificate_parser.py:528` | `_calculate_overall_confidence` (1/3) |
| `services/backend/app/services/document_parser/tax_declaration_parser.py:356` | Same (2/3) |
| `services/backend/app/services/document_parser/avs_extract_parser.py:484` | Same (3/3) |
| `apps/mobile/lib/services/financial_report_service.dart:210` | `_calculateAvsGaps` duplicates `circle_scoring_service.dart:490` |
| `apps/mobile/lib/widgets/simulation_widgets.dart:58` | `_calculateFutureValue` duplicates `interactive_simulations.dart:41` |

### Verdict

**Severity: HIGH** — this is the rule the project explicitly tells itself not to break, with an in-source warning that has been ignored.

**Estimated cleanup:** 24 h
- 8 h → backend: extract `compute_federal_progressive_tax(income, civil_status)` into `app.constants.social_insurance` and migrate 2 call sites; extract shared `compute_breakeven` helper into `services/arbitrage/_common.py` and migrate 3 sites; extract `compute_extraction_confidence` into `services/document_parser/_common.py` and migrate 3 sites.
- 12 h → mobile: move `_calculateAvsGaps` & spouse variant into `financial_core/avs_calculator.dart` and migrate 2 sites; consolidate `_calculateFutureValue` into `financial_core/cross_pillar_calculator.dart` (existing) and migrate 2 widget sites; review `tax_estimator_service` against `tax_calculator.dart`.
- 4 h → write a check `tools/checks/no_calc_outside_core.py` that enforces this going forward.

---

## Category 5 — Hardcoded user-facing strings (rule #5)

### Findings

`tools/checks/no_hardcoded_fr.py` — currently **NOT wired in lefthook or CI** (see Cat. 8) — flags **4 994 violations**.

A spot-check of the first 50 hits shows:
- ~30% are dead-code Dart comments containing French illustrative copy (e.g. `// Compare vs meilleur fintech au meme profil de risque`). Annoying, but invisible to users. Lint heuristic `IGNORE_MARKERS` could be tightened to skip pure comments.
- ~50% are real user-facing strings (e.g. `apps/mobile/lib/widgets/precision/field_help_tooltip.dart:47` — `label: 'Aide pour ce champ',` shipped to screen-readers).
- ~20% are dev/dart-doc strings (also comments).

Even if 50% are noise, **2 500 real ARB-extraction tickets** is still the largest piece of pure surface debt in the codebase.

### Top 20 offending files (highest hit density first)

| File | Approx. hits |
|---|---|
| `apps/mobile/lib/widgets/precision/smart_default_indicator.dart` | 6 |
| `apps/mobile/lib/widgets/precision/field_help_tooltip.dart` | 3 |
| `apps/mobile/lib/widgets/precision/precision_prompt_card.dart` | 2 |
| `apps/mobile/lib/widgets/coach/early_retirement_comparison.dart` | many |
| `apps/mobile/lib/widgets/coach/divorce_film_widget.dart` | many |
| `apps/mobile/lib/widgets/budget/stop_rule_callout.dart` | 1 (rules-engine literal copy) |
| `apps/mobile/lib/widgets/onboarding/onboarding_widgets.dart:319,352` | « Voici ce que ton coach a déduit » |
| `apps/mobile/lib/widgets/text/jargon_text.dart:8` | dartdoc example FR copy |
| `apps/mobile/lib/widgets/report/retirement_projection_card.dart:148` | « Chaque année manquante = -2.3% de rente à vie. » |
| `apps/mobile/lib/widgets/premium/mint_count_up.dart:33-34` | dartdoc example FR copy |
| `apps/mobile/lib/widgets/premium/mint_ligne.dart:11` | dartdoc with French aphorism |
| `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart` | many |
| `apps/mobile/lib/screens/expat_screen.dart` | many |
| `apps/mobile/lib/screens/coach/coach_chat_screen.dart` | many (some are intentional per `// accent_lint_fr / no_hardcoded_fr lints don't regress` exemption comment) |
| `apps/mobile/lib/screens/admin/*` | exempt by design (« Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/** ») |
| `apps/mobile/lib/services/coaching_service.dart:299` | LLM system-prompt literal (NOT user-facing — false positive) |
| `apps/mobile/lib/services/coach_narrative_service.dart:896` | LLM system-prompt literal |
| `apps/mobile/lib/services/coach/prompt_registry.dart:107,313` | Same |
| `apps/mobile/lib/services/agent/autonomous_agent_service.dart:870` | LLM tool description |
| `apps/mobile/lib/services/llm/response_quality_monitor.dart:50` | banned-term registry |

### Verdict

**Severity: BLOCKER** for journalist-defensible launch (every hardcoded FR string blocks DE/IT/EN parity). The hits in `widgets/precision/*` are particularly bad — accessibility labels (`label: 'Aide pour ce champ'`) bypass the screen-reader stack entirely for non-FR users.

**Estimated cleanup:** 60 h
- 8 h → tighten `no_hardcoded_fr.py` to exempt `///` dartdocs, multiline-string LLM prompts, and `lib/services/coach/*` registries → expected reduction to ~2500 real violations.
- 16 h → wire the lint into CI as a hard gate at threshold = current count, ratchet down with each PR (preventing regression while real cleanup happens).
- 36 h → karpathy-style extraction loop (use `/autoresearch-i18n` skill, runs ARB extraction → genl10n verify → repeat).

---

## Category 6 — Hardcoded colors (rule #2)

### Findings

- **`Color(0xFF…)` outside `lib/theme/`:** **2 hits**, both in the same file:
  - `apps/mobile/lib/widgets/consent/policy_diff_view.dart:88` — `? const Color(0xFFE8F5E9) // soft green`
  - `apps/mobile/lib/widgets/consent/policy_diff_view.dart:89` — `: const Color(0xFFFFEBEE); // soft red`
- **`Color(0x…)` total outside theme:** 2 (same as above; no transparent-hex hits).
- **Raw `Colors.<name>` (Material) outside theme, in user-facing widgets/screens:** **0** (the earlier high count was inflated by `MintColors.purple` etc. — token references, not raw Material).
- **One stale flag:** `apps/mobile/lib/app.dart:1788` — `color: Colors.red` inside a global error widget. Acceptable for a hard-error screen but should arguably move to `MintColors.error`.

### Verdict

**Severity: LOW.** The rule is essentially clean. Two diff-view soft tones can be lifted into `MintColors.successSurface` / `MintColors.errorSurface` in 15 minutes.

**Estimated cleanup:** 0.25 h.

---

## Category 7 — Banned LSFin terms in product code (rule #1)

### Findings

The literal token search returns **171 hits** for `garanti|optimal|meilleur|certain|assur(é|e)|sans risque|parfait` in `apps/mobile/lib/`. **Almost all** are:

- compliance-guard registries (`compliance_guard.dart`, `coaching_service.dart`, `response_quality_monitor.dart`),
- LSFin-rule docstrings (`// No banned terms ("garanti", …)`),
- legal terminology that is **specifically allowed** because it's the Swiss legal term: `gain assuré` (LACI art. 22), `revenus garantis` (AVS/LPP context).

### Real risks (user-facing or API-surface, not a docstring or guard list)

| File:Line | Issue |
|---|---|
| `services/backend/app/schemas/retirement.py:250-254` | Field `revenus_garantis` and description « Revenus garantis mensuels par source ». Backend API surface. The neighboring field's description correctly says « Ce n'est pas un revenu garanti », so the schema author IS aware of the rule but split the framing inconsistently. **Will leak through OpenAPI / generated Dart contract** if not caught. |
| `services/backend/app/api/v1/endpoints/documents.py:217` | Inside an LLM system prompt: `INTERDICTIONS : Pas de 'garanti', 'optimal', 'meilleur'…`. Legitimate (it's an instruction). |
| `apps/mobile/lib/services/circle_scoring_service.dart:187` | `lppStatus = ItemStatus.perfect; // Pas de lacune = parfait` — `perfect` is an enum value, not user copy. OK. |

### Verdict

**Severity: MEDIUM.** Only one substantive hit (`schemas/retirement.py`) and it's API-internal. But that schema is consumed by the mobile through OpenAPI codegen (`tools/openapi/`), so the field name `revenus_garantis` may surface in generated code or be displayed verbatim.

The mobile-side `compliance_guard.dart` is a healthy safety net (37 lines of banned-term list + replacements + regex-based detector). It SHOULD be exercised as part of CI.

**Estimated cleanup:** 1 h
- Rename `revenus_garantis` → `revenus_periodiques_avs_lpp` in the retirement schema; regenerate OpenAPI; bump consumer in mobile.
- Update the field description to drop « garantis ».

---

## Category 8 — Tools/checks not wired in lefthook OR CI

### Findings

`tools/checks/` contains **27 scripts**. CI (`.github/workflows/ci.yml`) wires **15** of them. Lefthook wires **2** (memory_retention.py + map_freshness_hint.py). Some checks are wired only in `tools/ship_gate/run_all_gates_v2_2.sh` (manual `/ship` workflow), which is **not** automatic.

### Wired in CI (`.github/workflows/ci.yml`)

`flesch_kincaid_fr.dart`, `landing_no_financial_core.py`, `landing_no_numbers.py`, `no_chiffre_choc.py`, `no_e2ee_overclaim.py`, `no_implicit_bloom_strategy.py`, `no_legacy_confidence_render.py`, `no_llm_alert.py`, `regional_microcopy_drift.py`, `route_registry_parity.py`, `screen_registry_parity.py`, `screen_registry_three_way_parity.py`, `sentence_subject_arb_lint.py`, `wcag_aa_all_touched.py` (+ `lefthook_self_test.sh` for the harness).

### Wired in lefthook

`memory_retention.py`, `map_freshness_hint.py`.

### Wired in `ship_gate/run_all_gates_v2_2.sh` (manual only)

`s0_s5_aaa_only.py` — accessibility AAA gate.

### **NOT wired anywhere automatic — surface debt**

| Script | What it enforces | Why it's debt |
|---|---|---|
| `tools/checks/no_hardcoded_fr.py` | Hardcoded French strings outside ARB | **Critical** — see Cat. 5 (4 994 violations). Lefthook header literally says « Phase 34 GUARD-01 will ADD … hardcoded_fr ». Phase 34 has not happened. |
| `tools/checks/accent_lint_fr.py` | French-accent ASCII corruption | Critical per CLAUDE.md TOP-RULE-2. Memory `f97e3c07 fix(lsfin): auto-fix 228 accent violations` shows this happens regularly and is caught **after** the fact. |
| `tools/checks/accent_lint_fr_autofix.py` | Auto-fix companion | Same |
| `tools/checks/no_legal_admission_in_public_docs.py` | Forensic / panic legal language in committed `.md` | PR #425 added the script with a commit message saying « ci: lint forensic », but **no workflow file references it**. The CI hook was never wired. |
| `tools/checks/claude_md_bracket.py` | CLAUDE.md schema sanity | Process-only, not source-code |
| `tools/checks/claude_md_triplets.py` | CLAUDE.md triplet structure | Process-only |
| `tools/checks/sentry_capture_single_source.py` | Sentry capture single-source pattern | Wired via `agent-drift/ingest_git.py` only — not pre-commit |
| `tools/checks/verify_sentry_init.py` | Sentry init present | Same |
| `tools/checks/audit_artefact_shape.py` | Phase artefact structure | Process-only |
| `tools/checks/s0_s5_aaa_only.py` | Strict AAA contrast on S0–S5 surfaces | Wired in ship_gate manual run only — **NOT pre-commit** |
| `tools/checks/no_e2ee_overclaim.py` | E2EE truth-in-crypto guard | ✅ wired in CI (correction: it IS in ci.yml; double-check yields it's there) |

(Re-validated after closer reading: 9 of 27 scripts truly unwired in any auto-trigger.)

### Verdict

**Severity: HIGH.** The codebase has **invented the lints** but never **flipped the gate**. This is the most pernicious form of surface debt: the appearance of safety. `f97e3c07` (228 accent violations auto-fixed in one commit) is the postmortem proving the gate would have caught them.

The lefthook config admits this in its own header: « Phase 34 GUARD-01 will ADD bare_catch, hardcoded_fr, accent_lint, arb_parity ». Phase 34 has not started. Phases 30.x → 54 advanced past it.

### Top 5 highest-leverage wirings

| Script | Action | Severity blocked |
|---|---|---|
| `accent_lint_fr.py` | Add to lefthook pre-commit + CI; auto-fix in pre-commit | BLOCKER (catches 228-at-a-time accent regressions) |
| `no_hardcoded_fr.py` | Add to CI as ratchet (current 4 994 = baseline; fail if increased) | BLOCKER (i18n parity) |
| `no_legal_admission_in_public_docs.py` | Wire to CI for `.md` paths (the script is ready) | HIGH (public-repo discipline) |
| `s0_s5_aaa_only.py` | Promote from ship_gate manual to CI | HIGH (a11y AAA) |
| `verify_sentry_init.py` + `sentry_capture_single_source.py` | Wire to CI for `apps/mobile/lib/services/sentry/**` paths | MEDIUM (observability) |

**Estimated cleanup:** 3 h
- 2 h → write a `lints` job in `.github/workflows/ci.yml` that runs the 5 above with appropriate `paths:` filters.
- 1 h → add `accent_lint_fr.py --autofix` to lefthook pre-commit (use the existing `accent_lint_fr_autofix.py`).

---

## Category 9 — TODO / FIXME / HACK density hotspots

### Findings

- **Total in `apps/mobile/lib/`:** 34 markers (incl. l10n decorative `XXX` like `756.XXXX.XXXX.XX` placeholders for AVS numbers — false positives).
- **Total in `services/backend/app/`:** 7 markers.
- Real `TODO()` / `TODO(P2)` density is low.

### Top per-directory

| Directory | Real TODO/FIXME/HACK count |
|---|---|
| `apps/mobile/lib/services/` | 8 (3 in coaching/profile providers `TODO(P2)`, 2 in `coach/`, 1 each in misc) |
| `apps/mobile/lib/widgets/` | 5 (2 in `precision/`, 1 in `text/`, 1 in `report/`, 1 in `mentor_fab.dart`) |
| `apps/mobile/lib/screens/admin/` | 3 (Phase 34 lint exemption notes — informational) |
| `apps/mobile/lib/screens/document_scan/` | 2 (P2-W12 EXIF strip — security hardening) |
| `services/backend/app/services/retirement/` | 1 (LAVS art. 29quinquies income-splitting model gap — financial accuracy) |
| `services/backend/app/api/v1/endpoints/coach_chat.py:2144` | 1 — TODO(billing): re-enable entitlement gate when billing live |
| `services/backend/app/api/v1/endpoints/reengagement.py:138` | 1 — « TODO: wire SQLAlchemy session » in feature-flagged path |
| `services/backend/app/models/document.py:1` | 1 — TODO(deferred-pre-launch): unencrypted SQLite |

### Notable individual findings

- **`services/backend/app/models/document.py:1`** — « Database is currently unencrypted SQLite. » TODO(deferred-pre-launch). **Pre-launch privacy assertion.**
- **`apps/mobile/lib/screens/document_scan/document_scan_screen.dart:683 & 1550`** — TWO copies of `// TODO(P2-W12): Strip EXIF metadata before Vision API call.` PII risk if the Vision API call carries device-EXIF (geo-coords).
- **`services/backend/app/services/retirement/avs_estimation_service.py:165`** — LAVS art. 29quinquies income-splitting during marriage not yet modeled. Affects every couple AVS projection.

### Verdict

**Severity: LOW** for volume, but the **3 individual items above are MEDIUM/HIGH product risk.**

**Estimated cleanup:** out of scope for « surface debt »; track these in `gsd-add-todo` queue.

---

## Category 10 — Phase deferred items still open

### Findings

Active deferral markers (after filtering verification logs and historic decisions): **23 substantive open items** across active Phase 53-54 plans + carryovers from earlier phases.

### Top 15 unresolved deferrals

| Phase | File | Deferred item |
|---|---|---|
| 54 | `54-CONTEXT.md:108` | Chat Vivant scene injection → Phase 55 |
| 54 | `54-CONTEXT.md:109` | Activate the 9 unactivated `SequenceTemplate`s beyond `retirement_prep` → Phase 55 |
| 54 | `54-CONTEXT.md:110` | Android build pipeline + GATE-02 → Phase 55 |
| 54 | `54-CONTEXT.md:111` | Production App Store submission → post-TestFlight beta |
| 54 | `54-CONTEXT.md:112` | Performance / cold-start tuning → separate phase |
| 53 | `53-CONTEXT.md:93` | Chat-vivant scene injection (`MintSceneRachatLPP`, `MintInlineInsightCard`, `ChatProjectionService`) → Phase 54 |
| 53 | `53-CONTEXT.md:94` | Doc scan confidence UX → Phase 55+ |
| 53 | `53-CONTEXT.md:95` | AVS / Open Banking / Swiss e-ID integration → v2.13+ |
| 53 | `53-CONTEXT.md:97` | Orphan-route cleanup → Phase 55+ (registry only documents) |
| 53 | `53-CONTEXT.md:98` | BYOK copy audit → Phase 55+ if surface still routable |
| 53-01 | `53-01-PLAN.md:123` | Orphan-route DELETION (the COVERAGE.md cohort) → Phase 55+ |
| 53-01 | `53-01-PLAN.md:126` | Doc scan confidence UX → Phase 55+ |
| 31-04 | `31-04-SUMMARY.md:168` | Live quota smoke (Sentry) — DEFERRED pending KEYCHAIN provisioning |
| 31-04 | `31-04-SUMMARY.md:174` | TRACE_PROPAGATION_TEST.md → optional polish |
| 31-04 | `31-04-SUMMARY.md:180` | Pace-heuristic WARN branch coverage → Phase 35 nightly |
| 31-03 | `31-03-SUMMARY.md:191` | Physical-device walkthrough Sentry — non-blocking |

### Verdict

**Severity: MEDIUM.** Not surface debt per se — explicit, documented deferrals with phase pointers. The risk pattern is **deferral creep**: « Phase 55+ » is mentioned 6 times across Phase 53 and 5 times across Phase 54 with no Phase 55 plan opened yet. This matches the memory `feedback_session_projection_vs_roadmap.md` warning that « next steps lists are projections, not roadmap commitments ».

**Estimated cleanup:** n/a (process). Action: when Phase 54 closes, the post-phase panel should explicitly inventory the « → Phase 55+ » carry-overs and decide which become Phase 55 plans vs which are dropped. Don't let « 55+ » become an indefinite parking lot.

---

## Category 11 — Recent CI/test failure pattern

### Findings

- **Last 50 commits:** 13 fix : 21 feat : 13 docs : 1 chore. **Fix:feature ratio = 0.62.**
- **Last 200 commits:** 50 fix : 71 feat. **Ratio = 0.70.**
- **Last 30 days:** 207 fix : 180 feat : 273 docs : 6 ci. **Ratio = 1.15** — fixes outpaced features over the month, mostly due to lint-cleanup waves (e.g. `f97e3c07 fix(lsfin): auto-fix 228 accent violations` sweeping multiple files in one go).

### PR #439 (mentioned in memory `feedback_pre_push_checklist.md` as 4 CI cycles)

PR #439 = `feat(phase-52.1): chat persistence_consent flag (mobile + backend) — closes B-3`. Local-branch history of the lead-up commits:

- `a5c851da feat(phase-52.1): chat persistence_consent flag (mobile + backend)`
- `3a511eeb fix(phase-52.1): shrink WRITE-tier whitelist + propagate persistence_consent`
- `5bd1ce93 fix(phase-52.1): patch missed _execute_internal_tool callsite in overview test`
- `061dc90c feat(phase-52.1): chat persistence_consent flag (mobile + backend) — closes B-3 (#439)`

The pattern matches the memory perfectly: a feature-add commit, then 2 fix-up commits to chase down callers (`_execute_internal_tool`) and tier-whitelist propagation that the original commit missed. The memory's prescription (« grep all callers + regenerate canonical OpenAPI + run full test before push ») would have collapsed this into one commit.

Phase 52 (with sub-phases 52.1, 52.2, 52.3, 52.4) shipped **3 fix(phase-52.x) commits** for missed scope: `25175116 close T-52-08 audit BLOCK — 3 missed write-tier handlers`, `248ab91e truth-in-crypto sweep — false E2EE claim at doc-scan auth gate`, `04a1a16d vault-metaphor truth sweep — close Phase 52.3 lint scope gap`. Each is a real bug missed at PR-merge time and caught by post-merge audit.

### Verdict

**Severity: MEDIUM.** The fix:feature ratio is healthy but a meaningful share of the « fix » volume is **post-PR scope-completion** rather than bug-discovery. The Phase 52.x cascade (every sub-phase needing a fix-PR within days of merge) is the prototype.

**Structural fix:** wire the Pre-push checklist (`feedback_pre_push_checklist.md`) as a literal check — see Structural Fix #2 below.

---

## Surface-debt score

| Category | Weight | Raw | Score (raw × weight, clipped to 100) |
|---|---|---|---|
| 1 — Façade | 5 | 0 | 0 |
| 2 — Orphan screens | 3 | 1 | 3 |
| 3 — Tests-don't-test | 8 | 13 | **8** (capped) |
| 4 — Calc duplication | 8 | 11 critical | **8** |
| 5 — Hardcoded FR | 10 | 4 994 / 4 994 | **10** |
| 6 — Hardcoded colors | 5 | 2 | 0 |
| 7 — Banned terms | 6 | 1 substantive | 1 |
| 8 — Unwired lints | 9 | 9 / 27 | **6** |
| 9 — TODO density | 2 | 30 | 1 |
| 10 — Deferred items | 4 | 23 | 2 |
| 11 — Fix:feature | 4 | 0.70 | 2 |

**TOTAL: 41 / 100** (lower is better). Cleanly below the 50 threshold, dominated by Cat 5 (i18n) and Cat 4 (duplicate calculators).

For comparison: a hypothetical « clean » repo would score < 15. The W14 trauma cleared the worst (Façade, Colors). The remaining debt is **content + tooling** debt, the slowest-bleeding kind.

---

## TOP 10 SINGLE FIXES (Pareto: max lucidity / min hours)

### Fix 1 — Wire `accent_lint_fr.py` into lefthook pre-commit (autofix mode)
- **Where:** `lefthook.yml` (add a `commands.accent-lint` block running `tools/checks/accent_lint_fr_autofix.py`).
- **Why:** Phase header in `lefthook.yml` already promises this. Memory `f97e3c07` shows 228 violations slipped in. Auto-fix mode is non-blocking ergonomics.
- **Cost:** 0.5 h.

### Fix 2 — Wire `no_hardcoded_fr.py` into CI as a ratchet
- **Where:** new `lints` job in `.github/workflows/ci.yml`. Compare against snapshot baseline `tools/checks/no_hardcoded_fr.baseline` (commit it). Fail if `current > baseline`. Allow drop, never increase.
- **Why:** Stops the 4 994 number from growing while real cleanup happens.
- **Cost:** 1 h.

### Fix 3 — Delete `apps/mobile/lib/screens/document_scan/document_stream_result_screen.dart`
- **Where:** `git rm` + corresponding test (none found).
- **Why:** Verified W14 leftover, zero references.
- **Cost:** 5 min + screen_registry_parity test re-run.

### Fix 4 — Convert 3 `expect(true, isTrue)` placeholders into real tests
- **Where:** `apps/mobile/test/providers/auth_provider_test.dart:161-173`.
- **Why:** Documented intent (« error mapping covers network errors / duplicate email / wrong credentials »); the mapping function exists at `apps/mobile/lib/providers/auth_provider.dart`. Drop-in tests possible.
- **Cost:** 1 h.

### Fix 5 — Un-skip 5 `coach_chat_test.dart` tests + fix what they reveal
- **Where:** `apps/mobile/test/screens/coach/coach_chat_test.dart:226,251,290,313,404`.
- **Why:** Coach chat is the heart of the product. Currently 5 untested behaviors silent-pass.
- **Cost:** 2 h (some will reveal real bugs — that's the point).

### Fix 6 — Wire `no_legal_admission_in_public_docs.py` to CI
- **Where:** new `paths-filter` job for `**/*.md` in `.github/workflows/ci.yml`.
- **Why:** Public-repo discipline (memory `feedback_public_repo_discipline.md`). Script exists, ungated since PR #425 landed.
- **Cost:** 30 min.

### Fix 7 — Rename `revenus_garantis` field in `services/backend/app/schemas/retirement.py`
- **Where:** `services/backend/app/schemas/retirement.py:250-257`. Regenerate OpenAPI. Update Dart consumer.
- **Why:** API field name leaks LSFin-banned framing into generated code.
- **Cost:** 1 h.

### Fix 8 — Consolidate 3-way `_calculate_breakeven` duplicate in `services/arbitrage/`
- **Where:** Extract to `services/backend/app/services/arbitrage/_common.py`. Migrate `rachat_vs_marche.py:177`, `rente_vs_capital.py:321`, `location_vs_propriete.py:226`.
- **Why:** 3 identical signatures; mathematical drift inevitable as one branch evolves.
- **Cost:** 2 h.

### Fix 9 — Migrate `cantonal_comparator._calculate_federal_tax` into `app.constants.social_insurance`
- **Where:** Honor the existing in-source warning at `services/backend/app/constants/social_insurance.py:368`. Move from `services/backend/app/services/fiscal/cantonal_comparator.py:444` and `services/backend/app/services/expat/frontalier_service.py:271`.
- **Why:** The constants file literally tells you not to do this. Two files do it.
- **Cost:** 3 h.

### Fix 10 — Wire `s0_s5_aaa_only.py` into CI (currently manual ship_gate only)
- **Where:** `.github/workflows/ci.yml` lints job.
- **Why:** AAA contrast is the project's published a11y promise. Manual ship_gate is not a promise.
- **Cost:** 30 min.

**Pareto total: ~12 h to neutralize 60-70% of the substantive debt surface.**

---

## 3 STRUCTURAL FIXES (prevent regression of top categories)

### Structural #1 — Promote ALL critical lints from « scripted but ungated » to « CI-enforced »

**Symptom this kills:** Cat. 8 (9 of 27 lints unwired). Cat. 5 (i18n drift). Cat. 7 (banned-term creep).

**Action:**
1. Audit `tools/checks/` quarterly. Every lint must have ONE of three states:
   - `enforced-ci` — referenced in `.github/workflows/ci.yml` with a `paths:` filter.
   - `enforced-pre-commit` — referenced in `lefthook.yml`.
   - `manual-only` — explicit `<!-- LINT-MANUAL-ONLY: reason -->` comment in the script, with sign-off in `tools/checks/STATUS.md`.
2. Create `tools/checks/STATUS.md` listing every lint and its state. CI fails if a lint exists in `tools/checks/` without an entry.
3. The lefthook header comment « Phase 34 GUARD-01 will ADD … » becomes a forcing function: open Phase 34 GUARD-01 NOW, even as a degraded « warning-only » version.

**Cost:** 4 h initial + 30 min/quarter.

### Structural #2 — Pre-push gate for « function signature change » + « schema field change »

**Symptom this kills:** Cat. 11 (Phase 52.x fix-PR cascade). PR #439 4-cycle pattern.

**Action:** new `tools/checks/signature_change_callers_audit.py` invoked by lefthook pre-push (not pre-commit — too slow). On staged diff:
- For each modified function in `services/backend/app/**/*.py`, grep the rest of the codebase for `<func>(` callers and require the diff also touches them OR contains a `// signature-change-OK: <reason>` comment.
- For each modified Pydantic field in `services/backend/app/schemas/**`, require `tools/openapi/generate_canonical.py` to have been run (check sha of generated artifact).
- For each new key in `apps/mobile/lib/l10n/app_fr.arb`, require all 6 ARB files updated (or `flutter gen-l10n` re-run).

This is the literal codification of memory `feedback_pre_push_checklist.md`.

**Cost:** 6 h to write + tune.

### Structural #3 — `no_calc_outside_core.py` lint enforcing rule #4

**Symptom this kills:** Cat. 4 (calculator duplication). The 11 backend + 9 mobile duplicates didn't just appear — they accreted because nothing prevents them.

**Action:** new `tools/checks/no_calc_outside_core.py`:
- Mobile: any `_calculate*` or `_calc[A-Z]*` method outside `apps/mobile/lib/services/financial_core/**` is a violation, unless the file declares `// calc-allowed: <reason>` on the line above.
- Backend: any function `def _calculate*(...) -> float|int|Decimal` outside `services/backend/app/services/financial_core/**` (or new central `app.constants.social_insurance`) is a violation under the same rule.
- Ship with the current 28 + 33 hits as `STATUS.md`-tracked exemptions; ratchet down to 0.

**Cost:** 4 h.

---

## Appendix A — Methodology

All counts produced via `grep -rEn` / `find` on the working tree at HEAD `4f863357 fix(anonymous-chat): MINT bubbles render markdown italic + bold`. Lints run via:
- `python3 tools/checks/no_hardcoded_fr.py` → 4 994 violations, exit 1.
- `python3 tools/checks/screen_registry_parity.py` → 125 OK after exemptions, exit 0.
- `python3 tools/checks/route_registry_parity.py` → 145 OK after exemptions, exit 0.

Phase deferral inventory restricted to `.planning/phases/{30.x, 31, 32, 52.1, 53, 54}/**/*.md` after filtering verification-log noise.

Commit churn measured against `git log --oneline` for windows of 50 / 200 commits and `--since=30 days ago`.

## Appendix B — What this audit does NOT cover

- **Backend test coverage gaps** (Cat. 3 only sampled mobile + spot-checked backend). A full coverage report would need `pytest --cov`.
- **Performance / cold-start budgets.** Out of scope per request.
- **Compliance content audit** (LSFin wording across ARB strings) — only the literal banned-token grep was done; semantic compliance (e.g. promise-form sentences) needs `compliance_guard.dart` runtime trace, not grep.
- **Walker FAIL evidence** from Phase 54-01 (`AUDIT_TAP_RENDER_RESULTS.md` doesn't exist on this branch yet).
- **Sentry breadcrumb coverage on the 43 redirect call-sites** — Phase 32 plan tracks; not re-audited here.

---

## Appendix C — Single-line reproductions

For each finding, paste these exactly into a fresh shell to reproduce:

```bash
# Cat. 1 — empty callbacks
grep -rEn "(onTap|onPressed):\s*\(\)\s*\{\s*\}" apps/mobile/lib/ --include="*.dart"

# Cat. 2 — orphan screens (look for no_app_ctor entries)
while read cls; do n=$(grep -rwE "\b$cls\(" apps/mobile/lib/app.dart 2>/dev/null | wc -l); if [ "$n" -eq 0 ]; then echo "no_app_ctor: $cls"; fi; done < <(grep -hE "^class [A-Z]\w+Screen\b" apps/mobile/lib/screens/ -r --include="*.dart" | sed -E 's/^class ([A-Z][A-Za-z0-9_]+).*/\1/' | sort -u)

# Cat. 3 — tautologies and skips
grep -rEn "expect\(true,\s*isTrue\)" apps/mobile/test/ services/backend/tests/
grep -rEn "skip:\s*true" apps/mobile/test/ --include="*.dart"

# Cat. 4 — calc methods outside core
grep -rEn "_calculate\w+|_calc[A-Z]\w+" apps/mobile/lib/services/ --include="*.dart" | grep -v "lib/services/financial_core/"
grep -rEn "_calculate\w+|_calc[A-Z]\w+" services/backend/app/ --include="*.py"

# Cat. 5 — hardcoded FR
python3 tools/checks/no_hardcoded_fr.py 2>&1 | tail -5

# Cat. 6 — hardcoded colors
grep -rEn "Color\(0x" apps/mobile/lib/ --include="*.dart" | grep -v "lib/theme/"

# Cat. 7 — banned terms in product code
grep -rEnwi "garanti" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ services/backend/app/schemas/ services/backend/app/api/ --include="*.dart" --include="*.py" | grep -vE "//|#"

# Cat. 8 — unwired lints
diff <(ls tools/checks/*.py tools/checks/*.dart tools/checks/*.sh 2>/dev/null | xargs -n1 basename | sort) <(grep -hE "tools/checks/" .github/workflows/*.yml lefthook.yml 2>/dev/null | sed -E 's|.*tools/checks/([a-zA-Z0-9_.-]+).*|\1|' | sort -u)

# Cat. 9 — TODO density
grep -rEn "TODO|FIXME|HACK|XXX" apps/mobile/lib/ services/backend/app/ --include="*.dart" --include="*.py" | grep -v "TODO(P3)" | awk -F: '{print $1}' | xargs -n1 dirname | sort | uniq -c | sort -rn | head -10

# Cat. 10 — phase deferrals
grep -rEn "DEFERRED|## Out of scope" .planning/phases/ --include="*.md" | grep -v "verification log"

# Cat. 11 — fix:feat ratio
echo "fix:$(git log --oneline -50 | grep -cE '^[a-f0-9]+ fix') feat:$(git log --oneline -50 | grep -cE '^[a-f0-9]+ feat')"
```

---

**End of audit. 41 / 100 surface-debt score. 12 hours of Pareto fixes documented above.**
