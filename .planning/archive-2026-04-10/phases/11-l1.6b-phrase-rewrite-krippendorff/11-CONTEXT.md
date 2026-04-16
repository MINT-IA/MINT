---
phase: 11-l1.6b-phrase-rewrite-krippendorff
type: context
requirements: [VOICE-04, VOICE-05, VOICE-06, VOICE-08, VOICE-09, VOICE-10, VOICE-14]
---

# Phase 11 — L1.6b Phrase Rewrite + Krippendorff Validation

## Goal
Rewrite the 30 most-used coach phrases to match `docs/VOICE_CURSOR_SPEC.md`, then statistically
prove tone-locking works via weighted ordinal Krippendorff α on a 15-tester panel blind-rating
the 50 frozen reference phrases. Ship N5 server-side hard gate + auto-fragility detector +
ARB `@meta level:` lint so editorial drift cannot recur.

This phase is the **empirical anti-shame gate**: if testers cannot reliably discriminate N4
from N5, MINT's voice is not actually tuned and Phase 12 cannot ship.

## Decisions (locked — NON-NEGOTIABLE)

### D-01 — 30-phrase mining strategy: usage-weighted, category-stratified
Mine candidates by usage count from `claude_coach_service.py` system prompt + few-shot bank
+ `apps/mobile/lib/l10n/app_fr.arb` (coach-scoped keys only: prefixes `coach*`, `chat*`,
`insight*`, greeting/fallback blocks). Rank by call-site frequency (grep consumers across
`apps/mobile/lib/**` + `services/backend/app/**`). Then **stratify by category** to guarantee
coverage: ≥4 greetings, ≥4 insight openers, ≥4 question formulations, ≥4 warnings/alerts,
≥4 validation/acknowledgement, ≥4 transitions, ≥4 closings, ≥2 error/fallback. Tie-breakers:
diversity of archetype usage, cross-language drift risk.

### D-02 — Tester pool: Phase 6 validator pool (3) + 12 new recruits = 15 total
Reuse the 3 native validators from Phase 6 (VS, ZH, TI — already NDA'd, already calibrated on
`docs/REGIONAL_VOICE_VALIDATORS.md` protocol, known-good blind-rating baseline). Recruit 12
additional testers: 6 French-speaking (VD/GE/NE/FR mix), 3 German-speaking (ZH/BE/LU mix),
3 Italian-speaking (TI). Target profile: Swiss residents 25-60, mixed financial literacy
(not finance pros), NO prior MINT exposure. Recruitment via personal network + Respondent.io
paid pool ($30/tester × 15 = $450 budget). **Recruitment starts Day 1 of Phase 11 execution
and runs in parallel with plans 01/03/04/05** — see scope concerns below.

### D-03 — Testing UI: static web form served from GitHub Pages (no backend)
Phase 11 testing does not justify a web app or Google Forms. Ship a single-file
`tools/krippendorff/rater_ui.html` (vanilla HTML/JS) that loads `frozen_phrases_v1.json` +
`reverse_test_phrases.json`, shuffles per-tester, collects N1-N5 rating + optional comment,
writes a JSON blob the tester emails/pastes back. Pros: zero backend, zero auth, zero PII
storage, works offline, deterministic blinding (per-tester seed). Published via GitHub Pages
or raw file URL.

### D-04 — Krippendorff bootstrap: N=1000 iterations, 95% CI
Use `tools/krippendorff/krippendorff_alpha.py` (Phase 2 tool) with weighted ordinal distance
(|i-j|²/(k-1)² for k=5 levels). Bootstrap resampling N=1000 over raters for 95% confidence
intervals. Gate on point estimate AND lower CI bound ≥ 0.60 (point ≥ 0.67) to avoid passing
on noisy samples. If tool lacks bootstrap, extend it in plan 05.

### D-05 — N5 hard gate location: `claude_coach_service.py` pre-send
Downgrade happens in `services/backend/app/services/coach/claude_coach_service.py` in the
post-generation / pre-ComplianceGuard hook (before the response leaves the backend). Read
`Profile.n5IssuedThisWeek` (already on Profile per CONTRACT-05/Phase 2). If counter ≥ 1 and
generated level == N5 → rewrite to N4 via deterministic template (not a re-LLM-call), log
`n5_downgraded` telemetry event, do NOT touch counter here (counter incremented only on
actual N5 send). Rolling window: purge entries > 7 days on every read.

### D-06 — Auto-fragility detector location: new `fragility_detector_service.py` consumed by coach
G2/G3 event counter lives on `Profile.fragileModeEnteredAt` (already on Profile per
CONTRACT-05) + a new rolling event log `Profile.recentGravityEvents: List[{ts, gravity}]`
(added as Phase 11 migration, rolling 30-day window). New service
`services/backend/app/services/coach/fragility_detector_service.py` exposes
`check_and_update(profile, new_event)` → bool (entered fragile mode this call).
Consumed by `claude_coach_service.py` before level selection. Disclosure string
`"MINT a remarqué…"` lives in ARB (6 languages), logged to biography via existing
`biography_service` append API.

### D-07 — `@meta level:` lint: extend existing `sentence_subject_arb_lint.py`
Do NOT create a new gate file. Extend the existing ARB lint in
`tools/checks/sentence_subject_arb_lint.py` with a second check pass that walks ARB keys
added/modified in the PR diff and requires an `@meta` sibling entry with a `level` field
∈ {N1,N2,N3,N4,N5}. Phase-11-existing keys grandfathered via an allowlist file
`tools/checks/arb_level_grandfather.txt` (generated once from pre-phase-11 ARB state).

### D-08 — ComplianceGuard adversarial extension lives in `tools/compliance/adversarial_n4_n5.json`
50 phrases split 25 N4 + 25 N5, each with: text, expected_level, expected_compliance_verdict
(pass/block), failure_category (imperative_no_hedge / banned_term_high_register /
prescription_drift / shame_vector / absolute_claim). Test file:
`services/backend/tests/compliance/test_adversarial_n4_n5.py` asserts 100% expected verdicts.
Red build on regression.

### D-09 — Reverse-Krippendorff trigger contexts: 10 synthetic sessions from `test/golden/`
Reuse Julien+Lauren golden fixtures to build 10 trigger contexts (mix: 3a gap, EPL question,
LPP split, expat FATCA, job loss, birth, mortgage capacity, divorce, inheritance,
cross-border). Each context forced to N4 via system prompt override in a one-shot script
`tools/krippendorff/reverse_generation_test.py`. Outputs `reverse_outputs_v1.json` → fed
into same tester UI as blind items. Pass gate: ≥ 7/10 classified N4 by majority vote.

### D-10 — Tester recruitment is PARALLEL, not blocking plan 01
Plan 01 (rewrite) + Plan 03 (N5 gate + fragility) + Plan 04 (ComplianceGuard) + Plan 05
(lint + runner) execute immediately. Plan 02 (recruitment + UI) kicks off Day 1 but its
"collect ratings" task is the long pole (2-3 weeks wall-clock). Phase 11 ship gate waits
on Plan 02 final task. All other plans finish in executor time; recruitment is wall-clock
bound.

## Deferred Ideas (NOT in Phase 11)
- Continuous tester panel (rolling monthly α checks) → Phase 12 or post-launch
- Multi-language Krippendorff (only FR rated in Phase 11; DE/IT rated in Phase 6 scope)
- Automated LLM-as-rater baseline comparison
- Public rater UI (Phase 11 is NDA-only)
- `voiceCursorPreference` UI surface → Phase 12
- Per-archetype phrase variants → Phase 13+

## Claude's Discretion
- Exact phrase-by-phrase rewrite wording (subject to 6 anti-shame checkpoints)
- File layout within `tools/krippendorff/` and `tools/compliance/`
- Telemetry event naming (follow existing conventions)
- Bootstrap implementation details if extending `krippendorff_alpha.py`

## Scope Concerns (explicit, for user visibility)

1. **Tester recruitment is the long pole.** 15 testers × blind rating × 50 phrases + 10
   reverse items ≈ 30-45 min/tester. Wall-clock realistic timeline: **2-3 weeks** from
   recruitment kickoff to usable α report, assuming Respondent.io paid pool. Phase 11
   code work (plans 01/03/04/05) completes in executor time (~1 day). Plan 02 is wall-clock
   blocked.

2. **If α < 0.67:** the spec itself may need revision (→ loop back to Phase 5), OR more
   few-shots in `claude_coach_service.py` system prompt. Build in 1-week contingency before
   declaring Phase 11 done.

3. **Reverse-Krippendorff ≥70%@N4 is the anti-tone-locking gate.** If Claude generates at
   system-prompt-requested N4 but testers rate outputs as N3 or N5, the system prompt is
   locked wrong. Fix = prompt revision + re-run (not re-rating), so this can iterate fast.

4. **Budget:** ~$450 tester fees + Phase 6 validator gratitude payment (already settled).

5. **Galaxy A14 / Phase 12 dependency:** N5 server gate + auto-fragility detector MUST land
   before Phase 12 "Ready for Humans" gate. This phase unblocks Phase 12.
