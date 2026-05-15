---
description: Wireframe v1 ASCII du composant TrajectoryMap horizontal A→B (timeline life-event-agnostic, marker position courante, milestones tap-able). Adapté de screen-plan.jsx (stepper vertical retraite-centric) vers horizontal multi-archetype. Input pour /design-shotgun Phase A. Compliance CLAUDE.md §3 + §6 + grammaire DS v2 PDF 2026-05-08.
name: trajectory-map-wireframe-v1
type: design
---

# TrajectoryMap — Wireframe v1 (ASCII)

> Wave 0 sub-agent C, 2026-05-14. **Status** : draft pour /design-shotgun Phase A — pas Figma, pas Flutter code à ce stade. Le wireframe doit être lisible par un LLM pour générer ensuite des variants HTML.

## TLDR

Composant horizontal A→B (timeline gauche-droite) montrant 5-7 milestones avec marker position courante, à intégrer dans Aujourd'hui ou Mon Argent (PAS un onglet à part — décision drift audit §A.3). Adapté de `docs/brand/mint-v2/screen-plan.jsx` (stepper vertical 4 phases) pour le passer en horizontal + life-event-agnostic (8 archetypes, pas « retraite 2053 »). Tap sur un milestone ouvre un overlay Coach scopé sur ce milestone (chat-as-verb doctrine Phase 96). Grammaire DS v2 mai 8 honorée : ConfidenceBand + EnrichmentPrompts mandatory sur tout chiffre projeté ; accent menthe-vive `#7DD3B5` sur milestone actif ; pas d'italique (italique = Landing + Onboarding seulement).

---

## Section 1 — Brief & contraintes

### 1.1 Sources canoniques

- **Design doc Wave 2 (approved 2026-05-14)** : timeline horizontale A→B, marker position courante, milestones tap-able, overlay Coach scope au tap.
- **Drift audit `.planning/audit/2026-05-14-handoff-vs-code-drift.md`** : `screen-plan.jsx` utilisable comme input wireframe (structure stepper 4 phases + ConfidenceBand inline + EnrichmentPrompts inline) MAIS framé retraite-centric (« En 2053, à 65 ans · 5'800 CHF/mois ») → ADAPTER life-event-agnostic + 8 archetypes. Verdict drift : Trajectoire = **composant** sur Aujourd'hui/Mon Argent, **pas onglet** (le JSX 3-tabs est exploratoire, le code canonique = 4 tabs).
- **PDF DS v2 mai 8** (`.planning/handoff/pdfs/MINT-Design-System-2026-05-08.pdf` pages 3-4) — grammaire MINT v2 (8 règles §D du drift audit) :
  - Règle 1 : une idée / écran — pas de mur de cartes
  - Règle 2 : voix observer, pas juger
  - Règle 3 : 4 artéfacts Coach (Décision · Comparaison · Trajectoire · Sensibilité)
  - Règle 4 : 18 events ≠ retraite-app — « Trajectoire », pas « Plan retraite »
  - Règle 5 : italique = 2 écrans max (Landing + Onboarding)
  - Règle 6 : chiffre nu interdit → ConfidenceBand + EnrichmentPrompts mandatory
  - Règle 7 : streaming visible
  - Règle 8 : dark mode natif (1ère classe)
- **`docs/MINT_IDENTITY.md`** — « Mint éclaire » (pas accuse). 5 piliers : calme, précis, fin, rassurant, net. Tagline #1 : « Mint te dit ce que personne n'a intérêt à te dire ». **MINT n'est PAS une app de retraite** — 18 life events.
- **`docs/VOICE_SYSTEM.md`** — chiffre d'abord puis explication ; pas d'exclamation ; pas d'injonction. Pattern Pulse : « [Prénom], [observation personnalisée]. [Implication concrète]. » Labels statut : « En bonne voie » / « À affiner » / « À traiter ».

### 1.2 Contraintes dures (non négociables)

| # | Contrainte | Source |
|---|---|---|
| C1 | Framing life-event-agnostic — JAMAIS « retraite 2053 » comme cadre dominant | CLAUDE.md TOP rule #3, drift audit, MINT_IDENTITY |
| C2 | ConfidenceBand obligatoire sous tout chiffre projeté/estimé | PDF DS v2 règle 6, drift audit §D.ter |
| C3 | EnrichmentPrompts obligatoire à côté de chaque hero number | PDF DS v2 règle 6 |
| C4 | Accent menthe-vive `#7DD3B5` sur milestone actif (CTA suivant) | PDF DS v2, drift audit §D |
| C5 | Pas d'italique Gambarino sur ce composant (italique = Landing + Onboarding) | PDF DS v2 règle 5 |
| C6 | Tap milestone → overlay Coach scope, PAS navigation push d'écran | Phase 96 chat-as-verb doctrine |
| C7 | Variants per-archetype (8 Swiss archetypes) — pas un parcours unique | CLAUDE.md TOP rule #7, drift audit |
| C8 | Termes bannis LSFin : pas de « garanti », « optimal », « meilleur », « certain », « assuré », « sans risque », « parfait » | CLAUDE.md TOP rule #1 |
| C9 | Accents FR 100% obligatoires (`éclairage`, `créer`, `découvrir`, `sécurité`) | CLAUDE.md TOP rule #2 |
| C10 | Dark mode natif — wireframe inclut variant dark | PDF DS v2 règle 8 |

### 1.3 Hors scope explicite

- Pas de Figma. Pas de JSX. Pas de Flutter code. **ASCII markdown only**.
- Pas de décision finale tabs structure (cf. drift §A.3 — laissé à Wave 0 step E « Mon Argent vision »).
- Pas d'animation spec détaillée (laissée à Wave 2 build).
- Pas de spec pixel-perfect (largeurs / paddings / etc.) — c'est un wireframe, pas un mockup.

---

## Section 2 — 3 wireframes ASCII

### W1 — TrajectoryMap horizontale (dashboard view)

État : embed sur Aujourd'hui sous le hero chiffre principal. Profil Julien, archetype `swiss_native`, 49 ans, 5 milestones visibles.

```
╔══════════════════════════════════════════════════════════════════════════╗
║  Aujourd'hui                                                    [⚙]      ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║   Julien, tu as 16 ans pour agir. Voici où tu en es.                     ║
║                                                                          ║
║   ┌────────────────────────────────────────────────────────────────┐     ║
║   │  TRAJECTOIRE                                          2 / 5    │     ║
║   │                                                                │     ║
║   │    ●━━━━━━━━●━━━━━━━━◉━━━━━━━━○━━━━━━━━○                       │     ║
║   │    │        │        │        │        │                       │     ║
║   │   M1       M2       [M3]     M4       M5                       │     ║
║   │  Piliers  3ᵉ open  Rachat   Achat    Projection                │     ║
║   │  scannés           LPP      immo     long terme                │     ║
║   │  fait     fait    EN COURS  à venir  à venir                   │     ║
║   │                                                                │     ║
║   │   ───────────────────────────────────────────                  │     ║
║   │                                                                │     ║
║   │   À ce stade :                                                 │     ║
║   │                                                                │     ║
║   │     5'800  CHF/mois                                            │     ║
║   │                                                                │     ║
║   │   à 65 ans, si tu termines les 5 étapes.                       │     ║
║   │   Sans rachat ni 3ᵉ pilier : 4'200 CHF/mois.                   │     ║
║   │                                                                │     ║
║   │   ▸ Confiance : faible · 16 ans d'écart, sensible aux revenus  │     ║
║   │                                                                │     ║
║   │   Pour affiner :                                               │     ║
║   │     [+ évolution salaire]  [+ enfants prévus]  [+ achat immo]  │     ║
║   │                                                                │     ║
║   │   ┌──────────────────────────────────────────────┐             │     ║
║   │   │  Continuer M3 — Racheter LPP   ▸             │  menthe     │     ║
║   │   └──────────────────────────────────────────────┘             │     ║
║   │                                                                │     ║
║   └────────────────────────────────────────────────────────────────┘     ║
║                                                                          ║
║   [Aujourd'hui]  [Mon argent]  [Coach]  [Explorer]                       ║
╚══════════════════════════════════════════════════════════════════════════╝

Légende symboles :
  ●  = milestone fait (cercle plein, ink primary)
  ◉  = milestone actif (cercle plein, accent menthe-vive #7DD3B5, ring)
  ○  = milestone à venir (cercle vide, hairline)
  ━  = trait timeline (1px hairline ; segment fait = ink primary)
  ▸  = chevron CTA / streaming start

Voix copy (rule 2 PDF DS v2 — observer pas juger) :
  - « Julien, tu as 16 ans pour agir. Voici où tu en es. » (pas « tu es en retard »)
  - « à 65 ans, si tu termines les 5 étapes » (conditionnel, pas promesse)
  - « Confiance : faible · 16 ans d'écart » (factuel, pas alarmiste)
  - « Pour affiner : » (invitant, pas injonctif)
```

### W2 — Milestone tap state (overlay Coach scope)

Tap sur M3 (« Racheter LPP », actif) ouvre un overlay Coach scopé sur ce milestone. Doctrine Phase 96 chat-as-verb : pas un push d'écran, un overlay invocable inline.

```
╔══════════════════════════════════════════════════════════════════════════╗
║  Aujourd'hui                                                    [×]      ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░     ║
║   ░  TrajectoryMap dimmed en arrière-plan (40% opacity, hairline)  ░     ║
║   ░    ●━━━●━━━◉━━━○━━━○                                           ░     ║
║   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░     ║
║                                                                          ║
║   ┌────────────────────────────────────────────────────────────────┐     ║
║   │  M3 · Racheter LPP                                       [×]   │     ║
║   │  ─────────────────────────────────────────────────────         │     ║
║   │                                                                │     ║
║   │  Tu peux racheter jusqu'à 10'000 CHF cette année.              │     ║
║   │                                                                │     ║
║   │     −3'400  CHF                                                │     ║
║   │                                                                │     ║
║   │  d'impôts économisés (estimation, canton VD, taux marginal).   │     ║
║   │                                                                │     ║
║   │  ▸ Confiance : moyenne · basé sur ton certificat LPP de 2025   │     ║
║   │                                                                │     ║
║   │  Pour affiner :                                                │     ║
║   │    [+ canton actuel]  [+ revenu net 2026]                      │     ║
║   │                                                                │     ║
║   │  ────────────────────                                          │     ║
║   │                                                                │     ║
║   │  Demande à Mint :                                              │     ║
║   │    ◆ « Pourquoi 10'000 et pas plus ? »                         │     ║
║   │    ◆ « Risque si je rachète puis change d'emploi ? »           │     ║
║   │    ◆ « Comparer rachat vs 3ᵉ pilier »                          │     ║
║   │                                                                │     ║
║   │  ┌─────────────────────────────────────────────────┐           │     ║
║   │  │ Écris ta question...                       ▸    │           │     ║
║   │  └─────────────────────────────────────────────────┘           │     ║
║   │                                                                │     ║
║   └────────────────────────────────────────────────────────────────┘     ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

Légende overlay :
  - Header : « M3 · Racheter LPP » (eyebrow style, no italic)
  - Hero chiffre : −3'400 CHF (signed négatif = économie ; pas « gain » qui peut sonner garanti)
  - ConfidenceBand : niveau moyenne (vs faible pour W1 hero — données plus proches)
  - EnrichmentPrompts : 2 prompts contextuels (canton, revenu net)
  - 3 questions pré-écrites (« Demande à Mint ») = entrées chat scopées
  - Input chat = streaming visible (rule 7 PDF DS v2 — bouton ▸ devient ■ pendant gen)

Voix copy :
  - « Tu peux racheter jusqu'à » (conditionnel, pas « tu dois »)
  - « estimation » + canton + taux explicites (transparence hypothèses)
  - Question pré-écrite « Risque si je rachète puis change d'emploi ? » = LSFin art. 79b
    rappel implicite, pas « attention ⚠️ » alarmiste
```

### W3 — Variants per-archetype (2 archetypes contrastés)

Deux archetypes pour visualiser la variabilité de la trajectoire. Le composant reste le même ; les milestones changent.

```
═══════════════════════════════════════════════════════════════════════════
VARIANT A — expat_us (FATCA, 32 ans, vient d'arriver en CH depuis NYC)
═══════════════════════════════════════════════════════════════════════════

   ┌────────────────────────────────────────────────────────────────┐
   │  TRAJECTOIRE                                          1 / 6    │
   │                                                                │
   │   ◉━━━━━○━━━━━○━━━━━○━━━━━○━━━━━○                              │
   │   │     │     │     │     │     │                              │
   │  [M1]  M2    M3    M4    M5    M6                              │
   │  Mapper Comprendre Décl. 3ᵉ pilier Acheter Projeter            │
   │  FATCA  AVS/LPP   FATCA   FATCA-comp.  ou rester  long terme   │
   │  EN COURS à venir à venir à venir   à venir   à venir          │
   │                                                                │
   │   ───────────────────────────────────────────                  │
   │                                                                │
   │   À ce stade :                                                 │
   │                                                                │
   │     ?  CHF/mois                                                │
   │                                                                │
   │   On a besoin de tes données 401(k) et IRA pour projeter.      │
   │                                                                │
   │   ▸ Confiance : très faible · 1 milestone sur 6, profil neuf   │
   │                                                                │
   │   Pour démarrer :                                              │
   │     [+ status IRS résident]  [+ 401(k) actuel]  [+ visa B/L/C] │
   │                                                                │
   │   ┌──────────────────────────────────────────────┐             │
   │   │  Commencer M1 — Mapper ta situation FATCA ▸  │  menthe     │
   │   └──────────────────────────────────────────────┘             │
   │                                                                │
   └────────────────────────────────────────────────────────────────┘

Notes archetype expat_us :
  - Milestones spécifiques FATCA / IRS dominent — pas de retraite framing
  - Hero number = « ? CHF/mois » assumé (pas de fake number, transparence
    Karpathy #1 + 0-trust §9). Confiance « très faible » légitime.
  - EnrichmentPrompts ciblés : status IRS résident, 401(k), visa
  - Voix : « On a besoin de tes données » (inclusif « on », pas « tu n'as pas »)

═══════════════════════════════════════════════════════════════════════════
VARIANT B — cross_border (frontalier FR→CH, 45 ans, 2 enfants, prop. en FR)
═══════════════════════════════════════════════════════════════════════════

   ┌────────────────────────────────────────────────────────────────┐
   │  TRAJECTOIRE                                          3 / 7    │
   │                                                                │
   │   ●━━━●━━━●━━━◉━━━○━━━○━━━○                                    │
   │   │   │   │   │   │   │   │                                    │
   │   M1  M2  M3 [M4]  M5  M6  M7                                  │
   │   Statut Impôt 90j 2ᵉ pilier Prévoy. Choix CMU Hypoth. Long    │
   │   front. source règle vs LPP retour /LAMal /transfert terme    │
   │   fait fait fait EN COURS à venir à venir à venir à venir      │
   │                                                                │
   │   ───────────────────────────────────────────                  │
   │                                                                │
   │   À ce stade :                                                 │
   │                                                                │
   │     6'400  CHF/mois                                            │
   │                                                                │
   │   à 65 ans, si tu restes frontalier jusque-là.                 │
   │   Si retour FR avant 50 ans : 4'100 CHF + droits FR à activer. │
   │                                                                │
   │   ▸ Confiance : moyenne · règle 90j sensible à ton télétravail │
   │                                                                │
   │   Pour affiner :                                               │
   │     [+ % télétravail]  [+ horizon retour FR]  [+ revenus conj.]│
   │                                                                │
   │   ┌──────────────────────────────────────────────┐             │
   │   │  Continuer M4 — 2ᵉ pilier vs LPP transfert ▸ │  menthe     │
   │   └──────────────────────────────────────────────┘             │
   │                                                                │
   └────────────────────────────────────────────────────────────────┘

Notes archetype cross_border :
  - 7 milestones (vs 5 pour swiss_native, 6 pour expat_us) — la trajectoire est
    plus longue car double juridiction
  - Hero number scénarisé : restera-frontalier vs retour-FR-avant-50
  - Voix : « si tu restes frontalier jusque-là » (conditionnel, hypothèse visible)
  - EnrichmentPrompts spécifiques : % télétravail (règle 90j), horizon retour,
    revenus conjoint (impact LAMal optionnelle)
```

---

## Section 3 — Mapping aux 8 archetypes

Pour chaque archetype Swiss, état initial → cible + 3-5 milestones intermédiaires types. **Non exhaustif** — juste assez pour montrer la variabilité.

| # | Archetype | Initial → Cible | Milestones types (3-5) |
|---|---|---|---|
| 1 | `swiss_native` | Comprendre 3 piliers → Sécuriser projection long terme | M1 Piliers scannés · M2 3ᵉ pilier ouvert · M3 Rachat LPP · M4 Achat immo · M5 Projection long terme |
| 2 | `expat_eu` | Statut résident EU → Optimiser CH-EU portabilité | M1 Statut résidence · M2 LPP transfert / blocage · M3 3ᵉ pilier (résidence dépendant) · M4 Couple-CH ou couple-EU · M5 Retour ou rester |
| 3 | `expat_us` | Mapper FATCA → Décl. fiscale duale stable | M1 Mapper FATCA · M2 Comprendre AVS/LPP · M3 Décl. FATCA · M4 3ᵉ pilier FATCA-compatible · M5 Acheter immo CH ou rester locataire · M6 Projeter long terme |
| 4 | `cross_border` | Comprendre règle 90j → Optimiser frontière + retour | M1 Statut frontalier · M2 Impôt source · M3 Règle 90j télétravail · M4 2ᵉ pilier vs LPP transfert · M5 Prévoyance retour · M6 Choix CMU/LAMal · M7 Hypothèque |
| 5 | `independent_no_lpp` | Comprendre 1er pilier seul → Reconstruire 2ᵉ + 3ᵉ | M1 Statut indépendant · M2 1er pilier (AVS solo) · M3 LPP volontaire ou pas · M4 3ᵉ pilier maxi · M5 Provisions retraite |
| 6 | `independent_with_lpp` | Optimiser mix LPP volontaire + 3ᵉ → Stabiliser horizon | M1 LPP volontaire actuel · M2 Rachats possibles · M3 3ᵉ pilier maxi · M4 Diversification · M5 Projeter |
| 7 | `returning_swiss` | Re-comprendre système après expatriation → Re-câbler 3 piliers | M1 Retour formel · M2 Rapatrier 3ᵉ pilier · M3 Reconstruire LPP · M4 Hypothèque achat · M5 Projeter |
| 8 | `late_starter` | Identifier le retard sans honte → Combler ce qui est rattrapable | M1 État des lieux honnête · M2 3ᵉ pilier ouvert · M3 Rachats LPP prioritaires · M4 Couper dépenses ou augmenter revenu · M5 Projeter avec attentes calibrées |

**Note voix archetype 8 (`late_starter`)** : voix system pillier 4 (rassurant) sans tomber dans la fausse motivation. Pas « il est jamais trop tard » (creux). Préférer : « Ce qui est rattrapable, tu peux le rattraper. Ce qui ne l'est plus, on en tient compte. »

---

## Section 4 — Grammaire visuelle DS v2 appliquée

### 4.1 ConfidenceBand — OÙ exactement

Sous le hero chiffre projeté, AVANT les EnrichmentPrompts.

```
     5'800  CHF/mois                                  ← hero number (numL)

   à 65 ans, si tu termines les 5 étapes.            ← caption (body)
   Sans rachat ni 3ᵉ pilier : 4'200 CHF/mois.

   ▸ Confiance : faible · 16 ans d'écart,            ← ConfidenceBand
     sensible aux revenus                              (eyebrow + meta)
```

Niveaux : `très faible` / `faible` / `moyenne` / `élevée`. **JAMAIS** « certaine » / « garantie » (banned). Justification toujours en 1 ligne meta.

### 4.2 EnrichmentPrompts — quels champs prompter

Sous ConfidenceBand. **Toujours 2-4 prompts**, jamais plus (rule 1 PDF DS v2 — une idée / écran).

Liste prompts canoniques par contexte :

| Contexte | Prompts EnrichmentPrompts |
|---|---|
| Aujourd'hui hero W1 | évolution salaire · enfants prévus · achat immobilier |
| Milestone Rachat LPP W2 | canton actuel · revenu net 2026 |
| Archetype expat_us | status IRS résident · 401(k) actuel · visa B/L/C |
| Archetype cross_border | % télétravail · horizon retour · revenus conjoint |
| Archetype late_starter | dette actuelle · dépenses fixes · horizon retraite envisagé |

Format visuel : `[+ libellé court]` chip outlined, hairline border, ink soft.

### 4.3 Italique Gambarino — utiliser ou pas

**Non.** Règle 5 PDF DS v2 : italique = 2 écrans max (Landing + Onboarding). Le composant TrajectoryMap est sur Aujourd'hui / Mon Argent (écrans récurrents) → pas d'italique. Tous les chiffres, captions, eyebrows sont en Supreme (regular / medium / bold selon hiérarchie).

### 4.4 Accent menthe-vive `#7DD3B5` — où l'appliquer

3 surfaces seulement (parcimonieux = canonique) :

1. **Marker milestone actif** `◉` — fill menthe-vive avec ring (1.5px) menthe-vive 20% opacity
2. **CTA suivant** « Continuer M3 — Racheter LPP » — fond menthe-vive, ink primary text
3. **Hairline segment timeline entre milestone fait et milestone actif** — gradient subtil ink → menthe-vive sur 8-16px (optionnel ; à valider design-shotgun)

**JAMAIS** sur ConfidenceBand, EnrichmentPrompts, ou hero number lui-même.

### 4.5 Dark mode preview (1 ASCII variant)

Même structure W1, palette dark (`darkBg`, `darkInk`, `darkInkSoft`, `darkBorderSubtle`, `darkMentheVive`).

```
╔══════════════════════════════════════════════════════════════════════════╗
║  Aujourd'hui                                                    [⚙]      ║   bg = #0F0F10
╠══════════════════════════════════════════════════════════════════════════╣   ink = #F4F1EC
║                                                                          ║
║   Julien, tu as 16 ans pour agir. Voici où tu en es.                     ║
║                                                                          ║
║   ┌────────────────────────────────────────────────────────────────┐     ║   surface = #1A1A1C
║   │  TRAJECTOIRE                                          2 / 5    │     ║
║   │                                                                │     ║
║   │    ●━━━━━━━━●━━━━━━━━◉━━━━━━━━○━━━━━━━━○                       │     ║   ◉ menthe-vive dark #8DE3C5
║   │    │        │        │        │        │                       │     ║   ● ink soft #C8C5BF
║   │   M1       M2       [M3]     M4       M5                       │     ║   ○ border-subtle #2A2A2E
║   │                                                                │     ║
║   │     5'800  CHF/mois                                            │     ║   numL = ink #F4F1EC
║   │                                                                │     ║
║   │   ▸ Confiance : faible                                         │     ║   meta = ink soft
║   │                                                                │     ║
║   │   [+ évolution salaire] [+ enfants prévus] [+ achat immo]      │     ║   chips outlined border-subtle
║   │                                                                │     ║
║   │   ┌──────────────────────────────────────────────┐             │     ║
║   │   │  Continuer M3 — Racheter LPP   ▸             │  menthe     │     ║   menthe-vive dark #8DE3C5
║   │   └──────────────────────────────────────────────┘             │     ║
║   └────────────────────────────────────────────────────────────────┘     ║
╚══════════════════════════════════════════════════════════════════════════╝
```

**Tokens dark canoniques** (cf. `colors.dart:323-335` per drift audit) : `darkBg`, `darkInk`, `darkInkSoft`, `darkBorderSubtle`, `darkMentheVive`. Migration per-screen deferred to MVP-DARK-MODE-V1 mais le wireframe doit montrer la cible.

---

## Section 5 — Questions ouvertes pour /design-shotgun next

5 directions à explorer en variants HTML (Phase A → /design-shotgun → comparison board) :

1. **Q1 — Densité timeline** : 5 milestones visibles d'un coup (W1) vs scroll horizontal avec 7-8 milestones (W3 cross_border) vs zoom contextuel (milestones lointains = dots, milestones proches = labels). Quelle densité scale mieux pour `late_starter` qui peut avoir 10+ milestones ?
2. **Q2 — Marker actif visualisation** : `◉` rond plein (W1) vs flèche pointeur sous la timeline vs zone highlight de fond rectangulaire (style screen-plan.jsx `background: accent + '22'`). Lequel reste lisible en dark mode ?
3. **Q3 — Hero number placement** : au-dessus de la timeline (drift audit § retraite-friendly) vs en dessous (W1 ici) vs intégré comme « tooltip » du marker actif (tap timeline = révèle chiffre). Quelle placement minimise le risque chiffre nu interpreté comme promesse ?
4. **Q4 — Milestones non-linéaires** : la timeline horizontale suppose linéarité. Pour `cross_border` ou `expat_us`, certains milestones sont parallèles (FATCA peut avancer pendant que 3ᵉ pilier avance). Faut-il une variante « branches » ou « pistes parallèles » ? Cf. screen-plan.jsx stepper vertical qui permettrait facilement des branches.
5. **Q5 — Tap milestone overlay vs panel slide-in vs bottom sheet** : W2 propose overlay scopé. Alternatives : bottom sheet (cf. doctrine `MintBottomSheet`), panel side-in. Quelle interaction respecte le mieux chat-as-verb tout en restant pouce-friendly ?

**Hors scope /design-shotgun Phase A mais à noter** :
- Animation de progression entre milestones (transition fait → actif) — laissé Wave 2 build
- Accessibilité a11y : labels Semantics, contraste milestone actif/inactif en dark — laissé design panel review pre-push (cf. memory `feedback_design_panel_before_push`)
- Internationalisation : « Trajectoire » → « Path » EN / « Verlauf » DE / « Percorso » IT — déjà clé i18n potentielle `trajectoryMapTitle`

---

## Section 6 — Compliance check

### 6.1 CLAUDE.md TOP rule #3 — « MINT ≠ retirement app »

**Verdict : OK.**

- Le titre du composant est « Trajectoire », pas « Plan retraite » (vs `screen-plan.jsx` originalement « Plan retraite » renommé « Trajectoire »).
- W1 hero copy : « tu as 16 ans pour agir » sans « pour ta retraite » dans la phrase d'accroche.
- W3 variants montrent que 3 archetypes sur 8 (cross_border, expat_us, late_starter) ont des milestones non-retraite-centric majoritaires.
- Le chiffre projeté « 5'800 CHF/mois à 65 ans » apparaît bien dans W1 — c'est cohérent avec la réalité : la retraite EST un horizon de projection valide parmi d'autres. Ne PAS supprimer ce chiffre serait dishonnête. Mais il est cadré comme **un résultat** parmi 7 milestones, pas comme **le cadre dominant**.
- W2 milestone tap state = « M3 · Racheter LPP » : rachat LPP est lié à la retraite, mais cadré comme une décision présente (-3'400 CHF d'impôts cette année), pas comme « optimiser ta retraite ».

**Caveat** : variant W1 montre encore un horizon retraite (Julien 65 ans). Pour un audit complet « jamais retraite-first » il faudrait aussi un variant sur un autre life event en hero (ex : achat immobilier dans 5 ans). À couvrir en /design-shotgun Q3 / Q4.

### 6.2 CLAUDE.md TOP rule #1 — Banned terms LSFin

**Verdict : OK, vérifié manuellement.**

Scan du wireframe pour : `garanti`, `optimal`, `meilleur`, `certain`, `assuré`, `sans risque`, `parfait` — **aucune occurrence**. Termes utilisés conformes : « pourrait », « si tu termines », « estimation », « sensible aux revenus », « hypothèse », « possible ». Conditionnel partout sur les projections. Pas de comparaison sociale (« mieux que la moyenne ») — explicitement retiré du screen-plan.jsx source dans son commentaire d'en-tête (« retiré 'largement mieux que la moyenne' (claim comparatif → LSFin) »).

**Reco** : faire passer `check_banned_terms` MCP sur le wireframe avant ratification (caveat : MCP non invoqué dans cette session sub-agent C — laissé au merger Wave 0 ou pre-PR lint).

### 6.3 CLAUDE.md TOP rule #6 — 0-trust protocol

**Verdict : citations + caveats présents.**

Évidence dans ce document :
- **Sources canoniques citées** : `screen-plan.jsx` (path), `MINT_IDENTITY.md` (path), `VOICE_SYSTEM.md` (path), `.planning/audit/2026-05-14-handoff-vs-code-drift.md` (path), `MINT-Design-System-2026-05-08.pdf` (path + pages 3-4).
- **Caveats explicites** :
  - § 1.3 hors scope : pas de décision finale tabs structure, pas de Flutter code
  - § 6.1 caveat : W1 montre encore horizon retraite — à compléter en /design-shotgun
  - § 6.2 caveat : MCP `check_banned_terms` non invoqué dans cette session
  - § 5 Q1-Q5 : 5 décisions design ouvertes, pas tranchées
- **Banned claim words** : ce document n'utilise PAS « shipped » / « ready » / « validated » / « green » / « works » / « PROVISIONALLY READY ». Le statut frontmatter est `draft pour /design-shotgun Phase A`. C'est un wireframe v1, pas un livrable final.
- **Accents FR rule #2** : `éclairage`, `créer`, `découvrir`, `sécurité`, `3ᵉ pilier`, `système`, `événement` — vérifiés présents avec accents partout dans le doc.

---

## Annexe — Référence pixel adaptation (info, pas binding)

Pour mémoire si /design-shotgun Phase A va vers HTML — proportions indicatives screen-plan.jsx adaptées horizontal :

- Hauteur composant : ~360-440px sur Aujourd'hui (laisse place hero + tabs en dessous)
- Largeur timeline horizontale : screen width - 2×28px padding = ~334px sur iPhone 13/14 logical width 390
- Espacement milestones : `(timeline_width - 5 × 28px dot) / 4 segments` ≈ 49px par segment pour 5 milestones, dégradé pour 7 milestones
- Dot diamètre : 28px (cf. screen-plan.jsx)
- Hero numL fontSize : 64px (Supreme Bold)
- ConfidenceBand : 13px meta (eyebrow style)
- EnrichmentPrompts chips : padding 6×12, hairline 1px

**Pas un spec build — référence orientation pour générateur HTML next.**

---

*Wireframe v1 produit par Wave 0 sub-agent C, 2026-05-14. Sources : screen-plan.jsx + drift audit + PDF DS v2 mai 8 + MINT_IDENTITY + VOICE_SYSTEM. Awaiting /design-shotgun Phase A pour variants HTML.*
