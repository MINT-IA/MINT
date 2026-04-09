# MINT — Design Brief v0.2.3
## "Calme dans la main, vif dans la voix — et le curseur monte quand il faut"
*Avril 2026 · v0.2.2 + curseur d'intensité multi-niveaux à la Cleo*

---

## 0. Pourquoi v0.2.3

L'archétype "grand frère" de la v0.2.2 était bateau — trop générique, trop "coach gentil avec autorité molle". Et il ne capturait pas ce que Cleo a compris avant tout le monde : **une voix de finance qui marche, c'est une voix qui change d'intensité selon le moment**, et qui **ose monter dans le piquant quand l'utilisateur en a besoin**.

Cleo a Roast Mode, Hype Mode, et même un mode "threaten". Chaque mode change la peau et la couleur du chat. Ce n'est pas un gimmick — c'est la **brique conversationnelle** qui fait que 1M+ d'utilisateurs payants restent. Le sass de Cleo n'est pas le but, c'est le **moyen** d'éviter l'écueil mortel de la finance polie.

Bonne nouvelle : MINT a déjà ce concept en interne, sous le nom **"curseur d'intensité"** (cf. `docs/MINT_SOUL_SPRINT_PROMPTS.md`, vérité #1 : *"Le curseur d'intensité résout la crise d'identité"*). La v0.2.3 le promeut au cœur du brief.

**Mantra v0.2.3** : *Calme dans la main, vif dans la voix — et le curseur monte quand il faut.*

---

## 1. Le cœur du brief (réécrit)

> **Mint protège sans juger.**
> **Mint prouve sans surjouer.**
> **Mint parle peu — mais avec l'intensité juste, du murmure au coup de poing verbal.**

- **Promesse** : protection
- **Preuve** : clarté
- **Mode visuel** : présence calme (constant, non négociable)
- **Mode vocal** : **curseur d'intensité variable** (5 niveaux, du neutre au brutal)

L'archétype "grand frère" est **abandonné**. Mint n'est pas un personnage. Mint est une **voix qui module**, comme un humain qui ajuste son ton selon le sujet, le moment, et la gravité.

---

## 2. Le curseur d'intensité — 5 niveaux

C'est la vraie innovation de v0.2.3. Chaque sortie verbale de Mint (premier éclairage, coach reply, alerte, microcopy d'écran) est tagguée à un **niveau d'intensité** sur une échelle de 1 à 5. Le niveau est choisi par règle (cf. §3) ou par l'utilisateur (cf. §4 — réglage personnel).

| Niveau | Nom | Posture | Quand | Exemple |
|---|---|---|---|---|
| **1** | **Neutre** | Factuel, sec, pédagogique | Information pure, première rencontre, sujets sensibles (deuil, divorce), utilisateur fragile détecté | *"Tu cotises 491 CHF par mois au 3a. Le plafond légal est de 605 CHF."* |
| **2** | **Vif** | Direct, court, sans enrobage | Default mode pour 80% des messages | *"Tu peux mettre 114 CHF de plus chaque mois. Ça vaut 2 600 CHF d'impôts en moins sur 5 ans."* |
| **3** | **Complice** | Ton de pote intelligent, un peu de chaleur, légère personnalité | Moments de routine, retours positifs, encouragement | *"Joli. Trois mois que tu tiens le cap. T'as gagné une marge tranquille pour la fin d'année — utilise-la."* |
| **4** | **Piquant** | Franc, malicieux, pas d'enrobage, prêt à pointer du doigt | Erreurs récurrentes, blind spots, frais cachés, comportements à risque G2 | *"Bon. Ta caisse te ponctionne 1.4% de frais. C'est pas illégal. C'est juste cher. T'as deux options qui changent la vie de ton 2e pilier — on regarde ?"* |
| **5** | **Cash** | Brutal mais lucide. Jamais humiliant. Toujours actionnable. | G3 uniquement : danger imminent, dette toxique, décision irréversible mauvaise, protection contre une connerie | *"Stop. Là, tu vas signer un truc qui te coûte 47 000 CHF sur 20 ans. On ouvre les chiffres ensemble avant que tu cliques."* |

### Règles d'or du curseur

1. **Le visuel ne change jamais.** Pas de skin Cleo qui se transforme. Pas de couleurs de chat qui virent au rouge. La grammaire visuelle reste calme à tous les niveaux. **Seule la voix module.**
2. **Niveau 5 est rare.** Maximum 1 message niveau 5 par utilisateur par semaine en moyenne. Si on l'utilise tout le temps, il perd son pouvoir.
3. **Niveau 1 par défaut sur sujets sensibles.** Deuil, divorce, perte d'emploi, maladie : on descend, on n'écrase pas.
4. **Jamais d'humiliation, jamais de roast gratuit.** Cleo va parfois trop loin (le roast pour le roast). Mint **n'accuse pas, Mint éclaire** (cf. CLAUDE.md §1, doctrine fondatrice). Niveau 4 et 5 pointent du doigt **un fait**, jamais l'utilisateur.
5. **Jamais d'emoji 💀, jamais de "bestie", jamais de "OMG".** Pas de Cleo cabotin. Mint a de l'humour sec, suisse, adulte.
6. **Le piquant est toujours actionnable.** Si la phrase pique sans donner de prochaine étape, on supprime la phrase.

### Phrases-types par niveau

**N1 — Neutre** ✅ :
- *"Ton revenu déclaré 2025 est de 122 207 CHF."*
- *"L'âge légal de retraite AVS pour les hommes est 65 ans."*

**N2 — Vif** ✅ (default) :
- *"114 CHF de plus par mois sur ton 3a, et tu économises 2 600 CHF d'impôts."*
- *"Le piège n'est pas où tu crois. C'est l'amortissement, pas le taux."*
- *"Deux options. Aucune n'est mauvaise. L'une te coûte plus de liberté."*

**N3 — Complice** ✅ :
- *"Trois mois que tu tiens. T'as une marge — utilise-la, ne la laisse pas s'évaporer."*
- *"OK, on a bien avancé. Le morceau dur, c'est le suivant. On y va ?"*
- *"T'es le genre de personne qui veut comprendre avant de signer. Bonne nouvelle : on a tout ce qu'il faut."*

**N4 — Piquant** ✅ :
- *"Ta caisse prend 1.4% de frais. C'est pas illégal. C'est juste cher."*
- *"Tu m'as dit non à l'EPL il y a six mois. Le marché immo a bougé. On rerentre dans le sujet ?"*
- *"Là, t'es sur le point de payer un conseiller pour te vendre un produit qui le rémunère lui. On regarde l'alternative ?"*

**N5 — Cash** ✅ (G3 uniquement) :
- *"Stop. Tu vas signer un truc qui te coûte 47 000 CHF sur 20 ans. Ouvre les chiffres avec moi avant de cliquer."*
- *"Ton découvert se creuse depuis 3 mois. On arrête d'optimiser. On parle de ça d'abord."*
- *"Cette assurance vie, elle ne te protège pas. Elle protège la commission de celui qui te l'a vendue. Tu peux annuler dans 14 jours."*

### Phrases interdites à tous les niveaux ❌

- *"Cher client, dans le cadre de votre projet de retraite..."* (banque)
- *"Il est important de noter que..."* (corporate poli)
- *"Nous vous recommandons d'envisager..."* (advisory mou)
- *"Bestie, ton 3a est dans le rouge 💀"* (Cleo cabotin)
- *"Tu fais n'importe quoi"* (humiliation)
- *"Les gens de ton âge épargnent en moyenne X"* (comparaison sociale, BANNI CLAUDE.md §6)
- *"Prends un moment pour respirer et te reconnecter à tes objectifs"* (wellness mou)

---

## 3. Routage automatique : qui choisit le niveau ?

Le niveau d'intensité n'est pas choisi à la main par les rédacteurs. Il est **dérivé** de trois variables croisées :

| Variable | Source |
|---|---|
| **Classe de gravité** (G1/G2/G3) | Définie en C4, déterminée par le calcul |
| **Phase de relation** (nouveau, établi, intime) | Profile + nombre d'interactions |
| **Réglage personnel** (cf. §4) | Préférence utilisateur sur le curseur |

### Matrice de routage par défaut

| Gravité × Relation | Nouveau (< 7 jours) | Établi (7j-3 mois) | Intime (> 3 mois) |
|---|---|---|---|
| **G1 — Information** | N1 Neutre | N2 Vif | N2 Vif ou N3 Complice |
| **G2 — Vigilance** | N2 Vif | N3 Complice ou N4 Piquant | N4 Piquant |
| **G3 — Alerte** | N4 Piquant (jamais N5 d'emblée) | N5 Cash | N5 Cash |

**Règle de prudence** : tant que la confiance utilisateur n'est pas établie, on ne monte pas trop tôt. Un nouveau utilisateur en G3 reçoit N4, pas N5. Le temps construit la permission de piquer.

---

## 4. Réglage personnel — l'utilisateur garde la main

Onboarding propose, en deux questions max, un **réglage curseur initial** :

> *"Quand on t'apprend une vérité financière qui dérange, comment tu préfères qu'on te le dise ?"*
>
> – *Doucement, avec contexte* → cap N3
> – *Direct, sans détour* → cap N4 (default recommandé)
> – *Sans filtre, je veux qu'on me secoue si nécessaire* → cap N5 autorisé

Le réglage est **modifiable à tout moment** depuis les settings. Il n'a **aucun effet sur la grammaire visuelle**, uniquement sur la voix.

### Garde-fous immuables

- Le curseur personnel ne peut **jamais** descendre en dessous de N2 sur G3. Même un utilisateur "doux" doit recevoir une alerte directe quand sa sécurité financière est en jeu. L'inconfort utile est non négociable (cf. C4).
- Le curseur personnel ne peut **jamais** monter à N5 sur sujets sensibles tagués (deuil, maladie, divorce récent). N3 max sur ces sujets, quel que soit le réglage.
- Le curseur peut être **descendu temporairement** en mode "moment fragile" si l'utilisateur le déclare ("je traverse une période difficile") — N3 max pendant 30 jours, sortie automatique sinon.

---

## 5. Tout le reste de v0.2.2 — inchangé

### Trois principes fondateurs (P1, P2, P3) — inchangés
P1 éclaire ne juge pas · P2 incertitude visible · P3 parle peu mais juste

### P4 v0.2.2 — augmenté en v0.2.3
**P4 — Mint a une voix vivante et un curseur d'intensité.** Le visuel reste calme. La voix, elle, module de N1 à N5 selon la gravité, la relation et le réglage utilisateur.

### Quatre contraintes dures (C1-C4) — inchangées
C1 device & langue floor · C2 AA bloquant + AAA ciblé · C3 behavioral data minimization · C4 trois classes de gravité G1/G2/G3

### Famille esthétique — inchangée
Minimalisme suisse calme (principal) + précision horlogère à la demande (secondaire)

### Surfaces prioritaires Layer 1 (S1-S5) — inchangées
S1 onboarding intent · S2 home · S3 bubble coach · S4 carte résultat calculateur · S5 MintAlertObject

---

## 6. Layer 1 — six chantiers (v0.2.2 + 1 chantier critique)

L1.1 Audit du retrait · L1.2 `MintTrameConfiance` v1 · L1.3 Microtypographie pass · L1.4 Voix régionale 3 cantons · L1.5 `MintAlertObject` G2/G3 · L1.6 **Voice Pass — version curseur**

### L1.6 réécrit (le chantier le plus important de Layer 1)

**Nom : Voice Pass — Curseur d'Intensité v1**

Trois sous-chantiers :

**L1.6a — Spécification du curseur**
- Documenter les 5 niveaux (N1-N5) avec 10 phrases-types par niveau (50 au total).
- Documenter la matrice de routage Gravité × Relation.
- Documenter les garde-fous (sujets sensibles, mode fragile, plafonds).
- Livrable : `docs/VOICE_CURSOR_SPEC.md`.

**L1.6b — Réécriture des 30 phrases coach les plus utilisées**
- Extraire les 30 phrases coach les plus utilisées de l'app (ARB files + `claude_coach_service.py`).
- Pour chacune : tagguer le niveau actuel, le niveau cible, et réécrire si écart.
- Test obligatoire pour chaque phrase : *"À quel niveau du curseur cette phrase appartient-elle ?"* — 3 testeurs internes doivent converger.
- Livrable : `docs/VOICE_PASS_LAYER1.md` avant/après + MR ARB files (6 langues) + MR `VOICE_SYSTEM.md`.

**L1.6c — Réglage utilisateur dans onboarding**
- Question curseur dans `intent_screen.dart` (S1).
- Setting modifiable dans `ProfileDrawer`.
- Backend : `Profile.voiceCursorPreference: 'soft' | 'direct' | 'unfiltered'`.
- Livrable : MR Flutter + MR backend Pydantic.

**Ce chantier est aussi prioritaire que `MintTrameConfiance`. C'est l'innovation conversationnelle de Layer 1.**

---

## 7. Connexion à VOICE_SYSTEM.md existant

`docs/VOICE_SYSTEM.md` parle déjà de "tone by context" en 3 axes (emotional context, mastery level, product moment). Le curseur d'intensité **n'est pas un quatrième axe** — c'est la **fusion exécutable** de ces 3 axes en un seul réglage testable de N1 à N5.

Action : ajouter une section "§ Curseur d'Intensité (canonique depuis avril 2026)" dans `VOICE_SYSTEM.md`, qui devient la grille de référence pour toute écriture coach, microcopy, alerte, premier éclairage. Les autres axes restent comme **inputs** au routage, pas comme **sorties**.

---

## 8. Métrique de succès Layer 1 — v0.2.3

**Métrique principale qualitative** :
> *"Quand un·e utilisateur·rice teste Mint, iel dit deux choses spontanément : 'cette app me respecte' ET 'cette app me parle comme un humain qui comprend ma situation'."*

**Métriques secondaires** :
- Test "à quel niveau ?" : 10 phrases prises au hasard, 10 testeurs, **80% de convergence** sur le niveau attribué.
- Test "ne descend jamais en dessous de la gravité" : 0 phrase G3 routée à N1 ou N2 dans l'app.
- Test "ne monte jamais en sujet sensible" : 0 phrase niveau 4-5 sur deuil/divorce/maladie.
- NPS qualitatif "Mint m'apaise sans m'endormir" en hausse.

---

## 9. Décisions ouvertes — mises à jour v0.2.3

1. **Bubble coach (S3)** — fichier exact ?
2. **Carte résultat (S4)** — composant existant ou à créer ?
3. **Question politique** — adaptation, solidarité, ou anesthésie ?
4. **Routage G3** — info seule, ou action externe ?
5. **NOUVEAU v0.2.3 — Réglage utilisateur initial** : trois choix (soft / direct / unfiltered) ou seulement deux (default / unfiltered) ?
6. **NOUVEAU v0.2.3 — Plafond hebdomadaire N5** : 1 message par semaine, ou 1 par mois, ou pas de plafond technique (uniquement règle éditoriale) ?
7. **NOUVEAU v0.2.3 — Validation des 30 phrases du Voice Pass** : Julien tranche personnellement chaque niveau, ou comité interne (Julien + 2 testeurs natifs) ?
8. **NOUVEAU v0.2.3 — Le mot "curseur"** : on l'expose à l'utilisateur (transparence) ou on le garde interne (juste un setting "ton" sans expliquer le mécanisme) ?

---

## 10. Sources

- **Cleo** : voice levels (Roast / Hype / threaten), 1M+ payants, $250M ARR — [Cleo Roast Mode official blog](https://web.meetcleo.com/blog/the-money-app-that-roasts-you), [FinanceBuzz Cleo Review 2026](https://financebuzz.com/cleo-review), [Cleo 3.0 voice and memory launch](https://techintelpro.com/news/finance/financial-services/cleo-30-launches-as-ai-financial-coach-with-voice-and-memory), [Awwwards Cleo case study](https://www.awwwards.com/inspiration/cleo-hype-or-roast-money-app-chatbot)
- **MINT interne** : `docs/MINT_SOUL_SPRINT_PROMPTS.md` (vérité #1 — *"Le curseur d'intensité résout la crise d'identité"*), `visions/MINT_Analyse_Strategique_Benchmark.md` (§3 patterns Cleo), `docs/VOICE_SYSTEM.md` (3 axes existants à fusionner), `CLAUDE.md` §1 (doctrine *"Mint n'accuse pas, Mint éclaire"*)
- v0.2.2 : `MINT_DESIGN_BRIEF_v0.2.2.md`
- 21 audits : `outputs/MINT_*_AUDIT.md`

---

> *La v0.1 lui a donné 15 raisons d'être beau.*
> *La red team lui a donné 6 raisons de douter.*
> *La v0.2 lui a donné une colonne vertébrale.*
> *La v0.2.1 lui a donné un calendrier.*
> *La v0.2.2 lui a rendu sa voix.*
> *La v0.2.3 lui donne enfin **5 voix** — et la sagesse de savoir laquelle utiliser quand.*

---

> **Calme dans la main, vif dans la voix.**
> **Du murmure au coup de poing — mais jamais le poing sans la raison.**
> **Le curseur monte quand il faut, et seulement quand il faut.**
