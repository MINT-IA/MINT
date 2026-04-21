# AUDIT 01 — Narrative Designer

**Posture :** ex-Monument Valley / Dark Souls / Journey. Un écran = une rencontre.
**Date :** 2026-04-19.
**Scope :** reframer MINT comme un univers de rencontres narrées autour des 18 life events, pas une app de menus.

---

## 1. Verdict : menu-centric, pas world-centric

MINT est aujourd'hui un **rayonnage de simulateurs**. Tu as un `aujourdhui_screen` (passif), 7 hubs `/explore/*` (taxonomie catalogue), et 18 écrans de life events qui sont tous construits sur le même moule industriel : `TabController(length: 4)` — Calcul / Tableau / Checklist / Détail. `naissance_screen.dart` = 4 onglets, `mariage_screen.dart` = 4 onglets, `divorce_simulator_screen.dart` = 984 lignes de tabs, `donation_screen.dart` = 1075 lignes de tabs. C'est un **Excel déguisé en app**. Aucun début, aucun milieu, aucune révélation. L'utilisateur qui vient d'avoir un enfant est jeté dans un formulaire "salaire mensuel : 6000" avec `_recalculate()` — MINT n'accuse jamais réception du fait qu'un être humain vient de naître.

Le layer-4 du moteur MINT (la question à poser) est **absent des 18 écrans**. Les 3 premiers layers sont dilués dans des onglets interchangeables. Le `timeline_screen` (536 lignes) est la seule surface à potentiel narratif — et il est enterré hors nav. **Diagnostic : MINT a le cerveau VZ, le visuel 2019, et zéro dramaturgie.**

---

## 2. Cinq life events reframés (les plus fréquents en vrai)

Règle de flow : **Accusé de réception → Ce qui change vraiment → Ce que MINT fait à ta place → La question à poser avant vendredi**.

### 2.1 Naissance — « Quelqu'un est arrivé »
1. **Reconnaissance.** Pas un formulaire. Un écran sombre, une seule phrase : « Il/elle est né·e. On respire, et quand tu veux on regarde ce qui bouge. » Bouton unique : *Continuer*. **Pas de chiffre avant ce tap.**
2. **Ce qui change vraiment.** Trois cartes révélées une par une (pas 4 onglets simultanés) : (a) ton plafond 3a ne bouge pas, mais tes déductions fiscales oui ; (b) ta LPP active une bonif. orphelin que tu ne verras qu'en cas de coup dur ; (c) les allocs cantonales VS = 275 CHF/mois, tu les touches dès le mois de naissance si tu déposes le formulaire ≤ 30 jours.
3. **Ce que MINT fait.** Pré-remplit la déclaration fiscale côté dépendant, détecte les allocations dues rétroactivement, alerte J-5 avant deadline dépôt employeur.
4. **Layer-4.** « Demande aux RH : est-ce que mon salaire assuré LPP est recalculé automatiquement, ou faut-il que je déclare ? » — une seule question, screenshotable.

**Câblage :** `naissance_screen.dart` (existe, à décomposer en séquence), `family_service.dart`, `baby_cost_widget.dart`, `clause_3a_widget.dart`. **Manque :** `BirthRecognitionScene` (écran 1), `AllocationDeadlineWatcher` (agent de rappel). Tuer les 4 tabs, les transformer en 4 beats.

### 2.2 Déménagement cantonal — « Tu changes de règles du jeu »
1. **Reconnaissance.** « Tu passes de VD à ZG. Tu ne déménages pas, tu changes de pays fiscal. »
2. **Ce qui change.** Taux marginal chute de ~34% à ~22% ; ton 3a banque reste mais ta caisse de prévoyance suit l'employeur donc rebascule si tu changes de job ; la déclaration 2026 se split entre deux cantons au prorata jour ; deadline fiscale ZG ≠ VD.
3. **Ce que MINT fait.** Calcule l'économie annuelle nette, détecte si rester en VD pour la fin d'année a du sens, génère les deux listes de démarches (départ + arrivée).
4. **Layer-4.** « Appelle ta commune de départ : quelle est la date effective d'annonce, et est-ce que je peux la fixer au 31.12 plutôt qu'au 15.11 ? » (économies 4-figures possibles).

**Câblage :** `demenagement_cantonal_screen.dart` (existe, linéaire à rendre), `cantonal_data.dart`, `tax_calculator.dart`. **Manque :** `MoveScene` (split temporal visuel canton A/canton B).

### 2.3 Premier emploi — « Ton premier vrai choix, il est déjà dans ton contrat »
1. **Reconnaissance.** « Tu as signé. Voilà ce que ton employeur ne t'a pas raconté. »
2. **Ce qui change.** Déduction coordination LPP = 26'460 invisible sur ta fiche ; ton 3a peut commencer ce mois (plafond 7'258), pas dans 10 ans ; ton permis fiscal détermine si tu es imposé à la source (et donc si tu peux récupérer via déclaration rectificative).
3. **Ce que MINT fait.** Lit ta fiche salaire scannée, te dit ce que tu paies pour quoi, flag si ta caisse LPP a un plan bonus (CPE, PUBLICA, Hotela — listés côté `lpp_certificate_parser`).
4. **Layer-4.** « Demande aux RH : quel est le plan LPP exact (Base ? Maxi ?) et la bonif. vieillesse actuelle ? » — la différence entre 15% et 24% = ~200k à 65 ans.

**Câblage :** `first_job_screen.dart` (1160 lignes de tabs à décomposer), `lpp_certificate_parser`, `document_scan/`. **Manque :** `FirstPayslipScene` (scan de la première fiche comme rite).

### 2.4 Achat immobilier (EPL) — « Tu vas geler un étage de ta vie »
1. **Reconnaissance.** « Acheter, c'est verrouiller 3 choses : ton 2e pilier, ta mobilité, ton taux d'impôt. Regarde lesquelles. »
2. **Ce qui change.** EPL min 20k, blocage 3 ans (OPP2 art. 5 + art. 79b al. 3), taxe de retrait au canton de domicile selon la matrice cantonale, taux théorique FINMA 5% + 1% amortissement + 1% frais = tenabilité 33% brut.
3. **Ce que MINT fait.** Croise ton avoir LPP scanné + ton revenu + canton cible, simule les deux scénarios (EPL vs nantissement) côte à côte sans ranker, alerte si retrait > 50% avoir (risque veuvage / invalidité).
4. **Layer-4.** « Demande à ton courtier : sur 25 ans, quelle est la différence cumulée nantissement vs retrait, impôts inclus ? Fais-le écrire. »

**Câblage :** routes `/epl` + `/hypotheque` + `/mortgage/*` (existent), `arbitrage_engine.dart`, `tax_calculator.dart`. **Manque :** `LockInScene` — visualiser les 3 verrous (prévoyance, mobilité, fiscalité) comme 3 portes qui se ferment.

### 2.5 Héritage / décès d'un proche — « Personne ne t'a expliqué ce qui se passe lundi »
1. **Reconnaissance.** « On sait. On fait lentement. D'abord trois choses qui ne peuvent pas attendre, ensuite le reste, au rythme qu'il te faut. »
2. **Ce qui change.** Inventaire successoral cantonal (délai 1 mois VS, 3 mois ZH) ; droits de succession — conjoint 0%, enfants souvent 0% mais concubin·e jusqu'à 50% selon canton ; LPP du défunt = hors succession (rente veuvage/orphelin séparée).
3. **Ce que MINT fait.** Génère la to-do list cantonale datée, liste les institutions à notifier, calcule l'impôt de succession simulé par canton, détecte si un contrat 3e pilier B est hors masse.
4. **Layer-4.** « Avant la séance notaire : demande si tu peux ou non renoncer à la succession (délai 3 mois dès connaissance du décès, CC art. 567). Fais-toi expliquer ce que ça change. »

**Câblage :** `deces_proche_screen.dart` (existe, 442 lignes), `donation_screen.dart`, `succession_patrimoine_screen.dart`. **Manque :** `GriefPacingScene` — protocole qui ralentit l'app (pas de chiffre choc, pas de chips gamifiées, typo plus grande, silence).

---

## 3. Le pattern universel

Un flow MINT **se raconte** quand il respecte ces cinq invariants :

1. **Un verbe à l'imparfait ou au présent d'arrivée avant tout chiffre.** « Tu as signé. » « Il est né. » « Tu déménages. » Le chiffre vient après l'accusé de réception, jamais avant.
2. **Révélation linéaire, pas tabulaire.** 3 à 4 beats qui avancent, pas 4 onglets parallèles. L'utilisateur ne choisit pas l'ordre, MINT le porte.
3. **Le layer-4 est terminal et unique.** Une seule question à poser, screenshotable, avec le destinataire nommé (« aux RH », « au notaire », « à ta commune »). Jamais une liste de 10 questions.
4. **MINT fait quelque chose à la place de l'utilisateur entre deux écrans.** Pré-remplit, rappelle, alerte, détecte. Sinon c'est un cours, pas un coach.
5. **Le silence est un geste.** Après le chiffre choc : espace, non-chip, pas de « veux-tu explorer ? ». L'utilisateur respire. C'est la signature Journey : l'absence de prompt est l'interaction.

Un flow qui **se navigue** (≠ se raconte) a 4 tabs, un AppBar avec titre-catégorie (« Naissance »), des champs input avant contexte, un `_recalculate()` live, et termine sur un résumé sans question. Les 18 screens actuels tombent tous dans ce moule.

---

## 4. Trois écrans à supprimer (ils cassent le récit)

1. **`explore/explore_hub_screen.dart` (64 lignes) + les 7 sous-hubs `/explore/*`.** Pure taxonomie catalogue. Rayonnage de supermarché. Un user qui hérite n'a jamais pensé « je vais cliquer sur Patrimoine & Succession ». Il a dit « mon père est mort ». MINT doit répondre à la phrase, pas à la catégorie.
2. **`aujourdhui_screen.dart` (tel quel).** Dashboard passif agrégeant des cards génériques. Il n'accueille personne, il liste. À reframer comme *scène d'ouverture contextuelle* (voir §5) ou à fusionner dans la surface narrative.
3. **`explore/explorer_screen.dart`.** Double emploi avec `explore_hub_screen`. Artefact de la Wire Spec V2. À mettre en `redirect` vers la nouvelle surface narrative (zéro breakage deep-link).

**Note :** je ne touche pas aux 18 screens life events. Ils contiennent la logique calcul, qui reste. C'est leur **coque UI quadri-onglets** qui doit mourir et être remplacée par une séquence de 3-4 scènes.

---

## 5. Proposition radicale : remplacer « Explorer » par **Le Seuil**

Tuer la tab *Explorer*. La remplacer par **Le Seuil** — un écran qui n'est pas un hub, c'est un **seuil narratif vivant**.

- **Une seule question en haut**, qui change selon ton état réel : « Qu'est-ce qui a bougé cette semaine ? » / « Ton père est décédé il y a 11 jours. On reprend ? » / « Tu as scanné ta fiche il y a 3 jours — tu veux voir ce qu'elle dit ? »
- **En dessous : trois rencontres possibles**, pas sept catégories. Générées par `life_events_service` + `autonomous_agent_service` depuis ton profil réel (détections + échéances + âges clés). Un étudiant genevois de 24 ans verra « Tu changes de job ? » / « Ton 3a n'est pas ouvert » / « Ta LAMal 2027 se négocie maintenant ». Un Julien 49 ans verra « Ton rachat LPP = fenêtre fiscale 2026 » / « Lauren FATCA — la déclaration US expire 15 juin » / « Votre commune bascule ZH 2027 ? ».
- **Pas de grille, pas d'icônes de catégorie.** Trois cartes verticales, typo Montserrat 24px, chacune finit par « Ouvrir ». C'est ça la rencontre.
- **Fallback froid** (profil vide) : une seule carte, « Commence par ce qui pèse. » → 4 verbes (j'ai signé, j'ai perdu, j'hérite, je déménage) → route directe vers la scène d'accueil correspondante.

Techniquement : nouveau `seuil_screen.dart`, consomme `LifeEventsService.surfaceableEvents()` + `CoachProfile.detectedEvents` + `SequenceTemplate`. Les 67 routes canoniques restent en deep link. L'IA nav `/home?tab=2` route vers `SeuilScreen`. Zéro casse.

**Effet :** MINT cesse d'être une app où tu choisis un rayon. Elle devient un lieu qui t'accueille avec ce qui te concerne vraiment, cette semaine-là. C'est Journey plutôt qu'Excel. C'est la mission.

---

**Mot de la fin.** MINT a tout le moteur (calc, compliance, 4-layer, archetypes, détections). Ce qui manque, c'est la **mise en scène**. On ne refait pas le code, on coupe les tabs, on ajoute des scènes d'accueil, et on remplace le rayonnage par un seuil. Trois sprints. Pas plus.
