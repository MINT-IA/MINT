# ORCHESTRATOR.md — Master Automation Script (Auto-Resume)
# Place in: .claude/ORCHESTRATOR.md
# Usage: Open Claude Code, paste ONE line:
#
#   Lis .claude/ORCHESTRATOR.md et exécute-le.
#
# The orchestrator auto-detects where you are and resumes from there.

---

## WHO YOU ARE

You are the Team Lead orchestrating the MINT Coach Vivant evolution.
You execute sprints autonomously: implement, test, commit, next sprint.

You DO NOT ask the user for permission between sprints.
You DO ask the user ONLY when:
- A test fails and you can't fix it in 3 attempts
- An audit reveals a critical bug that changes production numbers
- Something in the specs is ambiguous enough to produce two very different implementations

Otherwise: execute, test, commit, next. Full autonomy.

---

## AUTO-DETECT: WHERE ARE WE?

Before doing anything, run this detection sequence:

```
STEP 1 — Check which docs exist:

  EXISTS(.claude/AGENT_FINANCIAL_CORE_UNIFICATION.md)  ? → DOC_UNIF
  EXISTS(.claude/AGENT_COACH_VIVANT_MASTER_PROMPT.md)  ? → DOC_COACH
  EXISTS(docs/ONBOARDING_ARBITRAGE_ENGINE.md)          ? → DOC_ARB
  EXISTS(docs/MINT_COACH_VIVANT_ROADMAP.md)            ? → DOC_ROAD
  EXISTS(docs/DATA_ACQUISITION_STRATEGY.md)            ? → DOC_DATA
  EXISTS(docs/MINT_V2_INTEGRATION_PATCH.md)            ? → DOC_PATCH

  If ANY of the first 5 are false → STOP:
    "Il manque des documents Coach Vivant dans le repo.
     Copie ces fichiers depuis tes downloads :
     [list missing files with target paths]
     Puis relance-moi."

STEP 2 — Check integration patch status:

  GREP rules.md for "Arbitrage = comparaison"
  GREP LEGAL_RELEASE_CHECK.md for "Arbitrage Engine Compliance"
  GREP DefinitionOfDone.md for "Coach Vivant Sprints"
  GREP TEST_ROADMAP.md for "Persona Anna" OR "Persona \"Anna\""
  GREP AGENTS.md for "S30.5"

  If ALL found → PATCH_APPLIED = true
  If ANY missing → PATCH_APPLIED = false

STEP 3 — Check S30.5 status:

  EXISTS(docs/reports/FINANCIAL_CORE_AUDIT.md)           ? → S305_PHASE1 = done
  EXISTS(docs/reports/FINANCIAL_CORE_CLEANUP_PLAN.md)    ? → S305_PHASE2 = done
  EXISTS(docs/reports/FINANCIAL_CORE_COMPLETION.md)       ? → S305_PHASE6 = done

  Check git log for "S30.5" or "financial core unification":
    git log --oneline --all | grep -i "S30.5\|financial.core.unif\|core.unification\|financial-core\|unify calculations"
    If found → S305_COMMITTED = true

  If S305_PHASE6 = done AND S305_COMMITTED = true → S30.5 COMPLETE
  If S305_PHASE2 = done AND S305_PHASE6 != done → S30.5 IN PROGRESS (Phase 3-6)
  If S305_PHASE1 = done AND S305_PHASE2 != done → S30.5 IN PROGRESS (Phase 2)
  If S305_PHASE1 != done → S30.5 NOT STARTED

STEP 4 — Check sprint completion (S31-S40):

  S31: EXISTS(services/backend/app/services/onboarding/minimal_profile_service.py)
       AND EXISTS(services/backend/tests/test_minimal_profile.py)
       AND EXISTS(apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart)

  S32: EXISTS(services/backend/app/services/arbitrage/rente_vs_capital.py)
       AND EXISTS(services/backend/tests/test_rente_vs_capital.py)

  S33: EXISTS(services/backend/app/services/arbitrage/calendrier_retraits.py)
       AND EXISTS(services/backend/app/services/snapshots/snapshot_service.py)

  S34: EXISTS(services/backend/app/services/coach/compliance_guard.py)
       AND EXISTS(services/backend/tests/test_compliance_guard.py)

  S35: EXISTS(services/backend/app/services/coach/coach_narrative_service.py)
       AND EXISTS(apps/mobile/lib/services/coach/fallback_templates.dart)

  S36: EXISTS(apps/mobile/lib/services/notification_scheduler_service.dart)
       AND EXISTS(apps/mobile/lib/services/milestone_detection_service.dart)

  S37: EXISTS(apps/mobile/lib/services/scenario_narrator_service.dart)
       AND EXISTS(apps/mobile/lib/services/annual_refresh_service.dart)

  S38: EXISTS(apps/mobile/lib/services/financial_core/fri_calculator.dart)
       AND EXISTS(services/backend/app/services/fri/fri_service.py)

  S39: EXISTS(apps/mobile/lib/screens/fri/fri_dashboard_card.dart)

  S40: EXISTS(apps/mobile/lib/services/consent_manager.dart)
       AND EXISTS(apps/mobile/lib/screens/settings/consent_dashboard_screen.dart)

  S41: EXISTS(apps/mobile/lib/services/guided_precision_service.dart)
       AND EXISTS(apps/mobile/lib/widgets/field_help_tooltip.dart)

  S42: EXISTS(apps/mobile/lib/services/document_parser/document_scanner_service.dart)
       AND EXISTS(apps/mobile/lib/services/document_parser/lpp_certificate_parser.dart)

  S43: EXISTS(apps/mobile/lib/screens/document_scan/extraction_review_screen.dart)
       AND EXISTS(services/backend/tests/test_lpp_parser.py)

  S44: EXISTS(apps/mobile/lib/services/document_parser/tax_declaration_parser.dart)
       AND EXISTS(services/backend/tests/test_tax_parser.py)

  S45: EXISTS(apps/mobile/lib/services/document_parser/avs_extract_parser.dart)
       AND EXISTS(apps/mobile/lib/screens/document_scan/avs_guide_screen.dart)

  S46: EXISTS(apps/mobile/lib/services/enhanced_confidence_scorer.dart)
       AND EXISTS(services/backend/app/services/confidence/enhanced_confidence_service.py)

STEP 5 — Determine RESUME POINT:

  If PATCH_APPLIED = false         → RESUME = "PATCH"
  If S30.5 NOT STARTED             → RESUME = "S30.5_START"
  If S30.5 IN PROGRESS             → RESUME = "S30.5_RESUME"
  If S30.5 COMPLETE AND !S31_DONE  → RESUME = "S31"
  If S31_DONE AND !S32_DONE        → RESUME = "S32"
  ... (first incomplete sprint in S31-S40)
  If S40_DONE AND !S41_DONE        → RESUME = "S41"
  If S41_DONE AND !S42_DONE        → RESUME = "S42"
  If S42_DONE AND !S43_DONE        → RESUME = "S43"
  If S43_DONE AND !S44_DONE        → RESUME = "S44"
  If S44_DONE AND !S45_DONE        → RESUME = "S45"
  If S45_DONE AND !S46_DONE        → RESUME = "S46"
  If S46_DONE                      → RESUME = "ALL_DONE"

STEP 6 — Announce and jump:

  ANNOUNCE: "═══ ORCHESTRATOR — RESUME POINT: {RESUME} ═══"
  Jump to that section below.
```

---

## BASELINE CHECK (run before every sprint)

```
cd services/backend && pytest -q 2>&1 | tail -5
cd apps/mobile && flutter analyze 2>&1 | tail -5

If flutter errors > 0 → fix (max 3 tries) → if still failing, ask user
If pytest fails → identify what's broken → if pre-existing, note and continue
```

---

## SECTION: PATCH

Read docs/MINT_V2_INTEGRATION_PATCH.md. Apply each change to target files:
- rules.md (§0, §3, §4)
- AGENTS.md (sprint tracker, spawn prompts, hierarchy)
- AGENT_SYSTEM_PROMPT.md (§2, §4)
- LEGAL_RELEASE_CHECK.md (add §6, §7, §8)
- DefinitionOfDone.md (add Coach Vivant DoD)
- TEST_ROADMAP.md (add 5 personas)

```
git add rules.md AGENTS.md AGENT_SYSTEM_PROMPT.md LEGAL_RELEASE_CHECK.md DefinitionOfDone.md TEST_ROADMAP.md
git commit -m "docs: apply Coach Vivant integration patch"
```
→ Jump to S30.5

---

## SECTION: S30.5_START

Read .claude/AGENT_FINANCIAL_CORE_UNIFICATION.md + .claude/CLAUDE.md

Phase 1: Run all grep scans → produce docs/reports/FINANCIAL_CORE_AUDIT.md
Phase 2: From audit → produce docs/reports/FINANCIAL_CORE_CLEANUP_PLAN.md
→ Continue to S30.5_RESUME

---

## SECTION: S30.5_RESUME

Read cleanup plan. Check what's already done (git log + re-run greps).

Phase 3: For each REMAINING duplicate — one change at a time, test before/after.
Phase 4: Gap analysis — add missing methods to financial_core.
Phase 5: Parity check — 10 profiles, backend vs Flutter, ±1 CHF tolerance.
Phase 6: Produce docs/reports/FINANCIAL_CORE_COMPLETION.md

```
git add -A
git commit -m "chore(S30.5): financial core unification — {N} duplicates removed"
```
→ Jump to S31

---

## SECTION: S31

ANNOUNCE: "═══ S31 — ONBOARDING REDESIGN ═══"
BASELINE CHECK

Specs: docs/ONBOARDING_ARBITRAGE_ENGINE.md § II + .claude/AGENT_COACH_VIVANT_MASTER_PROMPT.md § S31

Backend: minimal_profile_service.py, chiffre_choc_selector.py, onboarding_models.py, endpoint, 35+ tests
Flutter: onboarding_minimal_screen, chiffre_choc_screen, progressive_enrichment_screen

Rules: use financial_core/, one chiffre choc only, no banned terms, confidence score on every output

Test → Commit → Jump to S32

---

## SECTION: S32

ANNOUNCE: "═══ S32 — ARBITRAGE PHASE 1 ═══"
BASELINE CHECK

Specs: docs/ONBOARDING_ARBITRAGE_ENGINE.md § III (B+D) + MASTER_PROMPT § S32

Backend: arbitrage_engine, rente_vs_capital (3 options always), allocation_annuelle (4 options), 30+ tests
Flutter: screens + trajectory_chart + hypothesis_editor + breakeven_indicator

Rules: never rank, hypotheses visible, sensitivity shown, conditional language

Test → Commit → Jump to S33

---

## SECTION: S33

ANNOUNCE: "═══ S33 — ARBITRAGE PHASE 2 + SNAPSHOTS ═══"
BASELINE CHECK

Specs: ONBOARDING_ARBITRAGE_ENGINE § III (A,C,E) + VI + MASTER_PROMPT § S33

Backend: location_vs_propriete, rachat_vs_marche, calendrier_retraits (45+ tests) + snapshot_service (10+ tests)
Flutter: corresponding screens + snapshot_service.dart

Rules: calendrier uses progressive tax brackets, snapshots need consent

Test → Commit → Jump to S34

---

## SECTION: S34

ANNOUNCE: "═══ S34 — COMPLIANCE GUARD (BLOCKER) ═══"
⚠️ DO NOT SPLIT. DO NOT SPAWN AGENTS. Execute everything yourself.
BASELINE CHECK

Specs: CLAUDE.md (banned terms) + LEGAL_RELEASE_CHECK + COACH_VIVANT_ROADMAP § S34 + MASTER_PROMPT § S34

Backend: compliance_guard.py (5 layers), hallucination_detector.py, prompt_registry.py, 40+ tests (25 adversarial)
Flutter: mirror all 4 files

Adversarial tests must catch: "meilleur", "sans risque", "tu devrais", prescriptive patterns, wrong numbers, empty, English, too long. Must pass: compliant conditional text.

Test → Commit → Jump to S35

---

## SECTION: S35

ANNOUNCE: "═══ S35 — COACH NARRATIVE ═══"
PREREQ: verify compliance_guard.py exists. If not → STOP.
BASELINE CHECK

Specs: COACH_VIVANT_ROADMAP § S35 + MASTER_PROMPT § S35

Backend: coach_narrative_service (4 independent methods), coach_context_builder, fallback_templates, endpoint, tests
Flutter: same + coach_cache_service (event-based invalidation) + 3 dashboard cards

Rules: 4 independent calls, CoachContext never has raw amounts, fallback templates are first-class

Test → Commit → Jump to S36

---

## SECTION: S36

ANNOUNCE: "═══ S36 — NOTIFICATIONS + MILESTONES ═══"
BASELINE CHECK

Specs: COACH_VIVANT_ROADMAP § S36 + MASTER_PROMPT § S36

Flutter-heavy: notification_scheduler, milestone_detection, celebration_sheet
Add deps: flutter_local_notifications, confetti

Rules: every notification = personal number + time + deeplink. Never social comparison.

Test → Commit → Jump to S37

---

## SECTION: S37

ANNOUNCE: "═══ S37 — SCENARIOS + REFRESH ═══"
BASELINE CHECK

Specs: COACH_VIVANT_ROADMAP § S37 + MASTER_PROMPT § S37

scenario_narrator_service, annual_refresh_service + screens
Scenarios: max 150 words, ComplianceGuard verifies numbers ±5%
Refresh: trigger > 11 months, 7 pre-filled questions

Test → Commit → Jump to S38

---

## SECTION: S38

ANNOUNCE: "═══ S38 — FRI SHADOW ═══"
BASELINE CHECK

Specs: ONBOARDING_ARBITRAGE_ENGINE § V + MASTER_PROMPT § S38

fri_calculator.dart + fri_service.py + 20+ tests
L=sqrt, R=pow1.5, F conditional on marginal>25%, S penalty-based
Logged in snapshots, NOT displayed. Test 8 archetypes × 3 ages.

Test → Commit → Jump to S39

---

## SECTION: S39

ANNOUNCE: "═══ S39 — FRI BETA ═══"
BASELINE CHECK

Specs: ONBOARDING_ARBITRAGE_ENGINE § V + MASTER_PROMPT § S39

Flutter: fri_dashboard_card, fri_history_chart, fri_breakdown_bars, fri_action_suggestion
Only if confidence >= 50%. Always breakdown. Never "faible"/"mauvais". Never compare users.

Test → Commit → Jump to S40

---

## SECTION: S40

ANNOUNCE: "═══ S40 — REENGAGEMENT + CONSENT ═══"
BASELINE CHECK

Specs: COACH_VIVANT_ROADMAP § S40 + MASTER_PROMPT § S40

reengagement_engine, consent_manager, consent_dashboard_screen
3 independent toggles (BYOK, snapshots, notifications), each revocable
Reengagement: always personal number + deadline, never generic

Test → Commit → Jump to S41

---

## SECTION: ALL_DONE_PHASE1

```
═══════════════════════════════════════════════
═══ COACH VIVANT PHASE 1 — COMPLETE ═══
═══ Starting PHASE 2 — DATA ACQUISITION ═══
═══════════════════════════════════════════════
```

Run: pytest -q + flutter analyze + flutter test
Report: total sprints S30.5-S40, total tests, all green.

→ Jump to S41

---

## ═══════════════════════════════════════════════════════
## PHASE 2 — DATA ACQUISITION (S41-S46)
## Spec: docs/DATA_ACQUISITION_STRATEGY.md
## Goal: evolve from "user guesses" to "verified financial state"
## ═══════════════════════════════════════════════════════

---

## SECTION: S41

```
ANNOUNCE: "═══ S41 — GUIDED PRECISION ENTRY ═══"
```

BASELINE CHECK

Read specs:
  - docs/DATA_ACQUISITION_STRATEGY.md § Channel 2 (Guided Precision Entry)
  - .claude/CLAUDE.md

This sprint has NO new infrastructure. It improves existing input flows.

IMPLEMENT BACKEND:

Create:
```
services/backend/app/services/validation/__init__.py
services/backend/app/services/validation/cross_validator.py
services/backend/app/services/validation/smart_defaults.py
services/backend/app/services/validation/validation_models.py
services/backend/tests/test_cross_validator.py                (min 20 tests)
services/backend/tests/test_smart_defaults.py                 (min 15 tests)
```

**cross_validator.py** — Consistency checks between related fields:

```python
class CrossValidator:
    """Detects inconsistencies in user-entered financial data."""

    def validate_lpp_vs_age_salary(self, lpp_total, age, salary) -> ValidationResult:
        """Flag if LPP seems too low or too high for age/salary combo."""
        expected_min = self._estimate_lpp_min(age, salary)
        expected_max = self._estimate_lpp_max(age, salary)
        if lpp_total < expected_min * 0.5:
            return ValidationResult(
                is_suspicious=True,
                message="Ce montant semble bas pour ton âge et salaire. "
                        "As-tu récemment changé d'emploi ou retiré un EPL ?",
                severity="warning"
            )
        # ... similar for too high

    def validate_salary_gross_vs_net(self, gross, net, canton, age) -> ValidationResult:
        """Flag if gross/net ratio is unusual."""

    def validate_3a_vs_age(self, pillar_3a, age) -> ValidationResult:
        """Flag if 3a exists before eligible age."""

    def validate_lpp_oblig_vs_total(self, oblig, total) -> ValidationResult:
        """Flag if obligatoire > total (impossible)."""

    def validate_mortgage_vs_income(self, mortgage_payment, gross_salary) -> ValidationResult:
        """Flag if mortgage stress > 38%."""
```

MUST use financial_core/ for all estimations (expected LPP range, net salary ratio, etc.)

**smart_defaults.py** — Archetype-aware defaults:

```python
class SmartDefaults:
    """Provides best-possible estimates when user doesn't know exact values."""

    def estimate_lpp(self, age, salary, archetype) -> SmartDefault:
        """
        Returns estimated LPP with confidence.
        - swiss_native: full career from 25
        - expat_eu: from arrival_age
        - independent_no_lpp: 0
        - etc.
        """
        # Uses LppCalculator from financial_core
        return SmartDefault(
            value=estimated,
            confidence=0.25 if archetype == "expat_eu" else 0.50,
            explanation="Estimation basée sur ton profil {archetype}, âge {age}, salaire {salary}",
            how_to_verify="Ce chiffre se trouve sur ton certificat de prévoyance, "
                          "ligne 'Avoir de vieillesse' ou 'Altersguthaben'."
        )
```

Tests:
- All 8 archetypes produce valid defaults
- Cross-validator catches: LPP 0 at age 50 with salary 100k → warning
- Cross-validator catches: gross 80k / net 78k → suspicious ratio
- Cross-validator passes: consistent profile → no warnings
- Smart defaults differ by archetype (expat lower confidence than swiss_native)

IMPLEMENT FLUTTER:

Create:
```
apps/mobile/lib/services/guided_precision_service.dart
apps/mobile/lib/services/cross_validator_service.dart
apps/mobile/lib/services/smart_defaults_service.dart
apps/mobile/lib/widgets/field_help_tooltip.dart
apps/mobile/lib/widgets/validation_alert_card.dart
apps/mobile/lib/widgets/precision_prompt_card.dart
```

**field_help_tooltip.dart** — Contextual help on every financial field:
```dart
/// Shows "Où trouver ce chiffre" + document name + field name
/// Also shows: "Si tu ne l'as pas, on estime à ~CHF {estimate}"
class FieldHelpTooltip extends StatelessWidget {
  final String fieldLabel;
  final String documentName;     // "Certificat de prévoyance"
  final String fieldOnDocument;  // "Ligne 'Avoir de vieillesse'"
  final String? germanLabel;     // "Altersguthaben" for bilingual
  final double? fallbackEstimate;
  // ...
}
```

**validation_alert_card.dart** — Shows cross-validation warnings inline:
```dart
/// "Ce montant semble bas pour ton âge et salaire.
///  As-tu récemment changé d'emploi ou retiré un EPL ?"
class ValidationAlertCard extends StatelessWidget {
  final ValidationResult validation;
  // Shows warning or info card, dismissible
}
```

**precision_prompt_card.dart** — Prompts for precision AT POINT OF NEED:
```dart
/// Shown before arbitrage when key data is estimated.
/// "Pour comparer rente et capital précisément,
///  on a besoin de la part obligatoire de ta LPP.
///  📄 Scanner mon certificat | ✏️ Entrer manuellement | ⏭️ Continuer avec estimation"
class PrecisionPromptCard extends StatelessWidget {
  final String fieldNeeded;
  final double currentEstimate;
  final double confidenceImpact;  // "+25 points de confiance"
  // ...
}
```

Integrate into existing onboarding and profile screens:
- Add FieldHelpTooltip to every financial input field
- Add ValidationAlertCard after field entry
- Add PrecisionPromptCard before arbitrage modules (if key field is estimated)

Run: flutter analyze && flutter test → 0 errors
Run: pytest -q → all pass

COMMIT:
```
git add [sprint files]
git commit -m "feat(S41): guided precision entry — contextual help + cross-validation + smart defaults

  - FieldHelpTooltip on every financial input
  - CrossValidator catches inconsistent entries
  - SmartDefaults by archetype (8 archetypes)
  - PrecisionPromptCard at point of need
  - Backend: {N} tests"
```

ANNOUNCE: "═══ S41 — DONE ═══"
→ Jump to S42

---

## SECTION: S42

```
ANNOUNCE: "═══ S42 — LPP CERTIFICATE PARSING (OCR INFRA) ═══"
```

BASELINE CHECK

Read specs:
  - docs/DATA_ACQUISITION_STRATEGY.md § Channel 1, Document A
  - .claude/CLAUDE.md

This sprint builds the OCR infrastructure + LPP certificate parser.

IMPLEMENT FLUTTER (Flutter-heavy — OCR is on-device):

Create:
```
apps/mobile/lib/services/document_parser/document_scanner_service.dart
apps/mobile/lib/services/document_parser/lpp_certificate_parser.dart
apps/mobile/lib/services/document_parser/extraction_confidence_scorer.dart
apps/mobile/lib/services/document_parser/document_models.dart
apps/mobile/lib/screens/document_scan/document_scan_screen.dart
apps/mobile/lib/screens/document_scan/extraction_review_screen.dart
apps/mobile/lib/screens/document_scan/document_impact_screen.dart
```

Add dependencies (pubspec.yaml):
```yaml
google_mlkit_text_recognition: ^latest   # On-device OCR
image_picker: ^latest                     # Camera + gallery
```

**document_scanner_service.dart**:
```dart
class DocumentScannerService {
  /// Orchestrates: camera → OCR → parse → review → inject
  ///
  /// Privacy: image NEVER stored. Deleted after extraction.
  /// On-device OCR by default (google_mlkit_text_recognition).
  /// BYOK LLM vision as optional upgrade (user's API key).

  Future<OcrResult> scanDocument(DocumentType type);
  Future<ExtractedFields> parseOcrResult(OcrResult raw, DocumentType type);
}

enum DocumentType {
  lppCertificate,
  taxDeclaration,
  avsExtract,
  threeAAttestation,
  mortgageAttestation,
}
```

**lpp_certificate_parser.dart**:
```dart
class LppCertificateParser {
  /// Extracts structured fields from OCR text of a LPP certificate.
  ///
  /// Target fields:
  ///   - avoir_total (total retirement savings)
  ///   - part_obligatoire (mandatory portion — CRITICAL for rente vs capital)
  ///   - part_surobligatoire (supplementary portion)
  ///   - taux_conversion_oblig (usually 6.8%)
  ///   - taux_conversion_suroblig (often 4.5-5.5%)
  ///   - lacune_rachat (buyback potential)
  ///   - rente_projetee (projected annual pension)
  ///   - prestation_invalidite (disability coverage)
  ///   - prestation_deces (death coverage)
  ///   - cotisation_employe (monthly employee contribution)
  ///   - salaire_assure (insured salary)

  Future<LppCertificateData> parse(String ocrText) {
    // Strategy:
    // 1. Regex patterns for common field labels (FR + DE)
    // 2. Amount extraction near labels
    // 3. Confidence score per field
    // 4. If BYOK available: send OCR text to LLM for structured extraction
  }
}

class LppCertificateData {
  final Map<String, ExtractedField> fields;
  final double overallConfidence;   // 0-1
  final String? caisseDetected;     // Pension fund name if identified
}

class ExtractedField {
  final String label;
  final double? value;
  final double confidence;          // 0-1 per field
  final String rawText;             // Original OCR text that was parsed
  final bool needsUserConfirmation; // true if confidence < 0.8
}
```

**extraction_review_screen.dart**:
```dart
/// Shows extracted values. User confirms or corrects each.
///
/// "Voici ce qu'on a lu. Vérifie et corrige si nécessaire."
///   Avoir total: CHF 143'287 ✓ [edit]
///   Part obligatoire: CHF 98'400 ✓ [edit]
///   Taux conversion: 6.8% / 5.2% ✓ [edit]
///   Lacune rachat: CHF 45'000 ✓ [edit]
///
/// Low-confidence fields highlighted in amber.
/// User can tap [edit] to correct any value.
/// "Confirmer" button injects values into profile.
```

**document_impact_screen.dart**:
```dart
/// After confirmation, shows the impact:
/// "Ton profil est maintenant plus précis."
/// "Confiance : 78% (+27 points)"
/// "Ton chiffre choc a été recalculé avec tes vrais chiffres."
///
/// Shows before/after comparison of key projections.
```

**Privacy rules (hardcoded, non-negotiable):**
- Original image deleted immediately after OCR (never stored on device or server)
- OCR runs on-device by default (google_mlkit_text_recognition)
- If BYOK LLM used for parsing: explicit consent, user's own API key
- Extracted values stored locally, encrypted at rest
- User can delete all extracted data at any time
- NO extracted data ever sent to MINT backend (stays on device)

IMPLEMENT BACKEND:

Create:
```
services/backend/app/services/document_parser/__init__.py
services/backend/app/services/document_parser/lpp_parser.py
services/backend/app/services/document_parser/parser_models.py
services/backend/tests/test_lpp_parser.py                    (min 15 tests)
```

Backend parser: handles BYOK LLM-assisted extraction when app sends OCR text.
NOT for processing images (that stays on device).

```python
class LppCertificateParserBackend:
    """Server-side LPP certificate parsing via BYOK LLM."""

    FIELD_PATTERNS = {
        "avoir_total": [
            r"avoir\s+de\s+vieillesse\s*:?\s*(?:CHF\s*)?([\d']+)",
            r"altersguthaben\s*:?\s*(?:CHF\s*)?([\d']+)",
            r"total\s+retirement\s+savings\s*:?\s*(?:CHF\s*)?([\d']+)",
        ],
        "part_obligatoire": [
            r"part\s+obligatoire\s*:?\s*(?:CHF\s*)?([\d']+)",
            r"obligatorisch(?:er?\s+teil)?\s*:?\s*(?:CHF\s*)?([\d']+)",
        ],
        # ... patterns for all 11 fields, FR + DE
    }

    def parse_with_regex(self, ocr_text: str) -> dict:
        """Attempt structured extraction via regex patterns."""

    async def parse_with_llm(self, ocr_text: str, llm_client) -> dict:
        """BYOK LLM-assisted extraction for unknown certificate formats."""
```

Tests:
- Mock OCR text from common caisses (Publica, BVK, CPEV format)
- Test regex extraction for each field in FR and DE
- Test confidence scoring (all fields found = high, partial = medium)
- Test that missing fields return None (not hallucinated values)
- Test amount parsing: "CHF 143'287", "143287", "143'287.50"

Run: all tests pass

COMMIT:
```
git add [sprint files]
git commit -m "feat(S42): LPP certificate OCR infrastructure

  - On-device OCR (google_mlkit_text_recognition)
  - LPP certificate parser (11 fields, FR+DE patterns)
  - Extraction review screen (user confirms values)
  - Privacy: image never stored, OCR on-device
  - Backend: regex + BYOK LLM parsing
  - {N} tests"
```

ANNOUNCE: "═══ S42 — DONE ═══"
→ Jump to S43

---

## SECTION: S43

```
ANNOUNCE: "═══ S43 — LPP PARSING INTEGRATION + PROFILE INJECTION ═══"
```

BASELINE CHECK

Read specs:
  - docs/DATA_ACQUISITION_STRATEGY.md § Channel 1 (Doc A continued) + § Data Acquisition Funnel
  - .claude/CLAUDE.md

This sprint connects the OCR parser to the profile and confidence system.

IMPLEMENT:

Create:
```
apps/mobile/lib/services/document_parser/profile_injector_service.dart
apps/mobile/lib/services/document_parser/source_tracker.dart
apps/mobile/lib/models/profile_field.dart
services/backend/tests/test_profile_injection.py              (min 10 tests)
```

**profile_field.dart** — Every profile field now tracks its source:
```dart
class ProfileField<T> {
  final T value;
  final DataSource source;
  final DateTime updatedAt;
  final double fieldConfidence;
}

enum DataSource {
  systemEstimate,           // MINT computed default (confidence: 0.25)
  userEstimate,             // "environ 100k" (confidence: 0.50)
  userEntry,                // User typed exact number (confidence: 0.70)
  userEntryCrossValidated,  // Typed + passed consistency check (confidence: 0.75)
  documentScan,             // OCR from certificate (confidence: 0.85)
  documentScanVerified,     // OCR + user confirmed (confidence: 0.95)
  openBanking,              // Live bank feed (confidence: 1.00)
  institutionalApi,         // Direct from caisse (confidence: 1.00)
}
```

**profile_injector_service.dart**:
```dart
class ProfileInjectorService {
  /// Injects extracted document values into user profile.
  /// Updates source tracking per field.
  /// Triggers: snapshot, confidence recalculation, chiffre choc refresh.

  Future<InjectionResult> injectLppCertificate(LppCertificateData data);
  Future<InjectionResult> injectTaxDeclaration(TaxDeclarationData data);
  Future<InjectionResult> injectAvsExtract(AvsExtractData data);
}

class InjectionResult {
  final int fieldsUpdated;
  final double confidenceBefore;
  final double confidenceAfter;
  final double confidenceDelta;
  final List<String> fieldsChanged;  // For UI display
}
```

**source_tracker.dart**:
```dart
class SourceTracker {
  /// Displays source quality to user on profile fields.
  ///
  /// "Avoir LPP: CHF 143'287  📄 Source: certificat (mars 2026)"
  /// "Avoir LPP: CHF ~150'000  ✏️ Source: estimation [📄 Scanner]"

  Widget buildSourceIndicator(ProfileField field);
}
```

Integration points:
- Update existing profile model to use ProfileField<T> instead of raw types
- After document injection → trigger new snapshot
- After document injection → recalculate FRI
- After document injection → refresh chiffre choc
- Add source indicator widgets to profile view screens

Add precision prompts to arbitrage screens:
```dart
// In rente_vs_capital_screen.dart, before showing comparison:
if (profile.lppObligatoire.source == DataSource.systemEstimate) {
  show PrecisionPromptCard(
    message: "Pour comparer rente et capital précisément, "
             "on a besoin de la part obligatoire de ta LPP.",
    actions: ["📄 Scanner mon certificat", "✏️ Entrer manuellement", "⏭️ Continuer avec estimation"],
    confidenceImpact: "+25 points",
  );
}
```

Run: all tests pass

COMMIT:
```
git add [sprint files]
git commit -m "feat(S43): LPP parsing integration + profile source tracking

  - ProfileField<T> with DataSource tracking per field
  - ProfileInjectorService connects OCR → profile → recalculation
  - Source indicators on profile screens
  - Precision prompts before arbitrage when data is estimated
  - {N} tests"
```

ANNOUNCE: "═══ S43 — DONE ═══"
→ Jump to S44

---

## SECTION: S44

```
ANNOUNCE: "═══ S44 — TAX DECLARATION PARSING ═══"
```

BASELINE CHECK

Read specs:
  - docs/DATA_ACQUISITION_STRATEGY.md § Channel 1, Document B

Reuses OCR infra from S42. Adds tax-specific parser.

IMPLEMENT:

Create:
```
apps/mobile/lib/services/document_parser/tax_declaration_parser.dart
services/backend/app/services/document_parser/tax_parser.py
services/backend/tests/test_tax_parser.py                    (min 15 tests)
apps/mobile/lib/screens/document_scan/tax_scan_screen.dart
```

**tax_declaration_parser.dart**:
```dart
class TaxDeclarationParser {
  /// Extracts from avis de taxation / déclaration fiscale:
  ///   - revenu_imposable (actual taxable income)
  ///   - fortune_imposable (taxable wealth)
  ///   - deductions (3a, frais, etc.)
  ///   - impot_cantonal (actual cantonal tax paid)
  ///   - impot_federal (actual federal tax paid)
  ///   - taux_marginal_effectif (CRITICAL — real marginal rate)

  Future<TaxDeclarationData> parse(String ocrText);
}
```

The marginal rate is THE critical output. It drives ALL tax-related arbitrages.
A user who thinks their rate is 25% but it's actually 32% gets wrong results on:
- Rachat LPP (breakeven shifts by years)
- 3a optimization (saving amount off by 28%)
- Allocation annuelle (ranking of options can change)

More standardized than LPP certificates (26 cantonal formats, but structured).
Regex patterns for the 6 main cantonal formats initially (ZH, BE, VD, GE, LU, BS — matching existing tax engine).

After extraction + user confirmation → inject via ProfileInjectorService.
Key impact: `marginalTaxRate` field updated from `systemEstimate` to `documentScanVerified`.

Run: all tests pass

COMMIT:
```
git add [sprint files]
git commit -m "feat(S44): tax declaration parsing — real marginal rate extraction

  - Tax-specific OCR parser (6 cantonal formats)
  - Marginal rate extraction (critical for arbitrage accuracy)
  - Reuses S42 OCR infrastructure
  - {N} tests"
```

ANNOUNCE: "═══ S44 — DONE ═══"
→ Jump to S45

---

## SECTION: S45

```
ANNOUNCE: "═══ S45 — AVS EXTRACT GUIDANCE + PARSING ═══"
```

BASELINE CHECK

Read specs:
  - docs/DATA_ACQUISITION_STRATEGY.md § Channel 1, Document C

IMPLEMENT:

Create:
```
apps/mobile/lib/services/document_parser/avs_extract_parser.dart
apps/mobile/lib/screens/document_scan/avs_guide_screen.dart
services/backend/app/services/document_parser/avs_parser.py
services/backend/tests/test_avs_parser.py                    (min 10 tests)
```

**avs_guide_screen.dart** — Guides user to request their CI extract:
```dart
/// Step-by-step guide:
/// 1. "Va sur www.ahv-iv.ch"
/// 2. "Connecte-toi avec ton numéro AVS"
/// 3. "Demande ton extrait de compte individuel (CI)"
/// 4. "Tu le recevras par courrier en 10-15 jours"
/// 5. "Quand tu l'as, reviens ici pour le scanner"
///
/// Alternative: "Tu l'as déjà ? 📄 Scanner maintenant"
///
/// Deep link: "https://www.ahv-iv.ch/fr/Mémentos-Formulaires/Formulaires/Extraits-de-comptes"
```

**avs_extract_parser.dart**:
```dart
class AvsExtractParser {
  /// Extracts from extrait de compte individuel (CI):
  ///   - annees_cotisation (contribution years — exact count)
  ///   - ramd (revenu annuel moyen déterminant — CRITICAL for AVS rente)
  ///   - lacunes (gap years — list of missing years)
  ///   - bonifications_educatives (education credits)

  Future<AvsExtractData> parse(String ocrText);
}
```

The RAMD is THE critical output. It determines the exact AVS rente.
An inaccurate RAMD estimate can be off by CHF 200-500/month.

After extraction → inject → AVS projection recalculated with real RAMD.
ConfidenceScore impact: +20-25 points.

Run: all tests pass

COMMIT:
```
git add [sprint files]
git commit -m "feat(S45): AVS extract guidance + parsing

  - In-app guide to request CI extract from ahv-iv.ch
  - AVS extract parser (contribution years, RAMD, gaps)
  - RAMD extraction critical for AVS projection accuracy
  - {N} tests"
```

ANNOUNCE: "═══ S45 — DONE ═══"
→ Jump to S46

---

## SECTION: S46

```
ANNOUNCE: "═══ S46 — ENHANCED CONFIDENCE SCORING ═══"
```

BASELINE CHECK

Read specs:
  - docs/DATA_ACQUISITION_STRATEGY.md § Confidence Scoring Evolution

This sprint migrates ConfidenceScorer from completeness-only to 3-axis scoring.

IMPLEMENT BACKEND:

Create:
```
services/backend/app/services/confidence/__init__.py
services/backend/app/services/confidence/enhanced_confidence_service.py
services/backend/app/services/confidence/confidence_models.py
services/backend/tests/test_enhanced_confidence.py           (min 20 tests)
```

**enhanced_confidence_service.py**:
```python
class EnhancedConfidenceService:
    """3-axis confidence scoring: completeness × accuracy × freshness."""

    def score(self, profile) -> ConfidenceBreakdown:
        return ConfidenceBreakdown(
            completeness=self._score_completeness(profile),
            accuracy=self._score_accuracy(profile),
            freshness=self._score_freshness(profile),
            overall=self._weighted_overall(completeness, accuracy, freshness),
            top_enrichments=self._rank_enrichments(profile),
        )

    def _score_accuracy(self, profile) -> float:
        """Score based on source quality of each field."""
        weights = {
            DataSource.OPEN_BANKING: 1.00,
            DataSource.DOCUMENT_SCAN_VERIFIED: 0.95,
            DataSource.DOCUMENT_SCAN: 0.85,
            DataSource.USER_ENTRY_CROSS_VALIDATED: 0.75,
            DataSource.USER_ENTRY: 0.50,
            DataSource.SYSTEM_ESTIMATE: 0.25,
        }
        # Weighted average across all fields

    def _score_freshness(self, profile) -> float:
        """Score based on data age."""
        # < 1 month: 1.0, 1-3 months: 0.9, 3-6: 0.75, 6-12: 0.50, >12: 0.25

    def _rank_enrichments(self, profile) -> list:
        """What action would improve confidence the most?"""
        # Returns ordered list:
        # "Scanner ton certificat LPP (+25 points)"
        # "Scanner ta déclaration fiscale (+18 points)"
        # "Connecter ton compte bancaire (+15 points)"
```

**Feature gating based on confidence:**
```python
CONFIDENCE_GATES = {
    "basic_chiffre_choc": 0,        # Always available
    "standard_projections": 30,      # 3 scenarios
    "arbitrage_comparisons": 50,     # With uncertainty bands below 70
    "fri_display": 50,
    "precise_arbitrage": 70,         # Without uncertainty bands
    "longitudinal_tracking": 70,     # Meaningful only with reliable data
    "full_precision": 85,
}
```

IMPLEMENT FLUTTER:

Create:
```
apps/mobile/lib/services/enhanced_confidence_scorer.dart
apps/mobile/lib/widgets/confidence_breakdown_card.dart
apps/mobile/lib/widgets/enrichment_suggestion_card.dart
```

**confidence_breakdown_card.dart**:
```dart
/// Shows 3 axes visually:
///   Complétude: ████████░░ 78%
///   Fiabilité:  ██████░░░░ 62%
///   Fraîcheur:  █████████░ 91%
///   ─────────────────────
///   Confiance:  ███████░░░ 73%
///
/// Below: "Pour améliorer : 📄 Scanner ton certificat LPP (+25 points)"
```

**enrichment_suggestion_card.dart**:
```dart
/// Context-aware prompt shown at right moment:
///
/// On arbitrage screen (if LPP estimated):
///   "Avec ton vrai certificat LPP, cette comparaison serait fiable à 95%."
///   [📄 Scanner] [⏭️ Continuer avec estimation (±15% de marge)]
///
/// On FRI screen (if tax estimated):
///   "Ton taux marginal est estimé. Scanner ta taxation pour un score plus précis."
///   [📄 Scanner] [⏭️ OK]
///
/// After chiffre choc (general):
///   "Ce résultat est basé sur {N} estimations. Précision actuelle : {confidence}%."
///   [📄 Améliorer la précision]
```

Integration: replace existing ConfidenceScorer calls with EnhancedConfidenceService.
Update arbitrage screens: show uncertainty bands when confidence < 70%.
Update FRI: show "basé sur estimations" when accuracy score < 0.70.

Run: all tests pass

COMMIT:
```
git add [sprint files]
git commit -m "feat(S46): enhanced confidence scoring — 3-axis (completeness × accuracy × freshness)

  - Source quality tracking (document > manual > estimate)
  - Freshness decay over time
  - Feature gating by confidence level
  - Enrichment suggestions ranked by impact
  - Uncertainty bands on arbitrage when confidence < 70%
  - {N} tests"
```

ANNOUNCE: "═══ S46 — DONE ═══"
→ Jump to ALL_DONE

---

## SECTION: ALL_DONE

```
═══════════════════════════════════════════════════════════
═══ MINT COACH VIVANT — ALL PHASES COMPLETE ═══
═══════════════════════════════════════════════════════════
  Phase 1 (S30.5-S40): Coach Layer + Arbitrage + FRI ✅
  Phase 2 (S41-S46): Data Acquisition + Precision ✅
═══════════════════════════════════════════════════════════
```

Run final verification:
  cd services/backend && pytest -q
  cd apps/mobile && flutter analyze && flutter test

Report:
```
  Total sprints: {count} (S30.5 through S46)
  Backend tests: {total}
  Flutter errors: 0
  New files created: {count}

  Phase 1:
    S30.5 ✅ Financial Core Unification
    S31   ✅ Onboarding Redesign
    S32   ✅ Arbitrage Phase 1
    S33   ✅ Arbitrage Phase 2 + Snapshots
    S34   ✅ Compliance Guard
    S35   ✅ Coach Narrative Service
    S36   ✅ Notifications + Milestones
    S37   ✅ Scenarios + Annual Refresh
    S38   ✅ FRI Shadow Mode
    S39   ✅ FRI Beta + Charts
    S40   ✅ Reengagement + Consent

  Phase 2:
    S41   ✅ Guided Precision Entry
    S42   ✅ LPP Certificate OCR Infra
    S43   ✅ LPP Parsing Integration
    S44   ✅ Tax Declaration Parsing
    S45   ✅ AVS Extract Guidance
    S46   ✅ Enhanced Confidence Scoring

  Remaining for V3:
    - Institutional API partnerships (caisse de pension direct feeds)
    - Open Banking extension for precision data
    - Monte Carlo simulations
    - Multi-device sync
    - AI-generated PDF reports
```

---

## ERROR HANDLING

- Test fails → fix (3 tries) → if still fails: revert, log in AGENTS_LOG.md, skip, continue
- Baseline breaks → STOP, identify regression, revert sprint change, ask user
- Context window low → commit what passes, add "PARTIAL" in commit message, next session auto-resumes
- File already exists → read first, extend, don't overwrite
- New dependency needed → add to pubspec/pyproject, note in commit

---

## AGENT TEAMS (if available)

Parallel sprints (spawn python-agent + dart-agent): S31-S33, S35-S37, S39-S46
Single agent (too critical to split): S30.5, S34, S38

Spawn prompts — python-agent:
```
Tu es le backend engineer MINT. Lis .claude/CLAUDE.md, le spec doc du sprint,
et .claude/skills/mint-backend-dev/SKILL.md. MUST use financial_core/. pytest -q doit passer.
```

Spawn prompts — dart-agent:
```
Tu es le Flutter engineer MINT. Lis .claude/CLAUDE.md, le spec doc du sprint,
et .claude/skills/mint-flutter-dev/SKILL.md. MUST import financial_core.dart. flutter analyze = 0.
```
