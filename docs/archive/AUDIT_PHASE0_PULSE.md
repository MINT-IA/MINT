# AUDIT — Phase 0 Pulse (S48)

> **Auditor**: Claude Code Senior Audit Team
> **Date**: 2026-03-10
> **Branch**: `claude/add-mint-repo-link-L2xCb`
> **Commit**: `936ed76` — `feat(pulse): implement Phase 0 Pulse dashboard with visibility score`
> **Scope**: 8 files, 1263 lines added, 12 lines removed

---

## SUMMARY

| Gate | Verdict | Findings |
|------|---------|----------|
| G1 — Architecture & Design System | **PASS** | 0 CRIT, 0 HIGH |
| G2 — Compliance (LSFin, banned terms) | **PASS** | 0 CRIT, 0 HIGH |
| G3 — Financial Core delegation | **PASS** | 0 CRIT, 1 MEDIUM |
| G4 — Code quality & edge cases | **WARN** | 0 CRIT, 1 HIGH, 1 MEDIUM |
| G5 — Navigation & integration | **PASS** | 0 CRIT, 0 HIGH |
| G6 — Test coverage | **FAIL** | 0 CRIT, 1 HIGH |

**Overall: WARN** — 0 CRIT, 2 HIGH, 2 MEDIUM, 3 LOW/INFO

---

## FILES AUDITED

| # | File | Lines | Role |
|---|------|-------|------|
| 1 | `screens/pulse/pulse_screen.dart` | 243 | Dashboard Pulse principal |
| 2 | `services/visibility_score_service.dart` | 451 | Moteur score visibilite (4 axes) |
| 3 | `widgets/pulse/visibility_score_card.dart` | 200 | Carte score + barres axes |
| 4 | `widgets/pulse/comprendre_section.dart` | 158 | Liens simulateurs |
| 5 | `widgets/pulse/pulse_action_card.dart` | 153 | Carte action prioritaire |
| 6 | `widgets/pulse/pulse_disclaimer.dart` | 45 | Micro-disclaimer inline |
| 7 | `screens/main_navigation_shell.dart` | +12/-12 | Tab 0 : Dashboard → Pulse |
| 8 | `theme/colors.dart` | +1 | `primaryLight` ajoutee |

---

## G1 — ARCHITECTURE & DESIGN SYSTEM

**Verdict: PASS**

| Check | Status | Detail |
|-------|--------|--------|
| GoRouter navigation | OK | `context.push()` partout, 9 routes verifiees |
| Provider state | OK | `context.watch<CoachProfileProvider>()` |
| Google Fonts — Outfit (headings) | OK | Coherent avec codebase (1080+ usages Outfit vs 10 Montserrat) |
| Google Fonts — Inter (body) | OK | Utilise correctement |
| MintColors palette | OK | Tous les tokens existent dans `colors.dart` |
| SliverAppBar + gradient | OK | `pulse_screen.dart:101-127` |
| Material 3 patterns | OK | `FilledButton`, `InkWell`, `Material`, `ClipRRect` |
| `primaryLight` ajoutee | OK | `Color(0xFF2D2D2F)` — gradient end coherent |
| Responsive layout | OK | `EdgeInsets`, `Expanded`, `SliverToBoxAdapter` |
| Tab integration | OK | `_tabs` rendu `static const` (optimisation), icon `show_chart` |

**Note**: CLAUDE.md mentionne Montserrat pour headings mais le codebase utilise Outfit depuis S30+. CLAUDE.md est desynchronise — pas un defaut du code Phase 0.

---

## G2 — COMPLIANCE (LSFin, FINMA, BANNED TERMS)

**Verdict: PASS**

| Check | Status | Detail |
|-------|--------|--------|
| Termes bannis absents | OK | Aucun "garanti", "certain", "optimal", "meilleur", "parfait", "conseiller" |
| Disclaimer present | OK | `PulseDisclaimer`: "Outil educatif. Ne constitue pas un conseil financier personnalise. LSFin art. 3" |
| Disclaimer toujours visible | OK | Affiche en bas de Pulse ET dans empty state |
| CTA educatifs | OK | "Simuler", "Explorer", "Demarrer" — jamais prescriptif |
| Pas de promesse | OK | Score = "visibilite" (clarte), pas "sante" financiere |
| Langue FR informelle | OK | Tutoiement "tu", "tes", "ton" |
| Langage inclusif | N/A | Pas de texte genere dans cette phase |

---

## G3 — FINANCIAL CORE DELEGATION

**Verdict: PASS** (1 MEDIUM)

| Check | Status | Detail |
|-------|--------|--------|
| Import `financial_core.dart` | OK | `visibility_score_service.dart:2` |
| Utilise `ConfidenceScorer.score()` | OK | Pour enrichment prompts |
| Utilise `ConfidenceScorer.scoreAsBlocs()` | OK | Pour repartition 4 axes |
| Pas de duplication calcul | OK | Normalisation axes seulement (ratio linéaire) |
| Pas de `_calculateTax()` prive | OK | Anti-pattern #12 respecte |

### MEDIUM-1: Double appel scorer (performance)

**Fichier**: `visibility_score_service.dart:104-105`
```dart
final blocs = ConfidenceScorer.scoreAsBlocs(profile);
final confidence = ConfidenceScorer.score(profile);
```

`scoreAsBlocs()` et `score()` calculent le profil deux fois separement. Les prompts pourraient etre extraits de `scoreAsBlocs()` ou un appel combine pourrait etre utilise (`scoreEnhanced()` retourne les deux).

**Impact**: Performance (x2 calcul sur chaque build). Pas de bug fonctionnel.
**Recommandation**: Utiliser `scoreEnhanced()` qui retourne blocs + prompts en un seul pass, ou cacher le resultat.

---

## G4 — CODE QUALITY & EDGE CASES

**Verdict: WARN** (1 HIGH, 1 MEDIUM)

### HIGH-1: `computeCouple` utilise `salaireBrutMensuel * 12` au lieu de `revenuBrutAnnuel`

**Fichier**: `visibility_score_service.dart:122-123`
```dart
final userRevenu = userProfile.salaireBrutMensuel * 12;
final conjRevenu = conjointProfile.salaireBrutMensuel * 12;
```

`CoachProfile` expose le getter `revenuBrutAnnuel` qui prend en compte `nombreDeMois` (12, 13, 13.5) et le bonus. Utiliser `salaireBrutMensuel * 12` sous-estime le revenu pour les profils avec 13e mois (standard en Suisse) et ignore les bonus.

**Impact**: Ponderation couple incorrecte pour ~60% des salaries suisses (13e mois). Julien = 9'078 × 12 = 108'936 au lieu de 122'207 reel.
**Fix**: Remplacer par `userProfile.revenuBrutAnnuel`.

### MEDIUM-2: Seuils status couple vs individuel inconsistants

**Fichier**: `visibility_score_service.dart:144`
```dart
status: avgScore >= uAxis.maxScore * 0.7 ? 'complete' : ...
```

Les axes individuels utilisent `>= 20` (soit 80% de 25) pour 'complete', mais `computeCouple` utilise `>= 0.7` (70%). Un couple peut apparaitre 'complete' sur un axe la ou les deux individus sont 'partial'.

**Impact**: Cosmétique — affichage inconsistant couple vs solo.
**Fix**: Aligner sur le meme seuil (80% = `* 0.8`).

### Checks OK

| Check | Status | Detail |
|-------|--------|--------|
| `withValues(alpha:)` moderne | OK | Pas de `withOpacity()` deprece |
| Null safety | OK | `profile.firstName ?? 'toi'`, null checks partout |
| Empty state gere | OK | `pulse_screen.dart:131-212` — CTA onboarding |
| Edge case 0 actions | OK | `if (visibilityScore.actions.isNotEmpty)` |
| Clamp scores 0-100 | OK | `.clamp(0, 100)` sur percentage |
| Clamp axes 0-25 | OK | `.clamp(0.0, 25.0)` sur chaque axe |
| No hardcoded strings | LOW | Textes FR directement dans le code, pas d'i18n `.tr`. Acceptable Phase 0. |

---

## G5 — NAVIGATION & INTEGRATION

**Verdict: PASS**

| Route utilisee | Existe dans `app.dart` | Ligne |
|----------------|----------------------|-------|
| `/lpp-deep/rachat` | OK | L491 |
| `/profile/bilan` | OK | L271 (nested) |
| `/simulator/3a` | OK | L345 |
| `/arbitrage/rente-vs-capital` | OK | L734 |
| `/budget` | OK | L330 |
| `/mortgage/affordability` | OK | L610 |
| `/household` | OK | L317 |
| `/document-scan` | OK | L296 |
| `/onboarding/smart` | OK | L676 |

| Integration check | Status | Detail |
|-------------------|--------|--------|
| Tab 0 remplacee | OK | `RetirementDashboardScreen` → `PulseScreen` |
| Tab name | OK | `'dashboard'` → `'pulse'` |
| Tab icon | OK | `home_outlined` → `show_chart_outlined` |
| `_tabs` static const | OK | Optimisation valide (aucun tab ne depend de `this`) |
| Import cleanup | OK | Ancien import `retirement_dashboard_screen` retire |

---

## G6 — TEST COVERAGE

**Verdict: FAIL** (1 HIGH)

### HIGH-2: Aucun test pour Phase 0 (0/1263 lignes couvertes)

| Fichier | Tests attendus | Tests trouves |
|---------|---------------|---------------|
| `visibility_score_service.dart` (451 loc) | Unit tests: axes normalization, narrative, actions, couple | **0** |
| `pulse_screen.dart` (243 loc) | Widget test: empty state, loaded state, actions list | **0** |
| `visibility_score_card.dart` (200 loc) | Widget test: score display, axis bars, couple alert | **0** |
| `comprendre_section.dart` (158 loc) | Widget test: 5 items render, navigation | **0** |
| `pulse_action_card.dart` (153 loc) | Widget test: render, navigation, impact badge | **0** |
| `pulse_disclaimer.dart` (45 loc) | Widget test: disclaimer text visible | **0** |

**Tests existants relies**: `ConfidenceScorer` (bien couvert), `MainNavigationShell` (existant mais pas mis a jour pour Pulse).

**Impact**: Regression silencieuse possible. Les axes normalization (raw/max * 25) ne sont pas testes.
**Recommandation minimum**:
1. `test/services/visibility_score_service_test.dart` — 15+ tests unitaires
2. `test/screens/pulse/pulse_screen_test.dart` — 5+ widget tests
3. Mettre a jour `navigation_shell_test.dart` pour le tab Pulse

---

## FINDINGS SUMMARY

| ID | Severity | Gate | Description | File:Line |
|----|----------|------|-------------|-----------|
| HIGH-1 | **HIGH** | G4 | `computeCouple` ignore 13e mois + bonus (use `revenuBrutAnnuel`) | `visibility_score_service.dart:122-123` |
| HIGH-2 | **HIGH** | G6 | 0 tests pour 1263 lignes de code | — |
| MEDIUM-1 | MEDIUM | G3 | Double appel scorer (performance x2) | `visibility_score_service.dart:104-105` |
| MEDIUM-2 | MEDIUM | G4 | Seuil status couple (0.7) vs solo (0.8) inconsistant | `visibility_score_service.dart:144` |
| LOW-1 | LOW | G4 | Textes FR hardcodes (pas d'i18n `.tr`) | Multiple files |
| INFO-1 | INFO | G1 | CLAUDE.md dit Montserrat, codebase utilise Outfit | N/A |
| INFO-2 | INFO | G2 | Axe "Securite" contient menage/archetype, pas assurances | `visibility_score_service.dart:264` |

---

## RECOMMENDED FIXES (priorite)

### 1. HIGH-1 — Fix couple revenue weighting (5 min)
```dart
// visibility_score_service.dart:122-123
// AVANT:
final userRevenu = userProfile.salaireBrutMensuel * 12;
final conjRevenu = conjointProfile.salaireBrutMensuel * 12;
// APRES:
final userRevenu = userProfile.revenuBrutAnnuel;
final conjRevenu = conjointProfile.revenuBrutAnnuel;
```

### 2. HIGH-2 — Add test suite (30 min)
- `test/services/visibility_score_service_test.dart`
- `test/screens/pulse/pulse_screen_test.dart`

### 3. MEDIUM-1 — Single scorer call (5 min)
```dart
// Utiliser scoreEnhanced() ou combiner les appels
final enhanced = ConfidenceScorer.scoreEnhanced(profile);
// Access blocs and prompts from enhanced result
```

### 4. MEDIUM-2 — Align couple threshold (2 min)
```dart
// visibility_score_service.dart:144
status: avgScore >= uAxis.maxScore * 0.8 ? 'complete' : ...
```

---

## VERDICT FINAL

**Phase 0 Pulse: WARN — Deployable avec reserves.**

L'architecture est solide, le design system est respecte, la compliance LSFin est en ordre, et le `financial_core` est correctement delegue. Les deux HIGH sont:
- Un bug de calcul couple (13e mois ignore) — impact reel modere car `computeCouple` n'est pas encore appele dans le flow
- L'absence totale de tests — risque de regression eleve

**Recommandation**: Fixer HIGH-1 + ecrire les tests avant merge dans main.
