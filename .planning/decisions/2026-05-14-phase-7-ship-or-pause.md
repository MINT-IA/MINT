---
date: 2026-05-14
status: Decided
authors: Julien Battaglia (decided), Claude (office-hours session 6 facilitator)
panel: single
supersedes: .planning/decisions/2026-05-10-phase-96-ux-panel.md
superseded_by: —
description: Phase 7 (kill chatTabVisible + intent bars sur cards) en PAUSE jusqu'à mesure post-Wave-1 — Option C Coach vivant rend le kill prématuré.
related:
  - .planning/decisions/2026-05-10-phase-96-ux-panel.md
  - .planning/decisions/2026-05-09-MILESTONE-CHAT-AS-VERB.md
  - /Users/julienbattaglia/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-S98-sentry-v0-design-20260514-110101.md
  - apps/mobile/lib/services/feature_flags.dart
---

# Phase 7 (chat-as-verb) — PAUSE jusqu'à mesure post-Wave-1

## TLDR

Phase 7 (kill du Coach tab + intent bars sur cards) est mise en PAUSE ; `chatTabVisible` reste à `true`. Le diagnostic Phase 96 (« chat-as-destination est mou ») reste valide, mais le remède (kill the tab) est rendu obsolète par la décision 2026-05-14 d'embarquer Option C (Coach vivant didactique avec tool-using backend + planner forced-invocation + render_widget inline). Re-litigation seulement après mesure d'engagement post-Wave-1.

## Context

Trois forces ont forcé cette décision :

1. **Doctrine/code drift actif.** Le panel UX 2026-05-10 (`.planning/decisions/2026-05-10-phase-96-ux-panel.md`) a verdict PASS sur « Kill the chat tab from bottom nav behind a feature flag », mais le code dit toujours `static bool chatTabVisible = true` à [apps/mobile/lib/services/feature_flags.dart:116](apps/mobile/lib/services/feature_flags.dart#L116). Phase 7 du milestone CHAT_AS_VERB est UNSHIPPED depuis 4 jours. Statu quo passif = waste.

2. **Le verdict de panel ≠ décision matérialisée.** Per memory `feedback_zero_trust_protocol` : *« A panel auditor's verdict (« PASS ») is a recommendation, not a gate. The gate is mechanical : sim output, CI exit code, lint exit code, Julien's eyes. »* G2 (founder confirmation) n'a jamais eu lieu pour Phase 96. La décision était formellement PROPOSED, jamais DECIDED.

3. **Option C surface dans /office-hours session 6.** Le 2026-05-14, /office-hours a surface un Coach didactique vivant (tool-using backend + planner + render_widget inline) qui rend le bottom-tab Coach justifié à condition que le grounding + citations + widgets soient câblés. Phase 7 remedy (kill the tab) attaque les bons symptômes (Coach mou) avec le mauvais remède (absence) puisqu'on prépare maintenant la qualité (présence améliorée). Réf : design doc APPROVED `julienbattaglia-feature-S98-sentry-v0-design-20260514-110101.md`.

## Decision

- `chatTabVisible` reste à `true`. Aucun PR ne flip le flag tant que cette décision n'est pas re-litigée.
- Phase 7 du milestone CHAT_AS_VERB est **PAUSED**. Pas SUPERSEDED — le diagnostic reste valide, seul le remède est différé.
- Le code-doctrine drift est résolu par cette décision elle-même : la doctrine canonical devient « Phase 7 paused pending Wave-1 outcome ». `.planning/decisions/2026-05-10-phase-96-ux-panel.md` est partiellement superseded par ce doc sur le point « kill the tab » spécifiquement ; le reste du verdict panel (intent bars sur cards, opening context injection, citation gate) reste valide et est intégré comme livrable Wave 1c du design doc 2026-05-14.

## Counter-arguments and data gaps

### What does the strongest opposing view say ?

Le steel-man « Ship Phase 7 maintenant » : *« Phase 96 panel a raison sur le mou. Une décision panel-validée ne peut pas être indéfiniment différée sans coût d'autorité interne. Le Coach n'aura jamais le niveau de qualité requis pour justifier un tab dédié — Cleo a $250M ARR sur un format conversationnel, mais la majorité des apps fintech 2026 ont abandonné le chat-tab parce que les users ne reviennent pas. Tu paries 8 semaines de Wave 1-4 sur l'hypothèse que le Coach va devenir une destination ; si ce n'est pas le cas, tu as gaspillé 8 semaines ET tu seras coincé avec un tab que tu sais déjà être mou. Ship Phase 7 d'abord, fais l'investissement Option C ensuite — l'investissement Option C n'a pas BESOIN d'un tab pour exister (les intent bars sur cards peuvent invoquer le même Coach vivant en overlay). Le tab est l'attachement nostalgique, pas la fonction. »*

Cette objection est sérieuse. Le contre-argument : les intent bars en overlay capent à 3 turns par card (Phase 96 design). Un Coach vivant didactique a besoin de plus de surface conversationnelle libre pour les jobs « explore + simule + raconte mon journey », et capper à 3 turns avant que le Coach ait grounded sa réponse + invoqué tools + rendu widgets = casse l'expérience. Le tab donne la surface libre. Mais l'objection vaut re-examen si Wave 1 ship sans gain d'engagement mesurable.

### What does this source not address ?

- **Aucune donnée d'engagement sur le Coach actuel.** Pas de mesure sessions/user, turns/session, retention sur le Coach tab. La décision est qualitative (vision + design doc) sans baseline quantitative. Si on découvre post-Wave-1 que le Coach tab a 5% DAU même avec grounding, l'objection ship-now est rétroactivement validée.
- **Aucun signal user externe.** Aucun utilisateur n'a été observé naviguant entre tabs MINT. La décision « le tab est utile » repose sur intuition founder + reasoning architectural, pas sur observation comportementale. Le user-research planifié Wave 0 (5 personas LLM + 3-5 humains sur wireframe) testera la trajectoire visuelle mais PAS le Coach tab spécifiquement.
- **Aucun benchmark concurrent post-2025.** Cleo a $250M ARR (référence design doc) mais on n'a pas chiffré le ratio chat-tab-DAU / total-DAU dans Cleo ou bunq Finn. Si Cleo a kill le tab depuis, on ne le sait pas.

### What would change this conclusion ?

- **Si post-Wave-1 (estimation : 4 semaines de mesure staging) le Coach tab a < 30% DAU malgré grounding + citations + widgets**, on re-ouvre Phase 7 et on ship le kill. Forcing function : créer le 2026-06-15-coach-tab-engagement-metrics report.
- **Si l'audit corpus visuel Wave 0 révèle < 5 widgets embed-able**, le Coach vivant didactique est plus difficile que prévu (Wave 4 retardée), et l'argument « le tab justifie sa présence par widgets inline » est affaibli. Re-évaluer.
- **Si user research Phase B (3-5 humains réels sur wireframe + app actuelle) dit « je ne comprends pas pourquoi il y a un onglet Coach séparé », et 3+ users le disent**, re-ouvrir Phase 7.
- **Si Anthropic ship un changement majeur côté API (e.g. nouveau model qui rend le current Coach UX obsolète), e.g. native multi-modal embed, voice-mode), réévaluer toute l'architecture, Phase 7 incluse.**

## Sources

- `.planning/decisions/2026-05-10-phase-96-ux-panel.md` (panel verdict PASS, partiellement superseded)
- `.planning/decisions/2026-05-09-MILESTONE-CHAT-AS-VERB.md` (Julien directive, force-vérifier)
- `apps/mobile/lib/services/feature_flags.dart:116` (code state actuel `chatTabVisible = true`)
- `/Users/julienbattaglia/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-S98-sentry-v0-design-20260514-110101.md` (design doc APPROVED 2026-05-14, source d'Option C)
- Memory `feedback_zero_trust_protocol` (panel verdict ≠ gate G2)
- Memory `project_coach_forced_tool_invocation` (créée 2026-05-14, fondement Wave 1b planner)

## Status & follow-up

- **Implementation tracking** : aucun PR à ship pour matérialiser cette décision — elle EST sa propre matérialisation (le code reste tel quel, la doctrine s'aligne sur le code).
- **Re-litigation triggers** :
  - Date : 2026-06-15 (revue planifiée après ship Wave 1)
  - Métrique : Coach tab DAU/sessions/turns post-Wave-1 (à créer baseline + 2-sem mesure)
  - Signal : audit corpus widget Wave 0 outcome
  - Signal : user research Phase B (3-5 humains réels) feedback sur Coach tab visibilité
- **Owner re-litigation** : Julien (founder gate), avec Claude facilitation /office-hours si pivot envisagé.
