---
date: 2026-05-10
status: Decided
decided_at: 2026-05-10
authors: PM Claude (Product Leader, autonomous orchestration mode per Julien 2026-05-10) + 3-panel synthesis
panel: 3-pers (95-architect / 96-ux-flutter / sequencing-compliance)
supersedes: —
superseded_by: —
description: Master synthesis of Phase 95 (DAG-INVALIDATION) + Phase 96 (CHAT-AS-VERB) autonomous-execution sequencing. Acts as the answer sheet for /gsd-discuss-phase 95/96 --auto chains. Driven by Julien's 2026-05-10 directive « tu orchestres, tu réponds toi aux questions de GSD, vous avancez en parfaite autonomie 94.1, 95, 96 ».
related:
  - .planning/decisions/2026-05-10-phase-95-architect-panel.md
  - .planning/decisions/2026-05-10-phase-96-ux-panel.md
  - .planning/decisions/2026-05-10-phase-95-96-sequencing-compliance-panel.md
  - .planning/decisions/2026-05-09-calc-first-llm-illumination.md
  - .planning/ROADMAP.md
  - .planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md
---

# 95 + 96 autonomous-execution master synthesis

## TLDR

Phase 95 ships in **2 waves (~2+2d)** : (W1) `inputs_hash` SHA256(JCS+Decimal2) + `superseded_by` UUID7 + nullable migration on the 4 projection models ; (W2) `ProjectionGroundingPack` Pydantic v2 emission by `financial_core/` wrappers + double-lookup substitution in `_substitute_placeholders()` with `CITATION_REGISTRY` fallback. Pareto = 3-point scalarisation only, Sobol → backlog 999.x, credible intervals = bootstrap fréquentiste. Phase 96 ships in **3 waves (~2+2+1d)** : (W1) Flutter `MintCardActionBar` + `MintChatOverlay` + chat-tab kill behind `FeatureFlags.chatTabVisible` ; (W2) Backend `SerializedCardContext` + `turn_count` server-side cap + Sentry metric ; (W3) `NarrativeSleeve` envelope + hook linter middleware + metaphor TOML library + Maestro G1 flow. Strict sequential per Julien's directive — Phase 95 PR merges first, Phase 96 rebases on top. Pre-merge gates : 4 compliance lints + 3 stop-condition tripwires.

## Context

Julien 2026-05-10 — « ensuite j'aimerais que tu sois complètement autonomes, tu orchestres, tu réponds toi aux questions de GSD, aux éventuelles questions qui arrivent. Tu es l'expert, tu es le product manager, si tu as des doutes, tu veux prendre un panel d'experts qui peuvent faire appel à tes agents qui sont eux-mêmes experts, et vous avancez comme ça un maximum, c'est-à-dire au moins 94.1, 95, 96, en parfaite autonomie » + « même pour les railway prod mutation, les force push et un recovered failure, tu peux faire appel à ton expertise ou à des panels d'experts. Tu as tous les droits. Mais je veux vraiment que tu respectes le workflow GSD ».

Translation : autonomous loop 94.1 → 95 → 96, full authority including Railway prod mutations + force-push + failure recovery (all gated by expert panels when uncertain), but strict GSD workflow (discuss → plan → execute → verify chain) for 95 + 96.

## Phase 95 — answer sheet for `/gsd-discuss-phase 95 --auto`

### Scope (locked)

| Question | Decision | Rationale source |
|----------|----------|------------------|
| `inputs_hash` algorithm | SHA256 of canonical JSON via `jcs` (RFC 8785) ; floats quantized to `Decimal(places=2)` before canonicalisation | 95-architect §1 |
| `inputs_hash` Python/Dart parity | Test fixture `tests/fixtures/hash_parity_50.jsonl` — 50 inputs hashed Python-side AND via `dart compile exe` calc_harness, equality asserted | 95-architect §1 + 92.5 calc_harness pattern |
| `superseded_by` ID format | UUID7 via `uuid.uuid7()` (Python 3.12+, RFC 9562) ; stored TEXT(36) in SQLite | 95-architect §2 |
| `superseded_by` migration | ADDITIVE — `ALTER TABLE projections ADD COLUMN inputs_hash TEXT NULL`, `ADD COLUMN superseded_by TEXT NULL` ; zero default-value backfill ; existing rows are `NULL` until the next projection touch | 95-architect §2 + sequencing-panel §2 |
| `GroundingPack` model name | `ProjectionGroundingPack` (Pydantic v2 `frozen=True, extra="forbid"`) | 95-architect §3 |
| `GroundingPack` shape | `inputs_hash: str` + `entries: dict[str, GroundingPackEntry]` (key→value+raw+source_ref+credible_low+credible_high+staleness_iso) + `pareto_points: list[ParetoPoint]` + `what_ifs: dict[str, GroundingPackEntry]` + `legal_constraints: list[str]` | 95-architect §3 |
| Pareto algorithm | 3-point scalarisation on 3 leviers (3a / rachat-LPP / amortissement-indirect) with 3 fixed pondérations (fiscal-pure / liquidity-prioritized / ruin-reduction-prioritized) ; produces exactly 3 `ParetoPoint` entries | 95-architect §4 |
| Sobol | OUT OF SCOPE — substituted with uni-variate sensitivity (±10% per input → 5 `what_ifs` entries). True Sobol → backlog 999.x when UI surface exists | 95-architect §5 |
| Credible intervals | Bootstrap fréquentiste 200 iterations on existing Monte Carlo ; P5/P95 → `credible_low` / `credible_high`. Narrator MUST annotate « selon le modèle simplifié actuel » when emitting bracketed numbers (anti-promise per LSFin) | 95-architect §6 |
| Plan count + wave split | 2 plans, 2 waves (W1 hash+migration ~2d, W2 emission+double-lookup ~2d). NO third wave for verification — verifier is a separate cycle | 95-architect §7 |
| `CITATION_REGISTRY` migration | KEEP intact in Phase 95. `_substitute_placeholders()` does double-lookup : try `GroundingPack.entries` first, fall back to `CITATION_REGISTRY.resolve()`. The registry is removed in Phase 96 (deferred until both paths are proven live on staging) | 95-architect §3 + §7 + sequencing-panel §1 |

### Pre-merge gates (Phase 95)

1. **Banned-terms lint** — `tools/checks/banned_terms_python.py` extended to scan `prompt_fragment:` string constants in any new bundle ; lefthook pre-commit + CI
2. **PII scan** — `tools/checks/pii_fixture_scan.py` greps AHV + phone patterns on every JSONL before commit
3. **`no_legal_admission_in_public_docs.py`** — already wired ; verify it runs on ADR commits
4. **`accent_lint_fr.py`** — every `prompt_fragment: str` exits 0
5. **`hash_parity_50.jsonl`** — 50/50 fixtures show byte-identical hash Python vs Dart-compiled harness
6. **G4 regression suite** — backend pytest ≥6441 baseline (Phase 94 baseline 6436 + Phase 94.1 +5 expected = 6441 ; Phase 95 adds ~30 tests = ≥6471 post-95)
7. **G5 schema migration** — alembic upgrade head + downgrade head both run clean on a clone of the staging DB snapshot
8. **G1 Maestro** — N/A for 95 (backend-only); deferred to 96

### Risks tracked (Phase 95)

- R1 — float-hash parity failure between Python+Dart. Mitigation : centime/bps integer scaling fallback documented in plan ; `hash_parity_50.jsonl` test gate.
- R2 — scope creep into Sobol/NSGA-II. Mitigation : hard PLAN.md boundary ; CI gate ≤2 min wall-clock to fail-fast scope inflation.
- R3 — registry-to-pack migration breaks the 18 keys from Phase 94. Mitigation : double-lookup cohabitation ; `CITATION_REGISTRY` removal deferred to Phase 96.

## Phase 96 — answer sheet for `/gsd-discuss-phase 96 --auto`

### Scope (locked)

| Question | Decision | Rationale source |
|----------|----------|------------------|
| Chat-tab kill mechanism | Remove tab index 2 (`tabCoach`) from `MintShell.NavigationBar` behind `FeatureFlags.chatTabVisible = false` (kill-switch reversible). 3-tab nav (Aujourd'hui / Mon Argent / Explorer). GoRouter branch + `CoachChatScreen` route STAY registered for the overlay. `ConversationStore` preserves in-flight state across overlay open/close. | 96-ux §1 |
| Card-actions intent bar | `MintCardActionBar` — inline animated row revealed below the card on tap (48dp expansion, 200ms easeOut). NO bottom sheet. 3 verbs, no more. | 96-ux §2 |
| Verb-set (FR copy) | « Explique-moi / Simule / Rassure-moi » — final | 96-ux §2 |
| Verb routing | « Simule » → deep-link to Explorer (ZERO turns consumed, no LLM). « Explique-moi » + « Rassure-moi » → `MintChatOverlay` modal | 96-ux §2 |
| ARB keys | `verbExplique`, `verbSimule`, `verbRassure` across 6 locales (fr/en/de/es/it/pt) | 96-ux §2 |
| Turn-cap policy | STRICT 3-turn cap, server-side, per `source_card_id` × app-session. NO soft cap, NO extension. At `turn_count >= 3`, backend returns a static FR template + Explorer deep-link, SKIPS the LLM entirely (0 token cost). Reset criterion : per source_card_id × app session | 96-ux §3 |
| Turn-cap instrumentation | Sentry metric `chat_overflow_turn_4` ; alert threshold > 40% sessions over 7-day window ; PRE-flag-flip pull on `chat_turn_distribution` to baseline expected cap-hit rate | 96-ux §3 + sequencing-panel §3 |
| `CoachChatRequest` extension | New optional field `source_card: SerializedCardContext` carrying `card_id`, `card_type`, `computed_facts` (financial_core values only — NO PII), `grounding_keys` (list of `{{cite:<key>}}` candidates from the card), `life_event`, `canton`, `archetype` | 96-ux §4 |
| `NarrativeSleeve` schema | 4 fields : `hook: str` (no digit, regex `\d` → swap fallback), `caption: str` (cited numbers post-substitution), `next_step: str` (verb-first, ≤12 words), `metaphor: str` (static TOML lookup by archetype × canton × event) | 96-ux §4 |
| `NarrativeSleeve` linter | Backend response middleware ; swaps hook on `\d` match, NEVER 500s the response. Run AFTER the citation gate (Phase 94 stays first in the middleware chain) | 96-ux §4 + sequencing-panel §1 |
| Metaphor library | `metaphors.toml` keyed by archetype × canton × event tuple (e.g. `[expat_us.VD.new_baby]`). Bootstrapped with 6-10 entries covering 3 archetypes × 2 cantons × 2 events for v1 ; expandable | 96-ux §5 |
| `GroundingPack` consumption | SOFT dependency — Phase 96 ships with `GroundingPack | None` fallback ; when None, narrator uses `CITATION_REGISTRY` per the Phase 95 double-lookup. Full GroundingPack path goes live only post-Phase 95 merge | sequencing-panel §1 + 96-ux §7 |
| `CITATION_REGISTRY` removal | DEFERRED to a future cleanup phase (post-96). Both paths cohabit during Phase 96 to avoid a 3-way migration race | 95-architect §7 + sequencing-panel §1 |
| Plan count + wave split | 3 plans, 3 waves : W1 Flutter (~2d), W2 Backend (~2d, BLOCKED on 95 merge), W3 cross-stack NarrativeSleeve + Maestro (~1d, BLOCKED on W2). | 96-ux §8-10 |
| G2 device verification | TestFlight sim walkthrough — open card « Mon 3a 2026 », tap « Explique-moi » → MintChatOverlay renders with cited numbers from GroundingPack → user hits 3-turn cap → terminal template + Explorer deep-link fires | 96-ux §G2 |

### Pre-merge gates (Phase 96)

1. **All Phase 95 gates** (banned-terms, PII, legal-admission, accent_lint, hash_parity, regression suite)
2. **`flutter analyze`** — 0 issues on the diff
3. **`flutter test`** — Flutter regression ≥229 baseline + new card-actions/overlay tests
4. **6-locale ARB parity** — `validate_arb_parity()` MCP tool returns clean ; no key in fr/ missing from en/de/es/it/pt
5. **MintColors / MintTextStyles only** — grep for hardcoded `Color(0x` returns 0 in changed files
6. **G1 Maestro `flow_card_action_intent_bar.yaml`** — exit 0 on iPhone 17 Pro sim against staging Railway ; assert the 3-turn cap fires (Sentry breadcrumb `chat_overflow_turn_4`)
7. **G2 Julien sim walkthrough** — surfaced as HUMAN-UAT (per CLAUDE.md §9, Phase 96 cannot claim « ready » without this gate completing OR explicit Julien skip-approval)

### Risks tracked (Phase 96)

- R1 — turn-cap rate is currently unknown ; if real session rate >40% hits the cap, the flag-walkback path activates immediately and Phase 96 ships a net-zero UX change. Mitigation : instrument `chat_turn_distribution` Sentry metric in W2 BEFORE flag-on flip ; baseline 7-day window before any conclusion.
- R2 — `MintChatOverlay` inherits the 57-import coach screen graph (untested render budget on older hardware). Mitigation : measure render time on the simulator ; if >16ms/frame, refactor to lazy-loaded separate route (adds ~3d to W3).
- R3 — `coach_chat.py` is touched by both Phase 95 and Phase 96. Mitigation : strict sequential merge order (95 first, 96 rebases) per Julien's GSD-respect directive ; sequencing-panel stop-condition #2 fires if a conflict appears on both branches simultaneously.

## Sequencing decision

Strict sequential per Julien's « respecter le workflow GSD » directive.

Order : Phase 94.1 (in-flight, background agent `a2f958bdc6c340949`) → verify+close → Phase 95 discuss → plan → execute → verify → close → Phase 96 discuss → plan → execute → verify → close → TestFlight ship preparation (pubspec bump + dev→staging merge).

Parallel-worktree acceleration (sequencing-panel §2) explicitly declined.

## Stop conditions (autonomous loop halts; surface to Julien)

1. **Eval threshold miss >30pp on Phase 94.1 first run** (Sonnet <65% gate-correct when target ≥95%) — structural problem, not prompt iteration. Pause.
2. **`coach_chat.py` merge conflict on Phase 95 AND Phase 96 simultaneously** — parallel-worktree drift indicator. Pause + consolidate manually.
3. **Railway staging health-check non-200 after Phase 95 migration deploy** — schema validation regression possible on existing profiles. Halt. Surface Railway log excerpt. No flag flip, no force-push, no recovery before Julien sees the log.
4. **Anthropic API spend > $200 cumulative this session** — hard cap. Pause, surface cost breakdown, ask continue/halt.
5. **Genuine unrecoverable failure** — any agent reports a failure that isn't `classifyHandoffIfNeeded` (per Claude Code known bug). Convene a 3-expert recovery panel ; if panel can't find a path, surface to Julien with the failure transcript path.

## Compliance gates (cross-phase, pre-merge)

1. **Banned-terms scan** (`tools/checks/banned_terms_python.py`) — every commit on narrator-touching files
2. **PII fixture scan** (`tools/checks/pii_fixture_scan.py`) — every JSONL commit
3. **`no_legal_admission_in_public_docs.py`** — every `.planning/**/*.md` PR diff
4. **`accent_lint_fr.py`** — every `prompt_fragment: str` modification

## 0-trust language audit (pre-merge per phase)

Run before every phase-close commit :
```bash
grep -nE "\b(shipped|livré|closed|fermé|ready|prêt|works|marche|validated|validé|green|PROVISIONALLY READY|MVP working|feature complete)\b" \
  .planning/phases/<phase>/*.md
```
Every match must have a deterministic citation in the same paragraph or be inside an explicit anti-claim (« Does NOT claim … »). Otherwise rewrite.

## Counter-arguments and data gaps

### Counter-arguments

### CA1 — « Why not run 95 + 96 in parallel worktrees to halve wall-clock? »

The sequencing-compliance panel recommended parallel worktrees as feasible. I declined per Julien's strict-GSD directive (« je veux vraiment que tu respectes le workflow GSD »). The GSD workflow is fundamentally sequential per phase per its own `<process>` block in `execute-phase.md`. Parallel execution would also raise the `coach_chat.py` merge-conflict risk (Phase 96 W2 modifies the chat request shape ; Phase 95 W2 modifies the response substitution). Reverting Julien's clear constraint without a stronger reason would itself be a respect-the-workflow violation.

### CA2 — « Why ship `GroundingPack` as a soft dependency instead of hard-blocking Phase 96 until 95 is GO-prod? »

The sequencing-panel made this argument and I accepted it. Hard-blocking would add unnecessary wall-clock dependency : Phase 96 W1 (Flutter UI) has zero `GroundingPack` consumption. Soft dependency lets W1 ship in parallel with Phase 95 W2 emission work. The cost is one if-branch in `_substitute_placeholders()` (`pack.entries.get(k) or CITATION_REGISTRY.resolve(k)`) — trivial, removed cleanly in the future registry-cleanup phase.

### CA3 — « Why not use Bayesian credible intervals instead of bootstrap fréquentiste? »

The 95-architect rejected Bayesian because there's no calibrated prior (Expert 1 from the calc-first ADR puts HMM-based Bayesian in 999.1 backlog). Fréquentiste bootstrap on the existing Monte Carlo is honest about the assumption gap and requires zero new prior calibration. The narrator's mandatory annotation « selon le modèle simplifié actuel » acknowledges the assumption gap to the user — that's LSFin-compliant.

### Data gaps

- DG1 — Phase 94.1 result is unknown at decision time. If thresholds miss >30pp, stop-condition #1 fires and Phase 95 opening is paused while we triage. The master synthesis assumes 94.1 lands but documents the fallback explicitly.
- DG2 — Real-user turn-distribution data does not exist (no logged-in users on prod ; only Maestro/eval synthetic traffic). Phase 96 W2 Sentry instrumentation closes this gap, but the 7-day window means we don't have the data BEFORE Phase 96 W3 starts. We're shipping the 3-turn cap on a hypothesis, not measurement. Mitigation : kill-switch flag lets us walk back fast if instrumented rate > 40%.
- DG3 — Anthropic API budget for the autonomous loop is bounded by stop-condition #4 ($200) but the actual cost trajectory of 3 phases × multiple sub-agents at Opus-1M is uncertain. First execution cycle (Phase 94.1) will provide the calibration baseline.
- DG4 — `hash_parity_50.jsonl` fixtures don't exist yet ; their authoring happens in Phase 95 W1. There's a circular risk : if Python and Dart hash differently, we discover it during Phase 95 execution and may need to refactor the canonicalisation step. Mitigation : architect's centime/bps fallback strategy documented in plan.

## Sources

- `.planning/decisions/2026-05-10-phase-95-architect-panel.md` — full Phase 95 architecture brief
- `.planning/decisions/2026-05-10-phase-96-ux-panel.md` — full Phase 96 UX brief
- `.planning/decisions/2026-05-10-phase-95-96-sequencing-compliance-panel.md` — full sequencing + compliance brief
- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` — N1/N2/N4 strategic pivot (foundation)
- `.planning/ROADMAP.md` — Phase 95 + 96 entries
- `apps/mobile/lib/services/financial_core/` — canonical Dart calculator suite (financial_core SOURCE OF TRUTH per CLAUDE.md rule 4)
- CLAUDE.md §1 banned terms, §2 accents, §9 0-trust, §7 Karpathy 4
- `tools/checks/{banned_terms_python,pii_fixture_scan,no_legal_admission_in_public_docs,accent_lint_fr}.py` — pre-merge lints
