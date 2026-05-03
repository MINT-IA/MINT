# Phase 55 — Surface-Debt Pareto Sprint

> Statut : **Ready to execute** (dépendance : Phase 54 TestFlight gate closure complète)
> Auteur : Claude (Product Leader)
> Date : 2026-05-03
> Durée estimée : 12 heures effectives, fenêtre 3 jours
> Goal : passer le score surface-debt de **41/100 → < 20/100** en réparant la maladie identifiée par Julien (« code en surface + app buggée ») de façon **structurelle**, pas cosmétique.

## Contexte

Audit du 2026-05-03 (`.planning/audits/2026-05-03-surface-debt-audit.md`) a révélé :
- 1 BLOCKER : i18n debt 4 994 hits + lint non-wiré → drift permanent
- 1 BLOCKER : 9/27 lints écrits mais jamais exécutés en CI/pre-commit → faux sentiment de sécurité
- 3 HIGH : duplications calculs (28 mobile + 33 backend), 13 tests non-tests, 1 banned term `revenus_garantis` qui leak dans l'OpenAPI
- Pattern PR #439 / Phase 52.x : feature-commit puis 2-3 fix-commits chasing missed callers — exactement ce que la pre-push checklist (memory) doit prévenir

Discipline appliquée : `docs/CLAUDE_CODE_DISCIPLINE.md` (publié 2026-05-03). Les 3 PRs ci-dessous **suivent le workflow canonique** (Plan → Research → RED → GREEN → Panel → Pre-push → Evidence).

## Architecture de la décision

3 PRs sériels (chaque PR débloque le suivant) :

```
PR-1 (Structural)            PR-2 (Pareto Hot Fixes)        PR-3 (i18n Ratchet Baseline)
   ↓                              ↓                              ↓
Wire les 5 lints critiques    Fix top-10 Pareto             Ratchet baseline + plan extraction
+ STATUS.md registry          (12h → 12h cumulés)           ARB par hot-spot
+ signature_change lint       
(4h)                          (5h)                          (3h)
```

**Pourquoi cet ordre :** PR-1 installe les gardes-fous AVANT que PR-2 fasse du nettoyage. Sinon PR-2 nettoie pendant que de nouveaux bugs entrent par la même porte. Symptôme actuel = pas de gate ; on commence par la gate.

## PR-1 — Structural Fixes (4h)

**Goal :** rendre structurellement impossible la régression sur les top catégories.

**Scope :**

### Task 1.1 — `tools/checks/STATUS.md` registry + CI gate (1h)
- Créer `tools/checks/STATUS.md` listant les 27 lints existants avec un état parmi {`enforced-ci`, `enforced-pre-commit`, `manual-only`}
- Créer `tools/checks/lint_status_audit.py` qui scanne `tools/checks/*.py` et fail si un fichier n'a pas d'entrée dans STATUS.md
- Ajouter ce script comme job `lints/status` dans `.github/workflows/ci.yml`

### Task 1.2 — Wire 5 lints critiques (2h)
| Lint | Cible | Mode |
|---|---|---|
| `accent_lint_fr.py` | lefthook pre-commit | autofix mode (non-blocking ergonomics) |
| `no_hardcoded_fr.py` | CI ratchet | snapshot baseline `tools/checks/no_hardcoded_fr.baseline`, fail si current > baseline |
| `no_legal_admission_in_public_docs.py` | CI paths-filter `**/*.md` | blocking |
| `s0_s5_aaa_only.py` | CI lints job | blocking (a11y promise publique) |
| `verify_sentry_init.py` | CI lints job | blocking |

### Task 1.3 — `tools/checks/no_calc_outside_core.py` (rule #4 enforcement) (1h)
- Détecter `_calculate*` / `_calc[A-Z]*` méthodes hors `apps/mobile/lib/services/financial_core/` (mobile) et hors `services/backend/app/services/financial_core/` ou `app.constants.social_insurance` (backend)
- Ship avec **baseline 28 mobile + 33 backend** comme exemptions (`STATUS.md`-tracked)
- Ratchet vers 0 (PR-2 + futures phases vont diminuer)
- Annotation autorisée `// calc-allowed: <reason>` pour exceptions documentées

**Verification :**
```bash
# Doit fail avec 0 nouveau, pass avec exactly baseline
python3 tools/checks/no_calc_outside_core.py
# Doit fail si quelqu'un ajoute une méthode hors core sans annotation
echo "  double _calculateNew() => 42;" >> apps/mobile/lib/services/test.dart
python3 tools/checks/no_calc_outside_core.py  # exit 1
git checkout apps/mobile/lib/services/test.dart
```

**RED tests à écrire d'abord :**
- `tools/checks/test_lint_status_audit.py` : test qu'un fichier nouveau dans `tools/checks/` sans STATUS.md entry → exit 1
- `tools/checks/test_no_calc_outside_core.py` : test exemption baseline + violation détection

**Pre-push checklist :**
- [ ] `python3 tools/checks/lint_status_audit.py` green
- [ ] `python3 tools/checks/no_calc_outside_core.py` green (baseline)
- [ ] `pytest tools/checks/` green
- [ ] `lefthook run pre-commit` green sur fichier exemple

**HTML evidence :** `.planning/phases/55-surface-debt-pareto/55-VERIFICATION-REPORT.html` initialisé après PR-1 merge.

## PR-2 — Pareto Hot Fixes (5h)

**Goal :** les 10 fixes haut-ROI identifiés par l'audit. ⚠️ Dépend de PR-1 mergé.

### Task 2.1 — Delete orphan screen (5 min)
- `git rm apps/mobile/lib/screens/document_scan/document_stream_result_screen.dart`
- Vérifier `screen_registry_parity` toujours green
- Commit : `chore(phase-55): remove orphan DocumentStreamResultScreen (Phase 28-04 leftover)`

### Task 2.2 — Convert auth_provider tests tautologie → real (1h)
- `apps/mobile/test/providers/auth_provider_test.dart:161-173` : 3 `expect(true, isTrue)` → assertions sur le mapping d'erreur (network / duplicate / wrong creds)
- **RED first** : écrire les 3 assertions, lancer test, voir RED, puis vérifier que le mapping function existe et passe GREEN

### Task 2.3 — Un-skip 5 coach_chat_test.dart (2h, **bug-discovery expected**)
- `apps/mobile/test/screens/coach/coach_chat_test.dart:226,251,290,313,404`
- Pour chaque test : retirer `skip: true`, lancer, observer fail/pass
- **Si fail = bug réel** : le fix devient sub-task. Si pass = test était over-cautious, garder.
- Coach chat = cœur du produit ; chaque bug trouvé ici a un impact device walkthrough disproportionné.
- **3-Fix Rule** : si un test échoue + 3 tentatives de fix échouent, STOP, reassess l'architecture du coach.

### Task 2.4 — Rename `revenus_garantis` (1h)
- `services/backend/app/schemas/retirement.py:250-257` : renommer en `revenus_recurrents` + update descriptions sans le mot « garanti »
- Regen OpenAPI canonical : `cd services/backend && python3 tools/openapi/generate_canonical.py`
- Update Dart consumer : `flutter pub run build_runner build --delete-conflicting-outputs` ou équivalent
- **Pre-push** : `grep -rn "revenus_garantis" services/backend apps/mobile` → 0 occurrences

### Task 2.5 — Consolidate `_calculate_breakeven` 3-way duplicate (2h, **subagent recommandé**)
- 3 fichiers : `services/backend/app/services/arbitrage/{rachat_vs_marche,rente_vs_capital,location_vs_propriete}.py`
- Extraire signature commune dans `services/backend/app/services/arbitrage/_common.py`
- Migrer les 3 callers
- Tests : ajouter test unitaire commun + retain 3 tests existants
- ⚠️ Subagent : `Agent` × 1 (complexité multi-fichier, < 10 fichiers donc 1 subagent suffit)
- Pre-push : `python3 tools/checks/no_calc_outside_core.py` doit montrer **−2 dans la baseline**

### Task 2.6 — Migrate `_calculate_federal_tax` (3h, sub-task DEFER si time-pressé)
- Honor warning à `services/backend/app/constants/social_insurance.py:368`
- Extraire de `services/backend/app/services/fiscal/cantonal_comparator.py:444` + `services/backend/app/services/expat/frontalier_service.py:271` vers `app.constants.social_insurance`
- ⚠️ Si le sprint dépasse 12h, defer à Phase 55.1. Documenter dans VERIFICATION-REPORT.html avec « DEFERRED to 55.1 — reason: scope ».

**Design panel obligatoire :** aucun nouveau écran touché → 4-person panel **skip OK** (mémoire `feedback_design_panel_before_push` s'applique aux écrans neufs/modifiés).

**Pre-push checklist (chaque commit PR-2) :**
- [ ] `grep -rn '<func>('` callers updated si signature changed
- [ ] OpenAPI regen si schema changed (Task 2.4)
- [ ] `flutter gen-l10n` si ARB changed (none in PR-2)
- [ ] `pytest -q` green
- [ ] `flutter test` green
- [ ] `flutter analyze` green
- [ ] `python3 tools/checks/no_calc_outside_core.py` green ou ratchet down

**HTML evidence :** update `55-VERIFICATION-REPORT.html` avec :
- 6 commits SHAs
- Tests pre/post coach un-skip (combien fail / combien révèlent un bug)
- baseline `no_calc_outside_core.py` avant/après (ex. 28→26 mobile, 33→32 backend)

## PR-3 — i18n Ratchet Baseline (3h)

**Goal :** snapshot la dette i18n, la geler, **commencer** l'extraction par hot-spot. Pas de cleanup massif (c'est 60h, hors-sprint).

### Task 3.1 — Snapshot baseline (30 min)
- `python3 tools/checks/no_hardcoded_fr.py --output tools/checks/no_hardcoded_fr.baseline`
- Commit le baseline
- Modifier `no_hardcoded_fr.py` pour comparer current vs baseline et fail si `current > baseline`
- CI gate déjà wired en PR-1 Task 1.2

### Task 3.2 — Identifier les 3 hot-spot files (30 min)
- `python3 tools/checks/no_hardcoded_fr.py --by-file --top 3`
- Probable hot-spots :
  - `apps/mobile/lib/widgets/precision/field_help_tooltip.dart` (audit cite l. 47)
  - autres TBD par scan

### Task 3.3 — Extract hot-spot #1 ARB (2h)
- Pour le top-1 hot-spot : extraire toutes les strings FR vers `app_fr.arb` + propager aux 5 autres ARB (en/de/es/it/pt) avec traduction LLM (`/autoresearch-i18n` skill)
- `flutter gen-l10n`
- Tests : screen golden si écran touché
- Baseline doit **diminuer** ; commit ratcheted baseline

### DEFER au sprint suivant
- Hot-spots #2, #3, …, #N → Phase 55.1 ou autoresearch-i18n autonome (skill existant `autoresearch-i18n` peut tourner en boucle 40 itérations)

**Pre-push :**
- [ ] Baseline `no_hardcoded_fr.baseline` commité
- [ ] Si extraction faite : baseline diminué, pas augmenté
- [ ] 6 ARB files all valid (`validate_arb_parity()` MCP)
- [ ] `flutter gen-l10n` re-run, generated files committed

## Definition of Done (sprint complet)

- [ ] PR-1 mergé : 5 lints wired + STATUS.md + no_calc_outside_core baseline
- [ ] PR-2 mergé : orphan screen deleted + 8 tautologie/skip tests réparées + revenus_garantis renamed + 1 calc duplicate consolidé
- [ ] PR-3 mergé : i18n baseline gelé + 1 hot-spot extracted
- [ ] Surface-debt score ré-calculé : cible **< 20/100**
- [ ] `55-VERIFICATION-REPORT.html` complet avec 3 PRs, panel verdicts (n/a panel design pour ce sprint), tests pre/post, screenshots si UX touché
- [ ] Session HTML `.planning/reports/SESSION-2026-05-XX.html` rolled up
- [ ] `MEMORY.md` updated si nouveau pattern appris (probable : « ratchet baseline pattern marche »)
- [ ] Phase 55.1 ouvert avec les fixes deferred + extraction i18n hot-spots #2-N

## Risques + mitigations

| Risque | Mitigation |
|---|---|
| Un test coach un-skipped révèle bug architecture profonde | Apply 3-Fix Rule : 3 tentatives max, sinon scope-out vers Phase 55.1 + ouvrir un investigate skill |
| Migration `_calculate_federal_tax` casse calculs existants | Tests parité backend pre/post : `pytest services/backend/tests/services/fiscal/ -q` doit rester green à 100%. Walker walkthrough sur scénario fiscal canton-comparison |
| OpenAPI regen casse Dart consumer | Tester localement AVANT push : `flutter analyze` + smoke test API call sur staging |
| i18n extraction modifie l'UX visuelle (longueur strings DE/IT) | Golden snapshots doivent passer ou être mis à jour intentionnellement avec screenshot review |
| Sprint déborde 12h | Task 2.6 (federal_tax migration) DEFER à 55.1 par défaut. Cap sur 12h. |

## Workflow d'exécution (suivant `docs/CLAUDE_CODE_DISCIPLINE.md`)

```
JOUR 1 (4h) — PR-1
  Plan (déjà fait, ce document)
  → Research : aucune (lints sont déjà spec'd)
  → RED : 2 tests pour lint_status_audit + no_calc_outside_core
  → GREEN : implémentation des 3 nouveaux lints + wire 5 existing
  → Pre-push : checklist
  → Push + PR-1
  → Evidence : init 55-VERIFICATION-REPORT.html

JOUR 2 (5h) — PR-2 (après PR-1 mergé)
  Plan : déjà fait, mais re-vérifier 30s qu'aucune décision n'a évolué post-PR-1
  → Research : lecture des 3 fichiers arbitrage/ pour Task 2.5
  → RED : tests pour auth_provider (3) + tests pour _calculate_breakeven extracté
  → GREEN : 6 commits indépendants (1 par task, atomic)
  → Pre-push après chaque commit
  → Push + PR-2 (squash)
  → Evidence : update HTML

JOUR 3 (3h) — PR-3 (après PR-2 mergé)
  → RED : pas applicable (refactor extraction)
  → GREEN : baseline + 1 hot-spot extraction via /autoresearch-i18n
  → Pre-push : ARB parity + gen-l10n
  → Push + PR-3
  → Evidence : finalize HTML, calculer nouveau score, ouvrir 55.1
```

## Liens

- Audit source : `.planning/audits/2026-05-03-surface-debt-audit.md`
- Discipline : `docs/CLAUDE_CODE_DISCIPLINE.md`
- ADR coach V3 (parallèle, hors-scope sprint) : `decisions/ADR-20260503-wiki-per-user-coach.md`
- Memory pre-push checklist : `feedback_pre_push_checklist.md`
- Memory façade-sans-câblage : (W14 doctrine, CLAUDE.md NEVER #6)
- Skill autoresearch-i18n : `.claude/skills/autoresearch-i18n/`
