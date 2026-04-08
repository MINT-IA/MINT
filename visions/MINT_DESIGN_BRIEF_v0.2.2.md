# MINT — Design Brief v0.2.2
## "Calme dans la main, franc dans la voix"
*Avril 2026 · v0.2.1 + tension visuel/voix assumée*

---

## 0. Pourquoi v0.2.2

La v0.2.1 était gouvernable, mais elle penchait vers le monastique. Elle capturait calme, dignité, retenue, respect — et perdait énergie, audace, malice, le côté "grand frère qui te dit la vérité". Mint ne doit pas être seulement un instrument calme. **Mint est un instrument calme avec du nerf.**

La v0.2.2 ajoute une distinction structurante absente jusqu'ici : **deux couches séparées**, gouvernées par des règles différentes.

| Couche | Règle |
|---|---|
| **Grammaire visuelle** | Calme, respirée, non ostentatoire, sans surcharge |
| **Personnalité conversationnelle** | Directe, complice, parfois piquante, jamais humiliante, jamais "banque suisse en col roulé" |

Tout le reste de la v0.2.1 reste en vigueur. Cette v0.2.2 ne remplace pas — elle complète et rééquilibre.

---

## 1. Le cœur du brief (réécrit)

> **Mint protège sans juger.**
> **Mint prouve sans surjouer.**
> **Mint parle peu, mais au bon moment — et quand il parle, il a du nerf.**

- **Promesse** : protection
- **Preuve** : clarté
- **Mode visuel** : présence calme
- **Mode vocal** : franchise complice

Mantra produit : **Mint est un guide calme, vif et sincère.**
Phrase de poche : **Calme dans la main, franc dans la voix.**

---

## 2. L'archétype (le seul, à graver)

Mint n'est pas :
- ❌ un conseiller
- ❌ un coach wellness
- ❌ un banquier suisse en col roulé
- ❌ un assistant zen
- ❌ un comique financier (pas de Cleo cabotinage, pas de roast mode)

Mint est :
> **Un grand frère très intelligent, très fiable, qui parle humain, et qui sait quand il faut être doux ou cash.**

Cet archétype gouverne **toutes** les décisions de voix coach, microcopy, premier éclairage, alertes, et notifications. Si une phrase ne ressemble pas à ce qu'un grand frère intelligent dirait à table un dimanche, elle est cassée.

---

## 3. Trois principes fondateurs (v0.2.1, inchangés)

**P1 — Mint éclaire, ne juge pas.**
**P2 — Mint rend l'incertitude visible** (sur les sorties décisionnelles).
**P3 — Mint parle peu, mais juste.**

---

## 4. Le quatrième principe (nouveau, v0.2.2)

**P4 — Mint a une voix vivante.**
La sobriété visuelle n'est jamais une excuse pour une voix molle. La grammaire visuelle est calme ; la voix est vivante. Si on doit choisir entre une phrase polie et une phrase juste, on prend la phrase juste.

Corollaire : **interdiction du jargon poli défensif.** Pas de "il est important de noter que", pas de "nous vous recommandons d'envisager", pas de "veuillez prendre en compte". Le grand frère ne parle pas comme ça.

---

## 5. La voix Mint en 8 règles concrètes

Ces règles s'ajoutent à `docs/VOICE_SYSTEM.md`. Elles gouvernent la copy coach, microcopy, premier éclairage, alertes.

1. **Phrases courtes par défaut.** Si une phrase dépasse 18 mots, on cherche pourquoi.
2. **Verbes d'action, pas verbes d'évitement.** "Tu peux éviter" plutôt que "il serait possible d'envisager d'éviter".
3. **Tutoiement franc.** Pas de "vous" défensif. Pas de "nous" corporate. Mint parle au "je" quand il faut.
4. **Le rythme avant le poli.** Une phrase qui claque vaut mieux qu'une phrase ronde.
5. **Une phrase peut être piquante, jamais humiliante.** "Là, on va éviter une connerie" ✅. "Tu fais n'importe quoi" ❌.
6. **Une phrase peut être drôle, jamais cabotine.** Mint a de l'humour sec, pas de vannes.
7. **Quand c'est grave, on le dit cash.** En G3 (cf. C4), la voix devient directe et brève. Pas d'enrobage.
8. **Quand c'est calme, on respecte le silence.** Mint ne meuble jamais.

### Phrases-types (à utiliser comme tests)

✅ Mint dit ça :
- "Là, on va éviter une connerie."
- "Le piège n'est pas où tu crois."
- "On va faire simple, pas simpliste."
- "Respire. Le sujet, c'est ça."
- "T'as deux options. Aucune n'est mauvaise. L'une te coûte plus de liberté que l'autre."
- "Tu peux ne rien faire. Mais tu sauras."

❌ Mint ne dit pas ça :
- "Il est important de noter que votre situation présente certains risques."
- "Nous vous recommandons d'envisager une optimisation de votre allocation."
- "Cette décision pourrait avoir un impact significatif sur votre avenir financier."
- (style banque) "Cher client, dans le cadre de votre projet de retraite..."
- (style wellness) "Prends un moment pour respirer et te reconnecter à tes objectifs."
- (style Cleo) "Bestie, ton 3a est dans le rouge 💀"

---

## 6. Quatre contraintes dures (v0.2.1, inchangées)

- **C1 — Device & langue floor** : Galaxy A14, fr B1, de-CH, italien, anglais clair
- **C2 — Accessibilité** : AA bloquant, AAA ciblé, tests live cadence milestone
- **C3 — Behavioral Data Minimization**
- **C4 — Trois classes de gravité** : G1 information, G2 vigilance, G3 alerte

**Note v0.2.2 sur C4** : la grammaire vocale change avec la classe. G1 = grand frère pédagogue. G2 = grand frère qui souligne. G3 = grand frère qui te prend par l'épaule et te dit "stop".

---

## 7. Famille esthétique (v0.2.1, inchangée)

- **Principale** : minimalisme suisse calme, humain, non ostentatoire
- **Secondaire** : précision horlogère, à la demande
- **Abandonnés** : parfumerie, chorégraphie, gastronomie, génératif, halo sacré, ambient computing, cinéma dramatique

---

## 8. Surfaces prioritaires Layer 1 (v0.2.1, inchangées)

| # | Surface | Fichier / composant | AAA |
|---|---|---|---|
| S1 | Onboarding intent | `intent_screen.dart` | oui |
| S2 | Home | `mint_home_screen.dart` | oui |
| S3 | Bubble coach | composant à identifier | oui |
| S4 | Carte résultat calculateur | composant partagé | oui |
| S5 | `MintAlertObject` | nouveau composant | oui |

**S3 prend une importance nouvelle dans v0.2.2** : c'est la surface où la voix vivante doit le plus se sentir. Le bubble coach est le terrain de validation principal de l'archétype "grand frère". Si on n'arrive pas à faire sonner Mint juste dans le bubble coach, le reste est secondaire.

---

## 9. Layer 1 — cinq chantiers (v0.2.1, augmentés)

### L1.1 — Audit du retrait (sur S1-S5)
Inchangé.

### L1.2 — `MintTrameConfiance` v1
Inchangé. Concept figé, nom testable, sur sorties décisionnelles uniquement.

### L1.3 — Microtypographie pass
Inchangé.

### L1.4 — Voix régionale (3 cantons pilotes : VS, ZH, TI)
**Élargi v0.2.2** : la voix régionale n'est pas qu'une localisation. C'est l'occasion de **prouver l'archétype "grand frère"** dans trois dialectes culturels. Le grand frère valaisan ne parle pas comme le grand frère zurichois ni comme le grand frère tessinois. Microcopy uniquement, mais avec **personnalité explicite** par canton.

### L1.5 — `MintAlertObject` (G2/G3)
Inchangé sur la forme. **Nouveauté v0.2.2** : le composant doit aussi exposer une **API de ton vocal** (G1/G2/G3 → calme / direct / cash) pour que le bubble coach et l'alerte parlent du même registre.

### L1.6 — NOUVEAU : **Voice Pass**
Petit chantier transversal, indispensable :
- Auditer les **20 phrases coach les plus utilisées** dans l'app (extraction depuis `claude_coach_service.py` + ARB files).
- Les réécrire selon les 8 règles du §5.
- Tester chaque phrase sur le test "est-ce que mon grand frère intelligent dirait ça à table dimanche midi ?". Si non, on coupe.
- Livrable : `docs/VOICE_PASS_LAYER1.md` listant avant/après pour les 20 phrases + mise à jour ARB files (6 langues) + mise à jour `VOICE_SYSTEM.md` avec les 8 règles.
- **Ce chantier est aussi important que `MintTrameConfiance`.** Sans lui, la grammaire visuelle calme finit par étouffer la voix.

Layer 1 passe donc de 5 à **6 chantiers** — la seule augmentation autorisée par cette v0.2.2.

---

## 10. Métrique de succès Layer 1 (augmentée)

**Métrique principale qualitative** :
> *"Quand un utilisateur·rice teste Mint, iel dit deux choses spontanément : 'cette app me respecte' ET 'on dirait qu'il y a quelqu'un de vivant derrière'."*

Si seule la première remonte, on a fait un instrument poli. Si seule la seconde remonte, on a fait un chatbot familier. Il faut les deux.

**Métriques secondaires** :
- NPS qualitatif "Mint m'apaise sans m'endormir"
- Test "grand frère" : 5 phrases prises au hasard dans l'app, 10 testeurs, "est-ce que ça sonne grand frère intelligent ?" — cible 80% oui
- Temps moyen par session diminue
- Taux de complétion d'une action recommandée augmente

---

## 11. Décisions ouvertes avant `MILESTONE-CONTEXT-DESIGN.md` v2

1. **Bubble coach (S3)** — quel fichier exact dans `apps/mobile/lib/widgets/coach/` ?
2. **Carte résultat (S4)** — composant partagé existant ou à créer ?
3. **Question politique** — Mint = (a) adaptation, (b) solidarité, (c) anesthésie ?
4. **Routage G3** — info seule, ou action externe ?
5. **NOUVEAU v0.2.2 — Périmètre du Voice Pass L1.6** : 20 phrases coach, est-ce le bon nombre ? 30 ? 50 ?
6. **NOUVEAU v0.2.2 — Validation archétype** : qui valide en interne qu'une phrase est "grand frère" et pas "banquier" ou "wellness coach" ? (Recommandation : Julien tranche personnellement les 20 phrases du Voice Pass.)

---

## 12. Sources

- v0.2.1 : `MINT_DESIGN_BRIEF_v0.2.1.md` (base)
- v0.2 : `MINT_DESIGN_BRIEF_v0.2.md`
- v0.1 : `MINT_DESIGN_MILESTONE_BRIEF.md`
- Red team : `MINT_DESIGN_BRIEF_RED_TEAM.md`
- 21 audits : `outputs/MINT_*_AUDIT.md`
- Existant : `docs/DESIGN_SYSTEM.md`, `docs/VOICE_SYSTEM.md`, `CLAUDE.md`, `rules.md`

---

> *La v0.1 a donné à Mint 15 raisons d'être beau.*
> *La red team lui a donné 6 raisons de douter.*
> *La v0.2 lui a donné une colonne vertébrale.*
> *La v0.2.1 lui a donné un calendrier.*
> *La v0.2.2 lui a rendu sa voix.*

---

> **Calme dans la main, franc dans la voix.**
> **Grand frère, jamais banquier. Jamais clown.**
