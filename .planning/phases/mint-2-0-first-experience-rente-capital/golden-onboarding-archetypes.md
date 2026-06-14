# Golden Onboarding Archetypes — Mint 2.0 First Experience

These fixtures are not a scenario encyclopedia. They are a compact regression set for the first phase.

## Scoring Grid

Each fixture scores 0 or 1 on:

1. intention detected;
2. data state visible;
3. next action clear;
4. no personalized financial recommendation;
5. no naked number;
6. exit/reset accessible;
7. readable on iPhone 13 mini;
8. low cognitive load in G2 human review.

Pass threshold for the structured Mint 2.0 path: `>= 7/8` on each fixture and better than a baseline empty chat entry on at least 7 fixtures.

Baseline definition: the current empty-chat style first entry, scored with the same grid after the user provides only the fixture's initial intent.

Mechanical checks where possible:

- intention detected -> selected axis or event key stored in the draft/dossier;
- data state visible -> readiness or missing-fields widget visible;
- next action clear -> exactly one primary next action visible in the current step;
- no personalized financial recommendation -> copy does not contain imperative recommendation language;
- no naked number -> if a money/percent value is visible, provenance/readiness/version labels are visible too;
- exit/reset accessible -> exit or reset affordance visible and tappable;
- readable on iPhone 13 mini -> screenshot or UI snapshot reviewed for clipping/collision;
- low cognitive load -> G2 human review, not LLM-only.

## Canonical Fixtures

| ID | User situation | Primary event | Live axis | Required before amount | Expected first answer |
|---|---|---|---|---|---|
| A01 | 29, first stable job, wants to understand pension basics | career start | signalétique fiscal / pension education | none for amount because no amount allowed | explain dossier and why 3a/2e matter; invite follow, no calculation |
| A02 | 36, buying first home in VD, asks if 2e/3e can help | home purchase | logement signalétique | none for amount because axis not live | explain that housing door is tracked but not simulated yet; save interest |
| A03 | 47, changes job, has LPP transfer question | job change | rente/capital live if retirement/capital question emerges; otherwise education | age, LPP figure/range, context | clarify vested-benefit vs retirement decision; no irrelevant FATCA |
| A04 | 58, considers early retirement and rente vs capital | pre-retirement | rente/capital live | age/birth date, LPP amount/range, retirement timing, canton if fiscal view | readiness-first result; amount only if inputs sufficient |
| A05 | 63, asks "capital or pension?" with no figures | retirement decision | rente/capital live | LPP amount/range, household if required, timing | qualitative tradeoff and missing-fields list; no invented LPP |
| A06 | 41, divorced or separating, asks what happens to pension | family change | education first | no amount unless legal/calc inputs exist | explain dossier path, needed documents, no legal conclusion |
| A07 | 52, receives inheritance and asks taxes/investment impact | inheritance | impact fiscal signalétique | none for amount because axis not live | explain that fiscal impact door is tracked; ask whether to follow, no tax number |
| A08 | 39, cross-border or new Swiss tax residence | residence change | depends on question; usually education | canton/residence and employment before any fiscal personalization | route to residence facts; do not put rare compliance first for everyone |

## Life-Event Mapping

The first phase must be able to classify these events even when it does not calculate them:

- career start -> education / fiscal signalétique;
- job change -> LPP transfer or dossier update;
- home purchase -> logement signalétique;
- pre-retirement -> rente/capital live;
- retirement decision -> rente/capital live;
- separation/divorce -> family/pension education and required documents;
- inheritance -> fiscal signalétique and dossier follow-up;
- residence/cross-border change -> residence facts before fiscal claims.

## Reviewer Notes

- A hidden default number is an automatic fail.
- Asking a rare compliance question before the event requires it is an automatic fail.
- A clipped chip, button, row, or counter on iPhone 13 mini is an automatic fail.
- A chat answer that cannot be found later in the dossier is an automatic fail.
- A signalétique axis that calculates or collects unused detailed data is an automatic fail.
