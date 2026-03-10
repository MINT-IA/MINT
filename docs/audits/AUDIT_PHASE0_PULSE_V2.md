# AUDIT V2 — Phase 0 Pulse (S48) — 3 Commits

> **Auditor**: Claude Code Senior Audit Team
> **Date**: 2026-03-10
> **Branch**: `claude/add-mint-repo-link-L2xCb`
> **Scope**: 3 commits, 10 fichiers, 1793 lignes (+), 12 lignes (-)
> **Supersedes**: `AUDIT_PHASE0_PULSE.md` (V1 — single commit only)

---

## COMMITS AUDITES

| # | Hash | Message | Fichiers | +/- |
|---|------|---------|----------|-----|
| 1 | `fce184f` | `docs: add UX V2 Coach Conversationnel spec` | 1 | +313 |
| 2 | `936ed76` | `feat(pulse): implement Phase 0 Pulse dashboard` | 8 | +1263/-12 |
| 3 | `cd38f59` | `feat(pulse): add temporal strip, couple mode, coach narrative` | 1 | +230/-15 |

---

## SUMMARY

| Gate | Verdict | Findings |
|------|---------|----------|
| G1 — Architecture & Design System | **PASS** | 0 CRIT, 0 HIGH |
| G2 — Compliance (LSFin, banned terms) | **PASS** | 0 CRIT, 0 HIGH |
| G3 — Financial Core delegation | **PASS** | 0 CRIT, 0 HIGH |
| G4 — Code quality & edge cases | **WARN** | 0 CRIT, 1 HIGH, 1 MEDIUM |
| G5 — Navigation & integration | **PASS** | 0 CRIT, 0 HIGH |
| G6 — Async safety & state management | **PASS** | 0 CRIT, 0 HIGH, 1 INFO |
| G7 — Test coverage | **WARN** | 0 CRIT, 1 MEDIUM |

**Overall: WARN** — 0 CRIT, 1 HIGH, 2 MEDIUM, 2 LOW, 3 INFO

> Note: V1 findings HIGH-1 (revenuBrutAnnuel), HIGH-2 (tests), MEDIUM-1 (double scorer),
> MEDIUM-2 (threshold 0.7→0.8) ont ete corriges dans le commit `690de87` avant cet audit V2.
> Ce rapport couvre le code APRES corrections + le nouveau commit `cd38f59`.

---

## FILES AUDITED

| # | File | Lines | Commit | Role |
|---|------|-------|--------|------|
| 1 | `screens/pulse/pulse_screen.dart` | 458 | C2+C3 | Dashboard Pulse (StatefulWidget) — temporal strip, couple mode, coach narrative |
| 2 | `services/visibility_score_service.dart` | 451 | C2 | Moteur score visibilite (4 axes, 25/25/25/25) |
| 3 | `widgets/pulse/visibility_score_card.dart` | 200 | C2 | Carte score + barres axes + alerte couple |
| 4 | `widgets/pulse/comprendre_section.dart` | 158 | C2 | 5 liens simulateurs |
| 5 | `widgets/pulse/pulse_action_card.dart` | 153 | C2 | Action enrichment avec impact points |
| 6 | `widgets/pulse/pulse_disclaimer.dart` | 45 | C2 | Micro-disclaimer inline LSFin |
| 7 | `screens/main_navigation_shell.dart` | 271 | C2 | Tab 0 = Pulse (4-tab shell) |
| 8 | `theme/colors.dart` | +1 | C2 | `primaryLight` ajoutee |
| 9 | `docs/UX_V2_COACH_CONVERSATIONNEL.md` | 313 | C1 | Spec UX complete |
| 10 | `services/financial_core/confidence_scorer.dart` | +9 | fix | `scoreWithBlocs()` ajoutee |

---

## G1 — ARCHITECTURE & DESIGN SYSTEM

**Verdict: PASS**

| Check | Status | Detail |
|-------|--------|--------|
| GoRouter navigation | OK | `context.push()` partout, 9 routes verifiees |
| Provider state | OK | `context.watch<CoachProfileProvider>()`, `context.read<ByokProvider>()` |
| Google Fonts — Outfit (headings) | OK | Coherent avec codebase (1080+ usages) |
| Google Fonts — Inter (body) | OK | Utilise partout correctement |
| MintColors palette | OK | Tous les tokens existent dans `colors.dart` |
| SliverAppBar + gradient | OK | `pulse_screen.dart:333-361` |
| Material 3 patterns | OK | `FilledButton`, `InkWell`, `Material`, `ClipRRect` |
| `primaryLight` ajoutee | OK | `Color(0xFF2D2D2F)` — gradient end |
| StatefulWidget lifecycle | OK | `didChangeDependencies` avec profile tracking |
| IndexedStack tabs | OK | 4 tabs, `static const` optimization |
| Responsive | OK | `isCompact` adapte a `height <= 760` |

---

## G2 — COMPLIANCE (LSFin, FINMA, BANNED TERMS)

**Verdict: PASS**

| Check | Status | Detail |
|-------|--------|--------|
| Termes bannis absents | OK | Scan complet 10 fichiers : 0 occurrences |
| Disclaimer present | OK | `PulseDisclaimer`: "Outil educatif. Ne constitue pas un conseil financier personnalise. LSFin art. 3" |
| Disclaimer en empty state | OK | `pulse_screen.dart:449` |
| Disclaimer en loaded state | OK | `pulse_screen.dart:264` |
| CTA educatifs | OK | "Simuler", "Explorer", "Demarrer", "Decouvre" |
| Pas de promesse | OK | Score = "visibilite" (clarte), pas "sante" financiere |
| Langue FR informelle | OK | Tutoiement "tu", "tes", "ton" |
| ComprendreSection | OK | 5 items, textes courts (<8 mots), tous educatifs |
| Coach narrative | OK | Template-based ou LLM-generated, pas de promesse |

---

## G3 — FINANCIAL CORE DELEGATION

**Verdict: PASS**

| Check | Status | Detail |
|-------|--------|--------|
| Import `financial_core.dart` | OK | `visibility_score_service.dart:2` |
| `ConfidenceScorer.scoreWithBlocs()` | OK | Appel combine (fix V1 MEDIUM-1 applique) |
| Pas de duplication calcul | OK | Normalisation axes seulement |
| Anti-pattern #12 respecte | OK | Aucun `_calculateTax()` prive |
| `RetirementTaxCalculator.estimateMarginalRate` | OK | Delegue a `financial_core/tax_calculator.dart` |
| `TemporalPriorityService.prioritize` | OK | Service existant reutilise |
| `CoachingService.generateTips` | OK | Service existant reutilise |
| `CoachNarrativeService.generate` | OK | Service existant reutilise |

---

## G4 — CODE QUALITY & EDGE CASES

**Verdict: WARN** (1 HIGH, 1 MEDIUM)

### HIGH-3: `_computeTemporalItems` utilise `salaireBrutMensuel * 12` au lieu de `revenuBrutAnnuel`

**Fichier**: `pulse_screen.dart:98-102`
```dart
final taxSaving3a = profile.salaireBrutMensuel > 0
    ? pilier3aPlafondAvecLpp *
        RetirementTaxCalculator.estimateMarginalRate(
            profile.salaireBrutMensuel * 12, profile.canton)
    : 0.0;
```

Le parametre de `estimateMarginalRate` s'appelle `revenuBrutAnnuel` (tax_calculator.dart:246).
Utiliser `salaireBrutMensuel * 12` ignore le 13e mois et le bonus.

**Impact**: Taux marginal sous-estime → economie 3a affichee trop basse dans le temporal strip.
Julien: 9'078 × 12 = 108'936 au lieu de 122'207 → taux marginal ~2-3% plus bas.

**Fix**:
```dart
final taxSaving3a = profile.salaireBrutMensuel > 0
    ? pilier3aPlafondAvecLpp *
        RetirementTaxCalculator.estimateMarginalRate(
            profile.revenuBrutAnnuel, profile.canton)
    : 0.0;
```

### MEDIUM-3: `_conjointToCoachProfile` patrimoine toujours vide

**Fichier**: `pulse_screen.dart:314`
```dart
patrimoine: const PatrimoineProfile(),
```

Le profil synthetique du conjoint a toujours `patrimoine = 0`. Lauren a 380k en investissements.
L'axe Liquidite du conjoint sera systematiquement sous-evalue.

**Impact**: Score couple biaise. Le score Liquidite du conjoint sera toujours `partial` ou `missing`
meme si le conjoint a du patrimoine renseigne. Note: `ConjointProfile` ne porte pas `PatrimoineProfile`,
donc cette limitation est architecturale — a traiter quand `ConjointProfile` sera enrichi.

**Recommandation**: Documenter en TODO inline ou enrichir `ConjointProfile` avec patrimoine minimal.

### Checks OK

| Check | Status | Detail |
|-------|--------|--------|
| `withValues(alpha:)` moderne | OK | 0 usage de `withOpacity()` deprece |
| Null safety complet | OK | `profile.firstName ?? 'toi'`, `conj.salaireBrutMensuel ?? 0` |
| Empty state gere | OK | `_buildEmptyState` avec CTA onboarding |
| Edge case 0 actions | OK | `if (visibilityScore.actions.isNotEmpty)` |
| Edge case no profile | OK | `!coachProvider.hasProfile` → empty state |
| Edge case no conjoint | OK | `_hasMinimalConjointData` guard |
| Edge case canton vide | OK | `profile.canton.isNotEmpty ? profile.canton : 'ZH'` |
| Clamp scores | OK | `.clamp(0, 100)`, `.clamp(0.0, 25.0)` |
| Profile tracking | OK | `_lastProfile == profile` evite recomputation |
| Generation counter | OK | `_narrativeGeneration` evite setState stale |
| Couple alert threshold | OK | `> 15` points de difference (raisonnable) |
| Couple weak name | OK | Identifie correctement le profil le plus faible |

---

## G5 — NAVIGATION & INTEGRATION

**Verdict: PASS**

### Routes verifiees (toutes existent dans `app.dart`)

| Route | Source | Existe |
|-------|--------|--------|
| `/lpp-deep/rachat` | Action cards, ComprendreSection | OK |
| `/profile/bilan` | Action cards, CoachBriefingCard | OK |
| `/simulator/3a` | Action cards, ComprendreSection | OK |
| `/arbitrage/rente-vs-capital` | ComprendreSection | OK |
| `/budget` | ComprendreSection | OK |
| `/mortgage/affordability` | ComprendreSection | OK |
| `/household` | Action cards | OK |
| `/document-scan` | Action cards | OK |
| `/onboarding/smart` | Empty state | OK |

### Tab integration

| Check | Status | Detail |
|-------|--------|--------|
| Tab 0 = PulseScreen | OK | `main_navigation_shell.dart:114` |
| Tab names | OK | `['pulse', 'agir', 'apprendre', 'profil']` |
| Tab icon Pulse | OK | `show_chart_outlined` / `show_chart` |
| Analytics tab switch | OK | `_analytics.trackTabSwitch()` |
| Feedback loop tab 0 | OK | Snackbar "Recommandations mises a jour" quand retour Pulse |
| MentorFAB contextuel | OK | `MentorFAB(currentTabIndex: _currentIndex)` |
| Budget auto-sync | OK | `profileUpdatedSinceBudget` + `refreshFromProfile` |
| App lifecycle observer | OK | `WidgetsBindingObserver` + welcome-back snackbar |
| Deep link from notif | OK | `NotificationService.consumePendingRoute()` |

---

## G6 — ASYNC SAFETY & STATE MANAGEMENT

**Verdict: PASS** (1 INFO)

| Check | Status | Detail |
|-------|--------|--------|
| `unawaited()` pour fire-and-forget | OK | `pulse_screen.dart:90` |
| `mounted` check avant setState | OK | `pulse_screen.dart:162, 167` |
| Generation counter anti-stale | OK | `_narrativeGeneration` incremente + verifie |
| `context.read` hors async gap | OK | `context.read<ByokProvider>()` avant `await` (line 138) |
| `context.watch` dans build/didChangeDep | OK | Pas dans callbacks async |
| Tips error handling | OK | try/catch avec `debugPrint` |
| Narrative error handling | OK | try/catch + fallback `_narrative = null` |
| `didChangeDependencies` gating | OK | `_lastProfile == profile` evite recomputation |
| Profile cleared handling | OK | Lines 72-78 — reset state quand profile supprime |
| BYOK null safety | OK | `byok.isConfigured && byok.apiKey != null && byok.provider != null` |
| LLM provider switch exhaustive | OK | `_ => null` fallback (line 144) |

### INFO-3: `context.read<ByokProvider>()` dans methode async mais AVANT l'await

`pulse_screen.dart:138` — `context.read<ByokProvider>()` est appele synchronement avant le `await`
sur line 155. C'est correct car `context.read` est safe tant qu'il n'y a pas de gap async avant.
La guard `if (mounted)` line 137 est presente. Aucun risque, mais noter pour review future si
le code est refactore.

---

## G7 — TEST COVERAGE

**Verdict: WARN** (1 MEDIUM)

### Etat des tests

| Fichier | Tests | Source |
|---------|-------|--------|
| `visibility_score_service.dart` | 20 tests | `test/services/visibility_score_service_test.dart` (fix V1) |
| `pulse_screen.dart` (458 loc) | **0 tests** | Manquant |
| `visibility_score_card.dart` | **0 tests** | Manquant |
| `comprendre_section.dart` | **0 tests** | Manquant |
| `pulse_action_card.dart` | **0 tests** | Manquant |
| `pulse_disclaimer.dart` | **0 tests** | Manquant |
| `main_navigation_shell.dart` | Existant mais pas mis a jour pour Pulse | `test/screens/coach/navigation_shell_test.dart` |

### MEDIUM-4: Tests manquants pour PulseScreen (commit 3) + widgets

Le fix V1 a ajoute 20 tests pour `VisibilityScoreService`, ce qui couvre le moteur de calcul.
Mais les ajouts du commit 3 (temporal strip, couple mode, coach narrative, `_conjointToCoachProfile`)
ne sont pas testes.

**Tests manquants prioritaires**:
1. `_conjointToCoachProfile` — conversion ConjointProfile → CoachProfile
2. `_computeTemporalItems` — items temporels generes
3. `_hasMinimalConjointData` — guard couple mode
4. Widget tests basiques pour les 4 widgets pulse

---

## FINDINGS SUMMARY (V2)

| ID | Severity | Gate | Description | File:Line | Status |
|----|----------|------|-------------|-----------|--------|
| ~~HIGH-1~~ | ~~HIGH~~ | ~~G4~~ | ~~`computeCouple` salaireBrutMensuel*12~~ | ~~visibility_score_service.dart~~ | **FIXED** (690de87) |
| ~~HIGH-2~~ | ~~HIGH~~ | ~~G7~~ | ~~0 tests~~ | — | **PARTIALLY FIXED** (20 unit tests added) |
| ~~MEDIUM-1~~ | ~~MEDIUM~~ | ~~G3~~ | ~~Double appel scorer~~ | ~~visibility_score_service.dart~~ | **FIXED** (scoreWithBlocs) |
| ~~MEDIUM-2~~ | ~~MEDIUM~~ | ~~G4~~ | ~~Seuil couple 0.7 vs 0.8~~ | ~~visibility_score_service.dart~~ | **FIXED** (690de87) |
| **HIGH-3** | **HIGH** | G4 | `_computeTemporalItems` utilise `salaireBrutMensuel * 12` | `pulse_screen.dart:101` | **OPEN** |
| MEDIUM-3 | MEDIUM | G4 | Conjoint patrimoine toujours vide (architectural) | `pulse_screen.dart:314` | **KNOWN LIMITATION** |
| MEDIUM-4 | MEDIUM | G7 | Tests manquants PulseScreen + widgets | — | **OPEN** |
| LOW-1 | LOW | G4 | Textes FR hardcodes (pas d'i18n `.tr`) | Multiple files | Acceptable Phase 0 |
| LOW-2 | LOW | G4 | `confidenceScore: visibilityScore.total` naming ambigu | `pulse_screen.dart:206` | Cosmetic |
| INFO-1 | INFO | G1 | CLAUDE.md dit Montserrat, codebase utilise Outfit | N/A | Doc outdated |
| INFO-2 | INFO | G2 | Axe "Securite" = menage/archetype, pas assurances | `visibility_score_service.dart` | By design |
| INFO-3 | INFO | G6 | `context.read` avant await — correct mais fragile | `pulse_screen.dart:138` | OK |

---

## FIX REQUIS

### 1. HIGH-3 — Fix temporal items tax estimation (2 lignes)
```dart
// pulse_screen.dart:98-102 — AVANT:
final taxSaving3a = profile.salaireBrutMensuel > 0
    ? pilier3aPlafondAvecLpp *
        RetirementTaxCalculator.estimateMarginalRate(
            profile.salaireBrutMensuel * 12, profile.canton)
    : 0.0;

// APRES:
final taxSaving3a = profile.salaireBrutMensuel > 0
    ? pilier3aPlafondAvecLpp *
        RetirementTaxCalculator.estimateMarginalRate(
            profile.revenuBrutAnnuel, profile.canton)
    : 0.0;
```

---

## VERDICT FINAL V2

**Phase 0 Pulse (3 commits): WARN — Deployable avec 1 fix requis.**

### Ce qui est bien fait
- Architecture solide : StatefulWidget avec lifecycle correct, Provider state
- Async safety exemplaire : generation counter, mounted checks, unawaited
- Compliance LSFin parfaite : disclaimer visible dans tous les etats
- Financial core correctement delegue : 4 services reutilises
- Couple mode bien implemente : conversion ConjointProfile, weak name detection
- Navigation verifiee : 9 routes, 4 tabs, analytics, deep links, FAB contextuel
- 20 tests unitaires pour le moteur de calcul

### Ce qui reste a corriger
- **HIGH-3** : `salaireBrutMensuel * 12` dans temporal strip (meme pattern que HIGH-1 deja fixe)
- **MEDIUM-4** : Tests pour PulseScreen + 4 widgets

**Recommandation** : Fixer HIGH-3 (2 lignes) puis merge.
