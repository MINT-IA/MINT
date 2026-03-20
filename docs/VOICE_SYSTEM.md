# MINT Voice System

> **Statut** : Référence éditoriale. Tout texte visible par l'utilisateur passe ce filtre.
> **Gouvernance** : Complète DESIGN_SYSTEM.md §6. En cas de doute sur le ton, ce document tranche.
> **Source de vérité** : oui, pour le ton, la microcopy et les tournures autorisées/interdites.
> **Ne couvre pas** : navigation, layout, logique produit, scoring du CapEngine.

---

## 1. BRAND VOICE PILLARS

La voix MINT n'est pas une personnalité théâtrale. C'est une **intelligence relationnelle stable** :
quelqu'un qui sait de quoi il parle, qui respecte son interlocuteur, et qui a juste assez d'esprit
pour que la conversation ne soit jamais ennuyeuse.

### Les 5 piliers

| Pilier | Ce que ça veut dire | Ce que ça ne veut PAS dire |
|--------|--------------------|-----------------------------|
| **Calme** | Posé, jamais dans l'urgence. Le ton ne monte pas, même quand le chiffre est mauvais. | Froid, distant, robotique |
| **Précis** | Chaque mot est choisi. Pas de remplissage, pas de tournure vide. | Technique, jargonneux, sec |
| **Fin** | Un sourire en coin, jamais un rire gras. L'esprit naît de l'observation, pas de la blague. | Copywriter-y, forcé, malin pour être malin |
| **Rassurant** | "On va y arriver, voici par où commencer." Accompagne sans porter. | Infantilisant, condescendant, paternaliste |
| **Net** | Dit la vérité, même inconfortable, avec tact. Pas de promesse, pas de flou. | Brutal, anxiogène, moralisateur |

### La formule MINT

> **Dire les choses comme un ami cultivé qui travaille dans la finance suisse.**
> Il tutoie. Il ne fait pas de cours. Il montre un chiffre, donne un contexte,
> et laisse son interlocuteur décider.

### Ce que MINT n'est jamais

- Un banquier privé (trop formel, trop distant)
- Un influenceur finance (trop enthousiaste, trop performatif)
- Un chatbot sympa (trop générique, trop lisse)
- Un prof (trop didactique, trop condescendant)
- Une startup française (trop d'anglicismes, trop de "🚀")

---

## 2. TONE BY CONTEXT

La voix reste stable. Le ton s'adapte à **3 axes** :

### Axe 1 — Contexte émotionnel

| Contexte | Ton | Longueur | Exemple |
|----------|-----|----------|---------|
| **Découverte** | Curieux, invitant | Court (1-2 phrases) | "3 infos, un premier chiffre. Le reste viendra." |
| **Projection** | Factuel, ancré | Moyen (chiffre + contexte) | "À 65 ans, tu gardes 63% de ton train de vie. C'est un point de départ." |
| **Stress** | Calme, structurant | Court, phrases simples | "Pas de panique. Voici les 3 choses à faire cette semaine." |
| **Erreur / gap** | Honnête, non-jugeant | Direct + solution | "Il te manque des données LPP. Ça fausse le calcul d'environ 15%." |
| **Victoire** | Sobre, complice | Très court | "Là, tu viens de t'acheter de la marge." |
| **Deuil / crise** | Empathique, en retrait | Plus long, plus doux | "C'est un moment difficile. On reste là. Voici ce qui est urgent." |

### Axe 2 — Niveau de maîtrise

| Niveau | Adaptation | Ce qui change |
|--------|-----------|---------------|
| **Novice** | Phrases courtes. Pas de sigle sans explication. Métaphores concrètes. | "Le 2e pilier, c'est l'argent que ton employeur et toi mettez de côté chaque mois." |
| **Autonome** | Sigles OK. Chiffres directs. Moins de contexte. | "Ton taux LPP : 6.8%. Rachat possible : 539k." |
| **Expert** | Références légales. Scénarios avancés. Hypothèses éditables. | "LAVS art. 35 : cap 150% en couple. Sensibilité : ±2% rendement inverse le résultat." |

**Règle** : MINT détecte le niveau via `profile.financialLiteracyLevel` et les interactions passées.
En cas de doute, écrire pour l'autonome. Ne jamais écrire que pour l'expert.

### Axe 3 — Moment produit

| Moment | Registre | Pattern |
|--------|----------|---------|
| **Onboarding** | Léger, rapide, zéro friction | Question → chiffre → "et voilà" |
| **Coach (chat)** | Conversationnel, complice | "Bonne question. Voici ce que tes chiffres disent." |
| **Simulation** | Factuel, hypothèses visibles | Chiffre + "si on suppose que..." + disclaimer |
| **Alerte** | Calme mais direct | "Ton taux passe sous 60%. Voici 2 leviers." |
| **Dossier** | Neutre, fonctionnel | Labels clairs, pas de narration |
| **Succès / milestone** | Sobre, jamais excessif | "7 jours. Le rythme est bon." |
| **Erreur technique** | Transparent, solution | "Quelque chose n'a pas marché. On réessaie ?" |

---

## 3. AUDIENCE ADAPTATIONS

MINT segmente par **événement de vie**, pas par âge. Mais le vocabulaire et le rythme
s'ajustent subtilement selon le profil.

### Ce qui change

| Signal | Jeune actif (22-35) | Milieu de parcours (35-50) | Pré-retraite (50-65) |
|--------|--------------------|-----------------------------|----------------------|
| **Rythme** | Plus court, plus direct | Équilibré | Un peu plus posé, pas plus long |
| **Vocabulaire** | "fisc" OK, argot rare et mesuré | Standard | Standard, jamais familier |
| **Références** | "Ton premier appart", "ta boîte" | "Ton foyer", "ta situation" | "Tes années de cotisation", "ton horizon" |
| **Humour** | Observation ("Oui, la Suisse a un formulaire pour ça") | Complicité ("Tu le sais déjà, mais les chiffres aident") | Understatement ("C'est un peu plus qu'un détail") |
| **Longueur CTA** | 3 mots ("Voir mon 3a") | 4-5 mots ("Simuler mon rachat LPP") | 4-5 mots ("Explorer mes options") |

### Ce qui ne change JAMAIS

- Le tutoiement (toujours "tu")
- Le respect (jamais condescendant, quel que soit l'âge)
- La précision des chiffres (pas d'arrondi "motivant")
- Le conditionnel pour les projections ("pourrait", "environ", "si")
- L'absence de jugement ("ta situation", jamais "ton problème")

### Règle anti-caricature

Ne pas créer 3 personas distincts. Créer **une seule voix qui module légèrement** :
- Un 25 ans et un 58 ans reçoivent le même chiffre, le même calcul, la même honnêteté
- Ce qui change : le rythme de la phrase, 1-2 mots de vocabulaire, le degré de contexte

**Test** : si tu caches l'âge du profil, le texte doit rester cohérent et naturel.

---

## 4. DO / DON'T

### DO

| Règle | Exemple |
|-------|---------|
| Commencer par le chiffre, expliquer après | "63% de ton revenu. C'est ton taux de remplacement." |
| Laisser le silence parler | Un chiffre seul sur l'écran, pas besoin de 3 phrases autour |
| Utiliser "on" pour inclure | "On regarde ça ensemble" (pas "je vais t'expliquer") |
| Reconnaître la complexité | "C'est normal de ne pas tout comprendre du premier coup." |
| Dire ce qui manque, pas ce qui est mal | "Il manque ton certificat LPP" (pas "tu n'as pas rempli") |
| Finir par une action concrète | "Prochaine étape : scanner ton certificat → +30 pts" |
| Faire confiance à l'intelligence du lecteur | Phrases courtes, pas de sur-explication |
| Être spécifiquement suisse | "En Valais", "ton 2e pilier", "la franchise LAMal" |

### DON'T

| Règle | Mauvais exemple | Pourquoi |
|-------|----------------|----------|
| Jamais d'exclamation enthousiaste | "Bravo, excellent travail !" | Sonne faux, infantilisant |
| Jamais de "voici ta situation" | "Voici ta situation financière aujourd'hui." | Plat, générique, mort |
| Jamais d'injonction | "Tu devrais absolument ouvrir un 3a." | Prescriptif (interdit CLAUDE.md §6) |
| Jamais de comparaison sociale | "Tu fais mieux que la moyenne suisse !" | Interdit (CLAUDE.md §6) |
| Jamais de fausse urgence | "DERNIÈRE CHANCE de cotiser cette année !!" | Manipulatif |
| Jamais de sur-célébration | "INCROYABLE ! Tu as ajouté ton salaire ! 🎉🎉🎉" | Gimmick |
| Jamais de jargon non expliqué (novice) | "Ton RAMD projeté est insuffisant" | Incompréhensible |
| Jamais de "c'est simple/facile" | "C'est très simple, il suffit de..." | Si c'était simple, ils n'auraient pas besoin de MINT |
| Jamais d'anglicisme gratuit | "Ton financial health score" | On est en Romandie, pas à Station F |

---

## 5. MICROCOPY PATTERNS

### Titres d'écran (headlineLarge / headlineMedium)

```
Pattern : [Sujet concret] — max 5 mots, sentence case
Bon    : "Ton aperçu retraite"
Bon    : "Rente ou capital ?"
Bon    : "Combien coûte un rachat ?"
Mauvais : "Tableau de bord de votre situation de prévoyance"
Mauvais : "SIMULATION DE RETRAITE"
```

### Chiffre-choc caption (sous le nombre dominant)

```
Pattern : [Contexte humain du chiffre] — 1 phrase, < 10 mots
Bon    : "Tu gardes 63% de ton train de vie"
Bon    : "Soit 2'100 CHF de moins chaque mois"
Mauvais : "Taux de remplacement calculé sur base du revenu net actuel"
```

### CTA (boutons)

```
Pattern : [Verbe] + [objet concret] — 3-5 mots
Bon    : "Voir mon aperçu"
Bon    : "Simuler un rachat"
Bon    : "Comprendre mon 2e pilier"
Mauvais : "En savoir plus"
Mauvais : "Découvrir les options disponibles"
Mauvais : "Cliquez ici pour accéder au simulateur"
```

### Labels de statut

```
Positif    : "En bonne voie"       (success, sobre)
Attention  : "À affiner"           (warning, invitant)
Urgent     : "À traiter"           (error, pas alarmiste)
Incomplet  : "Données manquantes"  (muted, pas accusateur)
```

### Empty states

```
Pattern : [Observation empathique] + [CTA encourageant]
Bon    : "Pas encore de données ici. Ajoute ton salaire pour voir la magie opérer."
Bon    : "C'est vide pour l'instant. Un scan de certificat, et tout s'éclaire."
Mauvais : "Aucune donnée disponible. Veuillez compléter votre profil."
```

### Erreurs

```
Pattern : [Ce qui s'est passé] + [Ce qu'on peut faire]
Bon    : "Le calcul a buté. On réessaie ?"
Bon    : "Connexion perdue. Tes données sont sauvées localement."
Mauvais : "Erreur 500 — une erreur inattendue s'est produite."
```

### Coach fallback (quand l'IA ne peut pas répondre)

```
Bon    : "Je n'ai pas assez de contexte pour cette question. Mais tu peux explorer
          le sujet directement — voici les outils pertinents."
Mauvais : "Le coach IA n'est pas disponible pour le moment. En attendant, tu peux :
          • Explorer tes simulateurs (3a, LPP, retraite)
          • Consulter les fiches éducatives"
```

### Narration Pulse (Aujourd'hui)

```
Pattern : [Prénom], [observation personnalisée]. [Implication concrète].
Bon    : "Julien, tu as 16 ans pour agir. Chaque année de rachat compte."
Bon    : "Julien, ta retraite couvre les deux tiers. Le dernier tiers, c'est ton levier."
Mauvais : "Julien, voici ta situation financière aujourd'hui."
Mauvais : "Bonjour Julien ! Bienvenue sur ton tableau de bord personnalisé !"
```

### Milestones / achievements

```
Pattern : [Fait concret] + [implication sobre]
Bon    : "7 jours de suite. Le rythme est bon."
Bon    : "Tu viens de comprendre ton 2e pilier. Pas mal."
Bon    : "Là, tu viens de t'acheter de la marge."
Mauvais : "FÉLICITATIONS ! Tu as débloqué le badge Bronze ! 🏆"
Mauvais : "Excellent travail, continuez comme ça !"
```

---

## 6. AVANT / APRÈS — 50 exemples

### Onboarding

| # | Avant (générique) | Après (MINT) |
|---|-------------------|--------------|
| 1 | "Bienvenue sur MINT, votre application de prévoyance" | "Bienvenue. Trois questions, un premier chiffre. Le reste, c'est toi qui décides quand." |
| 2 | "Veuillez entrer votre salaire brut annuel" | "Ton revenu brut annuel" |
| 3 | "Facultatif — vous pourrez le renseigner plus tard" | "Facultatif — on affinera plus tard" |
| 4 | "Votre estimation de retraite est prête !" | "Premier aperçu. C'est une estimation — elle s'affine avec tes données." |
| 5 | "Votre taux de remplacement est de 63%" | "Tu gardes 63% de ton train de vie. C'est un point de départ, pas une sentence." |
| 6 | "Cliquez pour accéder à votre tableau de bord" | "Voir mon tableau de bord" |
| 7 | "Attention : estimation basée sur des données partielles" | "Estimation indicative. Plus tu ajoutes de données, plus c'est précis." |

### Aujourd'hui (Pulse)

| # | Avant | Après |
|---|-------|-------|
| 8 | "Voici votre situation financière aujourd'hui" | "Julien, ta retraite couvre les deux tiers. Le dernier tiers, c'est ton levier." |
| 9 | "Taux de remplacement : 63%" | "63% — tu gardes presque deux tiers" |
| 10 | "Budget libre : +4'384 CHF/mois" | "+4'384 CHF/mois de marge" |
| 11 | "1 action à faire" | "Une chose à régler" |
| 12 | "Scannez votre certificat LPP pour améliorer la précision" | "Ton certificat LPP → +30 pts de confiance sur tes projections" |
| 13 | "Score de préparation : 57/100" | "57/100. De la marge, mais une bonne base." |
| 14 | "Votre patrimoine total est de 251'000 CHF" | "251k de patrimoine. On décompose ?" |

### Coach

| # | Avant | Après |
|---|-------|-------|
| 15 | "Je suis votre coach financier. Posez-moi vos questions." | "Pose ta question. Je regarde tes chiffres et je te dis ce que j'en pense." |
| 16 | "Le coach IA n'est pas disponible pour le moment." | "Je n'ai pas la réponse là, mais les outils sont juste à côté." |
| 17 | "Voici quelques suggestions basées sur votre profil :" | "Vu ton profil, deux pistes :" |
| 18 | "Voulez-vous en savoir plus sur le rachat LPP ?" | "Un rachat LPP pourrait te faire économiser ~8'000 CHF d'impôts. On simule ?" |
| 19 | "Excellent travail ! Vous avez exploré 3 simulateurs." | "3 simulateurs explorés. Tes recommandations s'affinent." |
| 20 | "Erreur lors du chargement. Veuillez réessayer." | "Raté. On réessaie ?" |

### Simulateurs

| # | Avant | Après |
|---|-------|-------|
| 21 | "Simulation de rente vs capital" | "Rente ou capital ?" |
| 22 | "Veuillez entrer vos paramètres de simulation" | "Ajuste les hypothèses, le résultat suit en temps réel." |
| 23 | "Le résultat de votre simulation est le suivant :" | (Juste le chiffre, 32pt, pas de phrase introductive) |
| 24 | "Attention : ces projections ne constituent pas un conseil" | "Estimation éducative. Pas un conseil financier (LSFin)." |
| 25 | "Si le rendement passe de 3% à 5%, votre capital augmente" | "±2% de rendement, et le résultat s'inverse. La sensibilité compte." |
| 26 | "Hypothèse : taux de rendement de 3.0%" | "Hypothèse : rendement 3% (ajustable)" |
| 27 | "Scénario optimiste / base / prudent" | "Prudent · Base · Favorable" (pas "optimiste" — terme interdit) |

### Événements de vie

| # | Avant | Après |
|---|-------|-------|
| 28 | "Simulateur d'impact du mariage" | "Se marier, ça change quoi ?" |
| 29 | "Impact financier de la naissance d'un enfant" | "Un enfant, combien ça coûte (et ce que la Suisse prend en charge)" |
| 30 | "Simulation de divorce — partage du 2e pilier" | "Divorce : qui repart avec quoi ?" |
| 31 | "Analyse de la perte d'emploi" | "Perte d'emploi : tes droits et tes prochaines étapes" |
| 32 | "Comparaison fiscale intercantonal" | "Déménager, ça rapporte combien ?" |
| 33 | "Décès d'un proche — démarches à effectuer" | "Perdre un proche. Ce qui est urgent, ce qui peut attendre." |
| 34 | "Statut d'indépendant — couverture sociale" | "Indépendant : ce que tu perds, ce que tu dois reconstruire" |
| 35 | "Expatriation — conséquences sur la prévoyance" | "Quitter la Suisse : ce qui te suit, ce qui reste" |

### Alertes

| # | Avant | Après |
|---|-------|-------|
| 36 | "Alerte : votre taux de remplacement est inférieur à 60%" | "Ton taux passe sous 60%. Deux leviers pour remonter." |
| 37 | "Votre franchise LAMal n'est pas optimale" | "Ta franchise LAMal te coûte peut-être 400 CHF/an de trop." |
| 38 | "Attention : rachat LPP bloqué pendant 3 ans avant retrait" | "Rappel : un rachat LPP est bloqué 3 ans (LPP art. 79b)." |
| 39 | "Votre profil est incomplet (42%)" | "42% complété. Chaque info ajoutée rend les projections plus fiables." |
| 40 | "Vos données n'ont pas été mises à jour depuis 287 jours" | "Dernière mise à jour il y a 9 mois. Tes chiffres ont peut-être bougé." |

### Dossier & profil

| # | Avant | Après |
|---|-------|-------|
| 41 | "Section Documents — gérez vos certificats" | "Documents" (le sous-titre suffit) |
| 42 | "Veuillez télécharger votre certificat LPP" | "Scanner un certificat" |
| 43 | "Profil complété à 72%" | "72% — il manque ton LPP et tes charges" |
| 44 | "Paramètres du modèle IA local" | "IA embarquée" |
| 45 | "Gestion des consentements et de la vie privée" | "Vie privée et consentements" |

### Éducation

| # | Avant | Après |
|---|-------|-------|
| 46 | "Le 2e pilier est un régime de prévoyance professionnelle obligatoire" | "Le 2e pilier, c'est l'épargne que ton employeur et toi constituez ensemble. Obligatoire dès 22'680 CHF/an." |
| 47 | "L'AVS constitue le premier pilier du système suisse" | "L'AVS, c'est le socle. Tout le monde cotise, tout le monde reçoit. Rente max : 2'520 CHF/mois." |
| 48 | "Le pilier 3a offre des avantages fiscaux significatifs" | "Le 3e pilier : tu mets de côté, le fisc te rend une partie. Jusqu'à 7'258 CHF/an déductibles." |
| 49 | "La franchise LAMal détermine votre participation aux frais" | "Franchise haute = prime basse, mais tu paies plus quand tu vas chez le médecin. C'est un pari sur ta santé." |
| 50 | "Le taux de conversion LPP transforme votre capital en rente" | "6.8% : c'est le taux qui transforme ton capital en rente mensuelle. 100'000 CHF → 567 CHF/mois. À vie." |

---

## 7. PHRASES INTERDITES

### Termes interdits (CLAUDE.md §6 — compliance)
- "garanti", "certain", "assuré", "sans risque"
- "optimal", "meilleur", "parfait" (comme absolus)
- "conseiller" → "spécialiste"

### Tournures interdites (VOICE_SYSTEM — éditorial)
- "Voici votre/ta situation..." (plat)
- "N'hésitez pas à..." (langue de bois)
- "Il est important de noter que..." (remplissage)
- "Excellent travail !" / "Bravo !" / "Félicitations !" (infantilisant)
- "Cliquez ici pour..." (années 2000)
- "Veuillez..." (administratif)
- "En savoir plus" (quand on peut être spécifique)
- "Découvrir" (quand on peut être concret)
- "Votre parcours personnalisé" (marketing vide)
- "Simple et rapide" / "En quelques clics" (promesse creuse)
- "Restez informé" / "Ne manquez pas" (newsletter energy)
- Toute phrase qui commence par "Bienvenue sur..." après l'onboarding

### Émojis
- **Jamais** dans les chiffres, projections, alertes, simulations
- **Acceptables** (avec modération) dans les milestones, empty states, coach casual
- **Maximum 1 par écran**, jamais en série (🎉🎉🎉 = interdit)

---

## 8. RÉFÉRENCES CULTURELLES

### La voix MINT s'inspire de

| Référence | Ce qu'on emprunte | Segment |
|-----------|-------------------|---------|
| **Kucholl & Veillon** (26 minutes, RTS) | L'understatement suisse, l'absurdité traitée avec sérieux | Universel |
| **Le Temps** (éditorial) | La rigueur intellectuelle + phrases accessibles | Universel |
| **Myret Zaki** (journaliste finance) | La crédibilité sans jargon, le ton direct | 35-65 |
| **Thomas Wiesel** (stand-up) | L'observation du quotidien suisse, l'autodérision | 22-40 |
| **Marc Pittet** (Mustachian Post) | Le "voici ce que j'ai fait concrètement", données réelles | 28-50 |
| **Headspace** (app) | Le "acknowledge then guide" — reconnaître avant d'aider | Moments de stress |
| **Wise** (fintech) | La clarté radicale, 0 décoration | Universel |

> **Attention** : ces références sont des inspirations, pas des modèles à imiter.
> Le but est de produire une voix MINT, pas une voix "RTS spirituelle fintech".
> Emprunter un mécanisme (l'understatement), pas un style (le pastiche).

### La formule d'humour suisse romand

> Prendre une réalité bureaucratique → la constater avec calme → laisser l'absurdité parler

Exemples MINT :
- "En Suisse, tu as 3 piliers pour ta retraite. Si tu es comme la plupart des gens, tu en connais un et demi."
- "La Suisse a inventé le chocolat, la montre, et un système de retraite que personne ne comprend complètement. On s'occupe du troisième."
- "Oui, il y a un formulaire pour ça. Mais on l'a déjà pré-rempli."

### La vérité inconfortable, dite avec tact

- "À ce rythme, la retraite pince un peu. On peut encore lui redonner de l'air."
- "Ton 3e pilier est un peu léger. Quelques versements changeraient la donne."
- "Sans rachat, il te manquera environ 800 CHF par mois. Avec, l'écart se réduit de moitié."

---

## 9. ADAPTATION LINGUISTIQUE ET CULTURELLE

### Le problème

La Suisse n'est pas un pays monolingue. MINT cible :

| Population | Langue | Taille | Particularité culturelle |
|-----------|--------|--------|--------------------------|
| Romands | Français | 23% | Understatement, litote, distance polie avec l'argent |
| Alémaniques | Allemand (suisse) | 63% | Direct, pragmatique, Sachlichkeit (factualité). L'humour est sec, pas spirituel. |
| Tessinois | Italien | 8% | Chaleureux, expressif, liens familiaux forts dans les décisions financières |
| Expats anglophones | Anglais | ~10% résidents | Clear, no-nonsense, attendent de la transparence type Wise/Revolut |
| Communauté portugaise | Portugais | ~260k | Souvent primo-arrivants, besoin d'accessibilité maximale, respect de la dignité |
| Communauté espagnophone | Espagnol | ~100k | Similaire au portugais, souvent 2e génération, bilingual |
| Frontaliers | FR/IT/DE | ~350k | Complexité fiscale unique (impôt source, 90 jours, charges sociales mixtes) |

### Principe fondamental

> **La voix MINT n'est PAS une traduction mot-à-mot du français.**
> Chaque langue a sa propre version de l'intelligence relationnelle MINT.

Les 5 piliers (calme, précis, fin, rassurant, net) restent identiques.
Mais leur **expression** change selon la culture linguistique.

### Adaptation par langue

#### Français (FR) — langue de référence
- Ton : understatement romand, légèrement spirituel
- Tutoiement systématique
- Humour : litote, observation absurde du quotidien suisse
- Référence tonale : Kucholl & Veillon, Le Temps

#### Allemand (DE) — Sachlichkeit + Wärme
- Ton : factuel, structuré, mais chaleureux (pas froid)
- **Duzen** (tu) acceptable dans le contexte app — les neobanks suisses-allemandes (Neon, Yuh) l'utilisent
- L'humour romand (litote, absurde) ne traduit PAS — remplacer par :
  - Pragmatisme avec un clin d'œil : "Drei Säulen. Die meisten kennen anderthalb."
  - Clarté comme valeur en soi : la phrase bien construite EST le plaisir
- Attention au Hochdeutsch vs Schweizerdeutsch : MINT écrit en Hochdeutsch standard mais
  le ton ne doit pas sonner "allemand d'Allemagne" (trop direct/marketing)
- Référence tonale : NZZ Feuilleton (rigueur), SRF (accessibilité)

#### Italiano (IT) — Calore + Chiarezza
- Ton : chaleureux, un peu plus expressif qu'en français, jamais froid
- **Tu** systématique (natural en italien)
- Plus de place pour l'émotion : les Tessinois parlent plus ouvertement d'argent en famille
- L'humour : calembours légers OK, mais pas de sarcasme
- Attention : ne pas tomber dans le ton "italiano standard" — le Ticino a sa propre identité
- Référence tonale : RSI (radio suisse italienne), Il Caffè (hebdo tessinois)

#### English (EN) — Clarity + Trust
- Ton : Wise-like clarity. Direct, transparent, respectful.
- Le public anglophone en Suisse est souvent expat, international, mobile
- Attend de la **transparence radicale** : pas de jargon suisse non expliqué
- Chaque sigle (AVS, LPP, LAMal) doit avoir son équivalent EN au premier usage :
  "AVS (state pension)", "LPP (occupational pension)", "LAMal (health insurance)"
- L'humour : understatement britannique fonctionne, pas le humor américain loud
- Référence tonale : Wise, The Economist, Monzo

#### Português (PT) — Respeito + Acessibilidade
- Ton : respectueux, accessible, jamais condescendant
- Public souvent primo-arrivant ou 2e génération — le jargon suisse est un vrai obstacle
- **Você** (formel-poli) plutôt que "tu" brésilien — la communauté portugaise suisse
  est majoritairement d'origine portugaise, pas brésilienne
- Chaque concept suisse doit être expliqué clairement :
  "O 2º pilar (LPP) é a poupança profissional obrigatória na Suíça."
- Pas d'humour qui suppose une connaissance culturelle suisse — rester informatif et chaleureux
- Référence tonale : journalisme lusophone de qualité, Público (Portugal)

#### Español (ES) — Cercanía + Claridad
- Ton : proche, clair, ni formel ni familier
- Public souvent 2e génération, bilingual — comprend le contexte suisse
- **Tú** (informel) acceptable — cohérent avec le FR et les apps modernes
- Plus de latitude pour l'humour léger que le PT (public plus intégré)
- Référence tonale : El País (clarté), apps espagnoles modernes

### Règles de traduction

1. **Le FR est la langue source** — c'est le template ARB
2. **Chaque traduction est une adaptation culturelle**, pas un mot-à-mot
3. **Les chiffres ne changent pas** — CHF, pourcentages, montants sont universels
4. **Les références légales restent en français** — "LPP art. 14" est le même partout
   (les lois suisses sont publiées dans les 3 langues officielles, mais les sigles FR dominent)
5. **Les ARB `@metadata`** doivent documenter le contexte émotionnel pour aider les traducteurs :
   ```json
   "@pulseNarrativeYearsToAct": {
     "description": "Narrative when user has 6-15 years to retirement. Tone: encouraging, not urgent.",
     "placeholders": { "yearsToRetire": { "type": "int" } }
   }
   ```
6. **Test de qualité** : un natif de chaque langue doit relire les surfaces critiques
   (Aujourd'hui, Coach fallback, onboarding) avant release

### Ce qui est spécifique aux frontaliers

Les frontaliers (FR→CH, IT→CH, DE→CH) ont un contexte unique :
- Impôt à la source (pas déclaration ordinaire)
- Règle des 90 jours (télétravail)
- Charges sociales mixtes (cotisent en CH, résident ailleurs)
- LAMal optionnelle (choix CMU en France)

MINT doit :
- Détecter l'archetype `cross_border` dans le profil
- Adapter le vocabulaire : "ton salaire en Suisse" vs "ton salaire"
- Expliquer les concepts CH sans supposer qu'ils sont connus
- Proposer les écrans frontalier en priorité dans les Response Cards

---

## 10. IMPLÉMENTATION

### Où s'applique ce système

| Surface | Priorité | Volume |
|---------|----------|--------|
| **Narrations Pulse** (Aujourd'hui) | Critique — vu chaque session | ~10 variantes |
| **Coach fallback templates** | Critique — quand LLM down | ~20 templates |
| **Coach system prompt** | Critique — guide le ton LLM | 1 prompt |
| **Titres d'écrans** (101 screens) | Haute — première impression | ~100 titres |
| **Chiffre-choc captions** | Haute — sous chaque nombre dominant | ~30 captions |
| **CTAs** (boutons) | Haute — déclenchent l'action | ~80 CTAs |
| **Labels de statut** | Moyenne — feedback récurrent | ~10 labels |
| **Empty states** | Moyenne — premier contact avec une section | ~20 states |
| **Milestones / achievements** | Basse — gamification | ~15 messages |
| **ARB translations** (6 langues) | Chaque modification FR → 5 traductions | Total ~3000 keys |

### Processus de rédaction

1. **Écrire le texte en français** selon ce guide
2. **Relire à voix haute** — si ça sonne comme une notice, réécrire
3. **Test du banquier** : un directeur de banque de 55 ans se sentirait-il respecté ?
4. **Test du barista** : un barista de 25 ans comprendrait-il sans chercher ?
5. **Test du sourire** : quand le contexte s'y prête, un trait d'esprit. Jamais sur erreur, deuil, sécurité, consentement.
6. **Ajouter aux 6 ARB** — les traductions doivent garder le même esprit, pas mot-à-mot

### Adaptation au profil (code)

```dart
// Le ton s'adapte via profile.age et profile.financialLiteracyLevel
// Mais les MÊMES chiffres, le MÊME respect, la MÊME honnêteté
String narrativeFor(CoachProfile profile) {
  final years = profile.effectiveRetirementAge - profile.age;
  if (years <= 5)  return '${profile.firstName}, ta retraite approche. Chaque décision compte.';
  if (years <= 15) return '${profile.firstName}, tu as $years ans pour agir. C\'est le bon moment.';
  if (years <= 25) return '${profile.firstName}, tu as le temps de construire. Voici où tu en es.';
  return '${profile.firstName}, ton avenir financier commence ici. Un chiffre à la fois.';
}
```
