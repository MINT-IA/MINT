# ADR — Hosting Migration Boundary

Status: Proposed
Date: 2026-07-09

## Context

MINT is a Swiss financial lucidity product that progressively collects salary,
tax, pension, insurance, mortgage, inheritance, and family variables. Railway is
currently part of the backend deployment architecture, but the target product
posture cannot treat a generic cloud host as a long-term home for raw,
identifiable financial state without an explicit decision.

This ADR defines the hosting boundary without pretending the current backend is
already stateless.

## Decision

Railway target = stateless compute only.

Policy: no new raw identifiable financial amount persisted server-side on Railway.
Railway may run API compute, orchestration, transient document processing,
health checks, and non-identifying operational telemetry. Any expansion of
server-side identifiable financial storage needs an ADR and privacy/compliance
review before merge.

Swiss hosting candidates for the storage migration are Infomaniak and Exoscale.

## Current Exceptions

Existing backend persistence means MINT cannot claim Railway is stateless today.
The current exceptions that drove this ADR are:

- `services/backend/app/models/snapshot.py:27` stores `gross_income`.
- `services/backend/app/models/profile_model.py:37` stores the full profile as JSON.
  Active write paths include `services/backend/app/api/v1/endpoints/profiles.py:120`
  on create and `services/backend/app/api/v1/endpoints/profiles.py:268` on update.
- `services/backend/app/models/scenario.py:20` and
  `services/backend/app/models/scenario.py:21` store scenario `inputs` and
  `outputs`.
- `services/backend/app/models/external_data_source.py:26` stores
  `cached_response` for external sources. This is a registered schema with no checked-in writer
  found at this ADR date, so it is treated as dormant storage risk rather than
  an active write path.
- `services/backend/app/models/document_memory.py:65` and
  `services/backend/app/models/document_memory.py:67` keep plaintext
  `evidence_text` and `vision_raw` nullable during the encryption migration
  window.
- `services/backend/app/models/coach_insight.py:45` stores `summary`, which may
  contain raw user financial facts.
- `services/backend/app/models/earmark.py:89` stores `amount_hint`.
- `services/backend/app/models/billing.py:86` stores `amount_cents`.
- `services/backend/app/models/snapshot.py:35` stores `tax_saving_potential`,
  a derived identifiable financial amount.

These exceptions are not permission to add more. They are inventory items to
reduce, encrypt, localize, or migrate before a production stateless-Railway
claim.

## Migration Triggers

Migration to a Swiss storage posture is already a production-readiness requirement
because server-side identifiable financial data exists today. Further migration
or hosting escalation is triggered by either condition:

- server-side storage of identifiable financial data expands beyond the current
  named exceptions;
- a regulatory requirement, including FINMA, nLPD, contractual, DPA, or legal
  counsel guidance, requires Swiss-controlled hosting or data residency.

## Alternatives Considered

- Keep Railway as full compute and data host indefinitely.
- Move all compute and storage immediately to Swiss hosting before the data
  model stabilizes.
- Keep Railway for stateless compute, block new raw identifiable financial
  amount persistence, and migrate storage when the trigger is reached.

## Consequences

- Backend PRs adding profile, document, pension, mortgage, inheritance, tax, or
  insurance persistence must check this ADR.
- CI and review should treat new raw identifiable financial amount fields on
  Railway as a governance event, not a casual model change.
- Engram, local agent memory, and chat transcripts are not compliance evidence.
  Checked-in ADRs, code, deployment config, PRs, and test results are the
  evidence.

## Migration Plan

1. Inventory server-side financial fields at each production-readiness gate.
2. Block or ADR-review new raw identifiable financial amount persistence.
3. If a trigger fires, choose Infomaniak or Exoscale for the first Swiss storage
   target.
4. Migrate storage before expanding compute, networking, DPA, secrets, and
   runtime proof.
5. Update `docs/DPA_TECHNICAL_ANNEX.md`, `docs/CICD_ARCHITECTURE.md`, secrets,
   deployment workflows, and mobile/backend runtime proof after migration.

## Evidence Links

- `docs/DPA_TECHNICAL_ANNEX.md`
- `docs/CICD_ARCHITECTURE.md`
- `services/backend/app/models/snapshot.py`
- `services/backend/app/models/coach_insight.py`
- `services/backend/app/models/earmark.py`
- `services/backend/app/models/billing.py`
