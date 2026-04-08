# Pitfalls Research — v2.2 La Beauté de Mint

**Domain:** Retrofit (calm visual layer + 5-level voice intensity dial + MTC confidence layer + regional microcopy carve-out) into a mature Flutter+FastAPI fintech codebase (12'892 tests, 8 calculators, 18 life events).
**Researched:** 2026-04-07
**Confidence:** HIGH on codebase-specific pitfalls (verified by grep against the actual repo). MEDIUM on LLM tone-locking literature (training-data dependent, prior art is sparse and contested).

> **Scope discipline.** This file does NOT repeat what the 21 audits + red team already caught (dark patterns, "18-99 ALL" lie, palate cleansers, MINT Signature, halo naming, theology of clarity, dual-system MTC, Krippendorff α≥0.67 vs naive 80%, VoiceCursorContract Phase 0, i18n carve-out, Galaxy A14 manual gate, précision horlogère cut). Those are **decisions**. This file surfaces **what survives** those decisions because it lives in joints, defaults, and human processes — not in the brief itself.

> **Ranking convention.** Each pitfall carries `Likelihood × Severity`. The Top-10 sorted list lives at the bottom (`§ Pitfall Ranking`).

---

## Critical Pitfalls

### Pitfall 1 — Tone-locking: Claude produces "polite chatbot's idea of N4", not actual N4

**What goes wrong:**
The VoiceCursorContract is plumbed end-to-end. `Profile.voiceCursorPreference = 'unfiltered'` is sent to `claude_coach_service.py`. The system prompt says *"output at intensity N4 piquant"*. Claude returns a message that is **structurally identical** to N2 — slightly shorter, mildly direct — but the *bite* never lands. Krippendorff α on the 30 reference phrases passes (those were hand-written by Julien). Production output silently regresses to N2-N3 across the board. Nobody notices because nothing breaks.

**Why it's hard to spot:**
- The L1.6b validation set is 30 phrases that were *written* at the target level, not *generated* by the model. The metric never tests generation, only recognition.
- LLMs are RLHF'd toward politeness. "Be sharp" is a weak signal against "be helpful, harmless". The model collapses to its base distribution under pressure.
- A/B testing voice intensity requires humans-in-the-loop; automated tests can verify *banned phrases absent* but not *piquant present*.
- It looks fine in spot-checks because Julien primes himself by reading the spec before reading the output.

**Likelihood:** HIGH — this is the documented failure mode of every "personality dial" system shipped on a frontier LLM since 2023 (Replika "spicy" mode, Character.ai persona drift, Cleo's own observation that Roast Mode required model fine-tuning, not prompting alone).
**Severity:** HIGH — kills the central thesis of v2.2. If the curseur doesn't actually modulate, the milestone shipped a setting screen and nothing else.

**Phase to address:** L1.6a (spec) + L1.6b (validation), with a **generation-side test** added to the spec, not just a recognition test.

**Prevention strategy:**
1. Add a third sub-deliverable to L1.6b: **"reverse Krippendorff"** — feed the spec + 10 trigger contexts to Claude, generate 10 candidate outputs per level, have the same 15 testers re-classify them blind. If generated-N4 is classified as N2/N3 by ≥30% of testers, the prompt is broken — reroll the prompt before validating phrases.
2. Build a one-shot **few-shot prompt** for each level: each system prompt for N4 must contain 3 verbatim N4 examples in the prompt itself. Zero-shot tone instructions do not work on Claude Sonnet for register modulation.
3. Add explicit **anti-examples** in the prompt: *"N4 is NOT 'I'd like to gently point out...'. N4 IS 'Ta caisse prend 1.4%. C'est pas illégal. C'est cher.'"*
4. Bound the failure: make the **default** `direct` cap N3, not N4. Earn N4 with verified output, don't ship it on day 1.

**Detection signal:**
- Production log sample: pull 100 random coach replies/week tagged `level: N4`, run a one-question rater script ("does this sting?"). Target: ≥60% yes.
- Grep for politeness markers in N4+ output: `"il est important"`, `"je pense que"`, `"peut-être"`, `"si tu veux"`, `"n'hésite pas"`. Any hit = drift.
- Krippendorff α on **generated** N4-N5 < 0.50 → ship blocker.

---

### Pitfall 2 — Context bleeding across turns: a G3 N5 alert poisons the next G1 turn

**What goes wrong:**
Turn N is a G3/N5 cash alert ("Stop. Tu vas signer un truc qui te coûte 47 000 CHF."). Turn N+1 is the user asking *"c'est quoi un 3a?"* — a G1 information request. Claude has the previous turn in context. The model anchors on the prior register and replies to the G1 question with a leftover N4 edge ("Bon. Le 3a, c'est…"). The user perceives Mint as relentlessly stern. The cursor matrix is technically correct but functionally broken because LLM context windows leak register.

**Why it's hard to spot:**
- Single-turn tests pass. Multi-turn drift only appears in real conversation logs.
- The brief treats each output as if it were generated in isolation. It is not.
- ComplianceGuard validates *content*, not *register*.

**Likelihood:** HIGH — this is the dominant failure mode of any system that injects per-turn personality flags into a stateful LLM session.
**Severity:** MEDIUM — degrades trust gradually rather than catastrophically.

**Phase to address:** L1.0 (VoiceCursorContract) + L1.6c (backend wiring).

**Prevention strategy:**
1. The system prompt must be **rebuilt fresh** every turn from `(currentGravity, currentRelation, currentPreference)`. No accumulated "vibe".
2. Include an explicit **register reset clause** in the system prompt: *"Ignore the tonal register of any previous turn in this conversation. Choose register only from the current routing matrix."*
3. Tag the assistant turn in conversation history with its level (`[N5]`) so the model can see the *change* and treat it as a deliberate shift rather than a continuation.
4. For G3→G1 transitions specifically, prepend a **calm-down separator** in the user-visible UI (small visual breath, not a screen) — and a corresponding marker in the prompt history.

**Detection signal:**
- Build a 20-conversation eval: each conversation contains a G3→G1 transition. Score the post-G3 G1 turn for register. If >20% of post-G3 G1 turns score as N3+, the reset isn't working.
- Log `(previousTurnLevel, currentTurnLevel)` pairs in prod. Distribution should be near-independent, not autocorrelated.

---

### Pitfall 3 — N5 weekly cap is editorial, not technical → fragile users get hammered

**What goes wrong:**
The brief states *"max 1 N5/utilisateur/semaine"* as an editorial rule. A user in active financial distress (the exact user who triggers G3 most often) receives 4 N5 messages in 3 days because each one is independently routed to G3 by the scoring rules. The "fragile mode" 30-day cap exists but only kicks in if the user *self-declares* fragility — which a user in crisis doesn't do. CLAUDE.md and the brief both say "no humiliation". The system humiliates by repetition.

**Why it's hard to spot:**
- Each individual N5 message is correct in isolation.
- Compliance review reads single messages, not message streams per user.
- Test data uses synthetic profiles that don't trigger 4 G3 events in 3 days.

**Likelihood:** HIGH — financial crisis events cluster (découvert + missed payment + tax deadline + insurance lapse all happen in the same week).
**Severity:** HIGH — this is the *exact* failure mode Cleo got criticized for and that the doctrine "Mint éclaire, n'accuse pas" was written to prevent.

**Phase to address:** L1.6a (spec) + L1.6c (backend) — must be enforced server-side, not editorially.

**Prevention strategy:**
1. **Promote the cap to a hard backend gate.** `Profile.n5IssuedThisWeek: int` with a 7-day rolling counter. When the counter ≥1, downgrade the next G3 to N4 automatically and log the suppression.
2. Add an **auto-fragility detector**: ≥3 G2/G3 events in 14 days → auto-enter fragile mode (N3 cap, 30 days), without requiring self-declaration. User receives a single N1 message explaining the shift.
3. Spec the routing matrix to read `(gravity, relation, preference, fragilityState, n5BudgetRemaining)` — five inputs, not three.

**Detection signal:**
- Backend metric `n5_issued_per_user_per_week_p99` — alert if >1.
- Grep production logs for any user receiving ≥2 N5 in any 7-day window. Target: zero.
- Test fixture: a Lauren-like profile with a synthetic crisis cluster. Replay through the routing engine. Assert ≤1 N5 emitted.

---

### Pitfall 4 — MTC migration breaks ~40 widget tests silently

**What goes wrong:**
Grep on `confidence_scorer | EnhancedConfidence | confidenceBadge` returns **40+ files** across screens, widgets, services, and tests. L1.2a builds the new MTC component. L1.2b migrates ~12 projection surfaces. The test files for the *legacy* badges still pass (because the legacy widget still exists somewhere) — but the screens that migrated lost their golden tests entirely because the test was for `ConfidenceBadge` and the screen now renders `MintTrameConfiance`. Coverage drops invisibly. `flutter test` is still green.

**Why it's hard to spot:**
- Removing a widget removes its tests. Removed tests do not fail.
- The 12'892 test count is a vanity metric — it can rise while coverage of *the migrated surfaces* falls.
- `flutter analyze` doesn't catch lost coverage.

**Likelihood:** HIGH — this is the dominant pattern of every "single rendering layer" migration. v2.1's façade audit caught the *runtime* version; the *test-coverage* version is harder.
**Severity:** MEDIUM — doesn't break prod immediately but creates a window where MTC bugs ship undetected.

**Phase to address:** L1.2a (component) — add a migration test scaffold *before* L1.2b begins.

**Prevention strategy:**
1. Before L1.2b touches any screen, snapshot the current test coverage of `confidence_scorer.dart` consumers using `flutter test --coverage` and `lcov` filter. Persist to `.planning/baselines/mtc-coverage-pre.lcov`.
2. Each L1.2b PR must include **MTC-equivalent tests** for any deleted legacy badge test. PR template gate.
3. Maintain a checklist file `.planning/milestones/v2.2-phases/L1.2-MTC-MIGRATION-CHECKLIST.md` listing all 12 surfaces with `[ ] component swapped` `[ ] test ported` `[ ] golden re-baselined` `[ ] manual tap-render verified on Galaxy A14`.

**Detection signal:**
- `lcov` diff: `confidence_scorer.dart` line coverage must not drop. Hard CI gate.
- Grep post-migration: `ConfidenceBadge\b` should return zero matches in `lib/`. Any leftover = dual-system regression (the very thing L1.2 exists to kill).
- Ratio test: count widget tests touching MTC = ≥ count of pre-migration tests touching legacy badges.

---

### Pitfall 5 — MTC is not a 1:1 replacement: legacy surfaces showed *different things*

**What goes wrong:**
The grep result shows confidence rendering on `hero_stat_resolver.dart`, `extraction_review_screen.dart`, `freshness_decay_service.dart`, `confidence_score_card.dart`, `trajectory_view.dart`, `plan_generation_service.dart`, `financial_plan.dart`. Some of these render **data freshness** ("ces données ont 3 mois"). Some render **calculation confidence** (4-axis EnhancedConfidence). Some render **document extraction confidence** (OCR score). Migrating all of them to a single MTC component flattens three semantically distinct concepts into one visual. Users lose information. Power users (Julien) immediately notice; QA doesn't.

**Why it's hard to spot:**
- The brief assumes "confidence is confidence". Code says otherwise.
- Each consumer maps its concept to MTC successfully — *technically*. The semantic loss is at the design level.
- Tests verify the new component renders, not that the *information* survived.

**Likelihood:** HIGH — verified by grep above.
**Severity:** MEDIUM-HIGH — silent information loss is the worst kind of regression because users can't articulate what changed.

**Phase to address:** L1.1 (audit du retrait) — must include a **semantic map** of all current confidence surfaces *before* L1.2 starts.

**Prevention strategy:**
1. L1.1 deliverable: `AUDIT_CONFIDENCE_SEMANTICS.md` — for each of the ~40 grep hits, classify: `extraction-confidence | data-freshness | calculation-confidence | composite`. Decide per-class whether MTC absorbs it or whether a sibling component (`MintFreshnessTrace`?) is needed.
2. If sibling components are needed, declare them in L1.2a's API design — not retrofitted later.
3. Forbid the migration of any surface where the source semantic ≠ "calculation confidence" until L1.1 has explicitly mapped it.

**Detection signal:**
- Manual side-by-side screenshots (Julien's tap-render walkthrough on Galaxy A14) of every migrated surface, before/after. Any "information lost" finding blocks L1.2b.
- Test: assert that any screen previously displaying a freshness timestamp still displays one after migration.

---

### Pitfall 6 — MTC bloom on a scrollable feed = jitter zone

**What goes wrong:**
v2.0 ships ContextualCard (ranked feed in `mint_home_screen.dart` / S2). After L1.2b, every card carrying a confidence indicator fires the 250ms bloom on first appearance. On Galaxy A14 scrolling at 60Hz with 6-8 cards visible, the GPU drops to ~40fps during the scroll-in animation cluster. The home screen feels janky on the device that's the explicit floor.

**Why it's hard to spot:**
- iOS Simulator and Pixel emulator render this fine. The Galaxy A14 is the only device where it shows.
- The brief specs the bloom in the *MTC component context*, not in the *list context*.
- Manual gate catches it eventually but only after the feature is "done".

**Likelihood:** MEDIUM-HIGH — depends on how aggressively MTC is placed in S2.
**Severity:** MEDIUM — degrades the primary screen, but recoverable.

**Phase to address:** L1.2a (component) — bloom strategy must be defined per-context in the API.

**Prevention strategy:**
1. The MTC API takes a `BloomStrategy` enum: `firstAppearance | onTap | never | onlyIfTopOfList`. Default in feed contexts = `onlyIfTopOfList` or `never`.
2. Honor `MediaQuery.disableAnimations` (WCAG 2.3.3, vestibular trigger). Without this, the AAA target is technically failed.
3. Stagger fallback: if multiple MTCs become visible in the same frame, only the topmost blooms; others fade in over 100ms with no scale.
4. Add `BloomStrategy` to L1.0's VoiceCursorContract sibling: a `MTCRenderContract` Dart const. Don't let each consumer choose blindly.

**Detection signal:**
- Galaxy A14 manual perf gate: scroll S2 from cold start, record 5 seconds, check frame timing in DevTools. >5% dropped frames = block.
- Grep: any MTC instantiation in `lib/` without an explicit `BloomStrategy` argument = lint failure (custom analyzer rule, cheap to add).
- Test: `MediaQuery(disableAnimations: true)` widget test asserts bloom duration = Duration.zero.

---

### Pitfall 7 — MTC "1 ligne audio" for screen readers is a UX problem, not a string problem

**What goes wrong:**
The brief specs *"version 1 ligne audio pour TalkBack/VoiceOver"*. The implementation reads: *"Confiance 73 pourcents. Complétude haute. Précision moyenne. Fraîcheur périmée. Compréhension débutant."* This is verbose, technical, and unparseable by a screen reader user. WCAG AAA target fails the moment it ships. Worse: the AAA test pool is one malvoyant·e user; if they're polite, they say "c'est OK" and the failure ships.

**Why it's hard to spot:**
- Sighted reviewers can't feel how screen reader output flows.
- "It produces a string" passes the implementation checklist.
- TalkBack and VoiceOver pronounce the same string differently.

**Likelihood:** HIGH — the brief explicitly punts the abstraction problem ("1 ligne audio").
**Severity:** MEDIUM — affects a minority of users but blocks the AAA claim.

**Phase to address:** L1.2a (component spec) — the audio variant is a design problem, not an i18n problem.

**Prevention strategy:**
1. Define the audio variant as a **single human sentence**, not a list of axes. Example: *"Estimation moyennement fiable, basée sur des données un peu anciennes."* Map the 4-axis combinatorial space (e.g. 81 cells if each axis is 3-valued) to ≤9 templated sentences.
2. Test on **TalkBack 13** (Galaxy A14, Android) AND iOS VoiceOver. They tokenize numbers, percent signs, and punctuation differently.
3. Recruit the malvoyant·e tester in **Phase 0**, not at "milestone cadence". Three sessions × 4-week recruitment lead = start now or it doesn't happen.
4. Forbid the literal string `pourcents` in any audio variant. Numbers should be either avoided ("fiabilité moyenne") or rounded to qualitative bands.

**Detection signal:**
- Audit: enumerate all (completeness, accuracy, freshness, understanding) buckets and check the rendered string. Anything >12 words = redesign.
- Live test transcript from session 1 — if the user says *"c'est trop long"* or asks for repetition, fail.

---

### Pitfall 8 — Cursor preference vs gravity floor: edge cases the matrix doesn't cover

**What goes wrong:**
Brief decision: preference *never* overrides gravity floor (G3 → never N1/N2). Matrix routes G3+nouveau→N4 and G3+established→N5. But what about a `unfiltered` user on G1+nouveau (matrix says N1)? Does `unfiltered` raise to N2? N3? The matrix is ambiguous on **upward overrides** (preference raising the floor) vs **downward overrides** (preference lowering it). Edge cases:
- `soft` user, G2+intime → matrix says N4. Soft caps at N3. Conflict.
- `unfiltered` user, G1+nouveau, sensitive topic (deuil) → matrix says N1, sensitive topic forces N1, unfiltered allows N5. Three rules, three answers.
- Fragile mode (N3 cap 30 days) + G3 → cap or override?

**Why it's hard to spot:**
- The brief lists garde-fous as a flat list. There's no precedence ordering.
- Each rule reads correct in isolation; conflicts only emerge in code review.

**Likelihood:** HIGH (certain).
**Severity:** MEDIUM — wrong answer to one user is recoverable; ambiguous spec compounds across the codebase.

**Phase to address:** L1.0 (VoiceCursorContract) — must define **precedence**, not just rules.

**Prevention strategy:**
1. Spec the precedence order as a numbered cascade in the contract:
   1. Sensitive-topic guard (hard cap N1-N3)
   2. Fragile-mode cap (hard cap N3, 30d)
   3. N5 weekly budget (auto-downgrade if exhausted)
   4. Gravity floor (G3 → ≥N4, G2 → ≥N2)
   5. Preference cap (soft → ≤N3, direct → ≤N4, unfiltered → ≤N5)
   6. Matrix default (gravity × relation)
2. Implement as a pure function `resolveLevel(inputs) → N1..N5` with **80+ unit tests** — one per cell of the cross-product. Cheap, exhaustive.
3. Property test: for any (gravity, relation, preference, sensitive, fragile, budget), the function must return a level satisfying ALL active constraints. If no level satisfies all, the spec is broken — surface the conflict at test time.

**Detection signal:**
- Unit test count for `resolveLevel`: < 64 = under-specified.
- Property test: zero unsatisfiable inputs.

---

### Pitfall 9 — N5 + ComplianceGuard: piquant register drifts into prescription

**What goes wrong:**
N4/N5 register encourages directness ("On regarde l'alternative ?", "Tu peux annuler dans 14 jours"). ComplianceGuard's "no advice" rule looks for product names, ISINs, "je recommande". It misses N4 phrases like *"Ta caisse te coûte cher. Change-la."* — which is structurally a recommendation ("change X"), even though no product is named. The piquant register is *closer* to the compliance line by design. ComplianceGuard's regex-based filters miss this.

**Why it's hard to spot:**
- ComplianceGuard's test corpus was written against the calm register. It has never seen N4/N5 inputs.
- The line between "éclairer" and "conseiller" is a register problem, not a vocabulary problem.

**Likelihood:** HIGH.
**Severity:** HIGH — a single FINMA-relevant slip is a P0 compliance event.

**Phase to address:** L1.6a (spec) + L1.6b (validation) — ComplianceGuard must be co-validated with the new register.

**Prevention strategy:**
1. Extend ComplianceGuard's test corpus with **50 adversarial N4/N5 phrases** that look helpful but cross into prescription. Run as part of L1.6b validation.
2. Add a **register-aware rule**: any output tagged ≥N4 must pass an additional check — does it contain an imperative verb directed at user action without a "tu peux / on peut / une option" hedge? If yes, route to human review or downgrade to N3.
3. Co-version ComplianceGuard with the VoiceCursorContract — same Phase 0, same source of truth.

**Detection signal:**
- Adversarial test pass rate: ≥98% on the 50-phrase corpus.
- Production log filter: weekly sample of N4/N5 outputs, manual review for the imperative-without-hedge pattern. >2/week = drift.

---

### Pitfall 10 — `chiffre_choc` rewording is a 30-file sweep, easy to half-finish

**What goes wrong:**
Grep returns **30 files** containing `chiffre_choc | chiffreChoc` — including `coach_orchestrator.dart`, `intent_screen.dart` (S1!), `screen_registry.dart`, ARB files for all 6 languages, journey golden-path tests for 8 personas, and `retroactive_3a_screen.dart`. The brief mandates "premier éclairage systématiquement". A surface-level rename touches Dart symbols but leaves test fixture strings, ARB values, and backend payload field names inconsistent. Some tests pass on legacy strings, some fail loudly, some pass *because* they assert the legacy string.

**Why it's hard to spot:**
- Renaming a field is mechanical. Renaming a *concept* across 6 languages × 30 files is not.
- Pydantic schemas with `populate_by_name` happily accept both old and new — silent dual-vocabulary.
- Golden-path journey tests test the *flow*, not the *naming*; they keep passing on stale wording.

**Likelihood:** HIGH (the codebase is provably half-renamed already).
**Severity:** LOW-MEDIUM — semantic confusion accumulates, eventually a user-facing string says "chiffre choc" in production.

**Phase to address:** L1.0 — small Phase 0 cleanup chore, blocks nothing but removes the legacy term before voice work multiplies references to it.

**Prevention strategy:**
1. Single sweep PR in Phase 0: rename `chiffre_choc` → `premier_eclairage` across Dart, Python, ARB, tests, fixtures. Use `git grep -l` then a scripted replace, then manual review of each diff hunk.
2. Add a **CI grep gate**: `git grep -i "chiffre.choc\|chiffreChoc"` returns zero in `lib/`, `app/`, `l10n/`. Any reintroduction = build break.
3. Backend Pydantic: drop the alias on the field name, force breaking change, version the API.

**Detection signal:**
- `git grep` returns 0 in source dirs (allowed in `.planning/`, `decisions/`, `docs/archive/`).
- ARB diff review for all 6 languages (es, pt, it especially — easy to miss).

---

### Pitfall 11 — Regional voice validators don't exist yet, recruitment is the schedule killer

**What goes wrong:**
L1.4 says "validés par natifs locaux" for VS, ZH, TI. Recruiting one Valaisan who is willing to review 30 microcopies, available within the milestone window, and reachable through Julien's network — possible. Doing the same for ZH (Swiss German vs Hochdeutsch question) AND Ticino in parallel — significantly harder. The chantier schedule treats validation as a 1-week task; in practice it's 4-6 weeks of recruitment + 1 week of review + 1 week of revision. L1.4 silently slips and blocks the milestone close.

**Why it's hard to spot:**
- The brief lists "validés par natifs locaux" as an output, not a process. There's no recruitment plan.
- Every other chantier is internally executable; L1.4 has external dependencies that look small but aren't.

**Likelihood:** HIGH.
**Severity:** MEDIUM — milestone slips, doesn't break.

**Phase to address:** L1.0 — recruitment must start in Phase 0, not in L1.4.

**Prevention strategy:**
1. Phase 0 deliverable: **3 named human validators committed**, one per canton, with availability windows. If three names aren't on the page by end of Phase 0, descope to one canton (VS — the easiest for Julien's network) and ship the others in v2.3.
2. Pay them. Volunteer reviewers ghost. CHF 200/canton is a rounding error against the milestone cost.
3. Pre-write the review brief (what to look for, what counts as caricature, what "subtle" means) so the validator's first session is production, not orientation.

**Detection signal:**
- Named validators in `.planning/milestones/v2.2-phases/L1.4-validators.md` by end of Phase 0.
- If absent → descope decision triggered automatically.

---

### Pitfall 12 — Backend regional injection: the dual-system trap (same as MTC, different layer)

**What goes wrong:**
`claude_coach_service.py` already has a `REGIONAL IDENTITY` block in its system prompt (verified by grep). `RegionalVoiceService.forCanton()` already exists in Flutter. L1.4 adds `app_regional_<canton>.arb` files. If the backend injection block stays AND the new ARB files exist AND the existing Flutter service routes between them, you have **three sources of regional truth** — the same dual-system trap MTC was created to kill. No one notices because each source produces *plausible* output independently.

**Why it's hard to spot:**
- Each layer "works".
- Drift only appears when a Valaisan user gets a Hochdeutsch turn of phrase because Layer 2 served it.
- Identical to F4 / MTC structurally, which is why this file singles it out.

**Likelihood:** HIGH (the conditions already exist in the repo).
**Severity:** MEDIUM-HIGH — it's the failure pattern v2.1 spent a whole audit wave killing.

**Phase to address:** L1.0 + L1.4 — must have an explicit "single source of regional truth" decision.

**Prevention strategy:**
1. Decide in Phase 0: which layer owns regional voice? Recommendation — **ARB files own static microcopy, backend system prompt owns dynamic-generation tone hints, Flutter service is just a router**. Document the split.
2. After L1.4, the backend `REGIONAL IDENTITY` block must reference the ARB carve-out conceptually but not duplicate strings. Strings live in ARB; the block tells Claude *"prefer the regional register tags it has been trained on for this canton"*.
3. CI check: `app_regional_*.arb` keys are loaded into `RegionalVoiceService` via a generated map. Backend doesn't load ARBs (privacy: ARB content stays mobile). Single direction of flow.

**Detection signal:**
- Grep: any string from `app_regional_vs.arb` appearing as a literal in `claude_coach_service.py` = duplication.
- Architectural ADR file `decisions/ADR-2026xxxx-regional-voice-source-of-truth.md` exists.

---

### Pitfall 13 — AAA contrast 7:1 will break MintColors brand pastels

**What goes wrong:**
`MintColors` palette uses Mint pastels and greens (the brand). WCAG AA (4.5:1) is roughly survivable with the current palette by tuning text-on-background. WCAG AAA (7:1) on S1-S5 forces darker text or darker backgrounds, which means **brand colors no longer work as intended on the surfaces that define the milestone**. The brief mandates AAA on S1-S5 without acknowledging the brand collision. L1.1 (audit du retrait) and L1.3 (microtypographie) will hit this within the first week.

**Why it's hard to spot:**
- The brief talks about "calme" and "AAA cible" as if they're aligned. They aren't — calm pastels and 7:1 are nearly opposite goals.
- DevTools contrast checker is rarely run on every text/background combination.
- Designers tend to lower opacity to "soften" backgrounds, which makes contrast worse, not better.

**Likelihood:** HIGH.
**Severity:** MEDIUM — forces either brand bend or AAA descope. Either decision is OK; *not deciding* is the failure.

**Phase to address:** L1.1 (audit) — must include a **contrast matrix** of every text color × every background color used on S1-S5.

**Prevention strategy:**
1. L1.1 deliverable: `AUDIT_CONTRAST_MATRIX.md` listing every text/background pair on S1-S5 with measured ratios. Decision tree: pass AAA → keep, pass AA only → bend brand or descope to AA-on-this-element-only with rationale.
2. Add a custom Flutter analyzer rule: any `Text` widget on S1-S5 surfaces must have a `// contrast-verified: AAA` comment OR be wrapped in an `AAATextStyle()` helper that asserts at debug time.
3. Decide explicitly per surface: AAA-on-text vs AAA-on-text+icons vs AA-on-decorative. Brief doesn't make this distinction, but WCAG does (large text = 4.5:1 even at AAA).

**Detection signal:**
- Contrast matrix file exists by end of L1.1.
- CI: a script using `flutter test` + a contrast plugin walks every Text widget on S1-S5 in golden tests, asserts ratio.

---

### Pitfall 14 — Live accessibility tests start too late

**What goes wrong:**
Brief mandates 3 live tests (1 malvoyant·e, 1 ADHD, 1 français-seconde-langue) "à cadence milestone". In practice, recruitment of these three users from outside Julien's existing network is a **4-6 week process** (especially the malvoyant·e tester — disability research orgs gatekeep, ad-hoc recruitment is unethical). If recruitment starts in L1.6 (because that's when the voice work is "ready to test"), the milestone closes before testing reports back. The tests become post-merge ceremony, not gates.

**Why it's hard to spot:**
- The brief schedules tests as a deliverable, not as a recruitment process.
- Same failure pattern as Pitfall 11 (regional validators).

**Likelihood:** HIGH.
**Severity:** MEDIUM-HIGH — turns the AAA + accessibility commitment into theater.

**Phase to address:** L1.0 — recruitment kicks off in Phase 0.

**Prevention strategy:**
1. Phase 0: contact a Swiss disability-research org (Pro Infirmis, FSA, Inclusion Handicap) and a francophonie-as-L2 community (e.g. Caritas Genève) **before any code is touched**. Schedule first sessions for end of L1.3.
2. Pay testers. CHF 150/session is ethical and standard.
3. If recruitment fails by end of L1.1, descope AAA target to "AA bloquant + AAA aspirational" honestly. Don't ship a fake AAA.

**Detection signal:**
- Named testers + scheduled session dates in `.planning/milestones/v2.2-phases/L1.0-accessibility-recruitment.md` by end of Phase 0.

---

### Pitfall 15 — Editorial drift: post-validation, every new phrase is a regression risk

**What goes wrong:**
L1.6b validates 30 phrases against the spec with Krippendorff α≥0.67. The milestone ships. The next sprint adds 12 new coach phrases for a new feature. None of them go through validation because the milestone is closed. Within 4-6 weeks, the spec exists as a document but the production text drifts toward the median LLM register again. By v2.3, the curseur is decoration.

**Why it's hard to spot:**
- The validation is a milestone artifact, not a process.
- "We have a spec" creates false confidence.
- New phrases are usually added by feature PRs, not by editorial PRs.

**Likelihood:** HIGH.
**Severity:** MEDIUM — slow decay rather than acute failure.

**Phase to address:** L1.6 + a post-milestone process commitment.

**Prevention strategy:**
1. Build a **lint-time level checker**: every new ARB string in coach-facing namespaces must carry a `@meta` annotation with `level: N1..N5`. Any string without annotation = build break.
2. PR template gate: any PR adding coach-facing strings must include a "level + 1-line justification" per string and link the spec section.
3. Quarterly editorial review: random sample 30 production strings, re-rate, compute α drift. <0.55 → emergency review.
4. Designate a single owner of `VOICE_CURSOR_SPEC.md` (Julien or one copywriter). Changes go through them.

**Detection signal:**
- Quarterly α on production sample.
- ARB strings without `@meta level:` = 0 in coach namespaces.

---

### Pitfall 16 — `MTC sortable` becomes the next ranking trap

**What goes wrong:**
MTC unifies confidence rendering. A future feature (not v2.2, but inevitable) sorts a list of projections by confidence — "show me my most reliable estimates first". Now MTC is being used to **rank** insights against each other, which compliance forbids ("no ranking"). The trap is structural: the moment confidence becomes a single number visible everywhere, sorting on it is a one-line code change someone will make in 3 sprints.

**Why it's hard to spot:**
- v2.2 doesn't ship the sort. The pitfall lands in v2.3-v2.5.
- Compliance review of v2.2 looks at v2.2 outputs, not at affordances created.

**Likelihood:** MEDIUM.
**Severity:** MEDIUM — recoverable but requires unwinding a feature.

**Phase to address:** L1.2a (component spec) — bake the constraint into the API now.

**Prevention strategy:**
1. MTC API does not expose confidence as a comparable scalar. The component takes `EnhancedConfidence` and renders. There is no `MTC.score: double` getter on the public API.
2. Document constraint in the component dartdoc: *"MTC must not be used to sort, filter, or rank items. Confidence is a per-item property, not a comparator. Compliance: no ranking (CLAUDE.md §6)."*
3. Add to the compliance test suite: any code in `lib/` calling `.sort` or `.compareTo` on a confidence-derived value = grep alert.

**Detection signal:**
- Public API of `MintTrameConfiance` does not expose a `double` comparable.
- Grep: `confidence.*\.compareTo\|sortedBy.*confidence` = 0 in lib/.

---

### Pitfall 17 — Sample size 30 phrases is too small to validate 5 levels with confidence

**What goes wrong:**
L1.6b validates the spec on 30 phrases (6 per level × 5 levels). With 15 testers and weighted ordinal Krippendorff, the per-level sample (n=6) is small enough that one ambiguous phrase per level can swing α below 0.67. The team either re-rolls until α passes (post-hoc cherry-picking) or ships on a brittle pass. Either way the spec hasn't been validated, just rationalized.

**Why it's hard to spot:**
- 30 looks like a round number. Statistical power isn't checked.
- Re-rolling phrases until pass is invisible in the final report.

**Likelihood:** MEDIUM.
**Severity:** MEDIUM — the metric is fake but everyone trusts it.

**Phase to address:** L1.6b — set sample-size policy in advance.

**Prevention strategy:**
1. Spec in advance: ≥10 phrases per level (50 total), with phrase set frozen *before* testers see it. No re-rolling individual phrases mid-validation.
2. Pre-register: which phrases, which levels, which testers. Deviations require a documented amendment.
3. Report per-level α and per-level confidence interval, not just aggregate. A pass on N1-N3 with fail on N4-N5 is the realistic outcome and should be flagged honestly, not averaged away.
4. If per-level α (N4 or N5) < 0.67, the spec for that level is unclear — fix the spec, then re-test on a fresh phrase set.

**Detection signal:**
- Validation report includes per-level α with CIs, not just aggregate.
- Test set frozen file (`.planning/milestones/v2.2-phases/L1.6b-test-set.json`) committed before validation runs.

---

### Pitfall 18 — ARB regional fallback: undefined behavior on missing key

**What goes wrong:**
`app_regional_vs.arb` has 30 keys. Six months later, a feature reuses one of those keys but extends it for VS only. The key gets renamed in `app_regional_vs.arb` but not in main `app_fr.arb`. A non-VS user hits the screen. Flutter's `AppLocalizations` falls back — but to *what*? If the regional namespace is its own generated class (`AppRegionalLocalizations.of(context)`), missing key throws. If it's merged into `AppLocalizations`, fallback chain is undefined and may render the key name as text. Either failure mode is worse than the current state.

**Why it's hard to spot:**
- Flutter's i18n fallback semantics depend on how the namespace is wired. Not documented in the brief.
- Tests run with the "happy" canton; missing-key paths are never executed.

**Likelihood:** MEDIUM.
**Severity:** LOW-MEDIUM.

**Phase to address:** L1.4 (regional voice) — fallback policy is a Phase 0 decision.

**Prevention strategy:**
1. Decide: regional ARBs are a **separate generated class**, accessed via `RegionalVoiceService.forCanton(context).keyName`. Missing key = fallback to main `AppLocalizations` value, with a debug-mode warning.
2. Test: every regional key has a counterpart in `app_fr.arb` (or equivalent base language). CI gate.
3. Forbid regional-only keys without a base-language sibling. Regional voice **overrides**, never **introduces**.

**Detection signal:**
- CI: for each key in `app_regional_*.arb`, assert key exists in corresponding base-language ARB.
- Debug build warning logged when fallback fires.

---

### Pitfall 19 — VoiceCursorContract Phase 0 deliverable bloat

**What goes wrong:**
Phase 0 (L1.0) currently bundles: STAB-17 walkthrough + Galaxy A14 baseline + VoiceCursorContract (Dart const + Pydantic) + Krippendorff tooling + accessibility tester recruitment + regional validator recruitment + chiffre_choc sweep + MTC coverage baseline + recruitment brief writing + the contract schema decisions for MTC and regional sources. That's 10+ artifacts. Phase 0 swells to 3 weeks and blocks every other chantier. The milestone arrives mid-summer with one-third of the chantiers unstarted.

**Why it's hard to spot:**
- Each Phase 0 item is small. The aggregate is not.
- "Phase 0 = stabilization" sounds bounded. It isn't.

**Likelihood:** HIGH.
**Severity:** MEDIUM.

**Phase to address:** L1.0 itself — scope cap.

**Prevention strategy:**
1. Hard rule: Phase 0 ships ≤5 deliverables. Pick the **blockers**: VoiceCursorContract (blocks L1.5+L1.6), STAB-17 walkthrough (blocks TestFlight), Galaxy A14 baseline (blocks any perf claim), recruitment kickoff (blocks L1.4+AAA), MTC contract draft (blocks L1.2). Everything else moves into the chantier that needs it.
2. Krippendorff tooling moves into L1.6b. ARB regional fallback policy moves into L1.4. Chiffre_choc sweep moves into L1.6 (it's an editorial chore).
3. Phase 0 has a 10-day budget. If it overruns by >3 days, descope.

**Detection signal:**
- Phase 0 deliverable count ≤5.
- Phase 0 calendar ≤2 weeks.

---

### Pitfall 20 — Bloom is a vestibular trigger; the brief is silent on `disableAnimations`

**What goes wrong:**
WCAG 2.3.3 (Animation from Interactions, AAA) requires that motion triggered by interaction can be disabled. MTC bloom is triggered by appearance — borderline interaction. WCAG 2.2.2 (Pause, Stop, Hide) applies. If MTC blooms regardless of `MediaQuery.disableAnimations`, the AAA target fails on this single animation. Vestibular users get nausea on the home feed. The brief mentions AAA without naming WCAG SCs.

**Why it's hard to spot:**
- "Animations" feels like a polish concern, not an accessibility one.
- The MTC spec talks about bloom as a *good* thing without acknowledging it's a regression for some users.

**Likelihood:** MEDIUM.
**Severity:** MEDIUM (one user category, hard regression).

**Phase to address:** L1.2a.

**Prevention strategy:**
1. MTC component reads `MediaQuery.of(context).disableAnimations` and returns the final state directly (no scale, no opacity transition) when true.
2. Document the binding in the MTC dartdoc with the WCAG SC reference.
3. Test: golden test with `disableAnimations: true` asserts no animation widget tree (no `AnimatedOpacity`, no `ScaleTransition`).

**Detection signal:**
- Widget test exists.
- Manual: enable Reduce Motion in Galaxy A14 settings, MTC renders statically.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|---|---|---|---|
| Ship the cursor as system prompt only (skip few-shot examples per level) | Saves 1 day | Pitfall 1 — model never modulates | Never for v2.2 |
| Implement N5 weekly cap as editorial rule, not server gate | Saves backend work | Pitfall 3 — fragile users hammered | Never |
| Regional ARB without fallback policy | Ships L1.4 faster | Pitfall 18 — runtime crashes 6 months later | Only if explicit ADR with revisit date |
| Skip MTC coverage baseline before L1.2b | Saves a day | Pitfall 4 — silent coverage loss | Never |
| Recruit accessibility testers in L1.6 instead of L1.0 | Frees Phase 0 | Pitfall 14 — tests become post-merge theater | Never if AAA is claimed |
| Krippendorff α<0.67 acceptance "we'll fix it later" | Unblocks L1.6 | Spec drift permanent (Pitfall 15) | Never |
| Reuse `confidence_score_card.dart` as MTC base instead of new component | Saves L1.2a | Drags legacy semantics into new layer (Pitfall 5) | Never |
| Ship without registering BloomStrategy on each MTC instance | Cleaner code | Pitfall 6 — feed jitter on Galaxy A14 | Only if MTC count ≤2 per screen |
| Single-language regional validator (one Valaisan, no ZH/TI) | Honest scope | Loses two-thirds of L1.4 value | Acceptable if Phase 0 recruitment fails — descope honestly |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|---|---|---|
| Claude system prompt + per-turn level | Single static prompt with level interpolated | Rebuild prompt fresh every turn from `(g, r, p, fragility, budget)`; explicit reset clause; few-shot examples per level |
| ComplianceGuard ↔ N4/N5 outputs | Run guard with legacy regex corpus | Extend corpus with 50 adversarial piquant phrases; add register-aware imperative-without-hedge rule |
| ARB regional namespace ↔ Flutter i18n codegen | Treat regional ARBs as additions to main namespace | Separate generated class `AppRegionalLocalizations`; explicit fallback to base; CI sibling-key check |
| `claude_coach_service.py` REGIONAL IDENTITY block ↔ new `app_regional_*.arb` | Both ship live = three sources of truth | One source per concern: ARB owns static strings, backend prompt owns dynamic register hints; ADR documents the split |
| MTC ↔ ContextualCard ranked feed | Bloom on every card on first appearance | `BloomStrategy.onlyIfTopOfList`; honor `disableAnimations`; staggered fade fallback |
| `Profile.voiceCursorPreference` Pydantic field ↔ existing Profile schema | Add field with default `direct`, ship | Add migration test (existing profiles), backfill default, version the schema, regenerate OpenAPI |
| `RegionalVoiceService.forCanton()` ↔ new ARB namespaces | Service hardcodes canton→ARB mapping | Generated map from ARB filenames; service is a router, not a registry |
| Galaxy A14 perf manual gate ↔ CI green | "CI green = ready to merge" | Add a separate `manual-perf-gate-passed` label requirement on PRs touching S1-S5 |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|---|---|---|---|
| MTC bloom cluster on scrollable feed | Galaxy A14 frame drops on S2 scroll | `BloomStrategy.onlyIfTopOfList`, stagger fallback, honor disableAnimations | ≥3 MTCs visible in same frame on 4GB Android |
| LLM context bloat from few-shot examples per level | Coach turn latency +400ms; cost +20% | Cache the per-level few-shot block as system prompt prefix; share KV across users (Anthropic prompt caching) | Whenever every turn rebuilds from scratch |
| Regional ARB load on app cold start | First-frame delay on low-end Android | Lazy-load regional ARBs only when canton is detected; main ARB loads always | Cold start with regional namespace eagerly loaded |
| Fragility detector running on every coach turn | Backend latency on coach hot path | Compute fragility state once per session; cache with 1h TTL | Whenever it's recomputed per message |
| Krippendorff computation on prod logs | OK at 30 phrases × 15 raters; quadratic at scale | Keep validation set bounded; never run α on prod corpus continuously | If "continuous validation" idea creeps in |

---

## Security & Compliance Mistakes

| Mistake | Risk | Prevention |
|---|---|---|
| N4/N5 piquant phrasing drifts into prescription | FINMA finding (no advice rule) | Adversarial corpus + register-aware ComplianceGuard rule (Pitfall 9) |
| MTC sortable used for ranking projections | Compliance (no ranking) violation | API does not expose comparable scalar (Pitfall 16) |
| Regional microcopy contains caricature of in-canton group | PR risk + brand damage | In-canton validators only, never out-canton reviewers (Pitfall 11) |
| Behavioral data (open count, attention) used to time N4/N5 messages | Violates v2.2 tier-1 rule (data minimization) | N4/N5 routing reads only `(gravity, relation, preference)`, never engagement signals; static analysis grep |
| Voice cursor preference logged with PII | Privacy regression | `voiceCursorPreference` stored as enum, never logged with user_id at INFO level |
| `chiffre_choc` legacy term leaks to user-facing surface | Identity / brand violation | CI grep gate (Pitfall 10) |
| Fragile-mode auto-detection logs distress signal externally | Privacy + ethics | Fragility flag is local-only, never sent to Claude system prompt verbatim, only as a numeric cap |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---|---|---|
| MTC audio variant verbose ("73 pourcents, complétude haute, précision moyenne…") | Screen reader user disengages | 9 templated human sentences mapping the 4-axis space (Pitfall 7) |
| Bloom fires on every MTC in feed | Vestibular trigger, jitter perception | BloomStrategy + disableAnimations honor (Pitfalls 6, 20) |
| User toggles "unfiltered" expecting Cleo-roast, gets polite chatbot | Disappointment, churn signal | Few-shot prompt + reverse Krippendorff (Pitfall 1) |
| User in crisis receives 4 N5 in a week | Humiliation by repetition | Server-side cap + auto-fragility (Pitfall 3) |
| "Curseur" word leaks to user setting label | Confusing jargon | User-facing label = "Ton" (already specified, but check ARB strings) |
| Confidence freshness info disappears after MTC migration | Silent information loss | L1.1 semantic audit (Pitfall 5) |
| AAA contrast forces brand-color rewrite mid-milestone | Visual identity regression | L1.1 contrast matrix decision *before* L1.3 typography work (Pitfall 13) |

---

## "Looks Done But Isn't" Checklist

- [ ] **VoiceCursorContract Dart const + Pydantic model:** Often missing — precedence order for conflicting rules. Verify: `resolveLevel()` has 64+ unit tests covering the cross-product.
- [ ] **L1.6b validation:** Often missing — generation-side reverse-Krippendorff test. Verify: report contains both recognition α AND generation α per level.
- [ ] **MTC component:** Often missing — `MediaQuery.disableAnimations` honor. Verify: golden test with disableAnimations:true asserts no animation tree.
- [ ] **MTC component:** Often missing — explicit `BloomStrategy` enum on the API. Verify: grep `MintTrameConfiance(` in lib/, every call passes `bloom:`.
- [ ] **MTC migration:** Often missing — coverage parity. Verify: lcov diff on `confidence_scorer.dart` consumers shows ≥0% delta.
- [ ] **MTC migration:** Often missing — semantic audit before swap. Verify: `AUDIT_CONFIDENCE_SEMANTICS.md` exists and classifies all 40 grep hits.
- [ ] **Regional ARB:** Often missing — sibling-key existence in base language. Verify: CI gate.
- [ ] **Regional voice carve-out:** Often missing — single source decision (ADR). Verify: `decisions/ADR-*regional*` exists.
- [ ] **N5 cap:** Often missing — server-side enforcement. Verify: replay test with synthetic crisis cluster, assert ≤1 N5 emitted.
- [ ] **Auto-fragility:** Often missing — detector runs without self-declaration. Verify: integration test with 3 G2 events in 14d triggers cap.
- [ ] **AAA:** Often missing — per-pair contrast matrix on S1-S5. Verify: matrix file exists; decisions logged for any AA-only element.
- [ ] **AAA:** Often missing — live test recruitment started in Phase 0. Verify: named testers + dates in `.planning/milestones/v2.2-phases/L1.0-accessibility-recruitment.md`.
- [ ] **L1.4 regional validators:** Often missing — committed humans by name. Verify: `L1.4-validators.md` with names + dates.
- [ ] **`chiffre_choc` rewording:** Often missing — ARB sweep across 6 languages and journey golden tests. Verify: `git grep -i "chiffre.choc"` returns 0 in source dirs.
- [ ] **ComplianceGuard:** Often missing — adversarial N4/N5 corpus. Verify: 50-phrase test file exists, run as part of L1.6b CI.
- [ ] **Editorial drift prevention:** Often missing — `@meta level:` annotation lint rule. Verify: build break on coach-namespace ARB string without annotation.
- [ ] **Context bleeding:** Often missing — system prompt rebuild clause + register reset instruction. Verify: prompt template inspection.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---|---|---|
| Tone-locking (P1) | HIGH | Re-prompt with few-shot examples; if still failing, route N4/N5 through a fine-tune or a different model; worst case, downgrade default cap to N3 and ship anyway |
| Context bleeding (P2) | LOW | Add reset clause + per-turn rebuild; redeploy backend |
| N5 hammering (P3) | MEDIUM | Hot-patch backend cap; backfill suppression to existing distressed sessions; manual outreach to top-N affected users |
| MTC test coverage loss (P4) | MEDIUM | Replay old test definitions against new component; budget 1 sprint of test backfill |
| MTC semantic loss (P5) | HIGH | Build sibling components (`MintFreshnessTrace` etc.) and re-migrate affected surfaces; user-visible UI churn |
| Bloom jitter (P6) | LOW | Switch BloomStrategy default to `never` in feed contexts via remote config |
| Audio variant verbosity (P7) | MEDIUM | Rewrite the 9 templated sentences; ship via ARB hotfix |
| Cursor precedence ambiguity (P8) | LOW | Add precedence cascade in code; deploy backend |
| ComplianceGuard miss (P9) | HIGH if FINMA, MEDIUM otherwise | Hot-patch guard rules; manual audit of last 30 days of N4/N5 outputs; potential disclosure |
| `chiffre_choc` leakage (P10) | LOW | One-PR sweep + CI gate |
| Regional validator missing (P11) | MEDIUM | Descope to one canton honestly; ship others in v2.3 |
| Backend regional dual-system (P12) | MEDIUM | ADR + delete duplication; one source wins |
| AAA contrast collision (P13) | MEDIUM | Per-element decision: bend brand or descope to AA on that element; document |
| Live tests too late (P14) | MEDIUM | Descope AAA claim publicly; commit to v2.3 retest |
| Editorial drift (P15) | MEDIUM | Quarterly audit + lint rule + spec ownership |
| MTC sortable abuse (P16) | MEDIUM | Compliance review of any future feature touching MTC; API hardening retroactive |
| Sample size 30 (P17) | LOW | Re-run validation with frozen 50-phrase set |
| ARB fallback undefined (P18) | LOW | Pick a policy + implement; cheap |
| Phase 0 bloat (P19) | LOW | Cut to ≤5 deliverables on day 1 |
| Bloom vestibular (P20) | LOW | One-line MediaQuery check |

---

## Pitfall Ranking (Likelihood × Severity, Top 10)

| Rank | Pitfall | L | S | Combined | Phase |
|---|---|---|---|---|---|
| 1 | P1 — Tone-locking (Claude can't actually do N4) | H | H | **CRITICAL** | L1.6a/b |
| 2 | P3 — N5 cap is editorial, not technical | H | H | **CRITICAL** | L1.6a/c |
| 3 | P9 — N4/N5 + ComplianceGuard prescription drift | H | H | **CRITICAL** | L1.6a/b |
| 4 | P2 — Context bleeding across turns | H | M | **HIGH** | L1.0/L1.6c |
| 5 | P4 — MTC migration silent test coverage loss | H | M | **HIGH** | L1.2a |
| 6 | P5 — MTC not 1:1 (freshness vs confidence vs OCR conflated) | H | M-H | **HIGH** | L1.1 |
| 7 | P13 — AAA contrast 7:1 vs MintColors brand pastels | H | M | **HIGH** | L1.1 |
| 8 | P14 — Live accessibility tests start too late | H | M-H | **HIGH** | L1.0 |
| 9 | P11 — Regional voice validators recruitment | H | M | **HIGH** | L1.0 |
| 10 | P8 — Cursor precedence undefined for edge cases | H | M | **HIGH** | L1.0 |

**Tier 2 (medium-high):** P6 bloom jitter, P7 audio variant, P12 backend regional dual-system, P15 editorial drift, P19 Phase 0 bloat, P20 vestibular.
**Tier 3 (medium-low):** P10 chiffre_choc sweep, P16 sortable trap, P17 sample size, P18 ARB fallback.

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---|---|---|
| P1 Tone-locking | L1.6a + L1.6b | Reverse Krippendorff α on generated outputs ≥0.55; politeness-marker grep on N4 outputs = 0 |
| P2 Context bleeding | L1.0 + L1.6c | Multi-turn eval set with G3→G1 transitions; autocorrelation of consecutive levels ≈ 0 |
| P3 N5 hammering | L1.6a + L1.6c | Replay test on synthetic crisis cluster asserts ≤1 N5/week; auto-fragility integration test |
| P4 MTC coverage loss | L1.2a (before L1.2b) | lcov delta ≥0% on `confidence_scorer.dart` consumers |
| P5 MTC semantic loss | L1.1 (before L1.2) | `AUDIT_CONFIDENCE_SEMANTICS.md` exists with all 40 hits classified |
| P6 Bloom jitter | L1.2a | Galaxy A14 manual scroll perf gate <5% dropped frames |
| P7 Audio variant | L1.2a | Live test transcript review by malvoyant·e tester |
| P8 Cursor precedence | L1.0 | 64+ unit tests on `resolveLevel`; property test 0 unsatisfiable inputs |
| P9 ComplianceGuard drift | L1.6a + L1.6b | 50-phrase adversarial corpus pass rate ≥98% |
| P10 chiffre_choc sweep | L1.0 | `git grep` returns 0 in lib/ app/ l10n/ |
| P11 Regional validators | L1.0 | Named humans + dates in `L1.4-validators.md` by end of Phase 0 |
| P12 Backend regional dual-system | L1.0 + L1.4 | ADR exists; no string duplication grep |
| P13 AAA contrast | L1.1 | `AUDIT_CONTRAST_MATRIX.md` exists; per-element decisions logged |
| P14 Live tests late | L1.0 | Named testers + scheduled session dates by end of Phase 0 |
| P15 Editorial drift | L1.6 + post-milestone | `@meta level:` lint rule active; quarterly α audit cadence committed |
| P16 MTC sortable | L1.2a | Public API has no comparable scalar; grep gate on `.compareTo` against confidence |
| P17 Sample size | L1.6b | Frozen 50-phrase test set committed pre-validation; per-level α reported |
| P18 ARB fallback | L1.4 | CI sibling-key check; debug fallback warning |
| P19 Phase 0 bloat | L1.0 | ≤5 deliverables; ≤2 weeks budget |
| P20 Vestibular bloom | L1.2a | Widget test with `disableAnimations: true` |

---

## Sources

- **Codebase grep evidence (HIGH confidence)** — verified 2026-04-07:
  - `chiffre_choc | chiffreChoc` → 30+ files including `coach_orchestrator.dart`, `intent_screen.dart`, `screen_registry.dart`, ARB files for 6 languages, journey tests for 8 personas.
  - `confidence_scorer | EnhancedConfidence | confidenceBadge` → 40+ files spanning extraction, freshness, plan generation, hero stat resolution, trajectory views.
  - `RegionalVoiceService | forCanton | REGIONAL IDENTITY` → confirms dual layer already exists (Flutter service + backend system prompt block in `claude_coach_service.py`).
- **MINT internal docs:**
  - `CLAUDE.md` §6 (compliance — no advice, no ranking, banned terms), §7 (UX — i18n hard rule), §9 (anti-patterns).
  - `visions/MINT_DESIGN_BRIEF_v0.2.3.md` (5-level cursor spec, garde-fous, 6 décisions ouvertes).
  - `visions/MINT_DESIGN_BRIEF_RED_TEAM.md` (the audits this file does NOT repeat).
  - `.planning/PROJECT.md` (locked decisions for v2.2).
- **External / prior art (MEDIUM-LOW confidence — training-data dependent):**
  - LLM register-modulation literature is sparse. Cleo's own writing ([Cleo Roast Mode blog](https://web.meetcleo.com/blog/the-money-app-that-roasts-you)) mentions persona work but doesn't disclose technique. Inferred prior art: Anthropic's own guidance on tone steering favors few-shot over zero-shot instructions.
  - WCAG 2.1 SC 2.3.3 (Animation from Interactions, AAA), 2.2.2 (Pause Stop Hide), 1.4.6 (Contrast Enhanced 7:1 AAA).
  - Krippendorff's α: convention "tentative" ≥0.67, "ship-ready" ≥0.80 (Krippendorff 2004).

---

*Pitfalls research for: v2.2 La Beauté de Mint — voice cursor + MTC + regional carve-out retrofit*
*Researched: 2026-04-07*
