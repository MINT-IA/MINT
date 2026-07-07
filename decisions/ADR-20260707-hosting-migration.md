# ADR-20260707 — Hosting Migration Triggers

Status: Proposed
Date: 2026-07-07

## Contexte

MINT currently uses Railway in the deployment architecture, while the product
direction is Swiss financial lucidity with progressively richer personal data.
This ADR defines a target hosting boundary without pretending the current
backend is already stateless.

Current persistence exceptions in the backend:

- `services/backend/app/models/snapshot.py:27` stores `gross_income`.
- `services/backend/app/models/coach_insight.py:45` stores `coach_insight.summary`.
- `services/backend/app/models/earmark.py:89` stores `amount_hint`.
- `services/backend/app/models/billing.py:86` stores `amount_cents`.

## Décision

Railway target = stateless compute only.

The target policy is no new raw identifiable financial amount persisted server-side
on Railway. Railway may run stateless API compute, orchestration, and transient
processing, but identifiable financial state should move to a Swiss hosting
posture before production use of server-side personal finance storage expands.

Migration to a Swiss host is triggered by either condition:

- server-side storage of identifiable financial data beyond the current
  explicitly named exceptions;
- regulatory requirement, including a FINMA or legal/compliance requirement
  that hosting or data residency must be Swiss-controlled.

Target Swiss hosting candidates: Infomaniak or Exoscale.

## Alternatives considérées

- Keep Railway as full application and data host indefinitely.
- Move immediately to Swiss hosting before the product data model stabilizes.
- Keep raw identifiable financial state local-first and use Railway only for
  stateless compute until a migration trigger is reached.

## Conséquences

- New backend features must not add raw identifiable financial amount
  persistence casually; if they do, this ADR requires an explicit review.
- Existing persistence exceptions remain visible and must be reduced or migrated
  before claiming a stateless Railway posture.
- Engram and agent memory are not compliance evidence; checked-in ADRs, code,
  deployment configuration, and PR history are authoritative.

## Plan de migration

1. Inventory server-side financial fields before each production-readiness gate.
2. Block new raw identifiable financial amount fields unless an ADR updates this
   policy.
3. If a trigger fires, choose Infomaniak or Exoscale, migrate storage first,
   then move compute or networking as needed.
4. Update the DPA, deployment workflows, secrets, and runtime proof after the
   migration.

## Liens

- `docs/DPA_TECHNICAL_ANNEX.md`
- `docs/CICD_ARCHITECTURE.md`
- `.github/workflows/deploy-backend.yml`
- `services/backend/app/models/snapshot.py`
- `services/backend/app/models/coach_insight.py`
- `services/backend/app/models/earmark.py`
- `services/backend/app/models/billing.py`
