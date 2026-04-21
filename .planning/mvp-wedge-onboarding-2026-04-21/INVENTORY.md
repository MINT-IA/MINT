# Inventaire — Ce qui existe, ce qu'il faut créer

**Scan** : 2026-04-21 | **Scope** : wedge onboarding pédagogique (cold → verdict retraite 90s)

---

## 1. Calculateurs financial_core

### Existe

- **`AvsCalculator.computeMonthlyRente()`** — `/avs_calculator.dart:29-118` ✅ test golden
  - Input: age, retirementAge, lacunes, arrivalAge, grossAnnualSalary, gender, isFemale, isDivorced, childRaisingYears
  - Output: double (rente mensuel CHF)
  - Gère: anticipation 63+, deferral bonus 65→70, AVS21 reference age, divorce split

- **`AvsCalculator.computeCouple()`** — line 156-169 | cap 150% married (LAVS art.35)

- **`AvsCalculator.computeBridgePension()`** — line 182-200 | gap estimation retirement→AVS ref age

- **`LppCalculator.projectToRetirement()`** — `/lpp_calculator.dart:67-123` ✅ test golden
  - Input: currentBalance, currentAge, retirementAge, grossAnnualSalary, caisseReturn, conversionRate, bonificationRateOverride, salaireAssureOverride
  - Output: rente annuelle CHF
  - Gère: seuil entree 22'680, bonifications par age, taux ajusté early retirement, rachat support

- **`LppCalculator.blendedMonthly()`** — line 160-198 | mix rente/capital + tax LIFD art.38 cantonal

- **`LppCalculator.computeSurvivorPension()`** — line 240-296 | conjoint 60% + orphans 20%/enfant, cap 100%

- **`LppCalculator.computeEplImpact()`** — line 325-390 | model EPL retrait impact interest composé

- **`LppCalculator.compareRetirementSequencing()`** — line 409-470 | optimize couple tax: same-year vs staggered

### À créer

- **`RetirementProjection.compute3aImpact()`** — aggregate AVS+LPP+3a → taux remplacement global + verdict
- **`RetirementCalculator`** — orchestrateur single-call: all 3 pillars → "on peut" / "attention" / "critique"

---

## 2. Scanner LPP + document_parser

### Existe

- **`DocumentScanScreen`** — `/document_scan/document_scan_screen.dart:55` | accept `initialType: DocumentType.lppCertificate`
  - Flow: Camera/Gallery → OCR → Parser → Review → Confirmation
  - Parsers: LPP ✅, Tax ✅, AVS ✅, Salary ✅
  - Privacy: images not persisted, only confirmed values saved

- **`LppCertificateParser`** — `/document_parser/lpp_certificate_parser.dart` | extract balance, rate, bonification
  - Test: `lpp_certificate_parser_test.dart` ✅

- **`DocumentImpactScreen`** + **`ExtractionReviewScreen`** — post-extraction UI

### Problem connue

- **Callback on-complete undocumented** (line 60) — currently returns via GoRouter pop. Wizard needs callback or return value.

### À créer

- **Callback wrapper for wizard** — pass `onConfirm: (LppCertificateData) → void` instead of pop

---

## 3. Voice system + pédagogie vocabulaire

### Existe

- **Glossaires ARB** — `/app_fr.arb` ✅
  - `glossaryLpp`, `glossaryAvs`, `glossary3a`, `glossaryRamd`, `glossaryTauxConversion`, `glossaryRachat`, `glossaryLacune`, `glossaryTauxRemplacement`, `glossaryRente` + 15+ entrées
  - Plus: `jargonXXXTooltip` (2-3 ligne version)

- **`RegionalVoiceService`** — `/voice/regional_voice_service.dart` | région-aware explanations (incomplete)

### À créer

- **`TermDefinitionService`** — lookup (term: "LPP") → short explanation (ARB-backed)

---

## 4. CoachProfile persistence

### Existe

- **`CoachProfileProvider`** — `/coach_profile_provider.dart:38` | load wizard answers → CoachProfile
  - Key methods: `loadFromWizard()`, profile getter, hasProfile/isPartialProfile

- **`CoachProfile` model** — `/models/coach_profile.dart` | age, revenuBrutAnnuel, canton, civilStatus, lppBalance, nombreEnfants
  - Enums: `FinancialArchetype` (swissNative, expatEu, independentWithLpp, etc.)
  - Nested: ConjointProfile, PrevoyanceProfile, PatrimoineProfile

- **`ReportPersistenceService`** — `/report_persistence_service.dart:8` | JSON persistence + encryption
  - Keys: `wizard_answers_v2`, `wizard_completed`, `mini_onboarding_completed`, `selected_onboarding_intent_v1`, `premier_eclairage_snapshot_v1`

### À créer

- **`WizardToProfileMapper`** — { age: 34, salaire: 8000, canton: "VD" } → CoachProfile (archetype deduction, validation)

---

## 5. Routing + shell

### Existe

- **`GoRouter`** — `/app.dart:207` | initialLocation `/`, refreshListenable `_authNotifier`
  - Redirect logic: Scope-based (public / onboarding / authenticated)

- **Routes publiques** — `/`, `/auth/login`, `/auth/register`, `/auth/verify`, `/anonymous/chat`

- **Shell (4-tab)** — line 345-437 | Aujourd'hui, Mon argent, Coach, Explorer
  - Builder: `MintShell(navigationShell)`

### Limitation

- No documented full-screen wizard zone outside shell

### À créer

- **`OnboardingShellRoute`** — variant sans 4 tabs, routes `/onboarding/step1..N`, full-screen safe

---

## 6. Feature flags + compliance

### Existe

- **`FeatureFlags`** — `/feature_flags.dart:10` | enableSlmNarratives, enableDecisionScaffold, enableCouplePlusTier, enableOpenBanking
  - Methods: `applyFromMap()`, `startPeriodicRefresh()` (6h backend sync)

- **ARB lint gates** — `tools/checks/accent_lint_fr.py`, `no_hardcoded_fr.py` (all UI strings must be in ARB)

### À créer

- **`OnboardingFeatureFlag`** — gate complete wizard flow

---

## 7. LandingScreen

### Existe

- **`LandingScreen`** — `/landing_screen.dart:17` | SafeArea, animated reveals (500-3200ms), CTA → `/auth/login` (long-press) or signup
  - NonNegotiable: ❌ no financial_core, ❌ no digits, ❌ no retirement vocab
  - Theme: `MintColors.warmWhite`

---

## 8. Tests integration

### Existe

- **`persona_marc_test.dart`** — `/integration_test/persona_marc_test.dart:11` | wizard flow + screenshots + assertions
  - Pattern: testWidgets + WidgetTester + tester.tap/pumpAndSettle + expect + binding.takeScreenshot

- **Golden tests** — matchesGoldenFile support ✅

### À créer

- **`onboarding_full_flow_test.dart`** — Persona Julien 34 Lausanne: age → canton → salary → lpp_balance → verdict assertion

---

## 9. ADRs (résumé 1 ligne)

1. **ADR-20260111-wizard-progression-clarte.md** — Indice Précision (0-100%) instead of gamification; 3 scenarios prudence/central/stress; Safe Mode blocks investment if debt >30%.
2. **ADR-20260419-autonomous-profile-tiered.md** — 3-level audit (L1 meta, L2 backend, L3 UI); L3 requires simulator + creator-device gate.
3. **ADR-archetype-driven-retirement.md** — Profile archetype determines calculation paths + alert relevance.

---

## DETTES CONNUES

1. DocumentScanScreen callback pattern undocumented (line 60) — returns via pop, wizard needs callback
2. TermDefinitionService missing — glossaire ARB exists, lookup service absent
3. ArchetypeDetectionService missing — enum exists, deduction logic absent
4. OnboardingShellRoute pattern missing — full-screen wizard zone undocumented
5. First launch detection — AuthProvider lacks `isFirstLaunch` flag
6. WizardToProfileMapper missing — transformation logic not centralized

---

## SCORE

- **11 sections scanned**
- **45+ composants catalogués**
- **✅ RÉUTILISABLE : 35 composants** (AVS, LPP, 3a, scan, glossaire, routing, tests)
- **⚠️ À CRÉER : 10 composants** (orchestrateurs, mappeurs, services pédagogie, wizard shell)
