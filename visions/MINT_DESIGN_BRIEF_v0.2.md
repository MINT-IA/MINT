# MINT — Design Brief v0.2
## "Un instrument calme"
*Avril 2026 · fusion gouvernable des v0.1 + red team*

---

## 0. Pourquoi v0.2

La v0.1 (15 experts créatifs) a ouvert l'imaginaire. La red team (6 voix adverses) a forcé le brief à répondre aux questions adultes. La v0.2 garde ce qui résiste aux deux : elle est plus courte, plus tranchée, plus exécutable.

**Mantra unique** : *Mint est un instrument calme.*
Pas une fintech artiste. Pas une expérience immersive. Un instrument — sobre, fiable, intime.

---

## 1. Trois principes fondateurs (immuables)

**P1 — Mint éclaire, ne juge pas.**
Toute information délivrée à l'utilisateur·rice doit réduire la honte avant de réduire la complexité. Si un écran simplifie en culpabilisant, il est cassé.

**P2 — Mint rend l'incertitude visible.**
Aucune projection nue. Toute donnée affichée porte sa marge, sa fraîcheur et son origine. Pas de chiffre orphelin.

**P3 — Mint parle peu, mais juste.**
Une seule idée par écran. Une seule action par moment. Le silence et le retrait sont des composants au même titre que la typographie.

*Ces trois principes remplacent les 10 anciens. Tout principe additionnel doit être prouvé sur le terrain avant promotion.*

---

## 2. Quatre contraintes dures (non négociables)

**C1 — Device & langue floor**
Tout chantier doit fonctionner sur Samsung Galaxy A14 (Android 13, 4 GB RAM) et en français B1, allemand suisse, italien. Test bloquant CI. Pas d'AirPods, pas de Vision Pro, pas de Apple Watch dans le cœur du brief.

**C2 — Accessibilité WCAG 2.1 AAA + tests réels**
Aucun écran ne ship sans test WCAG 2.1 AAA et test live avec au moins une personne malvoyante, une personne ADHD, et une personne dont le français est seconde langue. Promu de `rules.md` tier 1.

**C3 — Behavioral Data Minimization**
Aucune donnée comportementale (ouverture d'app, durée d'attention, contexte) ne déclenche un message vers l'utilisateur sans opt-in nommé et révocable. Suppression à 90 jours par défaut. Promu de `rules.md` tier 1.

**C4 — Où Mint doit être inconfortable**
Le calme n'est pas un absolu. Mint rompt la grammaire calme dans 5 cas définis : découvert imminent, frais cachés détectés, échéance fiscale < 14 jours, dette toxique (Safe Mode), retraite anticipée mal calculée. Dans ces moments, la couleur, le mouvement et le ton deviennent direct·s. C'est une faute professionnelle de rester doux quand l'utilisateur·rice est en danger.

---

## 3. Famille esthétique (choisie, pas collectionnée)

**Principale — Minimalisme suisse calme, humain, non ostentatoire.**
Refs : Dieter Rams, Helmut Schmid, Vignelli pour New York Subway, MUJI tardif, Lyst aux beaux jours, Linear. La grammaire est helvétique sans nostalgie : grille respirée, neutralité, retrait, dignité.

**Secondaire — Précision horlogère, à la demande seulement.**
La précision (chiffres, sources légales, formules) est disponible **au tap**, jamais imposée. C'est le "mécanisme visible quand on le demande" du watchmaker, pas le watchmaker en plein écran.

**Abandonnés du brief gouvernant** (gardés en R&D inspirationnel uniquement) : parfumerie, chorégraphie, gastronomie, art génératif, halo sacré, ambient computing, cinéma de plans dramatiques. Ils restent dans `/outputs/MINT_*_AUDIT.md` comme bibliothèque d'idées Layer 3, pas comme directives Layer 1.

---

## 4. Layer 1 — cinq chantiers, pas un de plus (4-8 semaines)

Tous validés par C1+C2+C3, tous au service des P1+P2+P3.

### L1.1 — Audit du retrait
Passer chaque écran existant au test "qu'est-ce qu'on enlève sans perdre de fonction ?". Cible -20% d'éléments visuels en moyenne. Toute suppression doit améliorer le contraste basse vision, pas le dégrader. Livrable : `docs/DESIGN_AUDIT_RETRAIT.md` + MR par écran.

### L1.2 — `MintTrameConfiance` v1
Objet visuel unique, omniprésent sur toute projection. Quatre exigences :
- **Lisible en une ligne** (version widget, version inline, version coach voice)
- **Tappable** pour ouvrir la version détaillée 4-axes
- **Accessibilité d'abord** : alt text structurée + version tabulée + version "1 ligne audio" spec'ées **avant** le code Flutter
- **Pas de gimmick** : c'est une trame typographique discrète, pas une animation hero

Le nom est figé : `MintTrameConfiance`. Pas "Halo".

### L1.3 — Microtypographie pass
Audit Montserrat/Inter sur tous les écrans. Largeur de paragraphe 45-75 caractères. Hiérarchie max 3 niveaux par écran. **Test obligatoire** : lecture sur Galaxy A14 + simulation DMLA + simulation dyslexie. Livrable : MR sur `lib/theme/text_styles.dart` + écrans hero.

### L1.4 — Voix régionale (3 cantons pilotes)
La seule innovation que les deux panels ont laissée intacte. VS, ZH, TI. Microcopy uniquement, jamais structure. Étendre `RegionalVoiceService.forCanton()`. Livrable : 30 chaînes microcopy par canton, validées par natifs locaux. Compliance ComplianceGuard sur tout.

### L1.5 — Mode "inconfort utile" (C4 implémenté)
Composant `MintAlertObject` réutilisable, déclenché uniquement par les 5 cas définis en C4. Couleur dédiée, ton direct, action immédiate. C'est l'opposé exact de `MintTrameConfiance` — quand la trame s'efface, l'alerte s'impose. Tests Patrol obligatoires.

**Tué de la v0.1** :
- ❌ MINT Signature v0 — rétrogradée en R&D Layer 3 sous forme de **texture quasi-typographique** (pas de feature, pas de génératif visible)
- ❌ Palate cleansers comme écrans dédiés — devient une **micro-pause** intégrée dans `MintTrameConfiance` (250ms entre l'apparition de la trame et celle du chiffre), pas un écran à part
- ❌ Lock Screen widget — reporté Layer 2 (parité Android exigée par C1, pas réaliste en Layer 1)

---

## 5. Layer 2 — prototypes internes seulement (~6 mois)

Documenter, prototyper, ne **rien** shipper. Cinq pistes :

- **L2.1** Lock Screen widget + Material You + Watch complications (parité Android impérative)
- **L2.2** `MintTrameConfiance` v2 — version 4-axes interactive, au tap depuis v1
- **L2.3** Voix régionale étendue — 6 cantons + microcopy enrichie
- **L2.4** Mint Cards — format de partage privé, jamais comparatif (P1)
- **L2.5** Cérémonie mensuelle — un check-in 3 écrans (pas 5) testé sur 50 users

---

## 6. Appendice R&D (Layer 3 — 2027-2028, document seulement)

Pour archive, **sans engagement** : Vision Pro / smart glasses, AirPods coach voice, CarPlay agent, biofeedback HRV opt-in, intégration cantonale API, Mint comme heirloom numérique transmissible, génératif comme texture, plans cinéma comme méthode formalisée. Tout ce qui était dans la v0.1 et que la red team a démoli : conservé ici comme bibliothèque, pas comme roadmap.

---

## 7. Conditions de survie business (à remplir par Julien avant GSD)

Le brief design ne survit pas seul. Cinq nombres + une décision :

| | Cible | Statut |
|---|---|---|
| CAC cible | ? | à définir |
| LTV cible | ? | à définir |
| Churn mensuel max | ? | à définir |
| CAC payback (mois) | ? | à définir |
| Conversion gratuit→payant | ? | à définir |
| Canal distribution principal | direct / B2B caisses / B2B advisors / partenariats RH | à choisir |

**Action urgente** (postmortem) : un email cette semaine à un·e conseiller·ère suisse certifié·e CFF, pitch "Mint comme infrastructure de pratique" — avant de relancer le milestone design.

---

## 8. La question politique (Stiegler)

> *"Quand Mint révèle à un·e utilisateur·rice qu'iel ne peut pas s'offrir la vie qu'iel envisage, qui supporte le coût de ce savoir ?"*

Trois réponses possibles :
- **(a) Outil d'adaptation** — l'utilisateur·rice s'ajuste seul·e (le brief actuel suppose ça par défaut)
- **(b) Outil de solidarité** — le savoir route vers un service tiers : conseil cantonal, caisse coopérative, syndicat, association de défense
- **(c) Outil d'anesthésie** — refuser de faire émerger la précarité

Cette décision conditionne le ton du coach, le contenu des "premier éclairage", et l'existence ou non de routages externes. **Pas d'ambiguïté possible.** Recommandation v0.2 : (b), avec (a) comme défaut tant que les partenaires de routage ne sont pas signés.

---

## 9. Les trois questions de Julien (à répondre avant GSD)

1. **Mint = clarté, protection, ou présence ?** Aujourd'hui les docs disent les trois. La v0.2 propose **présence**, parce que clarté et protection en découlent.
2. **La plus petite preuve visuelle d'incertitude ?** Le `MintTrameConfiance` v1 est conçu pour répondre à ça — une trame discrète, pas un nouveau langage opaque. Tu valides ?
3. **Layer 1 améliore l'expérience de quelqu'un qui a honte, peu de temps, peu d'énergie ?** Honnêtement : L1.1 (retrait), L1.3 (typographie), L1.4 (voix régionale), L1.5 (alerte utile) — oui. L1.2 (`MintTrameConfiance`) — seulement si la version "1 ligne" est priorisée sur la version "4-axes". Sinon non.

---

## 10. Métrique de succès Layer 1

Une seule métrique principale, qualitative :
> *"Quand un utilisateur teste Mint, il dit 'cette app me respecte' avant de dire 'cette app est belle'."*

Si la beauté arrive en premier dans les retours, on a échoué. Si le respect arrive en premier, on tient quelque chose.

Trois métriques secondaires quantitatives :
- NPS qualitatif "Mint m'apaise sans m'endormir" : baseline → +X
- Temps moyen par session : **diminue** (objectif : tu ouvres, tu reçois, tu fermes)
- Taux de complétion d'une action recommandée (= "premier éclairage suivi d'effet") : baseline → +Y

---

## 11. Ce que la v0.2 n'a pas tranché (et que GSD ne décidera pas non plus)

- Le nom "Mint" lui-même — le sémioticien a raison qu'il sous-vend le produit, mais la rebrand est un sujet Layer 3.
- Le routage tiers (question politique §8) — dépend de partenariats externes.
- Le pricing — dépend du §7.
- Le rapport au régulateur FINMA — chantier business indépendant.

---

## 12. Sources

- v0.1 : `MINT_DESIGN_MILESTONE_BRIEF.md` — brief panel créatif
- Red team : `MINT_DESIGN_BRIEF_RED_TEAM.md` — méta-synthèse adverse
- Audits intégraux : `outputs/MINT_*_AUDIT.md` (15 + 6 = 21 documents)
- Existant à respecter : `docs/DESIGN_SYSTEM.md`, `docs/VOICE_SYSTEM.md`, `CLAUDE.md`, `rules.md`

---

> *La v0.1 a donné à Mint 15 raisons d'être beau.
> La red team lui a donné 6 raisons de douter.
> La v0.2 lui donne 3 principes, 4 contraintes, 5 chantiers — et une chance d'être vrai.*

*Cette v0.2 est gouvernable. Elle peut alimenter `MILESTONE-CONTEXT-DESIGN.md` v2 dès que Julien aura tranché les trois questions du §9 et la question politique du §8.*
