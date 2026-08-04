---
description: Direction d'expérience du compagnon de vie — le chat est la porte, la carte est la maison, la trajectoire est la mémoire. Validée par Julien le 2026-08-04 ; l'exécution reste gouvernée batch par batch (règle 13).
---

# Expérience de navigation du compagnon de vie

Une app qu'on utilise dix ans n'a pas la même architecture qu'une app qu'on utilise dix minutes. Un compagnon de vie doit résoudre trois problèmes que les apps-tâches n'ont pas : revenir après trois mois sans se sentir étranger, refléter l'histoire accumulée (la mémoire, c'est la confiance), et grandir avec la complexité d'une vie sans empiler du chrome. Ce document fixe la direction ; chaque batch qui la réalise passe par la gouvernance normale (contrats, TDD, panels, règle 13).

## La thèse — trois couches, trois rôles stricts

| Couche | Rôle | Ce qu'elle ne fait jamais |
|---|---|---|
| **Le chat (Coach)** | Porte d'entrée universelle par l'intention — zéro connaissance de l'arborescence requise. Chaque réponse finit par le lien profond vers l'écran qui la prouve. | Contenir les chiffres. Le chat guide, l'écran fait foi (receipt + provenance). |
| **La carte (hubs + tabs)** | Domicile stable — la mémoire spatiale : on se souvient d'où vivent les choses. | Changer de structure au gré des features. |
| **La trajectoire (temps)** | La mémoire visible — acquis passés avec leurs receipts, présent (couverture des 18 événements), échéances futures connues. | Promettre. Scénarios Bas/Moyen/Haut à hypothèses éditables, jamais de rendement affirmé. |

## Les cinq réponses de direction

1. **Chat-first à la Cleo : non.** Le modèle Cleo/Autopilot est transactionnel, porté par une personnalité, sur un marché peu régulé, retenu par l'engagement. MINT est de la lucidité régulée : le chiffre doit être un artefact déterministe. Le chat est l'entrée universelle, pas le conteneur. L'esprit « Autopilot » se garde sous une seule forme : la **proactivité calendaire** (fenêtre 3a, échéances fiscales, saison des certificats LPP, jalons AVS) — consentie à l'onboarding, jamais d'action automatique sur l'argent.
2. **Accessibilité des écrans — la règle des trois chemins.** Un écran existe s'il a (a) une route déclarée au contrat de navigation, (b) une entrée depuis son hub en ≤ 2 taps, (c) une intention coach qui pointe vers lui. Un écran qui ne mérite pas ces trois chemins ne mérite pas d'exister. Le garde bidirectionnel du contrat (mergé) rend (a) mécanique ; (b) et (c) s'auditent par batch.
3. **Trajectoire + map de vie : oui, c'est le différenciateur.** Là où les apps d'engagement retiennent par les streaks, MINT retient par la **mémoire avec provenance** : l'app capable de montrer pourquoi tu sais ce que tu sais (« en mars tu as clarifié ta LPP, confiance 34 % → 72 % » — chaque acquis porte son receipt). La map de vie spatialise les 18 événements (exploré / en cours / pas encore pertinent selon archétype et âge) et sert à la fois de progression et de hub de navigation. Garde-fou : progression de compréhension, pas d'engagement — dignité 18-99, chaleur sans jugement.
4. **Pédagogie — cinq mécanismes d'ancrage.** Le moment enseignable bat le cours (micro-leçons 30-60 s déclenchées par le contexte, pas de bibliothèque) ; un concept s'ancre sur TON chiffre (étalon ESTV + receipts) ; le teach-back — faire restituer en une question — est la technique la plus prouvée (les nœuds `teach_back` existent déjà au contrat de navigation) ; le calendrier fiscal suisse est le programme de répétition espacée (chaque saison ramène ses concepts, enrichis de l'historique) ; un glossaire vivant — chaque terme suisse tappable partout, même explication, relié au chiffre de l'utilisateur quand il existe.
5. **Un acquis se mesure, pas se visite.** Un concept est acquis quand l'utilisateur l'a (a) vu en contexte, (b) appliqué sur son chiffre, (c) restitué en teach-back. Le « résumé des acquis » de la trajectoire mesure cela — jamais des écrans visités.

## Le recap de conversation (idée « Strava », roastée le 2026-08-04)

Proposition de Julien : une conversation MINT comme une activité Strava — enregistrée, puis revisitable avec ses highlights (points clés, actions à faire, suivi fait/pas-fait). Verdict après roast : **le besoin est réel, la métaphore se vole à moitié.**

- **Ce qu'on garde de Strava** : rendre l'effort invisible visible (la courbe cumulative — « Ton histoire » existe déjà) et l'artefact après l'activité. Une conversation doit laisser une trace durable : c'est cohérent avec « le chat guide, l'écran fait foi ».
- **Ce qu'on rejette** : la session comme unité. Une course est bornée et signifiante ; une session de chat est un conteneur arbitraire (3 messages ou 40 minutes). La bonne granularité est **l'objet extrait** : un *acquis* (concept ancré, avec receipt) ou un *engagement* (action déclarée, avec échéance). La session elle-même est jetable ; ses objets alimentent la Trajectoire. Pas de rituel start/stop non plus : détection implicite de clôture, recap proposé, jamais imposé.
- **Le suivi fait/pas-fait, honnêtement** : sans connexion externe, MINT ne peut pas *vérifier* — seulement demander. Deux classes d'engagements : *vérifiables in-app* (« clarifier ma LPP » → le certificat est chargé = auto-coché) et *externes* (« verser au 3a ») → auto-déclaration + relance calendaire douce (la fenêtre 3a se ferme → « tu avais prévu de verser — fait ? »). L'auto-déclaration décroît vite : le compagnon relance aux moments naturels, il ne harcèle jamais. Substrat existant : les tables commitment/pre_mortem du backend.
- **Garde LSFin** : le recap dit « tu as exploré X », jamais « MINT t'a recommandé X » — des scénarios explorés, pas des conseils donnés.

## Stratégie de données — du déclaré au connecté (ambition APIs, roastée le 2026-08-04)

Ambition de Julien : à terme, des connexions bancaires/LPP/AVS pour un système vivant et proactif. Verdict après roast : **oui à l'ambition, non à la précipitation, et deux illusions à crever.**

- **« Aucune connexion bancaire » est aujourd'hui un actif de confiance** (affiché à l'inscription). L'évolution se fera par **consentement opt-in par couche**, jamais par pivot du défaut : local-first reste le socle, le connecté est un choix explicite par source.
- **Illusion n° 1 — « les API LPP/AVS »** : elles n'existent pas. Les caisses de pension n'exposent rien ; l'extrait AVS vient des caisses de compensation, sans API publique. Le chemin réaliste est **le document comme API** : certificat LPP et extrait AVS chargés puis parsés (substrat document_memory existant) — données vivantes sans attendre des interfaces qui ne viendront pas à moyen terme.
- **Illusion n° 2 — « proactif exige les banques »** : faux. Le calendrier fiscal suisse + les données déclarées + les documents couvrent l'essentiel de la proactivité (fenêtre 3a, échéances, saison des certificats, jalons AVS). Le bancaire (bLink/agrégateurs — pas de PSD2 en Suisse, couverture banque par banque, coût récurrent) s'ajoute **quand les utilisateurs le demandent** — ce signal de demande est le bon déclencheur, pas la roadmap.
- **Séquence** : prouver la boucle confiance-pédagogie sur déclaré + documents → documents-comme-API → bancaire opt-in. Chaque couche multiplie la surface nLPD (le chantier suppression/crypto-shred venant d'être fait en donne la mesure) et peut soulever des questions FINMA selon les services — raison de le faire tard et délibérément, pas de ne jamais le faire.

## Principes d'exécution (Julien, 2026-08-04)

- **Petits batchs très intelligents** — innovants, créatifs, qui font du sens. Jamais construire des tas de choses pour construire des tas de choses. Le test par batch : « un expert humain trouverait-il ce batch intelligent, ou juste productif ? »
- **La direction ne devient jamais floue** — toute conversation de vision est consignée en ADR dans la foulée ; la règle 13 (herméneutique) force chaque batch à se réconcilier avec ce document, ou à le réviser explicitement.
- **Pas de code généré-raccourci** — TDD contre contrat, panels design 5 lentilles, roasts indépendants, promotion humaine des contrats scellés : la méthode existante reste le seul chemin.

## Ancrages déjà mergés (rien ici ne part de zéro)

Courbe de lucidité « Ton histoire » (#1168/#1169) — graine de la trajectoire · nœuds `teach_back` et arcs `education_*` déjà déclarés au contrat de navigation (liste d'attente datée du garde #1186) · receipts + provenance (#1107→#1171) · étalon fiscal ESTV (#1061→) · citation gate du coach (#564→) · consentement « notifications coaching » à l'onboarding · vocabulaire de la confiance fixé (DESIGN_SYSTEM §4.8).

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?** Le chat-first pourrait gagner : si l'usage réel montre que les utilisateurs passent 90 % de leur temps dans le coach, la carte devient du chrome et Cleo aura eu raison — l'engagement conversationnel est un modèle prouvé commercialement, la « mémoire avec provenance » ne l'est pas. La map de vie porte un risque réel de gamification perçue (infantilisation pour un public 45-65) et de complexité d'entretien (18 événements × 8 archétypes = matrice de pertinence à maintenir).
- **What does this source not address ?** Aucune donnée d'usage réelle n'existe (pas de bêta active) — toutes les affirmations d'ergonomie sont analytiques. Les mécanismes d'apprentissage cités (teach-back, répétition espacée) sont prouvés en éducation générale, pas mesurés sur cette cible et ce contenu. Le benchmark Cleo est lu de l'extérieur, sans données d'usage de Cleo. La charge de maintenance du glossaire vivant en 6 langues n'est pas chiffrée.
- **What would change this conclusion ?** Des sessions utilisateurs réelles montrant que la trajectoire n'est pas consultée (→ rétrograder en carte simple) ou que le chat concentre l'essentiel de l'usage (→ investir le chat comme surface première et repenser la carte). Un test de compréhension §G échoué deux batches de suite sur les micro-leçons contextuelles (→ revoir le format pédagogique). Une contrainte LSFin nouvelle sur les notifications proactives (→ réduire la proactivité calendaire).

## Sources

- `.planning/decisions/2026-07-31-north-star-experience.md` — « le chiffre d'abord, le changement ensuite, la profondeur sur demande, la chaleur sans jugement — et l'app se souvient de toi ».
- `.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md` — règle 13, vocabulaire Strangler Fig / legacy-as-library, workflow par batch.
- `docs/DESIGN_SYSTEM.md` §4.8 — vocabulaire de la confiance. `docs/VOICE_SYSTEM.md`, `docs/MINT_IDENTITY.md`.
- Benchmark externe : Cleo Autopilot (web.meetcleo.com/autopilot), lu comme contre-modèle partiel.
- Conversation Julien × lead du 2026-08-04 (questions : navigation long terme, chat-first, accessibilité, trajectoire/map de vie, pédagogie) — validée par Julien le même jour.

## Status & follow-up

- Statut : **Proposed** — direction validée oralement par Julien (2026-08-04) ; passe Decided après critique croisée Codex consignée. L'exécution n'est autorisée que batch par batch, chaque batch justifiant son lien à cette direction (règle 13).
- Candidats de batchs futurs (non lancés, non ordonnés) : surface Trajectoire (extension de « Ton histoire ») · extraction acquis/engagements depuis les conversations (recap) + relances calendaires · glossaire vivant · premiers nœuds `teach_back` au runtime MINT Next · règle des trois chemins comme audit par hub · documents-comme-API (certificat LPP, extrait AVS).
