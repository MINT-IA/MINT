# MINT — Red Team du Design Milestone Brief
## Méta-synthèse de 6 audits adverses
*Avril 2026 · v0.1*

---

## 0. Le mandat

Six expert·e·s, choisis pour leur **distance** vis-à-vis du milieu design, ont audité le brief design produit la veille (`MINT_DESIGN_MILESTONE_BRIEF.md`) et le milestone-context GSD. Mandat : itérer plusieurs fois, refuser les premières réponses statistiques, exposer ce que les 15 designers du premier panel ne pouvaient pas voir.

| # | Expert | Angle | Rapport |
|---|---|---|---|
| 1 | Harry Brignull's heir | Dark patterns, manipulation cachée sous "calme" | `outputs/MINT_AUDIT_DARK_PATTERNS.md` |
| 2 | Disability-justice practitioner | Inclusion réelle vs claim "18-99 ALL" | `outputs/MINT_AUDIT_ACCESSIBILITY.md` |
| 3 | Fatou (lived-experience, Vernier) | Mère célibataire, B1 français, Galaxy A14 | `outputs/MINT_AUDIT_FATOU.md` |
| 4 | Philosophe de la technique (Han/Zuboff/Stiegler) | Théologie cachée du brief | `outputs/MINT_AUDIT_PHILOSOPHY.md` |
| 5 | Trois fondateurs fintech morts | Post-mortem business | `outputs/MINT_AUDIT_POSTMORTEM.md` |
| 6 | Sémioticien (Barthes/Greimas) | Système de signes, mythe MINT | `outputs/MINT_AUDIT_SEMIOTIC.md` |

---

## 1. Les six accusations (en une phrase chacune)

1. **Brignull** : "Le calme est devenu une faille de conformité — MINT remplace le dark pattern dashboard par une surveillance ambiante enveloppée du langage du soin."
2. **Accessibility** : "Le brief affirme designer pour 18-99 mais ne fonctionne que pour un·e francophone neurotypique de 28-55 ans, voyant·e, à l'aise avec les gestes — soit 18-20% de la population suisse."
3. **Fatou** : "C'est beau pour quelqu'un d'autre. Aucun des 7 chantiers Layer 1 ne me fait économiser 200 CHF cette année."
4. **Philosophe** : "Le brief croit secrètement que la souffrance financière est un déficit d'information. C'est une théologie de la clarté qui désarme la critique structurelle."
5. **Postmortem** : "Beauté n'est pas distribution. À 24 mois, MINT meurt d'un mélange de churn 47%, lettre FINMA, Series A qui ne ferme pas — pendant qu'on peaufine le halo de confiance."
6. **Sémioticien** : "MINT raconte le mythe du Gardien Calviniste Calme — cohérent, puissant, mais le brief mélange 'simulation' (qui dit 'faux'), 'halo' (sacré) et watchmaking (perfection) sans choisir."

---

## 2. Les sept failles convergentes

Quand six personnes qui ne se parlent pas pointent **la même** chose, c'est structurel. Voici ce qu'elles disent toutes — ou presque toutes.

### F1 — Le calme cache de la manipulation (5/6 voix : Brignull, Philosophe, Postmortem, Sémioticien, Fatou par contraste)
"Calme" n'est pas un trait neutre. Il est :
- une **anesthésie** (Han)
- une **protection contre la critique** (les utilisateurs ne challengent pas un message livré doucement — Brignull)
- un **substitut à la distribution** (postmortem : on confond beauté et raison de revenir)
- le **mauvais signe pour Fatou** (le calme est un luxe de ceux qui peuvent ralentir)

**Action obligée** : ajouter au brief une section "Où MINT doit délibérément être inconfortable", listant 3-5 moments où le calme serait une faute professionnelle (alerte de découvert imminent, frais cachés détectés, échéance fiscale, etc.).

### F2 — "18-99 ALL" est faux (3/6 voix très fortes : Accessibility, Fatou, Postmortem)
La cible réelle du brief est : 28-55 ans, salarié·e LPP, francophone natif, voyant·e, neurotypique, smartphone récent, partenaire optionnel·le. Tout le reste est une illusion gratuite.

Le mensonge est dans le principe immuable n°10 ("Designer pour 18 et 99 dans le même geste"). Le brief n'est pas designé pour 78 ans avec DMLA. Il n'est pas designé pour 41 ans, B1 français, Galaxy A14. Il n'est pas designé pour ADHD. Il n'est pas designé pour des oreillettes filaires cassées.

**Action obligée** : choisir **soit** assumer que MINT est pour la classe moyenne francophone urbaine (et l'écrire honnêtement), **soit** redéfinir Layer 1 avec la contrainte "doit fonctionner pour Marthe (78, DMLA) ET pour Fatou (41, B1, Galaxy A14)". On ne peut pas faire les deux à la fois et c'est ça la décision politique du milestone.

### F3 — Le brief ne contient ni prix, ni distribution, ni régulateur, ni rétention (1 voix très forte : Postmortem, échos chez les 5 autres)
Pas une ligne sur :
- Combien MINT facture
- Comment on acquiert un utilisateur
- Comment on garde un utilisateur (churn target)
- Quelle conversation avec FINMA est ouverte
- Quelle économie API Claude (le coût LLM est invisible)
- Quel canal B2B (caisses, RH, advisors)

C'est un brief design qui se croit autonome. **Aucun design ne survit sans ces colonnes.** Le postmortem démonte le calendrier 24 mois jusqu'à la lettre FINMA et le Series A qui ne ferme pas.

**Action obligée** : ajouter au brief un §7 "Conditions de survie business" avec 5 nombres cibles (CAC, LTV, churn, CAC payback, taux de conversion gratuit→payant) et 1 décision sur le canal de distribution. Si Julien ne sait pas, écrire "à découvrir avant Layer 2".

### F4 — `<ConfidenceObject>` est un piège accessibilité ET sémiotique (2 voix techniques : Accessibility, Sémioticien)
Le composant central du Layer 1 est :
- **Inaccessible** au screen reader (helix 4-axes = impossible à narrer sans alternative texte structurée)
- **Mal nommé** : "Halo" est un signe sacré (transcendance, jugement) ; "Trame" est un signe textile (artisanat, tissage). Le choix n'est pas de typographie — c'est une décision théologique. Le sémioticien recommande **`MintTrameConfiance`** pour rester du côté humain/artisanal et éviter le glissement vers la cathédrale.

**Action obligée** : (a) figer le nom à `MintTrameConfiance` dans le milestone-context. (b) Spec accessibilité **avant** le code : alt text structurée, version texte tabulée, version "1 ligne" pour widget, version "audio" pour AirPods coach. Pas de helix qui ne peut pas être lu autrement.

### F5 — Wabi-sabi + watchmaking + perfumery + Swiss reserve = un système de signes qui se cannibalise (2 voix : Sémioticien, Philosophe)
- Wabi-sabi (imperfection, contingence) ↔ watchmaking (précision absolue) — choc.
- Calme (sédation) ↔ premier éclairage (révélation, feu) — choc.
- Borrowing du *ma* japonais par une fintech suisse — sincère ou extractif ? (Yuk Hui : extractif si sans cosmologie).
- 10 principes immuables (commandements) ↔ wabi-sabi (humilité) — choc.

Le brief n'a pas tranché. Il prend tout. Le résultat est un système qui ne peut pas se défendre quand un journaliste design le challengera.

**Action obligée** : choisir une famille principale, une famille secondaire, et **abandonner** les autres. Recommandation issue de la convergence des audits : **wabi-sabi minimaliste suisse** (famille principale) + **watchmaking pour la précision financière** (famille secondaire, visible à la demande seulement). On laisse tomber les références parfumerie et chorégraphie au niveau du brief — on les garde comme inspirations internes uniquement.

### F6 — La théologie cachée n'a pas été nommée (1 voix unique : Philosophe — donc d'autant plus précieuse)
Le brief croit que **la souffrance financière est un déficit d'information**. Si c'est vrai, MINT est un succès. Si c'est faux (et c'est faux pour Fatou, et pour 35-40% des résident·e·s suisses qui vivent des contraintes structurelles, pas informationnelles), alors MINT optimise les gens à l'intérieur d'une injustice qu'il refuse de voir.

C'est une question politique qui ne peut pas rester implicite.

**Action obligée** : Julien doit répondre à cette question avant Layer 2 :
> "Quand MINT révèle à un·e utilisateur·rice qu'iel ne peut pas s'offrir la vie qu'iel envisage, qui supporte le coût de ce savoir ?"
> Trois réponses possibles : (a) tool of adaptation (l'utilisateur s'ajuste seul) ; (b) tool of solidarity (le savoir nourrit une action collective — passage vers une caisse coopérative, vers un service social, vers un syndicat) ; (c) tool of anesthesia (refuser de faire émerger la précarité). Le brief actuel suppose (a). Il faut le savoir.

### F7 — Plusieurs choses du brief sont vraies seulement pour un device, un système, une langue (3 voix : Accessibility, Fatou, Postmortem)
- Lock Screen widget = iOS only (Android est plus complexe et arrive tard)
- Watch complication = Apple Watch only (8% du marché suisse, beaucoup moins chez Fatou)
- AirPods coach voice = AirPods (idem)
- Generative MINT signature = devices récents avec GPU décent
- Animations 250ms ease-out = Galaxy A14 sue déjà sur les transitions
- Voix régionale française = exclut allemand suisse, italien, romanche, anglais expat

**Action obligée** : ajouter au milestone-context une matrice "Device & Langue Floor" — ce qui doit fonctionner sur le Galaxy A14 de Fatou et le Nokia G22 de la maman de Marthe avant qu'on parle de Vision Pro.

---

## 3. Le seul accord positif des six audits

Tous reconnaissent — y compris Fatou et la philosophe — un point :

> **La voix régionale subtile (microcopy par canton, jamais structure) est la seule innovation du brief qui survit à tous les tests adverses.** Elle est cohérente neurologiquement (calmant amygdalien), respectueuse politiquement (pas extractive), peu coûteuse techniquement, vérifiable concrètement, et différenciante de tout ce que les banques suisses font. C'est le **noyau dur** à protéger.

Tout le reste est négociable. Pas la voix régionale.

---

## 4. Le brief réécrit en cinq actions concrètes

Voici ce qui doit changer dans `MINT_DESIGN_MILESTONE_BRIEF.md` et `MILESTONE-CONTEXT-DESIGN.md` avant que GSD démarre.

### A1 — Renommer et reficher Layer 1
De 7 chantiers à **5 chantiers chirurgicaux**, parce que les 6 audits ont tué deux candidats :
- ❌ **MINT Signature v0** (génératif) — Brignull dit "promesse non tenue", Accessibility dit "inutilisable au screen reader", Fatou dit "ça ne sert à rien", Philosophe dit "esthétisation de la donnée personnelle = surveillance déguisée". À reporter en R&D Layer 3 si jamais.
- ❌ **Palate cleansers** (écrans de respiration) — Postmortem dit "personne ne paie pour des écrans vides", Accessibility dit "ADHD friction", Fatou dit "j'ai pas le temps". À supprimer purement.

Les 5 chantiers qui survivent :
1. **Audit du vide** — gardé tel quel, mais avec une contrainte ajoutée : tout vide doit avoir un test contraste élevé pour basse vision.
2. **`MintTrameConfiance` v1** — gardé, renommé, avec spec accessibilité **avant** le code (alt text, version tabulée, version 1-ligne widget, version audio).
3. **Microtypographie** — gardé, mais étendu à un test de lisibilité Galaxy A14 + DMLA simulée.
4. **Lock Screen widget** — gardé, mais avec parité Android (Material You widget) **dès Layer 1**, sinon on ne le ship pas.
5. **Voix régionale 3 cantons pilotes** — gardé tel quel. Le seul chantier qui sort indemne.

### A2 — Ajouter un §7 "Conditions de survie business" au brief
Cinq nombres cibles + une décision distribution. À remplir par Julien avant GSD.

### A3 — Ajouter un §8 "Où MINT doit être inconfortable"
Liste de 3-5 moments où le calme serait une faute :
- Découvert imminent
- Frais cachés détectés dans un certificat LPP
- Échéance fiscale dans < 14 jours
- Détection d'une dette toxique (Safe Mode, déjà dans CLAUDE.md)
- Refus de retraite anticipée mal calculée

Dans ces moments, MINT doit **rompre la grammaire calme**. Couleur, mouvement, ton plus direct. C'est le seul moment où l'amygdale doit s'activer — et le système doit le savoir.

### A4 — Ajouter un §9 "Matrice device & langue floor"
Liste minimale : device cible bas (Galaxy A14, RAM 4GB, Android 13), data plan rationné (19 CHF unlimited mais 4G partial), langue minimale (français B1 + alémanique + italien + anglais). Tout chantier Layer 1 doit cocher cette matrice avant merge.

### A5 — Ajouter un §10 "La question politique" et la poser à Julien
Reformuler la question de Stiegler/Han en une décision business : MINT, quand il révèle l'impossibilité, est-il (a) un outil d'adaptation, (b) un outil de solidarité, ou (c) un outil d'anesthésie ? Pas d'ambiguïté possible. Le réglage de la voix coach, le contenu des "premier éclairage", et le routage vers des services tiers (services sociaux, conseil cantonal, caisses coopératives) **dépendent** de cette réponse.

---

## 5. Trois lignes à ajouter à `rules.md` (tier 1, immuable)

Ces trois règles convergent depuis trois audits indépendants. Elles méritent d'être promues au tier 1.

> **R1 — Behavioral Data Minimization** (Brignull) : MINT ne peut pas utiliser de capteurs comportementaux (ouverture d'app, durée d'attention, contexte) pour initier un message vers l'utilisateur, sauf si l'utilisateur s'est inscrit à une fonctionnalité nommée et peut la révoquer. Toute donnée comportementale est supprimée sous 90 jours par défaut.

> **R2 — WCAG 2.1 AAA Floor + Real Users with Disabilities** (Accessibility) : Aucun écran ne ship sans test WCAG 2.1 AAA et test live avec au moins une personne malvoyante, une personne ADHD, et une personne dont le français est seconde langue.

> **R3 — Device & Language Floor** (Fatou) : Tout chantier doit fonctionner sur Samsung Galaxy A14 (Android 13, 4 GB RAM) et en français B1, avant qu'on parle de Vision Pro ou de prose littéraire. C'est un test bloquant CI, pas un nice-to-have.

---

## 6. Decision points pour Julien (urgents — avant GSD)

Le brief original avait 5 decision points. La red team en ajoute 6 plus durs :

7. **Cible réelle assumée** : 28-55 ans CSP+ francophone (honnête) OU contrainte universelle 18-99 vraie (réimagine Layer 1) ?
8. **Théologie politique** : MINT est outil d'adaptation, de solidarité, ou d'anesthésie quand il révèle l'impossibilité ?
9. **Famille de signes principale** : wabi-sabi minimaliste suisse + watchmaking second OU autre choix explicite ?
10. **Sacrifier le génératif** : Layer 1 abandonne la MINT Signature, oui ou non ? (Recommandation red team : oui.)
11. **Sacrifier les palate cleansers** : oui ou non ? (Recommandation red team : oui.)
12. **Email de la semaine** : envoyer le pitch advisor B2B (postmortem) avant ou après le milestone design ? (Recommandation red team : avant.)

---

## 7. Ce que la red team **n'a pas** réussi à démolir

Pour être juste — toute red team doit pouvoir nommer ce qui résiste à l'attaque :

1. **La voix régionale** (unanime).
2. **L'idée du `MintTrameConfiance`** comme principe (rendre l'incertitude visible) — la critique porte sur le **comment**, pas sur le **quoi**.
3. **L'audit du vide** — quoique recadré pour basse vision, le principe "qu'est-ce qu'on enlève" tient.
4. **L'interdiction de la comparaison sociale** (CLAUDE.md §6) — chaque audit la cite comme une force.
5. **Le mythe du gardien calviniste calme** (Sémioticien) — cohérent, défendable, reconnaissable.

Le reste est négociable.

---

## 8. La phrase finale

> "Le premier panel a donné à MINT 15 raisons d'être beau. Le deuxième panel lui a donné 6 raisons de douter. Les deux ensemble lui donnent une chance d'être vrai."

---

*Sources : 6 audits intégraux dans `/outputs/MINT_AUDIT_*.md`. Ce document doit être lu **avec** `MINT_DESIGN_MILESTONE_BRIEF.md` et précède la mise à jour de `MILESTONE-CONTEXT-DESIGN.md`.*
