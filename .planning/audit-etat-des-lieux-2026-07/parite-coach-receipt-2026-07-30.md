---
description: Boucle de preuve parité coach×MoneyTruthReceipt fermée sur staging live (runs 1→6, PRs #1114-#1120) — trois causes racines successives, décision Reading A (pas de résolution pending par hash), harnais devenu garde de non-régression.
---

# Parité coach×receipt — boucle de preuve fermée (2026-07-30)

## TLDR

Le harnais #1114 (8 couples profil×question contre staging réel) a pris la parité
coach×écran de **0/8** à **verte 8/8-cohérente** en 6 runs et 5 PRs. Trois causes
racines distinctes, chacune masquée par la précédente, toutes prouvées par citation
(logs Railway, tracebacks, artefacts JSON). Le harnais est désormais la garde de
non-régression (`MINT_STAGING_PARITY=1`, skippé en CI).

## Chronologie des runs

| Run | Image staging | Verdict | Enseignement |
|---|---|---|---|
| 1-2 | 2cfe58156→1da71b813 (bascule en cours) | 0/8, 1 faux « vert » | Bascule de deploy invérifiable sans marqueur → #1117 |
| 3 | 1da71b813 certifiée (CLI Railway) | 0/8 | Le grounding #1116 atteint le prompt mais le narrateur le noie |
| 4 | 3bdfab8c0 certifiée (/health commit, 100 s) | 3× HTTP 500 | IndexError parents[5] en layout conteneur (#1119) |
| 5 | 2b3b8208f certifiée (120 s) | R1-R3 verts, P-couples rouges | Cœur prouvé ; attentes pending à instruire |
| 6 | 2b3b8208f | **2 passed — tout vert** | Attentes spec-fidèles (#1120), verrou anti-forge |

## Causes racines (dans l'ordre de découverte)

1. **Façade sans câblage** — `money_truth_receipt` écrit dans `safe_profile`
   (coach_chat.py:5224) mais droppé par la whitelist de
   `_build_coach_context_from_profile` (:1175) : écrit une fois, lu zéro fois.
   Fix #1116 : bloc de grounding resolved+pending + exemption du gate citations
   dérivée du bloc rendu (4 rounds Codex BLOQUANT corrigés).
2. **Narrateur non déterministe** — même groundé, le prompt de 45k chars orienté
   onboarding noyait le bloc (lost-in-the-middle) ; les dérivés/arrondis du LLM
   étaient rejetés par le gate → FALLBACK « Je n'ai pas cette donnée ».
   Fix #1118 : raccourci déterministe sans LLM (patron
   `_rente_capital_deterministic_loop_result`) pour receipt résolu × question
   net, durci par Codex (frontières de mots, bornes, scan LSFin fail-safe).
3. **Layout conteneur** — le scan LSFin importait `banned_terms_runtime`
   dont l'init module fait `Path(__file__).resolve().parents[5]` : IndexError
   sous `/app` + ImportError latent (`tools/checks/` hors image Docker).
   Fix #1119 : résolution de racine défensive + vocab packagé côté app +
   fail-closed (repli LLM, jamais 500). Sentry avait relevé l'erreur ;
   le harnais l'avait attrapée dans le même intervalle.

## Décision : Reading A — pas de résolution pending par inputsHash (#1120)

`compute_inputs_hash` ne couvre que les inputs bruts, PAS
`engine/engineVersion/taxYear/rounding` : deux receipts partageant un hash
peuvent porter des valeurs différentes → résoudre par hash pourrait servir une
valeur jamais affichée à l'écran (substitution sémantique intra-compte).
Spec §4.3 : résolution par `receiptId` scopée propriétaire ; pending répond
depuis le payload, jamais de recalcul, jamais de forgeage. Codex a tué la
lecture inverse en revue pré-implémentation.

**Contre-arguments considérés** : le by-hash aurait fermé P1-P3 en vert et
simplifié le handoff offline ; rejeté car le hash n'authentifie pas la
définition du calcul (§4.4:253 « même chiffre = mêmes inputs + même définition
+ même moteur »). **Data gap** : la conformité §4.3:244 du rendu pending
(« répond depuis le payload, jamais d'erreur nue ») reste non satisfaite —
le pending renvoie un fallback quasi-nu ; unité séparée à ouvrir.

## Infra née de la boucle

- `/api/v1/health` expose `commit` (RAILWAY_GIT_COMMIT_SHA tronqué, #1117) :
  les promotions §4.1 se vérifient en 100-120 s au lieu d'un settle aveugle.
- Harnais durci : C5 jugé sur le texte rendu, net+bornes uniquement (l'écho du
  brut d'input 6'500 faux-positivait), verrou anti-forge dur sur les pending.

## Évidence

Artefacts : `parite_run4.json` / `parite_run5.json` / `parite_run6.json`
(scratchpad session d8bdc5c9), run 6 = `2 passed` en 152 s. PRs #1114, #1116,
#1117, #1118, #1119, #1120 toutes squash-mergées, CI dev verte entre chaque.
