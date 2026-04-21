# ADR-20260419 — Autonomous profile tiered (3 niveaux par phase)

**Status** : Accepted
**Date** : 2026-04-19
**Context** : v2.8 milestone "L'Oracle & La Boucle", request créateur 2026-04-19 pendant /gsd-discuss-phase 30.5

## Contexte

Julien demande que le pipeline GSD tourne en autonomous mais que **chaque phase soit profondément auditée et, quand pertinent, testée sur le simulateur iPhone (Mac Mini local)**. Préoccupation explicite : "les agents ont tendance à câbler en surface" — façade-sans-câblage est pitfall #1 documenté MINT (`feedback_facade_sans_cablage.md`, 5 exemples Wave 14).

L'infrastructure simulator existe (xcrun simctl, idb fallback, iPhone 17 Pro booted via Mac Mini terminal) mais est sous-utilisée hors GATE-01 manuels. La Phase 35 v2.8 (`mint-dogfood.sh`) est censée industrialiser ça — mais elle ship en sem 6-7 du milestone, donc 5 phases avant ne bénéficient pas du simulator gate.

Appliquer "deep research + 7-pass audit + simulator walkthrough" uniformément à 8 phases ajouterait +3-5j par phase = +24-40j sur un milestone budgétisé 8-10 sem. Doublerait le milestone. Activerait le pitfall G1 "déjà-vu pattern" (v2.4 → v2.6 → v2.7 → v2.8 stabilisation déguisée) que la kill-policy ADR du 2026-04-19 voulait empêcher.

Application uniforme rejetée. Application différentielle adoptée.

## Décision

**Profil autonomous tiered en 3 niveaux**, calibré par phase selon le domaine (meta/dev-tooling vs backend/integration vs frontend/UI-touching).

### Level 1 — meta / dev-tooling

**Phases v2.8** : 30.5 Context Sanity, 30.6 Tools Déterministes, 34 Guardrails, 35 Boucle Daily

**Pipeline** :
- `/gsd-execute-phase` standard (mode autonomous)
- Post-execute : `gsd-verifier` 7-pass audit (déjà existant, audit-as-second-agent obligatoire — pas le même agent qui execute et qui audit)
- Tests : unitaires + lints (pas simulator, rien à tester sur device)
- Pas de research re-do (milestone init `.planning/research/SUMMARY.md` suffit)
- Pas de creator-device gate

**Coût overhead** : baseline ROADMAP, audit second-agent ≈ +0.25-0.5j par phase

### Level 2 — backend / integration

**Phases v2.8** : 32 Cartographier (route registry backend + admin endpoint), 33 Kill-switches (Redis flag convergence, middleware GoRouter)

**Pipeline** :
- `/gsd-execute-phase` standard
- Post-execute : `gsd-verifier` 7-pass + `gsd-secure-phase` (security audit retrospectif déjà existant)
- Tests : unitaires + integration (curl smoke staging Railway, cross-project link Sentry validation)
- Inter-layer contracts check (mobile↔backend enum parity, schema drift, OpenAPI canonical respect)
- Research re-do ciblé seulement si question ouverte explicite (`/gsd-plan-phase` peut le déclencher)
- Pas de creator-device gate (sauf si Phase 33 UI parts touchent navigation visible — alors bascule Level 3 partiel)

**Coût overhead** : +0.5-1j par phase (audit + secure + inter-layer checks)

### Level 3 — frontend / UI-touching / user-visible

**Phases v2.8** : 31 Instrumenter (Sentry Replay UI + error boundary observable in app), 33 Kill-switches **UI parts** (redirect on flag-disabled visible navigation), 36 Finissage E2E

**Pipeline** :
- `/gsd-execute-phase` standard, AVEC `walker.sh` simctl gate par task UI-touching (cf. infrastructure section ci-dessous)
- Post-execute : `gsd-verifier` 7-pass + `gsd-ui-review` (déjà existant, panel audit visuel externe) + `gsd-secure-phase` si compliance touched
- Tests : unitaires + integration + **simctl walkthrough automated** (boot iPhone 17 Pro + flutter run staging + assert via accessibility tree `simctl io enumerate`)
- **Creator-device gate** Julien manuel non-skippable (preserves ship discipline doctrine `feedback_ship_discipline_one_person_team.md`, `feedback_tests_green_app_broken.md`)
- Research re-do : déclenchable par `/gsd-plan-phase` si UI pattern nouveau hors design system

**Coût overhead** : +1-2j par phase (walker + ui-review + creator-device gate). Phase 36 budget déjà 2-3 sem MIN, absorbe.

## Mapping v2.8 phases (à annoter ROADMAP.md)

| Phase | Profile | Justification | Δ budget |
|-------|---------|---------------|----------|
| 30.5 Context Sanity | **Level 1** | CLAUDE.md restructure + memory gc, 0 UI | +0.25j (verifier) |
| 30.6 Tools Déterministes | **Level 1** | MCP tools backend, 0 UI | +0.25j (verifier) |
| 31 Instrumenter | **Level 3** | Sentry Replay observable in app, error boundary triggers visible | +1.5j (walker + ui-review) |
| 32 Cartographier | **Level 2** | Route registry backend + admin endpoint readonly | +0.75j (secure + inter-layer) |
| 33 Kill-switches | **Level 2 + L3 partial** | Backend Redis convergence (L2) + UI redirect/admin flip (L3 sub-tasks) | +1j |
| 34 Guardrails | **Level 1** | lefthook + lints, 0 UI | +0.25j (verifier) |
| 35 Boucle Daily | **Level 1** | dogfood scripts dev-only, 0 UI | +0.25j (verifier) |
| 36 Finissage E2E | **Level 3 mandatory** | 4 P0 fixes UI-visible + creator-device 20 min déjà spec'd | irreduceable, déjà budgété |

**Total overhead estimé** : +5.25j sur 8 phases. Reste dans la fourchette ROADMAP 8-10 sem (high end).

## Audit-as-second-agent (obligatoire Level 2+)

**Doctrine** : `feedback_audit_methodology.md` + `feedback_audit_no_optimism.md` + `feedback_audit_multi_pass.md` — un agent qui s'auto-audit est juge et partie. Le confirmation bias rend l'audit bouchon.

**Implémentation GSD** :
- `/gsd-execute-phase` ne lance PAS son propre audit
- `/gsd-verifier` est spawn séparément après execute, sans contexte execute partagé (fresh session, comme Panel D demandé pour CTX-05 spike)
- Pour Level 2+ : `gsd-verifier` produit un AUDIT.md consommé par Julien (review humain final pas obligatoire mais disponible)

## Infrastructure simulator (J0 Phase 31 livrable)

**Pre-ship** `tools/simulator/walker.sh` (≤80 lignes bash) :
- `xcrun simctl boot iPhone\ 17\ Pro` (idempotent)
- `flutter run -d iPhone\ 17\ Pro --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1` (per `feedback_app_targets_staging_always.md`)
- `xcrun simctl io enumerate` → accessibility tree texte (per `feedback_screenshot_discipline.md`)
- Assert helpers : `assert_widget_present`, `assert_text_contains`, `assert_no_red_screen_of_death`
- Extract logs : `xcrun simctl spawn iPhone\ 17\ Pro log show --predicate 'subsystem contains "ch.mint"' --last 5m`

**Subset minimal de `mint-dogfood.sh` (Phase 35)** : pas le 8-step scenario, juste les primitives boot/install/launch/assert/log. Phase 35 hérite de cette base et ajoute le scenario 8-step + Sentry pull + auto-PR.

**Budget** : +0.5j Phase 31 (peut emprunter de Phase 34 per ROADMAP build order).

**Doctrine ship** : Phase 30.5 reste non-empruntable (kill-policy ADR), walker.sh n'y entre pas malgré l'utilité — préserve l'intégrité du gate. Kill-policy s'applique d'abord à elle-même.

## Extension `gsd-debug` skill (Phase 35 livrable, optionnel)

**Pattern Karpathy loop natif GSD** : étendre la skill `gsd-debug` (existing : "Systematic debugging with persistent state across context resets") pour wrapper `tools/simulator/walker.sh`. Permet aux agents Level 3 de tourner fix → simctl → assert → fix loop max 5 itérations sans intervention Julien. Si fail après 5 → escalate avec reproducer + Sentry trace_id + screenshot annotation.

**Pas un nouveau skill, pas un fork de `gsd-execute-phase`** — extension d'un skill existant, capitalisation infrastructure. 0 framework nouveau.

**Budget** : +0.5-1j Phase 35 (bonus, si budget tolère, sinon defer v2.9).

## Conséquences

### Positif

- **Le câblage surface est attaqué structurellement** : Level 3 phases passent obligatoirement par walker simctl + creator-device gate, impossible de ship UI cassée silencieusement
- **Audit-as-second-agent casse le confirmation bias** sur Level 2+ — un agent ne peut plus se valider lui-même
- **Calibration différentielle évite l'inflation** uniform deep audit (qui doublerait le milestone)
- **0 nouveau framework** — assemblage des skills GSD existantes (`gsd-execute-phase`, `gsd-verifier`, `gsd-secure-phase`, `gsd-ui-review`, `gsd-debug`) + 1 script bash + 1 extension skill
- **Compatible kill-policy ADR du 2026-04-19** : Level 3 simctl gate fail = trigger kill-switch flag (per kill-policy)
- **Compatible Phase 35 mint-dogfood.sh** : walker.sh est la base réutilisable, dogfood en hérite

### Négatif / Risques

- **+5.25j overhead total v2.8** sur ROADMAP — high end fourchette 8-10 sem, peut serrer
- **Walker.sh fragile sur macOS Tahoe** : simctl change parfois entre versions Xcode. Mitigation : version-pin Xcode dans `.tool-versions`, smoke walker.sh hebdo en post-Phase-31 pour détecter régression infra
- **Creator-device gate Julien Level 3** : non-scalable au-delà solo-dev, OK pour MINT 2026 mais lock-in si équipe grandit
- **`gsd-verifier` n'a peut-être pas tous les hooks pour 7-pass MINT-spécifique** — à valider Phase 30.5 J1 avant Level 1 phases launching
- **Pas testé en chaîne autonomous longue** : `/gsd-autonomous` + 8 phases consécutives avec audit second-agent à chaque = beaucoup de session resets, context cost potentiellement élevé. Mesurer sur Phase 30.5 + 30.6 (Level 1, faible coût) avant de signer pour Level 3 long-running

### Permanent kills (NOT deferred)

- **Application uniform deep audit** sur toutes les phases — rejeté (combinatorial explosion, risque G1)
- **Ship walker.sh dans Phase 30.5** — rejeté (scope creep auto-violation kill-policy)
- **Fork `gsd-execute-phase` en `gsd-execute-with-simctl`** — rejeté (duplication code, préfère extension `gsd-debug`)
- **Référence aux skills `/autoresearch-*` comme infrastructure** — rejeté (créateur préfère GSD natif, autoresearch reste dispo en standalone hors pipeline)

## Re-open conditions

- Si Phase 30.5 + 30.6 (Level 1, smoke test du profil) montrent que `gsd-verifier` 7-pass insuffisant en pratique → re-spec avec un panel audit plus profond
- Si walker.sh Phase 31 J0 fail le smoke staging → re-évaluer simctl primitive vs idb fallback en Phase 31 plan
- Si Level 3 creator-device gate Julien devient bottleneck (>30 min/semaine) → considérer simctl walkthrough auto pré-Julien (filtre les évidents)

## Références

- `decisions/ADR-20260419-v2.8-kill-policy.md` — kill-policy fallback pattern (modèle pour ce ADR)
- `.planning/research/SUMMARY.md` §7 (10 pitfalls) + §6 (build order)
- `.planning/research/PITFALLS.md` G1 (déjà-vu), G2 (budget tilt)
- `.planning/phases/30.5-context-sanity/30.5-CONTEXT.md` — phase 30.5 décisions panel-augmented (D-19 fresh-context spike précurseur audit-as-second-agent)
- `MEMORY.md` feedback files :
  - `feedback_facade_sans_cablage.md` — pitfall #1 doctrine MINT
  - `feedback_tests_green_app_broken.md` — gate creator-device irreduceable
  - `feedback_ship_discipline_one_person_team.md` — Level 3 manual gate calibration
  - `feedback_audit_methodology.md` + `feedback_audit_no_optimism.md` + `feedback_audit_multi_pass.md` — audit-as-second-agent obligatoire
  - `feedback_screenshot_discipline.md` — `simctl io enumerate` > pixels
  - `feedback_app_targets_staging_always.md` — staging API_BASE_URL non-négociable

---

*Décidé en panel-augmented mode pendant `/gsd-discuss-phase 30.5` session 2026-04-19. ADR séparé pour ne pas polluer Phase 30.5 CONTEXT.md (scope CTX strict).*
