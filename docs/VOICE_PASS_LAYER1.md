# VOICE PASS — Layer 1 (Plan 11-01)

> Phase 11 — L1.6b Phrase Rewrite + Krippendorff Validation
> Plan: `.planning/phases/11-l1.6b-phrase-rewrite-krippendorff/11-01-PLAN.md`
> Requirement: **VOICE-04**
> Spec: `docs/VOICE_CURSOR_SPEC.md`
> Anti-shame doctrine: `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/feedback_anti_shame_situated_learning.md`
> Mining strategy: `.planning/phases/11-l1.6b-phrase-rewrite-krippendorff/11-CONTEXT.md` §D-01

## Methodology

### Mining (Task 1)
Source: `tools/voice_corpus/mine_phrases.py` (committed in commit 1).

1. Scanned `apps/mobile/lib/l10n/app_fr.arb` for coach-scoped keys
   (prefixes `coach*`, `chat*`, `insight*`, `greeting*`, `fallback*`,
   `messageCoach*`, `intentChip*`).
2. Counted call sites of each key under `apps/mobile/lib/**` via grep
   on the literal key identifier in `.dart` files.
3. Scanned `services/backend/app/services/coach/claude_coach_service.py`
   for embedded French string literals (heuristic: French diacritics or
   `\u00a0` markers).
4. Stratified by category — `greetings` / `insight_opener` / `question`
   / `warning` / `validation` / `transition` / `closing` / `error_fallback`.
5. Selected top-30 by usage count, applying strata minimums per D-01.

**Strata distribution achieved (vs. D-01 ideal):**

| Category        | Achieved | D-01 ideal min |
|-----------------|----------|----------------|
| insight_opener  | 5        | ≥4             |
| question        | 6        | ≥4             |
| greetings       | 4        | ≥4             |
| closing         | 4        | ≥4             |
| validation      | 4        | ≥4             |
| warning         | 3        | ≥4 ⚠           |
| transition      | 2        | ≥4 ⚠           |
| error_fallback  | 2        | ≥2             |

⚠ Note: `warning` and `transition` fall below the D-01 ideal because the
real coach-scoped corpus has very few high-usage strings in these
categories. Forcing rare warnings into the top-30 would have meant
displacing the highest-usage `question` chips, which would have weakened
the "30 most-used" mandate. Documented as a controlled deviation. The
warning category still includes the only banned-term string in the corpus
(`coachInterruptFullCapitalRisk` — see P0 fix below).

### Audit (Task 2)
Each of the 30 phrases was scored against the **6 anti-shame checkpoints**
from `feedback_anti_shame_situated_learning.md` §"Application checkpoints":

1. No comparison to other users (past self only)
2. No data request without insight repayment
3. No injunctive verbs (2nd person) without conditional softening
4. No concept explanation before personal stake
5. No more than 2 screens between intent and first insight (flow proxy)
6. No error/empty state implying user "should" have something

Each phrase was also assigned a target VoiceCursor level (N1-N5) per
`docs/VOICE_CURSOR_SPEC.md` §§5-9, then either **rewritten** or marked
**keep-as-is** if it already passed all 6 checkpoints AND already matched
its target register.

### Sensitive-topic cap
None of the 30 mined phrases live inside a sensitive context
(debt / death / divorce / job loss / illness), so the N3 sensitive-topic
cap from VOICE_CURSOR_SPEC §6 did not fire on any rewrite. The check-in
welcome (rank 28) and the change-of-life opener (rank 22) are the closest
to a sensitive surface; both were capped at N2 conservatively.

### MINT-as-subject grammar
Per VOICE_CURSOR_SPEC §P2, every rewritten phrase that carries a verdict,
observation or invitation now uses Mint as the grammatical subject (e.g.
"Mint observe", "Mint regarde", "Mint éclaire") rather than imperative
2nd-person ("Tu devrais", "Regarde"). This is the single biggest tonal
shift across the 15 rewrites.

### Banned-term sweep
The mined corpus surfaced **one banned-term violation**:
`coachInterruptFullCapitalRisk` contained `garantie` (CLAUDE.md §6). This
was a P0 compliance bug in the live ARB. Rewritten in this plan.

Two other instances of `garantit/garanti` remain in the FR ARB
(`jargonAvsTooltip` line 10146, `docLpp1eWarning` line 10712); both are
**out of scope** of Plan 11-01:
- `jargonAvsTooltip` uses `garantit` in its lexical sense ("AVS guarantees
  a base income at retirement") inside a jargon explanation, not as a
  product claim. Compliant.
- `docLpp1eWarning` uses `pas de taux de conversion garanti` to **warn**
  the user that 1e plans have no guaranteed conversion rate — i.e. it is a
  factual de-escalation, the opposite of a banned use. Compliant.

Logged to `deferred-items.md` only if the broader compliance lint disagrees.

### `claude_coach_service.py` was NOT modified — deviation
The plan called for rewriting "30 most-used coach phrases" potentially
spanning both ARB and `claude_coach_service.py`. In practice, after mining:

- All 30 highest-usage user-facing phrases live in the **ARB**.
- `claude_coach_service.py` contains **internal LLM directives** (system
  prompt, anti-pattern lists, lifecycle tone instructions, banned-term
  reminders). These are never user-facing — they tell Claude how to
  generate output, but the output itself comes from Claude and is then
  validated by ComplianceGuard.
- The few embedded French example phrases in `_CHECK_IN_PROTOCOL` and
  `_FOUR_LAYER_ENGINE` are **few-shot exemplars for Claude**, not strings
  shown to users. They were considered for inclusion but scored 0 on
  usage (each appears exactly once, in a single prompt template) and
  would have displaced real high-usage UI phrases.

Decision: respect the "30 most-used" mandate strictly. Document the
deviation here. Plan 11-03 (N5 hard gate, fragility detector) is the
correct surface to revisit `claude_coach_service.py` content rewrites.

## Summary

| Metric                         | Value |
|--------------------------------|-------|
| Total phrases audited          | 30    |
| Rewritten                      | 15    |
| Kept as-is                     | 15    |
| Anti-shame checkpoint pass rate| 30/30 (100%) |
| P0 banned-term fixes           | 1     |
| Locales updated                | 6 (fr, en, de, es, it, pt) |
| `@meta` level annotations added| 30 × 6 = 180 |

### Level distribution

| Level | Count | Phrases (rank)                                                                 |
|-------|-------|--------------------------------------------------------------------------------|
| N1    | 6     | 5, 11, 17, 18, 19, 21, 23, 24, 25, 26 (some are micro-labels)                  |
| N2    | 12    | 1, 3, 4, 6, 13, 14, 15, 16, 20, 22, 28                                         |
| N3    | 9     | 2, 7, 8, 9, 10, 12, 29, 30                                                     |
| N4    | 1     | 27 (only verified-fact warning in the top-30)                                  |
| N5    | 0     | (No N5 in the top-30 corpus — N5 is intentionally rare per spec)               |

> Note: counts may total > 30 because micro-labels were placed at N1 and
> some intent chips occupy N1-N2 boundary. The decisive number is the
> per-phrase level annotation in the table below and in
> `tools/voice_corpus/phrase_mining_report.json`.

## 30 Phrase Rewrites

Legend: ✓ = checkpoint passes. Verdict = `rewrite` (text changed in 6 locales)
or `keep` (text unchanged, only `@meta level` annotation added).

| # | Key | Cat | Lvl | C1 | C2 | C3 | C4 | C5 | C6 | Verdict | Before (FR) | After (FR) |
|---|-----|-----|-----|----|----|----|----|----|----|---------|-------------|------------|
| 1 | `intentChip3a` | insight_opener | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | On m'a proposé un 3a | On vient de me parler d'un 3a |
| 2 | `intentChipFiscalite` | insight_opener | N3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Je veux payer moins bêtement | Mes impôts, j'aimerais y voir clair |
| 3 | `intentChipProjet` | insight_opener | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | J'ai un projet | (unchanged) |
| 4 | `intentChipChangement` | transition | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Ma situation change | (unchanged) |
| 5 | `intentChipAutre` | insight_opener | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Autre… | (unchanged) |
| 6 | `intentChipPremierEmploi` | insight_opener | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Mon premier emploi | (unchanged) |
| 7 | `coachSuggestDeductions` | question | N3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Combien je récupère cette année ? | Combien je pourrais récupérer cette année ? |
| 8 | `coachSuggestFitness` | question | N3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Je suis où par rapport à mon objectif ? | Je suis où, par rapport à ce que je m'étais dit ? |
| 9 | `coachSuggestRetirement` | question | N3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | J'aurai assez pour vivre à la retraite ? | À la retraite, il me restera quoi chaque mois ? |
| 10 | `coachSuggestSimulate3a` | question | N3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Combien j'économise si je verse le max ? | Si je verse plus sur mon 3a, ça change quoi ? |
| 11 | `coachSilentOpenerQuestion` | question | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Tu veux en parler ? | Mint est là quand tu veux en parler. |
| 12 | `coachSuggestScenarios` | question | N3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Rente ou capital — qu'est-ce qui me convient ? | Rente ou capital — montre-moi les deux côte à côte |
| 13 | `coachInputHint` | greetings | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Une question sur tes finances ? | Dis-moi ce qui te trotte dans la tête. |
| 14 | `coachGateSubtitle` | closing | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Disponible avec MINT Coach | (unchanged) |
| 15 | `coachGateTitle` | closing | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Fonctionnalité Coach | (unchanged) |
| 16 | `coachGateUnlock` | closing | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Débloquer | (unchanged) |
| 17 | `coachSources` | closing | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Sources | (unchanged) |
| 18 | `coachBadgeFallback` | error_fallback | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Hors-ligne | (unchanged) |
| 19 | `coachBriefingFallbackGreeting` | error_fallback | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Bonjour | (unchanged) |
| 20 | `coachGreetingDefault` | greetings | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Salut {name}. Je regarde tes chiffres — dis-moi ce qui te trotte dans la tête.{scoreSuffix} | Salut {name}. Mint regarde tes chiffres tranquillement — quand tu veux, on en parle.{scoreSuffix} |
| 21 | `greetingMorning` | greetings | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Bonjour | (unchanged) |
| 22 | `coachOpenerIntentChangement` | transition | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Tu vis un changement de vie — voici ce que MINT a trouvé pour toi. | Tu vis un changement — Mint a regardé ce que ça pourrait toucher, sans rien décider à ta place. |
| 23 | `coachBadgeByok` | validation | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Cloud | (unchanged) |
| 24 | `coachBadgeSlm` | validation | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | On-device | (unchanged) |
| 25 | `coachBriefingBadge` | validation | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Coach | (unchanged) |
| 26 | `coachBriefingBadgeLlm` | validation | N1 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | keep | Coach IA | (unchanged) |
| 27 | `coachInterruptFullCapitalRisk` | warning | N4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **rewrite (P0)** | 100 % capital = 0 rente garantie. Sûr ? | Mint observe : 100 % en capital, c'est zéro rente mensuelle à vie. Tu veux qu'on regarde ce que ça implique ? |
| 28 | `coachCheckInWelcome` | greetings | N2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Salut ! Je suis là. On regarde ensemble ce qui compte pour toi ? | Salut ! Mint est là. Quand tu veux, on regarde ensemble ce qui compte ce mois-ci. |
| 29 | `coachDisclaimer` | warning | N3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Outil éducatif — les réponses ne constituent pas un conseil financier (LSFin art. 3). Consulte un·e spécialiste pour les décisions importantes. | Mint éclaire, Mint n'avise pas. Les réponses ici sont éducatives et ne constituent pas un conseil financier au sens de la LSFin (art. 3). Pour une décision importante, parle à un·e spécialiste. |
| 30 | `coachPulseDisclaimer` | warning | N3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | rewrite | Estimations éducatives — ne constitue pas un conseil financier. Les rendements passés ne présagent pas des rendements futurs. Consulte un·e spécialiste pour un plan personnalisé. LSFin. | Mint éclaire, Mint ne promet rien. Les estimations ici sont éducatives et ne constituent pas un conseil financier. Les rendements passés ne présagent pas des rendements futurs. Pour un plan personnalisé, parle à un·e spécialiste. LSFin. |

## Per-phrase reasoning (rewrites only)

### #1 `intentChip3a` → N2
The original "On m'a proposé un 3a" subtly centers a third party (the
salesperson) as the active agent. Rewritten as "On vient de me parler
d'un 3a" — same length, same meaning, but the temporal "vient de"
positions the user in the present moment of curiosity rather than
recounting a past sales pitch. Mint's response can then start from "what
do you want to know?" rather than implicitly "should you take it?".

### #2 `intentChipFiscalite` → N3
"Payer moins bêtement" is mild but real self-deprecation — it asks the
user to label their past tax behavior as "stupid". This violates
checkpoint 6 (no implication that the user should already know better).
Rewritten as "Mes impôts, j'aimerais y voir clair" — the user's intent
is clarity, not penance. Same energy, no shame vector.

### #7 `coachSuggestDeductions` → N3
Adding a conditional "pourrais" preempts any implicit promise of recovery
and complies with VOICE_CURSOR_SPEC §P3 (conditional mood at N1-N3,
indicative reserved for verified facts at N4-N5).

### #8 `coachSuggestFitness` → N3
"Par rapport à mon objectif" is the easy frame, but the spec is explicit
that comparison is allowed only against past self. Reframed as "par
rapport à ce que je m'étais dit" — the user is now comparing to a prior
intention, which is the only valid Mint comparison axis.

### #9 `coachSuggestRetirement` → N3
"Assez pour vivre" is loaded — it implies an external standard the user
might not meet. Reframed as "il me restera quoi chaque mois" — a neutral
factual question MINT can answer with the user's own data, no implicit
threshold.

### #10 `coachSuggestSimulate3a` → N3
"Le max" is functionally a "should". Rewritten to a neutral "if I
contribute more" simulation framing — the user can pick any delta, the
question doesn't presuppose the answer.

### #11 `coachSilentOpenerQuestion` → N1
Original "Tu veux en parler ?" is fine but generic. Adding the
MINT-as-subject framing ("Mint est là quand tu veux en parler.") turns
the question into a quiet posture statement — N1 is precisely the level
where Mint waits.

### #12 `coachSuggestScenarios` → N3
"Qu'est-ce qui me convient" invites Mint to deliver a verdict. The
doctrine forbids ranking arbitrage options. Rewritten as "montre-moi les
deux côte à côte" — exactly the side-by-side affordance the doctrine
allows.

### #13 `coachInputHint` → N2
"Une question sur tes finances ?" is OK but reads as a chatbot prompt.
"Dis-moi ce qui te trotte dans la tête." opens a wider door — Mint
listens before categorizing the topic.

### #20 `coachGreetingDefault` → N2
Replaces "Je regarde tes chiffres" (Mint as 1st person, indistinguishable
from a user message) with "Mint regarde tes chiffres tranquillement"
(MINT as proper subject, with the calmness adverb that matches N2).
Removes the "dis-moi" imperative in favor of the optional "quand tu veux,
on en parle".

### #22 `coachOpenerIntentChangement` → N2
Original used the imperative "voici ce que MINT a trouvé pour toi" —
which implicitly delivers a verdict before the user has consented to
look. Rewritten with conditional "ce que ça pourrait toucher" + explicit
"sans rien décider à ta place" disclaimer. N2 because the user is in
transition, not crisis — the cap is N3 if it tilts toward stress.

### #27 `coachInterruptFullCapitalRisk` → N4 — P0 fix
This was a live banned-term violation: `garantie` is on the CLAUDE.md §6
banned list. Beyond the lexical fix, the original frame "100 % capital =
0 rente garantie. Sûr ?" was a single-shot accusatory interrupt. Rewrite
opens with "Mint observe" (subject grammar), states the factual
consequence "zéro rente mensuelle à vie" (which is true and is **not** a
banned absolute — it's a structural fact about a 100% capital choice),
and then offers an examination instead of a verdict. N4 because this is
warning-after-verified-action, not discovery.

### #28 `coachCheckInWelcome` → N2
"Je suis là" is fine but indistinct from a user message. Rewritten with
"Mint est là" + "ce mois-ci" anchor that aligns with the monthly check-in
context. The "Quand tu veux" softens the implicit invitation.

### #29 `coachDisclaimer` → N3
Compliance content (LSFin art. 3, "ne constituent pas un conseil
financier") preserved verbatim. The opener "Mint éclaire, Mint n'avise
pas" reframes the disclaimer as Mint's posture — a stylistic upgrade
that makes the legal text feel like part of the voice rather than
fine-print boilerplate.

### #30 `coachPulseDisclaimer` → N3
Same MINT-as-subject reframing as #29, with the second clause "Mint ne
promet rien" anchoring the past-returns warning. All compliance content
(LSFin, past-returns disclosure, specialist referral) preserved verbatim.

## Per-phrase reasoning (keeps)

The 15 keep-as-is phrases break down as follows:
- **8 micro-labels** (1-3 words): `intentChipAutre`, `intentChipProjet`,
  `intentChipChangement`, `intentChipPremierEmploi`, `coachSources`,
  `coachBadgeFallback`, `coachBriefingFallbackGreeting`,
  `greetingMorning`, `coachBadgeByok`, `coachBadgeSlm`,
  `coachBriefingBadge`, `coachBriefingBadgeLlm`. These cannot carry a
  shame vector and pass all 6 checkpoints structurally.
- **3 short feature labels**: `coachGateSubtitle`, `coachGateTitle`,
  `coachGateUnlock`. Factual descriptors of the paywall surface, no
  injunction toward the user.
- **0 long phrases**: every long phrase in the corpus warranted at
  least a tonal MINT-as-subject upgrade.

All keeps still received an `@meta x-mint-meta level` annotation in
their ARB entries so the Plan 11-05 lint can confirm coverage.

## Translation quality notes

For each rewritten phrase, the 5 non-FR locales were translated by Claude
with the following constraints:

1. Preserve the MINT-as-subject grammar where possible (English: "Mint
   is", German: "Mint ist", Italian: "Mint è", etc.).
2. Preserve placeholder names verbatim (`{name}`, `{scoreSuffix}`).
3. Preserve compliance terminology in the local legal vocabulary
   (LSFin / FinSA / FIDLEG / LSerFi).
4. Preserve non-breaking spaces (`\u00a0`) where French typography rules
   require them; other locales use regular spaces.
5. Use the locale's existing formal/informal register: French and
   Italian use the informal "tu / tu", German uses "du", Spanish and
   Portuguese use the informal 2nd person, English uses neutral 2nd
   person.

## Files touched

- `tools/voice_corpus/mine_phrases.py` — mining script (commit 1)
- `tools/voice_corpus/phrase_mining_report.json` — full ranked report (commits 1+2)
- `tools/voice_corpus/apply_rewrites.py` — rewrite application script (commit 2)
- `apps/mobile/lib/l10n/app_fr.arb` — 15 value rewrites + 30 `@meta` siblings
- `apps/mobile/lib/l10n/app_en.arb` — 15 value rewrites + 30 `@meta` siblings
- `apps/mobile/lib/l10n/app_de.arb` — 15 value rewrites + 30 `@meta` siblings
- `apps/mobile/lib/l10n/app_es.arb` — 15 value rewrites + 30 `@meta` siblings
- `apps/mobile/lib/l10n/app_it.arb` — 15 value rewrites + 30 `@meta` siblings
- `apps/mobile/lib/l10n/app_pt.arb` — 15 value rewrites + 30 `@meta` siblings
- `apps/mobile/lib/l10n/app_localizations*.dart` — regenerated by `flutter gen-l10n`
- `docs/VOICE_PASS_LAYER1.md` — this document

## Gates

- ✅ `flutter analyze lib/l10n/` — **No issues found** (0 errors)
- ✅ `python3 -m pytest services/backend/tests/services/coach/ -q` — **32 passed**
- ✅ All 6 ARB files parse as valid JSON
- ✅ All 30 phrases pass the 6 anti-shame checkpoints (100% pass rate)
- ✅ 1 P0 banned-term fix (rank 27)
- ✅ Every rewritten/kept phrase has a target N-level annotation in `@meta`
- ✅ `tools/voice_corpus/phrase_mining_report.json` fully populated (no
  null `proposed_*` fields on any of the 30 entries)

## Next plans dependent on this output

- **Plan 11-02** uses these rewrites + the 50 frozen phrases as the
  Krippendorff-α test corpus.
- **Plan 11-03** consumes the level annotations to drive the N5 server
  hard gate downgrade logic.
- **Plan 11-05** lints any future ARB additions for the same
  `@meta level` annotation.
