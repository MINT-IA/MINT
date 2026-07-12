# MINT G1 Goal Handoff — 2026-07-12

## Purpose

This handoff is a launch package for a fresh Codex session. The next session
must stop planning drift and execute **G1 Ledger Reality Baseline** as the
mechanical foundation for making MINT usable.

The immediate target is not to build the six product loops yet. The target is
to make the data spine reliable enough that those loops can be built without
duplicated facts, local user-data sliders, stale values presented as facts, or
Swiss financial decisions computed from illustrative defaults.

## Current Product Doctrine

MINT is a Swiss financial lucidity product, not a retirement-only app and not a
generic calculator catalog.

Product spine:

`ledger variable -> DataQuest ask -> Case/scenario -> screen state -> dossier/PDF -> runtime proof`

The key doctrine to preserve:

- One source of truth for user facts.
- A screen must not ask again for a fresh known fact.
- A scenario lever is not a user fact unless explicitly confirmed and written
  through the canonical ledger path.
- High-stakes Swiss scenarios must show known, missing, stale, estimated,
  confidence, source, and open specialist questions.
- Claude/agent audits must block Swiss métier incoherence, not only code bugs.

Retirement Case doctrine:

- The 50-60 retirement-preparation surface is a first-class P0 life-event loop
  because it is a major Swiss user need and competitive wedge against VZ,
  Raiffeisen-style advisory, banks, pension funds, insurers, and fiduciaries.
- It is still one MINT Case among the life-event set, not a separate
  retirement product.
- It reuses the user's existing ledger history, asks only the missing or stale
  delta, compares rente/capital/mixed, decumulation, housing, tax, survivor,
  and succession implications without giving advice, and produces a dossier for
  consultation/export/print/specialist handoff.
- It is triggered by intent/lifecycle state, not by global branding. MINT must
  not become navigation-, hero-, Coach-, or dossier-branded as a retirement app.
- Its minimum/useful fact contract must cover Swiss archetype risk: archetype,
  nationality, residence country, residence permit, arrival age, US person/FATCA
  status, employment status, voluntary LPP status, last LPP buyback date,
  capital withdrawal deadline, spouse consent requirement, matrimonial regime,
  canton/commune, and source-sensitive LPP regulation facts.

## Active Repo State To Verify

The next session must verify these, not trust this handoff blindly:

- Active checkout: `/Users/julienbattaglia/Desktop/MINT.nosync`.
- Expected branch: `codex/mint-product-usability-plan-20260712`.
- Expected planning files:
  - `.planning/mint-product-usability-plan-2026-07-12.md`
  - `.planning/goals/G1-ledger-reality-baseline-2026-07-12.md`
  - `.planning/ACTIVE_CONTEXT.md`
  - this handoff file
- Expected prior commits on this branch:
  - `17a91c0f7 docs(planning): add audited mint usability plan`
  - `4c659e462 docs(planning): add retirement P0 loop`
- Before doing anything, run:
  - `git status --short --branch`
  - `git log --oneline --decorate -5`
  - `python3 tools/checks/mint_os_doctor.py --repo-only`

If the worktree is dirty, inspect every change. Never revert user work. If the
dirty files match the planning files above, continue carefully and commit
atomically after validation.

## Mint OS Rules For The Next Session

Start from the checked-in repo, not memory:

1. Read `CLAUDE.md`.
2. Read `AGENTS.md`.
3. Read `docs/MINT_AGENT_WORKFLOW.md`.
4. Read `.claude/skills/mint-operating-gates/SKILL.md`.
5. Read `.planning/ACTIVE_CONTEXT.md`.
6. Read `.planning/mint-product-usability-plan-2026-07-12.md`.
7. Read `.planning/goals/G1-ledger-reality-baseline-2026-07-12.md`.
8. Read the five executable `docs/codex/` specs before producing any matrix:
   - `docs/codex/DATA_LEDGER.md`
   - `docs/codex/DATA_QUEST.md`
   - `docs/codex/SCREEN_CONTRACTS.md`
   - `docs/codex/WIRING_GRAPH.mmd`
   - `docs/codex/MAESTRO_FLOWS.md`
9. Read the G1 role/source files:
   - `.claude/agents/mint-data-ledger-architect.md`
   - `.claude/agents/mint-data-quest-architect.md`
   - `.claude/agents/mint-quality-gate.md`
   - `.claude/agents/mint-swiss-brain.md`
   - `docs/data-flow.md`
   - `apps/mobile/lib/models/coach_profile.dart`
   - `apps/mobile/lib/providers/coach_profile_provider.dart`
   - `apps/mobile/lib/routes/route_metadata.dart`
   - `services/backend/app/api/v1/endpoints/coach_chat.py`
10. Run MINT Doctor before claiming any tool is missing.

Tool expectations:

- MINT Doctor: `python3 tools/checks/mint_os_doctor.py --repo-only`.
- Claude audits: always use `tools/checks/claude_external_audit.sh`, never raw
  `claude -p`.
- Opus audit: use `CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high`.
- Product-domain audit is mandatory for Swiss finance/product logic.
- Mermaid: `python3 tools/checks/mermaid_render_guard.py --root .`.
- Routes: `./tools/mint-routes reconcile`.
- Maestro: mandatory runtime proof when UI is touched.
- Patrol: use `$HOME/.pub-cache/bin/patrol` and
  `python3 tools/checks/patrol_tooling_guard.py`; do not declare Patrol absent
  from `command -v patrol` alone.
- Beads: CLI is `bd`; only initialize `.beads/` in a dedicated PR.
- Git hygiene: atomic commits, regular pushes, no destructive reset, no force
  push, verify diff before every commit.
- Diff size: 300 lines is a reviewability heuristic, not a hard gate.
- Memory/Engram is a recall index only. Checked-in repo docs, ADRs, tests, and
  git history are the source of truth.
- Privacy/nLPD: no real user financial data in prompts, Claude audits, logs,
  scorecards, fixtures, screenshots, or handoff artifacts. Use synthetic
  fixtures only; dossier/export work requires consent and minimization.

## G1 Objective

Implement G1 Ledger Reality Baseline:

Make the MINT data spine mechanically reliable so future P0 loops can ask only
for missing/stale facts, reuse existing history, distinguish user facts from
scenario assumptions, and prevent financial scenarios from reading local UI
data, duplicated data, stale data, or `GoRouter.extra` domain payloads as if
they were canonical.

G1 deliberately does **not** implement the six P0 loops.

## G1 Must Ship

1. `.planning/goals/G1-ledger-gap-matrix.md`
   - canonical key
   - wizard/storage key
   - `CoachProfile` field path
   - type/unit
   - allowed sources
   - freshness tier
   - confidence weight
   - write path
   - consumers
   - P0 loop consumers
   - current violation
   - `existing_gate | missing_gate | blocks_G2`
   - fix ticket/commit

2. `.planning/goals/G1-provider-boundary.md`
   - `CoachProfileProvider` = durable user facts and only profile write spine
   - `MintStateProvider` = derived read model only
   - legacy `ProfileProvider` = migrate consumers or ticket each remaining
     consumer before P0 work
   - provider islands = bridge into recompute or classify as non-financial
     cache/reference store

3. `.planning/goals/G1-scenario-lever-matrix.md`
   - every P0 local input classified as durable user fact, scenario lever, or
     derived output
   - no durable user fact remains a local slider/input outside DataQuest/ledger
   - Retirement Case scenario levers explicitly stay out of profile facts

4. `.planning/goals/G1-route-state-matrix.md`
   - empty, partial, stale, error, complete, return-to-origin behavior
   - CTA, i18n placeholder, route out, Maestro/Patrol proof target
   - exact route candidates reconciled against `route_metadata.dart`

5. Two executable hard-floor gates, green before G1 completion:
   - `no_domain_data_in_extra_test` for `/scan/review`, `/scan/impact`,
     `/rapport`, `/confidence`, plus any G1 route passing domain objects
     through `state.extra`
   - `ledger_dead_key_test` for P0-loop canonical keys
   - explicit commands:
     - `cd apps/mobile && flutter test test/routing/no_domain_data_in_extra_test.dart`
     - `python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q`
   - These tests are G1 deliverables. They may be absent at preflight, but G1 is
     incomplete until they exist and pass.
   - A passing stub is invalid. Each hard-floor gate must fail on a seeded
     violation before it is accepted, either through a committed negative fixture
     or red -> green evidence recorded in the scorecard.
   - `ledger_dead_key_test` must read P0 canonical keys from
     `.planning/goals/G1-ledger-gap-matrix.md` or another checked-in canonical
     registry produced by G1. It must not duplicate an incomplete key list inside
     the test.

6. Blocking tickets for remaining gates if not implemented:
   - `provenance_on_write_test`
   - `source_crosswalk_test`
   - `provider_bridge_recompute_test`

   Output file:
   - `.planning/goals/G1-blocking-gate-tickets.md`

   Each ticket must include:
   - id
   - owner agent
   - target files
   - exact failing predicate
   - fixture/input
   - command that must fail before fix
   - command that must pass after fix
   - blocks G2 yes/no
   - blocked P0 loops
   - planned implementation slice

   G2 default:
   - `G2 allowed?` is **no** by default if any of these remain ticket-only.
   - A yes requires explicit P1 triage in the scorecard and no P0/P1 unresolved
     Claude/agent finding.

7. `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/SCORECARD.md`
   - commands run
   - matrices created
   - hard-floor gates status
   - tickets created
   - Claude/agent verdicts
   - unresolved P1/P2
   - whether G2 is allowed to start

   Required evidence files:
   - `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/claude-architecture.md`
   - `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/claude-product-domain.md`
   - `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/agent-data-ledger.md`
   - `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/agent-quality-gate.md`
   - `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/agent-swiss-product.md`

## G1 Reality Scan Commands

Use `rg`, not assumptions. At minimum:

```bash
rg "class ProfileProvider|ProfileProvider" apps/mobile/lib apps/mobile/test
rg "state\\.extra|GoRouterState" apps/mobile/lib
rg "wizard_answers_v2|WizardAnswers|fromWizardAnswers|_mapFactKeyToAnswers" apps/mobile/lib apps/mobile/test
rg "/first-job|/simulator/job-comparison|/hypotheque|/mortgage/amortization|/mortgage/epl-combined|/epl|/rente-vs-capital|/decaissement|/3a-deep/staggered-withdrawal|/succession|/invalidite|/disability/insurance|/disability/self-employed|/independants/ijm|/life-event/donation|/segments/frontalier" apps/mobile/lib/routes apps/mobile/lib
```

## Mandatory Checks For G1

```bash
git fetch origin dev main
BASE_REF=$(git merge-base HEAD origin/dev)

git status --short --branch
git log --oneline --decorate -5
git diff --stat
git diff --check
python3 tools/checks/mint_os_doctor.py --repo-only
python3 -m pytest tools/checks/tests/test_codex_spec_reality_contract.py -q
python3 -m pytest tools/checks/tests/test_ledger_parity.py tools/checks/tests/test_no_bypass_persistence.py -q
python3 -m pytest tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py tools/checks/tests/test_screen_contracts_route_contract.py -q
python3 tools/checks/no_bypass_persistence.py apps/mobile/lib
python3 tools/checks/mermaid_render_guard.py --root .
./tools/mint-routes reconcile
lefthook run pre-commit
CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh architecture
CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh product-domain "$BASE_REF"
```

If code is touched, also run:

```bash
tools/checks/claude_external_audit.sh code "$BASE_REF"
```

Before marking G1 complete, the hard-floor gates must also run:

```bash
cd apps/mobile && flutter test test/routing/no_domain_data_in_extra_test.dart
python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q
```

These files are expected G1 deliverables and may not exist at preflight. Do not
treat absence as a broken tool. Do not create empty passing stubs. Prove each
gate with a seeded violation/negative fixture or red -> green evidence in the
scorecard, and make `ledger_dead_key_test` read keys from the G1 ledger gap
matrix or a checked-in canonical registry.

If `apps/mobile` is touched:

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/routing/scan_flow_repair_test.dart test/routes/ test/providers/
```

If UI/runtime is touched:

```bash
python3 tools/checks/mint_os_doctor.py
python3 tools/checks/patrol_tooling_guard.py
# Then run relevant Maestro/Patrol proof and store evidence under:
# .planning/runtime-evidence/g1-ledger-reality-baseline-20260712/
```

If ARB or user-facing copy is touched:

```bash
python3 tools/checks/arb_parity.py
python3 tools/checks/accent_lint_fr.py apps/mobile/lib/l10n/app_fr.arb
python3 tools/checks/banned_ui_terms.py apps/mobile/lib
python3 tools/checks/no_hardcoded_fr.py apps/mobile/lib
cd apps/mobile && flutter gen-l10n
```

## Permanent Agent Roster To Use

Use these as review roles, matching `AGENTS.md`:

- `mint-lead`: scope, sequencing, merge/no-merge.
- `mint-quality-gate`: tests, runtime evidence, scorecards.
- `mint-mobile`: Flutter route/provider/UI feasibility.
- `mint-backend`: backend/schema/API implications.
- `mint-swiss-brain`: Swiss finance/compliance/legal/product correctness.
- `mint-data-ledger-architect`: variables, provenance, freshness, no dead keys.
- `mint-data-quest-architect`: missing/stale/reconfirm asks and Case registry.
- `mint-lucidity-pdf`: dossier/PDF handoff requirements.
- `mint-external-auditor`: Claude wrapper evidence and unresolved findings.

The minimum expert panel before accepting G1:

- data-ledger architect + quality gate
- swiss-brain + product lead
- mobile/provider feasibility if any Flutter test/code is touched
- Opus architecture audit
- Opus product-domain audit

## Stop Conditions

Stop and fix or report if any of these happen:

- MINT Doctor says a required OS tool is missing.
- A route in the goal is not present in `route_metadata.dart`.
- The plan starts implementing G2 DataQuest Core or any G3 P0 loop before G1
  matrices and hard-floor gates are complete.
- A screen keeps a durable user fact as a local slider or local route payload.
- A Retirement Case calculation can run from illustrative defaults instead of
  minimum facts or partial-state asks.
- A Retirement Case projection ignores archetype, canton/commune, source date,
  or source-sensitive LPP regulation facts and still renders a confident result.
- Any privacy-sensitive user data appears in audit prompts, logs, scorecards,
  fixtures, screenshots, or handoff artifacts.
- Claude Opus returns P0/P1 NO-GO and the finding is not fixed or explicitly
  triaged in the scorecard.
- Tests fail for reasons plausibly related to the change.

## Audit Status For This Handoff

This handoff was audited on 2026-07-12 before being given to a future session:

- `mint-data-ledger-architect` + `mint-quality-gate`: **GO, 9.6/10**.
- `mint-swiss-brain` + product lead: **GO, 9.6/10**.
- Claude Opus architecture audit via `tools/checks/claude_external_audit.sh`:
  **PASS**, no P0/P1.
- Claude Opus product-domain audit via `tools/checks/claude_external_audit.sh`:
  **PASS**, no P0/P1.

P2 items integrated after Opus:

- route-state matrix must classify current wiring/provenance by route;
- parent plan restates the hard floor for `no_domain_data_in_extra_test` and
  `ledger_dead_key_test`;
- `BASE_REF` is derived with `git merge-base` instead of hardcoded blindly;
- housing/mortgage loop includes age/birth year for amortization-to-retirement
  and post-retirement affordability guardrails.

## Copy-Paste Prompt For New Codex Session

Use this exact prompt in a fresh session:

```text
Tu es Codex dans le repo MINT à `/Users/julienbattaglia/Desktop/MINT.nosync`.

Objectif: créer puis exécuter un goal actif nommé “G1 Ledger Reality Baseline”.
Tu ne t'arrêtes que lorsque G1 est réellement fini ou bloqué par un P0/P1
documenté. Le but n'est pas de coder les six parcours P0: le but est de rendre
la colonne vertébrale data de MINT mécaniquement fiable pour que les parcours
puissent ensuite être construits sans duplication, sans sliders de faits
utilisateur, sans `GoRouter.extra` porteur de données métier, et sans calculs
suisses à partir de valeurs illustratives.

Si l'outil Goal est disponible, appelle `create_goal` immédiatement avec:

objective = "G1 Ledger Reality Baseline — rendre le Data Ledger mécaniquement fiable avant G2/G3"

Ne marque le goal `complete` que si les hard-floor gates sont exécutables et
verts, le scorecard existe, et `G2 allowed?` est explicitement justifié.

Commence par vérifier le repo, pas la mémoire:

1. `git status --short --branch`
2. `git log --oneline --decorate -5`
3. `python3 tools/checks/mint_os_doctor.py --repo-only`
4. Lis `CLAUDE.md`, `AGENTS.md`, `docs/MINT_AGENT_WORKFLOW.md`,
   `.claude/skills/mint-operating-gates/SKILL.md`,
   `.planning/ACTIVE_CONTEXT.md`,
   `.planning/mint-product-usability-plan-2026-07-12.md`,
   `.planning/goals/G1-ledger-reality-baseline-2026-07-12.md`,
   `.planning/handoffs/mint-g1-goal-handoff-2026-07-12.md`.
5. Lis aussi avant le premier changement:
   `.claude/agents/mint-data-ledger-architect.md`,
   `.claude/agents/mint-data-quest-architect.md`,
   `.claude/agents/mint-quality-gate.md`,
   `.claude/agents/mint-swiss-brain.md`,
   `docs/data-flow.md`,
   `docs/codex/DATA_LEDGER.md`,
   `docs/codex/DATA_QUEST.md`,
   `docs/codex/SCREEN_CONTRACTS.md`,
   `docs/codex/WIRING_GRAPH.mmd`,
   `docs/codex/MAESTRO_FLOWS.md`,
   `apps/mobile/lib/models/coach_profile.dart`,
   `apps/mobile/lib/providers/coach_profile_provider.dart`,
   `apps/mobile/lib/routes/route_metadata.dart`,
   `services/backend/app/api/v1/endpoints/coach_chat.py`.

Règles absolues:

- Le repo git/ADR/docs est source de vérité; Engram est seulement un index de
  rappel.
- Utilise Mint OS: MINT Doctor, agents permanents MINT, Mermaid, Maestro,
  Patrol, Claude Opus via `tools/checks/claude_external_audit.sh`, et Beads
  seulement si déjà initialisé ou via PR dédiée.
- Claude doit auditer le code ET le produit/métier suisse. `product-domain` est
  obligatoire pour les scénarios financiers, Data Ledger/DataQuest, dossiers,
  fiscalité, LPP/AVS/3a, hypothèque, succession, assurance, frontalier.
- N'utilise jamais raw `claude -p`; utilise toujours le wrapper.
- Opus: `CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high`.
- Laisse Claude finir; les audits peuvent prendre plusieurs minutes.
- Patrol est `$HOME/.pub-cache/bin/patrol`; ne le déclare pas absent sur la base
  de `command -v patrol`.
- Mermaid est exécutable via `python3 tools/checks/mermaid_render_guard.py`.
- Beads est `bd`; n'initialise pas `.beads/` comme effet secondaire.
- La limite 300 lignes est une heuristique de review, pas un blocage.
- Commits atomiques, pushes réguliers, pas de reset destructif, pas de force push.
- Si UI touchée: runtime iPhone 14+ ou 15+, pas iPhone 13 mini; Maestro + Patrol
  quand le flux l'exige.
- Respecte le design MINT actuel; si UI touchée, relis les sources design du
  repo avant de modifier.
- Aucune donnée utilisateur réelle dans prompts Claude, audits, logs,
  scorecards, screenshots ou fixtures. Utilise uniquement des données
  synthétiques et respecte minimisation/consentement pour tout dossier/export.

Produit à préserver:

MINT est un système de lucidité financière suisse. Le spine est:
`ledger variable -> DataQuest ask -> Case/scenario -> screen state -> dossier/PDF -> runtime proof`.
Une donnée utilisateur durable vit dans la bibliothèque/ledger utilisateur.
Un écran ne redemande pas une donnée fraîche déjà connue. Un scénario peut avoir
des leviers locaux, mais ils ne deviennent pas des faits utilisateur sans
confirmation explicite et write path canonique.

Retirement Case:
Le cas 50-60 rente vs capital est un P0 majeur, mais pas une app retraite
séparée. Il doit réutiliser les données déjà connues, demander uniquement le
delta manquant/périmé, montrer les arbitrages AVS/LPP/3a/rente/capital/mixte/
décumulation/logement/fiscalité/survivant/succession sans conseil, et produire
un dossier utile pour spécialiste. Aucun résultat confiant ne doit sortir de
valeurs illustratives si les faits minimums sont absents ou stale.
Le contrat doit couvrir archetype, nationalité, pays de résidence, permis,
âge d'arrivée en Suisse, US person/FATCA, statut indépendant/salarié, LPP
volontaire, dernier rachat LPP, délai de retrait capital, consentement conjoint,
régime matrimonial, canton/commune et règlement LPP source-sensitive.

Scope G1 must ship:

1. `.planning/goals/G1-ledger-gap-matrix.md`
2. `.planning/goals/G1-provider-boundary.md`
3. `.planning/goals/G1-scenario-lever-matrix.md`
4. `.planning/goals/G1-route-state-matrix.md`
5. `no_domain_data_in_extra_test` exécutable et vert pour `/scan/review`,
   `/scan/impact`, `/rapport`, `/confidence`, plus toute route G1 qui passe des
   objets métier par `state.extra`.
6. `ledger_dead_key_test` exécutable et vert pour les clés canoniques des P0
   loops.
7. Ces deux hard-floor gates sont des livrables G1. Ils peuvent être absents au
   preflight, mais G1 est incomplet tant qu'ils n'existent pas et ne passent pas.
   Un stub vert est interdit: chaque gate doit échouer sur une violation seedée
   avant acceptation, via fixture négative commitée ou preuve red -> green dans
   le scorecard. `ledger_dead_key_test` doit lire ses clés depuis
   `.planning/goals/G1-ledger-gap-matrix.md` ou un registre canonique checked-in,
   pas depuis une liste dupliquée dans le test.
8. Tickets bloquants exacts pour `provenance_on_write_test`,
   `source_crosswalk_test`, `provider_bridge_recompute_test` si non implémentés.
9. `.planning/goals/G1-blocking-gate-tickets.md` si un gate reste ticket-only.
   `G2 allowed?` vaut NO par défaut tant que ces tickets bloquent G2.
10. `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/SCORECARD.md`
   avec commandes, matrices, gates, tickets, verdicts Claude/agents, P1/P2,
   et décision “G2 allowed?”.
11. Evidence files:
   `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/claude-architecture.md`,
   `claude-product-domain.md`, `agent-data-ledger.md`, `agent-quality-gate.md`,
   `agent-swiss-product.md`.

Réalise les scans avec `rg`, pas avec la mémoire:

```bash
rg "class ProfileProvider|ProfileProvider" apps/mobile/lib apps/mobile/test
rg "state\\.extra|GoRouterState" apps/mobile/lib
rg "wizard_answers_v2|WizardAnswers|fromWizardAnswers|_mapFactKeyToAnswers" apps/mobile/lib apps/mobile/test
rg "/first-job|/simulator/job-comparison|/hypotheque|/mortgage/amortization|/mortgage/epl-combined|/epl|/rente-vs-capital|/decaissement|/3a-deep/staggered-withdrawal|/succession|/invalidite|/disability/insurance|/disability/self-employed|/independants/ijm|/life-event/donation|/segments/frontalier" apps/mobile/lib/routes apps/mobile/lib
```

Commandes d'acceptance minimales:

```bash
git fetch origin dev main
BASE_REF=$(git merge-base HEAD origin/dev)

git status --short --branch
git log --oneline --decorate -5
git diff --stat
git diff --check
python3 tools/checks/mint_os_doctor.py --repo-only
python3 -m pytest tools/checks/tests/test_codex_spec_reality_contract.py -q
python3 -m pytest tools/checks/tests/test_ledger_parity.py tools/checks/tests/test_no_bypass_persistence.py -q
python3 -m pytest tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py tools/checks/tests/test_screen_contracts_route_contract.py -q
python3 tools/checks/no_bypass_persistence.py apps/mobile/lib
python3 tools/checks/mermaid_render_guard.py --root .
./tools/mint-routes reconcile
lefthook run pre-commit
```

Hard-floor G1 à créer/étendre puis exécuter avant `complete`:

```bash
cd apps/mobile && flutter test test/routing/no_domain_data_in_extra_test.dart
python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q
```

Ces fichiers peuvent être absents au preflight: c'est normal, ils sont à créer
pendant G1. N'accepte jamais un test vert par vacuité. Chaque hard-floor gate
doit avoir une fixture négative ou une preuve red -> green. `ledger_dead_key_test`
doit lire ses clés depuis `.planning/goals/G1-ledger-gap-matrix.md` ou un
registre canonique checked-in, pas depuis une liste locale incomplète.

Si `apps/mobile` est touché:

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/routing/scan_flow_repair_test.dart test/routes/ test/providers/
```

Si UI/runtime est touché:

```bash
python3 tools/checks/mint_os_doctor.py
python3 tools/checks/patrol_tooling_guard.py
# puis Maestro/Patrol avec evidence sous .planning/runtime-evidence/g1-ledger-reality-baseline-20260712/
```

Si ARB ou copy user-facing est touché:

```bash
python3 tools/checks/arb_parity.py
python3 tools/checks/accent_lint_fr.py apps/mobile/lib/l10n/app_fr.arb
python3 tools/checks/banned_ui_terms.py apps/mobile/lib
python3 tools/checks/no_hardcoded_fr.py apps/mobile/lib
cd apps/mobile && flutter gen-l10n
```

Audits Claude:

```bash
CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh architecture
CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh product-domain "$BASE_REF"
tools/checks/claude_external_audit.sh code "$BASE_REF"  # si code touché
```

Utilise les agents permanents comme panels d'audit:

- mint-data-ledger-architect + mint-quality-gate pour les matrices/gates.
- mint-data-quest-architect pour missing/stale/reconfirm, route-state matrix et
  prérequis Case/DataQuest.
- mint-swiss-brain + product lead pour le métier suisse, retraite, succession,
  hypothèque, assurance, frontalier, no-advice.
- mint-mobile si Flutter/routes/providers/tests mobile sont touchés.
- mint-external-auditor pour enregistrer les verdicts Claude.

Chaque audit doit donner verdict, score, P0/P1/P2, actions concrètes. Intègre
les P0/P1 avant de continuer. Pas de carousel d'audits: un premier pass, un
rerun ciblé si nécessaire, une confirmation finale.

Hygiène de livraison:

- Vérifie le diff avant chaque commit.
- Avant commit/push: `git diff --stat`, `git diff --check`,
  `git diff --shortstat origin/dev...HEAD`, puis relis le diff.
- Commits atomiques et pushes réguliers.
- Ne touche pas les fichiers hors G1 sauf nécessité justifiée dans le scorecard.
- À la fin, réponds en français avec fichiers changés, commandes exécutées,
  verdicts agents/Claude, risques non résolus, SHA/push, et si G2 peut démarrer.
```
