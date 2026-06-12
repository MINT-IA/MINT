---
phase: mint-grounded-coach-m1
plan: 08
subsystem: testing
tags: [device-gate, persona-walkthrough, idb, coach, grounding, rachat, save_fact, lsfin, 0-trust]

# Dependency graph
requires:
  - phase: mint-grounded-coach-m1-04-concept-registry-claim-checker
    provides: "registre concepts + claim-checker (inversion rachat bloquée) — la définition correcte device asserte ce chemin"
  - phase: mint-grounded-coach-m1-05-explain-concept-forced-tool
    provides: "explain_concept tool_choice forcé sur intent définition — la réponse versement authentifiée asserte ce forçage"
  - phase: mint-grounded-coach-m1-06-savefact-return-domain-fixes
    provides: "save_fact return-path (corroboration des 35 tests pour l'echo non-RUN device)"
  - phase: mint-grounded-coach-m1-07-activate-or-delete-facades-ci
    provides: "M1 backend HEAD (6a07753ee) = staging deploy ; CI eval gate ; façades résolues"
provides:
  - "Device-evidence walkthrough re-run (Marc cadre 50) prouvant rachat = versement sur surface authentifiée ET anonyme"
  - "Gate de sortie M1 passée sur le périmètre coach (zéro P1)"
  - "Cumulative VERIFICATION report HTML (lignée RED→GREEN, décisions façades, verdicts device)"
affects: [mint-grounded-coach-m1, M2-spine-cutover]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Persona-walkthrough gate par milestone : idb describe-all + simctl screenshot, free-drive quand les flows Maestro présupposent un seeding non câblé"
    - "Build non-seedé (sans MINT_E2E_ARCHETYPE) pour rendre l'echo save_fact falsifiable (leçon W1 caveat-0)"
    - "Assertion rachat SPLIT par surface (anonyme=pas d'inversion ; authentifié=versement forcé)"

key-files:
  created:
    - .planning/phases/mint-grounded-coach-m1/W1-cadre-50-rerun.md
    - .planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html
    - .planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-08-persona-walkthrough-closure-SUMMARY.md
  modified: []

key-decisions:
  - "Build staging non-seedé (sans MINT_E2E_ARCHETYPE) — profil onboarding âge 45 ≠ 50 → echo falsifiable"
  - "Assertion 3 (save_fact echo) honnêtement NOT-RUN device : limite 3-messages mode local + blocage outillage idb saisie '@' ; corroboré 35 tests verts (unit-green ≠ device-working, §9)"
  - "WTF-W1R-01/02/03 (chiffres/layout/accent) classés HORS périmètre coach et ≤ P2 → ne bloquent pas la gate coach"
  - "AUCUN changement de code produit — uniquement artefacts .planning/ (gate read-only)"

patterns-established:
  - "Pattern: gate de clôture milestone = walkthrough persona device avec citation idb/AX par assertion, PASS/NOT-RUN honnête"
  - "Pattern: corroboration unit-test pour une assertion device non re-testable, sans la substituer au device (0-TRUST)"

requirements-completed: [WS-A, WS-B, WS-C, WS-D, WS-E]

# Metrics
duration: ~50min
completed: 2026-06-12
---

# Phase mint-grounded-coach-m1 Plan 08: Persona Walkthrough Closure Summary

**Re-run device « Marc cadre 50 » sur sim contre staging M1 non-seedé : rachat défini comme un
VERSEMENT sur les surfaces anonyme ET authentifiée (WTF-W1-01 fermé), prescriptif éducatif sans
impératif, zéro P1 sur le périmètre coach — gate de sortie M1 passée. Echo save_fact honnêtement
NON-RUN device (limite 3-msg + outillage idb), corroboré 35 tests verts.**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-06-12T15:09Z (build) / 15:11Z (premier launch device)
- **Completed:** 2026-06-12T15:50Z (fin sweep) + artefacts
- **Tasks:** 3 (Task 1 pré-gate, Task 2 walkthrough, Task 3 report) + checkpoint
- **Files modified:** 0 code · 3 artefacts créés sous `.planning/`

## Accomplishments

- **Pré-gate déterministe vert** : backend 7792 passed / inversion+claim+registry 190 passed /
  flutter analyze clean / save_fact 35 passed — tous exit 0, AVANT le device.
- **Rachat = versement prouvé device sur les DEUX surfaces** : anonyme (« verser de l'argent dans
  ta caisse… LPP art. 79b ») ET authentifié (chemin explain_concept forcé) + paraphrase routée.
  L'inversion P1 de W1 (« rachat = retirer ton capital ») est éteinte.
- **Garde prescriptive calibrée device** : « qu'est-ce que je devrais faire » → réponse éducative,
  conditionnel « pourrait », contre-argument « angle mort », 0 fallback templaté, pas d'impératif.
- **Cohérence chiffres améliorée** : libre mensuel 7'745 identique sur 3 surfaces ; breakdown
  /retraite somme correctement ; provenance honnête (build non-seedé) AVS manquant/LPP estimé/3a manquant.
- **Artefacts** : walkthrough (≥40 lignes, préambule staging-SHA + health + build-invocation),
  VERIFICATION-REPORT.html (lignée RED→GREEN, décisions façades, 8 sections), 88 captures device.

## Task Commits

Plan 08 = gate read-only (aucun commit de code produit). Un seul commit de docs (artefacts) :

1. **Task 1: Pré-gate suites + fixtures** — pas de commit (vérification only, exit codes cités)
2. **Task 2: Walkthrough persona device** — artefact `W1-cadre-50-rerun.md` (commit docs)
3. **Task 3: VERIFICATION report** — `mint-grounded-coach-m1-VERIFICATION-REPORT.html` (commit docs)

**Commit docs unique:** `docs(grounded-coach-m1): closure walkthrough + verification report`

## Files Created/Modified

- `.planning/phases/mint-grounded-coach-m1/W1-cadre-50-rerun.md` — walkthrough device (préambule
  staging/build, timeline, 5 assertions PASS/NOT-RUN, WTF log, verdict Marc)
- `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html` —
  rapport cumulatif (suites, lignée RED→GREEN, livraison par plan 01-08, façades, verdicts device,
  findings, différés)
- `.planning/_walker/grounded-coach-m1/closure/*.png` — 88 captures device (evidence)

## Decisions Made

- **Build non-seedé** (sans `MINT_E2E_ARCHETYPE`) : le profil est construit par l'onboarding
  (DOB 15.07.1980 → âge 45), donc l'echo « j'ai 50 ans » est falsifiable (45 ≠ 50). C'est la
  leçon W1 caveat-0 appliquée.
- **Assertion rachat split par surface** (plan-checker) : anonyme = « pas d'inversion » (correct OU
  fallback acceptables, car `rachat` hors `_FINANCE_KW` anonyme) ; authentifié = « versement »
  (explain_concept forcé, Plan 05). Les deux ont donné l'issue forte (définition correcte).
- **Echo save_fact = NOT-RUN device honnête** : le tour « j'ai 50 ans » est pré-empté par la limite
  3-messages mode local ; la sortie de la limite (création de compte) est bloquée par une limitation
  d'outillage idb (saisie « @ » dans le TextFormField Material — pas un défaut produit). Corroboré
  par 35 tests save_fact verts, sans substituer le device (CLAUDE.md §9).

## Deviations from Plan

**None - plan executed as written.** Le plan prévoyait explicitement le split-par-surface et le
build non-seedé ; les deux ont été suivis. Aucune correction de code (gate read-only).

La seule divergence d'EXÉCUTION (pas de plan) : Assertion 3 device non complétée pour cause de
limitation d'outillage idb sur la création de compte — documentée comme NOT-RUN, pas masquée. Le
plan autorisait « create account / local mode » ; le local mode a buté sur la limite 3-msg, et la
création de compte sur l'outillage. Aucune tentative d'installation de package (exclusion Rule 3).

## Issues Encountered

- **idb `ui text` mangle « @ » et le 1er caractère** dans le `TextFormField` Material de création
  de compte : « @ » → « » et la 1re lettre est perdue ; le paste gère mal le curseur →
  concaténations résiduelles ; le validateur email (correct) rejette. Résolution : après ~3
  tentatives (fix-limit), arrêt — diagnostiqué comme limitation outillage, pas bug produit. Le
  validateur email de l'app fonctionne comme attendu.
- **Limite 3-messages mode local** pré-empte les tours coach multi-messages : contournée pour les
  assertions 1/2/4 (sessions fraîches via reinstall) ; non contournable pour l'echo save_fact
  (exige une session authentifiée).
- **Year-picker iOS scroll fiddly** via idb swipe : géré par swipes contrôlés successifs.

## Known Stubs

Aucun stub introduit (gate read-only, zéro code produit). Les findings résiduels sont des
comportements existants hors périmètre coach (voir Threat Flags / report) :
- WTF-W1R-01 : taux remplacement home 33% vs /retraite 44% (P2, hors coach) — deux moteurs.
- WTF-W1R-02 : RenderFlex overflow /retraite 192px (P2, hors coach).
- WTF-W1R-03 : accent-lint « Prevoyance »/« Cree »/« marie » (P3).

## Threat Flags

Aucune nouvelle surface de sécurité introduite (gate read-only, aucun endpoint/auth/schema modifié).
Threat register T-m1-08 du plan : T-08-01 (false-done) mitigé par walkthrough device cité ;
T-08-02 (stale target) mitigé par staging-SHA = M1 HEAD + health 200 cités ; T-08-03 (seed masking)
mitigé par build non-seedé cité.

## Next Phase Readiness

- **Gate de sortie M1 passée** sur son critère (rachat correct authentifié + pas d'inversion
  anonyme + zéro P1 coach). M1 prêt pour fermeture sous réserve checkpoint fondateur (optionnel,
  non-bloquant).
- **À porter en M2 (spine cutover)** : re-prouver l'echo save_fact device en session authentifiée
  (WTF-W1-04 désync profil non re-fermé device cette passe).
- **À traiter hors M1** : vague chiffres-cohérence (WTF-W1R-01 home/retraite replacement-rate ;
  WTF-W1R-02 overflow layout) ; passe accent-hygiène (WTF-W1R-03 + DEF-1/DEF-2).

## Self-Check: PASSED

- `W1-cadre-50-rerun.md` — FOUND (246 lignes ≥ 40 min plan)
- `mint-grounded-coach-m1-VERIFICATION-REPORT.html` — FOUND (215 lignes, 17 matches rachat|inversion|walkthrough)
- `mint-grounded-coach-m1-08-persona-walkthrough-closure-SUMMARY.md` — FOUND (nom exact requis)
- Evidence : 88 captures device sous `.planning/_walker/grounded-coach-m1/closure/` ; les 8 captures
  load-bearing par assertion présentes (05/29/30/31/39/70/80/87).
- Pré-gate exit codes cités : backend 7792 / fixtures 190 / analyze clean / save_fact 35 — tous 0.
- Aucun changement de code produit (gate read-only) ; STATE.md / ROADMAP.md NON modifiés (per objectif).

---
*Phase: mint-grounded-coach-m1*
*Completed: 2026-06-12*
