---
description: P003 Pillar 2 Panel output — 5 sub-agent verdicts + synthesis. Per MDM v1 Pillar 2.
type: cycle-panel
bug_id: P003
phase: 97-w7
created: 2026-05-12
---

# P003 — Expert Panel verdicts

5 expert sub-agents spawned in parallel with MDM 8.b briefing preamble. Each
received CONTEXT.md + a role-specific scope. Verdicts received 2026-05-12 morning.

## Verdict matrix

| Role | Verdict | Hypothesis (1 sentence) | Recommended fix scope |
|---|---|---|---|
| LLM Eval Engineer | **GO** | Prompt-code contract violation : citation_grammar.py:147-149 tells narrator user-input numbers are exempt ; gate code has zero user-input awareness. P001 H1's 95%/90% targets are mathematically unreachable on free-text first prompts (the registry has 0 user-input keys). | (A) extract user numbers + exempt in gate ; (B) retry=0 on free-text path ; (C) split eval-pack into free-text vs card-context buckets with realistic targets. |
| Backend Architect | **GO** | Same root cause + plumbing detail : the cleanest insertion point is `coach_chat.py` BEFORE `_initial_loop_kwargs` (line ~3320), capture `body.message` + last N user turns into a frozenset, thread as gate kwarg. Allowlist mutation is the WRONG knob (D-07 closed-world invariant). | (1) per-request `user_input_numbers` extracted + exempted in gate (~25 LOC) ; (2) split flag into `_LEGACY_ENABLED` (default False) + `_VERB_ENABLED` (default True) ; (3) drop the lie at citation_grammar.py:147-149. ~6 files, ~130 LOC + tests. |
| LSFin Compliance Officer | **CHANGE** | Two compliance defects intersect : (a) the prompt-code lie that traps the narrator ; (b) the FALLBACK string itself is an LSFin Art. 8 « information loyale » concern when served to a fully-documented user — pretending ignorance of explicitly-supplied data is a separate honesty defect. | (1) delete the false promise at citation_grammar.py:147-149 ; (2) replace FALLBACK_TEMPLATED_TEXT with an LSFin-safe ack that QUOTES user numbers back (meta-quote → already-exempted) + 1 scoped clarifying question. Requires D-10 amendment ADR. |
| UX Researcher | **CHANGE** | Triple UX failure : (1) generic re-prompt for data the user just supplied verbatim, (2) zero acknowledgement of received content, (3) 30s wait with no streaming affordance. The string sits at sub-N1 voice-cursor (zero observation, zero chiffre, zero contexte, zero action) and breaks MINT_IDENTITY Principle #4 (Prise immediate). | Replace FALLBACK with 2-part : (1) acknowledge facts as structured snapshot bubble (« J'ai noté : 49 ans, Valais, marié, 7'600 CHF/mois … c'est ça ? ») + (2) 2-3 deep-linked life-event angles (simulateur LPP, fiche 3a, simulateur fiscal cantonal). Option (a) hypothetical answer is REJECTED (re-introduces LSFin no-promise risk). |
| Adversarial Tester | **STOP** | All 5 panel-proposed fixes (A-E) assume FACTS that are UNVERIFIED. Key open question : did the narrator emit Julien's numbers (then gate replaced them with FALLBACK) OR did the narrator emit the fallback string ITSELF (because citation_grammar.py:119-120 literally teaches it to write « je n'ai pas cette donnée » when no key fits) ? Both produce the same user-visible behavior but need DIFFERENT fixes. Disabling the gate (A) might change NOTHING if the narrator self-fallbacks. | NONE — adversarial role. The correct next step is L3 staging-log inspection BEFORE picking a fix. Choosing any of A-E now is premature commitment that violates CLAUDE.md §9.4 sim-survival test. |

## Convergence + divergence

**Where all 5 agents converge :**
- The system-prompt fragment at `citation_grammar.py:147-149` is a known lie : it tells the narrator user-input numbers can be emitted bare ; the gate has no matching exemption. All 5 agents identified this as a defect (root cause OR a separate defect).
- The fallback emission, whatever the path, is user-visibly broken.
- The 30s wall-time is a symptom of either 2-LLM-call retry cascade (4 of 5 agents) OR the narrator's own latency on a hard prompt (adversarial dissent — possible if the narrator self-fallbacks).
- Disabling the gate (option A) is the SIMPLEST fix per Karpathy #2, but ALL 5 agents flag it as risky : reopens LSFin compliance hole + does not address the root structural issue.

**Where the panel diverges (genuine disagreement per `feedback_expert_panel_pattern`) :**
- **What to do with FALLBACK_TEMPLATED_TEXT** : Backend Architect + LLM Eval want to KEEP the string and add user-input awareness so it fires less often. LSFin Compliance + UX Researcher want to REPLACE the string with an acknowledgement-plus-angles payload. These are NOT mutually exclusive but the immediate work order matters.
- **Whether to split the flag** : Backend Architect proposes `_LEGACY_ENABLED` + `_VERB_ENABLED`. LLM Eval proposes a similar bimodal target split but at the eval-pack scoring level, not the flag level. Adversarial tester critiques flag-split as creating a two-tier compliance regime that confuses LSFin auditors.
- **Whether to fix BEFORE or AFTER L3 verification** : Adversarial says STOP and verify. The other 4 implicitly assume the gate-replaces-output mechanism is true. This is the critical divergence to resolve in Pillar 3.

## Synthesis (this assistant's reading of the panel)

The adversarial agent is correct on the procedural point : MDM Pillar 3 (Repro Ladder) is mandatory before Pillar 5 (Fix Design). Skipping L3 to commit to a fix would replay the 2026-05-12 morning mistake (8 hours of peripheral hygiene work while the core flow was broken — and never repro'd).

However, the 4 other agents converge on the same structural defect at `citation_grammar.py:147-149`, with deterministic citation (the file lines are in CONTEXT.md F7). Even WITHOUT L3, that line is a known defect — the system prompt tells the narrator something the gate doesn't enforce. Fixing that line is unconditionally correct regardless of which root cause hypothesis is true.

So the panel synthesizes into a **TWO-STEP commitment** :

1. **Step 1 — L3 verification (Pillar 3)** : capture the actual narrator output on staging for Julien's verbatim prompt. This answers : did the gate replace the output, or did the narrator self-fallback ?

2. **Step 2 — Fix Design (Pillar 5)** : conditional on L3 result.
   - **If L3 shows gate replaced narrator output** (4-agent hypothesis) : implement Backend Architect's two-part fix (user-input awareness + flag split) PLUS LSFin/UX changes to FALLBACK_TEMPLATED_TEXT.
   - **If L3 shows narrator self-fallbacked** (Adversarial hypothesis) : the citation_grammar.py system prompt is the dominant defect. Rewrite the grammar fragment to stop instructing the narrator to emit the fallback verbatim. Then re-measure.
   - **In BOTH cases** : citation_grammar.py:147-149 lie is fixed unconditionally.

## Open questions remaining after Panel

1. **L3 staging log access** : how do I read Railway logs for a specific request_id ? Memory `project_remote_control.md` references Mac mini access but not Railway. Need to either (a) curl staging directly with a test auth token and inspect the response + Sentry trace, OR (b) ask Julien for the request_id from his sim and a Railway login.
2. **Flag state on staging** : need to confirm `COACH_CITATION_GATE_ENABLED` is currently True on Railway staging. Per F5 the P001 W7 iter#11 notes say it stays ON, but that was 2026-05-11T21:30Z — flags can drift.
3. **Anonymous chat path comparison** : if I curl the same prompt against `/api/v1/anonymous/chat` (different endpoint, different gate path), does it return the same fallback ? Would help differentiate which middleware is responsible.

## Cycle next steps

- Pillar 3 L1 — unit test : run `_citation_gate` against a synthetic narrator output containing Julien's 4 numbers verbatim ; verify FALLBACK fires deterministically.
- Pillar 3 L3 — curl staging with Julien's exact prompt. Capture (a) HTTP status, (b) response body, (c) wall-time, (d) `gate_correct` Sentry breadcrumb. THIS is the GO/NOGO check that resolves the adversarial-flagged open question.
- Pillar 4 RCA — write up hypotheses with the L3 result as the discriminator.
- Pillar 5 Fix Design — score the 5 candidates (A-E from adversarial critique) plus the LSFin/UX hybrid options. Defer pick until L3 lands.
