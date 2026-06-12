# W1 — Walkthrough réel « Marc, cadre 50 ans » — 2026-06-12

> Real-user exploratory session. Persona : **Marc, 50 ans, cadre à Lausanne, ~140k brut/an, marié, 2 ados, propriétaire avec hypothèque, un 3a, ne comprend pas son certificat LPP**. Téléchargé MINT parce qu'un collègue a dit « ça t'explique où tu en es pour la retraite ». Impatient, skimme, tape du français court.
>
> Build : commit `3844c625b` (éclairage hotfix), iPhone 17 Pro sim (iOS 26.2), app targets Railway staging (health 200 vérifié 08:16). Fresh-install (uninstall + reinstall). Conduite idb + `simctl io screenshot`. **NO CODE CHANGES.**

## ⚠️ Caveat 0-TRUST load-bearing (à lire AVANT les findings « fiction »)

Le build installé hydrate `CoachProfileProvider` avec le **seed E2E `cadre_40_55_lpp_rachat`** (`coach_profile_seeds.dart:226-238` : `firstName:'Marc', age:48, canton:'GE', grossMonthlySalary:13500`). Preuve : RvC + /retraite + Mon Argent affichent exactement `age 48 / 162'000 brut / LPP 155'800` — ces valeurs **matchent le seed au CHF près**, pas mes saisies. Ce seed ne se charge QUE via `--dart-define=MINT_E2E_ARCHETYPE=…` (`coach_profile_seeds.dart:295-300`, gardé `kReleaseMode`). Le build précédent a donc été compilé E2E-pinned (cohérent avec `tools/simulator/walker_premier_eclairage.sh` qui pin ce seed).

**Conséquence sur la sévérité** : je **ne peux PAS** affirmer « la fiction fuite vers les vrais users en prod » — ce serait non-prouvé (le `kReleaseMode` guard bloque le seed en release). Les findings ci-dessous taggés `[E2E-SEED CAVEAT]` décrivent une **incohérence INTRA-build réelle** (le profil conversationnel ≠ le profil simulateur, dans la MÊME session) qui tient **indépendamment** du seed ; mais leur framing « données fictives présentées comme réelles » est conditionné à : *si jamais un profil seed/démo/partiel atterrit en prod*. Ce qui est build-indépendant et certain : **deux profils non-synchronisés coexistent dans une session** (le coach a utilisé mon « 50 ans », tout le reste utilise « 48 »).

---

## Timeline (HH:MM:SS, 2026-06-12)

| Heure | Action Marc | Écran | Capture |
|---|---|---|---|
| 08:16:49 | Lance l'app (fresh install) | Cold open | 01-cold-open.png |
| 08:17 | Lit « Voir clair, décider seul. » + sheet « MINT en test » | Landing consent | 01 |
| 08:18 | Tap « Je comprends, on y va » | Welcome | 03-after-consent.png |
| 08:19 | Tap « Parle à Mint » | Chat anonyme | 04-chat-open.png |
| 08:20 | Tape « j'ai 50 ans », envoie | Chat | 06, 07, 08 |
| 08:21 | Lit reply1 (AVS/LPP, 15 ans), tape « c'est quoi un rachat » | Chat | 09, 10, 12 |
| 08:23 | Lit reply2 (DÉFINIT rachat comme un RETRAIT ❌), tape « combien j'aurai à la retraite » | Chat | 12, 13 |
| 08:24 | reply3 (« 25 ans devant toi » ❌) + prompt compte (3-msg limit) | Account sheet | 13 |
| 08:24 | Tap « Créer un compte » | Créer ton compte (form Material) | 14, 15 |
| 08:25 | Tap « Continuer en mode local » | Home / Aujourd'hui | 16-after-local.png |
| 08:26 | Lit hero « Ta retraite pince encore — 28% » ; tap « Explorer mes scénarios » | RvC (Rente ou capital) | 16, 17 |
| 08:26 | Voit age 48 / 162'000 / LPP 155'800 préremplis (≠ ses saisies) | RvC | 17, 18 |
| 08:31 | Mon argent : libre 5'522 / fiab 80% / libre net 110'106 | Mon argent | 23 |
| 08:32 | Prévoyance : AVS manquant / LPP 155'800 estimé / 3a 203'530 « saisi » | Mon argent>Prévoyance | 26-prevoyance3.png |
| 08:33 | Futur : libre aujourd'hui **4'934** (≠ 5'522) | Mon argent>Futur | 27-futur.png |
| 08:34 | Explorer → Retraite & Prévoyance → Projection retraite | /retraite | 28, 29, 30 |
| 08:36 | Lit **69%** taux de remplacement (vs home 28%) | /retraite | 30-projection.png |
| 08:37 | Rachat LPP échelonné (honnête, rachat = versement ✓) | Rachat sim | 33, 34 |
| 08:40 | Tap Coach tab : vide, 5'522, gros void blanc ; Historique OK | Coach tab | 37, 38 |

---

## WTF log — un finding par ligne

### WTF-W1-01 · Le coach DÉFINIT « rachat » comme un RETRAIT (inversion factuelle) — **P1**
- **Surface** : Chat anonyme (`Parle à Mint`), reply2.
- **Repro** : msg « c'est quoi un rachat » → réponse commence : *« **Un rachat, c'est le fait de retirer une partie ou la totalité de ton capital du 2e pilier (LPP)** avant la retraite – par exemple pour devenir indépendant, acheter un logement… »*
- **Ce que Marc voit vs ce qui ferait sens** : Marc, qui ne comprend déjà PAS son certificat LPP, pose la question la plus basique possible et reçoit la **définition inversée**. Un rachat LPP = verser de l'argent DANS la caisse (déductible, art. 79b) ; un retrait/EPL = sortir de l'argent. Le coach enseigne l'exact opposé.
- **Triangulation (3 surfaces contredisent le coach)** : (a) reply1 même session traite rachat correctement (« le temps de récupération d'un rachat se raccourcit ») ; (b) la carte Premier Éclairage de reply1 : « Si ta caisse permet des rachats… pourrait abaisser ton revenu imposable » (= versement) ; (c) le menu Retraite distingue explicitement **« Rachat LPP »** (icône carte+) de **« EPL (retrait pour logement) »** — l'IA contredit la taxonomie de sa propre app.
- **Évidence** : 12-reply2-firstline.png (la phrase), 08-coach-reply1-top.png (reply1 correct), 07 (carte éclairage), 32-back-menu.png (Rachat LPP ≠ EPL).
- **Locus suspecté** : LLM coach (prompt / RAG retrieval). Pas un calcul — c'est une hallucination de définition. Coach numerical-tool infra ne couvre pas les définitions conceptuelles.

### WTF-W1-02 · Contradiction du taux de remplacement : home **28%** vs /retraite **69%** — **P1**
- **Surface** : /home hero « Ta retraite pince encore » vs /retraite « Projection retraite ».
- **Repro** : Home (16-after-local.png) : « **28 % de taux de remplacement**. Un rachat ou un 3a change la trajectoire. » — ton alarmiste (« ta retraite pince »). /retraite (30-projection.png) : jauge « **69 %** — C'est dans la moyenne suisse. Des optimisations sont possibles. » — ton rassurant. **Même profil, même session, même quantité, 41 points d'écart, deux verdicts émotionnels opposés.**
- **Ce qui ferait sens** : UNE valeur de taux de remplacement, partout. Marc ne peut pas savoir si sa retraite « pince » ou est « dans la moyenne ».
- **Évidence** : 16-after-local.png (28%), 30-projection.png (69%).
- **Locus suspecté** : home hero reçoit `replacementRatio` prop (`hero_retirement_card.dart:39`, computé upstream — vraisemblablement `minimal_profile_service` base BRUTE) ; /retraite lit `proj.tauxRemplacementBase` (`retirement_dashboard_screen.dart:361,529` via `retirement_projection_service`). Deux moteurs → c'est le finding « replacement-rate dénominateur divergent » de la MATRICE (D3 : 63%/46.5%) qui re-mord, maintenant 28/69.

### WTF-W1-03 · Le coach s'auto-contredit sur l'horizon : « 15 ans » (reply1) puis « 25 ans devant toi » (reply3) — **P1**
- **Surface** : Chat, reply1 vs reply3, même session, même « j'ai 50 ans ».
- **Repro** : reply1 : *« À 50 ans… il te reste **exactement 15 ans** avant l'âge ordinaire AVS (65 ans) »*. reply3 (combien à la retraite) : *« si tu as **25 ans d'activité devant toi** et que tu verses régulièrement… »*. Pour un homme de 50 ans visant 65, l'horizon est 15 ans ; 25 ans impliquerait départ à 75 ou âge 40.
- **Ce qui ferait sens** : horizon cohérent (15 ans) dans toute la conversation.
- **Évidence** : 08-coach-reply1-top.png (« exactement 15 ans »), 13-coach-reply3.png (« 25 ans d'activité devant toi »).
- **Locus** : LLM coach — oublie/recalcule l'horizon entre deux tours. Le « 2,3% de rente AVS par année manquante » de reply1 est correct (≈1/44) ; c'est l'horizon de reply3 qui dérape.

### WTF-W1-04 · Profil conversationnel (50 ans) ≠ profil simulateur (48 ans) — désync intra-session — **P1** (build-indépendant)
- **Surface** : Coach (50) vs RvC / /retraite / Mon Argent (48).
- **Repro** : J'ai dit « j'ai 50 ans », le coach l'a utilisé (« À 50 ans… 15 ans avant 65 »). Mais RvC champ « Ton âge » = **48** (17-scenarios.png), /retraite graphe « 48 ans → 70 ans » (30), Mon Argent dérivé du même profil 48. Deux profils non-synchronisés coexistent : le profil conversationnel (mes saisies chat) ne nourrit NI le simulateur NI le home.
- **Ce qui ferait sens** : ce que Marc dit au coach DOIT alimenter le profil unique qui sert home/simulateurs. Sinon « ça apprend avec toi » (promesse de la landing) est faux.
- **Évidence** : 08 (coach=50), 17-scenarios.png (RvC=48), 30-projection.png (graphe 48).
- **Locus** : `CoachProfileProvider.profile` (seed 48) découplé du parcours chat anonyme. `[E2E-SEED CAVEAT]` sur la valeur 48 spécifiquement (c'est le seed) — mais le **principe de désync** tient : aucun pont chat→profil observé.

### WTF-W1-05 · Inputs RvC préremplis indiscernables d'une vraie saisie utilisateur — **P2** `[E2E-SEED CAVEAT]`
- **Surface** : RvC (Rente ou capital).
- **Repro** : champs « Ton revenu brut annuel » = **162000**, « Ton avoir LPP actuel » = **155800**, « Ton âge » = **48** — rendus comme des champs de formulaire normaux (gris, éditables), AUCUN tag « estimé/démo » sur les INPUTS (seul le RÉSULTAT « ~Estimé » est tagué en bas). Marc n'a jamais donné de salaire ni de LPP.
- **Ce qui ferait sens** : si une valeur est préremplie par estimation/seed, le CHAMP doit le dire (« estimé » / « exemple »), pas seulement le résultat. Sinon Marc croit que l'app « sait » son salaire alors qu'elle l'a inventé.
- **Évidence** : 17-scenarios.png. C'est D5 de la MATRICE reproduit (défauts fictifs indiscernables) — les valeurs ont changé (48/162000/155800 vs le D5 50/100000/350000) car c'est un seed différent.
- **Locus** : `rente_vs_capital_screen.dart:217-242` `apply()` remplit `_ageCtrl/_salaryCtrl/_lppTotalCtrl` depuis `CoachProfileProvider.profile` sans surfacer la provenance au niveau champ.

### WTF-W1-06 · « Marge libre mensuelle » : 5'522 (Aujourd'hui + Coach) vs 4'934 (Futur) — **P2**
- **Surface** : Mon Argent>Aujourd'hui (5'522) + Coach tab (5'522) vs Mon Argent>Futur (4'934).
- **Repro** : onglet Aujourd'hui « Ton libre mensuel **5'522 CHF** » (23) ; Coach tab header « **5'522** Marge libre mensuelle » (37) ; onglet Futur « Libre aujourd'hui **4'934 CHF** » (27). **Même quantité, deux onglets adjacents du MÊME écran, écart 588 CHF.**
- **Ce qui ferait sens** : la marge libre mensuelle est UNE valeur.
- **Évidence** : 23-mon-argent.png (5'522), 27-futur.png (4'934), 37-coach-tab2.png (5'522).
- **Locus** : MATRICE §2 « Marge libre divergente » — `budget_living_engine.dart:196` (monthlyNet canonique) vs `minimal_profile_service.dart:296,307` (proxy net `*0.75`). Onglet Futur tire d'un moteur, Aujourd'hui de l'autre.

### WTF-W1-07 · « Libre net 110'106 » juxtaposé à « libre mensuel 5'522 » ne se réconcilient pas — **P2**
- **Surface** : Mon Argent>Aujourd'hui.
- **Repro** : carte montre « Ton libre mensuel 5'522 CHF » ET « Libre net 110'106 CHF » côte à côte. 5'522×12 = 66'264 ≠ 110'106. Marc lit « libre net » comme « libre annuel » → faux.
- **Ce qui ferait sens** : libellés qui se réconcilient, ou expliciter que « Libre net » = revenu net annuel (pas marge libre).
- **Évidence** : 23-mon-argent.png.
- **Locus** : `mon_argent` Aujourd'hui card — deux notions « libre » différentes sous le même mot.

### WTF-W1-08 · 3e pilier 203'530 CHF tagué « saisi » alors que Marc n'a rien saisi — **P2** `[E2E-SEED CAVEAT]`
- **Surface** : Mon Argent>Prévoyance.
- **Repro** : ligne « 3e pilier (3a) » tag vert « **saisi** » → 203'530 CHF. Marc n'a jamais saisi de 3a. Comparer : AVS tag « manquant », LPP tag « **estimé** » (honnête). Seul le 3a est faussement tagué « saisi » (= entré par l'utilisateur).
- **Ce qui ferait sens** : une valeur seed/démo doit être taguée « estimé » ou « exemple », jamais « saisi ». Le tag « saisi » est un mensonge de provenance.
- **Évidence** : 26-prevoyance3.png.
- **Locus** : `ProfileDataSource` du champ 3a dans le seed mal classé comme `user`/`saisi`. (LPP correctement `estimé` → le système de tags marche, c'est la donnée 3a du seed qui est mal source-taguée.)

### WTF-W1-09 · Arbre d'accessibilité VIDE sur 6 écrans (toute la surface éditoriale) — **P1 a11y**
- **Surface** : Landing, Welcome, Chat, Créer-compte, Home, RvC, /retraite — **tous**.
- **Repro** : `idb ui describe-all` retourne 0 nœud labellisé (seul le root `Application`) sur chaque écran testé. VoiceOver ne lit rien.
- **Ce qui ferait sens** : `Semantics` exposés. Pour un app suisse 18-99 (incluant seniors), un arbre AX vide = inutilisable au lecteur d'écran + non-testable en automation.
- **Évidence** : sorties `_ax.py` « 0 interactive/labeled nodes » répétées (logs session). Étend D6 de la MATRICE (qui ne l'avait trouvé que sur RvC) à TOUTE la surface nouvelle-éditoriale.
- **Locus** : widgets sans `Semantics`/`ExcludeSemantics` mal posé sur les nouveaux écrans. À investiguer globalement.

### WTF-W1-10 · Formulaire « Créer ton compte » en style Material-boxy, clash éditorial — **P2** (confirme finding connu)
- **Surface** : « Créer ton compte ».
- **Repro** : champs e-mail / Prénom (compteur « 0/50 ») / Date de naissance / mot de passe en **boîtes grises remplies Material** ; checkboxes carrées ; dense. Clash net avec l'input chat (pill cream bordé) et les heros serif.
- **Ce qui ferait sens** : champs cream bordés cohérents avec le reste ; pas de compteur « 0/50 » sur un prénom. Aussi : **redemande la date de naissance** alors que Marc vient de dire « j'ai 50 ans » au coach (re-collecte ignorant le contexte). Friction lourde (email+password+DOB+4 checkboxes) au msg 3 pour qui voulait juste « où j'en suis ».
- **Évidence** : 14-creer-compte.png, 15-creer-compte-scroll.png.
- **Locus** : écran register — design system pas migré vers l'éditorial.

### WTF-W1-11 · RenderFlex overflow « OVERFLOWED BY 191 PIXELS » sur /retraite — **P2** (debug-visible)
- **Surface** : /retraite Projection retraite.
- **Repro** : bande debug rouge/jaune « RIGHT OVERFLOWED BY 191 PIXELS » sur le bord droit de la zone taux/breakdown.
- **Ce qui ferait sens** : pas d'overflow. 191px est massif — un texte/row déborde, masqué en release mais signe d'un layout cassé (probable sur petits écrans ou textes longs i18n).
- **Évidence** : 30-projection.png (bande visible bord droit).
- **Locus** : `retirement_dashboard_screen.dart` zone hero/breakdown — Row sans `Flexible`/`Expanded`.

### WTF-W1-12 · Onglet Coach : vide au défaut + void blanc ~70% — **P2** (UX/spacing)
- **Surface** : Coach tab (bottom nav).
- **Repro** : tap Coach → header « 5'522 / Marge libre mensuelle » puis **vaste vide blanc** jusqu'à l'input « Dis-moi. » en bas. Aucune trace de la conversation que Marc vient d'avoir (3a/rachat/retraite) — surface coach DIFFÉRENTE du « Parle à Mint » anonyme. (L'historique EST récupérable via l'icône horloge → carte « j'ai 50 ans, 8 msg » — donc P2 pas P1.)
- **Ce qui ferait sens** : reprendre/afficher la conversation en cours, ou un état rempli ; remplir le void (suggestions, résumé). Le vide donne un sentiment d'inachevé.
- **Évidence** : 37-coach-tab2.png (void), 38-coach-history.png (historique OK).
- **Locus** : Coach tab empty-state + dual-coach-surface (anonyme vs tab) non-unifiés.

### WTF-W1-13 · Tags de conversation « 3a, assurance, emploi » ne matchent pas le sujet discuté — **P3**
- **Surface** : Coach>Historique.
- **Repro** : conversation portait sur âge / **rachat LPP** / **retraite-AVS** ; tags affichés : « 3a », « assurance », « emploi ». « assurance » et « emploi » n'ont pas été discutés explicitement.
- **Évidence** : 38-coach-history.png.
- **Locus** : tagger auto de conversation — sur-attribue.

### WTF-W1-14 · Rachat échelonné : deux montants par palier non-réconciliés (26'667 vs 21'044) — **P3**
- **Surface** : Rachat LPP échelonné.
- **Repro** : chaque palier affiche « CHF 26'667 » (gros) ET « Rachat CHF 21'044 » (petit). 26'667×3 = 80'001 ≠ Total 63'131 ; 21'044×3 = 63'132 ✓. Le gros chiffre (26'667) ne correspond ni au total ni à 3×lui-même.
- **Ce qui ferait sens** : libeller la distinction (capacité vs versé ? brut vs net ?) ou aligner.
- **Évidence** : 34-rachat-sim2.png.
- **Locus** : `staggered_withdrawal` / rachat sim — deux bases non-libellées.

### WTF-W1-15 · Espace blanc excessif récurrent (chat, menu retraite, historique, coach) — **P3** (spacing)
- **Surface** : Chat (greeting→chips, ~half empty 04), menu Retraite (6 items puis ~45% void, 32), Historique (1 carte puis ~75% void, 38), Coach tab (~70% void, 37).
- **Ce qui ferait sens** : ces listes courtes laissent d'énormes vides bas-d'écran. Sur un app premium-éditorial le vide doit être intentionnel (respiration) — ici il lit « inachevé / contenu manquant ».
- **Évidence** : 04, 32-back-menu.png, 37-coach-tab2.png, 38-coach-history.png.

---

## ✅ Ce qui MARCHE (ne pas casser)

1. **reply1 du coach est excellent** : a utilisé « 50 ans » → « 15 ans avant 65 », « 2,3% de rente AVS / année manquante » (≈ correct 1/44), extrait CI AVS, fenêtre rachat — **zéro terme banni LSFin** (« pourrait », « envisager »), question de relance. C'est le standard à généraliser.
2. **Carte Premier Éclairage conditionnelle (hotfix 3844c625b confirmé)** : « **Si** ta caisse de pension permet des rachats… pourrait abaisser ton revenu imposable. L'effet dépend de ta tranche marginale… » — copy honnête, conditionnelle, **une seule carte** par conversation (ECL-01 gate visible). 07-coach-reply1-full.png.
3. **Mon Argent>Prévoyance tagge la provenance** : AVS « manquant », LPP « estimé » — adresse D2 (LPP nu sur home). 26-prevoyance3.png.
4. **Cohérence LPP avoir 155'800** entre RvC et Prévoyance (même valeur, deux surfaces). 17 + 26.
5. **Rachat LPP échelonné** : pédagogique, honnête (« basée sur les barèmes cantonaux estimés »), cite LIFD art.33 / LPP art.79b al.3, blocage EPL expliqué, rachat correctement = versement déductible. 33 + 34.
6. **RvC bas de page** : sliders de sensibilité, « Hypothèses de cette simulation », Avertissement LSFin avec sources (LPP art.14, LIFD art.22/38) — solide. 18.
7. **Explorer = grille life-events** (Retraite, Famille, Travail, Logement, Fiscalité, Patrimoine…) — respecte Rule #3 (MINT ≠ retraite-first). 28.
8. **3-message limit → prompt compte** : flow logique, « Plus tard » dispo, mode local fonctionnel.
9. **Menu Retraite distingue Rachat LPP ≠ EPL** — taxonomie correcte (ce qui rend WTF-W1-01 d'autant plus net). 32.

---

## D7 — VERDICT EXPLICITE : **PASS** ✅

**Check** : « /retraite ne doit PAS afficher "4 infos suffisent" avec un profil hydraté ».

**Résultat** : avec le profil hydraté (seed cadre 48/162000/LPP155800), /retraite « Projection retraite » affiche une projection COMPLÈTE — jauge **69% taux de remplacement**, **~CHF 9'359/mois** (range 7'955–10'763), breakdown AVS 2'606 / LPP 2'152 / 3a 2'390 / Autre 2'211 (somme = 9'359 ✓, cohérent intra-écran), graphe 48→70 ans, « Calculé sur ce qu'on connaît aujourd'hui — quelques pièces manquent encore ». **AUCUNE trace de « 4 infos suffisent ».**

**Corroboration code** : `retirement_dashboard_screen.dart:461` `_showEnrichment => _confidenceScore.round() <= 69` — l'état enrichissement-vide est gaté sur la confiance ; profil hydraté → confiance > seuil → pas d'état vide. La régression D7 (8500b9269 / 53e0c24b7) tient.

**Capture** : `30-projection.png` (et `29-retraite-dash.png` pour le menu d'accès).

**Réserve 0-TRUST** : PASS vérifié sur un profil HYDRATÉ (seed). Le scénario inverse de D7 (profil hydraté PUIS vidé/clear → régression vers « 4 infos ») n'a PAS été re-testé dans cette session (nécessite un clear de profil) — son fix est revendiqué par 8500b9269 mais non re-prouvé ici. Pour CETTE session : **PASS**.

---

## Verdict global — « est-ce que ça fait du sens ? » (voix de Marc)

> « Honnêtement ? Le début m'a bluffé. Je tape "j'ai 50 ans" et le truc me sort un vrai paragraphe qui parle de MES 15 ans avant la retraite, des trous AVS, d'un rachat — c'est exactement ce que mon collègue m'avait promis. Là j'y crois.
>
> Et puis ça part en vrille. Je demande "c'est quoi un rachat", la question la plus bête, et il me répond qu'un rachat c'est *retirer* mon argent. Mais non — mon beau-frère a fait un rachat, il a *versé* de l'argent pour payer moins d'impôts. Donc soit l'app se trompe, soit mon beau-frère se trompe, et du coup je fais plus confiance à rien. Pire : deux messages avant, la même IA me disait l'inverse.
>
> Après c'est le festival des chiffres qui se battent. La page d'accueil me dit "ta retraite pince, 28%" — flippant. Je clique sur l'onglet retraite : "69%, t'es dans la moyenne suisse, tranquille". Lequel je crois ?? Ma marge libre c'est 5'522 sur un écran et 4'934 sur l'onglet d'à côté. Et le simulateur me sort que je gagne 162'000 et que j'ai 48 ans — j'en gagne 140 et j'ai 50, je lui ai JAMAIS donné ces chiffres, d'où il sort ça ? Mon 3a affiché "saisi" : j'ai rien saisi du tout.
>
> Y a de vrais bons morceaux — le simulateur de rachat échelonné est carré, honnête, il me dit "consulte ta caisse". La page prévoyance qui marque "estimé" sur la LPP, j'apprécie. Mais l'impression qui reste c'est : un bon coach qui parle bien, branché sur une calculette qui n'est pas d'accord avec elle-même. Pour un truc sur MON argent, ça suffit pas. Je veux UN chiffre, le bon, partout. »

**Synthèse** : la couche conversationnelle (reply1, éclairage conditionnel) et les simulateurs honnêtes (rachat échelonné, RvC bas-de-page) sont au niveau. Le sense-making casse sur (1) une **hallucination de définition** (rachat=retrait, P1), (2) **l'incohérence des chiffres entre surfaces** (28/69, 5522/4934, 50/48 — P1/P2), héritée des moteurs divergents de la MATRICE qui mordent à l'écran, et (3) un **désync profil-conversation ↔ profil-simulateur** qui invalide la promesse « apprend avec toi ». Priorité de fix : WTF-01 (coach rachat), WTF-02 (28 vs 69), WTF-04 (désync profil), WTF-09 (a11y vide).
