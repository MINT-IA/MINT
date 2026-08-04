---
description: Direction d'expérience du compagnon de vie — le chat est la porte, la carte est la maison, la trajectoire est la mémoire. Validée par Julien le 2026-08-04 ; l'exécution reste gouvernée batch par batch (règle 13).
---

# Expérience de navigation du compagnon de vie

Une app qu'on utilise dix ans n'a pas la même architecture qu'une app qu'on utilise dix minutes. Un compagnon de vie doit résoudre trois problèmes que les apps-tâches n'ont pas : revenir après trois mois sans se sentir étranger, refléter l'histoire accumulée (la mémoire, c'est la confiance), et grandir avec la complexité d'une vie sans empiler du chrome. Ce document fixe la direction ; chaque batch qui la réalise passe par la gouvernance normale (contrats, TDD, panels, règle 13).

## La thèse — trois couches, trois rôles

| Couche | Rôle | Frontière |
|---|---|---|
| **Le chat (Coach)** | Porte d'entrée universelle par l'intention — zéro connaissance de l'arborescence requise. Répond avec des chiffres fondés (outils forcés + citations) et finit par le lien profond vers la surface qui les porte. | L'artefact durable (receipt, provenance, comparatif) vit à l'écran, jamais dans une bulle. |
| **La carte (hubs + tabs, incluant la carte de vie)** | Domicile stable — la mémoire spatiale : on se souvient d'où vivent les choses. La carte de vie (les 18 événements : exploré / en cours / pas encore pertinent selon archétype et âge) est un hub de cette couche. | La structure ne change pas au gré des features. |
| **La trajectoire (temps)** | La mémoire visible — acquis passés avec leur provenance, présent (couverture des 18 événements), échéances futures connues. C'est une surface de consultation, pas un hub. | Jamais de promesse : scénarios Bas/Moyen/Haut à hypothèses éditables. |

## Les cinq réponses de direction

1. **Chat-first à la Cleo : non.** Le modèle Cleo/Autopilot est transactionnel, porté par une personnalité, sur un marché peu régulé, retenu par l'engagement. MINT est de la lucidité régulée : chaque chiffre doit rester un artefact déterministe et sourcé. Le chat est l'entrée universelle, pas le conteneur. L'esprit « Autopilot » se garde sous une seule forme : la **proactivité calendaire** (fenêtre 3a, échéances fiscales, saison des certificats LPP, jalons AVS) — consentie à l'onboarding, jamais d'action automatique sur l'argent.
2. **Accessibilité des écrans — la règle des trois chemins.** Un écran existe s'il a (a) une route déclarée au contrat de navigation, (b) une entrée depuis son hub en ≤ 2 taps, (c) une intention coach qui pointe vers lui. Un écran qui ne mérite pas ces trois chemins ne mérite pas d'exister. Le garde bidirectionnel du contrat (mergé) rend (a) mécanique ; (b) et (c) s'auditent par batch.
3. **Trajectoire + carte de vie : oui, c'est le différenciateur.** Là où les apps d'engagement retiennent par les séries quotidiennes, MINT retient par la **mémoire avec provenance** : l'app capable de montrer pourquoi tu sais ce que tu sais (« en mars tu as clarifié ta LPP, confiance 34 % → 72 % » — scores issus du modèle EnhancedConfidence 4 axes existant, pas d'une précision psychométrique revendiquée ; chaque acquis porte sa provenance). Garde-fou : progression de compréhension, pas d'engagement — dignité 18-99, chaleur sans jugement.
4. **Pédagogie — cinq mécanismes d'ancrage.** Le moment enseignable bat le cours (micro-leçons 30-60 s déclenchées par le contexte, pas de bibliothèque) ; un concept s'ancre sur TON chiffre (étalon ESTV + receipts) ; le teach-back — faire restituer en une question — s'appuie sur la pratique de récupération, une des techniques les mieux documentées en sciences de l'apprentissage (les nœuds `teach_back` existent déjà au contrat de navigation) ; le calendrier fiscal suisse fournit un espacement naturel de re-présentation des concepts — un rythme saisonnier assumé, pas un système adaptatif de répétition espacée ; un glossaire vivant — chaque terme suisse touchable partout, même explication, relié au chiffre de l'utilisateur quand il existe.
5. **Un acquis se mesure, pas se visite.** Au sens MINT, un concept est « acquis » quand l'utilisateur l'a (a) vu en contexte, (b) appliqué sur son chiffre, (c) restitué une fois en teach-back. C'est un indicateur pragmatique de progression — il ne mesure ni la rétention différée ni le transfert, et ne le prétend pas. Le « résumé des acquis » de la trajectoire affiche cela — jamais des écrans visités.

## Le récapitulatif de conversation (idée « Strava », passée au crible le 2026-08-04)

Proposition de Julien : une conversation MINT comme une activité Strava — enregistrée, puis revisitable avec ses points clés, ses actions, et un suivi fait/pas-fait. Verdict : **le besoin est réel, la métaphore se vole à moitié.**

- **Ce qu'on garde de Strava** : rendre l'effort invisible visible (la courbe cumulative — « Ton histoire » existe déjà) et l'artefact après l'activité — cohérent avec « le chat guide, l'écran fait foi ».
- **Ce qu'on rejette** : la session comme unité. Une course est bornée et signifiante ; une session de chat est un conteneur arbitraire. La bonne granularité est **l'objet extrait** : un *acquis* ou un *engagement* (action déclarée, avec échéance). La session est jetable ; ses objets alimentent la trajectoire. Pas de rituel début/fin : détection implicite de clôture, récapitulatif **proposé** — l'utilisateur confirme, édite ou refuse chaque objet extrait, peut le supprimer ensuite, et cette extraction relève du consentement produit existant (aucune donnée nouvelle, une réorganisation de ce que l'utilisateur a déjà dit).
- **Le suivi fait/pas-fait, honnêtement** : sans connexion externe, MINT ne vérifie pas — il demande. Deux classes d'engagements : *vérifiables in-app* (« clarifier ma LPP » → le certificat est chargé = coché automatiquement) et *externes* (« verser au 3a ») → auto-déclaration + relance calendaire douce, avec règle d'arrêt stricte : une seule relance par échéance, le silence classe l'engagement sans suite, jamais de harcèlement. L'auto-déclaration est fragile — c'est documenté, et le taux d'abandon des engagements sera une métrique de bêta, pas une surprise.
- **Garde LSFin** : le récapitulatif dit « tu as exploré X », jamais « MINT t'a recommandé X » — des scénarios explorés, pas des conseils donnés.

## Stratégie de données — du déclaré au connecté (ambition API, passée au crible le 2026-08-04)

Ambition de Julien : à terme, des connexions bancaires/LPP/AVS pour un système vivant et proactif. Verdict : **oui à l'ambition, non à la précipitation, et deux illusions à crever.**

- **« Aucune connexion bancaire » est aujourd'hui un actif de confiance** (affiché à l'inscription). L'évolution se fera par **consentement opt-in par couche et par source**, jamais par pivot du défaut : le socle reste le déclaré-d'abord sans connexion bancaire ; le connecté est un choix explicite.
- **Illusion n° 1 — « les API LPP/AVS »** : elles n'existent pas. Les caisses de pension n'exposent rien ; l'extrait AVS vient des caisses de compensation, sans API publique. Le chemin réaliste est **le document comme source** : certificat LPP et extrait AVS chargés puis parsés (substrat document_memory existant), avec les mêmes exigences que tout chiffre MINT — chaque champ extrait porte sa provenance, son score de confiance et une validation par l'utilisateur avant usage ; l'obsolescence est gérée par la fraîcheur (axe freshness d'EnhancedConfidence) et le rythme annuel des documents.
- **Illusion n° 2 — « proactif exige les banques »** : faux. Le calendrier fiscal suisse + les données déclarées + les documents couvrent l'essentiel de la proactivité. Le bancaire (bLink/agrégateurs — pas de PSD2 en Suisse, couverture banque par banque, coût récurrent) s'ajoute **quand les utilisateurs le demandent** — ce signal de demande est le bon déclencheur, pas la roadmap.
- **Séquence et conformité** : prouver la boucle confiance-pédagogie sur déclaré + documents → documents-comme-source → bancaire opt-in. Chaque couche élargit les obligations nLPD au-delà de la seule suppression : finalités déclarées par source, minimisation, droit de rectification, retrait du consentement par couche, et absence de profilage non consenti ; des questions FINMA peuvent surgir selon les services. Raison de le faire tard et délibérément, pas de ne jamais le faire.

## Principes d'exécution (Julien, 2026-08-04)

- **Petits batchs très intelligents** — innovants, créatifs, qui ont du sens. Jamais construire des tas de choses pour construire des tas de choses. Le test par batch : « un expert humain trouverait-il ce batch intelligent, ou juste productif ? »
- **La direction ne devient jamais floue** — toute conversation de vision est consignée en ADR dans la foulée ; la règle 13 (herméneutique) force chaque batch à se réconcilier avec ce document, ou à le réviser explicitement.
- **Pas de code généré-raccourci** — TDD contre contrat, panels design 5 lentilles, roasts indépendants, promotion humaine des contrats scellés : la méthode existante reste le seul chemin.

## Ancrages déjà mergés (rien ici ne part de zéro)

Courbe de lucidité « Ton histoire » (#1168/#1169) — graine de la trajectoire · nœuds `teach_back` et arcs `education_*` déjà déclarés au contrat de navigation (liste d'attente datée du garde #1186) · receipts + provenance (#1107→#1171) · étalon fiscal ESTV (#1061→) · citation gate du coach (#564→) · consentement « notifications coaching » à l'onboarding · vocabulaire de la confiance fixé (DESIGN_SYSTEM §4.8) · tables commitment/pre_mortem du backend (substrat des engagements).

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?** Le chat-first pourrait gagner : si l'usage réel montre que les utilisateurs passent l'essentiel de leur temps dans le coach, la carte devient du chrome et Cleo aura eu raison — l'engagement conversationnel est un modèle prouvé commercialement, la « mémoire avec provenance » ne l'est pas. La carte de vie porte un risque réel de gamification perçue (infantilisation pour un public 45-65) et de complexité d'entretien (18 événements × 8 archétypes = matrice de pertinence à maintenir). Le suivi d'engagements auto-déclaré pourrait s'effondrer en silence et transformer la trajectoire en cimetière de bonnes intentions.
- **What does this source not address ?** Aucune donnée d'usage réelle n'existe (pas de bêta active) — toutes les affirmations d'ergonomie sont analytiques. Les mécanismes d'apprentissage cités sont documentés en éducation générale, pas mesurés sur cette cible et ce contenu. Le benchmark Cleo est lu de l'extérieur. La charge de maintenance du glossaire vivant en 6 langues n'est pas chiffrée. Le coût et la fiabilité du parsing de documents (taux d'erreur d'extraction, effort de validation utilisateur) ne sont pas mesurés.
- **What would change this conclusion ?** Seuils de pivot (mesurés en bêta) : moins d'un utilisateur sur cinq consulte la trajectoire après trois mois → la rétrograder en carte simple ; plus des trois quarts de l'usage concentré dans le chat → investir le chat comme surface première et repenser la carte ; deux batches consécutifs échouant le test de compréhension §G sur les micro-leçons → revoir le format pédagogique ; taux d'abandon des engagements au-delà de ce qu'une relance unique corrige → réduire le récapitulatif aux seuls acquis ; contrainte LSFin nouvelle sur les notifications → réduire la proactivité calendaire.

## Sources

- `.planning/decisions/2026-07-31-north-star-experience.md` — « le chiffre d'abord, le changement ensuite, la profondeur sur demande, la chaleur sans jugement — et l'app se souvient de toi ».
- `.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md` — règle 13, vocabulaire Strangler Fig / legacy-as-library, workflow par batch.
- `docs/DESIGN_SYSTEM.md` §4.8 — vocabulaire de la confiance. `docs/VOICE_SYSTEM.md`, `docs/MINT_IDENTITY.md`.
- Benchmark externe : Cleo Autopilot (web.meetcleo.com/autopilot), lu comme contre-modèle partiel. Strava, lu comme métaphore partielle (courbe cumulative oui, session comme unité non).
- Conversations Julien × lead du 2026-08-04 (navigation long terme, chat-first, accessibilité, trajectoire/carte de vie, pédagogie, récapitulatif de conversation, ambition API) — validées par Julien le même jour.

## Status & follow-up

- Statut : **Proposed** — direction validée oralement par Julien (2026-08-04) ; critique croisée Codex appliquée (2 passes : rôles des couches resserrés, pédagogie dé-suraffirmée, gouvernance des données étendue au-delà de la suppression, français corrigé). L'exécution n'est autorisée que batch par batch, chaque batch justifiant son lien à cette direction (règle 13).
- Candidats de batchs futurs (non lancés, non ordonnés) : surface Trajectoire (extension de « Ton histoire ») · extraction acquis/engagements depuis les conversations (récapitulatif) + relances calendaires à règle d'arrêt · glossaire vivant · premiers nœuds `teach_back` au runtime MINT Next · règle des trois chemins comme audit par hub · documents-comme-source (certificat LPP, extrait AVS).
