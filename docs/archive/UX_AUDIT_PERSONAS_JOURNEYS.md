# UX Research: Personas, Journeys & Improvement Plan

> **MINT** -- Swiss Financial Education App
> Document produit le 14 fevrier 2026
> Auteur : UX Research Agent (Senior)
> Statut : Reference interne -- ne pas diffuser en externe

---

## Table des matieres

1. [MINT Personas (7 profils)](#1-mint-personas)
2. [Parcours utilisateur optimaux](#2-parcours-utilisateur-optimaux)
3. [Bonnes pratiques UX pour apps d'education financiere](#3-bonnes-pratiques-ux)
4. [Problemes UX critiques dans MINT actuel](#4-problemes-ux-critiques)
5. [Plan d'amelioration concret](#5-plan-damelioration)

---

## 1. MINT Personas

### 1.1 Lea -- La jeune pro debutante

| Champ | Valeur |
|---|---|
| Age | 24 ans |
| Canton | VD (Lausanne) |
| Profession | Junior marketing manager, PME |
| Situation familiale | Celibataire, en colocation |
| Revenu net | 4'800 CHF/mois |
| Litteratie financiere | 1/5 -- Ne connait pas la difference entre AVS et LPP |
| Segment technique | `young_professional` (variante low-income) |

**Pain points**
- Recoit sa premiere fiche de salaire et ne comprend pas les deductions (AVS, AC, LPP, impot a la source)
- N'a aucune idee de ce qu'est un 3a, ni pourquoi elle devrait s'y interesser maintenant
- Ses parents ne sont pas suisses -- aucune transmission de savoir financier local
- Se sent "trop jeune pour s'en occuper" mais sent confusement que ca compte

**Objectifs**
- Comprendre sa fiche de salaire en 5 minutes
- Savoir combien elle peut epargner par mois sans se priver
- Ouvrir son premier 3a si c'est vraiment utile

**Features MINT prioritaires**
1. Premier emploi (ecran `/first-job`) -- decomposition du salaire
2. Wizard onboarding -- diagnostic rapide de sa situation
3. Simulateur 3a -- visualiser l'economie fiscale concrete
4. Budget simplifie -- categorisation automatique des charges fixes

**Ce qui la ferait abandonner**
- Jargon financier non explique des le premier ecran (LPP, EPL, LIFD = alien)
- Questionnaire trop long avant de voir un resultat concret
- Ton condescendant ou moralisateur ("tu devrais...")

**Ce qui la ferait rester**
- Un "chiffre choc" immediat : "Tu travailles jusqu'au 12 mars pour payer tes impots"
- Des micro-lecons de 2 minutes avec un ton copain
- Le sentiment de progresser (badges, score qui augmente)

---

### 1.2 Marc -- Le papa proprietaire

| Champ | Valeur |
|---|---|
| Age | 37 ans |
| Canton | BE (Berne) |
| Profession | Ingenieur software, grande entreprise |
| Situation familiale | Marie, 2 enfants (3 et 6 ans) |
| Revenu net menage | 15'000 CHF/mois (couple) |
| Litteratie financiere | 3/5 -- Connait le 3a, ne connait pas le rachat LPP |
| Segment technique | `family_plan` |

**Pain points**
- Veut acheter un appartement mais ne comprend pas le calcul de capacite d'emprunt
- A un 3a depuis 5 ans mais contribue seulement 3'000 CHF/an au lieu de 7'258 CHF
- Ne sait pas que le rachat LPP existe, ni que c'est le levier fiscal le plus puissant pour lui
- Sa femme travaille a 60% : il ne realise pas l'impact sur sa rente LPP future

**Objectifs**
- Savoir s'il peut acheter a Berne avec son revenu
- Optimiser sa charge fiscale (il paie ~25'000 CHF/an d'impots)
- Comprendre la strategie EPL (retrait LPP + 3a pour l'apport)

**Features MINT prioritaires**
1. Capacite d'achat (`/mortgage/affordability`) -- simulation complete
2. Rachat echelonne LPP (`/lpp-deep/rachat`) -- levier fiscal
3. Gender gap prevoyance (`/segments/gender-gap`) -- pour sa femme
4. Naissance et famille (`/naissance`) -- deductions et allocations

**Ce qui le ferait abandonner**
- Ne pas trouver le simulateur hypothecaire en moins de 2 taps
- Des resultats generiques non personnalises a son canton (BE)
- Devoir re-saisir ses donnees entre les simulateurs

**Ce qui le ferait rester**
- Un rapport complet apres le wizard avec un "plan d'action en 3 etapes"
- La possibilite de partager le rapport en PDF avec sa femme
- Des rappels contextuels ("Verse avant le 20 dec pour la deduction 3a")

---

### 1.3 Priya -- L'expat desorientee

| Champ | Valeur |
|---|---|
| Age | 31 ans |
| Canton | ZH (Zurich) |
| Profession | Data scientist, fintech |
| Situation familiale | En couple (non mariee), pas d'enfants |
| Revenu net | 9'500 CHF/mois |
| Litteratie financiere | 2/5 pour la Suisse (4/5 pour les concepts generaux) |
| Segment technique | `young_professional` (variante expat) |

**Pain points**
- Comprend la finance en general (elle a un MSc) mais le systeme suisse est un labyrinthe
- 3 piliers ? Splitting ? Valeur locative ? Impot communal ? -- rien n'est intuitif
- N'a pas de 3a apres 2 ans en Suisse parce que personne ne lui a explique
- Anxiete : "Est-ce que je rate quelque chose d'important ?"

**Objectifs**
- Comprendre le systeme des 3 piliers en 10 minutes
- Ouvrir un 3a au bon endroit (banque vs fintech vs assurance)
- Savoir si elle a des lacunes AVS (elle a travaille 3 ans a l'etranger)

**Features MINT prioritaires**
1. Hub educatif "J'y comprends rien" (`/education/hub`) -- les bases sans jargon
2. Comparateur 3a (`/3a-deep/comparator`) -- choix concret du provider
3. Expatriation (`/expatriation`) -- lacunes AVS et rattrapage
4. Comparateur fiscal (`/fiscal`) -- comprendre l'impact de son canton

**Ce qui la ferait abandonner**
- Interface uniquement en francais sans support anglais
- Pas de "glossaire" ou d'explication inline pour les termes suisses
- Pas de reponse a la question "Qu'est-ce que je dois faire EN PREMIER ?"

**Ce qui la ferait rester**
- Un parcours "Expat starter" dedie avec les 5 actions cles
- La possibilite de poser des questions via Ask MINT
- Des comparaisons avec son pays d'origine (ex: "En Inde, il n'y a pas de 3a equivalent")

---

### 1.4 Thomas -- Le frontalier complexe

| Champ | Valeur |
|---|---|
| Age | 42 ans |
| Canton | GE (travaille a Geneve, habite en France) |
| Profession | Gestionnaire de patrimoine, banque privee |
| Situation familiale | Divorce, 1 enfant en garde alternee |
| Revenu net | 11'000 CHF/mois |
| Litteratie financiere | 4/5 -- Connait bien la finance mais pas les specificites frontalier/divorce |
| Segment technique | Frontalier + Divorce |

**Pain points**
- Situation fiscale ultra-complexe : impot source GE + declaration en France + convention bilaterale
- Apres le divorce, il a perdu 50% de sa LPP (partage obligatoire) et ne sait pas comment reconstruire
- Veut savoir s'il peut racheter sa LPP en deduisant de l'impot source
- Son fils alterne entre 2 pays -- quelle couverture LAMal/CMU ?

**Objectifs**
- Comprendre sa situation fiscale frontalier post-divorce
- Calculer le montant de son rachat LPP optimal
- Securiser la couverture de son fils entre 2 systemes

**Features MINT prioritaires**
1. Frontalier (`/segments/frontalier`) -- regle des 90 jours, impot source, charges sociales
2. Simulateur divorce (`/life-event/divorce`) -- impact LPP et partage
3. Rachat echelonne LPP (`/lpp-deep/rachat`) -- reconstruction post-divorce
4. Franchise LAMal (`/assurances/lamal`) -- optimisation couverture

**Ce qui le ferait abandonner**
- Pas de prise en compte de la situation frontalier dans le wizard
- Resultats fiscaux ne distinguant pas impot source vs declaration ordinaire
- Manque de nuance sur les conventions bilaterales

**Ce qui le ferait rester**
- Un parcours "Frontalier" dedie qui pose les bonnes questions
- La possibilite de simuler son impot source vs declaration ordinaire
- Un rappel annuel pour le choix CMU/LAMal (deadline octobre)

---

### 1.5 Sophie -- L'independante sans filet

| Champ | Valeur |
|---|---|
| Age | 35 ans |
| Canton | GE (Geneve) |
| Profession | Architecte independante (Sarl) |
| Situation familiale | Concubinage, 2 enfants |
| Revenu net | 12'000 CHF/mois (variable) |
| Litteratie financiere | 2/5 -- Excellente dans son metier, nulle en prevoyance |
| Segment technique | `self_employed` |

**Pain points**
- N'a pas de LPP obligatoire et n'a pas souscrit de LPP volontaire -- zero 2e pilier
- Cotise au 3a mais seulement 7'258 CHF/an au lieu des 36'288 CHF possibles
- Pas d'assurance IJM (indemnite journaliere maladie) -- si elle tombe malade, revenu = 0
- Concubinage = aucune protection legale pour son partenaire

**Objectifs**
- Comprendre ce qu'elle rate en tant qu'independante vs salariee
- Decider si elle doit prendre une LPP volontaire
- Proteger son partenaire et ses enfants sans se marier
- Optimiser sa remuneration (dividende vs salaire)

**Features MINT prioritaires**
1. Independant (`/segments/independant`) -- vue d'ensemble couverture
2. 3a independant (`/independants/3a`) -- plafond majore
3. Concubinage (`/concubinage`) -- checklist de protection
4. IJM (`/independants/ijm`) -- simulation perte de revenu
5. Dividende vs Salaire (`/independants/dividende-salaire`) -- optimisation Sarl

**Ce qui la ferait abandonner**
- Wizard qui assume qu'elle est salariee et ne pose pas les bonnes questions
- Pas de "chiffre choc" sur ce qu'elle perd en ne cotisant pas a la LPP
- Pas de plan d'action clair et etape par etape

**Ce qui la ferait rester**
- Un score "couverture sociale" qui montre ses trous (invalidite, deces, maladie)
- Un simulateur qui compare "avec LPP volontaire" vs "sans" sur 30 ans
- Des rappels trimestriels pour les cotisations AVS

---

### 1.6 Roberto -- Le pre-retraite anxieux

| Champ | Valeur |
|---|---|
| Age | 56 ans |
| Canton | TI (Lugano) |
| Profession | Directeur commercial, industrie |
| Situation familiale | Marie, 2 enfants adultes |
| Revenu net menage | 18'000 CHF/mois |
| Litteratie financiere | 3/5 -- A un 3a et une LPP correcte mais n'a jamais fait le calcul global |
| Segment technique | Pre-retraite |

**Pain points**
- A 9 ans de la retraite et n'a jamais calcule sa rente totale (AVS + LPP + 3a)
- Se demande s'il doit prendre le capital LPP ou la rente -- decision irreversible
- A 3 comptes 3a mais ne sait pas quand et comment echelonner les retraits
- Sa femme a travaille a temps partiel pendant 15 ans -- grosse lacune LPP

**Objectifs**
- Calculer sa rente totale et savoir s'il peut maintenir son train de vie
- Decider entre rente et capital LPP (ou un mix)
- Optimiser la fiscalite du retrait 3a (echelonnement)
- Comprendre le gender gap de sa femme et y remedier

**Features MINT prioritaires**
1. Planificateur retraite (`/retirement`) -- simulation AVS + LPP + 3a
2. Rente vs Capital (`/simulator/rente-capital`) -- comparaison detaillee
3. Retrait echelonne 3a (`/3a-deep/staggered-withdrawal`) -- optimisation fiscale
4. Gender gap (`/segments/gender-gap`) -- pour sa femme
5. Filet de securite (`/simulator/disability-gap`) -- les dernieres annees sont critiques

**Ce qui le ferait abandonner**
- Resultats imprecis ou trop generiques (il veut des chiffres exacts)
- Interface "trop jeune" ou gamifiee de facon infantile
- Pas de possibilite d'ajuster les hypotheses (age de retraite, taux de conversion, etc.)

**Ce qui le ferait rester**
- Un rapport PDF detaille a imprimer et discuter avec un conseiller
- La possibilite de comparer 3 scenarios (optimiste, moyen, pessimiste)
- Un calendrier des actions a mener annee par annee jusqu'a la retraite

---

### 1.7 Nadia -- La divorcee en reconstruction

| Champ | Valeur |
|---|---|
| Age | 40 ans |
| Canton | VD (Lausanne) |
| Profession | Enseignante a 80%, ecole primaire |
| Situation familiale | Divorcee, 2 enfants en garde partagee |
| Revenu net | 5'800 CHF/mois |
| Litteratie financiere | 1/5 -- Son ex-mari gerait tout |
| Segment technique | Divorce + reconstruction |

**Pain points**
- Vient de recevoir le partage LPP apres le divorce mais ne comprend pas ce que ca signifie
- N'a jamais gere ses finances seule -- aucune habitude d'epargne
- Doit constituer un fonds d'urgence de zero avec un budget serre
- Stress financier permanent : peur de ne pas y arriver

**Objectifs**
- Reprendre le controle de ses finances (budget, visibilite sur les charges)
- Constituer un fonds d'urgence de 3 mois en 1 an
- Comprendre ce qu'elle a dans sa LPP apres le partage
- Ne plus avoir de dette de leasing (encore 18 mois)

**Features MINT prioritaires**
1. Budget (`/budget`) -- visibilite et controle immediat
2. Check dette (`/check/debt`) -- evaluation du risque
3. Plan de remboursement (`/debt/repayment`) -- strategie de sortie du leasing
4. Simulateur divorce (`/life-event/divorce`) -- comprendre l'impact LPP
5. Aide et ressources (`/debt/help`) -- contacts gratuits

**Ce qui la ferait abandonner**
- Des recommandations d'investissement ou d'optimisation fiscale alors qu'elle n'a meme pas de fonds d'urgence
- Un ton culpabilisant sur les dettes
- Trop d'options, pas assez de guidage ("Par ou je commence ?")

**Ce qui la ferait rester**
- Le mode Protection active automatiquement qui masque les outils non pertinents
- Un plan etape par etape : "Mois 1 : Budget / Mois 2 : Fonds urgence / Mois 6 : 3a"
- Le sentiment d'etre comprise et pas jugee

---

## 2. Parcours utilisateur optimaux

### 2.1 Le schema universel : les 5 phases MINT

```
Phase 1 : DECOUVERTE (Jour 1)
   |
   v
Phase 2 : AHA MOMENT (Minutes 5-15)
   |
   v
Phase 3 : PREMIER RESULTAT TANGIBLE (Jour 1-3)
   |
   v
Phase 4 : HABITUDE (Semaine 2-8)
   |
   v
Phase 5 : AUTONOMIE (Mois 3+)
```

### 2.2 Parcours de Lea (jeune pro)

**Phase 1 : Decouverte (0-5 min)**
1. Decouvre MINT via un TikTok sur "combien tu travailles pour les impots"
2. Ouvre l'app -- voit l'ecran d'onboarding avec "10-15 minutes pour ton diagnostic"
3. Hesite -- 15 minutes c'est long. Mais les 3 cercles la rassurent (structure claire)
4. Clique sur "Commencer mon diagnostic"

**Phase 2 : Aha Moment (5-15 min)**
1. Question stress : choisit "Maitriser mon budget" -- se sent entendue
2. Repond aux questions profil (5 questions, 2 min) -- facile et rapide
3. Arrive a la question "Revenu net" -- saisit 4'800 CHF
4. **AHA** : Insight fiscal apparait : "Tu travailles jusqu'au 18 fevrier pour payer tes impots (1.5 mois)" -- reaction : "Ah quand meme !"
5. Question 3a -- insert educatif s'ouvre automatiquement, explique en 30 secondes
6. **AHA** : "En ouvrant un 3a, tu economises 960 CHF/an d'impots" -- concret et immediat

**Phase 3 : Premier resultat (15-30 min)**
1. Termine le wizard (25 questions, ~12 min) -- la barre de progression l'a motivee
2. Recoit son rapport avec un score global de 42/100
3. Voit ses 3 priorites : (1) Ouvrir un 3a, (2) Constituer un fonds d'urgence, (3) Comprendre sa fiche de salaire
4. Clique sur "Simuler mon 3a" et voit l'economie sur 40 ans -- impressionnee
5. Partage le chiffre en screenshot a ses amies

**Phase 4 : Habitude (semaines 2-8)**
- Revient 1x/semaine pour verifier son budget
- Recoit une notification en novembre : "Il te reste 6 semaines pour verser sur ton 3a"
- Explore l'onglet "Apprendre" : lit "C'est quoi le 3a ?" et "LPP : Mode d'emploi"
- Score passe de 42 a 58 apres ouverture du 3a

**Phase 5 : Autonomie (mois 3+)**
- Revient 1x/mois pour le suivi budget
- Revient a chaque echeance cle (3a en decembre, declaration fiscale en mars)
- Recommande l'app a ses collegues

---

### 2.3 Parcours de Marc (papa proprietaire)

**Phase 1 : Decouverte (0-5 min)**
1. Decouvre MINT via une recherche Google "calculer capacite achat immobilier suisse"
2. Tombe sur le simulateur de capacite d'achat -- le remplit en 3 min
3. Resultat : "Tu peux acheter jusqu'a 680'000 CHF" -- concret et utile
4. Voit le bouton "Faire un diagnostic complet" -- intrigant

**Phase 2 : Aha Moment (10-20 min)**
1. Lance le wizard -- repond rapidement (profil deja en tete)
2. **AHA n.1** : Insight rachat LPP : "Tu as un potentiel de rachat de 45'000 CHF qui te ferait economiser 13'500 CHF d'impots"
3. **AHA n.2** : "Tu verses 3'000 CHF/an au 3a au lieu de 14'516 CHF (couple). Tu laisses 2'880 CHF d'economie fiscale sur la table"
4. Transition vers le cercle "Patrimoine" -- voit la section immobilier

**Phase 3 : Premier resultat (jour 1-3)**
1. Rapport detaille : score 61/100
2. Plan d'action : (1) Maxer le 3a couple, (2) Racheter la LPP sur 3 ans, (3) Constituer l'apport immo avec EPL
3. Utilise le simulateur EPL combine pour voir l'apport total possible
4. Genere un PDF et le discute avec sa femme le soir

**Phase 4 : Habitude (semaines 2-8)**
- Utilise l'ecran "Suivre" pour tracker la progression de l'apport
- Simule differents scenarios d'achat (prix, commune, hypotheque SARON vs fixe)
- Recoit un rappel pour le versement 3a de decembre

**Phase 5 : Autonomie (mois 6+)**
- A achete un appartement -- utilise MINT pour le suivi hypotheque et valeur locative
- Score a 78/100 -- se sent en controle
- Revient pour les evenements de vie (naissance du 3e enfant ?)

---

### 2.4 Parcours de Nadia (divorcee)

**Phase 1 : Decouverte (0-5 min)**
1. Son avocate lui recommande "une app pour reprendre ses finances en main"
2. Ouvre l'app -- se sent submergee par les options
3. Le wizard commence par "Ton stress financier" -- choisit "Reduire mes dettes"
4. Se sent enfin ecoutee -- quelqu'un pose la bonne question

**Phase 2 : Aha Moment (5-15 min)**
1. Repond aux questions budget -- realise qu'elle depense 103% de son revenu
2. **AHA** : "Apres tes charges fixes, il te reste -180 CHF/mois" -- choc, mais au moins c'est clair
3. Le mode Protection s'active automatiquement
4. Voit uniquement 3 actions prioritaires au lieu de 50 outils -- soulagement

**Phase 3 : Premier resultat (jour 1-7)**
1. Utilise le budget pour identifier 3 postes de depenses a reduire
2. Plan de remboursement du leasing : "Libre dans 18 mois si tu verses 350 CHF/mois"
3. Decouvre les ressources d'aide gratuite (Caritas, centres de desendettement)
4. Commence a tracer ses depenses quotidiennes

**Phase 4 : Habitude (semaines 2-12)**
- Revient 2-3x/semaine pour le suivi budget (c'est son ancrage)
- Mois 2 : le leasing est sous controle, elle commence le fonds d'urgence
- Mois 3 : le mode Protection se desactive, elle decouvre les outils d'optimisation

**Phase 5 : Autonomie (mois 6+)**
- Ouvre son premier 3a -- "Si quelqu'un m'avait dit ca il y a 5 ans..."
- Utilise le simulateur de rente pour anticiper sa retraite a temps partiel
- Score passe de 28 a 55 -- fierte reelle

---

### 2.5 Moments de retour (Return Triggers) -- tous personas

| Trigger | Frequence | Personas concernes |
|---|---|---|
| Notification rappel 3a (decembre) | Annuel | Tous sauf Nadia phase 1 |
| Rappel declaration fiscale (mars) | Annuel | Tous |
| Suivi budget | Hebdo | Lea, Nadia, Sophie |
| Changement de situation (mariage, naissance) | Ponctuel | Marc, Sophie |
| Echeance hypothecaire | Annuel | Marc, Roberto |
| Renouvellement LAMal (novembre) | Annuel | Tous |
| Rappel cotisation AVS (independants) | Trimestriel | Sophie, Thomas |
| Bilan de fin d'annee (decembre) | Annuel | Roberto, Thomas |

---

## 3. Bonnes pratiques UX pour apps d'education financiere

### 3.1 Engagement : le modele Duolingo applique a la finance

**Ce qui fonctionne**
- **Streaks et sequences** : "7 jours consecutifs de suivi budget" -- efficace pour creer l'habitude initiale
- **Progression visible** : Score de sante financiere qui augmente avec chaque action completee
- **Micro-lecons** : Contenu de 2-3 minutes maximum, un concept par session
- **Recompenses d'apprentissage** : "Tu connais maintenant les 3 piliers" (badge) -- pas de points arbitraires
- **Competition sociale anonyme** : "72% des utilisateurs de ton age ont un 3a" -- effet de norming
- **Celebrer les jalons** : Animation quand le 3a est verse, quand le fonds d'urgence est atteint

**Ce qui echoue (gamification toxique)**
- Points/XP sans signification reelle -- la finance est trop serieuse pour du gamification arbitraire
- Classements publics -- la finance est privee et sensible
- Recompenses pour "avoir utilise l'app" vs "avoir agi dans la vie reelle"
- Ton enfantin sur des sujets stressants (dettes, divorce)

**La bonne approche pour MINT**
- Gamifier les **actions** (verser son 3a, constituer le fonds d'urgence) pas l'**usage** de l'app
- Utiliser le score comme un outil de diagnostic, pas comme un jeu
- Les badges doivent correspondre a des connaissances reelles : "Tu comprends la LPP" (apres avoir lu + repondu au quiz)

### 3.2 Progressive disclosure : gerer la complexite

**Principe** : Ne montrer que ce dont l'utilisateur a besoin au moment ou il en a besoin.

**Pattern a 3 niveaux pour MINT**

| Niveau | Contenu | Declencheur |
|---|---|---|
| Niveau 0 -- Immediat | Chiffre choc + 1 phrase | Toujours visible |
| Niveau 1 -- Contextuel | 3-5 points cles + sources legales | Tap sur "Comprendre ce sujet" |
| Niveau 2 -- Expert | Article complet, formules, cas limites | Tap sur "En savoir plus" |

**Application actuelle dans MINT** : Les educational inserts implementent deja ce pattern a travers `EducationalInsertWidget` + `GenericInfoInsertWidget`. Cependant, le `_showEducationalInsert = true` par defaut peut surcharger l'ecran. Recommandation : ouvrir automatiquement uniquement pour les 3-4 premieres questions, puis passer en mode "tap to reveal" pour la suite.

### 3.3 Wizard / Questionnaire : les regles d'or

**Recherche academique et industrielle**

1. **Nombre optimal de questions par session** : 7-15 questions maximum avant la premiere recompense (resultat). MINT en a 25 -- c'est trop si l'utilisateur ne voit rien avant la fin. La solution : montrer des insights intermediaires (deja partiellement implemente avec les insights fiscaux dans le wizard).

2. **Indication de progression** : Obligatoire. 3 patterns possibles :
   - **Barre lineaire** (actuel MINT : `_overallProgress%`) -- simple mais peut decourager si le % progresse lentement
   - **Sections nommees** (actuel MINT : "Profil / Budget / Prevoyance / Patrimoine") -- meilleur, donne du sens
   - **"X sur Y" questions** (actuel : "Question 8/25") -- peut effrayer si Y est grand
   - **Recommandation** : Combiner sections + mini-barre par section. Masquer le total "X/25" et montrer plutot "Question 3/6 -- Budget".

3. **Save & resume** : Critique pour un wizard de 15+ minutes. MINT a deja le `ReportPersistenceService.saveAnswers()` qui persiste dans SharedPreferences, et le `_loadSavedProgress()` dans le wizard. Cependant, le bouton "J'ai deja commence" sur l'onboarding est un TODO qui affiche un SnackBar. Cela doit etre connecte.

4. **Exit / escape hatch** : Le wizard MINT n'a actuellement AUCUN bouton de fermeture (X) ni confirmation avant de quitter. L'utilisateur peut uniquement utiliser le back natif Android ou le swipe iOS, sans confirmation de sauvegarde. C'est un probleme majeur.

5. **Rendre le questionnaire conversationnel** :
   - Utiliser le prenom de l'utilisateur apres la question `q_firstname` (ex: "Marc, parlons de ta prevoyance")
   - Varier les formulations (pas toujours la meme structure question -> choix)
   - Ajouter des reactions contextuelles ("Bonne nouvelle : tu as un 3a !")
   - Les transitions de section (CircleTransitionWidget) sont un bon debut mais l'auto-dismiss apres 3 secondes est trop rapide -- laisser l'utilisateur controler

### 3.4 Navigation dans une app a 50+ features

**Le probleme des "super-apps"** : MINT a 8 categories, 55 outils dans la tools library, 18 types d'evenements de vie, 3 tabs + FAB. C'est enorme.

**Patterns qui fonctionnent**

1. **Entry points contextuels** (vs catalogue) : Ne pas montrer les 55 outils mais seulement les 3-5 pertinents pour l'utilisateur. L'onglet "Maintenant" fait partiellement ca mais affiche encore trop de sections non personnalisees.

2. **Recherche intelligente** : Le `ToolsLibraryScreen` a un champ de recherche -- c'est bien. Ajouter la recherche en langage naturel ("comment payer moins d'impots ?") qui redirige vers le bon outil.

3. **Navigation par objectif** (pas par categorie technique) :
   - "Je veux payer moins d'impots" -> 3a + rachat LPP + comparateur fiscal
   - "Je veux acheter un appart" -> capacite + EPL + SARON vs fixe
   - "Je suis divorce" -> partage LPP + budget + reconstruction

4. **Architecture de l'information** : La hierarchie actuelle (Maintenant / Explorer / Suivre) est bonne conceptuellement mais l'onglet "Maintenant" est une liste verticale interminable avec 12+ sections. Reduire a 3-4 sections maximum, prioriser par profil.

### 3.5 Micro-learning et creation d'habitudes

**Le "Habit Loop" applique a la finance**

```
CUE (declencheur)     -> ROUTINE (action)          -> REWARD (recompense)
Notification push     -> Ouvrir MINT, 2 min         -> Insight + score augmente
Fin de mois           -> Revoir le budget            -> Voir l'epargne reelle
Evenement de vie      -> Consulter le simulateur     -> Plan d'action clair
```

**Patterns recommandes pour MINT**
- **Daily streak** : "Lis 1 concept/jour pendant 21 jours" -- gratuit en effort
- **Weekly check-in** : "Ton resume hebdo : +230 CHF epargnes, score 62/100"
- **Monthly report** : Email/notification avec les faits saillants du mois
- **Seasonal triggers** : Decembre (3a), mars (impots), octobre (LAMal), janvier (resolution)

### 3.6 Construire la confiance par la transparence

**Specifique a la finance : la confiance est le produit**

1. **Montrer les sources** : MINT le fait deja bien avec les references legales dans les inserts (LPP art. X, LIFD art. Y). Continuer.
2. **Montrer les hypotheses** : Le `EducationalInsertWidget` a un `ExpansionTile` pour les hypotheses de calcul -- excellent pattern.
3. **Disclaimer visible mais non intrusif** : Le footer gris avec l'avertissement educatif est bien dosé.
4. **Pas de dark patterns** : Pas de "Offre limitee !", pas de compteur d'urgence, pas de FOMO artificiel.
5. **Controle des donnees** : L'ecran de consentement (`/profile/consent`) existe. Mettre le lien en evidence dans le profil.

---

## 4. Problemes UX critiques dans MINT actuel

### 4.1 CRIT-01 : Wizard sans bouton de sortie ni sauvegarde explicite

**Fichier** : `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/advisor/advisor_wizard_screen_v2.dart`

**Constat** :
- Le `AppBar` du wizard contient uniquement un `IconButton(icon: arrow_back_ios_new)` qui appelle `_goBack()` -- retour a la question precedente
- Il n'y a AUCUN bouton "X" (fermer) ni "Sauvegarder et quitter"
- Si l'utilisateur quitte (via back systeme ou swipe), il n'y a AUCUNE boite de dialogue de confirmation
- Les reponses sont sauvegardees en arriere-plan via `ReportPersistenceService.saveAnswers()` a chaque question, mais l'utilisateur ne le sait pas
- Pas d'indication visuelle "Ta progression est sauvegardee automatiquement"

**Impact** : Eleve. Les utilisateurs qui quittent le wizard pensent avoir perdu leurs reponses et ne reviennent pas. Ceux qui veulent "juste regarder" se sentent pieges dans un flux lineaire sans issue.

**Severite** : 5/5

---

### 4.2 CRIT-02 : "J'ai deja commence" est un placeholder non fonctionnel

**Fichier** : `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart` (lignes 182-189)

**Constat** :
```dart
TextButton(
  onPressed: () {
    // TODO: Reprendre diagnostic sauvegarde
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalite a venir : reprendre ou tu t\'es arrete')),
    );
  },
  child: const Text('J\'ai deja commence mon diagnostic'),
),
```
Le bouton affiche un SnackBar d'erreur. Or, la fonctionnalite de sauvegarde/reprise existe deja (`ReportPersistenceService.loadAnswers()` et `_loadSavedProgress()` dans le wizard). Il suffit de connecter les deux.

**Impact** : Moyen-Eleve. Les utilisateurs qui reviennent apres une interruption pensent que leur progression est perdue.

**Severite** : 4/5

---

### 4.3 CRIT-03 : 55 outils sans priorisation personnalisee

**Fichier** : `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/tools_library_screen.dart`

**Constat** :
- 55 outils repartis en 8 categories statiques
- Aucune personnalisation basee sur le profil utilisateur
- Aucun label "Recommande pour toi" ni "Pertinent pour ta situation"
- L'ordre est fixe (Prevoyance en premier) quel que soit le profil
- Pour Nadia (divorcee, endettee), le premier outil affiche est "Planificateur retraite" -- completement hors sujet

**Impact** : Eleve. L'utilisateur moyen ne sait pas par ou commencer face a 55 options. Decision fatigue -> abandon.

**Severite** : 4/5

---

### 4.4 CRIT-04 : Pas de "Que faire maintenant ?" clair apres le wizard

**Fichier** : `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart`

**Constat** :
- Le rapport affiche un score global, des scores par cercle, et des "priority actions"
- Mais il n'y a pas de bouton "Commencer l'action n.1" qui redirige vers l'outil concret
- Le `SafeModeGate` bloque les recommandations si l'utilisateur a des dettes -- bien, mais le message de remplacement ("Priorite au desendettement") n'a pas de CTA
- Apres avoir lu le rapport, l'utilisateur est renvoye a la navigation principale sans guidage

**Impact** : Tres eleve. C'est le moment critique de conversion (wizard termine -> action reelle). Le laisser en suspens, c'est gaspiller tout l'investissement du wizard.

**Severite** : 5/5

---

### 4.5 CRIT-05 : Transitions de section (CircleTransitionWidget) jarring et non skippables

**Fichier** : `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/widgets/circle_transition_widget.dart`

**Constat** :
- La transition est un fullscreen modal avec une animation elastique de 1200ms
- Auto-dismiss apres 3 secondes via `Future.delayed`
- L'utilisateur PEUT taper pour dismiss, mais rien ne l'indique visuellement
- 3 transitions dans le wizard (Profil->Budget, Budget->Prevoyance, Prevoyance->Patrimoine) = 9 secondes d'attente forcee si l'utilisateur ne sait pas qu'il peut taper
- Pas d'indication "Touche pour continuer" ni de bouton "Continuer"

**Impact** : Moyen. Ca brise le flux et peut frustrer les utilisateurs presses.

**Severite** : 3/5

---

### 4.6 CRIT-06 : Inserts educatifs ouverts par defaut -- surcharge cognitive

**Fichier** : `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/widgets/wizard_question_widget.dart` (ligne 31)

**Constat** :
```dart
bool _showEducationalInsert = true; // Auto-ouvert pour "just-in-time"
```
- 16 questions sur 25 ont un insert educatif (`EducationalInsertService.questionsWithInserts`)
- Chaque insert est ouvert par defaut et prend 200-400px d'espace vertical
- L'utilisateur doit scroller au-dela de l'insert pour trouver les options de reponse
- Sur mobile (ecran 375px de large), l'insert peut pousser les choix de reponse completement hors ecran
- Pour les utilisateurs avec une bonne litteratie financiere (Thomas, Roberto), c'est du bruit

**Impact** : Moyen-Eleve. Allonge le wizard de 5-7 minutes supplementaires et cree de la fatigue.

**Severite** : 4/5

---

### 4.7 CRIT-07 : Le compteur "Question X/25" decourage

**Fichier** : `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/advisor/advisor_wizard_screen_v2.dart` (ligne 209)

**Constat** :
```dart
Text('Question ${_currentQuestionIndex + 1}/${_questions.length}')
```
- Affiche "Question 3/25" -- l'utilisateur voit qu'il reste 22 questions et peut abandonner
- Le nombre total (25) inclut les questions conditionnelles qui ne seront pas posees (certaines sont skippees par `WizardConditionsService`)
- Le vrai nombre de questions pour un profil donne est typiquement 18-22, pas 25
- La barre de progression avance en saccades (saute quand des questions sont skippees)

**Impact** : Moyen. Effet psychologique negatif sur la motivation.

**Severite** : 3/5

---

### 4.8 CRIT-08 : L'onglet "Maintenant" est une longue liste non priorisee

**Fichier** : `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/main_tabs/now_tab.dart`

**Constat** :
- L'onglet affiche 12 sections empilees verticalement : Situation, Open Banking, LPP Approfondi, Coaching, Actions, Assurances, Segments, Timeline, Evenements de vie, Prochains pas, Decouvrir les outils
- Aucune personnalisation : un utilisateur sans LPP voit quand meme "LPP Approfondi"
- Le scroll est tres long (~4 ecrans complets)
- Pas de hierarchie visuelle forte entre les sections (toutes ont le meme poids visuel)

**Impact** : Moyen. L'utilisateur ne sait pas ou regarder. Les sections basses ne sont probablement jamais vues.

**Severite** : 3/5

---

### 4.9 CRIT-09 : Aucun mecanisme d'onboarding progressif

**Constat** :
- L'utilisateur a 2 options a l'arrivee : faire le wizard complet (15 min) ou naviguer librement sans contexte
- Pas de "wizard light" de 3 questions pour un resultat instantane
- Pas de tutorial overlay ni de tooltips de decouverte pour les premieres utilisations
- Pas d'etat "empty state" pedagogique quand l'utilisateur n'a pas encore rempli son profil

**Impact** : Eleve. Les utilisateurs avec peu de temps ou de patience n'entreront jamais dans le wizard complet.

**Severite** : 4/5

---

### 4.10 CRIT-10 : Incoherence du tutoiement dans l'interface

**Constat** :
- La plupart de l'interface utilise le "tu" informel (conforme aux regles MINT)
- Mais certains ecrans utilisent le "vous" formel :
  - `AdvisorSessionFocusScreen` : "votre profil", "vos bases financieres"
  - `NowTab` en mode normal : "Conseils personnalises selon votre profil"
  - Certains labels de l'onglet Maintenant : "Connectez vos comptes bancaires", "Evaluez votre protection"
- L'education.inserts utilisent "tu" systematiquement

**Impact** : Faible-Moyen. Casse l'experience de marque et donne une impression d'app "assemblee en pieces".

**Severite** : 2/5

---

## 5. Plan d'amelioration concret

### Matrice Impact / Effort

| ID | Issue | Impact | Effort | Score (I/E) | Priorite |
|---|---|---|---|---|---|
| CRIT-01 | Wizard sans sortie | 5 | 2 | 2.5 | **P0** |
| CRIT-04 | Pas de "next step" post-wizard | 5 | 3 | 1.7 | **P0** |
| CRIT-02 | "J'ai deja commence" placeholder | 4 | 1 | 4.0 | **P1** |
| CRIT-07 | Compteur "X/25" decourage | 3 | 1 | 3.0 | **P1** |
| CRIT-05 | Transitions jarring | 3 | 1 | 3.0 | **P1** |
| CRIT-06 | Inserts ouverts par defaut | 4 | 2 | 2.0 | **P1** |
| CRIT-09 | Pas d'onboarding progressif | 4 | 4 | 1.0 | **P2** |
| CRIT-03 | 55 outils non priorises | 4 | 4 | 1.0 | **P2** |
| CRIT-08 | Onglet Maintenant trop long | 3 | 3 | 1.0 | **P2** |
| CRIT-10 | Tutoiement incoherent | 2 | 1 | 2.0 | **P3** |

### Implementations recommandees

---

#### P0-A : Wizard -- Bouton de sortie + sauvegarde explicite

**Impact** : 5/5 | **Effort** : 2/5

**Implementation** :
1. Ajouter un `IconButton(Icons.close)` dans les `actions` de l'AppBar du wizard
2. Au tap, afficher un `showModalBottomSheet` avec 3 options :
   - "Sauvegarder et quitter" (sauvegarde deja en place via `ReportPersistenceService`)
   - "Quitter sans sauvegarder" (appeler `ReportPersistenceService.clear()` puis `context.go('/')`)
   - "Continuer" (fermer le modal)
3. Intercepter le `WillPopScope` (ou `PopScope` en Flutter 3.16+) pour afficher le meme modal sur back natif
4. Ajouter une indication discrète "Tes reponses sont sauvegardees automatiquement" sous la barre de progression

**Fichier a modifier** : `advisor_wizard_screen_v2.dart`

---

#### P0-B : Post-wizard -- Ecran d'actions claires avec CTA

**Impact** : 5/5 | **Effort** : 3/5

**Implementation** :
1. Sur le `FinancialReportScreenV2`, ajouter un `FloatingActionButton` ou un `StickyFooter` avec :
   - "Commencer l'action n.1 : [Titre de la priorite]" -- bouton primaire
   - "Voir toutes les actions" -- lien secondaire
2. Chaque `priorityAction` doit avoir une `route` associee (vers le bon simulateur/outil)
3. Ajouter un ecran intermediaire "Ton Plan en 3 etapes" entre le rapport et la navigation principale :
   - Etape 1 : [Action specifique + bouton "Y aller"]
   - Etape 2 : [Action specifique + bouton "Plus tard"]
   - Etape 3 : [Action specifique + bouton "Plus tard"]
4. Si mode Protection active, l'ecran affiche un plan de desendettement avec des CTA vers `/debt/repayment` et `/debt/help`

**Fichiers a modifier** : `financial_report_screen_v2.dart`, nouveau widget `post_wizard_action_screen.dart`

---

#### P1-A : Connecter le bouton "J'ai deja commence"

**Impact** : 4/5 | **Effort** : 1/5

**Implementation** :
```dart
TextButton(
  onPressed: () async {
    final savedAnswers = await ReportPersistenceService.loadAnswers();
    if (savedAnswers.isNotEmpty) {
      if (context.mounted) context.push('/advisor/wizard');
      // Le wizard detectera les reponses sauvegardees via _loadSavedProgress()
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune progression sauvegardee. Commence un nouveau diagnostic.')),
        );
      }
    }
  },
  child: const Text('Reprendre mon diagnostic'),
),
```
Aussi : renommer le label de "J'ai deja commence" a "Reprendre mon diagnostic" (plus clair).

**Fichier a modifier** : `advisor_onboarding_screen.dart`

---

#### P1-B : Remplacer "Question X/25" par un compteur par section

**Impact** : 3/5 | **Effort** : 1/5

**Implementation** :
- Au lieu de `'Question ${_currentQuestionIndex + 1}/${_questions.length}'`
- Afficher `'Question 3/6 -- Budget'` en calculant la position dans la section courante
- Supprimer le total global (25) qui effraie
- Garder le pourcentage global (deja present : `_overallProgress%`) comme seul indicateur de progression totale

**Fichier a modifier** : `advisor_wizard_screen_v2.dart`

---

#### P1-C : Transitions de section -- ajouter un CTA et raccourcir

**Impact** : 3/5 | **Effort** : 1/5

**Implementation** :
1. Reduire l'auto-dismiss de 3 secondes a "pas d'auto-dismiss" -- laisser l'utilisateur contrôler
2. Ajouter un bouton "Continuer" visible sous la description
3. Ajouter un texte discret "Touche n'importe ou pour continuer"
4. Ajouter un resume rapide du cercle precedent : "Cercle 1 complete -- Score : 7/10"

**Fichier a modifier** : `circle_transition_widget.dart`

---

#### P1-D : Inserts educatifs -- fermes par defaut sauf les 3 premiers

**Impact** : 4/5 | **Effort** : 2/5

**Implementation** :
1. Passer `_showEducationalInsert = false` comme valeur par defaut dans `WizardQuestionWidget`
2. Creer un compteur statique ou un parametre `shouldAutoExpand` base sur l'index de la question
3. Regles :
   - Questions 1-3 : insert ouvert par defaut (onboarding, apprentissage du pattern)
   - Questions 4+ : insert ferme, bouton "Comprendre ce sujet" visible
   - Si l'utilisateur a choisi "Je ne sais pas" a une question precedente liee, ouvrir l'insert
4. Reduire la hauteur par defaut des inserts (condensed mode) : chiffre choc seulement, expandable pour le detail

**Fichier a modifier** : `wizard_question_widget.dart`, `educational_insert_service.dart`

---

#### P2-A : Onboarding progressif -- Wizard "Light" de 3 questions

**Impact** : 4/5 | **Effort** : 4/5

**Implementation** :
1. Creer un mini-wizard de 3 questions :
   - "Quel est ton stress financier n.1 ?" (q_financial_stress_check)
   - "Quel age as-tu ?" (q_birth_year)
   - "Quel canton ?" (q_canton)
2. Avec ces 3 reponses, generer immediatement un "mini-diagnostic" :
   - 1 chiffre choc (ex: "Tu travailles X jours pour payer tes impots dans le canton Y")
   - 3 outils recommandes
   - Bouton "Aller plus loin" pour le wizard complet
3. Stocker les 3 reponses pour pre-remplir le wizard complet si l'utilisateur continue

**Nouveaux fichiers** : `mini_wizard_screen.dart`, `mini_report_widget.dart`

---

#### P2-B : Priorisation personnalisee des outils

**Impact** : 4/5 | **Effort** : 4/5

**Implementation** :
1. Creer un `ToolRelevanceService` qui score chaque outil selon le profil :
   - Pas d'emploi -> `first-job` et `unemployment` en haut
   - A des dettes -> `debt/repayment` en haut, investissement en bas
   - Independant -> outils independant remontes
   - Age 55+ -> retraite et rente vs capital remontes
2. Ajouter un badge "Pour toi" sur les outils les plus pertinents
3. Option de filtre : "Pertinents pour moi" (defaut) / "Tous les outils"
4. Dans l'onglet "Maintenant", ne montrer que les 3 sections les plus pertinentes

**Fichiers a modifier** : `tools_library_screen.dart`, nouveau `tool_relevance_service.dart`

---

#### P2-C : Onglet Maintenant -- condensation et priorisation

**Impact** : 3/5 | **Effort** : 3/5

**Implementation** :
1. Reduire de 12 sections a 5 maximum :
   - **Section hero** : 1 carte situationnelle (diagnostic / mode protection / action urgente)
   - **Actions** : Top 3 recommandations personnalisees (deja present, garder)
   - **Timeline** : Prochaines echeances (garder mais condenser)
   - **Decouvrir** : 1 scroll horizontal de 6 outils (garder mais personaliser)
   - **Evenements de vie** : 1 scroll horizontal (garder)
2. Deplacer les sections moins prioritaires vers l'onglet "Explorer" :
   - Open Banking, LPP Approfondi, Assurances, Segments -> Explorer
3. Les sections affichees dependent du profil :
   - Si pas de wizard complete -> Hero = CTA wizard
   - Si dettes -> Hero = mode protection + plan de desendettement
   - Si profil complet -> Hero = score + progression

**Fichier a modifier** : `now_tab.dart`

---

#### P3 : Harmoniser le tutoiement

**Impact** : 2/5 | **Effort** : 1/5

**Implementation** :
1. Rechercher toutes les occurrences de "vous/votre/vos" dans le code Dart front-end
2. Remplacer par "tu/ton/ta/tes" conformement aux regles MINT
3. Verifier aussi les chaines i18n dans les fichiers `.arb`
4. Ajouter une regle lint ou un test de conformite qui detecte "vous" dans le code front-end

**Fichiers a modifier** : `advisor_focus_screen.dart`, `now_tab.dart`, et tout fichier avec "vous/votre"

---

## Annexe A : Metriques de suivi recommandees

| Metrique | Cible | Mesure |
|---|---|---|
| Taux de completion du wizard | > 65% | Debute vs termine |
| Time to first value | < 5 min | Premier chiffre choc affiche |
| Retention J7 | > 40% | Retour dans les 7 jours |
| Retention J30 | > 25% | Retour dans les 30 jours |
| Actions declenchees post-wizard | > 1.5 | Nombre moyen de simulateurs utilises dans les 48h |
| NPS (Net Promoter Score) | > 50 | Enquete in-app trimestrielle |
| Taux d'abandon wizard | < 35% | Quittes avant la fin / debutes |
| Couverture du rapport | > 80% | Utilisateurs qui scrollent > 75% du rapport |

## Annexe B : Benchmark concurrentiel

| App | Forces a emprunter | Faiblesses a eviter |
|---|---|---|
| **YNAB** | Methode budgetaire claire, philosophie educative, onboarding guide | Trop americain, pas adapte au systeme suisse |
| **Duolingo** | Streaks, micro-lecons, progression visible, ton ludique | Gamification excessive, pas adapte a la finance serieuse |
| **Revolut** | Interface epuree, acces rapide aux features, analytics | Pas educatif, pas suisse, dark patterns d'upsell |
| **N26** | Design minimal, spaces (sous-comptes), categorisation auto | Pas de contenu educatif, pas de systeme de prevoyance |
| **Finpension** | Specifique suisse, comparateur 3a, pillar tracker | Pas d'education, pas de budget, pas de vie events |
| **Selma Finance** | Onboarding conversationnel, scoring automatique | Focus investissement uniquement, pas educatif |

## Annexe C : Recommandations UX par persona (resume)

| Persona | Top 3 améliorations | Feature manquante critique |
|---|---|---|
| Lea (24, debutante) | Wizard light, inserts fermes, chiffre choc immediat | Parcours "Premier emploi" en homepage |
| Marc (37, proprietaire) | Post-wizard CTA, EPL combine, rappels 3a | Suivi de progression vers l'achat |
| Priya (31, expat) | Glossaire inline, parcours expat dedie, support EN | Comparaison systeme suisse vs pays d'origine |
| Thomas (42, frontalier) | Wizard adapte frontalier, impot source vs ordinaire | Calculateur convention bilaterale |
| Sophie (35, independante) | Score couverture sociale, IJM warning, 3a majore | Comparaison "avec vs sans LPP volontaire" |
| Roberto (56, pre-retraite) | Rente vs Capital, echelonnement 3a, scenarios | Calendrier annuel pre-retraite (9 ans) |
| Nadia (40, divorcee) | Mode Protection actif, budget prioritaire, plan etapes | Parcours "Reconstruction financiere" guide |

---

> **Note** : Ce document est a usage interne. Il ne constitue pas un delivrable client.
> Les recommendations sont basees sur l'analyse du code source au 14 fevrier 2026
> et sur les bonnes pratiques UX documentees dans la litterature academique et industrielle.
