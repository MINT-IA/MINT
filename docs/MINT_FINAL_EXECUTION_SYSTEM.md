# MINT Final Execution System

> Statut: point d'entree unique pour les agents leaders
> Role: transformer MINT en produit exceptionnel, production-ready, centre sur l'experience
> Portee: vision cible, doctrine, priorites, regles d'execution, pack final de prompts
> Principe: ce document orchestre. Les documents cites restent autoritatifs sur leur domaine.

---

## 1. Comment utiliser ce document

Ce document sert de **single entry point** pour les agents leaders qui pilotent MINT.

Il ne remplace pas les sources de verite existantes. Il les assemble en un systeme d'execution coherent.

Ordre de lecture obligatoire:
1. `CLAUDE.md`
2. `AGENTS.md`
3. ce document
4. les documents autoritatifs references en section 2

Règle:
- si ce document donne un cap produit et qu'un document autoritatif donne une regle technique precise, la regle technique precise l'emporte
- si une divergence apparait entre ce document et un document autoritatif, corriger ce document

---

## 2. Documents autoritatifs a respecter

Ces documents restent la reference sur leur domaine:

- [ROADMAP_V2.md](/Users/julienbattaglia/Desktop/MINT/docs/ROADMAP_V2.md)
- [MINT_UX_GRAAL_MASTERPLAN.md](/Users/julienbattaglia/Desktop/MINT/docs/MINT_UX_GRAAL_MASTERPLAN.md)
- [SOURCE_OF_TRUTH_MATRIX.md](/Users/julienbattaglia/Desktop/MINT/docs/SOURCE_OF_TRUTH_MATRIX.md)
- [ONBOARDING_ARCHITECTURE.md](/Users/julienbattaglia/Desktop/MINT/docs/ONBOARDING_ARCHITECTURE.md)
- [RFC_AGENT_LOOP_STATEFUL.md](/Users/julienbattaglia/Desktop/MINT/docs/RFC_AGENT_LOOP_STATEFUL.md)
- [ROUTE_POLICY.md](/Users/julienbattaglia/Desktop/MINT/docs/ROUTE_POLICY.md)
- [GLOSSAIRE_PRODUIT.md](/Users/julienbattaglia/Desktop/MINT/docs/GLOSSAIRE_PRODUIT.md)
- [TOP_10_SWISS_CORE_JOURNEYS.md](/Users/julienbattaglia/Desktop/MINT/docs/TOP_10_SWISS_CORE_JOURNEYS.md)
- [AGENTS.md](/Users/julienbattaglia/Desktop/MINT/AGENTS.md)

---

## 3. Thèse produit finale

MINT ne doit plus etre une collection d'outils.

MINT doit devenir un **compagnon suisse de clarte financiere**, qui:
- comprend la situation d'une personne ou d'un couple
- choisit la bonne prochaine etape
- oriente vers le bon ecran ou la bonne question
- montre ce qui a change
- memorise la progression
- revient avec le bon levier au bon moment

Formule produit:

```text
Comprendre -> Agir -> Voir le delta -> Revenir
```

Formule de marque:

```text
Les chiffres -> Les leviers
```

Ce que MINT ne doit pas etre:
- un dashboard de plus
- une app chat-only
- un catalogue de simulateurs
- une IA qui explique sans faire agir

Ce que MINT doit etre:
- un systeme vivant
- calme, suisse, credible
- pedagogique sans etre mou
- profond sans etre opaque

---

## 4. Changement de doctrine

Jusqu'ici, MINT a beaucoup avance par:
- moteurs
- calculs
- ecrans
- couverture metier

La suite doit se faire par:
- douleurs majeures
- parcours
- delta visible
- memoire de progression
- experience adaptee par cohorte

Nouvelle regle:

**Un sprint est prioritaire seulement s'il rend une douleur majeure plus claire, plus actionnable, ou plus visible.**

---

## 5. Douleurs prioritaires et architecture de parcours

### 5.1 Les 3 parcours flagship

Ce sont les parcours qui doivent devenir irreprochables avant d'elargir davantage le catalogue.

#### 1. Acheter sans se pieger

Pourquoi:
- projet tres emotionnel
- forte valeur percue
- tres demonstratif du moteur suisse de MINT

Le parcours doit couvrir:
- accessibilite logement
- fonds propres
- EPL si pertinent
- fiscalite retrait si pertinente
- resume clair
- prochaine etape credible

#### 2. Sortir d'une tension financiere

Pourquoi:
- grande douleur reelle
- forte frequence
- enorme potentiel de transformation visible

Le parcours doit couvrir:
- diagnostic tension
- dettes / leasing / charges fixes
- ratio de risque
- arbitrage liquidite
- plan de desencombrement
- prochaine action unique

#### 3. Preparer sa retraite sans angle mort

Pourquoi:
- differenciateur suisse majeur
- forte profondeur metier
- grande valeur pour 45+, 55+, 65+

Le parcours doit couvrir:
- revenu retraite projete
- confiance / incertitude
- leviers 3a / LPP / rachat / decaissement
- arbitrages lisibles
- resume final simple

### 5.2 Les 2 couches de renfort

#### Leviers

Cette couche nourrit les 3 parcours flagship:
- pilier 3a
- rachat LPP
- fiscalite
- retroactif 3a
- optimisation de retrait

Règle:
- ne pas traiter ces leviers comme des features isolees
- les brancher dans des parcours humains

#### Couple

Cette couche devient centrale apres stabilisation des 3 parcours flagship.

Elle doit couvrir:
- decisions a deux
- ordre des rachats
- retraite decalée
- asymetries de revenu / patrimoine / LPP
- logement a deux

---

## 6. Cohortes cibles 18-99

MINT ne doit pas penser seulement par age, mais par matrice:
- phase de vie
- structure de foyer
- statut de travail
- stress principal
- confiance des donnees

### Cohortes prioritaires

#### 18-27
- enjeu: premier salaire, premier budget, dette/leasing, education financiere simple
- cap typique: comprendre mon premier vrai revenu
- ton: pedagogique, direct, non abstrait

#### 28-37
- enjeu: logement, couple, enfants, 3a, comparaisons d'emploi
- cap typique: construire sans me pieger
- ton: concret, orienté arbitrages

#### 38-52
- enjeu: densification, famille, impots, prelevements, protection, rachats, projection
- cap typique: prioriser les bons leviers
- ton: serieux, efficace, sans surcharge

#### 53-64
- enjeu: pre-retraite, optimisation, risque de trou, fiscalite de sortie, decaissement
- cap typique: preparer la transition
- ton: maitrise, clarte, confiance

#### 65-74
- enjeu: retrait, rythme de consommation, succession, simplification
- cap typique: proteger et piloter
- ton: simple, rassurant, non technique

#### 75+
- enjeu: transmission, protection, simplicite, lisibilite dossier
- cap typique: garder une vue claire et transmettre proprement
- ton: sobre, accompagne, lisible

Règle de conception:
- un 22 ans, un couple de 36 ans avec projet immobilier, un independant de 47 ans, un pre-retraite de 59 ans et un retraite de 72 ans ne doivent jamais avoir l'impression d'utiliser la meme app generique

---

## 7. Architecture d'experience cible

Boucle coeur:

```text
Dossier
-> comprend la situation
-> nourrit le coach et Aujourd'hui
-> ouvre un parcours
-> declenche une action ou un scan
-> recalcule confiance + projections + caps
-> montre le delta
-> memoire de progression
-> prochaine etape
```

Chaque action dans MINT doit produire au moins un des trois:
- un chiffre qui change
- une confiance qui monte
- une decision qui devient plus claire

Sans cela, MINT reste un calculateur.

---

## 8. Regles produit non negociables

1. Pas de nouvelle feature hors parcours
2. Pas de nouveau chantier catalogue sans douleur claire
3. Pas de wording centre simulateur quand une formulation centree decision ou douleur est possible
4. Pas de chiffre ultra-precis sur donnees faibles sans signal pedagogique
5. Pas d'action sans delta visible
6. Pas de nouvelle route legacy
7. Pas de nouvelle double source de verite
8. Pas de “done” si le chemin runtime critique n'est pas prouve

---

## 9. Regles techniques non negociables

### 9.1 Source de verite

Respecter [SOURCE_OF_TRUTH_MATRIX.md](/Users/julienbattaglia/Desktop/MINT/docs/SOURCE_OF_TRUTH_MATRIX.md).

En particulier:
- `CoachProfile` = modele maitre local
- `MintUserState` = etat runtime unifie
- `financial_core` = seule source de verite calculatoire
- backend `EnhancedConfidence` = source de verite confiance
- onboarding API = chemin primaire, local = fallback

### 9.2 Routage

Respecter [ROUTE_POLICY.md](/Users/julienbattaglia/Desktop/MINT/docs/ROUTE_POLICY.md).

Regles rapides:
- nouvelles routes en francais kebab-case
- pas de nouvelles routes legacy
- toute route coach-routable doit exister dans `ScreenRegistry`
- migrations progressives, jamais big bang

### 9.3 Orchestration coach -> ecran -> retour

Respecter [RFC_AGENT_LOOP_STATEFUL.md](/Users/julienbattaglia/Desktop/MINT/docs/RFC_AGENT_LOOP_STATEFUL.md).

Regles rapides:
- `ScreenReturn` est le contrat central
- realtime riche = chemin canonique
- fallback route-return = exceptionnel / Tier B
- pas de second plan parallele a `CapSequence`
- pas de guard fragile si l'etat runtime persiste suffit

### 9.4 Tier A / Tier B

- Tier A = ecran migre au contrat riche sequence
- Tier B = fallback legacy

Un agent ne doit jamais presenter un ecran Tier B comme s'il etait Tier A.

---

## 10. Ordre d'execution recommande

### Chantier 1
Finir le parcours flagship `Acheter sans se pieger`

### Chantier 2
Construire le parcours flagship `Sortir d'une tension financiere`

### Chantier 3
Finir le parcours flagship `Preparer sa retraite sans angle mort`

### Chantier 4
Brancher la boucle `scan -> enrichissement -> delta visible -> coach explique`

### Chantier 5
Rendre visible `ce qui a change` dans Aujourd'hui et Dossier

### Chantier 6
Construire l'OS de cohortes

### Chantier 7
Hardening production: observabilite, tests runtime, audits de joints

---

## 11. Definition of done d'un parcours exceptionnel

Un parcours n'est pas “fini” parce qu'il a plusieurs ecrans.

Un parcours est fini si:
- l'entree par chat est naturelle
- le coach ouvre le bon flow
- le flow orchestre plusieurs etapes de facon robuste
- l'utilisateur comprend ce qu'il se passe
- un delta visible apparait
- la confiance ou la precision progresse
- la prochaine etape est claire
- le tout est memorise dans l'etat utilisateur
- les tests couvrent le joint runtime principal

---

## 12. Workflow des agents leaders

Le team lead doit suivre cette discipline:

1. cadrer le chantier par douleur et parcours
2. designer le contrat de verite
3. demander spec si sujet metier / legal / suisse
4. faire implementer backend si contrat traverse les couches
5. faire implementer Flutter
6. exiger un auto-audit
7. faire un audit final
8. merger seulement si le runtime principal est prouve

Le team lead ne doit pas:
- lancer plusieurs chantiers strategiques en meme temps
- accepter une PR qui corrige seulement un service si le bug est runtime
- accepter un “green CI” comme seule preuve

---

## 13. Pack final de prompts

### 13.1 Prompt maitre Team Lead

```text
Tu es le team lead de Mint. Ta mission est de transformer Mint en produit exceptionnel, production-ready, centre sur l'experience et non sur l'accumulation de features.

Lis et fais respecter:
- /Users/julienbattaglia/Desktop/MINT/CLAUDE.md
- /Users/julienbattaglia/Desktop/MINT/AGENTS.md
- /Users/julienbattaglia/Desktop/MINT/docs/MINT_FINAL_EXECUTION_SYSTEM.md
- /Users/julienbattaglia/Desktop/MINT/docs/ROADMAP_V2.md
- /Users/julienbattaglia/Desktop/MINT/docs/MINT_UX_GRAAL_MASTERPLAN.md
- /Users/julienbattaglia/Desktop/MINT/docs/SOURCE_OF_TRUTH_MATRIX.md
- /Users/julienbattaglia/Desktop/MINT/docs/ONBOARDING_ARCHITECTURE.md
- /Users/julienbattaglia/Desktop/MINT/docs/RFC_AGENT_LOOP_STATEFUL.md
- /Users/julienbattaglia/Desktop/MINT/docs/ROUTE_POLICY.md
- /Users/julienbattaglia/Desktop/MINT/docs/GLOSSAIRE_PRODUIT.md
- /Users/julienbattaglia/Desktop/MINT/docs/TOP_10_SWISS_CORE_JOURNEYS.md

Doctrine:
- Mint n'est plus une collection d'outils
- Mint doit devenir un systeme vivant: comprendre, agir, voir le delta, revenir
- toute feature doit s'inserer dans un parcours
- toute action doit produire un avant/apres visible
- aucune nouvelle dette structurelle
- aucune divergence mobile/backend/source de verite
- aucun wording produit centre “simulateur” ou “outil” si une formulation centree douleur ou decision est possible

Top priorites produit:
1. Achat logement
2. Dette / leasing / budget sous tension
3. Retraite / pre-retraite / decaissement
4. Scan -> enrichissement -> delta visible
5. Ce qui a change
6. Cohortes
7. Hardening prod

Ton travail:
- decouper le chantier en PRs strictes, testables, ordonnees
- assigner chaque PR a l'agent adapte
- exiger un auto-audit avant chaque commit
- refuser tout chantier hors priorite
- verifier les joints runtime, pas seulement les services
- fournir apres chaque etape:
  1. diagnostic
  2. changement
  3. verification
  4. residus
  5. prochaine etape

Definition of done globale:
- les 3 parcours flagship fonctionnent de bout en bout
- le coach orchestre reellement les ecrans
- l'utilisateur voit ce qui a change
- la confiance et les projections evoluent visiblement
- les cohortes cles ont une experience credible
- les flows critiques ont des tests d'integration runtime
- observabilite minimale en place
```

### 13.2 Prompt Flutter implementation

```text
Tu es le dart-agent Mint. Scope strict: /Users/julienbattaglia/Desktop/MINT/apps/mobile/ uniquement.

Lis:
- /Users/julienbattaglia/Desktop/MINT/.claude/skills/mint-flutter-dev/SKILL.md
- /Users/julienbattaglia/Desktop/MINT/.claude/skills/mint-test-suite/SKILL.md
- /Users/julienbattaglia/Desktop/MINT/CLAUDE.md
- /Users/julienbattaglia/Desktop/MINT/docs/MINT_FINAL_EXECUTION_SYSTEM.md
- /Users/julienbattaglia/Desktop/MINT/docs/MINT_UX_GRAAL_MASTERPLAN.md
- /Users/julienbattaglia/Desktop/MINT/docs/SOURCE_OF_TRUTH_MATRIX.md
- /Users/julienbattaglia/Desktop/MINT/docs/RFC_AGENT_LOOP_STATEFUL.md

Mission:
implementer le chantier demande sans deriver, avec priorite a l'experience utilisateur, au delta visible, a la robustesse runtime, et aux tests de joints.

Regles:
- avant toute modif: flutter analyze && flutter test cible
- ne pas toucher backend
- ne pas creer une nouvelle source de verite
- ne pas laisser de TODO user-facing mort
- si tu touches le coach, verifier:
  - route payload
  - ScreenReturn
  - realtime
  - fallback
  - analytics
  - tests widget/integration
- si tu touches une cohorte, verifier:
  - copy
  - CTA
  - delta visible
  - absence de jargon inutile

Sortie attendue:
- diagnostic
- fichiers touches
- tests lances
- findings restants
```

### 13.3 Prompt Backend implementation

```text
Tu es le python-agent Mint. Scope strict: /Users/julienbattaglia/Desktop/MINT/services/backend/ et si necessaire /Users/julienbattaglia/Desktop/MINT/tools/openapi/.

Lis:
- /Users/julienbattaglia/Desktop/MINT/.claude/skills/mint-backend-dev/SKILL.md
- /Users/julienbattaglia/Desktop/MINT/.claude/skills/mint-test-suite/SKILL.md
- /Users/julienbattaglia/Desktop/MINT/CLAUDE.md
- /Users/julienbattaglia/Desktop/MINT/docs/MINT_FINAL_EXECUTION_SYSTEM.md
- /Users/julienbattaglia/Desktop/MINT/docs/SOURCE_OF_TRUTH_MATRIX.md
- /Users/julienbattaglia/Desktop/MINT/docs/ONBOARDING_ARCHITECTURE.md

Mission:
garantir que tout contrat utilise par les parcours flagship et le coach reste authoritative, non divergent, teste, et documente.

Regles:
- avant modifs: ruff check . && pytest -q
- API change => update openapi + contrat
- ne jamais laisser mobile et backend diverger sur:
  - confidence
  - onboarding
  - profile minimal
  - outputs structures des parcours
  - analytics contract si expose
- ajouter des tests de contrat, pas seulement des tests service

Sortie attendue:
- contrat modifie
- non-divergence garantie
- tests
- residus
```

### 13.4 Prompt Swiss-Brain spec / compliance

```text
Tu es le swiss-brain de Mint. Scope strict: docs/, education/, decisions/, visions/. Pas de code.

Lis:
- /Users/julienbattaglia/Desktop/MINT/CLAUDE.md
- /Users/julienbattaglia/Desktop/MINT/docs/MINT_FINAL_EXECUTION_SYSTEM.md
- /Users/julienbattaglia/Desktop/MINT/docs/TOP_10_SWISS_CORE_JOURNEYS.md
- /Users/julienbattaglia/Desktop/MINT/docs/MINT_UX_GRAAL_MASTERPLAN.md
- /Users/julienbattaglia/Desktop/MINT/docs/SOURCE_OF_TRUTH_MATRIX.md

Mission:
produire la spec metier, suisse, fiscale, pedagogique et compliance avant implementation.

Tu dois fournir:
- hypotheses legales
- zones d'incertitude
- cas limites suisses
- wording recommande
- wording interdit
- jeux de tests metiers
- exigences de preuve documentaire

Interdit:
- ecrire du code
- designer un flow qui ressemble a du conseil prescriptif
- laisser des termes ambigus ou trop agressifs
```

### 13.5 Prompt review / audit

```text
Audit this change in code review mode.

Priorite absolue:
- bugs runtime
- regressions
- doubles sources de verite
- side effects paralleles
- tests manquants sur les joints
- claims "done" non prouves

Ne te contente pas des services isoles.
Cherche les chemins reels:
- UI -> navigation -> payload -> screen -> return -> handler -> store

Reponds avec:
1. Findings ordonnes par severite
2. Ce qui est confirme correct
3. Verification effectuee
4. Verdict honnete
```

### 13.6 Prompt auto-audit obligatoire

```text
Avant de commit, fais ton auto-audit.

Liste explicitement:
- le bug le plus probable encore present
- le joint le moins prouve
- le fallback le plus risque
- toute hypothese non demontree
- si cette etape est vraiment committable ou non

Si tu ne peux pas defendre le patch honnetement, ne commit pas.
```

### 13.7 Prompt implementation anti-bugs

```text
Mission:
Fermer ce chantier proprement, sans creer de dette ni laisser de bug de joint d'integration.

Tu dois travailler comme un engineer senior de production, pas comme un generateur de patchs.

Obligations:
- identifier la source de verite avant tout changement
- lister les callsites et consommateurs avant implementation
- corriger le chemin canonique d'abord
- verifier explicitement les fallbacks et side effects legacy
- ajouter ou ajuster les tests au niveau du joint reel
- faire un auto-audit avant de declarer l'etape terminee

Interdictions:
- corriger seulement un service si le bug est dans le runtime path
- laisser une double source de verite
- laisser un fallback silencieux non verifie
- declarer “done” sans preuve du flow complet
- melanger plusieurs chantiers non necessaires dans la meme PR

Format de travail:
1. Reformule le probleme exact
2. Identifie la source de verite
3. Liste les fichiers et callsites a verifier
4. Implemente le minimum necessaire
5. Lance analyze + tests cibles + test du joint principal
6. Fais un auto-audit:
   - bugs possibles restants
   - hypotheses faites
   - ce qui n'a pas ete prouve
   - pourquoi le patch reste acceptable ou non

Definition of done:
- le chemin canonique fonctionne
- les fallbacks pertinents sont verifies
- aucun side effect legacy parallele non voulu
- les tests couvrent le joint critique
- les residus sont explicitement listes
```

### 13.8 Prompt chantier 1 - Achat logement

```text
Chantier: rendre le parcours flagship "Acheter sans se pieger" exceptionnel.

Objectif produit:
l'utilisateur entre avec une intention logement et vit un parcours de bout en bout:
- accessibilite
- EPL / fonds propres
- fiscalite retrait
- resume clair
- delta visible
- prochaine etape credible

A livrer:
- sequence coach -> logement / accessibilite -> EPL -> fiscalite retrait -> resume
- Tier A propre sur les ecrans du parcours
- bouton Continuer reel
- SequenceProgressCard utile
- stepOutputs/prefill propres
- resume final comprehensible
- au moins un test d'integration runtime sur le parcours

Definition of done:
- parcours demo A a Z fonctionne
- pas de double consommation
- pas de side effects legacy paralleles
- delta visible apres chaque etape
- analytics de parcours presents
```

### 13.9 Prompt chantier 2 - Dette / leasing / budget sous tension

```text
Chantier: construire le parcours flagship "Sortir d'une tension financiere".

Objectif produit:
Mint doit aider un utilisateur en douleur reelle, pas seulement lui montrer un score.

Parcours cible:
- diagnostic tension
- dette / leasing / charges fixes
- ratio et risque
- arbitrage realisable
- plan de desencombrement
- prochaine action unique

Ce que tu dois concevoir et implementer:
- entree coach centree douleur
- route vers les bons ecrans existants ou nouveaux minimums necessaires
- logique de parcours guide
- wording non jugeant, non anxiogene, tres clair
- avant/apres visible:
  - charge mensuelle
  - marge restante
  - horizon de sortie
- CTA simples et progressifs

Regles:
- ne pas transformer ca en simple simulateur de dette
- ne pas diluer avec trop de choix
- montrer un plan realiste, pas “optimal”
- si leasing est traite, le faire comme un probleme de tension et d'engagement, pas comme un objet isole

Definition of done:
- un utilisateur sous tension comprend en 60 secondes sa situation
- voit un plan concret
- voit ce qui change s'il agit
- peut revenir plus tard et retrouver son parcours
```

### 13.10 Prompt chantier 3 - Retraite / pre-retraite / decaissement

```text
Chantier: rendre le parcours flagship "Preparer sa retraite sans angle mort" irreprochable.

Objectif produit:
passer d'outils isoles a un vrai parcours de decision.

Le parcours doit couvrir:
- niveau de revenu retraite attendu
- gaps et confiance
- leviers disponibles (3a, rachat LPP, decaissement, EPL si pertinent)
- arbitrages lisibles
- resume final en francais simple

Priorites UX:
- pas de jargon inutile
- pas de chiffres ultra-precis si confiance faible
- toujours montrer:
  - ce qu'on sait
  - ce qu'on estime
  - ce qui ameliorerait la precision

A livrer:
- sequence guidee retraite / pre-retraite
- scan LPP integre comme accelerateur de precision
- delta visible avant/apres scan ou simulation
- message coach qui explique le changement

Definition of done:
- Mint donne une sensation de maitrise, pas de confusion
- le parcours est utilisable pour 45+, 55+, 65+
- la confiance gouverne le type de message
```

### 13.11 Prompt chantier 4 - Scan -> delta visible

```text
Chantier: transformer le scan documentaire en moment de verite.

Objectif:
quand l'utilisateur scanne un document, il doit immediatement ressentir:
- ce qui a ete compris
- ce qui a change
- pourquoi c'est important

Boucle a livrer:
- coach recommande le meilleur document via EVI
- user scanne
- OCR extrait
- profil enrichi
- projections / confiance recalculees
- delta visible dans le chat + Aujourd'hui + Dossier

A montrer:
- +X points de confiance
- projection plus precise
- nouvelle prochaine etape

Regles:
- pas de wording generique
- pas de simple “scan reussi”
- toujours verbaliser l'impact metier

Definition of done:
- le scan devient un moteur de conversion, pas une fonction utilitaire
```

### 13.12 Prompt chantier 5 - Ce qui a change

```text
Chantier: rendre Mint vivant entre deux sessions.

Objectif:
l'utilisateur qui revient doit voir en quelques secondes:
- ce qui a change
- pourquoi ca a change
- ce qu'il peut faire maintenant

A livrer:
- section "Depuis ta derniere visite"
- Pulse: avant/apres visible
- Dossier: historique de parcours et enrichissements
- coach: message bref expliquant le delta

Exemples:
- confiance +12
- projection retraite resserree
- nouvelle etape debloquee
- budget ou cap modifie

Definition of done:
- chaque enrichissement important laisse une trace visible
- Mint ressemble a un film, pas a une photo
```

### 13.13 Prompt chantier 6 - OS de cohortes

```text
Chantier: rendre l'experience reellement adaptee aux cohortes Mint, de 18 a 99 ans.

Ne raisonne pas seulement par age.
Utilise la matrice:
- phase de vie
- structure de foyer
- statut de travail
- stress principal
- confiance des donnees

Travail demande:
- formaliser les cohortes prioritaires
- definir pour chacune:
  - le cap principal
  - les parcours prioritaires
  - le ton
  - les CTA
  - les ecrans a privilegier
- brancher cette logique dans le coach, Aujourd'hui, et les next steps

Definition of done:
- un 22 ans, un couple de 38 ans avec projet immo, un independant de 47 ans, un pre-retraite de 59 ans et un retraite de 72 ans n'ont pas l'impression d'utiliser la meme app generique
```

### 13.14 Prompt chantier 7 - Hardening production

```text
Chantier: rendre les parcours flagship launch-ready.

A livrer:
- observabilite minimale:
  - erreurs coach
  - erreurs OCR
  - erreurs sequence
  - latence provider
  - completion rates parcours
- tests runtime:
  - CoachChatScreen
  - RouteSuggestionCard
  - GoRouter.extra
  - ScreenCompletionTracker
  - Tier A / Tier B
- audit des side effects
- audit des fallbacks
- audit de non-divergence mobile/backend

Definition of done:
- les parcours critiques sont mesurables
- les erreurs sont visibles
- les regressions critiques cassent des tests
```

---

## 14. Regles de qualite pour eviter un maximum de bugs

Les prompts doivent toujours forcer ces verifications:

1. source de verite
2. callsites
3. chemin canonique
4. fallbacks
5. side effects legacy
6. joint runtime
7. auto-audit

Les bugs les plus frequents dans MINT viennent de:
- patch local alors que le bug est dans le runtime path
- tests service sans preuve de joint
- fallback encore vivant en parallele
- code “done” alors qu'un flow critique n'est pas prouve
- seconde verite introduite sans l'assumer

---

## 15. Checklists finales

### 15.1 Checklist Team Lead

- [ ] Le chantier correspond a une douleur majeure ou un parcours prioritaire
- [ ] La source de verite est claire
- [ ] Le contrat backend/mobile est coherent
- [ ] Le chemin canonique est explicite
- [ ] Les fallbacks sont verifies
- [ ] L'agent a fait un auto-audit honnete
- [ ] Les residus sont listes
- [ ] La PR ne melange pas des sujets inutiles

### 15.2 Checklist Implementation

- [ ] J'ai liste les callsites
- [ ] J'ai corrige le bon endroit
- [ ] J'ai verifie les side effects legacy
- [ ] J'ai teste le joint principal
- [ ] Je sais ce qui reste non prouve

### 15.3 Checklist Produit

- [ ] L'utilisateur comprend sa situation plus vite
- [ ] Une prochaine etape est claire
- [ ] Quelque chose change visiblement
- [ ] Le langage n'est pas jargonneux
- [ ] Le parcours parait vivant, pas bureaucratique

---

## 16. Verdict strategique

MINT n'a plus besoin prioritairement de plus de profondeur.

MINT a besoin de transformer la profondeur deja la en:
- parcours impeccables
- moments de clarte
- deltas visibles
- experiences adaptees aux cohortes

Le bon cap n'est pas:
- plus d'outils
- plus de coverage
- plus de sophistication abstraite

Le bon cap est:

**faire passer MINT d'un systeme riche a un systeme transformant.**

