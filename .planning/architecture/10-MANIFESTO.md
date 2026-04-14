# MINT Manifesto — L'Histoire et l'Architecture

> **Statut** : Source de vérité pour la reconstruction architecturale 2026-04 / 2026-05.
> **Auteur** : Office-hours co-design avec Julien (2026-04-11)
> **Subordonné à** : `docs/MINT_IDENTITY.md` (mission, doctrine), `docs/VOICE_SYSTEM.md` (voix)
> **Subordonné par** : `11-INVENTAIRE.md` (verdicts screen-by-screen), `12-PLAN-EXECUTION.md` (sprint 3-5 semaines)
> **Read time** : 8 minutes
> **Purpose** : Julien lit ce document une fois et sait exactement quelle histoire MINT raconte, à qui, comment, et quels écrans servent cette histoire.

---

## 1. L'histoire MINT en une phrase

**MINT est l'infrastructure personnelle de données financières du résident suisse — un dossier vivant qui collecte, comprend, et révèle ce que personne n'a intérêt à dire à son propriétaire.**

C'est tout. Ce n'est pas plus complexe que ça. Et c'est ce qui n'existe pas en Suisse.

---

## 1bis. L'image qui rend tout clair : photo vs film

> **MINT n'est pas une photo. MINT est un film.**

Cette image est l'image fondatrice. Elle distingue MINT de tous les acteurs financiers suisses actuels et elle encode toute l'architecture qui suit.

| Acteur | Format | Fréquence | Limite |
|---|---|---|---|
| **VZ Vermögenszentrum** | Photo haute résolution de ta situation financière | 1-2 fois par an, sur rendez-vous payant | Belle photo, mais figée. Entre deux photos, tu te débrouilles seul. |
| **Cleo, neo-banques** | Stories Instagram quotidiennes — drôles, courtes, jetables | Tous les jours | Plein de petits moments, mais aucune histoire qui se construit. Pas de mémoire long-terme. |
| **Apps bancaires** | Dashboard statique de chiffres présents | À chaque ouverture | Tu vois où tu es, jamais où tu vas. Pas de scénario. |
| **MINT** | **Film de ta vie financière** | En continu | Chaque scène compte, chaque scène est connectée à la précédente et à la suivante. Le scénario se construit avec toi. Le co-réalisateur (MINT) se souvient de tout, voit où ça va, te prévient des plot twists qui approchent, et t'aide à écrire la fin que tu veux. |

**Conséquences architecturales directes de "MINT est un film" :**

1. **Le dossier (RAG personnel) est le scénario en train de s'écrire.** Pas un coffre-fort statique. Une histoire qui se construit chaque fois que l'utilisateur dépose un document, connecte un compte, mentionne un événement, prend une décision.

2. **Les snapshots mensuels sont les scènes du film.** Chaque snapshot est une image arrêtée dans la séquence. Ensemble, ils forment le mouvement.

3. **L'anomaly_detection_service est le radar narratif.** Quand quelque chose cloche dans la séquence (dépense anormale, gap qui se creuse, deadline qui approche), MINT le voit comme un scénariste voit un plot hole.

4. **Les 18 événements de vie sont les actes du film.** Premier emploi = exposition. Mariage, achats, naissance = développement. Crises, divorces, deuils = retournements. Retraite = troisième acte. Chacun déclenche une analyse contextuelle, pas un screen isolé.

5. **Les plans pluriannuels sont les arcs narratifs.** *"Acheter un appartement dans 3 ans"* est un arc qui se déroule en 36 chapitres mensuels, avec des points de contrôle, des révisions, des adaptations.

6. **Le coach Claude est le co-réalisateur.** Il connaît le scénario, il connaît le passé, il anticipe les prochaines scènes, il alerte sur les angles morts. Il ne décide pas (l'utilisateur reste protagoniste), il accompagne.

7. **Tout écran qui n'est pas une scène du film n'a pas sa place.** Les écrans-catalogue, les écrans-leçon, les écrans-dashboard isolés, les écrans-achievement — tout ça appartient à un autre médium. Pas au film.

**Compatibilité avec la métaphore "bête vivante" :** les deux sont le même produit vu sous deux angles. La bête vivante est ce que MINT EST (un organisme avec un métabolisme, une mémoire, une voix). Le film est ce que MINT FAIT (raconter, scène par scène, l'histoire financière de son utilisateur dans le temps). Les deux ensemble : **MINT est l'organisme vivant qui filme et co-réalise ta vie financière.**

---

## 2. La cible : profondeur VZ + fréquence Cleo + vision long-terme

MINT n'a pas un seul concurrent. MINT a **trois métiers à la fois**, qu'aucun acteur suisse actuel ne combine :

### 2.1 — Profondeur de VZ Vermögenszentrum (la cible principale)

VZ est l'institution suisse de référence en planification financière personnelle. MINT démocratise ce qu'ils font :

| | VZ Vermögenszentrum | MINT |
|---|---|---|
| **Modèle de revenu** | Forfait planification (CHF 2'000-5'000) + AUM récurrent (0.5-1%/an sur les actifs gérés) | Subscription mensuelle (~CHF 15) ou freemium |
| **Biais structurel** | Capital plutôt que rente (le capital devient AUM, la rente non) | Aucun — pas d'AUM, pas de produits, pas de commissions, read-only par architecture |
| **Accessibilité** | Dès CHF 100k+ d'actifs, payant | Toute personne avec un téléphone et un document |
| **Profondeur** | Excellent — décennies d'expertise suisse | Tous les calculateurs critiques déjà construits, certifiés contre les barèmes officiels |
| **Fréquence d'interaction** | 1-2 entretiens par an | Présence quotidienne possible |
| **Personnalisation** | Forte — entretien d'1h, dossier monté | Forte — RAG personnel construit en continu |
| **Neutralité** | Compromise (intérêt commercial AUM) | Garantie par construction |
| **Vision temporelle** | Snapshot ponctuel + plan d'épargne | Plan vivant qui se met à jour à chaque changement |

**Pitch VZ-side en une phrase** : *"VZ te facture CHF 3'000 pour te dire ce que MINT te dit gratuitement, sans biais, sur ton téléphone — et MINT continue à te le dire chaque mois."*

### 2.2 — Fréquence de Cleo (la dimension quotidienne)

Cleo (UK) a démontré qu'une app finance peut être présente au quotidien — pas une visite occasionnelle. MINT prend cette dimension MAIS :

| | Cleo | MINT |
|---|---|---|
| **Ton** | Sass, roast, humour | Calme, précis, fin, rassurant, net (jamais sass) |
| **Cible du tranchant** | L'utilisateur (*"damn you spent £47 at Pret"*) | L'industrie (*"ton courtier a touché 1.8× ta prime annuelle en commission"*) |
| **Modèle de revenu** | Affiliations + pubs financières | Subscription, pas de commissions |
| **Profondeur** | Surface (catégorisation des dépenses, conseils génériques) | Profonde (calculateurs suisses certifiés, compliance LSFin, archetypes) |
| **Jurisdiction** | UK (FCA) | Suisse (LSFin, FINMA, nLPD) |
| **Géo** | 18-25 ans, anglophones | 18-99 ans, suisses, FR/DE/IT |
| **Continuité** | Engagement-driven (pour les pubs) | Outcome-driven (pour les bonnes décisions évitées) |

**Pitch Cleo-side en une phrase** : *"Cleo te roaste pour te faire rire et te garder dans l'app. MINT roaste l'industrie qui t'arnaque pour te garder dans tes finances."*

### 2.3 — Vision long-terme et pilotage de projets de vie

C'est la dimension qu'aucun acteur ne couvre vraiment aujourd'hui. **MINT pilote tes projets de vie sur 1-30 ans avec un plan vivant qui se met à jour à chaque nouvelle donnée.**

Exemples concrets de projets que MINT pilote :

- **Achat immobilier dans 3 ans** : *"Tu épargnes 800 CHF/mois, tu vises CHF 80'000 de fonds propres. Avec ton 2e pilier disponible en EPL, tu seras à CHF 95'000 dans 3 ans. Voici la fourchette de prix d'achat selon la règle du tiers. Voici le canton optimal selon ta capacité. Voici les 3 trucs à corriger pour accélérer."*
- **Premier enfant prévu cette année** : *"Voici les coûts mensuels moyens à prévoir, voici l'impact sur ton budget actuel, voici les allocations cantonales auxquelles tu auras droit, voici quand prendre ta congé maternité ou paternité, voici les couvertures à vérifier sur ton assurance."*
- **Mariage** : *"Voici les implications fiscales du changement de statut, voici la décision concubinage vs mariage avec les chiffres pour ton cas, voici les contrats à mettre à jour, voici la question à poser au notaire si vous envisagez un contrat de mariage."*
- **Changement de job** : *"Attention. Le salaire n'est pas le seul critère. La caisse de pension du nouveau job — vérifie son taux de couverture, ses bonifications de vieillesse, sa rémunération de l'avoir. Si elle est moins généreuse que ton actuelle, c'est CHF 50'000-200'000 de différence sur ta vie future à la retraite. Voici les 3 questions à poser au RH. Voici la timeline optimale du changement pour minimiser l'impact fiscal."*
- **Retraite anticipée à 60 ans** : *"Voici ce que ça coûte vraiment (rachats LPP supplémentaires nécessaires, lacune AVS, taxation du capital), voici si ta situation actuelle le permet, voici le plan sur 5-10 ans pour y arriver."*
- **Sortir du surendettement** : *"Voici les 3 leviers prioritaires dans ton cas, voici les organismes officiels suisses (Caritas, Caritas Dette Conseils), voici comment éviter la spirale, voici les premiers gestes ce mois-ci."*

**La dimension critique** : MINT est **proactive sur les angles morts**. L'utilisateur ne sait pas qu'il devrait comparer les caisses de pension lors d'un changement de job. MINT le sait, et MINT le dit avant que le contrat soit signé. Cette pro-activité repose sur :
- Le RAG personnel (MINT connaît ta situation actuelle)
- Le déclenchement par événement (changement détecté = analyse activée)
- La compliance neutre (MINT informe sans recommander un produit)
- La voix MINT (alerte sans alarmiste, *"attention, regarde ceci avant de signer"*)

**Pitch vision long-terme en une phrase** : *"MINT n'est pas un dashboard que tu consultes. MINT est un copilote financier qui sait où tu veux aller, qui voit les pièges sur la route, et qui te le dit avant que tu y tombes."*

### 2.4 — La synthèse des 3 dimensions

MINT = **profondeur de VZ + fréquence de Cleo + vision long-terme d'un planificateur familial vivant.**

Ce qui fait que MINT est extraordinaire en Suisse, ce n'est pas une seule de ces dimensions. **C'est leur combinaison.** Aucun acteur suisse actuel ne fait les trois en même temps. VZ a la profondeur mais pas la fréquence ni la pro-activité. Cleo a la fréquence mais pas la profondeur ni la jurisdiction. Les neo-banques (Yuh, Selma) ont la fréquence et un peu de profondeur mais aucune neutralité. Les apps de planification (PocketSmith, YNAB) sont étrangères et ignorent la spécificité suisse.

MINT est l'intersection. Et l'intersection n'existe pas.

---

## 2bis. Cleo n'est pas le repoussoir. Cleo est la référence d'architecture.

> **Mise à jour 2026-04-11 (post-audit Cleo)** : après une lecture sérieuse de 25 screenshots et schémas Cleo (dossier `CLEO/` du repo), il est clair que **Cleo a déjà résolu architecturalement le problème de l'organisme financier vivant**. Le ton sass médiatisé est trompeur — l'architecture sous-jacente est goal-driven, proactive, et anti-shame de la même façon que MINT_IDENTITY.md le décrit. **MINT ne combat pas Cleo. MINT applique l'architecture Cleo à la finance suisse, avec la profondeur de VZ et la neutralité que ni Cleo ni VZ ne peuvent avoir.**

### L'architecture Cleo 3.0 : la boucle de référence

Cleo expose explicitement son architecture interne : **Insight → Daily Plan → Conversation Agent → Action → Plan Memory → (boucle quotidienne)**.

```
                    ┌─────────────────────┐
                    │  Insight Generation │
                    │   (Validate & Store)│
                    └──────────┬──────────┘
                               ↓
                    ┌─────────────────────┐
                    │     Daily Plan      │
                    │ (Goal Selection +   │
                    │  Conversation Plan) │
                    └──────────┬──────────┘
                               ↓
                    ┌─────────────────────┐
                    │ Conversation Agent  │
                    │     (Cleo 3.0)      │
                    └──────────┬──────────┘
                               ↓
                    ┌─────────────────────┐
                    │     User Action     │
                    │  (one-tap, in-chat) │
                    └──────────┬──────────┘
                               ↓
                    ┌─────────────────────┐
                    │    Plan Memory      │ ──┐
                    │ (daily persistence) │   │ Daily loop
                    └─────────────────────┘ ──┘
```

C'est **la boucle Insight-Plan-Conversation-Action-Memory** qui transforme une app finance en organisme vivant. Sans cette boucle, on a un dashboard. Avec cette boucle, on a un compagnon.

### MINT a déjà tous les composants de cette boucle (vérifié dans le code 2026-04-11)

| Brique de la boucle Cleo 3.0 | Module(s) MINT existant(s) |
|---|---|
| **Insight Generation (Validate & Store)** | `services/coach/precomputed_insights_service.dart`, `models/coach_insight.dart`, `services/anticipation/anticipation_signal.dart`, `services/anticipation/anticipation_ranking.dart` |
| **Goal Selection** | `services/coach/goal_tracker_service.dart`, `services/goal_selection_service.dart`, `models/goal_template.dart`, `widgets/pulse/goal_selector_sheet.dart` |
| **Daily Plan / Conversation Plan** | `services/plan_generation_service.dart`, `services/plan_tracking_service.dart`, `models/financial_plan.dart`, `widgets/coach/plan_preview_card.dart`, `widgets/coach/plan_reality_card.dart` |
| **CAP Engine** (Capture-Anticipate-Plan, framework maison équivalent) | `services/cap_engine.dart`, `services/cap_sequence_engine.dart`, `services/cap_memory_store.dart`, `models/cap_decision.dart`, `models/cap_sequence.dart`, `widgets/pulse/cap_card.dart`, `widgets/pulse/cap_sequence_card.dart` |
| **Conversation Agent** | `services/coach/coach_orchestrator.dart`, `services/coach/coach_chat_api_service.dart`, `services/coach/intent_router.dart`, `services/coach/coach_context_builder.dart`, `services/coach/coach_models.dart`, backend `services/coach/claude_coach_service.py`, `services/coaching_engine.py` |
| **Tool Calling (in-chat actions)** | `services/coach/chat_tool_dispatcher.dart`, `services/coach/tool_call_parser.dart`, `services/coach/coach_tools.py` |
| **Anticipation Engine** (proactive timing) | `services/anticipation/anticipation_engine.dart`, `services/anticipation/anticipation_trigger.dart`, `services/anticipation/anticipation_persistence.dart`, `widgets/home/anticipation_signal_card.dart`, `providers/anticipation_provider.dart` |
| **Nudge Engine** (just-in-time interventions) | `services/nudge/nudge_engine.dart`, `services/nudge/nudge_persistence.dart`, `services/nudge/nudge_trigger.dart`, `services/coach/jitai_nudge_service.dart`, `services/coach/proactive_trigger_service.dart` |
| **Anomaly Detection** ("Money is leaking — Doordash") | `services/backend/app/services/anomaly_detection_service.py` |
| **Notification Scheduling** (lock-screen interventions) | `services/backend/app/services/notifications/notification_scheduler_service.py`, `notification_models.py` |
| **Snapshots in time** (graphes annuels eat-outs vs subs) | `services/backend/app/services/snapshots/snapshot_service.py`, `snapshot_models.py`, `models/budget_snapshot.dart` |
| **Conversation Memory** (Plan Memory loop) | `services/coach/conversation_memory_service.dart`, `services/coach/memory_reference_service.dart`, `services/coach/conversation_store.dart`, `services/cap_memory_store.dart` |
| **Data-driven opener** ("Hey Tom, solid work this month") | `services/coach/data_driven_opener_service.dart` |
| **Adaptive challenge** | `services/coach/adaptive_challenge_service.dart` |
| **Weekly recap** | `services/coach/weekly_recap_service.dart` |
| **Multi-LLM** (BYOK + fallback) | `services/coach/multi_llm_service.dart` |
| **Compliance Guard** (LSFin protection — ce que Cleo n'a PAS) | `services/coach/compliance_guard.dart`, backend `services/coach/compliance_guard.py` |
| **Hallucination Detector** (sécurité LLM) | `services/coach/hallucination_detector.dart`, backend `services/coach/hallucination_detector.py` |
| **Regional Voice** (FR/DE/IT cantonal — ce que Cleo n'a pas) | `services/coach/voice_service.dart`, `services/coach/voice_config.dart`, backend `services/coach/regional_voice_service.dart` |
| **Mint State Provider** (single source of truth utilisateur) | `providers/mint_state_provider.dart`, `models/mint_user_state.dart` |
| **Document parsers** (LPP, 3a, fiscal, AVS, bank, custom) | `services/document_vision_service.py`, `services/document_parser/`, `services/docling/`, `services/document_parser/lpp_certificate_parser.py`, `tax_declaration_parser.py`, `avs_extract_parser.py` |
| **RAG personnel** (mémoire indexée du dossier utilisateur) | `services/rag/` (12 modules : ingester, vector_store, hybrid_search, retriever, orchestrator, insight_embedder, knowledge_catalog, llm_client, update_pipeline, guardrails, faq_service, cantonal_knowledge) |

### Le diagnostic réel : dette d'intégration, pas dette de feature

**MINT a tous les composants de l'architecture Cleo 3.0. Et plus.** MINT a en plus :
- La compliance guard (Cleo n'a pas — Cleo n'est pas régulée comme conseiller financier)
- Le hallucination detector
- Les parsers de documents financiers suisses certifiés
- Le RAG personnel multi-modal
- Les 8 calculateurs financiers certifiés contre les barèmes officiels
- Les 18 événements de vie codés
- La voix régionale FR/DE/IT cantonale
- Le profil archetype financier (8 types : swiss_native, expat_eu, expat_us, independent_with_lpp, etc.)
- Le compliance guard read-only par architecture (pas de mouvements d'argent — c'est Cleo qui fait du cash advance, MINT non par doctrine)

**Le problème de la mobile cassée n'est PAS un problème de construction.** C'est un problème de **câblage** : tous ces services existent, ils ne sont juste pas câblés ensemble en boucle visible, et ils ne sont pas exposés à l'utilisateur sur des surfaces UI qui marchent.

C'est **extraordinairement bonne nouvelle**. Câbler du code qui marche déjà est 10x plus rapide que construire du code nouveau. Le sprint des 3-5 prochaines semaines est un sprint d'**intégration et de visibilité**, pas un sprint de construction.

### Reformulation de la cible avec cette compréhension

MINT n'est pas "Cleo + VZ + vision long-terme" comme une addition.

**MINT est l'évolution de Cleo 3.0 appliquée à la finance suisse complète, avec la profondeur de VZ, la neutralité structurelle (read-only, pas d'AUM, pas de produits, pas de commissions) que ni Cleo ni VZ ne peuvent avoir, et le pilotage des projets de vie sur 1-30 ans qu'aucun des deux ne fait.**

C'est plus précis. C'est plus juste. Et c'est ce que MINT a déjà construit en grande partie — il reste à le câbler et à le rendre visible.

---

## 3. La métaphore centrale : la bête vivante

MINT est **une bête vivante**. C'est la métaphore que Julien a utilisée verbatim, et c'est la bonne.

Ce que ça veut dire concrètement :

- **MINT a un métabolisme** : elle ingère continuellement (documents uploadés, transactions bancaires, événements de vie déclarés, questions au chat)
- **MINT a une mémoire** : tout ce qui entre devient partie du RAG personnel — `enhanced_confidence`, `coach_context`, `cap_memory_store`, vector store
- **MINT a des organes** : le coach Claude est le système nerveux, le compliance guard est le système immunitaire, l'anomaly detection est le système sensoriel, les calculateurs sont les muscles, le RAG est le cerveau
- **MINT a une voix** : calme, précise, fine, rassurante, nette — une intelligence relationnelle stable qui n'est pas un personnage théâtral
- **MINT a une vitalité variable** : parfois en bonne forme (FRI score qui monte, anomalies stables, plans tenus), parfois en stress (gap LPP, dette qui s'accumule, événement de vie non préparé)
- **MINT vit dans la poche du propriétaire** : pas un service externe, pas un site web qu'on consulte, pas un dashboard qu'on ouvre une fois par mois — une présence

**Compatibilité avec MINT_IDENTITY.md** : la bête vivante est l'incarnation de *"une intelligence calme, intime, fiable, dans la poche."* C'est la même chose dite avec une métaphore biologique au lieu d'une description abstraite.

**Compatibilité avec VOICE_SYSTEM.md** : *"La voix MINT n'est pas une personnalité théâtrale. C'est une intelligence relationnelle stable."* La bête vivante n'a pas besoin d'être théâtrale — elle est. Une vraie présence n'a pas besoin d'expressions faciales.

**Pas de mascotte. Pas d'avatar. Pas de visage.** La bête vivante est invisible. Elle se manifeste par sa voix, par ses interventions, par sa mémoire de toi. Comme un médecin de famille que tu connais depuis 20 ans — tu n'as pas besoin de voir sa tête pour savoir que c'est lui qui te parle.

---

## 4. Le centre de gravité : le dossier vivant

**MINT n'est pas un coach. MINT est un dossier vivant. Le coach est l'interface au-dessus du dossier.**

Cette inversion change tout. Aujourd'hui (à corriger), MINT met le chat en avant. Demain, MINT met le dossier en avant. Le chat est *comment* on parle au dossier, pas la chose elle-même.

### Qu'est-ce que le dossier vivant contient ?

**Documents bruts** :
- Certificats LPP (annuels, multi-employeurs)
- Contrats 3a (assurance et bancaire)
- Déclarations fiscales (annuelles, multi-cantonales si applicable)
- Contrats d'hypothèque
- Extraits AVS
- Relevés bancaires
- Polices d'assurance (vie, RC, ménage, complémentaires LAMal)
- Contrats de leasing
- Contrats de travail
- Tout autre document financier

**Données structurées extraites** (via parsers existants : `document_parser/`, `docling/`, `lpp_certificate_parser`, `tax_declaration_parser`, `avs_extract_parser`, `bank_statement` extractor) :
- Salaire, primes, allocations
- Avoir LPP, salaire assuré, bonifications, rente projetée, rachat possible
- Soldes 3a, types de comptes (assurance vs banque), durées
- Patrimoine total, dettes, charges fixes
- Couverture assurances, franchises, lacunes

**Données relationnelles** :
- État civil, partenaire, enfants à charge
- Canton, commune, archetype financier (swiss_native, expat_eu, expat_us, independent_with_lpp, etc.)
- Événements de vie en cours ou imminents (premier emploi, mariage, naissance, achat immobilier, divorce, retraite, etc.)

**Données comportementales** (via open banking + anomaly_detection_service) :
- Flux mensuels (revenus, dépenses, épargne)
- Catégorisation des dépenses
- Anomalies détectées
- Snapshots mensuels (évolution dans le temps)

**Données conversationnelles** :
- Historique des échanges chat
- Préférences exprimées
- Questions répétées (signal d'incertitude)
- Décisions prises ou reportées

### Comment le dossier se construit

**Par tous les canaux en parallèle** :

1. **Upload de documents** (canal principal pour le démarrage à froid) — l'utilisateur prend une photo ou drop un PDF, MINT parse en 30 secondes, stocke, indexe
2. **Conversation chat** (canal continu) — chaque fois que l'utilisateur dit *"j'habite à Sion"* ou *"je gagne 78'000"* ou *"je suis marié"*, MINT extrait, valide, enregistre dans `coach_context`
3. **Open banking** (canal automatique post-onboarding) — connexions bancaires via Blink, transactions ingérées en continu
4. **Événements de vie déclarés** (canal contextuel) — l'utilisateur dit *"je change de job"* ou *"on attend un enfant"*, MINT déclenche le flow correspondant
5. **APIs futures** (canal espéré) — quand les caisses LPP, l'AVS, ou les assurances offriront des APIs publiques (5+ ans peut-être), MINT s'y branche

**La règle d'or** : *"MINT ne pose pas de questions abstraites. MINT lit ce que tu lui donnes et complète par des questions ciblées seulement quand c'est nécessaire."*

Pas d'onboarding form de 20 questions. Pas de questionnaire de profil financier. Pas de formulaire de revenus. La première interaction, c'est : *"Dépose ton premier document. Je m'occupe du reste."*

---

## 5. Les 5 principes de fonctionnement

Repris de `MINT_IDENTITY.md` mais opérationnalisés pour la mobile :

### Principe 1 — Parler humain

*"Pas de jargon sans traduction. Pas de 'optimisation de prévoyance liée'. Dire : ce que tu bloques, ce que tu récupères, ce que tu gardes flexible, ce qu'on ne t'a pas dit."*

**Application mobile** : zéro acronyme sans expansion à la première occurrence (LPP → "ton 2e pilier", LAMal → "l'assurance maladie obligatoire"). Zéro phrase administrative ("Veuillez compléter votre profil"). Toujours la voix MINT, toujours la structure 4 couches sur les sorties analytiques.

### Principe 2 — Réduire la honte

*"Mint ne donne jamais l'impression que l'utilisateur est en retard, qu'il a raté sa vie, qu'il aurait dû savoir."*

**Application mobile** : bannis (CI guard) — "débloquer", "complet à X%", "bravo", "tu as loupé", "en retard", "tu devrais", barres de progression statiques, comparaisons sociales (même flatteuses), streaks, achievements, score reveals théâtraux. Embrassés — silence honnête, continuation ("on en était là"), pré-remplissage, conditional language, "on" plutôt que "tu dois".

### Principe 3 — Dialogue, pas leçon

*"L'utilisateur peut répondre avec ses mots. Il peut ne pas connaître les termes. Il peut avancer sans tout comprendre d'un coup."*

**Application mobile** : le chat est libre, pas un menu déguisé. Les analyses sont conversationnelles, pas dashboardées. Si l'utilisateur pose la même question 3 fois sous des formes différentes, MINT remarque et propose un cadrage différent — pas une 4e répétition de la même réponse.

### Principe 4 — Prise immédiate

*"Toujours : un danger évité, un piège éclairé, une question à poser, un prochain geste."*

**Application mobile** : chaque sortie MINT (parsing d'un document, réponse de chat, analyse de scénario) doit produire au minimum **une chose actionnable** — une question à poser à un courtier, une donnée à compléter, un document à uploader ensuite, une décision à prendre dans X jours. Pas d'output purement informatif sans next step.

### Principe 5 — Doux mais tranchant

*"Le ton MINT n'est pas mou. Simple, chaleureux, direct, protecteur. Jamais agressif, jamais mou."*

**Application mobile** : la tranchant cible **l'industrie** (les contrats opaques, les biais commerciaux, les pièges fiscaux), pas l'utilisateur. La douceur protège l'utilisateur. C'est la dynamique d'un avocat de défense compétent, pas d'un moralisateur.

---

## 6. Ce que MINT n'est jamais

Repris de `MINT_IDENTITY.md` et `VOICE_SYSTEM.md`, regroupés :

**MINT n'est PAS** :
- Un conseiller en placement (pas de recommandation personnalisée d'instruments)
- Un comparateur affilié (pas de commission, pas de ranking, pas de "top 5")
- Un prof de prévoyance (pas de cours, pas de leçons)
- Un justicier anti-broker (pas d'accusations, pas de populisme)
- Une app de retraite (18 événements de vie, pas un seul)
- Une app de gamification (pas de badges, pas de streaks, pas de score reveals)
- Une app de comparaison sociale (jamais "tu fais mieux que la moyenne suisse")
- Un banquier privé (trop formel, trop distant)
- Un influenceur finance (trop enthousiaste, trop performatif)
- Un chatbot sympa (trop générique, trop lisse)
- Une startup française (trop d'anglicismes, trop de "🚀")
- Un outil de transactions ou de paiement (read-only par architecture, jamais de virement)
- Un comparateur de produits ou un agrégateur (jamais de catalogue de tools)

Cette liste est un filtre. Tout écran, toute fonctionnalité, tout copy qui tombe dans une de ces catégories est à supprimer ou à refactorer.

---

## 7. L'architecture cible : 6 écrans principaux + ~10 secondaires

### Les 6 écrans principaux (ce que l'utilisateur voit le plus)

#### 1. **Splash / Welcome** (premier touch)

**Rôle** : faire entendre la voix MINT en 5 secondes et donner un seul CTA.

**Contenu** :
- Tagline verbatim de `MINT_IDENTITY.md` : *"Mint te dit ce que personne n'a intérêt à te dire."*
- Sous-titre court reprenant la formule MINT : *"Un ami cultivé qui travaille dans la finance suisse. Dans ta poche."*
- Un seul CTA : *"Dépose ton premier document"*
- Lien secondaire discret : *"Qui est MINT ?"* (vers une page about qui cite MINT_IDENTITY.md verbatim)

**Pas de** : choix de langue forcé (auto-détection), sélection de canton à l'entrée, formulaire d'email, lien vers Apple Sign In en pré-requis. L'utilisateur entre, voit la voix, dépose un document. Apple Sign In est demandé seulement quand il faut sauvegarder.

#### 2. **Document Upload**

**Rôle** : capturer un document et le passer au parser dans le moins de friction possible.

**Contenu** :
- Camera (par défaut sur mobile, pour photographier un document papier)
- Drop zone (pour PDF / images existants en galerie)
- Liste courte des types de documents reconnus (LPP, 3a, fiscal, AVS, hypothèque, contrat assurance, relevé bancaire) — pas exhaustive, juste indicative
- Pas de "choisis le type de ton document avant l'upload" — MINT classifie automatiquement via `document_vision_service`

**État de chargement** : message en voix MINT, *"Je lis ton document. C'est le moment où je vois ce qui n'est pas écrit en gros."* Animation minimale, jamais de spinner générique.

**État d'erreur** : *"Je n'ai pas réussi à lire ce document. Soit ce n'est pas un type que je reconnais, soit la qualité ne permet pas l'extraction. Tu peux réessayer ou m'envoyer une photo plus nette."* Voix MINT, jamais d'accusation.

#### 3. **Document Result (4 layers)**

**Rôle** : afficher l'output de l'analyse selon la structure 4 couches de `MINT_IDENTITY.md`.

**Contenu** (un seul scroll vertical) :
- **Couche 1 — Les faits** : extraction brute, sans opinion, avec les chiffres et les références au document source (numéros de page si applicable)
- **Couche 2 — Traduction humaine** : les mêmes faits reformulés en langage courant, voix MINT
- **Couche 3 — Pour toi** : mise en perspective personnelle avec les hypothèses visibles (canton, archetype, situation matrimoniale) et éditables inline
- **Couche 4 — À demander avant de signer** : 1-2 questions concrètes que l'utilisateur peut poser à son courtier, banquier, notaire — sourcées légalement

**Pied d'écran** :
- Disclaimer LSFin (collapsible)
- Sources légales (LPP art. X, LIFD art. Y, etc.)
- Bouton *"Sauvegarde dans mon dossier"* (déclenche Apple Sign In si pas connecté, sinon save direct)
- Bouton *"Pose une question à MINT sur ce document"* (ouvre le chat avec contexte forcé sur ce doc)

**Aucun** : score reveal, achievement unlock, comparaison cantonale, "tu fais mieux que X% des Suisses", celebration animations.

#### 4. **My Dossier (file vault)**

**Rôle** : montrer à l'utilisateur tout ce que MINT sait de lui, avec la possibilité de tout voir, tout modifier, tout supprimer.

**Contenu** :
- Liste des documents uploadés, groupés par catégorie (Prévoyance, Fiscalité, Logement, Assurances, Bancaire, Autre)
- Pour chaque document : preview, date d'upload, statut parsing, accès au détail
- Section *"Ce que MINT sait de toi"* : un résumé structuré du `coach_context` actuel (canton, archetype, statut, etc.) — éditable
- Section *"Tes événements de vie en cours"* : événements déclarés ou détectés
- Bouton *"Ajoute un document"* (raccourci vers Document Upload)
- Bouton *"Supprime tout"* (nLPD compliant — purge totale, irréversible, avec confirmation)

**Principe central** : **transparence radicale**. L'utilisateur doit pouvoir voir, à tout moment, exactement ce que MINT a stocké à propos de lui. Pas d'opacité. Pas de "nous traitons vos données pour améliorer votre expérience". Tout est visible et tout est supprimable.

#### 5. **Coach Chat**

**Rôle** : permettre à l'utilisateur de parler à MINT sur ses propres données.

**Contenu** :
- Conversation history (persistante, mais avec bouton "supprime cette conversation")
- Input text (libre)
- Bouton "Lightning menu" (raccourci vers les 18 événements de vie comme bottom sheet) — réutilise `lightning_menu.dart` existant
- Bouton "Joindre un document" (shortcut vers Document Upload, le résultat revient dans la conversation)
- Suggestions contextuelles si conversation vide ("Tu peux commencer par : 'Combien je paie d'impôts cette année ?'", "Tu peux commencer par : 'Mon contrat 3a est-il bon ?'", etc.)

**Principe central** : le chat est l'interface au-dessus du dossier. **Le coach ne sait que ce que le dossier contient.** Si l'utilisateur pose une question qui requiert une donnée manquante, MINT le dit explicitement : *"Pour répondre à ça, j'ai besoin de voir ton certificat LPP. Dépose-le dans ton dossier et je te réponds."* Pas de réponses inventées.

#### 6. **Profile / Settings**

**Rôle** : gérer le compte, les préférences, les paramètres légaux.

**Contenu** :
- Identité (depuis Apple Sign In ou similaire)
- Langue (FR / DE / IT / EN)
- BYOK Claude key (si l'utilisateur veut utiliser sa propre clé)
- SLM settings (si SLM activé)
- Privacy controls (export, suppression totale, contrôle des données)
- À propos de MINT (citation MINT_IDENTITY.md)
- Disclaimer LSFin
- Logout

**Principe** : minimaliste. Pas d'achievements. Pas de "compte premium". Pas de "ton score MINT". Pas de notifications agressives. Une vraie page de paramètres, fonctionnelle, réversible.

### Les ~10-15 écrans secondaires (accessibles depuis les 6 principaux)

Ces écrans existent mais ne sont pas dans la nav principale. Ils sont **invoqués** par les 6 écrans principaux :

- **Document Detail** : ouvert depuis le dossier ou un résultat sauvegardé
- **Coach Chat avec contexte forcé sur un document** : invoqué depuis le résultat d'un document
- **Bottom sheet "Décline les 18 événements de vie"** : invoqué depuis le lightning menu
- **Bottom sheet "Que veux-tu déposer ?"** : invoqué depuis Document Upload si l'utilisateur n'a rien sous la main
- **Open Banking Consent / Hub / Transactions** : flow secondaire pour la connexion bancaire
- **Couple / Household** : flow secondaire pour ajouter un partenaire au dossier
- **Legal pages (CGU, Privacy, Disclaimer)** : accessibles depuis Profile

Chacun de ces écrans secondaires est une **destination contextuelle**, pas une entrée de navigation principale. Ils n'ont pas besoin d'être dans une bottom nav, un drawer, ou un hub — ils sont invoqués par contexte.

### Les ~70-80 écrans existants : à arbitrer

Les 93 écrans actuels du code seront arbitrés un par un dans le **Livrable 2 (Inventaire)**. Le verdict pour chacun sera l'un de :

- **KEEP** : devient un des 6 écrans principaux ou un des ~10-15 secondaires, marche déjà ou nécessite un polish léger
- **REFACTOR** : devient un écran secondaire mais nécessite réécriture pour matcher la voix / le 4-layer / le dossier-first
- **MERGE** : fusionne avec un autre écran (ex : 5 mortgage screens → 1 écran "hypothèque" avec sections)
- **FREEZE** : reste dans le code mais inaccessible depuis la nav, déglacé sur user demand validé
- **DELETE** : supprimé pour de bon (doctrine indéfendable, dupliqué, mort)

---

## 8. Le user journey type : Sarah, 27 ans

Pour rendre l'architecture concrète, voici le user journey de la persona test (Sarah, infirmière à Sion, premier vrai salaire, archetype `swiss_native`).

### Jour 1 — Rencontre

Sarah découvre MINT (Reddit, Instagram, ami, peu importe). Elle télécharge l'app. Elle ouvre.

**Écran 1 : Splash.** Elle voit la tagline. Elle lit la formule MINT en sous-titre. Elle voit le CTA *"Dépose ton premier document"*. 5 secondes. Elle tape.

**Écran 2 : Document Upload.** Elle se souvient que son certificat LPP est dans son tiroir. Elle va le chercher, photographie. MINT parse en 30 secondes.

**Écran 3 : Document Result.** Sarah voit les 4 couches sur son LPP. Elle apprend qu'elle a 47'000 CHF dans son 2e pilier. Que sa rente projetée à 65 ans est de XX CHF/mois. Que sa caisse est ZZ. Que la bonification pour son âge est YY%. Que son rachat possible est WW CHF. Et surtout : *"3 trucs que ta caisse ne t'a pas dit"*. Et : *"La question à poser à ton employeur"*.

Elle n'est pas connectée (pas d'Apple Sign In encore). Elle voit le CTA *"Sauvegarde dans mon dossier — je perds rien à plus tard."* Elle clique. Apple Sign In en 1 tap. Doc sauvegardé.

MINT lui dit : *"J'ai vu ton LPP. Si tu déposes aussi ton contrat 3a, je peux te montrer comment ils s'articulent. Tu reviens quand tu veux. Je suis là."*

Total temps : ~3-4 minutes. Première session terminée. Valeur livrée.

### Jour 7 — Approfondissement

Sarah revient. Elle ouvre l'app. Elle est sur **Écran 4 : My Dossier** (parce qu'elle est connectée, MINT garde son contexte). Elle voit son LPP avec son chiffre. Elle voit *"Tes événements de vie en cours : Premier emploi"*.

Elle décide de déposer son contrat 3a Swiss Life Connect. Upload, parsing, résultat 4 couches. Elle découvre que son contrat lui coûte 18'000 CHF de plus qu'un 3a bancaire sur 30 ans. Elle voit la question à poser à son courtier. Elle est en colère — pas contre elle, contre le système.

Elle ouvre le chat (**Écran 5 : Coach Chat**) et demande : *"Si je transfère mon 3a, est-ce que je perds mon avantage fiscal ?"* MINT répond avec son `coach_context` (elle est en VS, salariée, salaire connu via le LPP) — réponse personnalisée, pas générique. Elle décide de garder le contrat actuel pour l'instant mais de poser la question à son courtier.

Total session : ~10 minutes.

### Jour 30 — Habitude

Sarah a uploadé 4 documents (LPP, 3a, déclaration fiscale, police RC). Elle a connecté son compte bancaire (un seul). MINT a un profil complet. Elle reçoit une notification (la première en 30 jours, pas spammy) : *"J'ai remarqué un truc dans tes dépenses. Tu veux qu'on regarde ?"*

Elle ouvre. MINT lui montre une anomalie de dépense (un abonnement qu'elle ne reconnaît pas). Elle l'identifie. Elle annule l'abonnement. MINT note dans le dossier *"Vigilance dépenses récurrentes"*. Pas de score, pas de badge, pas de streak. Juste : *"Bien joué. C'est noté."*

### Jour 90 — Vie qui change

Sarah reçoit une offre de job. Elle ouvre MINT, va dans **Écran 5 : Coach Chat**, dit : *"Je change de job, qu'est-ce que je dois faire ?"*. MINT a tout son contexte (LPP actuelle, 3a, profil VS, salarié). MINT lui répond avec :

- Les 3 questions à poser à son nouvel employeur sur la caisse de pension
- Les options pour son LPP actuel (transfert, libre passage, etc.)
- L'optimisation fiscale du timing du changement
- *"Veux-tu qu'on construise un plan ensemble ?"*

Elle dit oui. MINT génère un plan en 5 étapes. Elle le sauvegarde dans son dossier.

### Jour 365 — MINT comme infrastructure

Sarah ouvre MINT en moyenne 1 fois par semaine. Pas tous les jours — c'est pas ça qu'on cherche. Elle l'ouvre quand elle reçoit un nouveau document, quand elle a une question, quand elle veut faire une décision financière. Le reste du temps, MINT vit en background — elle ingère les transactions, détecte les anomalies, prépare les analyses, attend.

Sarah a maintenant un **dossier financier complet** dans MINT. Tout ce que VZ aurait dans son CRM après 3 entretiens à CHF 1'000 chacun, MINT l'a après 12 sessions d'app à 0 friction. Et MINT n'a jamais essayé de lui vendre quoi que ce soit.

C'est **ça**, MINT.

---

## 9. Compatibilité avec les documents existants

Ce manifesto **ne contredit aucun** des documents source. Il **opérationnalise** ce qui était déjà écrit :

- **`MINT_IDENTITY.md`** : la mission, le positionnement, les 5 principes, les 4 couches, les phrases autorisées/interdites, les références juridiques — tout est repris verbatim ou cité.
- **`VOICE_SYSTEM.md`** : les 5 piliers (Calme, Précis, Fin, Rassurant, Net), la formule MINT, les DO/DON'T, la règle anti-caricature — tout reste valide.
- **`CLAUDE.md`** : la doctrine no-advice, no-ranking, no-promise, no-social-comparison, no-LLM-without-guard, les anti-patterns 1-16 — tout est respecté.
- **`docs/MINT_UX_GRAAL_MASTERPLAN.md`** : à relire et auditer contre ce manifesto pour identifier les contradictions (probable : certaines parties parlent encore de "shell 3 tabs" qui contredit le dossier-first).
- **`docs/NAVIGATION_GRAAL_V10.md`** : à déprécier ou réviser — son shell 3-tabs (Aujourd'hui, Coach, Explorer) ne correspond plus à l'architecture cible.
- **`.planning/architecture/00-NAVIGATION-ROADMAP.md`** : reste comme **plan d'infrastructure technique** (LOOP-01 fix, MintNav, ShellRoute, anti-patterns CI guards, KPIs) mais son **plan produit** (kill list, phasing) est subordonné à ce manifesto. Le manifesto est la nouvelle source of truth pour ce qui est gardé/supprimé.
- **Design doc 9.2/10 du wedge web (`julienbattaglia-dev-design-20260411-110029.md`)** : reste comme spec pour la **surface publique web** (rencontre 3a assurance, FR, no auth) qui est une **déclinaison cohérente** de l'architecture mobile. Le wedge web partage le backend, la voix, le dossier (s'il est connecté), les 4 couches. Il devient le canal d'acquisition cold-friendly qui amène les humains vers la mobile.

---

## 10. Ce qui change concrètement par rapport à aujourd'hui

| Aspect | Aujourd'hui (v2.3 cassée) | Demain (v2.4 selon ce manifesto) |
|---|---|---|
| **Centre de gravité** | Chat surchargé, navigation floue, 95 écrans dispersés | Dossier vivant, 6 écrans principaux, navigation linéaire |
| **Premier touch** | Splash → 4-tab shell → confusion | Splash → "Dépose ton premier document" → résultat |
| **Onboarding** | Form de 20 questions, choix de canton, profil financier | Aucun form. Le premier document EST l'onboarding. |
| **Navigation** | 4 tabs cassés + drawer + navigation interne incohérente | Navigation linéaire entre 6 écrans + chat comme couche transversale |
| **Dossier** | Caché derrière `documents_screen.dart`, peu mis en avant | Premier-class citizen, accessible depuis partout, central |
| **Chat** | Présenté comme la chose principale, surchargé | Interface au-dessus du dossier, sait ce que le dossier sait |
| **Document scan** | Existe mais peu utilisé, intégration faible | Le canal principal d'enrichissement du dossier |
| **Achievements / streaks / score reveal** | Présents (anti-doctrine) | Supprimés |
| **Comparaisons cantonales** | Présentes (anti-doctrine) | Supprimées ou refactorées en données du dossier |
| **18 écrans life events** | Tous accessibles depuis hubs Explorer | Accessibles via lightning menu + chat |
| **Tools (calculateurs)** | Hub "Tools" ou similaire (catalog exposure = anti-pattern) | Invoqués par contexte depuis le chat ou un document |
| **Voix** | Inconsistante, mélange de contextes | Une seule voix MINT, modulation subtile par contexte |
| **Anti-patterns CI guards** | Pas en place | Mis en place dès Phase 1 (cf. nav roadmap Section 7) |

---

## 11. La promesse à Julien

Tu lis ce manifesto. Tu te dis : *"OK, c'est l'histoire. C'est claire. C'est ce que je veux raconter."*

Et tu te dis ensuite : *"Mais comment on y arrive depuis le code cassé d'aujourd'hui ?"*

Réponse : avec deux livrables qui suivent.

- **Livrable 2 — Inventaire** (`11-INVENTAIRE.md`) : le verdict screen-by-screen pour les 93 écrans existants. KEEP / REFACTOR / MERGE / FREEZE / DELETE pour chacun. Avec rationale, dépendances, et ordre d'exécution.
- **Livrable 3 — Plan d'exécution** (`12-PLAN-EXECUTION.md`) : un plan de 3-5 semaines, semaine par semaine, avec gates, qui prend le code d'aujourd'hui et le transforme en l'architecture cible décrite ici. Réutilise le navigation roadmap pour la partie infrastructure (MintNav, ShellRoute, CI guards, KPIs) et applique les verdicts du livrable 2 pour la partie produit.

À la fin des 3-5 semaines, tu installes la nouvelle build sur ton iPhone, tu fais le creator walkthrough cold-start, et **tu n'as plus envie de jeter ton téléphone par la fenêtre**. Tu vois la voix MINT, tu déposes ton certificat LPP en photo, tu reçois 4 couches d'insight, tu sauvegardes dans ton dossier, tu poses une question au chat, tu obtiens une réponse personnalisée, tu fermes l'app. Total : 4 minutes. Zéro bug. Zéro cul-de-sac. Une seule histoire.

C'est ça, le but. Et c'est atteignable avec le code que tu as déjà — il suffit de le réorganiser autour de la bonne histoire.

---

*Fin du manifesto.*

*Prochain document : `11-INVENTAIRE.md` (verdict screen-by-screen, en cours de production via 4 sub-agents parallèles).*
*Document suivant : `12-PLAN-EXECUTION.md` (plan 3-5 semaines avec gates).*
