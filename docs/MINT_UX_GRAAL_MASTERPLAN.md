# MINT UX Graal Masterplan

> Statut: document maître produit / UX / visual / voice
> Horizon: 2026-2027
> Portée: 109 surfaces actives MINT (`105 *_screen.dart` + `4` shell/tabs)
> Compagnons détaillés: `DESIGN_SYSTEM.md`, `NAVIGATION_GRAAL_V10.md`, `VOICE_SYSTEM.md`, `BLUEPRINT_COACH_AI_LAYER.md`, `CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md`
> Lire aussi: `DOCUMENTATION_OPERATING_SYSTEM.md`

---

## 1. But du document

Hiérarchie documentaire:
- `rules.md`
- `CLAUDE.md`
- ce document
- `DOCUMENTATION_OPERATING_SYSTEM.md`
- `DESIGN_SYSTEM.md`, `VOICE_SYSTEM.md`, `MINT_CAP_ENGINE_SPEC.md`, `MINT_SCREEN_BOARD_101.md`
- `NAVIGATION_GRAAL_V10.md`, `BLUEPRINT_COACH_AI_LAYER.md`
- `VISION_UNIFIEE_V1.md` comme archive stratégique

Ce document existe pour éviter que MINT avance sur 5 rails séparés:
- navigation
- voix
- design visuel
- coach IA
- refonte écran par écran

La thèse ici est simple:

**MINT ne doit plus être une collection d'outils.**

**MINT doit devenir un système vivant qui aide à comprendre, prioriser, agir, puis montre ce qui a changé.**

Formule produit:
- `Comprendre -> Agir`

Formule de marque:
- `Les chiffres -> Les leviers`

Ce document couvre:
- la thèse produit
- la boucle coeur
- la navigation cible
- la direction visuelle finale
- les templates maîtres
- la séquence d'implémentation

Ce document ne couvre pas:
- les tokens détaillés
- les règles de microcopy exhaustives
- la spec détaillée du CapEngine
- le board écran par écran exhaustif

Règle d'usage:
- si un agent ne lit qu'un seul document stratégique après `CLAUDE.md`, c'est celui-ci.

---

## 2. Ce que MINT doit devenir

### Ce que MINT ne doit pas être
- Une app finance en mode dashboard.
- Une app `chat-only`.
- Une taxonomie produit organisée selon le codebase.
- Une IA qui parle beaucoup mais ne change rien.
- Une belle UI froide, premium mais vide.

### Ce que MINT doit être
- Un compagnon financier suisse, calme, intelligent, incarné.
- Une expérience `plan-first, coach-orchestrated`.
- Une interface où la donnée nourrit des `insights`, les insights nourrissent un `plan`, et le plan nourrit l'action.

### Ancrages externes non négociables

MINT doit rester aligné avec 4 réalités externes:
- **Suisse / LSFin / FINMA** : information financière éducative, jamais conseil personnalisé prescriptif, jamais mouvement d'argent.
- **3 piliers suisses** : AVS/LPP/3a restent le cœur de différenciation et doivent rester juridiquement et pédagogiquement irréprochables.
- **Réalisme actuariel** : les projections doivent montrer hypothèses, confiance et incertitude, jamais une certitude déguisée.
- **UX mobile contemporaine** : navigation simple, hiérarchie radicale, conversation assistée par UI, jamais catalogue opaque ou cockpit.

Traduction produit:
- MINT peut expliquer, prioriser, simuler, comparer, contextualiser.
- MINT ne doit pas recommander d'acheter, vendre, souscrire, verser ou arbitrer à la place de l'utilisateur.

### Top 10 Suisse — priorités produit avant le long tail

Tous les événements ne doivent pas être traités à égalité. Avant d'élargir davantage, MINT doit être excellent sur les situations les plus fréquentes, les plus coûteuses, les plus émotionnelles et les plus structurantes en Suisse.

Top 10 à rendre irréprochables:
1. premier emploi / entrée dans la vie active
2. changement d'emploi / comparaison d'offre
3. chômage / perte d'emploi
4. invalidité / protection
5. concubinage / mariage
6. naissance
7. achat logement / hypothèque
8. dette / budget sous tension
9. indépendance
10. frontalier
11. retraite / décaissement / succession

Règle:
- ces situations coeur doivent définir le standard MINT;
- le reste du catalogue doit s'aligner sur leur niveau, pas l'inverse.

Précision:
- MINT parle de `Top 10 Suisse` comme noyau stratégique;
- en pratique, ce noyau couvre `11` situations parce que `retraite / décaissement / succession` forment un même bloc de décision et que `invalidité / protection` et `frontalier` doivent rester first-class.
- l'important n'est pas le chiffre marketing, mais la discipline de priorisation.

### Références de direction
- Chloé: luxe discret
- Aesop: respiration, matière, silence
- Wise: clarté fonctionnelle
- Cleo Autopilot: sentiment de système vivant
- Apple: calme, profondeur, retenue

### Ce qu'on prend chez Cleo
- la sensation de pilotage
- le passage `advice -> action`
- la logique `insights -> daily plan -> memory`
- l'atmosphère douce et désirable

### Ce qu'on refuse chez Cleo
- le ton trop consumer US
- le côté trop gimmick / cheeky
- l'impression que le produit agit à la place de l'utilisateur
- la promesse trop agressive d'autopilot

Traduction MINT:
- pas `Autopilot`
- plutôt `Cap`, `Plan vivant`, `Pilotage`

Recommandation:
- user-facing: `Cap du jour`
- nom interne système: `Plan Layer`

---

## 3. Architecture produit cible

### Boucle cœur

```text
Dossier
-> génère
Insights
-> nourrissent
Cap du jour
-> ouvre
Coach / Flow structuré
-> déclenche
Action
-> met à jour
Mémoire + Confiance + Projections
-> retourne dans Aujourd'hui
```

### État actuel (2026-03-21)

Ce que MINT possède et qui est fonctionnel en production:
- `Profile / Dossier data` — profil complet, couple, documents
- `ForecasterService` — projections retraite multi-scénarios
- `PulseHeroEngine` — moteur de données pour Aujourd'hui
- `ResponseCardService` — cards inline dans le chat
- `CoachChatScreen` — Claude API live, tool calling, compliance guard
- `ConversationMemoryService` — persistance cross-session (historique textuel)
- `RAG` — `RagRetrievalService` keyword-based sur 3 pools (concepts, cantons, FAQ)
- `dataTimestamps` — horodatage par champ de profil
- `EnhancedConfidenceService` — 4 axes, score 0-100%
- `CapEngine` (12 règles heuristiques) + `CapMemoryStore` (persistance SharedPreferences)
- `GoalTrackerService` — suivi objectif actif, boost x1.3 sur caps alignés
- `ActionSuccess` bottom sheet — feedback action + impact + next step
- `LifecycleDetector` + `LifecyclePhase` (7 phases) + `LifecycleContentService`
- `ScreenRegistry` (109 surfaces, intentTag/behavior/requiredFields)
- `ReadinessGate` (3 niveaux: Ready/Partial/Blocked)
- `RoutePlanner` — service de routage chat → écran
- `ProactiveTriggerService` (7 triggers: lifecycle change, weekly recap, goal milestone, seasonal, inactivity, confidence improvement, new cap)
- `RegionalVoiceService` (26 cantons — flavor texte pour system prompt, pas audio)
- `JitaiNudgeService` — triggers contextuels (paie, délai fiscal, anniversaire)
- `CantonalBenchmarkService` + `CantonalBenchmarkScreen`
- `WeeklyRecapService` + `WeeklyRecapScreen`
- `MultiLlmService` — Claude primary + GPT-4o fallback (config)
- `VoiceService` — structure stub, pas de STT/TTS réel intégré

Ce qui reste à construire ou finaliser:
- `ReturnContract` / `ScreenReturn` model — contrat de retour écran → coach (non confirmé en code)
- Vector store cross-session — `ConversationMemoryService` gère l'historique, pas le recall sémantique
- RAG v2 embeddings — retrieval keyword fonctionne; embeddings vectoriels non implémentés
- 13e rente AVS dans `AvsCalculator` — non encore implémenté
- STT/TTS réel dans `VoiceService` — stub uniquement
- Expert tier (advisor matching, dossier prep humain)
- Agent autonome (form pre-fill, lettre caisse de pension)

### Objet central à construire

`Cap du jour` contient au maximum:
- 1 priorité
- 1 pourquoi maintenant
- 1 action principale
- 1 impact attendu
- 1 niveau de confiance optionnel

Exemple:
- priorité: `Ta retraite pince encore.`
- pourquoi maintenant: `Cette année, un rachat LPP ou un 3a change déjà la trajectoire.`
- action: `Simuler un rachat`
- impact: `+4 à +7 pts`

### Règle système

Chaque action dans MINT doit pouvoir produire:
- une mise à jour visible
- un nouveau score de confiance
- un nouveau levier
- un retour dans `Aujourd'hui`

Sans cela, MINT reste un calculateur.

### Règle de progression

MINT ne montre pas d'abord l'état du système.

MINT montre d'abord l'avancement vers l'objectif actuel de la personne.

La progression doit donc être `goal-centric`, pas seulement `dashboard-centric` ou `retraite-centric`.

Selon le contexte, ce but peut être:
- sortir d'une dette,
- retrouver de la marge,
- préparer une naissance,
- absorber un chômage,
- clarifier une succession,
- financer un logement,
- renforcer la retraite,
- ou simplement compléter un dossier encore trop flou.

`Aujourd'hui` doit donc montrer en priorité:
- où l'utilisateur en est par rapport à son sujet du moment,
- ce qui a progressé,
- ce qui bloque encore,
- quel est le prochain levier.

Règle couple:
- dans les sujets où le ménage change réellement la décision, le couple n'est pas un simple mode d'affichage;
- le couple devient une unité de décision à part entière.
- les caps peuvent donc être individuels ou ménage, selon l'impact réel sur AVS, LPP, fiscalité, logement et succession.

### Orchestration chat-to-screen

> Spec complète : `CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md` (source de vérité pour cette couche).

Le coach peut ouvrir des surfaces MINT depuis le chat. Ce routage ne doit pas être ad hoc.

**Formule d'orchestration** :
```text
message utilisateur
  → IntentResolver (LLM)
  → RoutePlanner (readiness check)
  → meilleure surface (ou réponse inline)
  → ReturnContract
  → boucle vivante
```

**5 composants de la couche** :
- `RoutePlanner` — décide quelle action prendre selon l'intention et la readiness. Implémenté comme tool Claude `route_to_screen`.
- `ScreenRegistry` — carte officielle des 109 surfaces avec `intentTag`, `behavior`, `requiredFields`, `fallbackRoute`.
- `ReadinessGate` — vérifie si les données utilisateur suffisent avant d'ouvrir une surface (3 niveaux : Ready / Partial / Blocked).
- `ReturnContract` — contrat de retour standardisé quand l'utilisateur revient d'un écran vers le coach. Nourrit `CapMemory`.

**5 comportements de surface** (chaque surface appartient à exactement l'un d'eux) :
- `A` — Direct Answer : réponse inline dans le chat (widget, fait, comparaison rapide)
- `B` — Decision Canvas : ouvrir un écran de simulation/arbitrage
- `C` — Roadmap Flow : ouvrir un parcours de vie
- `D` — Capture / Utility : donnée manquante ou document à fournir
- `E` — Conversation pure : pas de surface, texte + éventuellement un fait éducatif

**Principe fondamental** : le LLM décide de l'intention, le code décide du routage. Le LLM ne retourne jamais un `context.push('/route')` brut.

**Plan d'implémentation** : Phase 1 `ScreenRegistry + ReadinessGate` (S57) → Phase 2 `RoutePlanner + route_to_screen + ReturnContract` (S58).

---

## 4. Navigation cible

### Shell final

```text
[Aujourd'hui] [Coach] [Explorer] [Dossier]
```

### Rôle des 4 piliers

- `Aujourd'hui`
  point de vérité du moment

- `Coach`
  compréhension, clarification, orchestration

- `Explorer`
  navigation autonome par grands parcours

- `Dossier`
  données, documents, consentements, connexions, réglages IA

### Capture

`Capture` n'est pas un onglet.

`Capture` est une capacité contextuelle présente dans:
- `Aujourd'hui`
- `Coach`
- `Dossier`

### Explorer: 7 hubs

- Retraite
- Famille
- Travail & Statut
- Logement
- Fiscalité
- Patrimoine & Succession
- Santé & Protection

### Règle d'architecture

- 4 destinations top-level maximum
- pas de FAB global cross-platform
- pas de taxonomie dev visible
- le coach peut ouvrir les flows, mais Explore doit vivre sans lui

---

## 5. Voice et comportement

### La voix MINT

MINT n'est pas une personnalité théâtrale.

MINT est:
- calme
- précis
- fin
- rassurant
- net

### Formules à retenir

- `Comprendre -> Agir`
- `Les chiffres -> Les leviers`

### Règles éditoriales

- commencer par le chiffre ou le fait
- dire peu, mais juste
- éviter le jargon non expliqué
- éviter la fausse urgence
- éviter la célébration artificielle
- finir par une action concrète

### Le coach

Le coach n'est pas le produit.

Le coach est:
- l'agent d'orchestration
- l'interface de clarification
- la couche de personnalisation

Le coach ne remplace pas:
- la preuve
- les écrans structurés
- les flows déterministes

---

## 6. Visual Graal 2027

### Thèse visuelle

MINT doit ressembler à:
- une interface premium
- un objet calme
- un système intelligent

Pas à:
- un back-office
- un cockpit
- une app fintech bruyante

### Image cible

Le produit doit donner l'impression de:
- lumière diffuse
- profondeur douce
- matière éditoriale
- stabilité
- intelligence silencieuse

### Principes visuels

1. L'air est un composant.
2. Un écran = une idée dominante.
3. La data doit être montrée comme progression, pas comme comptabilité.
4. Les couches doivent suggérer l'intelligence, pas la décoration.
5. Le calme prime toujours sur la démonstration.

### Palette directionnelle

Ce ne sont pas des tokens finaux, mais la direction artistique cible:

Règle d'implémentation:
- ces hex sont indicatifs
- en code Flutter, utiliser exclusivement `MintColors.*`
- leur mapping dans `colors.dart` relève d'une phase de convergence palette ultérieure, pas d'un hardcode écran par écran

- `Porcelaine` `#F7F4EE`
- `Craie` `#FCFBF8`
- `Sauge claire` `#D8E4DB`
- `Bleu air` `#CFE2F7`
- `Ardoise` `#3A3D44`
- `Cacao` `#4A2F26`
- `Pêche douce` `#F5C8AE`
- `Corail discret` `#E6855E`

### Règle couleur

- une couleur vive max par écran
- les verts et oranges servent à signaler, pas à décorer
- les neutres doivent porter 80% de l'interface

### Typographie

- Montserrat pour les grands temps forts
- Inter pour le corps
- sentence case partout
- zéro uppercase décoratif
- un chiffre hero doit pouvoir porter l'écran presque seul

### Profondeur

Oui à:
- halos doux
- fonds lumineux
- surfaces superposées
- verre très léger si maîtrisé

Non à:
- glassmorphism démonstratif
- gros blur gadgets
- ombres lourdes
- gradients "startup"

### Motion

- apparition douce
- transitions de couches
- graphes qui se dessinent calmement
- microparallax très léger

Jamais:
- confetti
- bounce gadget
- suranimation

---

## 7. 10 itérations mentales avant la version finale

### V1 — Minimal Finance
Très propre, très blanc, trop générique.

### V2 — Editorial Luxury
Plus beau, plus mode, mais pas encore assez produit.

### V3 — Coach Presence
Le coach devient visible, plus vivant.
Risque: trop dépendre de la copy.

### V4 — Calm Depth
Ajout de profondeur et de couches.
On commence à sentir 2027.

### V5 — Living System
Les écrans montrent enfin des conséquences.
Très important.

### V6 — Roadmap Native
Le plan devient un objet produit.
C'est le premier saut majeur.

### V7 — Data as Atmosphere
La donnée devient narration visuelle.
Plus de souffle, moins de cartes.

### V8 — Utility Discipline
Les écrans utilitaires s'alignent sur 3 primitives.
Nécessaire pour scaler à 109 surfaces actives.

### V9 — Signature MINT
Palette, rythme, ton, profondeur deviennent propres à MINT.

### V10 — Graal
`Plan-first, coach-orchestrated, editorial, atmospheric, radically calm`

**C'est cette version qu'il faut déployer.**

---

## 8. Les 4 templates maîtres

Les surfaces MINT ne doivent pas être designées une par une.

Ils doivent être ramenés à 4 familles maîtresses.

### Correspondance avec `DESIGN_SYSTEM.md`

Pour éviter tout clash documentaire, les catégories A-F du design system se projettent ainsi dans les templates du masterplan:

| DESIGN_SYSTEM | Sens | Template masterplan |
|---|---|---|
| `A` | Hero | `HP` |
| `B` | Simulator | `DC` |
| `C` | Life Event | `RF` |
| `D` | Form | `RF` |
| `E` | Utility | `QU` |
| `F` | List / Hub / Shell | `QU` ou `HY` selon qu'il s'agit d'un écran de contenu ou d'un container/navigation |

Le design system garde les catégories de fabrication.
Le masterplan impose les templates d'expérience à l'échelle produit.

### Template 1 — Hero Plan

Usage:
- Aujourd'hui
- Retirement Dashboard
- Chiffre-Choc
- Budget
- Fiscal comparator hero
- Gender Gap hero
- certains scores et milestones

Structure:
- 1 phrase
- 1 chiffre dominant
- 1 action
- 2 signaux max
- éventuellement 1 impact attendu

### Template 2 — Decision Canvas

Usage:
- Rente vs Capital
- Rachat LPP
- 3a
- Real Return
- Allocation
- LAMal
- Job Comparison
- Hypothèque / affordability

Structure:
- inputs compacts
- résultat dominant
- comparaison avant/après ou A/B
- hypothèses visibles
- disclaimer + sources

### Template 3 — Roadmap Flow

Usage:
- Mariage
- Naissance
- Divorce
- Chômage
- Expat
- Frontalier
- Déménagement
- Succession
- First Job
- Indépendant

Structure:
- impact hero
- 2 à 4 étapes ou tabs
- checklist d'actions
- insert éducatif
- prochaine étape

### Template 4 — Quiet Utility

Usage:
- Profile
- Documents
- Consentements
- Settings
- History
- Open banking
- Admin
- listes et hubs

Structure:
- app bar blanche simple
- section headers sobres
- cartes uniformes
- recherche / filtre si nécessaire
- aucune dramaturgie inutile

---

## 9. Règles de composition

### Règles universelles

- 1 point focal
- 1 CTA primaire
- 1 rythme vertical lisible
- 1 accent couleur dominant maximum

### Ce qu'on retire

- walls of sliders
- grilles 2x2 décoratives
- badges parasites
- sous-titres uppercase
- cartes glossy
- layers inutiles

### Ce qu'on ajoute

- respiration
- hiérarchie radicale
- densité plus faible
- profondeur légère
- comparaison plus lisible

### Reframing rule

Aucun chiffre défavorable ne doit apparaître seul.

Il doit être accompagné:
- d'un levier actionnable,
- d'un contexte qui explique,
- ou d'un horizon atteignable.

Ne jamais "positiver" un vrai risque. Montrer la réalité, puis le chemin.

Clause d'honnêteté:
- si aucun levier réaliste n'existe à horizon utile, MINT le dit avec tact;
- dans ce cas, MINT montre les limites de manœuvre, les hypothèses et, si nécessaire, oriente vers un spécialiste humain;
- le reframing ne doit jamais fabriquer un faux espoir.

Règle LPP:
- le minimum légal `6.8%` ne doit jamais être présenté comme un taux global implicite sur tout le capital LPP;
- MINT doit distinguer le minimum légal sur la part obligatoire et l'estimation de caisse ou enveloppante sur l'ensemble du capital;
- sans certificat LPP, une projection retraite détaillée reste une fourchette indicative, pas une estimation robuste.

### Proof after narrative

L'ordre de lecture d'un écran MINT est:
1. narrative d'abord (le chiffre, le levier, l'insight)
2. preuve accessible immédiatement (source, hypothèse, données brutes)
3. action ensuite (CTA, flow, capture)

La preuve ne doit pas être cachée. Elle doit être disponible sans effort, mais jamais en première lecture.
C'est particulièrement important pour un public suisse qui attend de la transparence.

### Graphes

Le chart montré dans la vidéo est une leçon utile:
- 3 lignes max
- 12 mois max
- légende simple
- zéro jargon
- axe minimal

Application MINT:
- budget
- revenus / dépenses
- retraite
- progression de plan
- confidence / précision

---

## 10. Design du Plan Layer

Spec détaillée:
- voir `MINT_CAP_ENGINE_SPEC.md` pour les règles de recalcul, de priorisation, de durée de vie et d'interface Dart

### Objectif

Faire apparaître entre `insight` et `screen spécialisé` une couche simple qui dit:
- ce qu'il faut faire
- pourquoi
- avec quel effet

### Nom recommandé

- user-facing: `Cap du jour`
- alternatives: `Plan du jour`, `Levier du moment`

### Contenu

- `headline`
- `why_now`
- `cta`
- `expected_impact`
- `blocking_data` optionnel

### États

- `Compléter`
- `Corriger`
- `Optimiser`
- `Sécuriser`
- `Préparer`

### Placement

- hero dans `Aujourd'hui`
- rappel dans `Coach`
- retour dans `Dossier` si blocage data

### Règle d'or

Le plan ne doit jamais être une to-do list complexe.

Le plan doit être:
- lisible en 3 secondes
- priorisé
- actionnable immédiatement

---

## 11. Traduction des écrans MINT

## 11.1 Tier 1

- `Aujourd'hui / Pulse` -> `Hero Plan`
- `Quick Start` -> `Roadmap Flow` en mode onboarding
- `Chiffre-Choc` -> `Hero Plan`
- `Profile` -> `Quiet Utility`
- `Coach Chat` -> hybride `Coach Orchestrator`
- `Budget` -> `Hero Plan` + `Decision Canvas`

## 11.2 Tier 2

- `Retirement Dashboard` -> `Hero Plan`
- `Rente vs Capital` -> `Decision Canvas`
- `Rachat LPP` -> `Decision Canvas`
- `Staggered Withdrawal` -> `Decision Canvas`
- `Décaissement` -> `Decision Canvas`
- `Succession` -> `Roadmap Flow`

## 11.3 Tier 3

- `Mariage` -> `Roadmap Flow`
- `Naissance` -> `Roadmap Flow`
- `Divorce` -> `Roadmap Flow`
- `Chômage` -> `Roadmap Flow`
- `Affordability` -> `Decision Canvas`
- `Déménagement cantonal` -> `Roadmap Flow`

## 11.4 Tier 4

- `Fiscal Comparator` -> `Decision Canvas`
- `Simulator 3a` -> `Decision Canvas`
- `Real Return` -> `Decision Canvas`
- `Allocation Annuelle` -> `Decision Canvas`
- `Indépendant` -> `Roadmap Flow`
- `Expatrié` -> `Roadmap Flow`

## 11.5 Tier 5

- `Frontalier` -> `Roadmap Flow`
- `Premier Emploi` -> `Roadmap Flow`
- `LAMal Franchise` -> `Decision Canvas`
- `Job Comparison` -> `Decision Canvas`
- `Gender Gap` -> `Hero Plan` + `Roadmap Flow`
- `Achievements` -> `Hero Plan` léger / `Quiet Utility`
- `Documents` -> `Quiet Utility`

## 11.6 Tier 6 — restant

### Retraite / patrimoine / fiscalité

- `Libre Passage` -> `Decision Canvas`
- `Pilier 3a` -> `Decision Canvas`
- `3a Comparator` -> `Decision Canvas`
- `3a Retroactif` -> `Decision Canvas`
- `Hypothèque` -> `Decision Canvas`
- `Amortization` -> `Decision Canvas`
- `EPL Combined` -> `Decision Canvas`
- `Imputed Rental` -> `Decision Canvas`
- `SARON vs Fixed` -> `Decision Canvas`
- `Arbitrage Bilan` -> `Decision Canvas`
- `Location vs Propriété` -> `Decision Canvas`
- `Donation` -> `Roadmap Flow`
- `Housing Sale` -> `Roadmap Flow`

### Travail / statut / protection

- `Invalidité` -> `Roadmap Flow`
- `Disability Insurance` -> `Roadmap Flow`
- `Disability Self Employed` -> `Roadmap Flow`
- `Coverage Check` -> `Decision Canvas`
- `IJM` -> `Decision Canvas`
- `Dividende vs Salaire` -> `Decision Canvas`
- `AVS indépendant` -> `Decision Canvas`
- `3a indépendant` -> `Decision Canvas`
- `LPP volontaire` -> `Decision Canvas`

### Dette / crédit / budget élargi

- `Debt Ratio` -> `Decision Canvas`
- `Debt Repayment` -> `Decision Canvas`
- `Debt Help Resources` -> `Quiet Utility` spécialisé
- `Debt Risk Check` -> `Decision Canvas`
- `Consumer Credit` -> `Decision Canvas`
- `Leasing` -> `Decision Canvas`

### Famille / relation / ménage

- `Concubinage` -> `Roadmap Flow`
- `Couple` -> `Quiet Utility` + `Roadmap Flow`
- `Accept Invitation` -> `Roadmap Flow`

### Éducation / contenu

- `Education Hub` -> `Quiet Utility`
- `Theme Detail` -> `Quiet Utility`
- `Weekly recap` -> `Hero Plan` futur, hors codebase actuel
- `Cantonal benchmark` -> `Decision Canvas`
- `Confidence dashboard` -> `Quiet Utility`
- `Timeline` -> `Quiet Utility`
- `Portfolio` -> `Quiet Utility`

### Dossier / réglages / IA

- `Consent Dashboard` -> `Quiet Utility`
- `BYOK Settings` -> `Quiet Utility`
- `SLM Settings` -> `Quiet Utility`
- `Conversation History` -> `Quiet Utility`
- `Open Banking Hub` -> `Quiet Utility`
- `Transactions` -> `Quiet Utility`
- `OB Consents` -> `Quiet Utility`
- `Bank Import` -> `Quiet Utility`

### Premium / billing

Les surfaces premium ou paywallées gardent la même grammaire que le reste de MINT.

Règle:
- un écran premium ne devient jamais un dump de données
- `Financial Report V2` reste un `Hero Plan`
- la valeur premium vient de la clarté, de la synthèse et du levier, pas d'une densité plus élevée

### Scan / capture

- `Document Scan` -> `Roadmap Flow`
- `AVS Guide` -> `Roadmap Flow`
- `Scan Review` -> `Roadmap Flow`
- `Scan Impact` -> `Hero Plan`
- `Data Block Enrichment` -> `Roadmap Flow`

### Auth / admin

- `Login` -> `Quiet Utility`
- `Register` -> `Quiet Utility`
- `Forgot Password` -> `Quiet Utility`
- `Verify Email` -> `Quiet Utility`
- `Admin Observability` -> `Quiet Utility`
- `Admin Analytics` -> `Quiet Utility`

---

## 12. Règles spécifiques par famille

### Hero Plan
- un chiffre dominant
- pas de ResponseCard legacy
- un CTA unique
- narration courte
- ton: projection calme, cap, élan, clarté
- si chiffre défavorable: montrer d'abord la marge à retrouver, puis le levier le plus proche

### Decision Canvas
- inputs compacts
- pas de mur de sliders
- avant/après obligatoire si pertinent
- hypothèses visibles
- ton: simulation nette, factuelle, sans dramatisation

### Roadmap Flow
- tabs ou étapes max 4
- checklist d'actions
- impact concret
- ton: empathie + structure + prochaine étape

### Quiet Utility
- layout normalisé
- peu d'effets
- lisibilité maximale
- ton: neutre, sobre, utilitaire

---

## 13. Séquence d'implémentation recommandée

### Phase 0 — Socle technique (DONE — S52)
- navigation cible 4 tabs / 7 hubs / capture contextuelle
- première vague tokens, i18n, AppBars, voix, conformité
- migration initiale des tiers S52 déjà traités
- nettoyage des patterns les plus legacy

### Phase 1 — Verrouiller la grammaire (DONE — S52)
- refonte `ResponseCardWidget` V2 (3 variantes: chat/sheet/compact)
- création des 4 templates maîtres (HP/DC/RF/QU)
- composant `Cap du jour` (CapCard + CapEngine)

### Phase 2 — Propager le système (DONE — S52)
- migration des 109 écrans + 192 widgets aux tokens MintTextStyles/MintSpacing/MintColors
- 0 GoogleFonts résiduel dans lib/ (hors theme/app.dart)
- nettoyage i18n T6-A (50 clés extraites)
- nettoyage async (document_scan 16 warnings -> 0)

### Phase 3 — Rendre le système vivant (DONE — S52/S53)
- `CapEngine` V1 heuristique (12 règles, scoring multiplicatif, pure function)
- `CapMemory` persistant (lastCapServed, completedActions, abandonedFlows, recentFrictionContext)
- `Goal Selection` : GoalA aligne les caps (boost x1.3 sur caps alignés)
- `Action Success` : bottom sheet feedback (action + impact + next step)
- `Life Events` : 18 événements de vie détectés via profile.familyChange
- Feedback loop : markServed → markCompleted → recompute → nouveau cap

### Phase 4 — Harmonisation finale (DONE — S52)
- `MintMotion` tokens (fast/standard/slow + curveStandard/curveEnter/curveExit)
- suppression `MintGlassCard`, `MintPremiumButton`, `mint_ui_kit.dart`
- 0 hardcoded hex colors dans screens/ et widgets/
- screenshot board des 109 surfaces actives (TODO — non bloquant)

### Phase 5 — Coach vivant + orchestration (DONE — S56/S57)
- `CoachChatScreen` avec Claude API live, tool calling
- `ProactiveTriggerService` (7 triggers proactifs)
- `RegionalVoiceService` (26 cantons, flavor system prompt)
- `RagRetrievalService` (3 pools, citations source)
- `ScreenRegistry` + `ReadinessGate` + `RoutePlanner`
- `LifecycleDetector` (7 phases) + `LifecycleContentService`
- `JitaiNudgeService` + `AdaptiveChallengeService`
- `WeeklyRecapService` + `CantonalBenchmarkService`
- `MultiLlmService` (Claude primary + fallback)

### Phase 6 — Prochaines priorités (PLANNED)
- `ReturnContract` / `ScreenReturn` — compléter le contrat de retour écran → coach
- RAG v2 embeddings — passer du keyword au vectoriel
- 13e rente AVS dans `AvsCalculator`
- STT/TTS réel dans `VoiceService`
- Expert tier (advisor matching)
- Agent autonome form pre-fill (S68)

---

## 14. DOD produit / design

Un écran MINT n'est pas terminé s'il n'est pas:

- visuellement calme
- hiérarchiquement clair
- fidèle à la voix MINT
- cohérent avec sa famille maître
- localisé correctement
- accessible correctement
- relié à une action ou à une progression visible

### Questions DOD obligatoires

1. Quelle est l'idée dominante de cet écran?
2. Quel est son template maître?
3. Quelle action concrète déclenche-t-il?
4. Qu'est-ce qui change après l'action?
5. Le ton est-il MINT?
6. Le screen tient-il en non-FR sans fuite de français?
7. L'écran est-il plus calme qu'avant?

Si une réponse est non, l'écran n'est pas fini.

---

## 15. La phrase qui doit guider tout le chantier

**MINT ne doit pas juste montrer des chiffres.**

**MINT doit transformer les chiffres en leviers, puis les leviers en mouvement visible.**
