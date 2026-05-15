---
date: 2026-05-14
status: Decided
authors: Julien (decided), Claude (drafted)
panel: single
supersedes: docs/DESIGN_SYSTEM.md §1 « MINT = l'anti-dashboard »
superseded_by: —
description: Aujourd'hui = director-dashboard one-number (PDF DS v2 mai 8 page 3) ; supersede DESIGN_SYSTEM:17 « anti-dashboard » qui devient « anti-cockpit-d-avion », pas anti-one-number.
related:
  - .planning/audit/2026-05-14-handoff-vs-code-drift.md
  - .planning/handoff/pdfs/MINT-Design-System-2026-05-08.pdf
  - docs/brand/mint-v2/screen-aujourdhui.jsx
  - docs/DESIGN_SYSTEM.md
  - .planning/decisions/2026-05-14-phase-7-ship-or-pause.md
---

# Aujourd'hui = director-dashboard one-number (DS v2 ratify)

## TLDR

Aujourd'hui adopte le pattern director-dashboard one-number du PDF MINT-Design-System-2026-05-08 page 3 (« Un chiffre à retenir » + hero `+340 CHF` + phrase observatrice + tendance + ConfidenceBand + EnrichmentPrompts) ; `docs/DESIGN_SYSTEM.md §1 « MINT = l'anti-dashboard »` est superseded — la doctrine reste anti-**cockpit-d-avion** (rejet du mur de 6 chiffres + 4 widgets + 3 graphes), pas anti-**one-number**.

## Context

Le design doc APPROVED 2026-05-14 (Wave 0 step F) signalait un conflit doctrine :
- `docs/DESIGN_SYSTEM.md:17` (« MINT = l'anti-dashboard ») dit chaque écran « doit ressembler à une page d'un beau livre, pas à un cockpit d'avion ».
- L'intuition Julien (session 2026-05-14) dit director-dashboard avec voyants pleins / chiffres lisibles à 3 secondes.

L'audit drift `2026-05-14-handoff-vs-code-drift.md` Section D.bis a tranché par lecture du **PDF MINT-Design-System-2026-05-08.pdf** (canonique, plus récent que DESIGN_SYSTEM.md daté 2026-04-05) :
- Page 3 « 02 · QUOTIDIEN — Un chiffre à retenir » montre un Aujourd'hui hero `+340 CHF / Tu gagnes plus que tu dépenses / 3ᵉ semaine. Tendance tenue.` Confidence band visible. EnrichmentPrompts (tes loyers récents · 14 transactions à classer) inline.
- Page 5 « 05 · GRAMMAIRE » règle #1 « Une idée / écran — Pas de mur de cartes. Le chiffre parle, pas l'UI. »

Le PDF DS v2 mai 8 réconcilie les deux positions : **one-number hero** est le **mode dominant** ; **mur de cartes** est l'**anti-pattern**. C'est cohérent avec ce que DESIGN_SYSTEM.md voulait dire en 2026-04-05, mais formulé de façon ambiguë (« anti-dashboard » lu comme « zéro chiffre dominant », alors que l'intention est « zéro cockpit »).

## Decision

**Aujourd'hui = director-dashboard one-number hero** :
- Un chiffre dominant unique par vue (`displayLarge` ou `displayHero`, ≥ 48pt)
- Phrase observatrice courte sous le chiffre (« Tu gagnes plus que tu dépenses. ») — `MintTextStyles.titleMedium` ou `bodySupreme15Regular`
- Métadonnée temporelle ou tendance (« 3ᵉ semaine. Tendance tenue. ») — `MintTextStyles.bodyMedium`
- **ConfidenceBand mandatory** (PDF DS v2 grammaire #6 « Chiffre nu = interdit »)
- **EnrichmentPrompts inline** (PDF DS v2 grammaire #6 — sous le ConfidenceBand)
- Mini chart / sparkline secondaire optionnel (max 1, sous le fold éventuellement)
- Carte Coach observation (« Ta LPP cache 3'400 CHF. Je te montre ? ») au-dessus du tab bar — `MintNarrativeCard`

**Mode dominant = chiffre + observation**, pas mur de KPIs. Si le sujet de la semaine n'est pas un chiffre (ex : life event annoncé, mission Cap), alors le « hero » devient une **mission** (mission Cap du jour) — mais une seule, dominante. Pas 3 missions empilées.

**Doctrine mise à jour de `docs/DESIGN_SYSTEM.md §1`** (à éditer en Wave 0 PR) :

> **MINT = l'anti-cockpit-d-avion.** Une expérience intime et premium qui donne confiance. Chaque écran porte UNE idée dominante (un chiffre, une mission, un choix), pas un cockpit. Les autres signaux reculent — secondaires visuellement, sous le fold si nécessaire. Le mur-de-cartes-coloré est l'anti-pattern.

**Reverdict DESIGN_SYSTEM §2 Hero Screens (catégorie A)** : déjà cohérent avec one-number hero. Pas de changement à cette section, c'était déjà la doctrine sous-jacente.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  Steel-man anti-dashboard pur : DESIGN_SYSTEM §1 cite Chloé/Aesop/Wise/Linear comme références — aucune de ces marques ne fait du one-number hero. Aesop n'affiche pas « +340 CHF cette semaine ». Le pivot Julien 2026-04-12 « lucidité, pas protection » + memory `feedback_mockup_examples` (mockup ≠ framing) + identité « ami cultivé qui travaille dans la finance suisse » suggèrent une voix éditoriale, pas dashboard. Risque : copier le pattern PDF mai 8 sans interroger pourrait nous ramener vers le cockpit qu'on voulait éviter. Test : un sim showing +340 CHF / mois — est-ce que cela survit le toilet test MINT_IDENTITY (utilisable en 20 secondes, jamais pompeux, jamais « finance pour gens déjà initiés ») ? Probablement oui — mais à valider sur les 5 utilisateurs (Wave 0 sub-agent G persona guide).

- **What does this source not address ?**
  Le PDF DS v2 mai 8 montre +340 CHF sur 1 écran. Il ne précise pas :
  - Quel est le chiffre dominant les semaines où il n'y a pas de delta positif évident (semaine de gros achats, life event triggered) ?
  - Que met-on si l'utilisateur n'a pas connecté de banque (pas de delta calculable) ?
  - Le « +340 CHF » dépend d'une catégorisation automatique de transactions — quelle confidence band attribuer si la catégorisation est incertaine ?
  - Comment l'one-number gère les couples / households ? Un chiffre individuel ou ménage ?
  
  Ces questions sont **à traiter en Wave 1/2** lors de l'implémentation. Wave 0 ratify la doctrine, pas l'implémentation détaillée.

- **What would change this conclusion ?**
  Si la Wave 0 test 5 utilisateurs (sub-agent G persona guide → test wireframe) révèle que ≥ 3/5 disent « je vois un chiffre mais je sais pas ce qu'il signifie » ou « j'attendais voir mes 3 piliers / mon score » — alors retour à la planche à dessin : peut-être que one-number n'est pas le bon mode dominant, ou peut-être qu'il faut **2 modes** (one-number sur Aujourd'hui pour le delta hebdo + ailleurs un screen patrimoine multi-chiffre — vraisemblablement Mon Argent, cf. décision Mon Argent en cours rédaction).

## Sources

- `.planning/handoff/pdfs/MINT-Design-System-2026-05-08.pdf` — pages 3 (Quotidien : Un chiffre à retenir) + 5 (Grammaire : « Une idée / écran »)
- `docs/brand/mint-v2/screen-aujourdhui.jsx` — proposition JSX cohérente avec doctrine ratifié
- `docs/DESIGN_SYSTEM.md:17` — la phrase « MINT = l'anti-dashboard » est superseded ici (à éditer en Wave 0 PR avec une note pointant ce ADR)
- `docs/MINT_IDENTITY.md` — toilet test cohérent avec one-number (« utilisable en 20 secondes »)
- `.planning/audit/2026-05-14-handoff-vs-code-drift.md` Section D.bis — l'analyse PDF qui a tranché
- `.planning/decisions/2026-05-14-phase-7-ship-or-pause.md` — PAUSED Phase 7 (statu quo `chatTabVisible=true`) cohérent avec ce ratify

## Status & follow-up

- **Implementation tracking** :
  - Wave 0 PR `feature/S99-wave-0-foundation` : édit `docs/DESIGN_SYSTEM.md §1` pour reformulation + commit ce ADR
  - Wave 2 PR : implémentation Aujourd'hui director-dashboard one-number (déjà partiellement câblé dans `pulse_screen.dart` / `aujourdhui_screen.dart` ; à vérifier)
  - Wave 2 acceptance : screenshots golden Aujourd'hui hero respect grammaire DS v2 (chiffre dominant + ConfidenceBand + EnrichmentPrompts mandatory)

- **Re-litigation triggers** :
  - Si test 5 utilisateurs Wave 0 (sub-agent G + test wireframe) révèle ≥ 3/5 confusion sur one-number → re-litigation
  - Si pivot doctrine ultérieur (Phase 99+) revient sur l'identité MINT (one-number n'est plus aligné avec une nouvelle vision) → re-litigation
  - Si la propagation DS v2 (sub-agent H output) montre que « one-number » force un coût UI démesuré sur les 80 écrans non-héros → reconsider granularité (one-number uniquement Tier 1 hero, pas tous écrans)

---
*Decided 2026-05-14 par Julien via /office-hours design doc APPROVED + drift audit Section D.bis + Wave 0 question explicite « Aujourd'hui doctrine ? » réponse « Confirmer + ADR ratify ».*
