# MINT CapEngine Spec

> Statut: spec produit + technique
> Dépend de: `MINT_UX_GRAAL_MASTERPLAN.md`, `NAVIGATION_GRAAL_V10.md`, `VOICE_SYSTEM.md`
> Rôle: transformer les insights MINT en priorité du moment lisible et actionnable
> Source de vérité: oui, pour la priorisation, les CTA modes, la mémoire et le feedback loop du `Cap du jour`
> Ne couvre pas: tokens UI détaillés, copy exhaustive, migration écran par écran

---

## 1. Rôle du CapEngine

Le `CapEngine` est la couche qui relie:
- les données utilisateur
- les insights calculés
- la narration `Aujourd'hui`
- le handoff vers `Coach` ou un flow structuré

Sans `CapEngine`, MINT montre des chiffres.

Avec `CapEngine`, MINT dit:
- ce qui compte maintenant
- pourquoi
- quel levier activer
- avec quel effet

---

## 2. Position dans l'architecture

```text
Profile / Documents / Open Banking / Timestamps
-> Forecaster / Budget / Fiscal / Protection services
-> ResponseCardService + PulseHeroEngine + confidence
-> CapEngine
-> Aujourd'hui hero
-> Coach prompt / route / capture
-> action réalisée
-> update profile + confidence + hero
```

---

## 3. Job to be done

Le `CapEngine` doit répondre à une seule question:

**"Si MINT ne devait proposer qu'une seule chose maintenant, laquelle serait la plus utile?"**

---

## 4. Sortie attendue

Le moteur retourne un objet unique:

```ts
CapDecision {
  kind: CapKind
  priority_score: number
  headline: string
  why_now: string
  cta_label: string
  cta_mode: "route" | "coach" | "capture"
  cta_route?: string
  coach_prompt?: string
  capture_type?: string
  expected_impact?: string
  confidence_label?: string
  blocking_data?: string[]
  supporting_signals?: CapSignal[]
  source_cards?: string[]
  expires_at?: DateTime
}
```

### Durée de vie du cap

Heuristique V1:
- un cap standard expire `24h` après sa première exposition
- un cap `Complete` persiste jusqu'à résolution ou jusqu'à remplacement par un risque plus critique
- un cap lié à une deadline expire à l'échéance métier réelle, même si elle est inférieure à `24h`
- après action réussie, le cap courant expire immédiatement et le moteur recalcule un nouveau cap
- si l'utilisateur ignore le même cap plusieurs jours de suite, le `recency_modifier` baisse sa priorité et favorise une rotation contrôlée

---

## 5. Types de caps

```text
Complete   = il manque une donnée qui bloque la qualité
Correct    = un risque ou un déséquilibre doit être traité
Optimize   = un levier concret améliore la situation
Secure     = un risque de protection / compliance / timing existe
Prepare    = un événement ou horizon justifie une préparation
```

### Exemples

- `Complete`
  `Ton certificat LPP manque encore. Sans lui, ta retraite reste floue.`

- `Correct`
  `Ton budget serre un peu trop. On peut lui redonner de l'air.`

- `Optimize`
  `Cette année, ton 3a peut encore alléger la note fiscale.`

- `Secure`
  `Ta couverture invalidité mérite un vrai check.`

- `Prepare`
  `Tu pars bientôt à l'étranger. Trois choses doivent bouger avant le départ.`

---

## 6. Entrées du moteur

## 6.1 Données utilisateur

- âge
- canton
- statut marital
- mode couple / ménage si actif
- enfants
- revenu
- patrimoine
- dettes
- budget
- LPP
- 3a
- documents disponibles
- open banking connecté ou non

## 6.2 Métadonnées de qualité

- `confidence_score`
- `dataTimestamps`
- `missing_fields`
- `staleness flags`
- `document freshness`

## 6.3 Insights calculés

- `PulseHeroEngine.primaryFocus`
- `ResponseCardService.generateForPulse(...)`
- budget margin
- retirement replacement rate
- AVS / LPP / 3a gaps
- fiscal opportunity
- debt risk
- insurance / protection gaps
- life-event alerts

## 6.4 Signals comportementaux

- dernier écran visité
- dernière action réalisée
- dernier cap servi
- derniers prompts coach
- flows abandonnés récemment
- contexte ménage vs individuel de la dernière décision

## 6.5 Time triggers

- fin d'année fiscale
- départ annoncé
- refresh annuel
- document périmé
- échéance de couple / invitation / consentement

## 6.6 Caps ménage

Dans certains cas, le `CapEngine` ne doit pas raisonner seulement au niveau individuel.

Le moteur peut produire un cap ménage quand:
- l'impact réel porte sur les deux personnes,
- la décision modifie AVS, fiscalité, logement, succession ou retraite à l'échelle du ménage,
- un arbitrage croisé entre deux profils est plus utile qu'une optimisation isolée.

Exemples de caps ménage:
- `Voir ce qui change à deux`
- `Prioriser le rachat LPP le plus utile pour votre ménage`
- `Comparer l'impact fiscal couple vs individuel`
- `Clarifier le prochain levier logement à deux`

Règles:
- un cap ménage doit rester lisible comme un seul levier principal;
- il ne doit pas fusionner deux problèmes sans lien;
- il doit expliciter ce qui concerne le ménage et ce qui reste individuel;
- il ne doit jamais masquer les asymétries fortes entre les deux profils.

---

## 7. Règles de scoring

Le `priority_score` doit combiner:

```text
score = impact * urgency * confidence_penalty * readiness * recency_modifier
```

### Dimensions

- `impact`
  combien ce levier change réellement la situation

- `urgency`
  est-ce sensible au temps ou au risque

- `confidence_penalty`
  si la confiance est trop basse, on pousse plutôt vers compléter la donnée

- `readiness`
  si l'action est exécutable immédiatement

- `recency_modifier`
  éviter de resservir le même cap 5 fois d'affilée

### Heuristique simple V1

- si `confidence < 45`
  favoriser `Complete`

- si deadline fiscale < 30 jours et levier 3a / fiscal existe
  favoriser `Optimize`

- si opportunité `3a rétroactif` existe
  favoriser `Optimize` avec urgence modérée, jamais `Secure`

- si budget négatif ou dette critique
  favoriser `Correct`

- si risque protection fort
  favoriser `Secure`

- si life event proche ou déclaré
  favoriser `Prepare`

### Règle budget / déficit

Si le budget est en déficit:
- le cap doit montrer d'abord la marge à retrouver
- puis l'action la plus proche (ajuster une enveloppe, couper un poste, simuler)
- jamais un chiffre rouge seul sans levier

### Clause d'honnêteté

Si aucun levier réaliste n'existe à horizon utile:
- le `CapEngine` ne doit pas fabriquer une fausse solution;
- il doit dire la vérité avec tact;
- il peut basculer vers un cap de clarification, de protection ou d'orientation humaine;
- l'UX montre alors les limites de manœuvre, pas un faux espoir.

### Règle LPP / certificat

Si `avoirLppTotal == null` ou si le certificat LPP manque:
- les projections retraite détaillées doivent être considérées comme indicatives;
- le moteur doit favoriser un cap `Complete` ou un `why_now` centré sur le certificat LPP;
- les écrans détaillés doivent afficher des fourchettes larges plutôt qu'une précision artificielle.

---

## 8. Hiérarchie des décisions

### Ordre V1

1. Risque critique immédiat
2. Donnée manquante bloquante
3. Levier fiscal / retraite à forte fenêtre temporelle
4. Correction budget / dette
5. Préparation life event
6. Optimisation secondaire

### Règle

`CapEngine` ne retourne qu'un cap principal.

Les autres signaux vivent en:
- signaux secondaires dans `Aujourd'hui`
- suggestions dans `Coach`
- cards de soutien

---

## 9. Stratégies de CTA

## 9.1 `cta_mode = route`

À utiliser quand:
- le flow est déterministe
- l'objectif est clair
- les données sont suffisantes

Exemples:
- `/rente-vs-capital`
- `/budget`
- `/assurances/lamal`
- `/expatriation`

## 9.2 `cta_mode = coach`

À utiliser quand:
- il faut clarifier
- l'utilisateur a besoin d'un arbitrage
- plusieurs options sont plausibles

Exemples:
- `Aide-moi à prioriser entre 3a et rachat LPP`
- `Dis-moi ce qui compte dans ma situation`

## 9.3 `cta_mode = capture`

À utiliser quand:
- la donnée manque
- un scan ou import débloque la qualité

Exemples:
- certificat LPP
- extrait AVS
- relevé open banking

---

## 10. Copy contract

Le `CapEngine` ne renvoie pas des phrases longues.

Il renvoie des morceaux sobres:

- `headline`
  4 à 9 mots

- `why_now`
  1 phrase

- `cta_label`
  3 à 5 mots

- `expected_impact`
  2 à 8 mots

### Exemples

```text
headline: Cette année compte encore
why_now: Un versement 3a peut encore alléger tes impôts et renforcer ta retraite.
cta_label: Simuler mon 3a
expected_impact: jusqu'à CHF 1'240 d'économie
```

```text
headline: Il manque ton LPP
why_now: Sans certificat, ta projection retraite reste plus floue qu'elle ne devrait.
cta_label: Scanner mon certificat
expected_impact: +30 pts de confiance
```

---

## 11. États d'interface

## 11.1 Aujourd'hui

Le hero consomme:
- `headline`
- `why_now`
- `cta_label`
- `expected_impact`
- `confidence_label`

## 11.2 Coach

Le coach consomme:
- `headline` comme rappel
- `coach_prompt` comme amorce
- `source_cards` comme support

## 11.3 Dossier

Le dossier consomme:
- `blocking_data`
- `capture_type`

---

## 12. Feedback loop

Après action:
- recalcul du profil
- recalcul du `confidence_score`
- recalcul du hero
- affichage d'un `Action Success`

### Format retour

```text
Tu as fait: Versement 3a ajouté
Ce que ça change: économie fiscale estimée CHF 1'240
La suite: vérifier ton certificat LPP
```

---

## 13. V1 technique

### Interface

```dart
abstract final class CapEngine {
  static CapDecision compute({
    required CoachProfile? profile,
    required int confidenceScore,
    required PulsePrimaryFocus? primaryFocus,
    required List<ResponseCard> responseCards,
    required DateTime now,
    CapMemory? memory,
  });
}
```

### CapMemory

L'objet `CapMemory` persiste entre les sessions et alimente le `recency_modifier` et le ciblage.

```dart
class CapMemory {
  final String? lastCapServed;
  final DateTime? lastCapDate;
  final List<String> completedActions;
  final List<String> abandonedFlows;
  final String? preferredCtaMode; // "route" | "coach" | "capture"
  final List<String> declaredGoals;
  final String? recentFrictionContext; // contexte émotionnel observé, jamais diagnostic
}
```

Règles:
- `recentFrictionContext` capture le contexte observable (stress, hésitation, abandon), pas une étiquette psychologique
- `completedActions` et `abandonedFlows` alimentent le `recency_modifier` du scoring
- `preferredCtaMode` est déduit du comportement, pas demandé explicitement
- persisté via `SharedPreferences` sous clé `_cap_memory`

### Dépendances V1

- `PulseHeroEngine`
- `ResponseCardService`
- `CoachProfileProvider`
- `dataTimestamps`
- `ConfidenceScorer`

### V1 sans ML

Le V1 peut être 100% heuristique.

Pas besoin d'intent classifier ici.
Le classifier vient après, côté coach.

---

## 14. V2

Le `CapEngine` pourra ensuite intégrer:
- intent history
- abandon de flow
- preferences explicites
- saisonnalité
- segmentation comportementale
- caps ménage explicites quand la décision réelle porte sur le couple
- distinction plus fine obligatoire / surobligatoire dans les caps LPP et décaissement

### Séquences de caps (V2)

Le V1 choisit le meilleur cap indépendamment. Le V2 introduit le concept de **séquence** : un cap peut avoir des prérequis (données ou actions) et un cap suivant.

Cas d'usage principal : le plan retraite.

```text
Phase 1: Complete (certificat LPP → extrait AVS → recensement 3a)
Phase 2: Prepare (rente vs capital → timing 3a → hypothèque)
Phase 3: Optimize (rachat LPP → LAMal → succession → budget post)
Phase 4: Prepare (déclaration retrait → vérification rente AVS)
```

Règles de séquencement:
- un cap de Phase N+1 ne s'active que si les données de Phase N sont présentes
- un cap sans ses prérequis data affiche des fourchettes indicatives + CTA vers la capture manquante
- la progression est visible dans Aujourd'hui : "X/Y étapes clarifiées"
- le recalcul après action complétée peut changer l'ordre des caps restants

Interface V2 (cible):
```dart
class CapSequence {
  final String sequenceId;       // ex: "retirement_plan"
  final List<String> phases;     // ex: ["clarify", "arbitrate", "prepare", "accompany"]
  final Map<String, List<String>> prereqs; // capId → required completedActions
  final int completedCount;
  final int totalCount;
}
```

Le V2 n'ajoute pas de nouvelle UI obligatoire — la séquence est invisible. Le CapEngine choisit toujours 1 cap, mais il le choisit en tenant compte de l'avancement dans la séquence.

Mais pas en V1.

---

## 15. Métriques

- taux d'ouverture du cap
- taux de complétion de l'action recommandée
- temps entre `cap -> action`
- variation de confiance post-action
- taux de répétition du même cap
- part des caps `complete / correct / optimize / secure / prepare`

---

## 16. DOD

Le `CapEngine` est prêt si:
- il retourne toujours 1 cap principal
- ce cap est lisible en moins de 3 secondes
- il choisit entre route / coach / capture
- il ne ressert pas le même levier trop souvent
- il favorise la donnée manquante quand la confiance est faible
- il rend l'impact visible après action
