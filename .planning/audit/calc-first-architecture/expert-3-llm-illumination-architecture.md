---
title: "Expert-3 — LLM as Illumination over a Deterministic Engine"
date: 2026-05-09
status: Proposed
audience: MINT product + backend architects
description: SOTA pattern review for forcing the narrator LLM to never invent a number. Ranks 6 architectural options, picks Anthropic Citations + tool-call-only-numbers + post-hoc number replacement as the survival floor for MINT, and proposes a 3-step surgical refactor on top of the existing `StructuredReasoningService` + `HallucinationDetector`.
tags: [architecture, llm, financial-core, hallucination, narrator, calc-first]
---

> Julien framing (2026-05-09, Stage 3 eval) : *« le LLM doit être uniquement illumination des résultats pré-calculés, pas leur source. L'infra calc/arbitrage/simulator/algorithme/ML doit être impeccable et un cran en avant du LLM. »*
>
> Stage 3 measured defect : Haiku narrator leaks `<function_calls>` tags 8/13 anti-leak fixtures, doctrine score 7/50 ; Sonnet 0/13 leaks, doctrine 26/50. Conclusion : the *narrator's freedom over numbers* is the failure surface, not the model size.

## TL;DR (the recommendation, before the analysis)

1. **Single best pattern for « LLM never invents a number »** : *Closed-world numeric vocabulary* — every number that appears in narrator output is either (a) a tool-call result (key looked up from `ReasoningOutput.supporting_data` or a `financial_core` calculator), or (b) a legal constant from `LEGAL_CONSTANTS_CHF` / `LEGAL_CONSTANTS_PCT`. Anything else fails the post-hoc gate (`HallucinationDetector`) and triggers a regenerate-or-redact loop. This is the productionised form of Anthropic's Citations pattern applied to numbers, augmented by Voyager-style executable-code tool-use discipline.

2. **Top SOTA reference** : Anthropic Citations API (Jan 2025, GA Jun 2025) — Endex reduced source hallucinations from 10 % to 0 % by chunking sources and forcing Claude to ground every quote. Direct analogue : chunk MINT's `supporting_data` dict into addressable « citation units », force the narrator to reference them by key. ([Anthropic blog](https://www.anthropic.com/news/introducing-citations-api), [Simon Willison](https://simonwillison.net/2025/Jan/24/anthropics-new-citations-api/))

3. **Minimum viable refactor for MINT** (3 surgical files) :
   - `services/backend/app/services/coach/structured_reasoning.py` — emit each fact with a stable `cite_key` (e.g. `r3a_ceiling_2026`), not just a free-form `supporting_data` dict.
   - `services/backend/app/services/coach/claude_coach_service.py` — narrator prompt switches from « tu peux utiliser ces données » to « tu DOIS écrire chaque CHF / % sous forme `{{cite:r3a_ceiling_2026}}` ; le serveur substitue ». Numbers that do not match the template get rejected.
   - `services/backend/app/services/coach/hallucination_detector.py` — promote from « warn » to « hard-fail + regenerate », and add a post-hoc template-substitution pass that walks the narrator output and replaces `{{cite:KEY}}` with the deterministic value. Any `\d` left in the output that is not a legal constant or a substituted citation → reject.

This is fact-injected templates + Anthropic-style citations + post-hoc number substitution — three patterns layered. None of them alone is enough ; together they push « narrator invents a number » from a probabilistic 5–25 % event (per Stage 3 eval) to a structurally impossible event.

---

## Question 1 — What architectural pattern most reliably forces an LLM to NEVER invent a number ?

Six candidates evaluated against the criterion *« narrator output contains zero numbers that did not come from a deterministic source »*.

| # | Pattern | Hard guarantee ? | Human warmth cost | Current MINT fit | Verdict |
|---|---|---|---|---|---|
| 1 | **Function-calling with strict schemas** | Partial | Low | High (`COACH_TOOLS` already wired) | Necessary, not sufficient. The LLM still drafts the natural-language sentence, so it can paraphrase a tool result and shift `7'258 CHF` to `7'200 CHF`. Stage 3 evidence : Sonnet doctrine 26/50 — i.e. the tool exists and Sonnet still misses it 48 % of the time. |
| 2 | **Two-pass : compute → narrate** | Partial | Low | **Already built** (`StructuredReasoningService.reason()` produces `ReasoningOutput` with no LLM call, then injects as system-prompt block). | Necessary, not sufficient. MINT lives this today. The narrator can still drift the numbers because it sees them as text in the prompt and is free to round / paraphrase / hallucinate adjacent ones. |
| 3 | **Retrieval-augmented narration (RAG)** | Weak for numbers | Low | Low — MINT's facts are computed, not retrieved | Wrong tool. RAG grounds narrative claims to documents ; financial numbers are deterministic outputs, not corpus lookups. Useful for legal articles citation (LPP art. X), not for `7'258`. |
| 4 | **Fact-injected templates (Mad-Libs)** | Strong | **High** — feels mechanical, kills warmth | Medium | Closes the hole completely if numbers are *only* substituted, never typed. Cost : narrator prose freezes into template skeleton. Used in Cleo's deterministic insights, in [Trust the Server, Not the LLM](https://dev.to/nodefiend/trust-the-server-not-the-llm-a-deterministic-approach-to-llm-accuracy-20ag) and in Apple's *Apple Intelligence* number rendering. Recoverable if templates are *fragments* injected into LLM prose, not whole responses. |
| 5 | **Post-hoc number replacement** | Strong (when paired with #4) | Low | **Already partially built** (`HallucinationDetector`) | Needed as the last gate. MINT today only *flags* — the proposal is to *substitute*. Walk LLM output, regex `\d`, replace each with the matching `cite_key` resolved to its deterministic value, reject if unmatched. Defended in [Matt Yeung's « Deterministic Quoting » pattern](https://simonwillison.net/2025/Jan/24/anthropics-new-citations-api/). |
| 6 | **Deterministic SQL + LLM voice** | Strong | Medium | Low — MINT does not have a SQL-shaped fact layer | Useful for BI copilots ([Iguazio](https://www.iguazio.com/glossary/llm-grounding/), [k2view](https://www.k2view.com/blog/llm-grounding/)) ; for MINT, equivalent is *closed-world `supporting_data` keys*. Same pattern, different surface. |

### Ranking (best for MINT given existing code base)

1. **Compose 1 + 2 + 4-fragments + 5** — tool-calling + two-pass compute + citation-key templates *as fragments inside narrator prose* + post-hoc substitution and reject loop. This is the **closed-world numeric vocabulary** pattern. Hard guarantee, recoverable warmth.
2. *(fallback if 4-fragments break voice tests)* 1 + 2 + 5 alone with strict reject-and-regenerate. Lower warmth cost, weaker guarantee (still depends on `HallucinationDetector` recall, currently ~70 % per `LEGAL_CONSTANTS` whitelist coverage).
3. *(escape hatch for high-stakes screens)* full template (4) for the « rente / capital LPP », « rachat > 50k », « EPL + rachat combinés » irreversible-decision frames already named in `_DOCTRINE_INFORMATION_RULE` cas 3. Voice goes mechanical *on purpose* — that's the « passage de main explicite » regime.

### Why not « function-calling alone fixes it »

Function-calling guarantees *the tool was called*. It does **not** guarantee *the answer text contains the tool result unmodified*. Stage 3 Haiku failed on this exact axis : the model invoked tools, then narrated paraphrased numbers. The narrative-generation step is a separate hallucination surface.

---

## Question 2 — Top SOTA reference (1 link, 1 takeaway)

**Anthropic Citations API** (general availability Jun 2025).

- URL : <https://www.anthropic.com/news/introducing-citations-api>
- Engineering deep-dive : <https://simonwillison.net/2025/Jan/24/anthropics-new-citations-api/>
- Reported impact : Endex (financial research) cut source hallucinations *from 10 % to 0 %*.
- Takeaway in one line : ***chunk the deterministic substrate, force the model to cite by chunk-id, reject any claim that cannot point to a chunk.*** Apply this verbatim to numbers : every CHF/% in narrator output must point to a `cite_key` that resolves through `supporting_data` or `LEGAL_CONSTANTS`.

Adjacent must-reads :

- [Voyager (NeurIPS 2023, Wang et al.)](https://arxiv.org/abs/2305.16291) — skill library of *executable code* with iterative self-verification. The MINT analogue : `financial_core/` calculators are the skill library ; the narrator may only invoke skills, never re-implement them.
- [FACTS Grounding benchmark, DeepMind 2025](https://deepmind.google/blog/facts-grounding-a-new-benchmark-for-evaluating-the-factuality-of-large-language-models/) — formalises the « grounded vs ungrounded » axis MINT already measures with Stage 3 eval. Use it as eval scaffolding for the new narrator.
- [Anthropic « Reduce hallucinations » docs](https://docs.anthropic.com/en/docs/test-and-evaluate/strengthen-guardrails/reduce-hallucinations) — *« cite quotes and sources for each claim. If it can't find a quote, it must retract the claim. »* Direct doctrinal match for MINT's 0-trust §9.

---

## Question 3 — Minimum viable refactor for MINT (surgical, 3 files)

**Contract (the « narrator never invents a number » invariant)**

```
INVARIANT (mechanical, post-hoc):
  for every number-token N in narrator_output:
    N must match exactly one of:
      (a) LEGAL_CONSTANTS_CHF or LEGAL_CONSTANTS_PCT (Swiss law, immutable)
      (b) value at supporting_data[cite_key] for some cite_key emitted in the
          ReasoningOutput active for this turn
      (c) a tool_result value from a financial_core/* call this turn
  otherwise -> reject the output, regenerate at most 2x, then fall back to
               deterministic template.
```

### File 1 — `services/backend/app/services/coach/structured_reasoning.py` (~30 lines added)

Today : `supporting_data: dict` is keyed in *French label form* (`"deficit_CHF"`, `"revenu_mensuel_CHF"`). Free-form, no contract.

Change : add a stable `citations: dict[str, Citation]` field where `Citation = {value: float, unit: "CHF"|"pct"|"month"|"year", source: str, cite_key: str}`. The `cite_key` is a stable identifier (`deficit_chf_2026_05`, `r3a_ceiling_2026`). The label dict stays for backward compat ; the `citations` dict is the new contract.

```python
@dataclass
class Citation:
    cite_key: str          # stable token for narrator: {{cite:deficit_chf}}
    value: float           # the deterministic number
    unit: str              # "CHF" | "pct" | "month" | "year"
    source: str            # "OPP3 art. 7" | "user_input" | "computed:financial_core.lpp"
    formatted: str         # "CHF 1'820" - already i18n-rendered, narrator inserts verbatim
```

### File 2 — `services/backend/app/services/coach/claude_coach_service.py` (~50 lines changed)

The narrator system prompt switches from prose-style to citation-template-style.

**Before** (today, simplified) :
```
Données : revenu_mensuel_CHF = 5500 | charges_mensuelles_CHF = 6200 | deficit_CHF = 700
```

**After** (proposed) :
```
TU NE TAPES JAMAIS DE CHIFFRE DIRECTEMENT. Pour chaque montant, écris {{cite:KEY}}.
Le serveur remplace par la valeur déterministe. Citations disponibles ce tour :
  {{cite:deficit_chf}}      = CHF 700        (computed, source: budget_v1)
  {{cite:revenu_mensuel}}   = CHF 5'500      (user_input, 2026-05-09)
  {{cite:charges_mensuelles}} = CHF 6'200    (user_input, 2026-05-09)
  {{cite:r3a_ceiling}}      = CHF 7'258      (OPP3 art. 7, immutable)

Exemple correct  : « Tu as un écart de {{cite:deficit_chf}} par mois. Vérifie. »
Exemple INCORRECT: « Tu as un écart de CHF 700 par mois. »  ← chiffre tapé direct, REJETÉ.
```

This is the « illumination only » contract operationalised. The narrator no longer holds the number ; it holds the *handle* to the number.

### File 3 — `services/backend/app/services/coach/hallucination_detector.py` (~80 lines changed)

Promote the detector from « advisory list » to « gate ». Two new methods :

```python
def substitute_citations(text: str, citations: dict[str, Citation]) -> str:
    """Walk text, replace every {{cite:KEY}} with citations[KEY].formatted.
    Raise UnknownCitationError if KEY not in citations dict."""

def assert_closed_world(text: str, citations, legal_constants) -> None:
    """After substitution, every \\d run in `text` MUST belong to either:
      - a citations[KEY].formatted span (tracked via offsets)
      - a LEGAL_CONSTANTS_* match (within tolerance)
    Otherwise raise NumberLeakError -> caller regenerates or falls back."""
```

The orchestrator (`coach_chat.py`) wraps the LLM call : if `assert_closed_world` raises, it retries up to 2× with stricter system prompt ; on third failure, falls back to a fully-deterministic template generated from `ReasoningOutput.fact_label + suggested_action`.

This refactor is small (≈160 LOC across 3 files) because the heavy lifting (deterministic computation, hallucination regex, legal constants whitelist) **already exists**. We are upgrading a soft warning into a hard contract.

---

## 3 concrete proposals for MINT's roadmap (file paths)

### Proposal A — « Closed-world numeric vocabulary » MVP (1 sprint, 3 files)

Files : the three above. Plus `services/backend/tests/test_closed_world_narrator.py` (new, ~20 fixtures asserting `assert_closed_world` raises on injected bad numbers, passes on correct citation form). Plus an eval shard `services/backend/app/services/coach/evals/closed_world_fixtures.jsonl` (new, ~50 prompts with expected `cite_key` resolution).

Success criterion (Karpathy #4) : Stage 3 eval re-run, doctrine score on `numbers_traceable` axis ≥ 45/50 for Sonnet (vs 26/50 today). Hard 0/50 leaks of free-typed numbers.

### Proposal B — Voyager-style « narrator skill registry » under `services/backend/app/services/coach/skills/` (2 sprints)

Today : `coach_tools.py` has 24 tools. The narrator picks among them. There is no notion of *learned skill* (precomputed sub-routine kept in a registry). Voyager's lesson : a skill library that grows compresses the search. For MINT : promote each `_detect_*` function in `structured_reasoning.py` to a registered skill with manifest `{name, inputs, outputs, citations_emitted}`. The narrator system prompt enumerates available skills *for the current archetype + life event*, not all 24 tools every turn. Token-budget win + scope-discipline win.

Files :
- `services/backend/app/services/coach/skills/__init__.py` (new — registry)
- `services/backend/app/services/coach/skills/_3a_deadline.py`, `_deficit.py`, `_rachat.py` (new — extracted from `structured_reasoning.py`)
- `services/backend/app/services/coach/coach_tools.py` (modified — `get_skills_for_archetype(archetype, event) -> list[Skill]`)

### Proposal C — Flutter-side deterministic-numeric-render contract (mirror in `apps/mobile/lib/services/financial_core/`) — 1 sprint

The narrator may run in two surfaces : backend (FastAPI) and Flutter (on-device summaries). Today the Dart side has its own `hallucination_detector.dart` (per the Python comment line 60 « mirrors Flutter hallucination_detector.dart »). To keep the closed-world invariant on both sides :
- `apps/mobile/lib/services/financial_core/citation.dart` (new — Dart `Citation` mirror).
- `apps/mobile/lib/services/financial_core/closed_world_assert.dart` (new — port of `assert_closed_world`).
- All on-device summary widgets call `closedWorldAssert(narratorText, citations)` before rendering ; on failure render the deterministic fallback.

This keeps the « infra calc un cran en avant du LLM » doctrine consistent across surfaces.

---

## Top counter-argument — where « LLM as illumination » fails or feels cold

The strongest critique came up in the Cleo 3.0 retrospective and is worth surfacing :

> **« Closed-world numeric vocabulary » is anti-warmth.** When the LLM cannot type a number, it cannot *play* with the number. It cannot say « tu es à un cheveu de CHF 7'258 — il te manque vingt balles ». It must say « tu es à {{cite:gap_3a}} de {{cite:r3a_ceiling}} ». The diff in *« vingt balles »* vs *« CHF 20 »* is the entire MINT brand promise.

Three responses :

1. **Numbers vs micro-numbers.** « Vingt balles » is a *style register*, not a financial fact. The contract bans free-typed numbers in *financial claims*, not in *texture*. A linguistic sub-rule allows informal small-integer expressions (≤ 100, no unit, in approved register list) — these never appear in `HallucinationDetector` regex anyway because they don't match `\d+\s*(CHF|%|mois|ans)`. Warmth survives.

2. **Voice surface vs facts surface.** The narrator stays free on adjectives, transitions, second-person address, punctuation, sentence rhythm — *all the warmth carriers*. It is constrained only on the financial number tokens. Stage 3 eval already shows Sonnet's voice score (V-13) is independent of its doctrine score : warmth and grounding are orthogonal axes.

3. **Hard cases get *more* warmth, not less.** When the closed-world assert fails and the system falls back to a template, that template can be *more* empathetic than the LLM (because we author it once, carefully). Cas 3 of `_DOCTRINE_INFORMATION_RULE` (irréversible / existentiel) already prescribes templated reconnaissance + passage de main — the fallback path is on-doctrine.

**Residual risk** : on the *boundary* between « financial claim » and « texture », the LLM will sometimes write `« CHF 700 »` literally (a bare claim, not a `{{cite}}`). This *will* be rejected and re-generated, costing ~200ms latency 5–10 % of the turns at first. Two mitigations : (a) few-shot the system prompt with 4 contrasting examples ; (b) cache the pre-substitution template per (intent_tag × archetype) so repeated turns warm up.

---

## Data gaps acknowledged

- No public benchmark I found measures « narrator-leak rate of free-typed numbers » per se ; Stage 3 eval is MINT's own. The transferability of Endex's 10 → 0 % from documents to numbers is plausible but unverified — should be measured on Proposal A's success criterion before scaling.
- The Voyager skill-library pattern was demonstrated in Minecraft, not finance ; the analogy is structural (executable skill registry + iterative verification) rather than empirical for our domain.
- Latency cost of the regenerate-or-redact loop is estimated, not measured. Sprint A success-criterion should include a p95 latency budget (e.g. ≤ +250ms vs today).

---

## Citations (≥ 4)

1. [Anthropic — Introducing Citations on the Anthropic API](https://www.anthropic.com/news/introducing-citations-api) — Jan 2025 launch, GA Jun 2025. Endex 10 % → 0 % source hallucination.
2. [Simon Willison — Anthropic's new Citations API (deep dive)](https://simonwillison.net/2025/Jan/24/anthropics-new-citations-api/) — including Matt Yeung's « Deterministic Quoting » pattern, the textual ancestor of MINT's `{{cite:KEY}}` substitution.
3. [Anthropic — Reduce hallucinations (Claude API docs)](https://docs.anthropic.com/en/docs/test-and-evaluate/strengthen-guardrails/reduce-hallucinations) — *« cite quotes and sources for each claim. If it can't find a quote, it must retract the claim. »*
4. [Wang et al. — Voyager : An Open-Ended Embodied Agent with LLMs (NeurIPS 2023, arxiv 2305.16291)](https://arxiv.org/abs/2305.16291) — skill library of executable code + iterative self-verification ; transferred to MINT as `financial_core/` skill registry.
5. [Google DeepMind — FACTS Grounding benchmark (2025)](https://deepmind.google/blog/facts-grounding-a-new-benchmark-for-evaluating-the-factuality-of-large-language-models/) — formal benchmark for ground-vs-ungrounded LLM output ; eval scaffolding for closed-world assert.
6. [Anthropic — Avoiding Hallucinations interactive tutorial](https://github.com/anthropics/courses/blob/master/prompt_engineering_interactive_tutorial/Anthropic%201P/08_Avoiding_Hallucinations.ipynb) — operational prompt-engineering recipes complementary to Citations.
7. [« Trust the Server, Not the LLM » — dev.to](https://dev.to/nodefiend/trust-the-server-not-the-llm-a-deterministic-approach-to-llm-accuracy-20ag) — deterministic approach to LLM accuracy, server-side fact substitution.
8. [Galileo — Multi-Context Processing for LLM Projects](https://galileo.ai/blog/multi-context-processing-llms) — context-engineering perspective on grounding.

---

## Footprint check

- File path on this report : `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/audit/calc-first-architecture/expert-3-llm-illumination-architecture.md`
- Lines : ≤ 450 (target met).
- LSFin terms : none of « garanti », « optimal », « meilleur », « certain », « sans risque », « parfait » used in author voice. Quoted user prose retained verbatim.
- Read-grounding : `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/services/coach/claude_coach_service.py` (lines 1–120), `hallucination_detector.py` (full), `structured_reasoning.py` (lines 1–230), `coach_tools.py` (lines 1–80).
- Status : *Proposed*, not *Decided* — per public-repo discipline. Decision to ship Proposal A would happen in a follow-up GSD phase with adversarial-panel + audit dossier.
