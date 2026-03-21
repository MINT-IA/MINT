# Budget Vivant Architecture

> Statut: spec produit + architecture applicative
> Rôle: traduire `Budget A + Budget B + Gap + Cap` dans l'architecture MINT actuelle
> Source de vérité: oui, pour l'intégration du concept `Budget vivant` sans casser le shell 4 onglets
> Dépend de: `CLAUDE.md`, `MINT_UX_GRAAL_MASTERPLAN.md`, `MINT_CAP_ENGINE_SPEC.md`
> Ne couvre pas: refonte visuelle détaillée écran par écran, algorithmes actuariels complets, implémentation backend

---

## 1. Thèse

Le budget n'est pas un outil parmi d'autres.

Le budget est le sol.

Dans MINT:
- le `budget aujourd'hui` montre la liberté réelle du présent,
- le `budget retraite` montre la liberté projetée du futur,
- le `gap` montre l'écart entre les deux,
- le `cap` montre le meilleur levier pour réduire cet écart,
- et ce levier doit pouvoir montrer ses effets:
  - maintenant,
  - plus tard,
  - et parfois sur une séquence de plusieurs années.

Ce modèle ne remplace pas:
- le coach,
- l'explorer,
- le dossier,
- les parcours de vie.

Il devient la couche de lecture silencieuse commune à tout le produit.

---

## 2. Ce qui ne change pas

Le shell 4 onglets reste la bonne architecture:

```text
[Aujourd'hui] [MINT] [Explorer] [Dossier]
```

Traduction:
- `Aujourd'hui` = budget vivant
- `MINT` = coach / cerveau / clarification
- `Explorer` = hubs / navigation autonome
- `Dossier` = vérité personnelle / documents / données / couple

Règle:
- on ne revient pas à 3 onglets.
- on ne cache pas `Explorer` derrière le coach.
- on ne fusionne pas `Dossier` et `Explorer`.

---

## 3. Nouveau cœur conceptuel

## 3.1 Budget A — Aujourd'hui

Le budget d'aujourd'hui doit répondre à:
- combien entre chaque mois,
- combien sort,
- combien reste libre,
- à quel point ce chiffre est fiable.

Forme cible:

```text
Revenu   CHF X
Charges  CHF Y
Libre    CHF Z
```

## 3.2 Budget B — Retraite

Le budget retraite doit répondre à:
- quels revenus mensuels projetés existeraient à la retraite,
- quelles charges probables resteraient,
- combien resterait libre par mois.

Composants typiques:
- AVS
- rente LPP
- retraits 3a / capital annualisé
- autres revenus retraite si présents
- charges retraite estimées

## 3.3 Gap

Le `gap` est:

```text
Gap = Libre aujourd'hui - Libre retraite
```

Rôle:
- rendre tangible l'enjeu
- donner une unité commune aux leviers
- permettre au `CapEngine` d'expliquer son action

Exemple:
- `L'écart : CHF 1'140/mois`
- `Un rachat LPP réduirait cet écart de 12%`

## 3.4 Temporalités d'impact

Un levier MINT ne doit pas seulement répondre à:
- `est-ce utile ?`

Il doit aussi répondre à:
- `qu'est-ce que ça change cette année ?`
- `qu'est-ce que ça change à la retraite ?`
- `qu'est-ce que ça change si je l'étale intelligemment ?`

Règle:
- un cap peut être un levier simple,
- ou une séquence de leviers,
- si la séquence est plus fidèle à l'intérêt réel de l'utilisateur.

## 3.5 Cap

Le `cap` n'est plus un bloc abstrait.

Il devient:
- le meilleur levier pour réduire le `gap`,
- ou, si le `gap` n'est pas encore calculable, le meilleur levier pour fiabiliser le budget futur.

Et ce cap doit pouvoir porter jusqu'à 3 couches d'impact:
- `impact_now`
- `impact_later`
- `impact_sequence`

Exemple:
- `impact_now`: `~CHF 2'800 d'impôt en moins cette année`
- `impact_later`: `écart retraite réduit de 12%`
- `impact_sequence`: `~CHF 8'500 d'économie fiscale cumulée sur 3 ans`

---

## 4. Traduction dans l'architecture actuelle

## 4.1 Existant à conserver

Sources actuelles:
- [CoachProfile](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/models/coach_profile.dart)
- [CoachProfileProvider](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/providers/coach_profile_provider.dart)
- [BudgetService](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/domain/budget/budget_service.dart)
- [ForecasterService](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/forecaster_service.dart)
- [CapEngine](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/cap_engine.dart)
- [PulseScreen](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/pulse/pulse_screen.dart)
- [CoachChatScreen](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/coach/coach_chat_screen.dart)
- [ExploreTab](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/main_tabs/explore_tab.dart)
- [DossierTab](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/main_tabs/dossier_tab.dart)
- [MainNavigationShell](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/main_navigation_shell.dart)

Règle:
- on ne jette pas `CapEngine`
- on ne remplace pas `ForecasterService`
- on n'introduit pas une seconde source de vérité parallèle au `CoachProfile`

## 4.2 Nouveau service

Créer:
- `apps/mobile/lib/services/retirement_budget_service.dart`

Rôle:
- transformer la projection retraite en budget mensuel lisible

Job:
- prendre des sorties de projection existantes
- les annualiser / mensualiser proprement
- produire un `libre retraite` éducatif

Ce service est le seul vrai nouveau calcul du chantier.

## 4.3 Nouvel orchestrateur

Créer:
- `apps/mobile/lib/services/budget_living_engine.dart`
- `apps/mobile/lib/models/budget_snapshot.dart`

Rôle:
- agréger le présent, le futur, le gap, la confiance et le cap

---

## 5. BudgetSnapshot

## 5.1 Objet

```dart
class BudgetSnapshot {
  final PresentBudget present;
  final RetirementBudget? retirement;
  final BudgetGap? gap;
  final CapDecision cap;
  final BudgetCapImpact? capImpact;
  final BudgetCapSequence? capSequence;
  final int confidenceScore;
  final BudgetStage stage;
  final List<CapSignal> supportingSignals;
  final DateTime computedAt;
}
```

## 5.2 Sous-objets

```dart
class PresentBudget {
  final double monthlyIncome;
  final double monthlyCharges;
  final double monthlyFree;
}

class RetirementBudget {
  final double avsMonthly;
  final double lppMonthly;
  final double pillar3aMonthly;
  final double otherMonthly;
  final double monthlyCharges;
  final double monthlyFree;
}

class BudgetGap {
  final double monthlyGap;
  final double ratioRetained;
  final bool isPositive;
}

class BudgetCapImpact {
  final String? now;
  final String? later;
  final String? sequence;
}

class BudgetCapSequenceStep {
  final String label;
  final String effect;
}

class BudgetCapSequence {
  final String title;
  final List<BudgetCapSequenceStep> steps;
  final String? cumulativeBenefit;
}

enum BudgetStage {
  presentOnly,
  emergingRetirement,
  fullGapVisible,
}
```

## 5.3 Règles métier

### Stage 1 — `presentOnly`

Cas:
- jeune profil
- données retraite insuffisantes
- confiance trop basse

UI:
- montrer Budget A seul
- montrer un cap de complétude ou de premier levier

### Stage 2 — `emergingRetirement`

Cas:
- projection possible
- confiance encore moyenne

UI:
- montrer Budget B de manière plus prudente
- afficher fourchette ou message de confiance

### Stage 3 — `fullGapVisible`

Cas:
- confiance suffisante
- données retraite exploitables

UI:
- montrer Budget A + Budget B + Gap
- le gap devient le chiffre clé

---

## 6. RetirementBudgetService

## 6.1 Entrées

- `CoachProfile`
- `ProjectionResult` de `ForecasterService`
- `confidenceScore`

## 6.2 Sorties

```dart
class RetirementBudget {
  final double avsMonthly;
  final double lppMonthly;
  final double pillar3aMonthly;
  final double otherMonthly;
  final double monthlyCharges;
  final double monthlyFree;
}
```

## 6.3 Règles

- ne jamais prétendre à une précision supérieure à la confiance réelle
- si certificat LPP absent:
  - assumer une sortie conservative
  - ou une fourchette
- distinguer clairement revenu retraite et liberté retraite
- les charges retraite peuvent être simplifiées en V1 mais doivent être explicitement qualifiées comme estimation

## 6.4 Clause d'honnêteté

Si aucun levier réaliste ne change matériellement le `gap`:
- le service ne ment pas par sur-précision,
- le `CapEngine` prend le relais avec un cap d'honnêteté,
- l'UI montre les limites de manœuvre.

---

## 7. BudgetLivingEngine

## 7.1 Interface cible

```dart
abstract final class BudgetLivingEngine {
  static BudgetSnapshot compute({
    required CoachProfile profile,
    required DateTime now,
    CapMemory? memory,
  });
}
```

## 7.2 Pipeline

```text
CoachProfile
-> BudgetService
-> ForecasterService
-> RetirementBudgetService
-> ConfidenceScorer
-> CapEngine
-> BudgetSnapshot
```

## 7.3 Responsabilités

Le moteur:
- calcule Budget A
- calcule Budget B si possible
- calcule le gap si possible
- choisit le stage d'affichage
- appelle le `CapEngine`
- traduit le cap en impacts temporels compréhensibles
- expose une séquence si le meilleur levier est pluriannuel
- produit l'objet unique consommé par `Aujourd'hui` et injecté dans `MINT`

Le moteur ne doit pas:
- faire de recommandation prescriptive
- cacher l'incertitude
- contourner les garde-fous compliance

---

## 8. Aujourd'hui = Budget vivant

## 8.1 Rôle

`Aujourd'hui` cesse d'être un hero d'insights génériques.

Il devient:
- le lieu où l'on voit sa liberté actuelle,
- sa liberté future (quand pertinent),
- l'écart (quand défendable),
- le prochain levier,
- et le double ou triple effet de ce levier dans le temps.

Mais le hero ne montre PAS toujours le libre mensuel.

Le hero s'adapte au parcours actif de l'utilisateur:
- si retraite = le gap ou le libre retraite
- si dette = la marge à retrouver
- si chômage = le budget de survie 90 jours
- si achat = la capacité d'achat
- si premier emploi = le salaire net décrypté
- si aucun parcours déclaré = le libre mensuel comme sol neutre

Le `BudgetSnapshot` alimente Aujourd'hui, mais c'est le goal actif qui choisit le hero.

## 8.2 Structure cible

```text
Bonjour Julien

CHF 2'480
libre par mois

Revenu   8'200
Charges  5'720
Libre    2'480

À la retraite
CHF 1'340
libre par mois

L'écart : CHF 1'140/mois

[Cap du jour]

Aujourd'hui   ~CHF 2'800 d'impôt en moins
Retraite      écart réduit de 12%
Sur 3 ans     ~CHF 8'500 cumulés

3a        CHF 32'000
LPP       CHF 70'377
Confiance 72%
```

## 8.3 Règles d'affichage

- Budget A est toujours visible si le profil existe
- Budget B apparaît progressivement avec la confiance
- le gap n'apparaît que quand il est défendable
- le cap s'explique par rapport au gap ou à la fiabilité du budget futur
- quand un levier a un effet court terme et long terme, les deux doivent être visibles
- quand une stratégie échelonnée est meilleure qu'un levier unique, l'écran doit pouvoir montrer la séquence sans devenir un tableau complexe

## 8.4 Ce qui change dans [PulseScreen](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/pulse/pulse_screen.dart)

Le rôle de l'écran change:
- avant: hero de cap + signaux
- après: hero de liberté mensuelle + gap + cap

À conserver:
- logique `CapEngine`
- `ActionSuccess`
- ton calme

À remplacer progressivement:
- `dominantNumber` devient `monthlyFreeToday`
- `secondarySignals` deviennent `3a / LPP / confiance`
- la carte cap devient contextuelle au gap

---

## 9. Injection dans MINT

## 9.1 Rôle

Le coach reçoit le `BudgetSnapshot` à chaque requête importante.

Ainsi, il peut parler naturellement:
- du libre aujourd'hui
- du libre retraite
- du gap
- du coût de court terme d'un levier
- du bénéfice de long terme
- du bénéfice fiscal ou cash immédiat
- du bénéfice cumulé d'une stratégie échelonnée

## 9.2 Règle produit

Le coach n'explique pas un levier dans le vide.

Il l'explique dans le langage:
- de la marge,
- du gap,
- de la liberté future,
- ou de la donnée manquante qui empêche de calculer proprement.

## 9.3 Exemples

Pas:
- `Un rachat LPP est intéressant.`

Mais:
- `Tu as CHF 2'480 de libre aujourd'hui. Un rachat de CHF 30'000 réduirait ta marge d'environ CHF 833/mois pendant 3 ans, mais réduirait ton écart retraite de 12%.`
- `Tu as CHF 2'480 de libre aujourd'hui. À la retraite, tu tomberais à CHF 1'340. Des rachats LPP échelonnés sur 3 ans pourraient réduire cet écart de 12% et alléger ton impôt cumulé d'environ CHF 8'500. Voici l'hypothèse, la preuve, la simulation.`

---

## 10. Explorer et Dossier

## 10.1 Explorer

Ne change pas de rôle.

Il reste:
- la porte d'entrée autonome
- l'accès aux hubs
- l'alternative au coach

## 10.2 Dossier

Ne change pas de rôle.

Il reste:
- la source de vérité personnelle
- le lieu des documents
- le lieu du couple
- le lieu de la complétude et de la confiance

Le `Budget vivant` lit dans `Dossier`.
Il ne le remplace pas.

---

## 11. Parcours utilisateur

## 11.1 Jour 1

- âge + revenu + canton
- Budget A visible
- cap de complétude ou premier levier

## 11.2 Semaine 1

- ajout LPP / LAMal / logement / documents
- Budget A se fiabilise
- Budget B commence à émerger

## 11.3 Semaine 2-4

- confiance > seuil
- gap visible
- caps d'optimisation lisibles

## 11.4 Long terme

- boucle `action -> recalcul -> gap réduit`
- système vivant

---

## 12. Roadmap technique minimale

### Phase 1
- `RetirementBudgetService`
- `BudgetSnapshot`
- `BudgetLivingEngine`

### Phase 2
- brancher `PulseScreen` sur le snapshot
- injecter le snapshot dans le coach

### Phase 3
- affiner le stage d'affichage
- ajouter la courbe trajectoire
- enrichir les signaux de soutien
- ajouter `impact_now / impact_later / impact_sequence`
- introduire les premières `cap sequences`

### Phase 4
- open banking en temps réel sur Budget A

---

## 13. Non-objectifs

Ce chantier ne doit pas:
- changer le shell 4 onglets
- supprimer les 110 écrans existants
- transformer MINT en app budget pure
- faire croire que tous les parcours commencent par le budget

Règle clé:
- le budget est le sol,
- pas la porte d'entrée unique.

---

## 14. Définition de réussite

Le concept est réussi si:
- `Aujourd'hui` devient immédiatement lisible et plus concret,
- le cap devient naturellement relié à un écart,
- le coach parle dans le langage de la marge et du futur,
- les parcours de vie continuent d'exister comme entrées autonomes,
- et le produit paraît plus vivant sans devenir plus prescriptif.
