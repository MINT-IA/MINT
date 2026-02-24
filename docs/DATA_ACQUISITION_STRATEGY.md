# DATA_ACQUISITION_STRATEGY.md — Precision Through Better Inputs

> How MINT evolves from "user guesses" to "verified financial state"
> without becoming a bank, without requiring aggregation licenses,
> and without violating LPD/nLPD.

---

## THE PROBLEM

MINT's projections are only as good as its inputs. Today:

```
Input quality:       User self-declaration (low precision)
Confidence score:    Measures completeness, not accuracy
Key unknowns:        LPP split oblig/suroblig, exact RAMD, real marginal rate
Error margin:        Estimated 10-30% on retirement projections
Impact:              Arbitrage comparisons can flip on a 5% input error
```

A user who enters "LPP environ 150k" when their certificate says 143'287 CHF
(of which 98'400 obligatoire) gets a rente vs capital comparison that's
materially wrong — because the 6.8% conversion only applies to the 98'400.

**This document defines how MINT progressively increases input precision
across 4 channels, from easiest to most sophisticated.**

---

## THE 4 CHANNELS

```
Channel 1 — Smart Document Parsing       (high impact, medium effort)
             User photographs documents → MINT extracts verified numbers

Channel 2 — Guided Precision Entry        (medium impact, low effort)
             Better questions, validation, cross-checks

Channel 3 — Open Banking / bLink          (high impact, high effort)
             Direct account data feeds

Channel 4 — Institutional Data APIs       (highest precision, longest term)
             Direct connections to caisses de pension, AFC, AVS
```

Each channel increases the ConfidenceScore and unlocks more precise features.

---

## CHANNEL 1 — SMART DOCUMENT PARSING

### The Insight

Swiss financial life produces physical documents with exact numbers.
Most people have these documents. They just don't know what to do with them.

MINT can say: "Photographie ton certificat de prévoyance. On lit les chiffres pour toi."

### Target Documents (by impact)

#### Document A: Certificat de prévoyance LPP (HIGHEST PRIORITY)

This single document contains:

```
- Avoir de vieillesse total              → lpp_total
- Part obligatoire                       → lpp_obligatoire (CRITICAL for rente vs capital)
- Part surobligatoire                    → lpp_surobligatoire
- Salaire assuré                         → lpp_insured_salary
- Taux de bonification                   → lpp_bonification_rate (actual, not statutory)
- Taux de conversion (obligatoire)       → conversion_rate_oblig (usually 6.8%)
- Taux de conversion (surobligatoire)    → conversion_rate_suroblig (often 4.5-5.5%)
- Rente de vieillesse projetée           → projected_rente
- Capital de vieillesse projeté à 65     → projected_capital_65
- Prestation d'invalidité               → disability_coverage
- Prestation de décès                    → death_coverage
- Lacune de rachat                       → buyback_potential
- Cotisation employé mensuelle           → employee_contribution
- Cotisation employeur mensuelle         → employer_contribution
```

This is the SINGLE MOST VALUABLE document for MINT.
It fills ~15 fields that the user would otherwise estimate.
It makes rente vs capital arbitrage actually reliable.

**Implementation approach:**

```
Step 1: User photographs certificate (camera or gallery)
Step 2: OCR extraction (on-device or API)
Step 3: Structured field detection (template-based + LLM-assisted)
Step 4: User confirms/corrects extracted values
Step 5: Values injected into profile with source = "document_lpp_certificate"
Step 6: ConfidenceScore jumps significantly
```

**Technical options for OCR + extraction:**

```
Option A — On-device OCR (ML Kit / Apple Vision)
  + Privacy: document never leaves device
  + No API cost
  - Lower accuracy on complex layouts
  - No LLM-assisted field detection

Option B — Cloud OCR API (Google Document AI / Azure Form Recognizer)
  + High accuracy
  + Pre-trained on financial documents
  - Document leaves device (LPD concern)
  - API cost per document

Option C — BYOK LLM with vision (Claude / GPT-4o via user's API key)
  + Highest accuracy for Swiss financial documents
  + Can handle varied layouts across 1000+ caisses
  + User's own API key = their consent
  - Depends on BYOK being configured
  - Variable cost

Recommended: Option A as default (privacy-first),
             Option C as upgrade for BYOK users (higher accuracy).
```

**Swiss LPP certificate formats:**

The challenge: there is NO standardized format across Swiss pension funds.
Each of the 1'400+ caisses de pension has its own layout.

Mitigation strategy:
- Build a base extractor for the ~20 most common caisses (covering ~60% of market)
- Use LLM-assisted extraction as fallback for unknown formats
- Always require user confirmation of extracted values
- Track extraction accuracy per caisse to improve over time

**Fields extracted → profile impact:**

```
Field extracted              Profile field updated       Impact on projections
────────────────────────────────────────────────────────────────────────────────
Avoir total                  lpp_total                   LPP capital projection
Part obligatoire             lpp_obligatoire             Rente vs capital (CRITICAL)
Part surobligatoire          lpp_surobligatoire          Rente vs capital (CRITICAL)
Taux conversion oblig        conversion_rate_oblig       Rente amount (CRITICAL)
Taux conversion suroblig     conversion_rate_suroblig    Mixed scenario (CRITICAL)
Lacune de rachat             buyback_potential           Rachat arbitrage
Rente projetée               projected_rente_lpp         Retirement projection
Prestation invalidité        disability_coverage         Gap analysis
Prestation décès             death_coverage              Gap analysis
Cotisation employé           employee_lpp_contribution   Net salary accuracy
Salaire assuré               lpp_insured_salary          Bonification accuracy
```

**ConfidenceScore impact:** +25-30 points from a single document scan.

---

#### Document B: Déclaration fiscale / Avis de taxation

Contains:
```
- Revenu imposable                → actual_taxable_income
- Fortune imposable               → actual_taxable_wealth
- Déductions effectuées           → actual_deductions (3a, frais, etc.)
- Impôt cantonal + communal       → actual_cantonal_tax
- Impôt fédéral                   → actual_federal_tax
- Taux marginal effectif          → actual_marginal_rate (CRITICAL for arbitrage)
```

Impact: the marginal tax rate drives ALL tax-related arbitrages.
A user who thinks their rate is 25% but it's actually 32% gets wrong results
on rachat LPP, 3a optimization, and allocation annuelle.

**Implementation:** Same OCR approach. Simpler because tax documents
are more standardized (26 cantonal formats, but structured).

**ConfidenceScore impact:** +15-20 points.

---

#### Document C: Relevé AVS (extrait de compte individuel)

Contains:
```
- Années de cotisation           → avs_contribution_years (exact)
- Revenu annuel moyen (RAMD)     → avs_ramd (CRITICAL for rente calculation)
- Lacunes de cotisation          → avs_gaps (years missing)
- Bonifications éducatives       → avs_education_credits
```

This is the document that makes AVS projections accurate instead of estimated.
Available from: www.ahv-iv.ch (Extrait de compte individuel CI).

Impact: AVS rente is the largest component of Swiss retirement income.
An inaccurate RAMD estimate can be off by CHF 200-500/month on the projected rente.

**Implementation:** This one is trickier — the CI extract is a PDF/letter.
OCR + field extraction. Alternatively, guide the user to request it and enter key fields manually.

**ConfidenceScore impact:** +20-25 points.

---

#### Document D: Attestation 3a

Contains:
```
- Solde actuel                   → pillar_3a_balance
- Versements cumulés             → pillar_3a_contributions
- Rendement net                  → pillar_3a_performance
```

Simple document, usually 1 page.

**ConfidenceScore impact:** +5-10 points.

---

#### Document E: Attestation hypothécaire

Contains:
```
- Capital restant dû             → mortgage_remaining
- Taux d'intérêt actuel          → mortgage_rate (real, not theoretical)
- Échéance du taux fixe          → mortgage_fixed_rate_expiry
- Amortissement annuel            → mortgage_amortization
- Valeur estimée du bien          → property_value (sometimes)
```

**ConfidenceScore impact:** +10-15 points for property owners.

---

### Document Parsing — Architecture

```
apps/mobile/lib/services/document_parser/
    document_scanner_service.dart       # Camera/gallery + OCR orchestration
    lpp_certificate_parser.dart         # LPP-specific field extraction
    tax_declaration_parser.dart         # Tax-specific field extraction
    avs_extract_parser.dart             # AVS CI-specific extraction
    generic_document_parser.dart        # Fallback LLM-based extraction
    extraction_confidence_scorer.dart   # Per-field confidence of extraction
    document_models.dart                # Shared types

apps/mobile/lib/screens/document_scan/
    document_scan_screen.dart           # Camera UI
    extraction_review_screen.dart       # User confirms/corrects values
    document_impact_screen.dart         # Shows how much precision improved
```

**User flow:**

```
1. "Photographie ton certificat de prévoyance"
2. Camera opens → user takes photo
3. Processing spinner (2-5 seconds)
4. Extraction review screen:
   "Voici ce qu'on a lu. Vérifie et corrige si nécessaire."
   - Avoir total: CHF 143'287 ✓ [edit]
   - Part obligatoire: CHF 98'400 ✓ [edit]
   - Taux conversion: 6.8% / 5.2% ✓ [edit]
   - Lacune rachat: CHF 45'000 ✓ [edit]
5. User confirms
6. "Ton profil est maintenant plus précis. Confiance : 78% (+27 points)."
7. Chiffre choc recalculated with real numbers
```

**Privacy rules (non-negotiable):**
- On-device OCR by default (document never leaves phone)
- If cloud OCR used: explicit consent + data deleted after extraction
- If BYOK LLM used: user's own API key, their responsibility
- Extracted values stored locally, encrypted at rest
- Original image NEVER stored (deleted after extraction)
- User can delete all extracted data at any time

---

## CHANNEL 2 — GUIDED PRECISION ENTRY

### The Insight

When document parsing isn't available, we can still dramatically improve
input accuracy through smarter questions and real-time validation.

### Technique 1: Contextual Help at Point of Entry

Instead of:
```
"Avoir LPP total" → [text field]
```

Do:
```
"Avoir LPP total" → [text field]
  ℹ️ "Ce chiffre se trouve sur ton certificat de prévoyance,
      ligne 'Avoir de vieillesse' ou 'Altersguthaben'.
      Si tu ne l'as pas, on peut estimer (~CHF {estimation})."
```

For EVERY financial field, provide:
- Where to find the exact number
- What document it's on
- What it's typically called (FR + DE for bilingual users)
- A fallback estimation if user doesn't know

### Technique 2: Cross-Validation

After entry, automatically check for consistency:

```python
# Example: LPP consistency checks
if lpp_total > 0 and age > 25:
    expected_min = estimate_lpp_min(age, salary)
    expected_max = estimate_lpp_max(age, salary)
    if lpp_total < expected_min * 0.5:
        alert("Ce montant semble bas pour ton âge et salaire. "
              "As-tu récemment changé d'emploi ou retiré un EPL?")
    if lpp_total > expected_max * 1.5:
        alert("Ce montant est élevé — est-ce que ça inclut le surobligatoire? "
              "C'est bien le total (obligatoire + surobligatoire)?")

# Example: Salary consistency
if gross_salary > 0 and net_salary > 0:
    expected_ratio = estimate_net_ratio(gross_salary, canton, age)
    actual_ratio = net_salary / gross_salary
    if abs(actual_ratio - expected_ratio) > 0.08:
        alert("L'écart entre ton brut et ton net est inhabituel. "
              "Vérifie que le brut inclut bien le 13ème si applicable.")

# Example: 3a consistency
if pillar_3a > 0 and age < 25:
    alert("Tu ne peux ouvrir un 3a qu'à partir de 18 ans avec un revenu soumis AVS.")
```

### Technique 3: Smart Defaults with Transparency

When user doesn't know a value, use the BEST possible estimate, not a generic one:

```
Instead of:    "LPP estimé" (based on statutory minimums)
Use:           "LPP estimé pour un·e {archetype} de {age} ans
                avec un salaire de {salary} dans le canton de {canton}"
```

Estimation should account for:
- Archetype (expat has fewer years, independent may have 0)
- Age (bonification rate matters enormously)
- Salary level (above/below coordination threshold)
- Sector (if known — public sector caisses are more generous)

### Technique 4: Progressive Precision Prompts

Don't ask everything upfront. Ask for precision when it MATTERS:

```
Trigger: User opens Rente vs Capital arbitrage
AND lpp_obligatoire is estimated (not from document)

Prompt: "Pour comparer rente et capital précisément,
         on a besoin de la part obligatoire de ta LPP.
         📄 Photographie ton certificat de prévoyance
         ✏️ Ou entre le montant manuellement
         ⏭️ Continuer avec l'estimation (~CHF {estimate})"
```

The precision ask happens at the moment of need, not during onboarding.
This is much higher conversion than asking upfront.

### Technique 5: Annual Recalibration via Tax Declaration

Every year in February-April (tax season), prompt:

```
"C'est la saison fiscale. Ton avis de taxation de l'année dernière
 contient tes vrais chiffres. 📄 Scanne-le pour recalibrer ton profil."
```

This creates a natural annual data refresh cycle aligned with Swiss fiscal calendar.

---

## CHANNEL 3 — OPEN BANKING (bLink / SFTI)

### Context

MINT S14 already implemented Open Banking bLink/SFTI integration.
This channel extends it for precision data.

### What Open Banking Provides

```
Account balances        → actual cash + savings amounts
Transaction history     → actual spending patterns
3a account balances     → actual 3a value (if 3a-bank account)
Mortgage details        → actual remaining debt + rate
```

### What Open Banking Does NOT Provide

```
❌ LPP details (not in banking system)
❌ AVS history (federal, not banking)
❌ Tax rate (cantonal, not banking)
❌ Insurance coverage (separate industry)
```

### Integration for Precision

If bLink is connected:
- Auto-populate cash, savings, 3a bank accounts
- Derive actual monthly expenses from transaction categorization
- Detect salary deposits → accurate gross/net
- Detect 3a transfers → track actual 3a utilization
- Detect mortgage payments → verify mortgage details

**ConfidenceScore impact:** +15-25 points depending on connected accounts.

### Privacy & Consent

Already handled in S14 architecture. Key rules:
- Explicit consent per account
- Read-only (MINT never moves money)
- User can disconnect at any time
- Transaction data processed locally, not sent to LLM

---

## CHANNEL 4 — INSTITUTIONAL APIs (Long-Term)

### The Vision

Direct data feeds from Swiss financial institutions.

### 4A: Caisse de Pension API

**Status:** No standard API exists today. BUT:
- Some large caisses (Publica, BVK, CPEV) have member portals
- The SwissPensions initiative is working on standardization
- EU EIOPA is pushing pension tracking standards

**What MINT can do now:**
- Partner with 2-3 large caisses for pilot API integration
- Use their member portal data (with user authentication)
- Demonstrate value → attract more caisses

**What this provides:**
- Real-time LPP balance (obligatoire + surobligatoire)
- Actual conversion rates
- Actual buyback potential
- Projected rente (by the caisse itself)
- Disability/death coverage

**ConfidenceScore impact:** +30-35 points. This is the holy grail.

### 4B: AVS/AI Information System

**Status:** The extrait de compte individuel (CI) is available online
at www.ahv-iv.ch. No public API, but:
- User can download their CI as PDF
- Future: eID-based authentication could enable direct access

**What MINT can do now:**
- Guide user to request their CI online
- Parse the PDF (Channel 1 approach)
- Extract: contribution years, RAMD, gaps, bonifications

### 4C: AFC Tax Data (Cantonal Tax APIs)

**Status:** Some cantons offer online tax calculators with APIs.
- Most cantonal tax administrations have public barème data
- Real marginal rates can be computed from barèmes without user data

**What MINT already does:** TaxCalculator estimates marginal rates.

**What could improve:**
- Integrate cantonal barème data more precisely (26 cantons × communes)
- Allow user to import from their cantonal tax portal

### 4D: Insurance Coverage Data

**Status:** No standard API. But:
- Some insurers offer digital attestations
- User can photograph their police d'assurance

**Lower priority** — disability and death coverage are important but
less frequently changing than LPP or tax data.

---

## CONFIDENCE SCORING EVOLUTION

### Current: Binary Completeness

The current `ConfidenceScorer` measures: "How many fields are filled?"

### Proposed: Multi-Dimensional Confidence

```dart
class EnhancedConfidenceScorer {
  /// Scores confidence on 3 axes
  ConfidenceBreakdown score(UserProfile profile) {
    return ConfidenceBreakdown(
      completeness: _scoreCompleteness(profile),    // Fields filled (current)
      accuracy: _scoreAccuracy(profile),             // Source quality (NEW)
      freshness: _scoreFreshness(profile),           // Data age (NEW)
    );
  }
}

class ConfidenceBreakdown {
  final double completeness;  // 0-100: how many fields are filled
  final double accuracy;      // 0-100: how reliable are the sources
  final double freshness;     // 0-100: how recent is the data
  final double overall;       // Weighted combination

  // Actionable: what would improve confidence the most
  final List<EnrichmentPrompt> topEnrichments;
}
```

### Accuracy Scoring by Source

```
Source                              Accuracy weight
──────────────────────────────────────────────────
Open Banking (live)                 1.00
Document scan (verified)            0.95
Institutional API                   0.95
Document scan (unverified)          0.85
User entry (with cross-validation)  0.70
User entry (raw)                    0.50
Estimation (from defaults)          0.25
```

### Freshness Scoring

```
Data age          Freshness score
────────────────────────────────
< 1 month         1.00
1-3 months         0.90
3-6 months         0.75
6-12 months        0.50
> 12 months        0.25
```

### Impact on Features

```
Overall Confidence    Features Available
──────────────────────────────────────────────
< 30%                 Basic chiffre choc only (wide ranges)
30-50%                Standard projections (3 scenarios)
50-70%                Arbitrage comparisons (with uncertainty bands)
70-85%                Precise arbitrage + FRI scoring
> 85%                 Full precision + longitudinal tracking meaningful
```

**Key rule:** Arbitrage modules show wider uncertainty bands
when confidence is lower. The comparison is still shown,
but with: "Avec une confiance de 55%, les résultats pourraient
varier de ±15%. Scanne ton certificat LPP pour plus de précision."

---

## DATA ACQUISITION FUNNEL

### Mapping the User Journey to Data Collection

```
ONBOARDING (30 sec)
  ├── 3 questions (salary, age, canton)
  ├── Confidence: ~25%
  └── Unlock: chiffre choc + basic projections

FIRST SESSION (5-10 min)
  ├── Progressive enrichment (family, savings, property)
  ├── Confidence: ~40-50%
  └── Unlock: standard projections, basic coaching

FIRST WEEK
  ├── Document scan prompt: "Scanne ton certificat LPP"
  ├── 3a attestation scan
  ├── Confidence: ~65-75%
  └── Unlock: arbitrage comparisons, FRI

FIRST MONTH
  ├── Open Banking connection (optional)
  ├── AVS extract (guided request)
  ├── Confidence: ~80-90%
  └── Unlock: full precision, reliable longitudinal tracking

ANNUAL REFRESH
  ├── Tax declaration scan
  ├── Updated LPP certificate
  ├── Confidence refresh: maintain > 75%
  └── Keep projections accurate year over year
```

### Conversion Incentives (Why Users Share Data)

Users share data when they see IMMEDIATE value. Not "for better accuracy."

```
Trigger                          Incentive shown
──────────────────────────────────────────────────────────────────────
After chiffre choc               "Avec ton vrai certificat LPP,
                                  cette estimation deviendrait exacte."

Before arbitrage                 "Pour comparer rente vs capital,
                                  on a besoin de ta part obligatoire.
                                  📄 Scanne ton certificat (30 sec)."

After FRI display                "Ton score est basé sur des estimations.
                                  Avec tes vrais chiffres, il pourrait
                                  changer de ±10 points."

Tax season (Feb-Apr)             "Ton avis de taxation = tes vrais chiffres.
                                  📄 Scanne-le pour recalibrer."

After salary change              "Ton salaire a changé? Ton nouveau
                                  certificat LPP aussi. 📄 Mets-le à jour."
```

**NEVER use guilt, urgency, or dark patterns to collect data.**
Always: "Voici ce que ça t'apporte. Voici ce qu'on fait avec. Tu décides."

---

## IMPLEMENTATION ROADMAP

### Phase 1 — Guided Precision Entry (S41, low effort, immediate impact)

```
- Contextual help on every financial field ("Où trouver ce chiffre")
- Cross-validation alerts (LPP vs age/salary, salary gross vs net)
- Smart defaults by archetype (not generic)
- Progressive precision prompts at point of need
```

Effort: ~1 sprint. No new infrastructure.
Impact: Reduces input errors by estimated 30-50%.

### Phase 2 — LPP Certificate Parsing (S42-S43, high impact)

```
- Camera integration (existing packages: camera, image_picker)
- On-device OCR (google_mlkit_text_recognition)
- LPP field extraction engine (template-based for top 20 caisses)
- LLM-assisted extraction fallback (BYOK users)
- Extraction review screen (user confirms values)
- Profile injection + confidence update
```

Effort: 2 sprints. Requires OCR testing with real certificates.
Impact: +25-30 confidence points per user who scans.

### Phase 3 — Tax Declaration Parsing (S44)

```
- Same OCR pipeline as Phase 2
- Tax-specific field extraction (simpler format, more standardized)
- Marginal rate extraction (CRITICAL for arbitrage accuracy)
```

Effort: 1 sprint (reuses Phase 2 OCR infra).
Impact: +15-20 confidence points. Accurate marginal rate.

### Phase 4 — AVS Extract Guidance + Parsing (S45)

```
- In-app guide: "Comment demander ton extrait CI"
- Link to www.ahv-iv.ch
- PDF parsing when user uploads/photographs the extract
- Contribution years + RAMD extraction
```

Effort: 1 sprint.
Impact: +20-25 confidence points. Accurate AVS projection.

### Phase 5 — Enhanced Confidence Scoring (S46)

```
- Migrate from completeness-only to completeness + accuracy + freshness
- Source tracking per field (document, manual, estimated)
- Freshness decay over time
- Enrichment prompts ranked by impact on confidence
```

Effort: 1 sprint.
Impact: Users understand WHY precision matters and WHAT to do about it.

### Phase 6 — Institutional Partnerships (S47+, long-term)

```
- Pilot with 2-3 large caisses de pension
- API integration for real-time LPP data
- eID authentication exploration
```

Effort: 3-6 months of business development + technical integration.
Impact: The ultimate precision play. Confidence > 95%.

---

## DATA QUALITY RULES (for agents)

### Rule 1: Always track source per field

```dart
class ProfileField<T> {
  final T value;
  final DataSource source;
  final DateTime updatedAt;
  final double fieldConfidence;  // Based on source quality
}

enum DataSource {
  userEstimate,          // "environ 100k"
  userEntry,             // User typed exact number
  userEntryCrossValidated, // User typed + passed consistency check
  documentScan,          // OCR from certificate
  documentScanVerified,  // OCR + user confirmed
  openBanking,           // Live bank feed
  institutionalApi,      // Direct from caisse/AFC
  systemEstimate,        // MINT computed default
}
```

### Rule 2: Show source quality to user

```
"Avoir LPP: CHF 143'287  📄 Source: certificat de prévoyance (mars 2026)"
"Avoir LPP: CHF ~150'000  ✏️ Source: estimation  [📄 Scanner mon certificat]"
```

Users who see that a number is estimated are more motivated to provide the real one.

### Rule 3: Decay confidence over time

A LPP certificate from 2024 is less reliable in 2026.
Apply freshness decay: -10% confidence per year of age.

### Rule 4: Never pretend estimated data is precise

If a projection uses estimated inputs, ALWAYS surface this:
```
"Cette projection utilise 3 valeurs estimées.
 Scanne ton certificat LPP pour un résultat plus fiable."
```

### Rule 5: Cross-validate on every new data point

When user adds a new piece of data, check consistency with existing data.
Flag contradictions rather than silently accepting.

---

## COMPLIANCE (LPD / nLPD)

### Document Scanning

- Original image deleted immediately after OCR (never stored)
- Extracted values stored locally, encrypted at rest
- If cloud OCR used: explicit consent, data deleted on provider side after processing
- User can delete all extracted data at any time

### Source Tracking

- Source metadata is for internal quality tracking, not shared externally
- Never sent to LLM (CoachContext does not include source metadata)

### Open Banking

- Already covered by S14 bLink architecture
- Read-only, explicit consent per account, revocable

### Institutional APIs

- Authenticated via user's credentials (eID or portal login)
- MINT never stores institutional credentials
- Data pulled on user request, not continuous monitoring

---

## SUCCESS METRICS

| Metric | Current (est.) | Target (12 months) |
|--------|---------------|-------------------|
| Average confidence score | ~35% | > 60% |
| Users with LPP certificate scanned | 0% | > 30% |
| Users with accurate marginal rate | ~20% | > 50% |
| Arbitrage precision (LPP split known) | ~10% | > 40% |
| Data freshness (< 6 months) | unknown | > 70% |
| Users who completed annual refresh | N/A | > 40% |

---

*Document version: 1.0 — February 2026*
*Depends on: CLAUDE.md (constants), ONBOARDING_ARBITRAGE_ENGINE.md (arbitrage specs)*
*Feeds into: MINT_COACH_VIVANT_ROADMAP.md (confidence thresholds for features)*
