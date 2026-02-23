# ADR-20260223 — Simulator Data Enrichment Pattern

**Status**: Accepted
**Date**: 2026-02-23
**Authors**: Julien + Claude (architecture)
**Depends on**: ADR-20260223-unified-financial-engine.md

---

## Contexte

### Probleme identifie

MINT dispose de 39+ simulateurs qui collectent des donnees financieres detaillees
(LPP, 3a, hypotheque, fiscalite, etc.) mais ces donnees sont **100% ephemeres** :
elles disparaissent a la fermeture du simulateur.

Parallellement, les projections (retraite, dashboard) manquent de donnees precises
et utilisent des estimations approximatives (ex: LPP estime depuis le salaire).

Le paradoxe : **l'utilisateur a deja saisi la donnee exacte dans un simulateur,
mais la projection continue d'utiliser une estimation.**

### Chiffres cles

| Metrique | Valeur |
|----------|--------|
| Simulateurs totaux | 39 |
| Simulateurs qui pre-remplissent depuis CoachProfile | 5 (13%) |
| Simulateurs qui sauvegardent vers CoachProfile | 0 (0%) |
| Ecrans qui sauvegardent vers le profil | 2 (annual_refresh + coach_checkin) |
| Donnees ephemeres estimees | ~85% des inputs simulateurs |

### Exemple concret

1. L'utilisateur ouvre le simulateur "Rente vs Capital"
2. Il saisit son avoir LPP reel : **420'000 CHF** (lu sur son certificat de prevoyance)
3. Il ferme le simulateur
4. La projection retraite continue d'utiliser l'estimation : **280'000 CHF** (calculee depuis le salaire)
5. Ecart de 140'000 CHF → projection fausse de ~500 CHF/mois

---

## Decision

### Architecture : Prefill → Delta → OptIn Save → Lifecycle

4 etapes pour chaque simulateur :

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│  1. PREFILL  │────>│ 2. DELTA DETECT │────>│ 3. OPTIN SAVE│────>│ 4. LIFECYCLE│
│              │     │                 │     │              │     │             │
│ Lire profil  │     │ Comparer inputs │     │ Proposer MAJ │     │ Declencher  │
│ Pre-remplir  │     │ vs profil actuel│     │ si delta > 0 │     │ coaching    │
│ les champs   │     │ Identifier plus │     │ L'user valide│     │ events      │
│              │     │ frais / precis  │     │ ou refuse    │     │             │
└─────────────┘     └─────────────────┘     └──────────────┘     └─────────────┘
```

### Etape 1 — Prefill

Le simulateur lit `CoachProfile` via `context.read<CoachProfileProvider>()` et
pre-remplit les champs avec les valeurs connues du profil.

```dart
// Pattern existant (retirement_projection_screen.dart L88-100)
final profile = context.read<CoachProfileProvider>().profile;
if (profile != null) {
  _ageController.text = profile.age.toString();
  _salaryController.text = profile.salaireBrutMensuel.toStringAsFixed(0);
  _lppController.text = profile.prevoyance.avoirLppTotal?.toStringAsFixed(0) ?? '';
}
```

**Regle** : Chaque champ pre-rempli porte un badge visuel "Estime" ou "Reel"
selon que la donnee provient d'une estimation ou d'une saisie utilisateur.

### Etape 2 — Delta Detection

A la fin du simulateur (quand l'utilisateur a rempli et valide), comparer les
valeurs saisies avec le profil actuel :

```dart
class SimulatorDelta {
  final String fieldKey;        // ex: 'prevoyance.avoirLppTotal'
  final String label;           // ex: 'Avoir LPP'
  final double? profileValue;   // valeur actuelle du profil
  final double? simulatorValue; // valeur saisie dans le simulateur
  final bool isEstimated;       // true si la valeur profil est estimee
  final DeltaType type;         // factual | hypothetical

  bool get hasMeaningfulDelta =>
    type == DeltaType.factual &&
    simulatorValue != null &&
    (profileValue == null || (simulatorValue! - profileValue!).abs() > 100);
}

enum DeltaType {
  factual,      // Donnee reelle (solde LPP, salaire) → peut etre sauvegardee
  hypothetical, // Scenario (age retraite, taux rendement) → JAMAIS sauvegardee
}
```

### Etape 3 — OptIn Save

Si des deltas factuels sont detectes, afficher une carte non-intrusive :

```
┌─────────────────────────────────────────────────┐
│ 🔄 Donnees plus recentes detectees              │
│                                                 │
│ ☑ Avoir LPP : 280'000 → 420'000 CHF            │
│ ☑ Taux de conversion : 5.4%                     │
│ ☐ Canton : ZH → VD (non coche par defaut)       │
│                                                 │
│ [Mettre a jour mon profil]  [Non merci]         │
│                                                 │
│ Tes projections seront plus precises.           │
└─────────────────────────────────────────────────┘
```

**Implementation** via `CoachProfileProvider.updateFromSimulator()` — nouvelle methode
calquee sur `updateFromRefresh()` (L357 de `coach_profile_provider.dart`) :

```dart
// Nouvelle methode dans CoachProfileProvider
Future<void> updateFromSimulator({
  required String simulatorId,
  Map<String, dynamic> fieldsToUpdate = const {},
}) async {
  if (_profile == null || fieldsToUpdate.isEmpty) return;

  // Construire le profil mis a jour
  var updated = _profile!;
  for (final entry in fieldsToUpdate.entries) {
    updated = _applyFieldUpdate(updated, entry.key, entry.value);
  }

  _profile = updated;

  // Persister vers SharedPreferences (meme pattern que updateFromRefresh)
  final prefs = await SharedPreferences.getInstance();
  for (final entry in fieldsToUpdate.entries) {
    await prefs.setString('_simulator_${entry.key}', json.encode(entry.value));
  }
  await prefs.setString('_simulator_last_update', DateTime.now().toIso8601String());
  await prefs.setString('_simulator_source', simulatorId);

  notifyListeners();
}
```

### Etape 4 — Lifecycle Events

Quand le profil est mis a jour materiellement, declencher un evenement coaching :

```dart
// Dans CoachingService, ecouter les changements de profil
if (delta.fieldKey == 'prevoyance.avoirLppTotal' &&
    (delta.simulatorValue! - delta.profileValue!).abs() > 10000) {
  triggerEvent(CoachEvent.profileEnriched(
    field: 'lpp',
    oldValue: delta.profileValue,
    newValue: delta.simulatorValue,
    impact: 'Tes projections retraite viennent de gagner +20% de precision',
  ));
}
```

---

## Regles non-negociables

### Ce qui peut etre sauvegarde (DeltaType.factual)

| Donnee | Simulateurs sources | Champ CoachProfile |
|--------|--------------------|--------------------|
| Avoir LPP reel | Rente vs Capital, LPP Deep, Retirement | `prevoyance.avoirLppTotal` |
| Taux de conversion reel | Rente vs Capital, LPP Deep | `prevoyance.tauxConversionReel` |
| Soldes 3a | 3a Optimizer, 3a Deep | `prevoyance.comptes3a` |
| Salaire brut mensuel | Job Comparison, First Job | `salaireBrutMensuel` |
| Canton actuel | Fiscal Comparator, Mortgage | `canton` |
| Valeur immobiliere | Housing Sale, Mortgage | `patrimoine.immobilier` |
| Dette hypothecaire | Mortgage, Housing Sale | `dettes.hypotheque` |
| Prime LAMal | LAMal Franchise | `depenses.lamalPremium` |

### Ce qui ne doit JAMAIS etre sauvegarde (DeltaType.hypothetical)

| Donnee | Raison |
|--------|--------|
| Age de retraite choisi | C'est un scenario "et si", pas une decision |
| Taux de rendement simule | Hypothese, pas un fait |
| Canton de destination (comparaison) | L'utilisateur n'a pas demenage |
| Montant de rachat LPP | Intention, pas action realisee |
| Franchise LAMal testee | Comparaison, pas choix definitif |
| Salaire d'un emploi compare | Offre, pas emploi actuel |

### Regle d'or

> **Sauvegarder = "C'est MA situation actuelle."**
> **Ne pas sauvegarder = "C'est un scenario que j'explore."**

---

## Mapping par simulateur (Phase 1 — Top 5)

### 1. Simulateur Rente vs Capital

| Champ | Prefill depuis | Peut sauvegarder | Type |
|-------|---------------|------------------|------|
| Avoir LPP | `prevoyance.avoirLppTotal` | Oui | factual |
| Taux conversion | `prevoyance.tauxConversionReel` | Oui | factual |
| Canton | `canton` | Non (pas de demenagement) | hypothetical |
| Etat civil | `etatCivil` | Non (deja dans profil) | — |
| % capital choisi | — | Non | hypothetical |

### 2. Simulateur Fiscal (comparateur cantons)

| Champ | Prefill depuis | Peut sauvegarder | Type |
|-------|---------------|------------------|------|
| Revenu brut | `salaireBrutMensuel * 12` | Oui (si plus recent) | factual |
| Canton actuel | `canton` | Non (c'est une comparaison) | hypothetical |
| Commune | `commune` | Non | hypothetical |
| Etat civil | `etatCivil` | Non | — |
| Enfants | `nombreEnfants` | Oui (si change) | factual |
| Fortune | `patrimoine.totalNet` | Oui | factual |

### 3. Simulateur Hypothecaire

| Champ | Prefill depuis | Peut sauvegarder | Type |
|-------|---------------|------------------|------|
| Revenu brut menage | `salaireBrutMensuel + conjoint.salaire` | Oui | factual |
| Prix du bien | — | Non (projet, pas reel) | hypothetical |
| Fonds propres | `patrimoine.epargneLiquide` | Oui | factual |
| Avoir LPP (EPL) | `prevoyance.avoirLppTotal` | Oui | factual |
| Avoir 3a (EPL) | `prevoyance.totalEpargne3a` | Oui | factual |

### 4. Simulateur 3a Optimizer

| Champ | Prefill depuis | Peut sauvegarder | Type |
|-------|---------------|------------------|------|
| Revenu | `salaireBrutMensuel * 12` | Oui | factual |
| Statut emploi | `employmentStatus` | Non (deja dans profil) | — |
| Solde 3a actuel | `prevoyance.totalEpargne3a` | Oui | factual |
| Contribution annuelle | — | Non (intention) | hypothetical |
| Rendement estime | — | Non | hypothetical |

### 5. Comparateur LPP (Job Change)

| Champ | Prefill depuis | Peut sauvegarder | Type |
|-------|---------------|------------------|------|
| Avoir LPP actuel | `prevoyance.avoirLppTotal` | Oui | factual |
| Taux conversion actuel | `prevoyance.tauxConversionReel` | Oui | factual |
| Salaire actuel | `salaireBrutMensuel` | Non (deja dans profil) | — |
| Nouveau salaire | — | Non (offre, pas reel) | hypothetical |
| Nouveau taux conversion | — | Non | hypothetical |

---

## Phases restantes (P2-P4)

### Phase 2 — Simulateurs secondaires (10 simulateurs)

Etendre le pattern aux : Disability Gap, Divorce, Housing Sale, Donation,
Succession, Unemployment, First Job, LAMal Franchise, Expat, Frontalier.

### Phase 3 — Enrichment avance

- Upload certificat de prevoyance (OCR ou saisie manuelle)
- Saisie extrait AVS
- Import releve 3a
- Chaque enrichment reduit la bande d'incertitude (voir ADR confidence scoring)

### Phase 4 — Lifecycle integration

- Coaching proactif : "Tu as saisi un avoir LPP de 420k dans le simulateur
  mais ton profil indique 280k. As-tu recu un nouveau certificat ?"
- Rappels annuels : "Ton avoir LPP date de 11 mois. Mets-le a jour avec
  ton nouveau certificat de prevoyance."
- Declenchement automatique de recalcul des projections apres enrichment.

---

## Alternatives considerees

### 1. Auto-save systematique (rejetee)

Sauvegarder automatiquement toute donnee saisie dans un simulateur.

**Rejete car** :
- Un scenario "et si je demenage a Zoug" ne doit pas changer le canton du profil
- L'utilisateur perdrait le controle de ses donnees
- Pollution du profil avec des donnees hypothetiques
- Violation du principe de consentement (LPD)

### 2. Aucun save-back (statu quo, rejetee)

Garder les simulateurs 100% ephemeres.

**Rejete car** :
- Projections restent imprecises meme quand l'utilisateur a fourni la donnee
- UX frustrant : saisir le meme LPP dans 3 simulateurs differents
- Score de confiance plafonne

### 3. OptIn save explicite (acceptee)

L'utilisateur choisit quelles donnees sauvegarder via une carte non-intrusive.

**Accepte car** :
- Respect du consentement utilisateur
- Distinction claire factuel vs hypothetique
- Enrichissement progressif du profil (coherent avec confidence scoring)
- Pattern existant (`updateFromRefresh()`) reutilisable

---

## Consequences

### Ce qui change

1. **CoachProfileProvider** : nouvelle methode `updateFromSimulator()`
2. **Simulateurs Phase 1** : ajout de delta detection + OptIn card en fin de flow
3. **CoachProfile** : `isEstimated` flag sur certains champs pour distinguer estimation vs reel
4. **ConfidenceScorer** : bonus quand un champ passe de `estimated` a `real`

### Ce qui ne change pas

- Wizard / mini-onboarding (inchange)
- Backend API (les calculs restent en Flutter)
- Navigation / design system
- Simulateurs non Phase 1 (restent read-only pour l'instant)

---

## Liens

- **ADR-20260223-unified-financial-engine.md** — Architecture Financial Core
- **ADR-20260223-archetype-driven-retirement.md** — Archetypes et confidence scoring
- **LPD art. 6** — Principe de consentement (traitement des donnees personnelles)
- **coach_profile_provider.dart L357** — Pattern `updateFromRefresh()` de reference
- **annual_refresh_screen.dart** — Implementation existante de save-back
