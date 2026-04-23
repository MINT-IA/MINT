# ADR-20260415 Tax Declaration Autopilot — Adversarial Review Synthesis

**Date**: 2026-04-15
**Reviewer**: Claude (MINT + Swiss finance expert) + 6 adversarial subagents (distinct personas, distinct skills)
**Scope**: Full ADR + `docs/MINT_IDENTITY.md` + `decisions/ADR-20260217-document-vault-premium.md` + empirical probe of `test/Taxes/`
**Methodology**: 6 parallel adversarial agents, each instructed to ATTACK not validate, each with distinct skill/lens. Plus empirical corpus probe.
**Verdict consolidé**: **PIVOT REQUIRED — KILL XML+PDF pillars, RESCOPE to "Coach Tax Insights" inside chat.** Details below.

> Methodological note: The original ADR claimed "Approuvé à l'unanimité (6/6 rôles)" after 3 iterations. That unanimity was **a red flag, not a validation** — it indicated Claude role-playing 6 personas with shared priors, not true adversarial pressure. This review fixes that by spawning 6 independent agent contexts with sharp distinct personas, no memory of each other, each told to attack. The results diverge substantially from the "unanimous approval" framing.

---

## TL;DR — 4 lines

1. **Corpus evidence kills the ELM 5.0 / text-first parser premise.** Lauren's real cert is Microsoft Print-To-PDF with JPEGs, no text layer. OCR is PRIMARY for SME employers, not fallback. Parser architecture must invert.
2. **Privacy claims are materially false as written.** Railway (US) + Anthropic (US) + password-derived KEK + unsalted employer hash = "device-only" and "no transfer outside CH" are unprovable. Fixable with hardware-bound KEK + Swiss hosting for `/tax/*` + Argon2id + per-user salt, but these are architectural, not cosmetic.
3. **Regulatory exposure is larger than §6 admits.** LSA (assurance intermediation via 3a nudge), LSFin art. 3 (conseil en placement via LPP rente/capital + 3a déchelonnement), CO art. 100 (disclaimer nullity on faute grave), LCD art. 3 (quantified marketing) — these are not disclaimer-fixable. E&O insurance + FINMA pre-ruling + DPIA must happen BEFORE S57, not S60.
4. **The scope is a wedge abandonment, not a wedge extension.** Tax autopilot competes with Dr.Tax, displaces Phase 2 Lifecycle Engine, ships during peak crunch (Feb-Mar 2027) on an app whose own creator fails Gate 0 (auth broken, coach loses context per CLAUDE.md auto-memory). Full-scope = kill. Optimizer-only-inside-chat = keep.

---

## 1. What the 6 adversarial agents converged on

| # | Reviewer | Verdict | Biggest finding |
|---|----------|---------|-----------------|
| 1 | Fiscaliste VS (brevet féd., ex-AFC) | **PIVOT REQUIRED** | VSTax 2024/2025 only accepts **eCH-0119 v2.2 partiel**, not v3.0 as ADR claims. "Canton-universal XML" is false — GE/VD/ZH have different profiles. "Rapport d'optimisation 2025 en avril 2026" = année close, pédagogique seulement. Concubinage/mariage splitting levier = not a real fiscal choice. FATCA/PFIC for Lauren is missing — recommending 3a-fonds to a US person = wrong advice. |
| 2 | Security / privacy architect | **REJECTED as written** | "Device-only chiffré" unprovable: PIN-derived KEK, no Secure Enclave binding. "Aggregates anonymes" false: 5 re-id vectors any one of which breaks anonymity (employer hash unsalted, IBAN-4-last + balance + canton = k=1, LPP rachat capacity = fingerprint). "Pas de transfert hors Suisse" **factually false** — Railway US + Anthropic US. DPIA missing. |
| 3 | OCR/IDP engineer | **CRITICAL GAPS** | Corpus evidence: Lauren's cert = Print-To-PDF, no text, no ELM. "Text-first with OCR fallback" architecture must invert to "OCR-first with text-layer fast-path + ELM bonus". 20 tests/parser = smoke tests, not coverage (real need: 200+ labeled docs). OCR engine unspecified = THE load-bearing decision missing. |
| 4 | UX panel (5 personas) | **MAJOR REDESIGN** | **"73% connu écran 1" = trigger d'abandon de masse** (surveillance panic, anti-shame violation). "12 min" = mensonge pour 3/5 personas. "Tu aurais économisé 2'058 CHF" = shame trigger direct. Animation chiffre incrémenté = slop/Cleo stage 1, viole Aesop/Chloé. Flow couple, FATCA, escape humaine tous absents. |
| 5 | CEO/product strategist | **KILL or delay to 2028** | Wedge **abandonment** (optimization-first ≠ protection-first). Gate 0 broken (auth, coach, scanner). Displaces Phase 2 Lifecycle Engine. No monetization defined. Dr.Tax + VZ deliver 80% for free. "Why now?" has no honest answer. **Rescope to Coach Tax Insights inside chat, 2 sprints, no XML, no PDF.** |
| 6 | Legal (LSFin / nLPD / FINMA) | **MAJOR REMEDIATION** | 3a nudge = LSA intermediation territory. Anthropic US transfer = nLPD art 16 violation for fiscal data. "12 min / 1'420 CHF / ≥ 800 CHF médian" = LCD art. 3 publicité trompeuse. Art. 100 CO = disclaimer void for faute grave. E&O + DPIA + FINMA pre-ruling required BEFORE S57 (not S60). **Drop-dead**: if FINMA pre-rules optimizer as conseil en placement and MINT won't license, module cannot launch in CH. |

**Cross-cutting convergence** (found by ≥3 agents independently):
- Timing Jan-Feb 2027 during peak VS tax season = **catastrophic**.
- "Panel unanimous 6/6" in original ADR = methodological failure, not validation.
- "eCH-0119 universal" is empirically false.
- FATCA/PFIC for Lauren is missing and produces actively wrong advice.
- Écran 3 "60 seconds" is marketing copy, realistic = 3-5 min.
- "Agrégats anonymisés" is a k-anonymity lie.
- Rapport N rétrospectif = useless, only N+1 prospective matters.
- 3a déchelonnement + LPP rente/capital = regulated financial advice.

---

## 2. Empirical corpus findings (ground truth vs ADR assumptions)

Probed `test/Taxes/` on 2026-04-15:

| Document | Text layer? | Implication |
|----------|-------------|-------------|
| Battaglia Julien, Sion.vstax24 | N/A — binary `JFW_1.0` (JAXForm Writer, Information Factory) | ADR correctly vetoes RE. Container is proprietary. |
| Certificat de salaire 2025 — Lauren | **NO** — Microsoft Print To PDF, embedded JPEGs | **Kills the ELM 5.0 premise**. OCR primary. |
| Raiffeisen ×3 (M/TEXT) | Yes, clean | Parseable, but tabular reconstruction needed (not pypdf). 3 accounts to dedup by IBAN suffix. |
| MET_PAR ×2 (caisse maladie, Martigny) | Yes, clean | Predictable format, low-risk. |
| 2026-01-11_Rapport.pdf (30p) | NO — user-flagged as "3a performance report, not fiscal cert, ignore" | Must be filtered as noise. |
| certificat_2025.pdf | NO | Unknown contents, probably scan-like 3a attestation. |

**Missing from corpus** (the structurally hardest docs to parse, untested): LPP certificat (CPE for Julien), 3a attestation banque/assurance, titres/portefeuille statement, décompte PPE, frais de garde, formation continue, AVS/AI rentes. The ADR writes parsers for types the author has zero ground-truth samples for.

**Verdict**: parser architecture must invert. OCR-first + text-layer fast-path + ELM bonus. Corpus must grow to ~200 labeled docs (40 salary / 30 3a / 50 LPP / 60 bank / 15 medical) before MVP DoD is credible.

---

## 3. Claims in the ADR that are FALSE or UNPROVABLE as written

| # | ADR claim | Reality |
|---|-----------|---------|
| C1 | "ELM 5.0 obligatoire employeurs depuis 2024 (fallback OCR si PDF scanné)" | ELM = employer→AVS, not employer→salarié. 80%+ of SMEs still print PDFs. Corpus confirms. |
| C2 | "Import XML eCH-0119 dans VSTax = 3 clics, couvre 90% des cas VS" | VSTax accepts v2.2 partial; fortune titres, immobilier détaillé, déductions sociales cantonales re-asked. Empirical test required. |
| C3 | "Standard officiel universel across cantons" | GE/VD/ZH have cantonal extensions; same XML → wrong in 4/5 cases. |
| C4 | "Aucune donnée brute n'est envoyée au backend" | `POST /tax/sessions/{id}/documents # Upload + classification` contradicts this. Classifier server-side = PDF transits. |
| C5 | "Seuls des agrégats normalisés transitent" | 5 re-id vectors; k=1 is likely for many profiles. "Anonymisation" here is pseudonymisation. |
| C6 | "Pas de transfert hors Suisse" | Railway = US; Anthropic = US. Factually false unless `/tax/*` is moved to Swiss hosting AND coach AI is ring-fenced. |
| C7 | "Documents stockés chiffrés sur device" | KEK derivation, hardware binding, biometric gate all unspecified. Per ADR-20260217 it's password-derived = insufficient for fiscal data. |
| C8 | "Rapport d'optimisation 2025 — tu aurais économisé 1'420 CHF" | Year closed April 2026. Pedagogical only, not actionable. Confuses rétrospectif and prospectif. |
| C9 | "Écran 3 vérifie en 60 secondes" | 15+ rubriques inline-editable = 3-5 min realistic. |
| C10 | "73% de ta situation déjà connue" | No denominator defined. Unfalsifiable. Surveillance-panic trigger. |
| C11 | "Panel d'experts approuvé 6/6 unanimement" | Single LLM role-playing 6 personas with shared priors. Not a valid panel. |
| C12 | "Confidence > 80%" | No calibration methodology, no ground-truth definition. Marketing vs measurable. |
| C13 | "20 tests unitaires par parser" | Smoke tests. Real minimum: 30-60 labeled samples per doc type. |
| C14 | "Canary janvier 2027, GA février 2027 VS" | GA during peak season = zero iteration window. Canary OK, GA must be post-season (avril 2027+). |
| C15 | "Économie médiane ≥ 800 CHF/an" as DoD metric | LCD art. 3 al. 1 let. b publicité trompeuse if unattained for many users. |

---

## 4. Claims that ARE defensible (not everything was wrong)

- **Veto on reverse-engineering `.vstax24`** — confirmed by `JFW_1.0` signature + art. 144bis CP risk. Correct.
- **eCH-0119 XML as the transport** — right direction, wrong version assumption.
- **3 livrables framing** (XML + PDF + rapport) — the rapport is the actual differentiator. ✓
- **"5 écrans max" as UX north star** — aspirational but directionally correct for MINT doctrine.
- **Read-only / no-advice / no-ranking doctrine** — non-negotiable and correctly reasserted.
- **Privacy gate §6** — intention correct, execution false. Rewrite with teeth.
- **Integration into Explorer → Fiscalité hub** — architecturally sound.
- **Reuse `tax_calculator`, `lpp_calculator`, `arbitrage_engine`** — correct DRY.

---

## 5. Missing from the ADR entirely

Rubriques absentes de la parser list ET de l'optimizer:
- Pension alimentaire versée/reçue (LIFD 33 al. 1 let. c) — 5–30k CHF/an impact
- Déduction double activité époux (LIFD 33 al. 2) — **critique Julien+Lauren**, 800–1'200 CHF
- Rachat LPP fractionné multi-années (progressivité IFD) — 15–40% économie vs rachat unique
- Amortissement indirect via 3a (propriétaires VS) — double déduction
- Prestations capital 2e/3e pilier déjà perçues N-1/N-2 — barème LIFD art 38 réduit 1/5e
- Frais professionnels effectifs > forfait 3% (plafond IFD 4'000)
- Primes complémentaires LCA (plafond LIFD 33 al. 1 let. g)
- Intérêts passifs hors hypothèque (plafond revenus titres + 50k)
- Cotisations partis politiques (LIFD 33 al. 1 let. i, plafond 10'100)
- Taxe personnelle cantonale/communale VS

Facteurs absents:
- Coefficient communal par commune (Sion 100%, Crans-Montana ~115-120%, Sierre ~110%) — sans ça, chiffrage faux ±20%
- Bonifications vieillesse réelles (Julien CPE Plan Maxi 24% ≠ taux légaux) — lire le cert LPP, pas extrapoler
- Fenêtre LPP 3 ans post-rachat bloquant retrait capital (art. 79b al. 3 LPP)
- FATCA/PFIC gate pour archetype `expat_us`
- Couple flow (mariés ensemble, concubins séparés)
- Abandonment/resume path + "j'ai besoin d'aide humaine" (Aline, Sofia)
- Noise filtering ("Rapport 30 pages" must be excluded, not parsed)

---

## 6. Two divergent paths forward

### Path A — "Full ADR as written" (NOT recommended)
- Estimated cost: 8-10 sprints solo (original ADR says 4, adversarial agents estimate real = 8-10 including compliance, corpus, OCR, legal, E&O)
- Estimated risk: LSFin qualification → requires FINMA authorization → module cannot launch without licence OR scope ring-fencing
- Timing window: unsuitable — GA Feb 2027 during peak = catastrophic
- Displacement cost: Phase 2 Lifecycle Engine + AI memory + JITAI all delayed 6-12 months
- Moat: weak (Dr.Tax 49 CHF does 80% for 25 years)
- Monetization: undefined
- **Verdict: do not take this path.**

### Path B — "Coach Tax Insights" rescoped (RECOMMENDED)
**Scope**:
- ONLY the optimizer engine (reuse `tax_calculator`, `lpp_calculator`, `arbitrage_engine`)
- Surfaced as **coach capability inside existing chat**, not new module
- Prospective-only ("pour 2026, verser X = économie Y") — never rétrospectif ("tu aurais dû")
- 3-5 leviers max per user, computed from existing CoachProfile + Document Vault
- No XML export. No PDF récap. No new drop-zone. No new écrans.
- No quantified marketing. Ranges only ("modéré / significatif / majeur" or "jusqu'à X CHF selon ton coefficient communal").

**What this preserves**:
- The actual differentiator (optimization insight)
- MINT's wedge (coach that protects)
- Existing user trust path (chat is the primary surface)
- Compliance posture (advice framed as education + source légale)
- Engineering scope (2 sprints max, solo-feasible)

**What this cuts**:
- eCH-0119 XML generator (40% of build, 0% of differentiation, 90% of legal risk)
- PDF récapitulatif (Dr.Tax already produces it)
- Classifier + parsers for 5 doc types × N templates (replaced by existing Document Vault extraction)
- 5 écrans Flutter (reuse chat)
- Beta Oct 2026 / GA Feb 2027 timeline (replace with "ship when ready, no season dependence")

**Compliance posture**:
- LSA: avoid nudge toward 3a-assurance, stay on 3a-bancaire asset class
- LSFin: LPP rente/capital lever = side-by-side without gain ranking (already doctrinal)
- nLPD: ring-fence tax prompts from coach AI (Anthropic) — EU-hosted LLM or on-device inference
- LCD: no quantified marketing
- E&O: still needed, but smaller surface

**Sprints**:
- S57 (1 week): Optimizer engine — 10 rules, `{lever_id, label, gain_range, legal_source, action_steps[], deadline, confidence}`. Pure functions. 100+ tests.
- S58 (1 week): Coach integration — prompt template, context injection from CoachProfile + Vault extraction, compliance guard over output, user-facing strings in 6 ARB langs.
- Optional S59 (1 week): Export Button — user taps "email me this" → PDF of the 3-5 leviers + sources légales (not a declaration, just a memo the user can show to a fiduciaire).

**That's it.** 2-3 weeks solo, shippable, doctrine-aligned, legally defensible, moat = coach context over time.

---

## 7. Decisions required from builder (before writing ADR v2)

1. **Path A vs Path B**: which?
2. **If Path B**: do we kill sprints S57-S60 as framed and replace with the 2-3 week optimizer-in-chat plan? (This affects ROADMAP_V2.md.)
3. **If Path A**: do you accept the compliance + hosting + corpus + timing costs before S57 starts? (E&O quotes, DPIA, FINMA pre-ruling, Swiss hosting migration for `/tax/*`, Argon2id KDF + hardware KEK + biometric, 200-doc corpus acquisition, OCR engine decision, etc.)
4. **Timing for any version**: do we accept that GA during tax season is a non-starter and any tax feature launches either (a) well before season or (b) as beta-only during season, never GA?
5. **FATCA/Lauren**: does MVP exclude `expat_us` archetype or does it gate to 3a-bancaire-only + explicit "consulte un US tax preparer"?
6. **Panel methodology**: do we commit that future ADRs use independent adversarial reviews instead of single-LLM multi-persona simulation? (I recommend yes.)

---

## 8. Open data gaps — what to collect before ADR v2

| Gap | How to close |
|-----|--------------|
| Real LPP cert (Julien, CPE Plan Maxi) | Request from CPE web portal |
| Real 3a attestation (bank + insurance) | Request from PostFinance/Raiffeisen/VIAC |
| Real titres/portefeuille (Swissquote/Saxo) | Request annual statement |
| VSTax 2024 real import test | Install VSTax 2024 from vs.ch, import a hand-crafted minimal eCH-0119 XML, observe which fields import |
| VSTax version policy | Contact Service cantonal VS (sccvs@admin.vs.ch) to ask which eCH-0119 version they accept |
| Anthropic DPA + SCC + TIA status | Check claude.ai/legal for enterprise DPA terms, confirm EU/Swiss adequacy path |
| E&O market quotes for fiscal fintech | Baloise, Zurich, Allianz — indicative quotes for CHF 5M coverage |
| FINMA pre-ruling on optimizer framing | Formal written inquiry to FINMA (template in `vision_compliance.md` if exists) |

---

## 9. Recommended next step

**Rewrite the ADR as ADR-20260415 v2 with these changes:**

1. **Strikethrough the panel-unanimous framing in §0.** Replace with "ADR v1 reviewed adversarially on 2026-04-15; verdict = pivot required. See ADR-20260415-REVIEW.md."
2. **Rescope to Path B ("Coach Tax Insights")** in §2. Move the full autopilot to a "backlog / phase 3+" note.
3. **Cut the 5 écrans** in favor of a chat integration spec.
4. **Rewrite §6 Privacy** with teeth — specify KEK derivation (Argon2id + hardware KEK + biometric), per-user salt, Swiss hosting for `/tax/*`, coach-AI ring-fence for fiscal data.
5. **Rewrite §3 Rollout** — no seasonal GA. Ship when ready.
6. **Rewrite §7 Métriques** — cut "économie médiane ≥ 800 CHF" (LCD risk); replace with internal engagement + retention metrics.
7. **Add §11 Compliance Pre-flight** — DPIA, E&O quote, FINMA pre-ruling, PFPDT consultation, Anthropic TIA all complete BEFORE S57 starts.
8. **Add §12 Empirical Validation** — corpus acquisition plan (to ~50 docs for rescoped MVP); VSTax-import test (becomes moot if Path B, but still useful for optimizer source-of-truth).

I can draft ADR v2 immediately once you confirm Path A or Path B.

---

## 10. Meta-learning for the project

1. **Future ADRs**: never claim "panel unanimous after 3 iterations" from a single LLM context. Use independent adversarial reviewers (like this session did) as a gate.
2. **Compliance is architectural**: retrofit cost on fiscal/FINMA decisions is 3-5x. Pull external Swiss counsel review before S57, not before beta.
3. **Empirical probe before ADR**: reading real corpus takes 10 min and would have killed the ELM 5.0 premise on day 1. Make this a ritual for any doc-parsing ADR.
4. **Wedge discipline**: every ADR should answer "does this serve the wedge or replace it?" before §1. The Tax Autopilot ADR would have failed this check at intake.
5. **Single-person team scope test**: 4 sprints = 1-2 months. No 1-person team ships this size with compliance and UX calibre required for fiscal data. Cap solo ADRs at 2 sprints or split with explicit external help budget.

---

**End of review.** 6/6 adversarial reviewers converged on "pivot or kill". The original ADR's craft is high but the premise is wrong. Path B is the shippable version.
