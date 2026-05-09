---
name: MVP-P1-CRON-ARCHETYPE-AWARE — perimeter STUB
description: Audit findings 2026-05-08 (PR #533 P1 sweep) — (a) annual_refresh_service.py:145 yearly cron asks « Ton salaire annuel brut a-t-il change ? » to retirees who have no salary ; (b) precision_service.py:99,109 hardcodes « Fiche de salaire mensuelle » as the canonical source for both salaire_brut and salaire_net, ignoring independents / retirees / cross-border. Both reframed to be archetype-aware. Effort ~0.3 j.
type: decision
date: 2026-05-09
status: STUB → IN_FLIGHT (this PR opens with the fix)
related:
  - .planning/decisions/2026-05-09-perimeter-archetype-input-normalization/STUB.md
  - .planning/decisions/2026-05-09-perimeter-fatca-calculator-gate/STUB.md
sources:
  - PR #533 audit synthesis P1 sweep B-EXP-F-1 + B-EXP-F-2 line items
  - Code trace `services/backend/app/services/scenario/annual_refresh_service.py:145` (salary-only label)
  - Code trace `services/backend/app/services/precision/precision_service.py:99,109` (Fiche de salaire prescriptive)
---

# MVP-P1-CRON-ARCHETYPE-AWARE — STUB

## Goal

**Reframe two backend services so they don't assume a salaried-active archetype** :

1. `annual_refresh_service` — accepts `employment_status` and reframes the salary / job-change questions when the user is `'retraite'`. Same pattern as the B2 fix on `suggest_actions` chips (« source de revenus » instead of « salaire »).
2. `precision_service` — `salaire_brut` / `salaire_net` field-help entries reframed to cover the 8 archetypes (salaried, independent, retiree, FATCA in transition, cross-border, etc.) instead of prescribing « Fiche de salaire mensuelle » as the only source.

## Background (CLAUDE.md NEVER #4 + #7)

MINT positioned itself as 18-99 multi-archetype after the 2026-04-12 pivot. But two backend services kept the salaried-active framing :
- A retiree opening the app in Jan would get a yearly cron prompt « Ton salaire annuel brut a-t-il change ? » → frustrating, condescending, signals MINT « doesn't know me ».
- An independent uploading their tax declaration would see « Cherche ta fiche de salaire mensuelle » in field help → wrong document type.

Both cases are silent fail modes (the user-facing copy is misleading but doesn't break the flow). They erode trust over months.

## Fix

### `annual_refresh_service.py`

- New optional `employment_status` parameter on `generate_refresh_questions()`, propagated to `_build_questions()`.
- When `employment_status == 'retraite'`, the salary question becomes :
  - `« Tes sources de revenus (rentes, retraits, autres) ont-elles change ? »`
- And the job-change question becomes :
  - `« Y a-t-il eu un changement dans ta situation (rente, activite reduite, deces conjoint) ? »`
- All other archetypes (None, 'salarie', 'independant', etc.) keep the current salary-framed labels (since most data flows still assume them).
- `risk_profile`, `current_lpp`, `current_3a` questions unchanged — these are universal.

### `precision_service.py`

- `salaire_brut.where_to_find` reframed to enumerate three sources : salaried (fiche de salaire), independent (declaration fiscale), retiree (rentes + autres revenus).
- `salaire_net.where_to_find` same pattern.
- `document_name` now lists multiple acceptable documents.
- `fallback_estimation` made archetype-agnostic.

## 5 gates mécaniques

| Gate | Description | Évidence |
|---|---|---|
| G1 | sim walker — set seed.employment_status='retraite' on a stale profile, trigger annual refresh, assert salary question label contains « rentes » or « retraits » | walker logs |
| G2 | device by Julien — flip his profile to 'retraite' temporarily on TestFlight v2.12.2+5, hit the 12-month cron, confirm reframed questions | TestFlight |
| G3 | dev CI green — backend pytest (incl. new annual_refresh employment_status branches) | run green |
| G4 | regression tests — `test_annual_refresh_archetype_aware.py` covers 'salarie' (legacy phrasing) + 'retraite' (new phrasing) + None (legacy phrasing) | new test exit 0 |
| G5 | LSFin/accent/ARB lint — backend Python only ; no ARB changes ; lint clean | banned_terms exit 0 |

## Tâches breakdown

| # | Action | Effort | Dépendance |
|---|---|---|---|
| 1 | annual_refresh_service: add `employment_status` param to `generate_refresh_questions` + `_build_questions` | 0.05 j | None |
| 2 | annual_refresh_service: branch salary + job labels on `is_retired` | 0.05 j | 1 |
| 3 | precision_service: reframe `salaire_brut.where_to_find` + `document_name` + `fallback_estimation` | 0.05 j | None |
| 4 | precision_service: reframe `salaire_net.where_to_find` + `document_name` + `fallback_estimation` | 0.05 j | None |
| 5 | regression test `test_annual_refresh_archetype_aware.py` — 3 archetypes × salary label assertion | 0.1 j | 1+2 |
| 6 | full backend pytest pass | 0.05 j | All |

**Total estimé** : ~0.3 j.

## Counter-arguments and data gaps

- **Risk 1** : Other archetypes (independent, student, expat_us in transition) still get the salary-framed labels. This is intentional v1 — independents do have salary-equivalent income (revenue net independant) ; students and transition-state users typically don't trigger the annual refresh cron in the first place. v2 could reframe further.
- **Risk 2** : The `precision_service` fix changes user-visible copy. If users had memorized the old « Fiche de salaire mensuelle » phrasing they may be confused by the new enumeration. Mitigation : the new copy is a SUPERSET of the old ; old paths still work.
- **Risk 3** : Backwards compat — existing callers of `generate_refresh_questions()` don't pass `employment_status`. The new param defaults to None ; legacy behavior preserved. Tests cover this.
- **Risk 4** : Banned-term sweep — new copy uses « rentes », « retraits », « decompte de rente », none of which are banned per LSFin (no « garanti », « optimal », « meilleur »). Verified manually.
- **Data gap** : No telemetry on actual archetype distribution. We don't know how often the retiree-on-salary-cron mismatch fires today. Mitigation : log archetype × cron-fired event for 1 week post-deploy ; size impact based on actual ratio.

## Approval gate

**This PR opens immediately**. The fixes are backend-only, surgical, fully unit-tested, and reverse cleanly.

## Order of fixes (within this perimeter)

Single commit covering both services + STUB + regression test.
