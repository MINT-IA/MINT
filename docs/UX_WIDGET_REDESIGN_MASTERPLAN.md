# UX Widget Redesign Masterplan — MINT

> **Objectif** : Transformer chaque écran MINT en expérience "mindblowing" pour un novice du système suisse des 3 piliers.
> **Méthode** : Audit créatif par un panel senior (Flutter, actuaire, data science fintech suisse).
> **Date de création** : 2026-03-07

---

## CHARTE DE DESIGN MINT — "Comprendre en 3 secondes, agir en 30"

### Philosophie

MINT n'est pas un dashboard financier. C'est un **traducteur** entre le monde des actuaires et celui des humains. Chaque écran doit passer le test du **bar PMU** : si tu ne peux pas l'expliquer à un collègue autour d'un café, c'est trop compliqué.

### Les 7 lois MINT

| # | Loi | Signifie | Anti-pattern |
|---|-----|----------|-------------|
| **L1** | **CHF/mois d'abord** | Tout se traduit en impact mensuel. Pas de montants annuels, pas de pourcentages abstraits sans ancrage. | "Taux de conversion 6.8%" sans dire ce que ça fait en francs |
| **L2** | **Avant → Après** | Chaque décision se montre comme un delta. L'utilisateur voit sa situation actuelle vs. le changement. | Un simulateur qui montre un résultat isolé sans point de comparaison |
| **L3** | **3 niveaux max** | Novice voit 3 infos. Curieux en voit 6. Expert débloque le cockpit. Jamais 15 composants d'un coup. | Un scroll infini de graphiques sans hiérarchie |
| **L4** | **Raconte, ne montre pas** | Chaque chiffre est accompagné d'une phrase humaine qui dit "et alors ?". | Un graphique sans légende narrative |
| **L5** | **Une action, pas un cours** | Chaque écran finit par "Que faire maintenant ?" — 1 action concrète, pas 10 options. | "Consultez un·e spécialiste" comme seul CTA |
| **L6** | **Le chiffre-choc ouvre** | Chaque écran commence par UN nombre qui fait lever les sourcils. C'est le hook. Le reste est le contexte. | Un formulaire de 8 champs avant de voir un résultat |
| **L7** | **La métaphore bat le graphique** | Si un concept existe dans la vie quotidienne (météo, sandwich, thermomètre, pile de briques), utilise cette métaphore plutôt qu'un chart technique. | Un tornado chart pour un utilisateur qui ne sait pas ce qu'est un pilier |

### Vocabulaire visuel unifié

| Brique | Usage | Pattern |
|--------|-------|---------|
| **Hero CHF/mois** | Première chose visible. Gros nombre + contexte humain. | `36pt Montserrat W800` + phrase sous le nombre |
| **Carte Avant/Après** | Montre l'impact d'une décision | 2 colonnes : gauche grisée (avant) / droite colorée (après) + delta |
| **Slider interactif** | L'utilisateur joue avec UNE variable | Slider + zone colorée (rouge/jaune/vert) + commentaire temps réel |
| **Pile de briques** | Décompose un montant en sources | Blocs empilés, le plus solide en bas |
| **Micro-histoire** | Remplace les analyses de sensibilité | "Et si [situation] → [impact CHF] → [action]" |
| **Thermomètre** | Montre un niveau avec paliers nommés | Barre verticale avec étiquettes humaines |
| **Film en actes** | Raconte une timeline de vie | Acte 1/2/3 avec titre narratif + CHF |
| **Badge Strava** | Gamifie un progrès | Score + benchmark pair + prochaine action pour monter |
| **Chiffre-choc** | Hook émotionnel en entrée | 1 nombre + 1 phrase percutante + source légale |
| **Disclaimer éducatif** | Compliance LSFin | Toujours en footer, jamais anxiogène |

### Tons de voix

| Contexte | Ton | Exemple |
|----------|-----|---------|
| Bonne nouvelle | Fier, félicitations | "Tu es dans le vert. Ton coussin absorbe les imprévus." |
| Neutre / info | Calme, factuel | "Ton AVS sera calculée sur 38 années de cotisation." |
| Alerte douce | Encourageant | "Il te manque 6 années d'AVS. On peut regarder ça ensemble." |
| Alerte sérieuse | Direct, sans panique | "Sans couverture AI, un arrêt de 6 mois = CHF 0 de revenu. Vérifie ta police." |
| Couple | Complice | "Vous avez 5 ans d'écart. Ça crée un creux — mais aussi une opportunité fiscale." |

### Palette émotionnelle

| Émotion | Couleur MINT | Quand |
|---------|-------------|-------|
| Sérénité / vert | `MintColors.primary` | "Ça va", marge positive, objectif atteint |
| Attention douce | `MintColors.accent` (orange) | Donnée manquante, optimisation possible |
| Alerte | `MintColors.error` (rouge) | Risque réel, gap important, deadline proche |
| Neutre / info | `MintColors.info` (bleu) | Explication, contexte, comparaison |
| Couple / partage | `MintColors.purple` | Tout ce qui touche au conjoint |
| Progression | `MintColors.gold` | Score, badge, milestone, félicitations |

---

## SUJET TRANSVERSAL — Maintenir les chiffres à jour

### Architecture actuelle

Le fichier `apps/mobile/lib/constants/social_insurance.dart` est la source unique Flutter :
- **En-tête** : "Valeurs en vigueur: 2025 — Dernière mise à jour: 2025-01-01"
- **Miroir** de `services/backend/app/constants/social_insurance.py` (source de vérité backend)
- **Procédure** : MAJ Python → reporter dans Dart → lancer tests

### Problème

Les constantes suisses changent chaque année (OFAS publie en septembre pour l'année suivante) :
- Rentes AVS, seuils LPP, plafonds 3a, cotisations AC, taux AI
- Taux d'impôt cantonaux (révision annuelle)
- Règles hypothécaires (FINMA peut ajuster les exigences)

### Changements législatifs majeurs à anticiper

| Réforme | Horizon | Impact sur MINT |
|---------|---------|-----------------|
| **Abolition valeur locative** (résidence principale) | ~2028-2029 | `imputed_rental_screen.dart` → conditionner sur date d'entrée en vigueur, garder pour résidences secondaires |
| **Réforme LPP 21** (en discussion) | 2026-2027? | Taux de conversion, seuil d'entrée, bonifications → MAJ massive `social_insurance.dart` |
| **Imposition individuelle** (initiative populaire) | 2026+ | Splitting marié supprimé → impacte `family_service.dart`, `mariage_screen.dart` |

### Proposition : le "Millésime MINT"

Chaque écran affiche discrètement en footer :

```
Calculs basés sur le droit en vigueur au 01.01.2026
Prochaine mise à jour prévue : janvier 2027
```

Et dans le profil admin, un dashboard de millésime :
- Liste des constantes avec leur date de validité
- Alerte quand l'OFAS publie les nouveaux barèmes (septembre N-1)
- Checklist de mise à jour (Python → Dart → Tests → Deploy)

### Note importante pour les mockups

Les chiffres dans les propositions P1-P18 sont des **exemples de FORMAT**, pas des calculs vérifiés. En implémentation, tous les nombres viennent des moteurs de calcul (`ArbitrageEngine`, `MortgageService`, `FamilyService`, etc.) avec les constantes de `social_insurance.dart`. Le mockup dit "le locataire gagne 32k" pour montrer le format — le moteur dira le vrai résultat selon chaque profil.

Pour P3 en particulier : en Suisse, avec les taux actuels (~2.5%), le propriétaire paie souvent MOINS en mensualité que le locataire équivalent. Le "grand match" montrera le résultat réel du moteur, qui peut pencher dans les deux sens selon les paramètres (taux, horizon, appréciation immo, rendement alternatif).

---

## P1 — RETIREMENT DASHBOARD

### Diagnostic

Le dashboard actuel est un cockpit d'avion — techniquement irréprochable, mais un novice voit 15 instruments et ne sait pas où regarder.

| Composant actuel | Problème |
|---|---|
| HeroRetirementCard | Nombre abstrait — "5'234 c'est bien ou pas ?" |
| PillarDecomposition | Jargon des piliers, pas de storytelling |
| ConfidenceBar | Confond précision des données avec fiabilité de la projection |
| MintTrajectoryChart | 3 courbes = confusion, pas de repère émotionnel |
| BudgetGapChart | Waterfall = concept de consultant, pas de novice |
| EarlyRetirementChart | 7 barres = trop de choix, pas de "sweet spot" clair |
| SensitivitySnippet | "Variables testées indépendamment" = incompréhensible |
| CoupleTimelineChart | Phase 1/Phase 2 = jargon, pas d'émotion |
| MonteCarloChart | Probabilités = anxiogène, pas actionnable |
| MintScoreGauge | Score arbitraire sans benchmark |

### Propositions créatives (10)

#### A. Le "Salaire après 65" — Hero repensé

**Lois** : L1 + L2

**Concept** : Arrête de parler de "projection retraite". Parle du nouveau salaire.

```
Ton salaire après 65 ans

Aujourd'hui     →    À la retraite
CHF 8'333          CHF 5'234
 ████████████       ████████

Tu garderas 63% de ton train de vie
"Pour la plupart des ménages,
 60-70% suffit (pas de navette,
 pas de LPP, enfants partis)"
```

L'utilisateur pense en "salaire", pas en "projection". Le ratio 63% avec explication ("tes charges baissent aussi") crée un soulagement immédiat.

#### B. La "Pile de briques" — Piliers vulgarisés

**Lois** : L7 + L4

**Concept** : Remplace les barres horizontales par une métaphore de construction.

```
D'où vient ton argent à 65 ans ?

┌─────────┐  CHF 890   Ton épargne
│ 3a/Libre│  ← "Ce que TU as mis de côté"
├─────────┤
│  LPP    │  CHF 2'410 Ta caisse
│ (2ème)  │  ← "Ton patron et toi, chaque mois"
├─────────┤
│  AVS    │  CHF 1'934 L'État
│ (1er)   │  ← "Garanti par la Confédération"
└─────────┘
      ▲
  Le socle = le plus solide
```

Le novice comprend en 2 secondes que son revenu repose sur 3 sources avec des niveaux de solidité différents.

#### C. Le Slider "Et si je partais à..." — Retraite anticipée simplifiée

**Lois** : L3 + L4

**Concept** : Remplace les 7 barres par UN slider avec 3 zones colorées.

```
Et si je partais à...

58    60    62  63  64  65  66  67  70
─────🔴──────🟡────🟢────────🔵───────
                  ▲
             [CURSEUR]

À 63 ans : CHF 4'510/mois (-14%)
"Tu perds CHF 724/mois à vie.
 Mais tu gagnes 2 ans de liberté.
 Coût total: ~CHF 174k sur 25 ans."
```

Zones :
- 🔴 58-62 : "Risqué — gros sacrifice financier"
- 🟡 63-64 : "Faisable — avec compromis"
- 🟢 65 : "Standard — pas de pénalité"
- 🔵 66-70 : "Bonus — tu gagnes plus mais tu profites moins longtemps"

#### D. La "Météo financière" — Remplacer Monte Carlo

**Lois** : L7 + L4

**Concept** : Personne ne comprend "10'000 simulations à 80% de succès". Tout le monde comprend la météo.

```
Ta météo financière à la retraite

     ☀️  Soleil  (45% des cas)
     Tu vis confortablement — CHF 5'200+/mois

     ⛅  Nuageux (35% des cas)
     Budget serré mais ok — CHF 4'200–5'200/mois

     🌧️  Pluie   (20% des cas)
     Il faudra des ajustements — CHF 3'500–4'200/mois

"Aujourd'hui : ⛅ tendance ☀️"
"Chaque action déplace le curseur"
```

#### E. Les "Histoires et si..." — Remplacer le Tornado

**Lois** : L4 + L5

**Concept** : Au lieu de barres de sensibilité techniques, raconte 3 micro-histoires.

```
Ce qui pourrait tout changer

📈 "Et si ta caisse LPP passait de 1% à 2% de rendement ?"
   → +CHF 320/mois à 65 ans
   → "Vérifie ton relevé LPP pour connaître ton taux"

🏠 "Et si tu déménageais de ZH à TG à la retraite ?"
   → +CHF 280/mois (impôts)
   → "Économie fiscale nette"

⏰ "Et si tu travaillais 1 an de plus (66 au lieu de 65) ?"
   → +CHF 410/mois à vie
   → "1 an de travail = 25 ans de bonus"
```

Chaque histoire finit par une action concrète.

#### F. Le "Film du couple" — Couple timeline narratif

**Lois** : L4 + L2

**Concept** : Les swim lanes sont un outil de chef de projet. Raconte un film en 3 actes.

```
Votre histoire à deux

ACTE 1 · 2026–2041 (15 ans)
"Vous travaillez tous les deux"
Revenus: CHF 13'333/mois
→ Fenêtre pour épargner ensemble

ACTE 2 · 2041–2046 (5 ans)
"Julien est à la retraite, Lauren travaille encore"
Revenus: CHF 10'234/mois (-23%)
→ ⚠️ Le creux : 5 ans de revenu réduit

ACTE 3 · 2046+ (25+ ans)
"Retraite à deux"
Revenus: CHF 8'890/mois
→ Le plateau : vos revenus stabilisés

💡 "Pendant l'Acte 2, le salaire de Lauren compense.
C'est le moment idéal pour retirer le 3a de Julien
(fiscalement avantageux)."
```

Au lieu de 2 barres parallèles, on raconte LEUR vie.

#### G. Le "Budget gap" en sandwich — Remplacer le waterfall

**Lois** : L7 + L1

**Concept** : Le sandwich, tout le monde le comprend.

```
Ton budget retraite

Ce qui rentre     CHF 5'234
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
AVS 1'934 + LPP 2'410 + 3a 540 + Épargne 350

       ↓ moins

Ce qui sort       CHF 4'800
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
Impôts 650 + Loyer 1'500 + LAMal 450 + Quotidien 2'200

       ↓ reste

✅ Marge: CHF 434/mois
"Tu es dans le vert. Ce coussin absorbe les imprévus."
```

Ce qui rentre, ce qui sort, ce qui reste. Point.

#### H. Le "Score Strava" — Fitness financier gamifié

**Lois** : L5 + L7

**Concept** : Le score /100 actuel est arbitraire. Rends-le comparable et motivant.

```
Ta forme financière

       ╭────────╮
      ╱  72/100  ╲
     │   ↑ +3    │
      ╲  ce mois ╱
       ╰────────╯

"Mieux que 65% des 45-55 ans dans ton canton"

Ce qui t'a fait monter :
✅ 3a versé en janvier (+5 pts)
✅ Budget respecté en février (+2 pts)

Ce qui te ferait passer à 80 :
📋 Ajouter ton certificat LPP (+4 pts)
📋 Vérifier ta couverture AI (+4 pts)
```

Le peer benchmark ("mieux que 65%") crée une fierté/urgence. L'historique des gains gamifie l'engagement.

#### I. Le "Thermomètre de confiance" — Remplacer la barre de précision

**Lois** : L7 + L5

**Concept** : La barre de confiance confond précision des données avec fiabilité. Utilise un thermomètre.

```
Qualité de ta projection

   ┌──┐  95%  Photo parfaite
   │██│  ← certificat LPP + relevé AVS
   │██│
   │██│  65%  ← TU ES ICI — Bonne estimation
   │▒▒│
   │▒▒│  40%  Estimation large
   │░░│  20%  On devine beaucoup
   └──┘

Pour monter à 80% :
"Scanne ton certificat LPP, ça prend 30 secondes" [Scanner]
```

#### J. Le "Dashboard progressif" — 3 vues selon la maturité

**Lois** : L3

**Concept** : Adapte la densité au niveau de l'utilisateur.

| Niveau | Ce qu'on montre | Ce qu'on cache |
|--------|----------------|----------------|
| **Novice** (<50% confiance) | Hero "salaire après 65" + Pile de briques + Thermomètre + 1 action | Tout le reste |
| **Intermédiaire** (50-80%) | + Météo + Slider retraite anticipée + Histoires "et si" + Film du couple | Monte Carlo, Tornado, FRI |
| **Expert** (>80% + opt-in) | + Cockpit complet + Monte Carlo + Tornado + Waterfall + FRI radar | Rien de caché |

Un novice qui voit 3 choses comprend. Un novice qui voit 15 choses fuit.

---

## P2 — MARIAGE · DIVORCE · CONCUBINAGE

### Diagnostic

| Constat | Gravité |
|---------|---------|
| Le calcul fiscal utilise un taux fixe de 18% pour les mariés (devrait varier par canton/revenu) | CRIT |
| 4 widgets de visualisation existent mais ne sont utilisés dans aucun écran | MOD |
| Le chiffre-choc succession concubins (75k CHF d'impôt sur 300k) est noyé dans une matrice | CRIT |
| La pension alimentaire utilise 600 CHF/enfant sans source ni explication | MOD |
| Le régime matrimonial ne distingue pas biens propres vs acquêts | MOD |
| Participation aux acquêts et communauté de biens affichent tous les deux 50/50 | LOW |
| Aucun lien vers des ressources, modèles de convention, ou médiateurs | UX |
| Le partenariat enregistré n'existe pas | UX |

### Vision : 3 écrans → 1 question

> "Qu'est-ce qui change dans mon portefeuille quand je change de statut ?"

Fil rouge : Avant / Après / Le prix de ne rien faire.

### Propositions créatives (6)

#### A. Le "Ticket de caisse du mariage"

**Lois** : L1 + L6

L'écran mariage s'ouvre sur un ticket de caisse, pas sur 3 onglets.

```
🧾 TON TICKET DE CAISSE DU MARIAGE

Revenus : 80k + 60k = 140k · Canton : VD
─────────────────────────────
Impôts (2 célibataires)  12'400
Impôts (mariés)          11'200
                         ───────
BONUS MARIAGE         -1'200/an ✅

Mais attention :
AVS plafonnée (couple)  -540/an ⚠️
                         ───────
BILAN NET             -660/an  ✅

"Le mariage t'économise 55 CHF par mois.
 Mais ce n'est pas la vraie raison de se marier..."

👇 La vraie raison est en dessous
```

Scrolle → le vrai chiffre-choc :

```
💀 CE QUE TON CONCUBIN PERD SI TU DÉCÈDES DEMAIN

Marié·e :   CHF 0 d'impôt
            + rente AVS survivant + 60% rente LPP

Concubin·e: CHF 75'000 d'impôt
            + CHF 0 rente AVS + CHF 0 rente LPP*

"La vraie pénalité n'est pas d'être marié.
 C'est de ne PAS l'être sans avoir pris les mesures."
```

Le novice cherche "pénalité de mariage" (un concept média). On lui montre que le vrai risque est ailleurs.

#### B. Le "Film du divorce en 3 actes"

**Lois** : L2 + L4

Le divorce n'est pas un simulateur. C'est une histoire en 3 actes.

```
ACTE 1 · Le partage obligatoire
"Vos LPP accumulés pendant le mariage sont coupés en deux. Point."

  Toi: 180'000    Conjoint·e: 80'000
       ↘               ↙
      130'000      130'000

Tu transfères CHF 50'000
"C'est la loi (CC art. 122). On ne négocie pas."
→ Ta rente LPP baisse de ~CHF 283/mois

ACTE 2 · L'impôt change

  Avant (mariés)       Après (séparés)
  CHF 11'200/an       CHF 12'400/an
  +CHF 1'200/an d'impôts
  "Tu perds le splitting marié. Mais tu gagnes
   la déduction parent isolé si tu as la garde."

ACTE 3 · Les pensions

  Pour 1 enfant :  ~CHF 1'500/mois
  Entretien conjoint·e : ~CHF 500/mois (3-5 ans)
  ⚠️ "La pension versée est déductible de TES impôts.
      Elle est imposable pour l'AUTRE." (LIFD art. 33/23)
```

On raconte l'histoire dans l'ordre chronologique du vécu.

#### C. Le "Match Mariage vs Concubinage"

**Lois** : L7

Remplace la matrice technique par un match en rounds.

```
MARIAGE ⚡ CONCUBINAGE

ROUND 1 · Impôts
🥊 Mariage gagne — "Tu économises CHF 1'200/an"

ROUND 2 · Héritage
🥊🥊🥊 Mariage écrase
"Ton concubin paie CHF 75'000 d'impôt. Ton époux·se : CHF 0."

ROUND 3 · Protection décès
🥊🥊 Mariage gagne
"Rente AVS survivant : CHF 2'520/mois. Concubin : CHF 0."

ROUND 4 · Flexibilité
🥊 Concubinage gagne
"Pas de partage LPP, pas de procédure."

ROUND 5 · Pension alimentaire
🥊 Mariage gagne (pour le plus faible)
"Le conjoint au revenu inférieur est protégé."

VERDICT · Mariage 4 — Concubinage 1
"Le mariage protège. Le concubinage donne la liberté.
 Les deux se planifient."

⚡ Si tu restes concubin, tes 3 urgences :
1. Testament (sinon = 0 CHF)
2. Clause LPP (30 sec par téléphone)
3. Assurance-vie croisée
```

#### D. Le "Régime matrimonial en 30 secondes"

**Lois** : L7 + L3

Remplace le donut chart par une métaphore de tiroirs.

```
PARTICIPATION AUX ACQUÊTS (défaut)
🗄️ Avant le mariage : chacun garde
🗄️ Pendant le mariage : 50/50
"Tout ce que vous avez GAGNÉ ensemble se partage.
 Ce que tu avais AVANT, tu gardes."

SÉPARATION DE BIENS
🗄️ Tout reste séparé. Toujours.
"Ce qui est à toi reste à toi.
 Populaire chez les indépendants et les 2ème mariages."

COMMUNAUTÉ DE BIENS
🗄️ Tout est commun. Tout.
"Rare en Suisse (<5% des couples).
 Tout se partage, même ce qui existait avant."

💡 "80% des Suisses sont en participation aux acquêts sans le savoir."
```

#### E. La "Checklist d'urgence" priorisée

**Lois** : L5

Classe les items par coût de l'inaction, pas par ordre alphabétique.

```
🔴 URGENT (si tu décèdes demain)
□ Testament → sinon : 0 CHF — "5 lignes manuscrites suffisent"
□ Clause LPP → sinon : 0 CHF rente — "1 appel à ta caisse de pension"

🟡 IMPORTANT (ce trimestre)
□ Assurance-vie croisée — "Compense l'absence de rente AVS"
□ Convention de concubinage — "Qui paie quoi, qui garde quoi"
□ Mandat pour inaptitude (CC 360) — "Sinon, c'est la KESB qui décide"

🟢 RECOMMANDÉ (cette année)
□ Directives anticipées (CC 370)
□ Bail commun clarifié
□ Bénéficiaire 3a mis à jour
```

#### F. Le "Pont cassé" — Protection survivant

**Lois** : L2 + L6

Montre visuellement ce qui se passe quand un des deux tombe.

```
SI L'UN DE VOUS DISPARAÎT

MARIÉ·E·S
Julien décède ───→ Lauren reçoit
  Rente AVS survivant   CHF 2'520/mois
  Rente LPP 60%         CHF 1'450/mois
  Capital décès LPP     CHF 180'000
  Total : CHF 3'970/mois + capital

CONCUBIN·E·S (sans protection)
Julien décède ─ ✕ Lauren reçoit
  Rente AVS survivant   CHF 0
  Rente LPP             CHF 0
  Héritage      CHF 300k - 75k impôt
  Total : CHF 0/mois + 225k capital (taxé)

Écart : CHF 3'970/mois à VIE
"Sur 20 ans, c'est CHF 952'800 de protection en moins."

[Que puis-je faire ?] → 3 actions qui comblent 80% du gap
```

---

## P3 — ACHAT IMMOBILIER (housingPurchase)

### Diagnostic

7 écrans dédiés + 1 moteur d'arbitrage. Le mythe "loyer = argent perdu" est le fil rouge.

| Constat | Gravité |
|---------|---------|
| Valeur locative utilise un taux fixe de 3.5% au lieu du taux cantonal réel | CRIT |
| Le loyer n'a PAS d'inflation dans la simulation (0%) → avantage achat surestimé | CRIT |
| Le taux théorique FINMA de 5% confondu avec le taux réel de 2.5% | MOD |
| SARON n'inclut pas la marge bancaire (+0.5-1.5%) | MOD |
| Frais de transaction (notaire 2-3%) non comptés | MOD |
| Retrait LPP/3a affiché brut, pas net d'impôt | CRIT |
| 7 écrans séparés sans narration commune | UX |
| Pas de "breakeven holding period" visible | UX |

### Propositions créatives (7)

#### A. Le "Bilan de match" — Louer vs Acheter démystifié

**Lois** : L6 + L2 + L4

L'écran s'ouvre sur le résultat, pas sur un formulaire. Le chiffre-choc d'abord.

```
LE GRAND MATCH · Louer et investir vs Acheter

Dans 20 ans, ton patrimoine :
  LOCATAIRE           PROPRIÉTAIRE
  CHF 612'000         CHF 580'000

Le locataire gagne de CHF 32'000

"Surpris ? Ton loyer n'est PAS de l'argent perdu.
 C'est le prix de la flexibilité + tu investis la différence."

MAIS : le propriétaire a un TOIT. Le locataire a un PORTEFEUILLE.
Les deux ont raison.
```

Scrolle → décomposition des coûts mensuels :
- Locataire : loyer 2'000 + investit 1'200/mois
- Propriétaire : intérêts 1'460 + amortissement 670 + entretien 670 + valeur locative 400 = 3'200/mois

"La vraie question n'est pas 'louer ou acheter'. C'est : 'Est-ce que je resterai 8+ ans ?'"

#### B. Le "Seuil de rentabilité" — Le seul chiffre qui compte

**Lois** : L1 + L6

Au lieu de 2 courbes qui se croisent, UN nombre.

```
COMBIEN DE TEMPS POUR QUE L'ACHAT SOIT RENTABLE ?

         ╭──────────╮
        │  8 ANS   │
         ╰──────────╯

Avant 8 ans : le locataire gagne
Après 8 ans : le propriétaire rattrape

Ce qui accélère : appréciation immo +1% → 6 ans
Ce qui ralentit : rendement bourse +1% → 10 ans
```

Personne ne veut lire 2 courbes. Tout le monde comprend "8 ans".

#### C. La "Facture cachée du propriétaire" — Valeur locative expliquée

**Lois** : L7 + L4

La valeur locative racontée comme une histoire.

```
LA TAXE LA PLUS BIZARRE DE SUISSE

"Imagine : tu as fini de payer ta maison.
 Tu ne paies plus de loyer. Mais le fisc te dit :
 'Tu AURAIS payé CHF 2'800/mois. On ajoute
  CHF 33'600/an à ton revenu imposable.'"

C'est la VALEUR LOCATIVE.
Tu paies un impôt sur un loyer que tu ne paies pas.

Impact net : ~CHF 200/mois de taxe invisible.

Astuce : "Quand tu auras remboursé ton hypothèque,
tu perdras la déduction intérêts. Certains gardent
exprès un petit crédit pour continuer à déduire."
```

#### D. Le "Crash test FINMA" — Affordabilité gamifiée

**Lois** : L7 + L3

Remplace les jauges par un crash test automobile.

```
CRASH TEST FINMA · "La banque va-t-elle te prêter ?"

Test 1 · Fonds propres (min 20%)
Tes fonds : 200k sur 800k = 25% ✅ PASSÉ
"Attention : LPP net après impôt = CHF 170k, pas 200k"

Test 2 · Charge maximale (≤ 33%)
Taux utilisé : 5% (PAS ton vrai taux !)
Charges théoriques : CHF 4'670/mois
Ton revenu : CHF 10'000/mois → 47% ❌ ÉCHOUÉ

"La banque calcule avec 5% même si le taux réel est 2.5%.
 C'est un stress test : 'Et si les taux remontaient ?'"

Prix maximum : CHF 650'000
```

Le "crash test" est une métaphore universelle. L'explication du 5% lève LE malentendu principal.

#### E. Le "Parcours fléché" — 7 écrans → 1 histoire

**Lois** : L3 + L5

Au lieu de 7 écrans isolés, 1 parcours narratif.

```
TON PARCOURS IMMOBILIER

① Est-ce que je peux acheter ? → Crash test FINMA
   ✅ Prix max : CHF 650k

② D'où viennent mes fonds propres ? → Cash + 3a + LPP
   ⚠️ Attention : impôt de retrait !

③ Quel type d'hypothèque ? → SARON vs Fixe
   💡 SARON = risqué mais moins cher

④ Direct ou indirect ? → Amortissement
   💡 Indirect + 3a = double déduction

⑤ Et la valeur locative ? → La taxe bizarre
   📊 Impact : ~CHF 200/mois

⑥ Au final, louer ou acheter ? → Le grand match
   🎯 Seuil de rentabilité : 8 ans

⑦ Et si je revends un jour ? → Simulation de vente
   💰 Plus-value estimée après impôt
```

Le novice ne sait pas qu'il a 7 questions à se poser.

#### F. Le "Double compteur" — Amortissement direct vs indirect

**Lois** : L2 + L1

2 compteurs côte à côte au lieu de 3 courbes.

```
DIRECT vs INDIRECT : dans 15 ans

                  DIRECT          INDIRECT
Hypothèque :      CHF 550k        CHF 700k
Capital 3a :      CHF 0           CHF 127k
Intérêts payés :  CHF 231k        CHF 262k
Économie fiscale: CHF 0           CHF 32k
────────────────────────────────────────
COÛT NET :        CHF 231k        CHF 103k

L'indirect coûte CHF 128k de MOINS grâce à la double déduction.
⚠️ "Mais ta dette reste à 700k. Si les taux montent, tes intérêts aussi."
```

#### G. Le "Thermomètre SARON" — Stress test visuel

**Lois** : L7 + L4

Au lieu de 3 courbes de coût, un thermomètre de mensualités.

```
ET SI LES TAUX MONTAIENT ?

Hypothèque : CHF 640'000

   5.0%  CHF 2'667/mois  😰 "Tes charges = 40% du revenu"
   3.5%  CHF 1'867/mois  😐 "Ça passe, mais serré"
   2.5%  CHF 1'333/mois  ← AUJOURD'HUI "Confortable"
   1.5%  CHF   800/mois  😊 "Les années dorées (2020)"

"En SARON, chaque hausse de 1% = +CHF 533/mois."

Règle d'or : choisis le SARON uniquement si tu peux
supporter le scénario 5% sans stress.
```

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/arbitrage/location_vs_propriete_screen.dart` | Louer vs acheter |
| `screens/mortgage/affordability_screen.dart` | Crash test FINMA |
| `screens/mortgage/amortization_screen.dart` | Direct vs indirect |
| `screens/mortgage/epl_combined_screen.dart` | Sources fonds propres |
| `screens/mortgage/imputed_rental_screen.dart` | Valeur locative |
| `screens/mortgage/saron_vs_fixed_screen.dart` | SARON vs fixe |
| `screens/housing_sale_screen.dart` | Simulation de vente |
| `services/mortgage_service.dart` | Moteur de calcul |

---

## P4 — INVALIDITÉ (disability) — *Le trou béant que personne ne voit venir*

### Diagnostic

| Écran existant | Ce qu'il fait | Ce qui manque |
|---------------|---------------|---------------|
| `disability_gap_screen.dart` | Écart revenu si invalidité | Zéro émotion, tableau froid, pas de temporalité |
| `disability_insurance_screen.dart` | Couverture APG/AI | Formule technique, pas de scénario vécu |
| `disability_self_employed_screen.dart` | Cas spécial indépendants | Pas de chiffre-choc, le danger mortel n'est pas visible |

**Problème central** : L'invalidité est le risque financier #1 en Suisse (1 personne sur 5 sera touchée avant 65 ans — OFS), mais les écrans MINT la traitent comme un formulaire administratif. Personne ne ressent le danger → personne n'agit.

### Propositions créatives

#### A. La Falaise — Timeline à 3 actes *(L6 + L2 + L7)*

**Concept** : Raconter l'invalidité comme un film en 3 actes temporels — le choc, la chute, le plateau.

```
┌─────────────────────────────────────────────────────────────┐
│  🎬  SI TU NE POUVAIS PLUS TRAVAILLER DEMAIN               │
│                                                              │
│  ╭─────────────╮                                             │
│  │  ACTE 1     │  Jours 1-30 : Ton employeur paie 80%       │
│  │  Le filet   │  Tu touches : 6'667 CHF/mois               │
│  ╰─────┬───────╯                                             │
│        │                                                     │
│        ▼                                                     │
│  ╭─────────────╮                                             │
│  │  ACTE 2     │  Mois 2-24 : L'AI évalue ton cas           │
│  │  L'attente  │  Tu touches : 4'200 CHF/mois (APG)         │
│  │             │  ⏱ Délai moyen de décision AI : 14 mois     │
│  ╰─────┬───────╯                                             │
│        │                                                     │
│        ▼                                                     │
│  ╭─────────────╮                                             │
│  │  ACTE 3     │  Après décision AI :                        │
│  │  Le plateau │  ✅ Rente AI entière : 2'520 CHF/mois       │
│  │             │  ➕ Rente LPP invalidité : ~1'800 CHF       │
│  │             │  ═══════════════════════════════════════     │
│  │             │  TOTAL : 4'320 CHF vs 8'333 avant           │
│  ╰─────────────╯                                             │
│                                                              │
│  💰 CHIFFRE-CHOC : Tu perdrais 4'013 CHF/mois.              │
│     Sur 15 ans = 721'000 CHF de revenu en moins.             │
│                                                              │
│  [Slider: Ton salaire brut ─────●─────── 100'000 CHF/an]    │
│                                                              │
│  → Action : "Vérifie ta couverture LPP invalidité"           │
│                                                              │
│  ℹ️ Outil éducatif · LAVS art. 28-29, LPP art. 23-26        │
└─────────────────────────────────────────────────────────────┘
```

#### B. Le Reset silencieux — Perte d'ancienneté *(L1 + L7)*

**Concept** : Montrer le coût caché invisible — l'invalidité ne détruit pas que ton revenu actuel, elle reset ton ancienneté LPP et tes bonifications.

```
┌─────────────────────────────────────────────────────────────┐
│  ⏪  LE RESET SILENCIEUX                                     │
│                                                              │
│  À 45 ans, tu cotises au taux 15% (LPP art. 16).            │
│  Si invalidité partielle (50%) + reconversion à 48 ans :     │
│                                                              │
│  Avant :  Salaire 100k → bonification LPP = 7'950 CHF/an    │
│  Après :  Salaire  55k → bonification LPP = 2'915 CHF/an    │
│                                                              │
│  ╔══════════════════════════════════════╗                     │
│  ║  Ton 2e pilier à 65 ans :           ║                     │
│  ║  Sans invalidité : 520'000 CHF      ║                     │
│  ║  Avec invalidité : 310'000 CHF      ║                     │
│  ║                                     ║                     │
│  ║  Rente mensuelle perdue : -875 CHF  ║                     │
│  ║  Chaque mois. Pour toujours.        ║                     │
│  ╚══════════════════════════════════════╝                     │
│                                                              │
│  💡 "C'est pas juste ton salaire qui baisse.                 │
│      C'est ta retraite qui rétrécit."                        │
│                                                              │
│  → Action : "Simule un rachat LPP pour combler le trou"      │
└─────────────────────────────────────────────────────────────┘
```

#### C. L'Écran rouge de l'indépendant *(L6 + L4)*

**Concept** : Pour les indépendants sans LPP, afficher un écran dramatiquement différent — le système de protection est quasi inexistant.

```
┌─────────────────────────────────────────────────────────────┐
│  🚨  INDÉPENDANT : TON FILET N'EXISTE PAS                   │
│                                                              │
│  Si tu ne peux plus travailler demain :                      │
│                                                              │
│  Salarié touche :          Toi tu touches :                  │
│  ┌──────────────┐          ┌──────────────┐                  │
│  │ APG 80%      │          │              │                  │
│  │ LPP invalid. │          │   RIEN       │                  │
│  │ AI rente     │          │   pendant    │                  │
│  │              │          │   ~14 mois   │                  │
│  └──────────────┘          └──────────────┘                  │
│  = 4'320 CHF/mois          = 0 CHF/mois                     │
│                                                              │
│  Après décision AI :                                         │
│  Salarié : 4'320 CHF       Toi : 2'520 CHF (AI seule)       │
│                                                              │
│  💰 CHIFFRE-CHOC : 14 mois à 0 CHF.                         │
│     = tu dois avoir 70'000 CHF d'épargne de sécurité.        │
│                                                              │
│  ╭────────────────────────────────────────╮                   │
│  │ 💡 As-tu une assurance perte de gain ? │                   │
│  │    [Oui] [Non] [Je ne sais pas]        │                   │
│  ╰────────────────────────────────────────╯                   │
│                                                              │
│  → Action : "Compare 3 assurances perte de gain"             │
│                                                              │
│  ℹ️ Outil éducatif · LAMal art. 67-77, CO art. 324a          │
└─────────────────────────────────────────────────────────────┘
```

#### D. Le vrai coût de ta franchise *(L1 + L2)*

**Concept** : La franchise LAMal prend une dimension critique en cas d'invalidité. Montrer la différence de coût réel entre franchise 300 et 2500 en cas de maladie longue.

```
┌─────────────────────────────────────────────────────────────┐
│  🏥  TA FRANCHISE EN CAS DE PÉPIN LONG                       │
│                                                              │
│  Scénario : maladie/accident nécessitant 2 ans de soins     │
│                                                              │
│  Franchise 2'500 CHF :              Franchise 300 CHF :      │
│  ┌────────────────────┐             ┌────────────────────┐   │
│  │ Franchise : 2'500  │             │ Franchise :   300  │   │
│  │ Quote-part : 700   │             │ Quote-part :  700  │   │
│  │ × 2 ans = 6'400    │             │ × 2 ans = 2'000    │   │
│  └────────────────────┘             └────────────────────┘   │
│                                                              │
│  Surcoût franchise haute : +4'400 CHF                        │
│  Économie prime mensuelle : +130 CHF/mois                    │
│                                                              │
│  ╔═══════════════════════════════════════════════════╗        │
│  ║ Seuil de rentabilité :                            ║        │
│  ║ Si tu vas chez le médecin > 2× par an →           ║        │
│  ║ La franchise basse te coûte MOINS.                ║        │
│  ╚═══════════════════════════════════════════════════╝        │
│                                                              │
│  [Slider: Combien de consultations/an ? ──●── 4]            │
│                                                              │
│  → Action : "Simule le changement de franchise au 30.11"     │
└─────────────────────────────────────────────────────────────┘
```

#### E. Le Bulletin scolaire de ta couverture *(L5 + L2)*

**Concept** : Une note A-F sur chaque pilier de ta protection invalidité — comme un bulletin scolaire. Tu vois immédiatement où tu es couvert et où c'est le trou.

```
┌─────────────────────────────────────────────────────────────┐
│  📋  TON BULLETIN DE COUVERTURE INVALIDITÉ                   │
│                                                              │
│  Couverture        Note   Détail                             │
│  ──────────────────────────────────────                      │
│  APG (perte gain)   B+    80% pendant 720j max              │
│  AI (rente)          C    2'520 CHF max (degré ≥70%)        │
│  LPP invalidité     A-    Rente = 40-70% du salaire assuré  │
│  Épargne urgence     D    Tu as 2 mois de réserve            │
│  Assurance privée    F    ❌ Aucune détectée                  │
│                                                              │
│  ╔═══════════════════════════════════════════════╗            │
│  ║  MOYENNE GÉNÉRALE :  C-                       ║            │
│  ║  "Tu survivrais, mais ton niveau de vie       ║            │
│  ║   baisserait de 48%."                         ║            │
│  ╚═══════════════════════════════════════════════╝            │
│                                                              │
│  Matière la plus faible : Assurance perte de gain privée     │
│  → Action : "Passer de F à B coûte ~85 CHF/mois"            │
│                                                              │
│  ℹ️ Outil éducatif · LAMal, LAVS, LPP art. 23-26            │
└─────────────────────────────────────────────────────────────┘
```

#### F. Le Compte à rebours du délai de carence *(L6 + L7)*

**Concept** : Visualiser les 720 jours de délai AI comme un compte à rebours — combien de jours d'économies as-tu réellement ?

```
┌─────────────────────────────────────────────────────────────┐
│  ⏱  COMBIEN DE TEMPS TU TIENS ?                              │
│                                                              │
│  Tes charges fixes mensuelles : 5'200 CHF                    │
│  Ton épargne disponible : 28'000 CHF                         │
│                                                              │
│  ╔═════════════════════════════════════════════════╗          │
│  ║                                                 ║          │
│  ║   ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░      ║          │
│  ║   ◄── 5.4 mois ──►                             ║          │
│  ║                   ◄── le vide : 8.6 mois ──►   ║          │
│  ║                                                 ║          │
│  ║   Délai moyen décision AI : 14 mois             ║          │
│  ║   Tu tiens : 5.4 mois                           ║          │
│  ║   Il te manque : 44'720 CHF                     ║          │
│  ║                                                 ║          │
│  ╚═════════════════════════════════════════════════╝          │
│                                                              │
│  💰 CHIFFRE-CHOC : Après 5 mois, tu dois emprunter          │
│     ou vendre pour survivre.                                 │
│                                                              │
│  [Slider: Ton épargne disponible ────●──── 28'000 CHF]      │
│                                                              │
│  → Action : "Constitue un fonds d'urgence de 6 mois"        │
│  → Action : "Souscris une APG privée (dès 45 CHF/mois)"     │
│                                                              │
│  ℹ️ Outil éducatif · LAI art. 28, LPGA art. 19               │
└─────────────────────────────────────────────────────────────┘
```

### Grille de cohérence P4

| Proposition | L1 CHF/mois | L2 Avant/Après | L6 Chiffre-choc | L7 Métaphore |
|-------------|:-----------:|:--------------:|:----------------:|:------------:|
| A. Falaise  | ✅ 4'013/mois perdu | ✅ 8'333→4'320 | ✅ 721k sur 15 ans | ✅ Film 3 actes |
| B. Reset    | ✅ -875/mois rente | ✅ 520k→310k | ✅ Rente perdue | ✅ Reset/rewind |
| C. Écran rouge | ✅ 0 CHF/mois | ✅ Salarié vs indép. | ✅ 14 mois à 0 | ✅ Filet vs vide |
| D. Franchise | ✅ +130/mois économie | ✅ 300 vs 2500 | ✅ Seuil rentabilité | ✅ Bulletin |
| E. Bulletin | ✅ 85/mois pour B | ✅ Notes A-F | ✅ -48% niveau vie | ✅ École/notes |
| F. Countdown | ✅ 5'200/mois charges | ✅ Couvert vs vide | ✅ 5.4 mois | ✅ Compte à rebours |

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/disability/disability_gap_screen.dart` | Écart de revenu invalidité |
| `screens/disability/disability_insurance_screen.dart` | Couverture AI/APG |
| `screens/disability/disability_self_employed_screen.dart` | Cas indépendant |
| `services/disability_gap_service.dart` | Moteur de calcul gap |

---

## P5 — PREMIER EMPLOI (firstJob) — *"Ton toi de 65 ans te remerciera"*

### Diagnostic

| Écran existant | Lignes | Forces | Faiblesses |
|---|---|---|---|
| `first_job_screen.dart` | 989 | Décomposition salaire, 3a, LAMal, checklist | Formulaire froid, pas de storytelling, tout en vrac |
| `salary_breakdown_widget.dart` | 294 | Bar stacké + cotisations employeur | Statique, pas de avant/après |
| `simulator_3a_screen.dart` | 388 | Calcul fiscal, règle 5 comptes | Détaché du contexte premier emploi |

**Problème central** : Un jeune de 22 ans ouvre cet écran et voit un mur de chiffres. Il ne comprend pas *pourquoi* 37% de son salaire disparaît ni *ce que ça lui rapporte*. Le moment émotionnel unique du premier salaire est gâché par un formulaire technocratique.

### Propositions créatives

#### A. Le Film du premier salaire — Onboarding en 5 actes *(L4 + L6 + L7)*

**Concept** : Le premier salaire comme un film interactif en 5 actes — chaque acte révèle une couche du système suisse.

- **Acte 1 · La douche froide** : 5'500 brut → 4'210 net. Barre animée qui rétrécit. "1'290 CHF disparaissent. Mais c'est pas perdu — c'est ton futur."
- **Acte 2 · L'argent invisible** : 4 briques empilées (AVS 291, LPP 193, AC 61, AANP 72) + cadeau employeur qui double. "Ton vrai salaire est 6'094 CHF."
- **Acte 3 · Le cadeau fiscal** : 605 CHF/mois en 3a → 3 scénarios à 65 ans (420k/680k/1'050k). "Potentiellement millionnaire. Commence maintenant."
- **Acte 4 · Le piège LAMal** : Franchise 2'500 vs 1'500 vs 300. Conseil: 1'500 = bon compromis.
- **Acte 5 · Checklist** : Semaine 1 (3a + virement auto), Semaine 2 (LAMal + RC privée), Avant 31.12 (maximum 3a). Badge "Premier pas financier".

#### B. Le Time-Lapse de ta carrière *(L2 + L7)*

**Concept** : Slider "âge de début" qui montre le patrimoine à 65 ans. Chaque année perdue coûte ~30'000 CHF.

```
22 ans : ████████████████████████████████  680k
25 ans : ██████████████████████████████    610k
27 ans : ████████████████████████████      530k
30 ans : ██████████████████████████        450k
35 ans : ████████████████████              310k
```

"5 ans d'attente = 150'000 CHF de moins. Les intérêts composés sont ton meilleur allié — mais seulement si tu commences tôt."

#### C. La Radiographie de ta fiche de paie *(L1 + L4)*

**Concept** : Reproduction visuelle d'une fiche de paie suisse. Tap sur chaque ligne → explication en une phrase + icône + référence légale.

- AVS/AI/APG 5.30% → 🧱 "Ta rente à 65 ans. 44 ans de cotisation → max 2'520/mois. LAVS art. 3"
- LPP → 🏦 "Ton 2e pilier. Ton employeur double ta cotisation."
- AC 1.10% → 🪂 "Ton parachute chômage. LACI art. 3"
- AANP 1.30% → 🏥 "Accident hors travail. LAA art. 6"

#### D. Le Budget 50/30/20 personnalisé *(L5 + L1)*

**Concept** : Budget automatique basé sur le net, le canton et l'âge.

- 50% FIXE (2'105 CHF) : loyer coloc, LAMal, transport, tel, assurances, impôts provisionnels
- 30% VIE (1'263 CHF) : sorties, vêtements, sport, resto, loisirs, imprévus
- 20% FUTUR (842 CHF) : 3a prioritaire (605 CHF) + épargne libre (237 CHF)

"Avec 842 CHF/mois : 7'258 CHF de 3a + fonds d'urgence de 3'000 CHF en 12 mois."

#### E. Le Miroir employeur — L'iceberg *(L6 + L2)*

**Concept** : Visualisation iceberg — net au-dessus de la surface, cotisations toi + employeur en dessous.

- Net : 4'210 (visible)
- Tes cotisations : 1'290 (sous l'eau)
- Cotisations employeur : 654 (fond)
- Coût total employeur : 6'154 CHF

"Quand tu négocies +200 CHF brut : tu reçois net ~153 CHF. Ton employeur paie ~224 CHF de plus."

Slider : "Simule une augmentation" → impact net, LPP, 3a, impôts.

#### F. Le Compte à rebours 3a *(L5 + L6)*

**Concept** : Widget urgence (dès octobre). Barre de progression du plafond 3a + jours restants.

- Plafond 2026 : 7'258 CHF. Versé : 3'600 CHF. Reste : 3'658 CHF en 87 jours.
- "Si tu complètes : 1'450 CHF d'impôts en moins = 1 mois de loyer gratuit."
- "Si tu ne fais rien : 1'450 CHF laissés sur la table. Chaque année."

### Grille de cohérence P5

| Proposition | L1 CHF/mois | L2 Avant/Après | L6 Chiffre-choc | L7 Métaphore |
|---|:-:|:-:|:-:|:-:|
| A. Film 5 actes | ✅ 1'290/mois | ✅ Brut→Net | ✅ Millionnaire 3a | ✅ Film/actes |
| B. Time-Lapse | ✅ 30k/an perdu | ✅ 22→35 ans | ✅ 150k perdus | ✅ Time-lapse |
| C. Radiographie | ✅ Chaque ligne CHF | ✅ Fiche annotée | ✅ Vrai salaire 6k | ✅ Radiographie |
| D. Budget 50/30/20 | ✅ 842/mois épargne | ✅ Sans→Avec budget | ✅ 3k urgence en 12m | ✅ Règle simple |
| E. Iceberg | ✅ 6'154 coût réel | ✅ Visible→Invisible | ✅ +200 brut=153 net | ✅ Iceberg |
| F. Countdown 3a | ✅ 605/mois | ✅ Versé→Manquant | ✅ 1'450 d'impôts | ✅ Compte à rebours |

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/first_job_screen.dart` | Écran principal premier emploi |
| `widgets/educational/salary_breakdown_widget.dart` | Décomposition salaire |
| `services/first_job_service.dart` | Moteur de calcul |
| `screens/simulator_3a_screen.dart` | Simulateur 3a |
| `models/age_band_policy.dart` | AgeBand.youngProfessional + LifeEventType.firstJob |

---

## P6 — INDÉPENDANT (selfEmployment) — *"Le jour où tu deviens ton propre RH"*

### Diagnostic

| Écran existant | Lignes | Forces | Faiblesses |
|---|---|---|---|
| `independant_screen.dart` | 928 | Coverage gaps, coûts, chiffre-choc IJM | Hub technique, pas de parcours narratif |
| `dividende_vs_salaire_screen.dart` | 856 | Optimisation SA/Sàrl, risque requalification | Trop technique pour novice |
| `lpp_volontaire_screen.dart` | 780 | Trade-off LPP vs 3a, projection retraite | Pas d'émotion sur le choix crucial |
| `avs_cotisations_screen.dart` | 687 | Barème dégressif, jauge | Pas de comparaison "avant/après" transition |
| `ijm_screen.dart` | 786 | Prime × âge × carence | Pas assez dramatique pour un risque critique |
| `pillar_3a_indep_screen.dart` | 700 | Grand vs petit 3a | Détaché du contexte transition |

**Problème central** : L'indépendant perd 100% de la protection employeur du jour au lendemain — mais les écrans présentent chaque risque en silo. Aucun ne montre le choc total ni ne dit "voici ce que tu fais dans les 90 premiers jours."

### Propositions créatives

#### A. Le Jour J — La grande bascule *(L2 + L6 + L7)*

Avant/après dramatique : tout ce qui change en 1 jour. Chaque protection a un interrupteur ON→OFF.
- AVS ×2 (884 vs 442), LPP DISPARU, LAA DISPARU, IJM DISPARU, APG DISPARU.
- Chiffre-choc : "Tu perds 1'654 CHF/mois de protection invisible = 19'848 CHF/an."
- "Tu n'as pas quitté un emploi. Tu as quitté un système de protection."

#### B. Le Plan 90 jours — Checklist de survie *(L5 + L4)*

Parcours séquentiel en 4 phases avec deadlines et conséquences :
- Semaine 1 : inscription caisse AVS (délai 90j, sinon rétroactif + intérêts), numéro TVA, compte pro
- Semaine 2-4 : IJM (💀 sans = 0 CHF si malade), LAA complémentaire, RC professionnelle
- Mois 2 : choix stratégique LPP volontaire (→ petit 3a) vs pas de LPP (→ grand 3a)
- Mois 3 : provisionnement impôts (15-20%), structure juridique, 1er rachat LPP
- Badge "Indépendant structuré"

#### C. Le Double prix de ta liberté *(L1 + L6)*

Comparaison côte à côte charges salarié vs indépendant à 100k.
- Salarié total charges : 12'320 CHF/an. Indépendant : 23'340 CHF/an (×1.9).
- "Tu paies 918 CHF/mois de plus. Pour garder le même net, facture +22%."

#### D. Le Tarif horaire de la vérité *(L1 + L7)*

Décomposition : net souhaité + charges + impôts + frais + vacances/maladie = CA nécessaire.
- 100k salarié net → 149'540 CHF CA / 1'600h = **94 CHF/h minimum**.
- "En dessous de 94 CHF/h, tu t'appauvris."
- "94 CHF/h ≠ 94 CHF dans ta poche. 38 CHF partent en charges."

#### E. Le Grand 3a — Ton arme secrète *(L6 + L2)*

Super-pouvoir fiscal de l'indépendant sans LPP. Barres : salarié 7'258 vs toi 36'288 (×5).
- Économie fiscale : 9'070 CHF/an vs 1'815 pour le salarié.
- En 20 ans à 4% : salarié 217k, toi 1'083k. "Millionnaire en 3a."
- Warning : si LPP volontaire → 3a retombe à 7'258.

#### F. L'Arbre de décision — LPP vs Grand 3a *(L3 + L5)*

Arbre visuel pour LE choix stratégique : revenu > 60k → veux rente garantie → LPP / sinon → grand 3a.
- LPP : ✅ rente + déduction ❌ 3a plafonné ❌ coûteux seul
- Grand 3a : ✅ 36k déduction ✅ libre choix ❌ capital seul ❌ pas d'invalidité LPP
- "Il n'y a pas de mauvais choix. Mais le bon te fait économiser 3'000-9'000 CHF/an."

### Grille de cohérence P6

| Proposition | L1 CHF/mois | L2 Avant/Après | L6 Chiffre-choc | L7 Métaphore |
|---|:-:|:-:|:-:|:-:|
| A. Jour J | ✅ 1'654/mois perdu | ✅ Salarié→Indép. | ✅ 19'848/an | ✅ Interrupteurs |
| B. Plan 90j | ✅ Coûts par phase | ✅ Avant→Après checklist | ✅ Rétroactif AVS | ✅ Plan de survie |
| C. Double prix | ✅ 918/mois charges | ✅ 12k→23k charges | ✅ ×1.9 le prix | ✅ Prix de la liberté |
| D. Tarif horaire | ✅ 94 CHF/h min | ✅ Brut→Net horaire | ✅ 38/94 en charges | ✅ Tarif de vérité |
| E. Grand 3a | ✅ 756/mois épargne | ✅ 7k→36k plafond | ✅ ×5 vs salarié | ✅ Super-pouvoir |
| F. Arbre LPP/3a | ✅ 3-9k/an impôts | ✅ LPP vs 3a | ✅ 9k écart fiscal | ✅ Arbre décision |

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/independant_screen.dart` | Hub couverture + coûts |
| `screens/independants/dividende_vs_salaire_screen.dart` | Split SA/Sàrl |
| `screens/independants/lpp_volontaire_screen.dart` | LPP volontaire |
| `screens/independants/pillar_3a_indep_screen.dart` | Grand vs petit 3a |
| `screens/independants/avs_cotisations_screen.dart` | Barème AVS |
| `screens/independants/ijm_screen.dart` | Assurance perte de gain |
| `services/independants_service.dart` | 5 calculateurs |
| `screens/arbitrage/rachat_vs_marche_screen.dart` | Rachat vs marché |

---

## P7 — PERTE D'EMPLOI (jobLoss) — *"Le jour le plus cher de ta carrière"*

### Diagnostic

| Écran existant | Lignes | Forces | Faiblesses |
|---|---|---|---|
| `unemployment_screen.dart` | 1'028 | LACI 70/80%, durée, checklist, timeline | Simulateur froid, pas de parcours de crise |
| `unemployment_service.dart` | 278 | Calcul pur Dart, testé | Pas de lien avec budget/profil |
| `libre_passage_screen.dart` | 575 | 3 situations, alertes 30j, sfbvg.ch | Détaché du contexte jobLoss |
| `emergency_fund_ring.dart` | 273 | Anneau animé mois de réserve | Pas surfacé lors du jobLoss |

**Problème central** : La perte d'emploi est un tsunami à 3 vagues (choc, chute de revenu, décisions cachées) mais les écrans sont éparpillés en silo.

### Propositions créatives

#### A. Les 3 vagues — Ton tsunami financier *(L4 + L6 + L7)*

3 actes : Vague 1 = inscription ORP en 5 jours (sinon perte). Vague 2 = chute de 8'333→5'833 CHF/mois (30'000 CHF/an perdu). Vague 3 = décisions cachées (LPP 30 jours, 3a, LAMal, budget). "La vague la plus dangereuse n'est pas le chômage. C'est les décisions que tu oublies de prendre."

#### B. Le Crash-test budget *(L1 + L2 + L5)*

Budget actuel vs "mode survie" — chaque poste avec verdict (🔒 incompressible, ✂️ réduit, ⏸️ suspendu). Loyer 2'100→2'100, 3a 605→0, loisirs 500→100. Calcul de la marge restante et combien de mois de réserves tiennent.

#### C. Le Compteur de jours — Capital temps *(L6 + L7)*

Compteur défilant : 260 indemnités = ~12 mois. Comparaison par profil (<25 ans: 200, 25-54: 260, 55+: 400, 60+: 520). "Après 12 mois, plus rien. Pas de prolongation. Tu passes à l'aide sociale."

#### D. Opération sauvetage 2e pilier *(L5 + L6)*

30 jours chrono pour transférer ton LPP. 3 options : nouveau employeur, libre passage (recommandé — 2 comptes pour fiscalité), ne rien faire (institution supplétive = 9'000 CHF de manque à gagner sur 5 ans). Lien sfbvg.ch pour avoirs oubliés.

#### E. Tableau de bord crise *(L3 + L1)*

Dashboard "mode crise" avec 5 indicateurs vitaux : réserves (mois), chômage (jour X/260), LPP (transféré?), budget (déficit?), dettes. Alertes colorées + actions prioritaires.

#### F. La Ligne d'horizon *(L7 + L6)*

Barre temporelle : zone sûre (5'833 CHF) → mur (0 CHF). "Après la ligne : aide sociale, prestations complémentaires, ton épargne = dernier recours." Chiffre-choc : passage instantané de 5'833→0 CHF.

### Grille de cohérence P7

| Proposition | L1 CHF/mois | L2 Avant/Après | L6 Chiffre-choc | L7 Métaphore |
|---|:-:|:-:|:-:|:-:|
| A. 3 vagues | ✅ -2'500/mois | ✅ 8'333→5'833 | ✅ 30k/an perdu | ✅ Tsunami |
| B. Crash-test | ✅ Marge -420/mois | ✅ Budget→Survie | ✅ Postes coupés | ✅ Crash-test |
| C. Compteur | ✅ 5'833/mois | ✅ Jour 0→260 | ✅ 260 puis 0 | ✅ Sablier |
| D. Sauvetage LPP | ✅ 185k en jeu | ✅ LP vs supplétive | ✅ 9k de différence | ✅ Sauvetage |
| E. Dashboard crise | ✅ 5 KPIs CHF | ✅ Normal→Crise | ✅ Déficit mensuel | ✅ Tableau de bord |
| F. Ligne horizon | ✅ 5'833→0 | ✅ Couvert→Vide | ✅ Mur instantané | ✅ Horizon |

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/unemployment_screen.dart` | Simulateur chômage LACI |
| `services/unemployment_service.dart` | Moteur de calcul LACI |
| `widgets/educational/unemployment_timeline_widget.dart` | Timeline actions urgentes |
| `screens/lpp_deep/libre_passage_screen.dart` | Advisor libre passage |
| `widgets/budget/emergency_fund_ring.dart` | Anneau fonds d'urgence |
| `widgets/educational/emergency_fund_insert_widget.dart` | Calculateur fonds d'urgence |

---

## P8 — HÉRITAGE & DONATION (inheritance/donation) — *"L'argent dont on ne parle jamais à table"*

### Diagnostic

| Écran existant | Lignes | Forces | Faiblesses |
|---|---|---|---|
| `succession_simulator_screen.dart` | 1'329 | CC 2023, réserves, quotité, 3a OPP3, testament | Technique, tabou non brisé |
| `donation_screen.dart` | 1'288 | Impôt cantonal, avancement hoirie, alertes | Formulation juridique froide |
| `donation_service.dart` | 351 | 26 cantons, 6 liens parenté, CC art. 471 | Pas de chiffre-choc émotionnel |
| `donation_reserve_donut.dart` | 510 | Donut animé réserves vs quotité | Sous-exploité |

**Problème central** : Le sujet est tabou — personne n'ouvre l'écran succession spontanément. Il faut briser la glace avec un chiffre-choc irrésistible.

### Propositions créatives

#### A. Le Testament invisible *(L6 + L7)*
"Si tu meurs ce soir, voici qui reçoit quoi." Distribution légale automatique vs avec testament. Chiffre-choc concubin : 0% héritage + 24% d'impôt. Marié : 50% + 0% d'impôt. CC art. 457-462.

#### B. Le Prix du silence *(L1 + L2)*
500k patrimoine : marié = 0 CHF d'impôt succession. Concubin = 120'000 CHF. "Le silence te coûte un appartement. Un testament coûte 500 CHF."

#### C. La Clause 3a oubliée *(L5 + L6)*
OPP3 art. 2 : concubin ne touche le 3a QUE si clause bénéficiaire déposée. Sans clause = 0 CHF. "Ton 3a de 180k part à tes parents, pas à ta partenaire." Action : "Dépose ta clause en 5 minutes."

#### D. Le Donut des réserves *(L3 + L7)*
Donut animé : réserve conjoint 25%, réserve descendants 25%, quotité disponible 50%. CC 2023 : parents n'ont plus de réserve. "Tu as 50% de liberté testamentaire."

#### E. L'Avancement d'hoirie *(L2 + L4)*
Film 2 actes : 2 enfants, donation 200k à l'un. Acte 1 (aujourd'hui) → Acte 2 (au décès : rapport à la masse CC art. 626). "Ce que tu donnes sera déduit de sa part."

#### F. Le Comparateur cantonal *(L1 + L6)*
Impôt succession pour 500k (tiers/concubin) : Schwyz 0 CHF, Vaud 125'000 CHF. "Ton canton peut te coûter un appartement."

### Grille de cohérence P8

| Proposition | L1 CHF/mois | L2 Avant/Après | L6 Chiffre-choc | L7 Métaphore |
|---|:-:|:-:|:-:|:-:|
| A. Testament invisible | ✅ 0 vs 50% | ✅ Avec/sans testament | ✅ 0%+24% impôt | ✅ Testament invisible |
| B. Prix du silence | ✅ 120k d'impôt | ✅ Marié vs concubin | ✅ 120k vs 0 | ✅ Silence coûteux |
| C. Clause 3a | ✅ 180k en jeu | ✅ Avec/sans clause | ✅ 0 CHF pour partenaire | ✅ Clause oubliée |
| D. Donut réserves | ✅ 50% libre | ✅ 2023 vs ancien | ✅ 0% parents | ✅ Donut |
| E. Avancement | ✅ 200k impact | ✅ Aujourd'hui→Décès | ✅ Rapport masse | ✅ Film 2 actes |
| F. Cantons | ✅ 0→125k | ✅ SZ vs VD | ✅ 125k de diff | ✅ Loterie cantonale |

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/succession_simulator_screen.dart` | Simulateur succession complet |
| `screens/donation_screen.dart` | Simulateur donation + fiscalité |
| `services/donation_service.dart` | Calcul impôt donation 26 cantons |
| `services/life_events_service.dart` | SuccessionService + logique CC |
| `widgets/visualizations/donation_reserve_donut.dart` | Donut réserves animé |

---

## P9 — NAISSANCE (birth) — *"Le plus beau budget de ta vie"*

### Diagnostic

| Écran existant | Lignes | Forces | Faiblesses |
|---|---|---|---|
| `naissance_screen.dart` | 1'700+ | 3 tabs (congé/allocations/impact), complet | Moment émotionnel unique non célébré |
| `family_service.dart` | 585 | 6 méthodes pures, APG, allocations 26 cantons | Calculs froids |
| `parental_leave_timeline.dart` | 637 | Timeline animée congé | Sous-exploité |
| `canton_allocation_map.dart` | 505 | Bubble treemap 26 cantons | Pas de comparaison émotionnelle |

**Problème central** : Le moment émotionnel le plus fort de la vie est traité comme un formulaire budgétaire.

### Propositions créatives

#### A. Le Coût du bonheur *(L1 + L6)*
"Un enfant = ~1'200 CHF/mois × 25 ans = 360'000 CHF." Décomposition : crèche (le poste monstre : 2'400 CHF/mois à ZH), LAMal enfant, nourriture, activités. Chiffre-choc : "La crèche coûte plus cher que ton loyer."

#### B. Le Congé en film *(L4 + L2)*
Timeline animée : mère 98j à 80% (max 220 CHF/jour = 4'400/mois), père 10j. Barre revenu qui chute puis remonte. "Pendant 14 semaines, tu touches 4'400 au lieu de 5'500."

#### C. Le Super-pouvoir fiscal enfant *(L6 + L1)*
Déduction LIFD : 6'700/enfant + frais garde max 25'500. Taux 25% → économie 8'050 CHF/an. "L'État te rend de l'argent pour avoir un enfant."

#### D. La Carte des allocations *(L7 + L2)*
Bubble map : Valais 305 CHF vs Zurich 200 CHF. "En déménageant ZH→VS, +1'260 CHF/an par enfant." Classement visuel des 26 cantons par générosité.

#### E. Le Budget bébé mode *(L5 + L1)*
Budget 50/30/20 avec curseur "nombre d'enfants" qui fait bouger les proportions en temps réel. "2 enfants : ta part loisirs passe de 30% à 15%."

#### F. La Couverture décès/invalidité *(L6 + L4)*
"Tu as un enfant. Si invalidité : AI 2'520 + rente enfant 840 = 3'360 CHF pour 3 personnes." Bulletin scolaire couverture familiale. → Action : assurance risque décès.

### Grille de cohérence P9

| Proposition | L1 CHF/mois | L2 Avant/Après | L6 Chiffre-choc | L7 Métaphore |
|---|:-:|:-:|:-:|:-:|
| A. Coût bonheur | ✅ 1'200/mois | ✅ Sans→Avec enfant | ✅ 360k sur 25 ans | ✅ Bonheur chiffré |
| B. Congé film | ✅ 5'500→4'400 | ✅ Avant/après congé | ✅ -1'100/mois 14 sem | ✅ Film |
| C. Fiscal enfant | ✅ 8'050/an | ✅ Sans→Avec déduction | ✅ 8k d'impôts | ✅ Super-pouvoir |
| D. Carte allocations | ✅ 200→305/mois | ✅ ZH vs VS | ✅ 1'260/an/enfant | ✅ Carte |
| E. Budget bébé | ✅ Loisirs -50% | ✅ 0→2 enfants | ✅ 30%→15% loisirs | ✅ Curseur |
| F. Couverture | ✅ 3'360/mois | ✅ Couvert vs non | ✅ 3 personnes à 3k | ✅ Bulletin |

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/naissance_screen.dart` | Écran principal 3 tabs |
| `services/family_service.dart` | 6 calculateurs famille |
| `widgets/visualizations/parental_leave_timeline.dart` | Timeline congé |
| `widgets/visualizations/canton_allocation_map.dart` | Carte allocations |

---

## P10 — CRISE DE DETTE (debtCrisis) — *"Le premier pas pour remonter"*

### Diagnostic

| Écran existant | Lignes | Forces | Faiblesses |
|---|---|---|---|
| `debt_ratio_screen.dart` | 758 | Jauge, LP art. 93, 3 niveaux, Dettes Conseils | Ton clinique pour sujet honteux |
| `debt_risk_check_screen.dart` | 388 | Quiz 6 questions, SOS Jeu | Formulation interrogatoire |
| `consumer_credit_screen.dart` | 350 | Coût total crédit, taux max 10% | Pas assez dramatique |
| `simulator_leasing_screen.dart` | 320 | Coût opportunité 20 ans | Détaché du contexte dette |
| `debt_prevention_service.dart` | 663 | Avalanche vs boule de neige, min. vital, 26 cantons | UI manquante pour repayment |

**Problème central** : Le surendettement provoque de la honte. Les écrans sont froids et cliniques. Il faut de la bienveillance et du pragmatisme.

### Propositions créatives

#### A. Le Check-up bienveillant *(L4 + L7)*
Reformuler le quiz en "bilan de santé financière" — médical, pas judiciaire. Résultat vert/orange/rouge + "Tu n'es pas seul — 1 ménage sur 6 en Suisse a des dettes." OFS source.

#### B. Avalanche vs Boule de neige *(L2 + L7)*
Visualisation côte à côte (logique existe dans RepaymentPlanner). Avalanche : -2'300 CHF d'intérêts. Boule de neige : 1ère victoire en 3 mois. "L'avalanche est rationnelle. La boule de neige est humaine. Choisis ta méthode."

#### C. Le Minimum vital — Ton droit *(L1 + L6)*
LP art. 93 : insaisissable = 1'200 CHF (seul), 1'750 (couple) + 400/enfant. Jauge : ton revenu vs minimum vital. "Ce montant est protégé par la loi. Personne ne peut te le prendre."

#### D. Le Coût caché du leasing *(L6 + L7)*
500 CHF/mois × 48 mois = 24'000 CHF. À la fin : pas propriétaire. Investi à 5% sur 20 ans : 205'000 CHF. "Ton leasing t'a coûté un acompte immobilier."

#### E. Le Numéro gratuit *(L5 + L4)*
Card proéminente : 0800 40 40 40 (Dettes Conseils) + 0800 708 708 (Caritas). "Gratuit, confidentiel, sans jugement." Tap-to-call. SOS Jeu si gambling détecté.

#### F. Le Mode survie MINT *(L3 + L5)*
Dashboard alternatif "mode crise" auto-activé si ratio > 30%. 3 KPIs : dette totale, marge mensuelle, jours depuis dernier retard. Actions : couper loisirs, suspendre 3a, appeler Dettes Conseils.

### Grille de cohérence P10

| Proposition | L1 CHF/mois | L2 Avant/Après | L6 Chiffre-choc | L7 Métaphore |
|---|:-:|:-:|:-:|:-:|
| A. Check-up | ✅ Ratio % | ✅ Avant/après quiz | ✅ 1 ménage sur 6 | ✅ Médecin |
| B. Avalanche/Neige | ✅ -2'300 intérêts | ✅ 2 stratégies | ✅ 3 mois victoire | ✅ Nature |
| C. Min. vital | ✅ 1'200/mois | ✅ Revenu vs minimum | ✅ Insaisissable | ✅ Bouclier légal |
| D. Leasing | ✅ 500/mois | ✅ Leasing vs investi | ✅ 205k perdus | ✅ Fuite capital |
| E. Numéro gratuit | ✅ 0 CHF appel | ✅ Seul vs accompagné | ✅ Gratuit | ✅ Bouée |
| F. Mode survie | ✅ 3 KPIs | ✅ Normal→Crise | ✅ Ratio >30% | ✅ Mode urgence |

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/debt_prevention/debt_ratio_screen.dart` | Jauge ratio d'endettement |
| `screens/debt_risk_check_screen.dart` | Quiz santé financière |
| `screens/consumer_credit_screen.dart` | Simulateur crédit |
| `screens/simulator_leasing_screen.dart` | Anti-leasing |
| `services/debt_prevention_service.dart` | Avalanche/Boule de neige, min vital |
| `widgets/report/debt_alert_banner.dart` | Bannière alerte dette |
| `widgets/educational/credit_cost_insert_widget.dart` | Insert coût crédit |

---

## P11 — NOUVEAU JOB (newJob) — *"Le vrai prix d'un changement"*

### Diagnostic

| Écran | Lignes | Rôle |
|---|---|---|
| `job_comparison_screen.dart` | 1'186 | Comparateur 7 axes LPP |
| `job_comparison_service.dart` | 403 | Calcul delta capital retraite |

**Problème** : Le comparateur montre 7 axes techniques mais pas l'impact émotionnel du changement — "combien je gagne ou perds à long terme ?"

### Propositions créatives

#### A. Le Prix du changement *(L2 + L6)*
Avant/après dramatique : salaire net, LPP employeur, 3a impact, bonus, vacances. "Ton nouveau job paie +500 CHF net/mois MAIS ta LPP employeur perd 200 CHF. Impact réel : +300 CHF." Slider : "Combien négocier pour compenser ?"

#### B. Le Film de ta LPP *(L4 + L7)*
Projection à 65 ans avec job actuel vs nouveau. "Changer de job à 45 ans : capital LPP final +85k vs -40k selon la caisse." 2 barres animées qui divergent. "Demande TOUJOURS le certificat LPP avant de signer."

#### C. La Checklist 48h *(L5)*
J0 : demander certificat LPP ancien + nouveau. J5 : vérifier transfert libre passage. J30 : premier bulletin → vérifier déductions. "Tu as 30 jours pour vérifier que ton LPP a été transféré."

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/job_comparison_screen.dart` | Comparateur 7 axes |
| `services/job_comparison_service.dart` | Moteur de calcul |

---

## P12 — DÉMÉNAGEMENT CANTONAL (cantonMove) — *"Le canton le moins cher de Suisse est à 30 minutes"*

### Diagnostic

| Écran | Lignes | Rôle |
|---|---|---|
| `fiscal_comparator_screen.dart` (tab 3) | 1'640 | Comparateur fiscal + simulation déménagement |
| `cantonal_comparator.py` (backend) | 599 | Calcul 26 cantons |

**Problème** : L'écran montre des taux d'imposition abstraits. Pas de "combien j'économise par mois si je déménage de VD à FR."

### Propositions créatives

#### A. La Carte du trésor *(L6 + L7)*
Carte de Suisse colorée par économie fiscale vs ton canton actuel. "En déménageant de VD à ZG, tu économises 12'800 CHF/an = 1'067 CHF/mois." Heatmap : rouge (cher) → vert (favorable). Tap sur canton → détail.

#### B. Le Vrai coût du déménagement *(L1 + L2)*
Économie fiscale vs coûts réels : loyer différent, assurance LAMal cantonale, frais de déménagement, école des enfants. "Tu économises 800 CHF d'impôts mais le loyer augmente de 500 CHF. Gain réel : 300 CHF/mois."

#### C. Le Top 5 pour toi *(L5 + L6)*
Classement personnalisé des 5 meilleurs cantons selon ton profil (revenu, famille, patrimoine). Avec LAMal + impôt + loyer médian. "Ton top 1 : Zoug. Mais si tu as 2 enfants, c'est Fribourg."

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/fiscal_comparator_screen.dart` | Comparateur fiscal 3 tabs |
| Backend: `cantonal_comparator.py` | Moteur 26 cantons |

---

## P13 — EXPATRIATION (countryMove) — *"Quitter la Suisse sans laisser 50k derrière toi"*

### Diagnostic

| Écran | Lignes | Rôle |
|---|---|---|
| `expat_screen.dart` | 1'692 | 3 tabs : forfait fiscal, départ, AVS gap |
| `expat_service.dart` | 811 | 8 méthodes : source tax, quasi-résident, 90j, forfait |

**Problème** : L'expatriation est un labyrinthe administratif. Le risque de perdre des droits (AVS, 3a, LPP) est énorme et irréversible.

### Propositions créatives

#### A. Les 5 choses que tu perds en partant *(L6 + L2)*
Avant/après : 5 droits qui changent. AVS : rente réduite (-X% par année manquante). LPP : libre passage ou retrait (selon EU/non-EU). 3a : retirable si hors UE. LAMal : plus de couverture. Impôts : impôt à la source. "En partant, tu laisses potentiellement 180k de LPP dormir à 0.05%."

#### B. Le Compte à rebours 90 jours *(L5 + L7)*
Checklist avec deadlines légales : J0 annoncer départ commune, J30 transfert LPP libre passage, J90 clôturer 3a (si hors UE), 6 mois retirer LPP (si non-EU). "Chaque jour de retard peut te coûter un formulaire de plus."

#### C. Le Trou AVS *(L1 + L6)*
Projection rente : 44 ans cotisés = 2'520 CHF/mois. 35 ans cotisés = 2'017 CHF/mois. "Chaque année hors Suisse te coûte ~57 CHF/mois de rente. Pour toujours." Slider : "Combien d'années à l'étranger ?"

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/expat_screen.dart` | Hub expatriation 3 tabs |
| `services/expat_service.dart` | Calculs source tax, AVS gap, forfait |

---

## P14 — DÉCÈS D'UN PROCHE (deathOfRelative) — *"Les papiers qu'on ne veut pas remplir"*

### Diagnostic

| Écran | Lignes | Rôle |
|---|---|---|
| `succession_simulator_screen.dart` | 1'329 | Simulateur succession (couvert en P8) |

Note : cet événement partage l'écran succession avec P8 (héritage/donation) mais le vécu émotionnel est fondamentalement différent — P8 = planification, P14 = crise.

### Propositions créatives

#### A. Le Guide de première urgence *(L5 + L4)*
Pas de calculs. Juste une checklist humaine en 4 phases : 48h (état civil, médecin, assurances), 1 semaine (banque, employeur, succession), 1 mois (impôts, succession, notaire), 6 mois (inventaire, partage). Ton doux, bienveillant.

#### B. Les Rentes de survivant *(L1 + L6)*
"Si ton conjoint décède : rente de veuf/veuve AVS = 80% de sa rente. Si tu n'es pas marié : 0 CHF." LAVS art. 23-24. Chiffre-choc pour concubins : "Le mariage vaut 2'016 CHF/mois de rente survivant."

#### C. La Clause 3a d'urgence *(L5 + L6)*
"Le 3a de ton partenaire : si la clause bénéficiaire n'est pas déposée, tu ne touches rien." OPP3 art. 2. Action immédiate : "Vérifie la clause de ton partenaire aujourd'hui."

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/succession_simulator_screen.dart` | Partagé avec P8 |
| `services/life_events_service.dart` | SuccessionService |

---

## P15 — VENTE IMMOBILIÈRE (housingSale) — *"Les impôts que tu ne vois pas venir"*

### Diagnostic

| Écran | Lignes | Rôle |
|---|---|---|
| `housing_sale_screen.dart` | 1'118 | Plus-value, impôt, EPL, remploi |
| `housing_sale_service.dart` | 326 | Calcul gain en capital, EPL |

**Problème** : La vente immobilière cache 3 pièges fiscaux (impôt sur le gain, remboursement EPL, remploi) que l'écran montre mais sans dramaturgie.

### Propositions créatives

#### A. Les 3 surprises de la vente *(L6 + L4)*
Film 3 actes : Acte 1 = impôt sur gain en capital (canton-dépendant, dégressif par durée). Acte 2 = remboursement EPL obligatoire (tu as retiré 80k de LPP → tu dois les remettre). Acte 3 = remploi 2 ans (si tu ne rachètes pas, l'impôt sur le gain n'est pas différé). "Tu vends à 1.2M, tu penses toucher 400k, tu reçois 280k."

#### B. Le Calculateur de net réel *(L1 + L2)*
Cascade : prix de vente → - hypothèque → - impôt gain → - EPL retour → - frais notaire → = net réel. "Ton net réel est 30% en dessous de ce que tu imagines."

#### C. Le Chrono du remploi *(L5 + L7)*
Si tu vends ta résidence principale et ne rachètes pas dans les 2 ans : l'impôt sur le gain est dû. Compte à rebours : "Il te reste 18 mois pour racheter et différer l'impôt de 45'000 CHF."

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `screens/housing_sale_screen.dart` | Simulateur vente |
| `services/housing_sale_service.dart` | Calcul gain, EPL, remploi |

---

*Note : Les événements `concubinage`, `mariage`, `divorce` sont couverts par P2. L'événement `retirement` est couvert par P1.*

---

## GRILLE DE COHÉRENCE

Chaque proposition est vérifiée contre les 7 lois :

### P1 — Retirement Dashboard

| Prop. | L1 CHF/mois | L2 Avant/Après | L3 3 niveaux | L4 Raconte | L5 Action | L6 Chiffre-choc | L7 Métaphore |
|-------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| A. Salaire après 65 | ✅ | ✅ | ✅ | ✅ | — | ✅ | — |
| B. Pile de briques | ✅ | — | ✅ | ✅ | — | — | ✅ |
| C. Slider retraite | ✅ | ✅ | ✅ | ✅ | — | ✅ | ✅ |
| D. Météo financière | — | — | ✅ | ✅ | ✅ | — | ✅ |
| E. Histoires "et si" | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| F. Film du couple | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| G. Sandwich budget | ✅ | — | ✅ | ✅ | — | — | ✅ |
| H. Score Strava | — | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| I. Thermomètre | — | — | ✅ | ✅ | ✅ | — | ✅ |
| J. Dashboard progressif | — | — | ✅ | — | — | — | — |

### P2 — Mariage / Divorce / Concubinage

| Prop. | L1 CHF/mois | L2 Avant/Après | L3 3 niveaux | L4 Raconte | L5 Action | L6 Chiffre-choc | L7 Métaphore |
|-------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| A. Ticket de caisse | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| B. Film du divorce | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| C. Match boxing | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| D. Tiroirs régimes | — | — | ✅ | ✅ | — | ✅ | ✅ |
| E. Checklist urgence | — | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| F. Pont cassé | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## FICHIERS CONCERNÉS (référence technique)

### P1 — Retirement Dashboard
| Fichier | Type | Rôle |
|---------|------|------|
| `screens/coach/retirement_dashboard_screen.dart` | Screen | Hub principal |
| `screens/coach/cockpit_detail_screen.dart` | Screen | Cockpit expert |
| `widgets/coach/hero_retirement_card.dart` | Widget | Hero number |
| `widgets/coach/hero_couple_card.dart` | Widget | Hero couple |
| `widgets/coach/pillar_decomposition.dart` | Widget | Décomposition piliers |
| `widgets/coach/mint_trajectory_chart.dart` | Widget | Trajectoire 3 scénarios |
| `widgets/coach/mint_score_gauge.dart` | Widget | Jauge fitness |
| `widgets/coach/confidence_bar.dart` | Widget | Barre confiance |
| `widgets/coach/confidence_blocks_bar.dart` | Widget | Blocs par catégorie |
| `widgets/retirement/income_stacked_bar_chart.dart` | Widget | Revenus empilés |
| `widgets/retirement/early_retirement_chart.dart` | Widget | Retraite anticipée |
| `widgets/retirement/couple_timeline_chart.dart` | Widget | Timeline couple |
| `widgets/retirement/budget_gap_chart.dart` | Widget | Gap budget |
| `widgets/retirement/monte_carlo_chart.dart` | Widget | Monte Carlo |
| `widgets/coach/sensitivity_snippet.dart` | Widget | Tornado snippet |
| `widgets/coach/temporal_strip.dart` | Widget | Chips temporels |
| `widgets/coach/early_retirement_comparison.dart` | Widget | Table retraite anticipée |
| `widgets/coach/benchmark_card.dart` | Widget | Benchmark pairs |
| `widgets/coach/fri_radar_chart.dart` | Widget | FRI radar |
| `services/retirement_projection_service.dart` | Service | Moteur projection |
| `services/forecaster_service.dart` | Service | 3 scénarios |

### P2 — Mariage / Divorce / Concubinage
| Fichier | Type | Rôle |
|---------|------|------|
| `screens/mariage_screen.dart` | Screen | Écran mariage (3 onglets) |
| `screens/divorce_simulator_screen.dart` | Screen | Simulateur divorce |
| `screens/concubinage_screen.dart` | Screen | Comparaison mariage vs concubinage |
| `widgets/visualizations/concubinage_decision_matrix.dart` | Widget | Matrice (inutilisé) |
| `widgets/visualizations/regime_matrimonial_pie.dart` | Widget | Donut régime (inutilisé) |
| `widgets/visualizations/marriage_penalty_gauge.dart` | Widget | Thermomètre pénalité (inutilisé) |
| `widgets/visualizations/fiscal_impact_waterfall.dart` | Widget | Waterfall fiscal (inutilisé) |
| `services/family_service.dart` | Service | Calculs mariage/famille |
| `services/life_events_service.dart` | Service | DivorceService + SuccessionService |
| `education/inserts/q_divorce.md` | Content | Insert éducatif divorce |
