# Cohort OS Spec

> Statut: **IMPLÉMENTÉ** — vérifié contre le code le 29 mars 2026
> Role: adapter MINT par cohortes sans creer de seconde source de verite
> Scope: coach, suggestion chips, Pulse, priorisation de surfaces
> Non-scope: nouvelle engine de classification parallele, refonte visuelle globale
>
> **Implémentation** :
> - `ProductCohortService` : 6 cohortes projetées depuis `LifecyclePhaseService` (pas de nouvelle SOT)
> - `_suppressedTopics()` : matrice de suppression par cohorte (Anti-Bullshit Manifesto §6)
> - `CapEngine` : filtrage des caps par cohort topics (6 points d'intégration)
> - `ContextInjectorService` : injection lifecycle phase dans le contexte coach (14 points)
> - `SequenceTemplate.topics` : 10 séquences avec topics field pour cohort suppression check
> - `SequenceChatHandler.startSequence()` : guard `suppressedTopics.intersection()` avant démarrage

---

## 1. Principe directeur

L'OS de cohortes ne doit pas creer un nouveau systeme de classification a cote
de l'existant.

**Source de verite canonique**:
- [LifecyclePhaseService](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/lifecycle_phase_service.dart)
- [CoachProfile](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/models/coach_profile.dart)
- [ContentAdapterService](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/content_adapter_service.dart)

**Regle absolue**:
- `LifecyclePhaseService` reste le classifieur canonique
- l'OS de cohortes est une **projection produit** du lifecycle existant
- aucune nouvelle SOT de type `CohortDetectionService` n'est introduite en Phase 6A

Autrement dit:

```text
LifecyclePhase + profile context + major life signals
-> projection cohort product
-> adaptation de l'experience
```

et non:

```text
Nouveau moteur cohortes
-> concurrence le lifecycle existant
-> derive du code et des prompts
```

---

## 2. Pourquoi cet OS existe

MINT doit cesser d'etre percu comme une app finance generique.

L'objectif de l'OS de cohortes est de faire en sorte que:
- un 22 ans
- un couple de 34 ans avec projet immo
- un independant de 47 ans
- un pre-retraite de 59 ans
- un retraite de 72 ans

n'aient pas l'impression d'utiliser la meme app.

L'OS de cohortes adapte:
- les suggestion chips
- le ton coach
- les priorites Pulse
- l'ordre des surfaces mises en avant
- la densite de contenu
- les sujets a pousser ou a taire

Il ne change pas:
- le design system
- la structure generale de navigation
- les moteurs financiers

---

## 3. Modele cible

## 3.1 6 cohortes produit

Les cohortes sont un modele produit, pas une SOT technique autonome.

| Cohorte | Phase dominante | Definition produit |
|---|---|---|
| 18-27 Premier pas | `demarrage` | premier salaire, budget, comparaison d'offre |
| 28-37 Construction | `construction` | logement, couple, enfants, premiers arbitrages forts |
| 38-52 Densification | `acceleration` + `consolidation` | arbitrages complexes, protection, retraite preview |
| 53-64 Pre-retraite | `transition` | preparation, fiscalite de sortie, decaissement |
| 65-74 Retraite active | `retraite` | rythme de consommation, protection, succession vivante |
| 75+ Transmission | `transmission` | simplification, transmission, clarte patrimoniale |

## 3.2 Regle de projection

Projection recommandee:

```text
LifecyclePhase.demarrage      -> Cohorte Premier pas
LifecyclePhase.construction   -> Cohorte Construction
LifecyclePhase.acceleration   -> Cohorte Densification
LifecyclePhase.consolidation  -> Cohorte Densification
LifecyclePhase.transition     -> Cohorte Pre-retraite
LifecyclePhase.retraite       -> Cohorte Retraite active
LifecyclePhase.transmission   -> Cohorte Transmission
```

Ensuite, des signaux de contexte raffinent le rendu:
- `profile.isCouple`
- `profile.employmentStatus`
- `profile.patrimoine`
- `profile.dettes`
- `profile.targetRetirementAge`
- signaux de vie deja detectes ou connus par le systeme

---

## 4. Regles d'implementation

## 4.1 Ce qu'on NE fait PAS en Phase 6A

- pas de `CohortDetectionService` declare comme nouvelle source de verite
- pas de pseudo-code base sur des champs `CoachProfile` inexistants
- pas de nouvel `ExplorerHubController` tant qu'il n'existe pas
- pas de gating lourd de tout le produit d'un coup
- pas de refonte visuelle majeure

## 4.2 Ce qu'on fait en Phase 6A

On adapte 3 surfaces seulement:

1. `ResponseCardService.suggestedPrompts()`
2. `CoachContextInjectorService`
3. la priorisation Pulse / Cap a petite echelle

Objectif:
- prouver qu'une experience differenciee par cohorte cree une meilleure valeur
- sans re-architecturer tout le produit

---

## 5. Champs reels a utiliser

La spec doit s'exprimer avec des champs qui existent reellement dans
[coach_profile.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/models/coach_profile.dart).

### Champs OK

- `profile.birthYear`
- `profile.age`
- `profile.salaireBrutMensuel`
- `profile.employmentStatus`
- `profile.isCouple`
- `profile.targetRetirementAge`
- `profile.patrimoine`
- `profile.dettes`
- `profile.prevoyance`
- `profile.nombreEnfants`

### Equivalents a calculer explicitement

Au lieu de champs inexistants, utiliser:

| Faux champ | Equivalent reel |
|---|---|
| `totalAssets` | derive de `profile.patrimoine` |
| `monthlyDebt` | derive de `profile.dettes` |
| `monthlyIncome` | derive de `salaireBrutMensuel` ou net calcule |
| `salaryStatus` | `employmentStatus` |
| `lppCapital` | `profile.prevoyance.avoirLppTotal` ou autre champ prevoyance reel |
| `retirementDate` | derive de `targetRetirementAge` / goal |
| `dependentAge` | signal explicite a definir; ne pas l'inventer |
| `debtSource` | ne pas supposer; modeler plus tard si necessaire |

---

## 6. Les 6 cohortes produit

## 6.1 Premier pas (18-27)

Enjeux:
- premier salaire
- budget sous tension
- comparaison d'offre

Parcours phares:
- premier salaire maitrise
- tension budget simple
- comparaison d'offre

Ce qu'on pousse:
- budget
- fiche de paie
- epargne de base
- comparaison d'emploi

Ce qu'on evite par defaut:
- succession
- retirement deep
- rachat LPP agressif

Ton:
- pedagogique
- simple
- non abstrait

## 6.2 Construction (28-37)

Enjeux:
- achat logement
- couple
- naissance et couts
- premiers arbitrages 3a / fiscalite

Parcours phares:
- acheter sans se pieger
- couple financier
- naissance et couts

Ce qu'on pousse:
- logement
- couple
- enfants
- fiscalite concrete

## 6.3 Densification (38-52)

Enjeux:
- arbitrages complexes
- protection
- retraite preview
- priorisation de leviers

Parcours phares:
- densifier sans se tendre
- retraite preview
- proteger la famille

Ce qu'on pousse:
- protection
- retraite
- fiscalite
- clarification des priorites

## 6.4 Pre-retraite (53-64)

Enjeux:
- transition
- decaissement
- choix rente/capital
- fiscalite de sortie

Parcours phares:
- retraite 11 etapes
- decaissement
- succession / testament

## 6.5 Retraite active (65-74)

Enjeux:
- rythme de consommation
- protection long terme
- succession vivante

Parcours phares:
- rythme de consommation
- succession vivante
- protection longevite

## 6.6 Transmission (75+)

Enjeux:
- simplification
- clarte patrimoniale
- transmission sereine

Parcours phares:
- clarte patrimoniale
- transmission sereine
- sante / fin de vie

---

## 7. Matrice d'adaptation Phase 6A

## 7.1 Suggestion chips

Premiere surface cible.

La logique doit etre:
- lifecycle d'abord
- contexte ensuite
- zero contradiction metier

Exemple de garde-fous:
- ne jamais pousser `rachat LPP` si l'utilisateur n'a pas de LPP
- ne jamais pousser retraite profonde a un 22 ans par defaut
- ne jamais pousser succession en priorite a une cohorte Premier pas

## 7.2 Coach context

Injecter:
- cohort label produit
- ton attendu
- sujets prioritaires
- sujets a ne pas pousser spontanement

Sans:
- mentionner brutalement le nom de la cohorte a l'utilisateur
- rigidifier le coach au point de le rendre idiot

## 7.3 Pulse / Cap

Adapter:
- l'ordre de priorite
- la formulation du cap
- la promesse d'impact

Sans:
- re-ecrire tout `CapEngine` en Phase 6A

---

## 8. Golden personas obligatoires

Chaque cohorte doit avoir au moins un persona golden teste.

### P1 Premier pas
- 24 ans
- premier emploi
- pas de LPP reel exploitable
- budget serre

### P2 Construction
- 33 ans
- en couple
- projet logement
- un enfant en route

### P3 Densification
- 46 ans
- couple avec enfants
- revenus confortables
- protection et retraite preview

### P4 Pre-retraite
- 59 ans
- encore actif
- choix rente/capital a venir

### P5 Retraite active
- 68 ans
- deja retraite
- consommation + succession

### P6 Transmission
- 79 ans
- retraite longue
- clarte patrimoniale et transmission

---

## 9. Assertions de comportement

Avant toute generalisation, definir au minimum 18 assertions, 3 par cohorte.

Exemples:
- P1 ne voit pas `rachat LPP` dans ses suggestions par defaut
- P2 voit logement et couple avant succession
- P3 voit protection / retraite preview avant premier salaire
- P4 voit decaissement et rente/capital avant budget debutant
- P5 ne voit pas comparaison premier emploi comme CTA majeur
- P6 voit transmission / simplification avant optimisation agressive

---

## 10. Plan d'implementation corrige

### Sprint 6A.1
- corriger les suggestion chips lifecycle-aware existantes
- verrouiller les tests metier de suggestions

### Sprint 6A.2
- introduire une projection cohort produit basee sur `LifecyclePhaseService`
- pas de nouvelle SOT

### Sprint 6A.3
- injecter les regles cohortes dans `CoachContextInjectorService`

### Sprint 6A.4
- adapter une priorisation Pulse / Cap minimale

### Sprint 6A.5
- golden personas + assertions produit automatisees

### Sprint 6B
- seulement apres validation Phase 6A
- envisager Explorer ordering
- envisager suppression / dimming de surfaces
- envisager parcours flagship par cohorte

---

## 11. Decision de gouvernance

Cette spec ne doit pas etre lue comme:
- “construisons un nouveau moteur cohortes”

Elle doit etre lue comme:
- “projetons une experience produit cohorte-aware sur la base lifecycle deja existante”

La priorite immediate n'est donc pas d'implanter 18 journeys.

La priorite immediate est:
1. corriger les erreurs cohort-aware deja live
2. verrouiller la logique de suggestion / ton / priorite
3. prouver la valeur sur 3 surfaces

---

## 12. Definition of done

La Phase 6A est reussie si:
- aucune contradiction metier evidente ne subsiste dans les suggestions
- le lifecycle reste la seule base canonique
- 6 personas golden ont des comportements differencies credibles
- coach + suggestions + Pulse ne donnent plus une impression d'app generique
- aucun nouveau moteur parallele n'a ete introduit

