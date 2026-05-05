# Requirements: MINT v2.10 — Le Premier Éclairage (Cleo-grade)

**Defined:** 2026-05-05
**Roadmap:** 2026-05-04
**Core Value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, reçoit une réponse qui le surprend, crée un compte pour ne pas perdre ça.

## v2.10 Requirements (active scope)

Periphery serré : 4 surfaces utilisateur + 1 gate walker + hygiène repo. Pas plus.

### Landing v3 (éditorial)

- [ ] **LAND-01**: User opens MINT app and sees a single editorial hero phrase « L'argent, en clair. » in Fraunces serif italic.
- [ ] **LAND-02**: User reads sub-title « Ta Suisse financière, traduite. » in Inter Regular below the hero phrase.
- [ ] **LAND-03**: User sees the MINT wordmark in the top-left corner, sans-serif compact, no exaggerated letterSpacing.
- [ ] **LAND-04**: User taps a single primary CTA « Commencer → » styled as `RoundedRectangleBorder(14px)`, black ink, white text.
- [ ] **LAND-05**: User can tap a secondary link « Déjà là ? Se connecter » placed under the primary CTA.
- [ ] **LAND-06**: User sees a cream background (`MintColors.warmWhite` or `porcelaineHero`) with zero chrome (no card, no shadow, no decorative gradient).
- [ ] **LAND-07**: User tapping « Commencer » lands on `/anonymous/chat` ; tapping « Se connecter » lands on `/auth/login` with `?redirect=` preserved when applicable.

### Anonymous Chat (Cleo-grade)

- [ ] **ANON-01**: User does not see the legacy 6 felt-state pills (« Je paye, je signe, mais je comprends pas tout », etc.) — pills layer is removed entirely.
- [ ] **ANON-02**: User lands on a chat-first surface with empty input field and exactly one coach opener message visible.
- [ ] **ANON-03**: Coach opener is one short concrete question in Cleo voice (adult, clear, witty without joking) — no menu of phrases.
- [ ] **ANON-04**: Each user reply triggers at most one coach question per turn (no question stacking, no multi-bullet answers).
- [ ] **ANON-05**: Within 2-3 turns the coach delivers the Premier Éclairage insight payload (ECL-01).
- [ ] **ANON-06**: User killing the app and reopening within 7 days resumes the same conversation (PR-A AnonymousChatPersistence — already shipped via #480).
- [ ] **ANON-07**: User registering an account triggers `clear()` of the anonymous transcript (consent boundary — already shipped via #482).

### Premier Éclairage rendering

- [ ] **ECL-01**: Coach delivers a single insight as a hero card in chat with one CHF figure + one-line « pourquoi ça compte » + a soft account-creation hint.
- [ ] **ECL-02**: Account-creation hint renders as a tappable link (not a modal), copy = « Crée ton compte pour suivre ça » or equivalent that does not push.
- [ ] **ECL-03**: Backend prompt for the anonymous tier is `anonymous_eclairage_prompt.py` (already shipped via #481) — no other prompt is used in the anonymous path.
- [ ] **ECL-04**: Coach output contains zero LSFin banned terms (« garantit », « garantito », « optimal », « parfait », « certain », « assuré », « sans risque ») — verified via `check_banned_terms` MCP at request time.

### Walker E2E + golden (4 archetypes)

- [ ] **WALK-01**: `walker_audit_tap_render.sh --no-dry-run --archetype <X>` runs end-to-end on iPhone 17 simulator from cold-launch to ECL-01 insight render.
- [ ] **WALK-02**: Walker exit code is `0` for archetypes : `julien_swiss`, `lauren_expat_us`, `fatih_cross_border`, `sarah_indep_no_lpp`.
- [ ] **WALK-03**: Walker captures screenshots at four checkpoints — landing, anonymous_chat (after coach opener), ECL insight rendered, register CTA exposed.
- [ ] **WALK-04**: Visual diff vs locked landing mockup ≤ 4 % pixel difference in the hero zone on iPhone 17 viewport.
- [ ] **WALK-05**: Walker output archived in `.planning/walker/<run-id>/` where run-id = `YYYY-MM-DD-<git-sha-short>`.
- [ ] **WALK-06**: Per-archetype walker run completes in ≤ 120 s wall-clock on Mac mini.

### Compliance (LSFin + public-repo discipline)

- [ ] **COMP-01**: 0 banned terms across 6 ARB files (FR/EN/DE/IT/ES/PT), enforced by `tools/checks/banned_terms_arb.py` blocking in pre-commit lefthook.
- [ ] **COMP-02**: `tools/checks/no_legal_admission_in_public_docs.py` blocking in pre-commit lefthook (repo is public ; per Sprint 1 panel recommendation).

### Hygiene (release-blocker)

- [ ] **HYG-01**: PRs in flight #478, #479, #480, #481, #482 are merged or closed before TestFlight 2.10.0 cut. No PR left in « pending review » at ship.
- [ ] **HYG-02**: Phase 56 PRs (#470, #472) explicitly decided — merged into dev or closed as deferred-post-v2.10.
- [ ] **HYG-03**: PROJECT.md + STATE.md aligned on v2.10 (no mismatch between declared milestone and yaml-front-matter).
- [ ] **HYG-04**: 0 dirty worktrees with unstaged tracked changes at TestFlight cut. All worktrees either committed-or-removed.
- [ ] **HYG-05**: TestFlight 2.10.0 build visible in App Store Connect with attached walker run-id evidence.

## Out of Scope (anti scope-creep — explicit exclusions)

| Feature | Reason |
|---------|--------|
| Wiki coach v3 (per-user knowledge graph) | Post-TestFlight milestone ; ADR-20260503 referenced but not yet written. |
| Couple mode wiring (UI ↔ financial_core) | Data layer cracked ; 2-3 weeks of work to fix properly ; not on the v2.10 ship path. |
| FIX-03 save_fact `responseMeta.profileInvalidated` | Carry-forward — does not block the anonymous tier (no save_fact in anonymous chat). |
| FIX-04 Coach tab routing stale after chat-AI response | Carry-forward — only affects authenticated tier. |
| 388 bare-catches sweep (332 mobile + 56 backend) | Carry-forward to v2.11 ; observability tooling is wired (Sprint 0 #478) so the bleed is visible. |
| Coach chat full redesign (post-auth) | Out — only anonymous chat redesigned in v2.10. |
| Aujourd'hui / Dossier / Explorer redesign | Out — touched only via navigation parity, not visually redesigned. |
| Multi-step onboarding wedge (T9-style 8-step) | Out — chat-first replaces it ; T9 wedge stays in code as fallback but is not the v2.10 entry. |
| Banking API + LPP API integration | v3.0+ ; not in 2026 scope. |
| Vignettes / Scènes / Canvas (v2.9 doctrine) | Deferred — those phases (40-43) are NOT v2.10 ; revisited post-TestFlight. |
| BYOK (Bring Your Own Key) testing | Out per memory `project_byok_scope` ; ServerKey only for v2.10. |

## Traceability (filled by roadmap 2026-05-04)

| Requirement | Phase | Status |
|-------------|-------|--------|
| LAND-01 | 73 | Pending |
| LAND-02 | 73 | Pending |
| LAND-03 | 73 | Pending |
| LAND-04 | 73 | Pending |
| LAND-05 | 73 | Pending |
| LAND-06 | 73 | Pending |
| LAND-07 | 73 | Pending |
| ANON-01 | 71 | Pending |
| ANON-02 | 71 | Pending |
| ANON-03 | 71 | Pending |
| ANON-04 | 71 | Pending |
| ANON-05 | 72 | Pending |
| ANON-06 | 71 | Pending (PR-A #480 ships it ; validated behind new UI in 71) |
| ANON-07 | 71 | Pending (PR-B #482 ships it ; validated behind new UI in 71) |
| ECL-01 | 72 | Pending |
| ECL-02 | 72 | Pending |
| ECL-03 | 72 | Pending (PR-C #481 ships it ; prompt-path assertion in 72) |
| ECL-04 | 71 | Pending |
| WALK-01 | 74 | Pending |
| WALK-02 | 74 | Pending |
| WALK-03 | 74 | Pending |
| WALK-04 | 74 | Pending |
| WALK-05 | 74 | Pending |
| WALK-06 | 74 | Pending |
| COMP-01 | 70 | Pending |
| COMP-02 | 70 | Pending |
| HYG-01 | 70 | Pending |
| HYG-02 | 70 | Pending |
| HYG-03 | 70 | Pending |
| HYG-04 | 70 | Pending |
| HYG-05 | 75 | Pending |

**Coverage:**
- v2.10 requirements: 31 total
- Mapped to phases: **31** ✓ (100%)
- Unmapped: 0 ✓
- Phases: 6 (70 / 71 / 72 / 73 / 74 / 75)

**Phase distribution:**
- Phase 70 (Hygiene + LSFin lint): 6 REQs (HYG-01..04, COMP-01, COMP-02)
- Phase 71 (Anonymous Chat redesign): 7 REQs (ANON-01..04, ANON-06, ANON-07, ECL-04)
- Phase 72 (Premier Éclairage rendering): 4 REQs (ANON-05, ECL-01, ECL-02, ECL-03)
- Phase 73 (Landing v3 éditorial): 7 REQs (LAND-01..07)
- Phase 74 (Walker E2E + golden): 6 REQs (WALK-01..06)
- Phase 75 (TestFlight 2.10.0 cut): 1 REQ (HYG-05)

## Constraints from Julien (operational, 2026-05-05)

- No human-in-the-loop testing. Claude validates everything via simulator iPhone (Mac mini) before any visual is shown to Julien.
- Image budget : max 1-2 screenshots per checkpoint surfaced to Julien. Full gallery archived under `.planning/walker/<run-id>/`.
- TestFlight = Claude-validated only. No human device gate.
- No new PRs until v2.10 roadmap approved.

---
*Requirements defined: 2026-05-05*
*Last updated: 2026-05-04 — roadmap shipped, 31/31 REQs mapped to phases 70-75, traceability complete.*
