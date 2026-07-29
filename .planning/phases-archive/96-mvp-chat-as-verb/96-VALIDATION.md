---
phase: 96
slug: mvp-chat-as-verb
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-11
---

# Phase 96 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Drawn from 96-RESEARCH.md §Validation Architecture + 96-CONTEXT.md D-23..D-28 compliance gates + 96-UI-SPEC.md Maestro G1 contract.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (backend)** | pytest 8.x (Python 3.12) |
| **Framework (mobile)** | flutter test (Dart 3.x) + Maestro 2.5.1 (sim) |
| **Quick run command (backend)** | `cd services/backend && python3 -m pytest tests/test_chat_as_verb/ -q --tb=no` |
| **Full suite (backend)** | `cd services/backend && python3 -m pytest tests/ -q --ignore=tests/integration` |
| **Quick run (mobile)** | `cd apps/mobile && flutter test test/widgets/mint_card_action_bar_test.dart test/widgets/mint_chat_overlay_test.dart` |
| **Full mobile suite** | `cd apps/mobile && flutter analyze && flutter test` |
| **Maestro G1** | `bash tools/simulator/maestro_env.sh test tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml --format junit --output /tmp/maestro_96_g1.xml` |
| **ARB parity** | `python3 tools/checks/arb_parity_gate.py apps/mobile/lib/l10n/*.arb` exits 0 |
| **Estimated runtime** | ~120s full backend, ~90s full Flutter, ~30s Maestro |

---

## Sampling Rate

- **After every task commit:** Run task-specific quick command (backend OR Flutter scope)
- **After every plan wave:** Run full backend pytest + full Flutter test + ARB parity gate + accent_lint
- **Before `/gsd-verify-work`:** Full suites green + Maestro G1 exit 0 + Phase 95 byte-identity preserved (182/182 test_citation_gate + 74/74 test_dag_invalidation)
- **Max feedback latency:** ≤ 180s per wave close

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 96-01-01 | 01 | 1 | VERB-04 | T-96-W1-NavDrift | NavigationBar shows 3 tabs when flag false, 4 when true; goBranch index remap correct | widget | `cd apps/mobile && flutter test test/widgets/mint_shell_flag_gate_test.dart` | ❌ W0 | ⬜ pending |
| 96-01-02 | 01 | 1 | VERB-01 | T-96-W1-CardActionBarUI | MintCardActionBar reveals 48dp / 200ms easeOut with 3 verbs visible | widget | `cd apps/mobile && flutter test test/widgets/mint_card_action_bar_test.dart` | ❌ W0 | ⬜ pending |
| 96-01-03 | 01 | 1 | VERB-01, VERB-03 | — | « Explique-moi » + « Rassure-moi » open MintChatOverlay; « Simule » deep-links to Explorer | widget | `cd apps/mobile && flutter test test/widgets/mint_card_action_bar_routing_test.dart` | ❌ W0 | ⬜ pending |
| 96-01-04 | 01 | 1 | VERB-01 (ARB parity) | — | 3 new ARB keys present in all 6 locales | integration | `python3 tools/checks/arb_parity_gate.py apps/mobile/lib/l10n/*.arb` | ✅ (existing) | ⬜ pending |
| 96-01-05 | 01 | 1 | VERB-04 (FeatureFlags wiring) | — | FeatureFlags.chatTabVisible default true, server-override via /config/feature-flags | unit | `cd apps/mobile && flutter test test/services/feature_flags_chat_tab_test.dart` | ❌ W0 | ⬜ pending |
| 96-02-01 | 02 | 2 | (Phase 95 gate) | T-96-W2-Phase95Gate | Phase 95 W2 merge verified before Plan 96-02 starts | manual | grep -q "fb2b13aa\\|29bb08de" git log --oneline | ✅ | ⬜ pending |
| 96-02-02 | 02 | 2 | VERB-03 | T-96-W2-PIISmuggling | SerializedCardContext Pydantic v2 frozen+forbid validates; computed_facts contains no PII | unit | `cd services/backend && python3 -m pytest tests/test_chat_as_verb/test_serialized_card_context.py -q` | ❌ W0 | ⬜ pending |
| 96-02-03 | 02 | 2 | VERB-03 | — | source_card injection into narrator system prompt | unit | `cd services/backend && python3 -m pytest tests/test_chat_as_verb/test_narrator_source_card_block.py -q` | ❌ W0 | ⬜ pending |
| 96-02-04 | 02 | 2 | VERB-02, VERB-05 | T-96-W2-TurnCountTamper | turn_count enforced server-side; cap-hit returns terminal template + Sentry breadcrumb | unit | `cd services/backend && python3 -m pytest tests/test_chat_as_verb/test_turn_cap.py -q` | ❌ W0 | ⬜ pending |
| 96-02-05 | 02 | 2 | VERB-02 (terminal template) | — | turn 4 returns static FR template + Explorer deep-link, SKIPS LLM | unit | `cd services/backend && python3 -m pytest tests/test_chat_as_verb/test_terminal_template.py -q` | ❌ W0 | ⬜ pending |
| 96-02-06 | 02 | 2 | VERB-05 (instrumentation) | — | chat_overflow_turn_4 Sentry breadcrumb fires with non-PII payload (card_id + session_id only) | unit | `cd services/backend && python3 -m pytest tests/test_chat_as_verb/test_sentry_overflow_breadcrumb.py -q` | ❌ W0 | ⬜ pending |
| 96-03-01 | 03 | 3 | (W2 staging gate) | T-96-W3-StagingExercise | Staging deploy with turn_count flow exercised before W3 starts | manual | `railway status --service backend-staging` shows latest commit | ✅ | ⬜ pending |
| 96-03-02 | 03 | 3 | (NarrativeSleeve schema) | — | NarrativeSleeve Pydantic v2 frozen+forbid; 4 fields validate | unit | `cd services/backend && python3 -m pytest tests/test_chat_as_verb/test_narrative_sleeve_schema.py -q` | ❌ W0 | ⬜ pending |
| 96-03-03 | 03 | 3 | (hook digit-free linter) | T-96-W3-LinterDoS | response middleware swaps hook on `\d` match, NEVER raises | unit | `cd services/backend && python3 -m pytest tests/test_chat_as_verb/test_narrative_sleeve_lint.py -q` | ❌ W0 | ⬜ pending |
| 96-03-04 | 03 | 3 | (metaphor library v1) | T-96-W3-TOMLPoisoning | metaphors.toml loads, 6+ entries, mobile↔backend byte-equal | unit + integration | `cd services/backend && python3 -m pytest tests/test_chat_as_verb/test_metaphor_lookup.py -q` AND `python3 tools/checks/metaphor_parity.py` | ❌ W0 | ⬜ pending |
| 96-03-05 | 03 | 3 | VERB-06 (walkback path) | — | flag-toggle via /config/feature-flags reverts to 4-tab nav within periodic refresh window | integration | `cd apps/mobile && flutter test test/services/feature_flags_walkback_test.dart` | ❌ W0 | ⬜ pending |
| 96-03-06 | 03 | 3 | (G1 Maestro) | — | flow_card_action_intent_bar.yaml exits 0 on iPhone 17 Pro sim against staging | integration | `bash tools/simulator/maestro_env.sh test tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml --format junit` | ❌ W0 | ⬜ pending |
| 96-03-07 | 03 | 3 | (G2 Julien sim) | — | HUMAN-UAT — sim walkthrough by Julien on TestFlight build per CLAUDE.md §9 | human | persisted as 96-HUMAN-UAT.md after auto-verification | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · 👤 human-pending*

---

## Wave 0 Requirements

- [ ] `apps/mobile/lib/widgets/mint_card_action_bar.dart` — NEW widget (~80 LOC AnimatedSize + AnimatedOpacity)
- [ ] `apps/mobile/lib/widgets/mint_chat_overlay.dart` — NEW widget (~120 LOC modal scaffold)
- [ ] `apps/mobile/lib/services/feature_flags.dart` — extension : add `chatTabVisible` flag
- [ ] `apps/mobile/lib/widgets/mint_shell.dart` — flag-gated NavigationBar destinations
- [ ] `apps/mobile/lib/l10n/app_fr.arb` + 5 other locales — add `verbExplique`, `verbSimule`, `verbRassure`
- [ ] `apps/mobile/test/widgets/{mint_card_action_bar,mint_chat_overlay,mint_shell_flag_gate,mint_card_action_bar_routing}_test.dart` — 4 new test files
- [ ] `apps/mobile/test/services/feature_flags_chat_tab_test.dart` + `feature_flags_walkback_test.dart` — 2 new test files
- [ ] `apps/mobile/pubspec.yaml` — add `toml: ^0.16.0` dep
- [ ] `apps/mobile/assets/metaphors.toml` — 6-entry v1 bootstrap
- [ ] `services/backend/app/schemas/card_context.py` — `SerializedCardContext` Pydantic v2
- [ ] `services/backend/app/schemas/narrative_sleeve.py` — `NarrativeSleeve` Pydantic v2
- [ ] `services/backend/app/services/coach/metaphor_lookup.py` — mirror of Dart resolver
- [ ] `services/backend/app/services/coach/turn_cap.py` — in-memory `TURN_COUNTER` keyed by `(session_id, source_card_id)`
- [ ] `services/backend/app/services/coach/narrative_sleeve_lint.py` — response middleware hook linter
- [ ] `services/backend/tests/test_chat_as_verb/__init__.py` + `conftest.py`
- [ ] `services/backend/tests/test_chat_as_verb/test_{serialized_card_context,narrator_source_card_block,turn_cap,terminal_template,sentry_overflow_breadcrumb,narrative_sleeve_schema,narrative_sleeve_lint,metaphor_lookup}.py` — 8 new test files
- [ ] `tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml` — G1 Maestro flow
- [ ] `tools/checks/metaphor_parity.py` — mobile↔backend metaphor TOML byte-equality lint (registered in lefthook)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Phase 95 W2 merge gate before Plan 96-02 starts | T-96-W2-Phase95Gate | Cross-phase dependency; orchestrator-level | Verify commits `fb2b13aa..29bb08de` (Phase 95 W2) merged to current branch via `git log --oneline` |
| Staging deploy exercise before W3 starts | T-96-W3-StagingExercise | Requires Railway deploy + manual smoke | Push to staging; verify `chat_overflow_turn_4` breadcrumb fires when 4 turns sent on same card via curl |
| G2 Julien sim walkthrough on TestFlight | (CLAUDE.md §9 0-trust) | Real device, real eyes; no automation can substitute | Open card « Mon 3a 2026 » → tap « Explique-moi » → see MintChatOverlay → 3 turns → hit cap → terminal template + Explorer deep-link → verify visual quality |
| 7-day baseline `chat_turn_distribution` pull before flipping `chatTabVisible=false` to prod | D-11 (cap-hit instrumentation) | Requires real-user traffic + Sentry query | After staging soak, pull `chat_turn_distribution` Sentry metric over 7-day rolling window ; if >40% sessions hit turn 3+, defer the flag-flip and surface to Julien |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify OR Wave 0 dependencies OR are explicitly manual
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (manual gates count as boundaries)
- [ ] Wave 0 covers all MISSING references (17 W0 items listed)
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s per wave close
- [ ] `nyquist_compliant: true` set in frontmatter (toggle after planner reviews + W0 stubs land)

**Approval:** pending (planner agent will set `nyquist_compliant: true` once all W0 stubs are referenced in plan tasks)
