---
title: Advice-Path Audit — VZ-and-beyond quality review of how MINT produces financial guidance
author: Swiss financial-advisory domain expert (VZ-calibre, external audit)
date: 2026-06-12
status: Proposed
severity_legend: "S0 = user gets wrong advice silently · S1 = wrong advice possible, weak guard · S2 = quality/structure gap vs VZ · S3 = regulatory/liability exposure"
---

# TLDR

MINT's chat coach can emit a financial **claim** (definition, directionality, cause→effect) with **zero deterministic source behind it**, because every production guard checks only **numbers and banned words** — never the *meaning* of a sentence. The "rachat = retirer ton capital" inversion (it is the opposite: a rachat is paying IN, LPP art. 79b) is not a fluke; it is the designed-in blind spot. The live path is the **legacy single-LLM prompt** (`build_system_prompt`) — the citation gate, dual-LLM extractor/narrator split, and bundle compiler are **all flag-OFF in prod** (`config.py:71,80,91`). The LLM recites Swiss facts from a free-text "CONNAISSANCES SUISSES" block in the system prompt (`claude_coach_service.py:740-748`), which it can paraphrase, invert, or stale-cite at will. Meanwhile a genuinely VZ-quality structured engine (`coach_reasoner.dart` — risks + assumptions + sources + alternatives per recommendation) **exists but has no production caller** (façade-without-wiring). The deterministic constants themselves are mostly **correct for 2026** (3a 7'258, LPP seuil 22'680, coordination 26'460, conversion 6.8% all verified against OFAS/finpension) — but the registry's `avs.reference_age_women = 65.0` is the AVS21 *terminal* value, wrong for 2026 (should be 64.5), and the prompt's EPL/79b explanation is materially under-specified vs the 26 Feb 2026 Tribunal fédéral arrêts. The founder is right that "the path to the advice" is unaudited — but his framing under-specifies the LSFin "conseil" boundary that a ranking arbitrage engine crosses.

---

# 1. The advice pipeline, traced end-to-end

```
user message
  │
  ├─(mobile) coach_chat_screen → coach_llm_service → POST /v1/coach/chat
  │
  ▼ (backend) app/api/v1/endpoints/coach_chat.py  (5784 lines)
  │   1. _build_system_prompt_with_memory()              [:1408]
  │        ├─ if COACH_DUAL_LLM_ENABLED  → narrator prompt   (FLAG OFF in prod)
  │        ├─ if COACH_BUNDLE_COMPILER   → bundle prompt     (FLAG OFF in prod)
  │        └─ ELSE → build_system_prompt()  ◄── LIVE PATH    [:1517]
  │   2. _run_agent_loop()  → Anthropic API with COACH_TOOLS
  │   3. _run_narrator_with_gate()                        [:5296]
  │        ├─ if NOT COACH_CITATION_GATE_ENABLED → return raw   ◄── LIVE PATH [:5303]
  │        ├─ runtime_verb_gate   (only if gate flag ON)  [:5313]
  │        ├─ runtime_freshness_gate (only if gate ON)    [:5344]
  │        ├─ runtime_temporal_gate  (only if gate ON)    [:5373]
  │        └─ citation_parser.gate() (only if gate ON)    [:5398]
  │   4. ComplianceGuard.validate()  ◄── the ONLY live guard  (compliance_guard.py)
  │
  ▼ response → Flutter widget_renderer / response_card_service render
```

**Confirmed flag state (the load-bearing fact):**
- `services/backend/app/core/config.py:71` — `COACH_DUAL_LLM_ENABLED: bool = False`
- `:80` — `COACH_BUNDLE_COMPILER_ENABLED: bool = False`
- `:91` — `COACH_CITATION_GATE_ENABLED: bool = False`

So the elaborate Phase-94 closed-world citation gate (`citation_parser.py`, 734 lines), the runtime verb/freshness/temporal gates, the extractor/narrator split, and the bundle compiler are **all dark in production**. The live coach is: `build_system_prompt()` → Anthropic → `ComplianceGuard.validate()`. That is the entire deterministic spine the founder's "rachat" answer passed through.

---

# 2. Where the LLM can emit a financial claim with NO deterministic source (severity-ranked holes)

### HOLE-1 (S0) — Qualitative/definitional claims are completely ungated
`claude_coach_service.py:740-748` ships a free-text "CONNAISSANCES SUISSES" block INSIDE the system prompt:
> "LPP (2e pilier) : taux conversion minimum 6.8%... Rachat = déduction fiscale complète. ATTENTION : après un rachat, EPL bloqué 3 ans..."

The LLM is free to **paraphrase** any of this. The "rachat = retirer ton capital" inversion is a sentence with **no number**. Trace it through every live guard:
- `ComplianceGuard._check_banned_terms` — no banned word → pass.
- `ComplianceGuard._check_prescriptive` — no imperative verb pattern → pass.
- `HallucinationDetector.detect` (`hallucination_detector.py:136-274`) — **extracts only `CHF`, `%`, durations, `/100` scores**. A definition has none → `extract_numbers` returns `[]` → `detect` returns `[]` → pass.
- Citation gate — OFF, and even if ON, `citation_parser.py:653` iterates `(_RE_CURRENCY, _RE_PERCENT, _RE_DURATION, _RE_REGULATORY)` only. A definition matches none → `uncited_count = 0` → `PASS`.

**There is no semantic/claim-level verifier anywhere in the stack.** This is the single most important finding. Every guard is lexical or numeric. The meaning of a financial sentence is never checked against ground truth. The founder's verdict ("tu ne regardes pas les conseils donnés et le chemin qui a amené à ces conseils") is mechanically accurate: the path validates digits, not advice.

### HOLE-2 (S1) — The LLM recites Swiss law from prompt memory, not from a tool
The live `build_system_prompt` embeds the entire Swiss knowledge base as prose (`claude_coach_service.py:740-748`) plus the life-event/archetype catalogs (`:346-400`). The `get_regulatory_constant` tool exists (`coach_tools.py:736`) but the prompt **does not force** its use for narrative facts — it is offered, not mandated. Contrast `save_fact` which is "MANDATORY" with explicit triggers. Result: for any conceptual question ("c'est quoi un rachat?"), the LLM answers from its own weights + the prompt prose, with no tool-call trace. This is exactly the "trust collapse" the founder's own memory `project_coach_forced_tool_invocation` warns against — but the forcing is not implemented for *definitions*, only attempted (and only when the citation gate is ON) for *numbers*.

### HOLE-3 (S1) — Hallucination detector tolerance has a structural escape hatch
`compliance_guard.py:494` — hallucination detection only runs `if context and context.known_values`. For a new/empty profile (onboarding, anonymous, first message) `known_values` is empty → `detect()` returns `[]` at `hallucination_detector.py:183` → **all numbers pass unchecked**. The most vulnerable users (no data yet, highest trust-formation stakes) get the *least* numeric verification. Additionally `:191-194` strips any `known_value == 0`, so a freshly-declared field can't anchor a check.

### HOLE-4 (S1) — Prescriptive + banned-term layers are log-only, not blocking
`compliance_guard.py:451-461` — Layer 2 (prescriptive) "NEVER fallback... always log only." Layer 1 only forces fallback at **>5 distinct banned terms** (`:442`). So "tu devrais racheter ta LPP maintenant" (one prescriptive hit, zero banned terms) is logged and **shipped to the user**. The defense is explicitly delegated "in the prompt, not in post-hoc rejection" (`:454-455`). For an app whose entire LSFin posture is "narrateur, pas conseiller," the enforcement is advisory.

### HOLE-5 (S2) — The VZ-quality engine exists but is unwired (façade-without-wiring)
`apps/mobile/lib/services/financial_core/coach_reasoner.dart` is genuinely good: each `Recommendation` carries `assumptions[]`, `risks[]` (incl. the *correct* art. 79b note at `:145`), `why[]`, `alternatives[]`, `evidenceLinks[]` (fedlex URLs), and a `ProjectionConfidence`. This is ~80% of the VZ advice contract. **But it has no production caller** — `grep` finds `CoachReasonerService` only in the barrel `financial_core.dart` export; the two screen hits (`gender_gap_screen`, `independant_screen`) call *different* services (`GenderGapService.analyse`, `IndependantService.analyse`). So the best advice-structuring asset in the codebase does not touch the chat coach the user actually talks to. CLAUDE.md NEVER #6 (façade-sans-câblage doctrine) is violated by the org's own flagship reasoner.

### HOLE-6 (S2) — Internal contradiction in the ranking doctrine
`arbitrage_engine.dart:19` documents "NEVER rank options — side-by-side only." But `coach_reasoner.dart:94` does `results.sort((a,b) => annualized(b).compareTo(annualized(a)))` and `:159` titles a card "Rachat LPP : impact fiscal indicatif..." sorted to the top by return. Ranking by "effective annual return" IS implicit advice. Two financial_core files hold opposite doctrines. (See §4 — this is also the LSFin-boundary issue.)

### HOLE-7 (S2) — Citation registry is descriptive, not value-bearing
Even when the gate is ON, `citation_registry.py:227-245 resolve()` is a "Wave 0 stub" that returns `description_fr` text, **not the actual value or its computation trace**. So a `{{cite:lpp_taux_conv_obligatoire_2026}}` placeholder substitutes to a *sentence about* the conversion rate, not a verified 6.8% from the registry. The citation chip asserts authority it does not mechanically hold. (Phase 95/96 intends to fix via GroundingPack; not shipped.)

---

# 3. Deterministic-layer spot-check vs Swiss law (VZ-quality bar)

WebSearch verified against admin.ch-ecosystem sources (OFAS publication, finpension, Tribunal fédéral coverage). Registry = `services/backend/app/services/regulatory/registry.py`.

| # | Constant | Registry value (file:line) | Official 2026 | Verdict |
|---|---|---|---|---|
| 1 | 3a plafond avec LPP | `7'258` (`registry.py:52`, `:88` for 2026) | CHF 7'258 (2026) | ✅ correct |
| 2 | 3a plafond sans LPP | `36'288` (`:64`) | CHF 36'288 (2026) | ✅ correct |
| 3 | LPP seuil d'entrée | `22'680` (`:234`) | CHF 22'680 (2026) | ✅ correct |
| 4 | LPP déduction coordination | `26'460` (`:245`) | CHF 26'460 (2026, = 7/8 rente AVS max) | ✅ correct |
| 5 | LPP salaire coordonné max | `64'260` (`:267`) | CHF 64'260 (2026) | ✅ correct |
| 6 | LPP salaire assuré max | `90'720` (`:278`) | CHF 90'720 (2026) | ✅ correct |
| 7 | LPP taux conversion min | `0.068` (`:289`) | 6.8% (LPP art. 14 al. 2) | ✅ correct |
| 8 | AVS rente max mensuelle | `2'520` (`:436` table) | CHF 2'520/mo (2026, 44 ans, rev. moyen ≥ 90'720) | ✅ correct |
| 9 | LPP bonifications 7/10/15/18% | `:311-350` | LPP art. 16 (7/10/15/18) | ✅ correct |
| 10 | **AVS âge réf. femmes** | **`65.0`** (`:504`) | **64.5 en 2026** (transition AVS21, atteint 65 en 2028) | ❌ **WRONG for 2026** (S0 for women's projections) |

**Verdict on the constants layer:** core prévoyance figures are accurate and well-sourced (`effective_from`, `source_title`, `source_url` per param — this is good registry hygiene). **Two material defects:**

- **DET-1 (S0):** `avs.reference_age_women = 65.0` (`registry.py:504`) is the AVS21 *endpoint*, not the 2026 value. A woman born 1962 retires at 64.5 in 2026. Any rente/anticipation projection for women aged ~62-64 is off by 6 months — and `coach_reasoner.dart:52` falls back to `avs.reference_age_men` anyway, so women's horizons are silently computed at 65. VZ would never ship a transition-year age as a flat 65.

- **DET-2 (S1):** The prompt's EPL/79b prose (`claude_coach_service.py:742`, "après un rachat, EPL bloqué 3 ans") is **materially under-specified**. Per art. 79b al. 3 LPP and the **two Tribunal fédéral arrêts of 26 Feb 2026**, the 3-year block applies to **every capital withdrawal** (retraite, départ de Suisse, indépendant, *and* EPL) and freezes the **entire retirement capital**, not only the rachat amount. The coach saying merely "EPL bloqué 3 ans" will mislead a user who plans a capital retirement withdrawal 2 years post-rachat. The Dart reasoner's risk note (`coach_reasoner.dart:145`) has the same narrowing ("tout retrait EPL est bloqué") — but at least it's structured. The live chat path has only the prompt prose.

Sources: [OPP3 art. 7 / 3a 2026 — finpension](https://finpension.ch/en/knowledge/maximum-amount-pillar-3a/) · [3a 2026 7'258 — Raiffeisen](https://www.raiffeisen.ch/rch/fr/clients-prives/prevoyance-et-assurance/montant-maximal.html) · [LPP 2026 seuils — Allianz](https://www.allianz.ch/fr/clients-prives/guide/prevoyance/explication-lpp.html) · [LPP 2026 montants — Robuste Fiduciaire](https://robuste.ch/lpp-obligatoire-pme-2026/) · [art. 79b al. 3 délai 3 ans — finpension](https://finpension.ch/en/glossary/definition-three-years/) · [TF 26.02.2026 règle absolue — juriup](https://juriup.ch/actualite-juridique/rachat-lpp-le-tribunal-federal-confirme-le-delai-de-3-ans/) · [AVS 21 âge réf. 2026 64.5 femmes — BSV](https://www.bsv.admin.ch/bsv/fr/home/assurances-sociales/ahv/donnees-de-base-et-legislation/ahv-21.html) · [rente max 2'520 2026 — Migros Bank](https://www.migrosbank.ch/fr/guide/prevoyance/rente-avs-maximale.html)

---

# 4. "VZ quality and beyond" — concrete definition + the advice contract MINT must adopt

**What a VZ (VermögensZentrum) advice output actually looks like:**
1. **Every number traces to a source** — the figure, the legal basis (LPP art. X / LIFD art. Y), and the year of validity, shown to the client.
2. **Every recommendation is an arbitrage with stated assumptions** — "we assume marginal rate 28%, fund return 1.5%, 8 years to retirement" — and the client can change them.
3. **Scenario ranges, never point promises** — bas/moyen/haut, with the sensitivity driver named.
4. **Caveats and disqualifiers up front** — "this only holds if you are not US-person / not within 3 years of a planned capital withdrawal."
5. **A named human owns irreversible calls** — capital-vs-rente, EPL, divorce-split are escalated to a person, not auto-advised.
6. **Directional/definitional correctness is non-negotiable** — a VZ advisor who said "rachat = withdrawing your capital" would be removed.

**Proposed MINT Advice Contract (the missing spec):**

> **C-1 — No bare claim.** Every *financial assertion* the coach emits (number OR definition OR directional cause→effect) must resolve to one of: (a) a registry constant with `source_url`, (b) a financial_core calculator output with an `inputs_hash` trace, or (c) an explicit "je n'ai pas cette donnée." A sentence that asserts a financial *fact* with none of these is a contract breach — gate it like an uncited number.
>
> **C-2 — Claim-level verification, not just number-level.** Build a deterministic **claim checker** for the ~50 highest-frequency Swiss financial assertions (rachat = paying in; EPL = anticipated withdrawal; rente = taxed as income; capital = taxed once separately; 3a deductible; etc.). Each is a (subject, relation, object) triple with a canonical truth and a set of known inversions. Run it on coach output the way `hallucination_detector` runs on numbers. **This is the direct fix for the founder's Exhibit A.** It is mechanical, testable, and closes HOLE-1.
>
> **C-3 — Forced retrieval for definitions, not just facts.** Extend the `project_coach_forced_tool_invocation` doctrine: make `get_regulatory_constant` / a new `define_concept` tool MANDATORY for any conceptual answer, and REJECT + re-prompt if the LLM produces a definitional claim with no tool trace — exactly as the founder's own memory already demands for numbers.
>
> **C-4 — Wire the reasoner.** `CoachReasonerService` already produces C-1..C-5-shaped output (assumptions/risks/sources/alternatives). Connect it to the chat path so structured advice replaces free-text recitation for the 5 levers it covers. Delete the dead-vs-live ambiguity (HOLE-5/6).
>
> **C-5 — Turn the gates ON or delete them.** The citation gate + verb/freshness/temporal gates are built, tested, and dark. Either flip `COACH_CITATION_GATE_ENABLED` (after the claim-checker C-2 is added, since the gate alone doesn't catch definitions) or stop carrying 1500 lines of dead guard code that creates false confidence in reviews.

---

# 5. CHALLENGE THE FOUNDER'S FRAMING (mandatory)

The founder's instinct — "audit the path to the advice, not just the advice" — is **correct and the single most valuable QA reframe in this project.** But the vision text, taken literally, is wrong/naive/under-specified in four Swiss-regulatory ways:

**5.1 — "Mint te dit ce que personne n'a intérêt à te dire" + a ranking arbitrage engine = you have become a conseiller (LSFin), not a narrateur.** The prompt insists "Tu es un narrateur, pas un conseiller... Tu ne donnes JAMAIS de recommandation personnalisée au sens LSFin art. 3" (`claude_coach_service.py:577-579`). Yet `coach_reasoner.dart:94` *ranks* personalised levers by return, and `get_couple_optimization` / `get_cross_pillar_analysis` compute personalised arbitrages. **You cannot simultaneously claim "pure information (art. 3 exempt)" and ship a personalised ranked arbitrage.** The moment output is "for *your* situation, lever A returns more than lever B," that is *conseil en placement* under LSFin art. 3 let. c — which carries suitability, documentation, and adviser-register obligations. The founder's framing treats the narrateur/conseiller line as a branding choice; it is a **regulated perimeter** with FINMA consequences. Decide deliberately: either (a) stay strictly educational (categories side-by-side, never ranked, never "for you") — then unwire the ranking — or (b) accept you're giving *conseil* and build the LSFin suitability/documentation scaffold. Today the code does (b) while the prompt claims (a). That gap is the real liability, larger than the rachat typo.

**5.2 — "The path to the advice" is necessary but not sufficient; the founder under-specifies *ground truth*.** Auditing the *path* assumes a *destination* exists. There is currently **no canonical claim-truth set** for qualitative assertions — only number constants. You can perfectly trace a path that arrives at a wrong-but-uncheckable definition. The founder's frame needs the addition of C-2: a deterministic claim-truth registry. Path-auditing without a ground-truth registry is "using a probabilistic tool to verify probabilistic output" (CLAUDE.md §9 / johnsonlee.io) for everything that isn't a number.

**5.3 — Liability of an arbitrage algorithm is not neutralised by a disclaimer.** The prompt auto-injects "Outil éducatif... ne constitue pas un conseil financier (LSFin)" (`compliance_guard.py:343`). Swiss regulators look at **substance over label** (FINMA Circ. 2008/21 risk-management lens; LSFin substance test). An algorithm that computes "your buyback saves CHF X/year and you should spread it over N years" is advice *whatever the footer says*. The disclaimer is a mitigant, not a shield. The founder's mental model ("we add a disclaimer, so we're educational") is the most common and most dangerous fintech misconception in CH. (Public-repo discipline: this is a design caution, not a legal admission — frame decision artifacts as Proposed.)

**5.4 — "VZ-and-beyond" is the wrong north star for the *definitional* failure.** VZ's edge is advisor judgment + depth. MINT cannot out-judge VZ with an LLM; it can out-*verify* VZ by making **every claim mechanically grounded** — which VZ's human advisors do *not* do (they rely on training + reputation). The "beyond" should be **deterministic claim-grounding at scale**, not "deeper opinions." Reframe the ambition from "VZ-quality advice" (judgment) to "VZ-correct facts with zero ungrounded claims" (verification) — that is both achievable for an LLM product and the actual fix for Exhibit A. Chasing "better advice" deepens the LSFin exposure in 5.1; chasing "provably grounded information" reduces it.

---

# 6. Recommended sequencing (for the orchestrator)

1. **DET-1 + DET-2** (data fixes, hours): correct `avs.reference_age_women` to a year-aware transitional value; rewrite the 79b/EPL prose to "tout retrait en capital bloqué 3 ans, capital entier" with the TF 26.02.2026 reference. Lowest-effort, highest-correctness.
2. **C-2 claim-checker** (the real fix for Exhibit A): a (subject, relation, object) truth set for the top ~50 Swiss assertions + known-inversion detection, wired into `ComplianceGuard` as a new blocking layer. This is what catches "rachat = retirer."
3. **5.1 perimeter decision** (founder + counsel): narrateur-only (unwire ranking) vs conseiller-with-scaffold. Everything else depends on this call.
4. **C-4**: wire `CoachReasonerService` or formally delete it (kill the façade).
5. **C-5**: gates ON (post C-2) or removed.

— end —
