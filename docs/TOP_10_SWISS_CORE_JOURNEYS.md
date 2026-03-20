# TOP 10 Swiss Core Journeys

> Statut: priorités produit avant le long tail
> Rôle: dire quels parcours/situations doivent définir le standard MINT
> Source de vérité: oui, pour la priorisation métier des parcours coeur
> Ne couvre pas: implémentation détaillée écran par écran, routing exhaustif, wording complet

---

## 1. Principe

Tous les événements de vie ne doivent pas être traités à égalité.

Avant d'élargir davantage le catalogue, MINT doit être excellent sur les situations:
- les plus fréquentes,
- les plus coûteuses,
- les plus émotionnelles,
- les plus structurantes en Suisse.

Règle:
- le noyau MINT n'est pas "la retraite uniquement";
- le noyau MINT est l'ensemble des situations qui font réellement bouger la vie financière suisse.

Précision:
- le document garde le nom `Top 10 Suisse` pour la lisibilité;
- en pratique, le noyau stratégique couvre `10+1` situations, car `retraite / décaissement / succession` forment un même bloc de décision et que `invalidité / protection` et `frontalier` doivent rester first-class.

---

## 1.1 Où en est MINT aujourd'hui

Le socle produit/UX existe déjà:
- shell 4 tabs + 7 hubs,
- `Aujourd'hui` piloté par le `CapEngine`,
- `Action Success` pour refermer la boucle,
- design tokens et voice system largement diffusés,
- une grande partie des écrans T1-T5 déjà migrés au standard S52.

Mais tout n'est pas au même niveau.

Pour le noyau produit, il faut distinguer:
- ce qui est **déjà fort**,
- ce qui est **partiellement fort mais encore éclaté**,
- ce qui est **encore secondaire ou incomplet**.

Règle:
- on ne part pas de zéro;
- on passe d'un codebase déjà riche à un produit cohérent, hiérarchisé et irréprochable sur ses parcours coeur.

---

## 2. Les parcours coeur

### 1. Premier emploi

Pourquoi:
- première entrée dans AVS / LPP / impôts / budget réel
- moment fondateur pour la relation avec MINT

MINT doit montrer:
- ce qui change sur la fiche de salaire,
- ce que signifient AVS / LPP / net,
- ce que l'utilisateur peut déjà faire sans sur-complexifier.

Cap type:
- `Comprendre mon premier salaire`

Template:
- `RF` puis `HP`

Preuves requises:
- fiche de salaire
- canton
- âge

Interdits:
- jargon non expliqué
- détail de prévoyance trop tôt

État MINT aujourd'hui:
- [first_job_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/first_job_screen.dart) est traité au standard S52 (`10/10` dans le board).

Ce qui est déjà fort:
- onboarding métier du premier salaire,
- pédagogie AVS/LPP,
- ton plus accessible que beaucoup d'outils suisses.

Ce qu'il reste à fermer:
- relier encore mieux ce parcours à `Aujourd'hui`,
- brancher un `Cap` type premier salaire si c'est le sujet dominant,
- vérifier la preuve documentaire idéale: fiche de salaire / certificat LPP futur.

---

### 2. Changement d'emploi / comparaison d'offre

Pourquoi:
- très fréquent
- fort impact salaire / LPP / fiscalité / mobilité

MINT doit montrer:
- différence nette réelle,
- impact LPP / bonus / 13e / trajet / coût de vie,
- ce qui change vraiment après impôt et charges.

Cap type:
- `Comparer mes deux offres`

Template:
- `DC`

Preuves requises:
- salaire brut
- mois de salaire
- bonus
- canton / commune

Interdits:
- comparaison purement brute
- conseil prescriptif "prends l'offre X"

État MINT aujourd'hui:
- [job_comparison_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/job_comparison_screen.dart) est traité (`10/10`).

Ce qui est déjà fort:
- comparaison de scénarios,
- logique métier réelle,
- bon terrain pour `Decision Canvas`.

Ce qu'il reste à fermer:
- rendre ce parcours plus central dans `Aujourd'hui` quand un changement d'emploi est détecté,
- mieux relier `job comparison` au parcours global "nouvel emploi / statut / canton / budget".

---

### 3. Chômage / perte d'emploi

Pourquoi:
- forte charge émotionnelle
- besoin d'action rapide et rassurante

MINT doit montrer:
- droits de base,
- chute de revenu estimée,
- prochaines urgences,
- levier budgétaire immédiat.

Cap type:
- `Sécuriser les 90 prochains jours`

Template:
- `RF`

Preuves requises:
- dernier salaire
- situation familiale
- canton

Interdits:
- dramatisation
- chiffres négatifs sans levier

État MINT aujourd'hui:
- [unemployment_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/unemployment_screen.dart) est traité (`10/10`).

Ce qui est déjà fort:
- charge émotionnelle déjà reconnue,
- sujet très compatible avec `Roadmap Flow`.

Ce qu'il reste à fermer:
- faire du chômage un vrai `Cap` de protection / stabilisation,
- renforcer la logique `90 jours`,
- relier plus explicitement budget, ORP, LPP et prochaines pièces à fournir.

---

### 4. Invalidité / protection

Pourquoi:
- risque financier sous-estimé
- sujet critique pour salariés comme indépendants
- très fort écart entre revenu d'activité et rentes de remplacement

MINT doit montrer:
- la perte de revenu potentielle,
- ce qui est déjà couvert,
- ce qui manque encore,
- l'ordre des leviers de protection.

Cap type:
- `Vérifier mon filet de protection`

Template:
- `RF` puis `DC`

Preuves requises:
- certificat LPP
- revenu actuel
- IJM éventuelle
- couverture privée éventuelle

Interdits:
- faux sentiment de sécurité
- jargon assurantiel sans hiérarchie
- promesse implicite qu'une couverture "suffit"

État MINT aujourd'hui:
- l'invalidité existe dans le catalogue, mais n'est pas encore traitée comme parcours coeur first-class.

Ce qui est déjà fort:
- bon ancrage suisse protection / filet social,
- cohérent avec le positionnement "reconstruire le filet".

Ce qu'il reste à fermer:
- faire remonter invalidité comme sujet noyau dans `Aujourd'hui` et le `CapEngine`,
- relier AI / LPP invalidité / IJM / couverture privée dans une même séquence lisible,
- distinguer plus clairement les cas salarié et indépendant.

---

### 5. Concubinage / mariage

Pourquoi:
- très fréquent
- change fiscalité, AVS, succession, couple mode

MINT doit montrer:
- ce qui change juridiquement et fiscalement,
- où il y a gains/pertes,
- ce qui doit être clarifié entre les deux personnes.

Cap type:
- `Voir ce qui change à deux`

Template:
- `RF`

Preuves requises:
- statut
- revenus des deux
- enfants

Interdits:
- simplification abusive du couple
- confusion concubinage vs mariage

État MINT aujourd'hui:
- [mariage_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/mariage_screen.dart) est traité (`10/10`).
- [concubinage_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/concubinage_screen.dart) reste en retrait (`T6-A`).

Ce qui est déjà fort:
- couple mode existe,
- mariage est déjà un bon parcours coeur.

Ce qu'il reste à fermer:
- mettre concubinage au même niveau de qualité que mariage,
- rendre explicite le contraste suisse mariage vs concubinage,
- mieux relier couple / AVS / succession / logement / enfants dans un même langage de progression,
- traiter le couple comme une unité de décision quand AVS, fiscalité et logement changent réellement à deux.

---

### 6. Naissance

Pourquoi:
- très fréquent
- énorme effet budget, temps, déductions, garde

MINT doit montrer:
- coûts anticipés,
- aides / déductions,
- impact budget et organisation,
- prochaine formalité utile.

Cap type:
- `Préparer le vrai coût de la naissance`

Template:
- `RF`

Preuves requises:
- canton
- situation de couple
- nombre d'enfants
- garde envisagée

Interdits:
- ton mignon / infantilisant
- chiffres sans contexte de garde et déductions

État MINT aujourd'hui:
- [naissance_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/naissance_screen.dart) est traité (`10/10`).

Ce qui est déjà fort:
- c'est déjà un des bons parcours émotionnels du produit,
- le sujet déductions / garde / budget est légitime pour MINT Suisse.

Ce qu'il reste à fermer:
- renforcer la progression visible,
- faire remonter naissance comme sujet du moment dans `Aujourd'hui`,
- améliorer le lien entre coûts, aides et formalités.

---

### 7. Achat logement / hypothèque

Pourquoi:
- décision majeure en Suisse
- mélange de capacité, fiscalité, 2e pilier, 3a, FINMA

MINT doit montrer:
- capacité réelle,
- stress test,
- fonds propres,
- arbitrages EPL / 3a / amortissement.

Cap type:
- `Tester ma capacité réelle`

Template:
- `DC`

Preuves requises:
- revenus
- patrimoine
- LPP / 3a
- prix bien / apport

Interdits:
- faire croire qu'un achat est "possible" au sens bancaire certain
- confondre taux réel et stress FINMA

État MINT aujourd'hui:
- [affordability_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/mortgage/affordability_screen.dart) est traité (`10/10`).
- plusieurs sous-écrans restent à harmoniser: amortization, EPL combined, imputed rental, SARON vs fixed.

Ce qui est déjà fort:
- MINT sait déjà mieux que beaucoup d'apps expliquer les contraintes FINMA/ASB,
- le couple logement + prévoyance est un avantage suisse réel.

Ce qu'il reste à fermer:
- rendre le parcours logement plus unifié,
- relier capacité, EPL, amortissement et fiscalité dans un même flow,
- éviter que le sujet se fragmente en sous-outils.

---

### 8. Dette / budget sous tension

Pourquoi:
- sujet récurrent, urgent, fidélisant
- fort besoin de reframing et de levier concret

MINT doit montrer:
- marge à retrouver,
- ordre utile des actions,
- prochain remboursement / coupe la plus proche,
- progression visible.

Cap type:
- `Retrouver de l'air ce mois-ci`

Template:
- `DC` puis `HP`

Preuves requises:
- dettes
- mensualités
- budget
- taux ou ordre de priorité

Interdits:
- culpabilisation
- rouge sans levier
- mur de sliders

État MINT aujourd'hui:
- [budget_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/budget/budget_screen.dart) est traité (`10/10`).
- le mini-hub dette existe déjà via `debt_ratio`, `repayment`, `help_resources`, `debt_risk_check`, `consumer_credit`.
- plusieurs de ces sous-écrans restent hors niveau `10/10` homogène.

Ce qui est déjà fort:
- très bon territoire de fidélisation,
- `CapEngine` sait déjà détecter dette et déficit budget,
- bonne intuition produit vs Cleo.

Ce qu'il reste à fermer:
- faire de la dette un vrai parcours coeur unifié,
- rendre la progression visible au-delà du diagnostic,
- consolider le hub dette dans `Explorer`,
- relier dette, budget et aide pro dans une séquence cohérente.

---

### 9. Passage à l'indépendance

Pourquoi:
- sujet suisse à très forte valeur
- LPP, IJM, 3a, AVS, dividende/salaire

MINT doit montrer:
- ce qui disparaît du filet salarié,
- ce qu'il faut reconstruire,
- les arbitrages prioritaires.

Cap type:
- `Reconstruire mon filet`

Template:
- `RF` + `DC`

Preuves requises:
- revenu estimé
- statut
- LPP
- charges

Interdits:
- ton trop technique d'entrée
- noyer AVS/LPP/IJM sans hiérarchie

État MINT aujourd'hui:
- [independant_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/independant_screen.dart) est traité (`10/10`).
- les sous-outils AVS / IJM / 3a / LPP volontaire / dividende vs salaire sont encore plus hétérogènes.

Ce qui est déjà fort:
- c'est un des domaines où MINT a un vrai avantage suisse,
- le sujet "reconstruire le filet" est très différenciant.

Ce qu'il reste à fermer:
- clarifier la hiérarchie entre les sous-sujets,
- éviter la dispersion outillage,
- faire remonter plus clairement le `Cap` de filet manquant / LPP volontaire / IJM.

---

### 10. Frontalier

Pourquoi:
- sujet structurellement complexe en Suisse
- impact fiscal, assurance maladie et statut très supérieur à un simple déménagement

MINT doit montrer:
- où se situe le vrai arbitrage,
- ce qui change côté impôt source, LAMal / CMU, 90 jours, retraite,
- quelles pièces et décisions comptent réellement.

Cap type:
- `Clarifier mon statut frontalier`

Template:
- `RF` puis `DC`

Preuves requises:
- pays de résidence
- canton de travail
- permis / statut
- revenus
- choix couverture santé si existant

Interdits:
- simplifier à "vivre d'un côté, travailler de l'autre"
- ignorer les spécificités fiscales et LAMal
- ton administratif sans hiérarchie

État MINT aujourd'hui:
- [frontalier_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/frontalier_screen.dart) existe et fait partie des parcours importants, mais il doit être reclassé comme noyau stratégique.

Ce qui est déjà fort:
- le sujet est déjà couvert dans le codebase,
- forte valeur ajoutée suisse vs apps généralistes.

Ce qu'il reste à fermer:
- faire remonter frontalier dans le noyau et le `CapEngine`,
- relier fiscalité, santé, retraite et statut dans une progression unique,
- mieux distinguer preuve, hypothèse et zone d'incertitude.

---

### 11. Divorce / séparation

Pourquoi:
- charge émotionnelle très forte
- impacts multiples: LPP, pension, logement, impôts

MINT doit montrer:
- points à clarifier,
- zones de risque,
- ordre logique des sujets,
- simulations éducatives et non juridiques.

Cap type:
- `Clarifier ce qui change maintenant`

Template:
- `RF`

Preuves requises:
- enfants
- revenus
- logement
- prévoyance

Interdits:
- ton léger
- fausse précision juridique

État MINT aujourd'hui:
- [divorce_simulator_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/divorce_simulator_screen.dart) est traité (`10/10`).

Ce qui est déjà fort:
- bon sujet émotionnel et utile,
- très légitime dans le positionnement éducatif suisse.

Ce qu'il reste à fermer:
- mieux séquencer pension / LPP / logement / budget,
- renforcer les preuves et limites juridiques,
- relier divorce à un vrai parcours de stabilisation, pas juste à une simulation.

---

### 12. Retraite / décaissement / succession

Pourquoi:
- terrain historique de MINT
- différenciation suisse maximale

MINT doit montrer:
- taux de remplacement,
- scénarios de retrait,
- séquencement fiscal,
- documentation manquante,
- risques survivant / succession si pertinent.

Cap type:
- `Choisir le prochain levier retraite`

Template:
- `HP` + `DC`

Preuves requises:
- AVS
- LPP
- 3a
- libre passage
- horizon de retraite

Interdits:
- rente vs capital prescriptif
- projection sans confiance / hypothèses
- utilisation implicite du `6.8%` comme taux global sur tout le capital LPP

État MINT aujourd'hui:
- c'est le domaine le plus avancé de MINT.
- [retirement_dashboard_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart), [rente_vs_capital_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart), [simulator_3a_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/simulator_3a_screen.dart), [real_return_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/pillar_3a_deep/real_return_screen.dart), [staggered_withdrawal_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart) sont traités.
- des compléments restent à harmoniser: libre passage, EPL, rétroactif 3a, comparator, succession détaillée.

Ce qui est déjà fort:
- c'est la plus grosse profondeur métier du produit,
- c'est l'avantage le plus net face à Cleo et aux apps généralistes.

Ce qu'il reste à fermer:
- faire de ce domaine un système plus lisible que riche,
- mieux relier retraite, décaissement, succession, libre passage et confiance des données,
- éviter que la force métier se transforme en dispersion UX,
- distinguer plus clairement part obligatoire / surobligatoire et fourchette indicative si le certificat LPP manque.

Séquence retraite cible (plan vivant):

Le problème classique (type VZ) est de donner 15 actions en une fois. L'utilisateur en fait 2-3 et pose le reste. MINT doit faire l'inverse : 1 levier à la fois, dans le bon ordre, avec un retour visible après chaque action.

Phase 1 — Clarifier (compléter le dossier):
1. Scanner le certificat LPP → sans lui, tout le reste est flou
2. Vérifier l'extrait AVS → lacunes = rente réduite, irréversible
3. Recenser le 3a (combien de comptes, chez qui) → le séquencement du retrait change l'impôt

Phase 2 — Arbitrer (les 3 grandes décisions):
4. Rente ou capital (ou mixte) → la décision structurante, dépend de l'espérance de vie, du couple, de la fiscalité
5. Timing du retrait 3a → étaler sur 2-3 ans réduit la progressivité fiscale
6. Hypothèque : rembourser ou pas → dépend du taux, du capital retiré, de la fiscalité

Phase 3 — Préparer (les actions concrètes):
7. Dernier rachat LPP → LPP art. 79b al. 3, blocage 3 ans avant retrait
8. Adapter la LAMal → la franchise change quand le revenu baisse
9. Succession / testament / mandat pour inaptitude → souvent oublié, toujours urgent trop tard
10. Budget post-retraite → le train de vie doit s'adapter AVANT le jour J

Phase 4 — Accompagner (post-décision):
11. Déclaration de retrait (timing) → 3 mois avant minimum
12. Vérifier la rente AVS effective → demander le calcul anticipé à la caisse AVS

Règles de séquencement:
- un cap de Phase 2 ne s'ouvre pas tant que les données de Phase 1 ne sont pas là;
- les arbitrages sans certificat LPP affichent des fourchettes très larges avec le message "affine tes données pour voir le vrai chiffre";
- Aujourd'hui montre la progression : "3/12 étapes clarifiées";
- chaque cap complété met à jour la confiance, les projections et le prochain cap;
- le coach peut accélérer en expliquant pourquoi l'ordre compte.

Ce que MINT fait mieux qu'un dossier VZ:
- 1 levier à la fois (pas 15 en une fois),
- plan vivant qui se met à jour (pas snapshot figé),
- progression visible chaque jour (pas rendez-vous dans 1 an),
- rappel intelligent quand le contexte change (pas de rappel du tout chez VZ),
- gratuit / freemium (pas 2'000-5'000 CHF la consultation).

---

## 3. Règle produit commune

Pour chacun de ces 10 parcours, MINT doit être excellent sur:
- déclencheur clair,
- un fait ou chiffre dominant,
- une progression visible,
- un levier suivant,
- les preuves ou documents requis,
- le bon niveau de ton,
- la preuve accessible,
- le disclaimer suisse approprié.

Si un parcours n'offre pas cela, il n'est pas "coeur MINT".

---

## 3.1 Lecture produit de l'état actuel

### Déjà très solides
- premier emploi
- changement d'emploi / comparaison
- chômage
- naissance
- indépendance
- divorce
- grande partie retraite / arbitrages

### Solides mais encore fragmentés
- invalidité / protection
- logement / hypothèque
- dette / budget
- frontalier
- retraite élargie (libre passage, succession, rétroactif 3a)

### Encore à mettre au niveau du noyau
- concubinage
- certaines jonctions couple / documents / progression
- certains flows de preuve et de capture liés aux caps

---

## 3.2 Ce qu'il faut encore faire pour atteindre le but

Avant de poursuivre le reste du codebase, MINT doit:

1. rendre ces 10 parcours cohérents entre eux,
2. faire remonter leur logique dans `Aujourd'hui` via le `CapEngine`,
3. afficher une progression lisible vers le but du moment,
4. lier chaque parcours à ses preuves réelles (documents, données, hypothèses),
5. rendre le coach vraiment utile sur ces sujets sans devenir bavard ni prescriptif,
6. harmoniser les sous-outils encore éclatés autour de parcours lisibles.

En pratique, le vrai travail restant n'est pas d'ajouter 50 écrans.

C'est de:
- mieux relier ce qui existe,
- mieux hiérarchiser,
- mieux mettre en scène la progression,
- et rendre ces 10 parcours irréprochables.

---

## 4. Ce qui doit rester secondaire

Les sujets utiles mais moins structurants peuvent rester en second cercle:
- déménagement cantonal
- expatriation
- variantes avancées d'invalidité / protection
- variantes d'assurance
- outils annexes patrimoniaux

Ils comptent, mais ils ne doivent pas dicter la grammaire produit avant le noyau.

---

## 5. Phrase de pilotage

**Le standard MINT se définit sur les situations qui bouleversent réellement la vie financière suisse.**

**Le reste doit s'aligner sur ce niveau, pas l'inverse.**
