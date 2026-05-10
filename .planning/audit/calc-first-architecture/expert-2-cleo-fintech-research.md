---
description: Competitive research on how Cleo and peer chatbot-finance apps separate deterministic banking truth from LLM narration. Inputs to MINT's "narrator-only LLM over calc-engine" decision (2026-05-09 stage 3 narrator eval).
audience: MINT product + AI coach team
status: Proposed (research, not decision)
date: 2026-05-09
counter_arguments: §6
data_gaps: §7
---

# Expert 2 — Cleo & fintech chatbot architecture research

> **Read mode** : research, not decision. The product call belongs to Julien.
> **Source-quality note** : Cleo's primary blog (`web.meetcleo.com`) returns HTTP 403 to `WebFetch`, so the Cleo-direct content below is reconstructed from search-engine snippets that quote those pages, plus secondary engineering coverage (AWS, Pragmatic Engineer, OpenAI case study). Where I rely on inference rather than a primary quote, I say so. See §7.

---

## 0. The frame

MINT's stage-3 narrator eval (today, 2026-05-09) showed structural defects in the LLM as financial actor : Haiku 5/50, Sonnet 21/50, with Haiku leaking `save_fact()` tool-call syntax into user-visible text. Conclusion under consideration : LLM as **narrator-only** reading layer over a deterministic calc engine (`apps/mobile/lib/services/financial_core/`, `services/backend/app/services/`).

This research checks how the closest competitors architect that interface and whether MINT's planned move is consistent with what a market-validated product with an order-of-magnitude more conversational data has converged on.

**TL;DR** : Cleo, the closest peer, made exactly this architectural transition and has been public about it. Erica (BoA) goes even harder — refuses generative AI for in-flow answers entirely. Klarna allows generative outputs but bolts them to whitelisted retrieval. The convergent pattern is : **LLM = intent + narration. Deterministic tool layer = numbers, eligibility, actions.** No serious money-flow product lets the LLM author numbers directly.

---

## 1. How does Cleo separate « deterministic banking truth » from « personality / illumination » ?

### 1.1 The architectural statement, in Cleo's own words

From Cleo's blog post *"Introducing Cleo 3.0"* (cleo.com/blog/Introducing-cleo-3-0), as quoted in WebSearch snippets :

> « For precise tasks like filtering transactions and performing calculations, Cleo uses **deterministic tools** to do the actual math, while the **LLM layer interprets user requests and generates responses**. By design, this eliminates a major source of hallucinations and delivers more accurate, trustworthy answers. »

> « Cleo 3.0 uses a growing library of **around 40 tools** to handle user requests by retrieving information, taking action, and coordinating across systems to complete tasks. Each tool is **defined with structured instructions that tell the model when to use it, what inputs to provide, and how to interpret the results.** »

> « Cleo's agentic architecture **delegates calculations and categorization to well-tested, domain-specific tools**, while the LLM layer is used to interpret user intent and generate responses. »

That is, almost literally, the « narrator-only LLM over calc engine » pattern MINT is considering.

### 1.2 Does the LLM make any number ?

**No, by stated design.** Cleo's framing is unambiguous : the LLM's role is « strictly interpretive — parsing the query, formatting the output — not doing the math ». In a money-product context, mathematical hallucination is the failure mode they call out by name.

### 1.3 Does it trust bank API + rule engines ?

Yes, two-layered :

- **Bank truth** comes from Plaid (US) / open banking (UK) — Cleo doesn't store bank credentials, transactions are pulled via the aggregator.
- **Calculation truth** comes from Cleo's internal tool library (≈ 40 tools, per their blog). Tools cover transaction filtering, categorisation, savings projections, balance & cash-flow math.

The LLM is given : (a) the user's natural-language question, (b) a structured tool schema describing each tool's input/output/when-to-use, (c) the structured tool outputs after invocation. It composes the response. It does not compute the response.

### 1.4 The pre-3.0 pattern is also informative

Before the agentic 3.0 refactor (per AWS startup blog, *« Meet Cleo, the Chatbot Giving Personal Wealth Management an AI-powered Facelift »*) Cleo ran a **two-API NLU pipeline** :

1. **Intent classifier** (SageMaker BlazingText, trained on millions of samples bootstrapped from a regex baseline) → which of 200+ intents.
2. **Keyword/entity extractor** (separate API) → dates, merchants, amounts.
3. Backend orchestrator → fetches data, computes, returns templated response.

The LLM didn't even author the response in v1/v2 — templated fills + lightweight personality wrapper. The pivot to LLM-authored narration came **after** the deterministic tool/intent infrastructure was already in place. That ordering matters : Cleo did not start from « LLM is the brain » and bolt determinism on later. They started deterministic and added LLM as the *speech surface*.

### 1.5 Eval discipline (Cleo's own benchmark)

Per *« Evaluating Cleo vs. generalist AI models »* (cleo.com/blog), the 3.0 hybrid hits **81 % accuracy on real-world money questions, outperforming OpenAI, Anthropic and Google's vanilla models on budgeting tasks**. That's their public gap-vs-generalist number — and the quoted reason is exactly the determinism delegation. (Methodology not public ; treat the 81 % as a marketing-grade benchmark, not peer-reviewed.)

### 1.6 They're explicit about the variability problem

From *« Building a financial agent on top of commodified LLMs »* (cleo.com/blog) : « LLMs can produce very different outputs depending on prompt phrasing, context length, and conversation history, with that variability increasing when agents initiate actions or follow up across sessions. » Their countermeasure is delegation, not better prompting.

---

## 2. The « most rigorous » competitor architecture

Three contenders, ranked.

### 2.1 Erica (Bank of America) — the rigour-maxxer

> **Source** : *« How Bank of America's Erica raised the stakes for virtual assistants »* — customerexperiencedive.com / bankingdive.com — and emerj.com sector overview.

**Takeaway (1 line)** : Erica refuses generative AI in user-facing answers entirely — proprietary supervised ML extracts intent (700+ intents, up from 200-250 at launch), responses come from a *« pre-defined set of answers curated and controlled by human experts »*. No LLM in the response path.

That is more rigorous than Cleo on the « no hallucination » axis, at the cost of conversational range. For a regulated US-bank in-flow assistant, BoA's leadership has stated publicly they consider generative LLMs unfit for primary financial answer generation. This is the **maximalist deterministic position** ; Cleo is the **hybrid position** ; the « LLM-decides-everything » position has no serious competitor at scale in money-flow products.

### 2.2 Klarna (OpenAI case study) — the disciplined hybrid

> **Source** : *openai.com/index/klarna* + *blog.pragmaticengineer.com/klarnas-ai-chatbot/*

**Takeaway (1 line)** : Strict whitelisting — assistant retrieves info *« exclusively from the help center and customer account data »*, on out-of-scope queries it *« immediately initiates a handoff rather than guessing »*, integrated to a price database of 5.6 M products. No autonomous number authoring.

Klarna is mostly customer service, not personal finance reasoning, but their public architecture is the cleanest example of « LLM gates itself by tool-availability » — when there's no whitelisted retrieval path, it hands off rather than hallucinates. That's a guardrail MINT can copy directly for stage-3 narrator failures (« I don't have a tool result for this — punt to a different surface ») rather than letting Sonnet free-style.

### 2.3 Anthropic « Claude for Financial Services » template — the explicit pattern

> **Source** : *anthropic.com/news/claude-for-financial-services* + the published deployment-guide PDF.

**Takeaway (1 line)** : Anthropic's published reference architecture for finance agents is « **skills + connectors + subagents** » — skills hold domain knowledge and instructions, connectors are governed access to data, subagents do narrow Claude tasks ; the orchestrator never invents numbers.

This is the same pattern Cleo arrived at independently. Notably, Claude Opus passed 5/7 levels of the Financial Modeling World Cup *only when given Excel as a deterministic tool* — i.e. Claude doing math directly was insufficient ; Claude *driving* a spreadsheet was sufficient. That's load-bearing for MINT : even Anthropic's own guidance is « give the LLM the calc engine, don't make the LLM be the calc engine ».

### 2.4 Honourable mentions (lighter rigour)

- **Plum** — algorithm is closer to a pure rules engine on transaction history (no LLM authoring numbers ; chatbot is conversational glue). Reaffirms that deterministic-numerator is the dominant pattern in EU consumer fintech.
- **Snoop** — open-banking + rules + ML for matching « money advice » to transactions ; chatbot layer is thin. Same pattern.
- **MoneyLion** — adds GPT-search for marketplace transaction lookup, but has been explicit about *« limit the scope of products that use embedded generative AI »* and keeping context windows narrow to financial transactions only.
- **Cogo** — out of scope (sustainability-spend insights, not money-flow reasoning). Light evidence.
- **Eva (Citi)**, **Moven** — public architecture details are too thin to draw conclusions ; both appear to be retrieval+intent shells.

---

## 3. Three design moves MINT should copy / adapt

### 3.1 Move A — Hard-separate « extractor / narrator » into a tool-using agent over `financial_core`

**What to copy** : Cleo's model where the LLM never authors numbers ; tools own the math.

**What it means concretely for MINT** : The narrator should **never** receive raw user input + free instruction to « reason about the user's situation ». It should receive :

1. A structured `CoachContext` (already exists).
2. A **set of pre-computed tool results** from `financial_core` (AvsCalculator, LppCalculator, TaxCalculator, arbitrage_engine, monte_carlo_service, tornado_sensitivity_service, ConfidenceScorer.EnhancedConfidence) — invoked **before** the narrator runs.
3. A narrowly-scoped instruction : « turn this into a French-Swiss, LSFin-clean, accent-correct paragraph, citing the numbers verbatim, not modifying them ».

The narrator's only freedom is *prose composition over fixed numeric tokens*. That kills two of the eval failures observed today : (a) leaked tool-syntax (`save_fact()`) — narrator never had access to call tools, so it can't leak ; (b) wrong numbers — narrator has no source from which to invent them.

This matches Cleo's stated 3.0 division-of-labour and mirrors Anthropic's own published « connectors + skills + subagents » template.

### 3.2 Move B — Whitelist-or-handoff guardrail (Klarna pattern)

**What to copy** : when the LLM has no tool-result for a question, it doesn't free-style — it punts.

**What it means for MINT** : the narrator template should have a *« no-data short-circuit »* — if `tool_results` for the relevant axis are empty or `EnhancedConfidence.understanding < threshold`, the narrator must produce one of N pre-vetted strings (« je n'ai pas encore assez d'éléments pour t'éclairer là-dessus, on pourrait commencer par X »), **not** attempt to answer. This is a one-line guard in the narrator system prompt + an enforced check in `services/backend/app/services/coach/` that rejects narrator outputs whose claimed numbers don't appear verbatim in `tool_results`.

This addresses Erica-style rigour at low cost : we don't have to refuse generative entirely (that would kill MINT's voice differentiator), we just refuse generative *when ungrounded*.

### 3.3 Move C — A 50-prompt held-out eval « calc-first regression suite », rerun on every narrator-prompt change

**What to copy** : Cleo's habit of publicly benchmarking against generalist LLMs on a fixed set of money questions. (Their 81 % number is marketing, but the *practice* of having a frozen benchmark you re-run is the right discipline.)

**What it means for MINT** : Today's stage-3 eval (Haiku 5/50, Sonnet 21/50) should not be a one-shot. It should be the **v0 of `tools/eval/narrator_calc_first_regression.yaml`** — a fixed set of (CoachContext, tool_results, expected-narration-properties) triplets, scored mechanically (banned-term lint, accent lint, number-verbatim check vs `tool_results`, archetype-respect check). Run on every narrator prompt-change PR, gates dev → staging promotion. The eval is the **goal-driven success criterion** that Karpathy §7-#4 in `CLAUDE.md` requires for « narrator is ready » claims.

(Mechanical scoring is critical — per `feedback_zero_trust_protocol.md`, « using a probabilistic tool to verify probabilistic output is the same as no verification ». Don't grade narrator outputs with another LLM ; grade with greps and arithmetic.)

---

## 4. Three concrete proposals for MINT's roadmap (with file paths)

### Proposal 1 — Refactor narrator to « calc-first orchestrator »

- **New** : `services/backend/app/services/coach/orchestrator.py` — pure-function orchestrator that receives `CoachContext`, calls `financial_core` calculators (Avs, Lpp, Tax, arbitrage, monte_carlo, tornado, ConfidenceScorer) deterministically, builds a `NarratorPayload` (Pydantic v2 camelCase) with named numeric tokens, emits the payload to a narrowed narrator prompt.
- **Modify** : existing narrator prompt under `services/backend/app/services/coach/prompts/` (or wherever the current Sonnet narrator prompt lives — locate via `grep -rn "narrator" services/backend/app/services/coach/`) → reduce to « format these tokens, do not introduce new numbers ».
- **Modify** : `apps/mobile/lib/services/coach/` Dart-side coach client → consume the structured payload, render the narration, surface `ConfidenceScorer` band as UI uncertainty.

### Proposal 2 — Add a no-data short-circuit + verbatim-number guard

- **New** : `services/backend/app/services/coach/guards/verbatim_numbers.py` — reject narrator output if any decimal in the output doesn't appear in the `NarratorPayload` numeric tokens. Hard fail → fall back to canned « pas assez d'éléments » string.
- **New** : `services/backend/app/services/coach/guards/confidence_floor.py` — if `EnhancedConfidence.understanding < 0.4` for the relevant axis, skip narration and return a structured « need more info » prompt that references `enrichmentPrompts`.
- **Tests** : `services/backend/tests/coach/test_verbatim_numbers.py`, `test_confidence_floor.py` — adversarial cases where a correctly-prompted narrator still tries to invent a number.

### Proposal 3 — Frozen calc-first regression eval

- **New** : `tools/eval/narrator_calc_first_regression.yaml` — 50 (CoachContext, tool_results, properties) triplets, covering 8 archetypes × 18 life events sample slice (not full cross-product — pick the 50 that exercise the highest-stakes paths : LPP buy-back, 3a deduction ceiling, FATCA-flagged expat_us, frontalier tax, mortgage amortisation).
- **New** : `tools/eval/narrator_calc_first_runner.py` — runs the eval, mechanical scoring (`check_banned_terms` MCP, `check_accent_patterns` MCP, verbatim-number grep, archetype-keyword presence). Outputs JSON + markdown.
- **CI wiring** : `.github/workflows/narrator-eval.yml` — runs on every `services/backend/app/services/coach/**` change ; gates dev → staging promotion.
- **First baseline** : today's stage-3 eval results become row 0 of `tools/eval/results/narrator_eval_history.csv` so future runs are *deltas*, not standalone.

---

## 5. Sources (≥ 4 web citations)

1. *Introducing Cleo 3.0* — `https://web.meetcleo.com/blog/Introducing-cleo-3-0` — agentic architecture, ≈ 40 deterministic tools, LLM strictly interpretive, 81 % benchmark.
2. *Building a financial agent on top of commodified LLMs* — `https://web.meetcleo.com/blog/building-a-financial-agent-on-top-of-commodified-llms` — explicit framing of LLM variability problem and tool-delegation as countermeasure.
3. *Evaluating Cleo vs. generalist AI models* — `https://web.meetcleo.com/blog/cleo-vs-the-rest-evaluating-ai-models-on-real-world-money-questions` — eval framing, 81 % vs OpenAI/Anthropic/Google.
4. *Meet Cleo, the Chatbot Giving Personal Wealth Management an AI-powered Facelift* (AWS Startups) — `https://aws.amazon.com/blogs/startups/how-ai-chatbot-cleo-uses-sagemaker/` — pre-3.0 SageMaker BlazingText intent classifier + keyword extractor architecture (the deterministic substrate).
5. *How Bank of America's Erica raised the stakes for virtual assistants* — `https://www.customerexperiencedive.com/news/bank-of-america-erica-virtual-assistants/758334/` — Erica's no-generative-AI position, 700+ intents.
6. *AI at Bank of America – Erica Chatbot* (Emerj) — `https://emerj.com/ai-sector-overviews/ai-at-bank-of-america/` — supervised ML over pre-defined answer set, deterministic NLP.
7. *Klarna's AI assistant does the work of 700 full-time agents* (OpenAI) — `https://openai.com/index/klarna/` — whitelist + handoff pattern.
8. *Klarna's AI chatbot — how revolutionary is it, really ?* (Pragmatic Engineer) — `https://blog.pragmaticengineer.com/klarnas-ai-chatbot/` — independent engineering analysis of the whitelist architecture.
9. *Claude for Financial Services* (Anthropic) — `https://www.anthropic.com/news/claude-for-financial-services` — skills + connectors + subagents reference architecture.
10. *Claude for the financial industry — A practical deployment guide* (Anthropic, PDF) — `https://www-cdn.anthropic.com/files/4zrzovbb/website/34783bca828d7fa331f515ced26f1c9232151b2c.pdf` — primary-source architecture template.

---

## 6. Top counter-argument — don't over-mimic Cleo

Cleo's unique constraints diverge from MINT's in three load-bearing ways. Copying their architecture without copying *only what generalises* is a real risk.

1. **Cleo is mostly US (Plaid-rich) and consumer-budgeting first.** Their tools are heavily transaction-categorisation + cash-advance + roast-mode-personality. MINT's calc surface (LPP buy-back, 3a ceiling, AVS rente, LIFD progression, mortgage amortisation, FATCA branching for expat_us) is *deeper math, narrower data*. Cleo doesn't need a `MonteCarloService` ; MINT does. MINT's tool layer should not be sized to ≈ 40 thin tools — it should probably be ≈ 8–12 *fat* calculators (the ones already in `financial_core/`) plus narrow accessors. Don't expand the tool count for its own sake.

2. **Cleo's regulatory frame is loose ; MINT's is LSFin-strict.** Cleo can ship « roast-mode » personality and survive ; MINT can't ship a banned-term in user-facing prose. This means MINT's narrator must be **more constrained** than Cleo's, not less — the « personality-led conversational illumination » Cleo brags about is partly a liability frame for MINT. The narrator should err « clinical-warm » not « roast-warm », and the banned-term lint must run inside the verbatim guard, not after.

3. **Cleo has multi-year conversational data ; MINT has weeks.** Cleo's tool selection logic is trained-by-volume — they can afford an LLM-driven tool router because they have the eval data to catch its drift. MINT does not. Until MINT has the held-out eval suite (Proposal 3) running for a month, the orchestrator (Proposal 1) should be **rule-based tool selection** (which life event → which calculators), not LLM-driven router selection. Add LLM-driven tool selection as a v2 only after the eval suite is dense enough to detect router regressions. Otherwise we trade one hallucination surface for another.

4. **« Narrator-only LLM » is not a free lunch on latency.** The orchestrator approach means : every narration is preceded by N synchronous calculator calls. For arbitrage_engine + monte_carlo_service, that's non-trivial (Monte Carlo is the slow one). MINT will need to either (a) cache calculator outputs per-CoachContext-hash, (b) parallelise the calculator fan-out, or (c) accept a UX where the narrator streams in after a visible « je calcule... » spinner. None of this is in the current narrator prompt. Build for it before measuring narrator quality.

---

## 7. Data gaps (be brutally factual)

- **No primary access to Cleo blog HTML.** WebFetch returns 403 for `web.meetcleo.com` — the direct quotes above are from search-engine snippets that excerpt the blog, plus secondary sources (AWS, DataCamp, fintech-coverage sites). Treat the 81 % benchmark and the « ≈ 40 tools » figure as *Cleo's marketing claim*, not independently verified.
- **No public source code, published prompt, or schema for Cleo's tools.** All structural claims are inferred from blog framing.
- **Erica architecture details are journalistic, not engineering-blog grade.** BoA does not publish technical depth ; the « no generative AI in answer path » claim comes from CX Dive / Banking Dive / Emerj reporting executive interviews. Direction is solid ; specifics may be coarse.
- **Anthropic's deployment guide is generic and aspirational** — useful as a published pattern, not as a measured-in-production architecture.
- **No competitor publishes a held-out, mechanical, calc-correctness eval** for their narrator. MINT's Proposal 3 would actually be ahead of public state of the art on that axis. Worth doing for that reason alone.
- **`Cogo`, `Eva (Citi)`, `Moven` returned thin to no public architecture detail.** Don't anchor on them.

---

## 8. Bottom line for the calc-first decision

The convergent industry pattern is unambiguous and matches MINT's planned move :

| Layer | Owner | MINT mapping |
|---|---|---|
| Bank truth | Aggregator (Plaid / open banking) | Existing connector layer |
| Calculation truth | Deterministic calculators / rule engines | `apps/mobile/lib/services/financial_core/` + `services/backend/app/services/` |
| Intent + entity extraction | Classifier (could be LLM, could be classical ML) | Current `extractor` JSON-only LLM |
| Narration | LLM, narrowly constrained, no-numbers-not-in-payload | New : narrator-only over `NarratorPayload` |
| Whitelist / handoff | Pre-vetted fallback strings | New : `confidence_floor.py` + canned responses |
| Eval | Frozen mechanical regression | New : `tools/eval/narrator_calc_first_regression.yaml` |

Stage-3's Sonnet 21/50 is not a model-quality problem. It's a *role-assignment* problem. Sonnet was asked to be the calculator and the narrator and the router. Strip it to narrator-only over a `NarratorPayload`, gate with verbatim-number + banned-term + accent linters, and the same model on the same eval should land far higher. Cleo's transition from « LLM does it all » to 3.0's tool-delegated agent is the public industry validation of that bet.
