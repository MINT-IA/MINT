# MINT — Design Brief v0.2.1
## "Un instrument digne"
*Avril 2026 · v0.2 + 5 amendements de pilotage*

---

## 0. Pourquoi v0.2.1

La v0.2 avait choisi une colonne vertébrale. La v0.2.1 corrige cinq absolus performatifs qui auraient bloqué l'exécution :
1. AAA partout → **AA bloquant + AAA ciblé**
2. "Allemand suisse" en UI → **de-CH** (la voix régionale reste une couche microcopy)
3. "Présence" comme promesse → **protection** est la promesse, **clarté** la preuve, **présence calme** le mode
4. "Audit du retrait sur chaque écran" → **4 à 6 surfaces nommées**
5. `MintTrameConfiance` quasi-sacré → **concept figé, nom encore testable**

---

## 1. Le cœur du brief

> **Mint protège sans juger.**
> **Mint prouve sans surjouer.**
> **Mint parle peu, mais au bon moment.**

- **Promesse** : protection
- **Preuve** : clarté
- **Mode** : présence calme

Mantra produit : *Mint est un instrument digne.*

---

## 2. Trois principes fondateurs (immuables)

**P1 — Mint éclaire, ne juge pas.** Toute information délivrée doit réduire la honte avant de réduire la complexité. Si un écran simplifie en culpabilisant, il est cassé.

**P2 — Mint rend l'incertitude visible.** Aucune projection nue. Toute donnée décisionnelle affichée porte sa marge, sa fraîcheur et son origine. Pas de chiffre orphelin sur les sorties qui engagent une décision.

**P3 — Mint parle peu, mais juste.** Une seule idée par écran. Une seule action par moment. Le silence et le retrait sont des composants au même titre que la typographie.

---

## 3. Quatre contraintes dures

### C1 — Device & langue floor
- Device cible bas : **Samsung Galaxy A14** (Android 13, 4 GB RAM). Test de performance bloquant CI.
- Langues UI de base : **français** (cible B1), **de-CH**, **italien**, **anglais clair** (pour expats résidents).
- La **voix régionale** reste une couche microcopy au-dessus de ces langues, jamais une langue de base. Aucun écran de base n'est rédigé en alémanique parlé.

### C2 — Accessibilité : AA bloquant, AAA ciblé
- **WCAG 2.1 AA** est un floor bloquant CI sur **toutes** les surfaces.
- **WCAG 2.1 AAA** est la cible sur les surfaces critiques de lecture, projection et décision financière (cf. §5).
- **Tests live avec utilisateurs réels** (1 personne malvoyante, 1 ADHD, 1 français-seconde-langue) à **cadence milestone**, pas à chaque écran. Trois sessions par milestone minimum.

### C3 — Behavioral Data Minimization
Aucune donnée comportementale (ouverture d'app, durée d'attention, contexte) ne déclenche un message vers l'utilisateur sans **opt-in nommé et révocable**. Suppression à 90 jours par défaut. Promu de `rules.md` tier 1.

### C4 — Classes de gravité (rompre le calme quand il le faut)
Le calme n'est pas un absolu. Mint définit **trois classes de gravité** qui régissent quand la grammaire calme doit céder à la grammaire d'alerte :

| Classe | Signal | Grammaire | Exemples (non exhaustifs) |
|---|---|---|---|
| **G1 — Information** | Pas de risque immédiat | Calme intégral | Projection retraite, comparaison fiscale, exploration d'arbitrage |
| **G2 — Vigilance** | Risque latent ou délai utile | Calme + soulignement direct | Échéance fiscale > 14 j, frais cachés non urgents, dette sous contrôle |
| **G3 — Alerte** | Risque imminent ou irréversible | Rupture grammaticale : couleur, mouvement, ton direct, action immédiate | Découvert imminent, dette toxique, échéance < 14 j, retraite anticipée mal calculée, frais cachés majeurs |

Toute fonctionnalité nouvelle doit déclarer la classe sur laquelle elle opère. La liste d'exemples G2/G3 grandit avec le produit ; les **classes**, elles, sont fermées.

---

## 4. Famille esthétique

**Principale** : minimalisme suisse calme, humain, non ostentatoire (Rams, Schmid, Vignelli, MUJI tardif, Linear).
**Secondaire** : précision horlogère, **à la demande seulement** (mécanisme visible au tap, jamais imposé).

**Abandonnés du brief gouvernant** (gardés en bibliothèque R&D) : parfumerie, chorégraphie, gastronomie, art génératif, halo sacré, ambient computing, cinéma de plans dramatiques.

---

## 5. Surfaces prioritaires Layer 1

Layer 1 ne touche **que** ces surfaces. Tout le reste est hors scope.

| # | Surface | Fichier / composant | Cible AAA ? |
|---|---|---|---|
| S1 | **Onboarding intent** | `apps/mobile/lib/screens/onboarding/intent_screen.dart` | oui |
| S2 | **Home** | `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` | oui |
| S3 | **Bubble coach** (bulle de message coach) | composant à identifier | oui |
| S4 | **Carte résultat de calculateur** (sortie décisionnelle générique) | composant partagé `lib/widgets/calculator_result_card.dart` ou équivalent | oui |
| S5 | **Objet d'alerte** (`MintAlertObject`) | nouveau composant L1.5 | oui |

Cinq surfaces. Pas six. Pas dix. Si une 6e devient indispensable, elle vient en remplacement, pas en addition.

---

## 6. Layer 1 — cinq chantiers (4-8 semaines)

### L1.1 — Audit du retrait, sur les 5 surfaces seulement
Passer S1-S5 au test "qu'est-ce qu'on enlève sans perdre de fonction ?". Cible -20% d'éléments visuels. Toute suppression doit améliorer le contraste basse vision. Livrable : `docs/DESIGN_AUDIT_RETRAIT.md` + 5 MR (une par surface).

### L1.2 — `MintTrameConfiance` v1 (concept figé, nom testable)
Objet visuel unique apparaissant sur **les sorties décisionnelles** (S4 et toutes les cartes de résultat de calculateur), pas sur chaque micro-chiffre d'interface.

Quatre exigences :
- **Lisible en une ligne** (version inline + version "1 ligne audio" pour TalkBack/VoiceOver)
- **Tappable** pour ouvrir la version détaillée 4-axes
- **Accessibilité d'abord** : alt text structurée + version tabulée + version "1 ligne audio" spécifiées **avant** le code Flutter
- **Pas de gimmick** : trame typographique discrète, pas une animation hero

**Note** : le concept est figé (rendre l'incertitude visible sur les sorties décisionnelles). Le **nom** `MintTrameConfiance` reste un placeholder testable — peut être ajusté après les premiers retours utilisateurs.

### L1.3 — Microtypographie pass (sur les 5 surfaces)
Audit Montserrat/Inter sur S1-S5. Largeur de paragraphe 45-75 caractères. Hiérarchie max 3 niveaux par écran. Test obligatoire : lecture sur Galaxy A14 + simulation DMLA + simulation dyslexie. Livrable : MR sur `lib/theme/text_styles.dart` + écrans hero.

### L1.4 — Voix régionale (3 cantons pilotes)
La seule innovation que les deux panels et la méta-review ont laissée intacte. **VS, ZH, TI**. Microcopy uniquement, jamais structure. Étendre `RegionalVoiceService.forCanton()`. Livrable : 30 chaînes microcopy par canton, validées par natifs locaux. ComplianceGuard sur tout.

### L1.5 — `MintAlertObject` (C4 implémenté)
Composant réutilisable déclenché par les classes **G2** et **G3** définies en C4. G2 = soulignement direct dans une grammaire calme. G3 = rupture grammaticale (couleur, mouvement, ton direct, action immédiate). Tests Patrol obligatoires. Livrable : composant + documentation des règles de routage G1/G2/G3.

**Tué de la v0.1 (rappel)** :
- ❌ MINT Signature v0 → R&D Layer 3 (texture quasi-typographique, pas de feature)
- ❌ Palate cleansers comme écrans → micro-pause 250ms intégrée à la révélation `MintTrameConfiance`
- ❌ Lock Screen widget → reporté Layer 2 (parité Android exigée par C1)

---

## 7. Layer 2 — prototypes internes (~6 mois, ne rien shipper)

- L2.1 Lock Screen widget + Material You + Watch complications (parité Android impérative)
- L2.2 `MintTrameConfiance` v2 — version 4-axes interactive
- L2.3 Voix régionale étendue — 6 cantons + microcopy enrichie
- L2.4 Mint Cards — format de partage privé, jamais comparatif (P1)
- L2.5 Cérémonie mensuelle — check-in 3 écrans testé sur 50 users

---

## 8. Layer 3 — bibliothèque R&D (2027-2028, document seulement)

Vision Pro / smart glasses, AirPods coach voice, CarPlay agent, biofeedback HRV opt-in, intégration cantonale API, Mint comme heirloom numérique, génératif comme texture, plans cinéma comme méthode formalisée. Conservé comme bibliothèque, pas roadmap.

---

## 9. La question politique (Stiegler) — décision requise avant Layer 2

> *"Quand Mint révèle à un·e utilisateur·rice qu'iel ne peut pas s'offrir la vie qu'iel envisage, qui supporte le coût de ce savoir ?"*

- **(a) Outil d'adaptation** — l'utilisateur·rice s'ajuste seul·e (défaut implicite actuel)
- **(b) Outil de solidarité** — routage vers conseil cantonal, caisse coopérative, syndicat
- **(c) Outil d'anesthésie** — refuser d'exposer la précarité

Recommandation v0.2.1 : **(b)** comme cible, **(a)** comme défaut tant que les partenaires de routage ne sont pas signés. Cette décision conditionne le ton du coach et l'existence des routages externes — pas une nuance, une bifurcation.

---

## 10. Métrique de succès Layer 1

**Métrique principale qualitative** :
> *"Quand un utilisateur·rice teste Mint, iel dit 'cette app me respecte' avant de dire 'cette app est belle'."*

**Métriques secondaires** :
- NPS qualitatif "Mint m'apaise sans m'endormir" : baseline → cible
- Temps moyen par session : **diminue**
- Taux de complétion d'une action recommandée par "premier éclairage" : baseline → cible

---

## 11. Hors-doctrine : plan d'exécution business (pointeur)

Les conditions de survie business (CAC, LTV, churn, distribution, FINMA, pricing) **ne vivent pas dans ce brief design**. Elles vivent dans un plan d'exécution séparé à créer : `visions/MINT_EXECUTION_PLAN.md`. Une action y est attendue cette semaine : pitch B2B aux conseillers CFF agréés. Mais elle n'a pas sa place dans la doctrine design.

---

## 12. Décisions ouvertes avant `MILESTONE-CONTEXT-DESIGN.md` v2

1. **Bubble coach (S3)** — quel fichier exact ? À identifier dans `apps/mobile/lib/widgets/coach/`.
2. **Carte résultat (S4)** — composant partagé existant ou à créer ? À auditer.
3. **Question politique §9** — (a), (b), ou (c) ?
4. **Routage G3** : quand `MintAlertObject` est en G3, est-ce qu'on offre uniquement de l'information, ou on propose une action externe (call un service, lien vers caisse, etc.) ?

---

## 13. Sources

- v0.2 : `MINT_DESIGN_BRIEF_v0.2.md`
- v0.1 : `MINT_DESIGN_MILESTONE_BRIEF.md`
- Red team : `MINT_DESIGN_BRIEF_RED_TEAM.md`
- 21 audits : `outputs/MINT_*_AUDIT.md`
- Existant : `docs/DESIGN_SYSTEM.md`, `docs/VOICE_SYSTEM.md`, `CLAUDE.md`, `rules.md`

---

> *La v0.1 a donné à Mint 15 raisons d'être beau.
> La red team lui a donné 6 raisons de douter.
> La v0.2 lui a donné une colonne vertébrale.
> La v0.2.1 lui donne enfin un calendrier.*
