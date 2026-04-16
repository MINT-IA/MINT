# DPA Technical Annex — MINT Finance SA

> **DRAFT v1 — LEGAL REVIEW PENDING**
> Status: internal draft produced at end of Phase 29 (compliance & privacy).
> Intended audience: Walder Wyss / MLL Legal (Swiss nLPD + LSFin specialists).
> Language: French primary; English translation maintained in parallel.
> Last updated: 2026-04-14.

## Revision history

| Version | Date       | Author        | Change                                   |
|---------|------------|---------------|------------------------------------------|
| v1      | 2026-04-14 | Julien (MINT) | Initial draft, end of Phase 29 planning. |

## Table of contents

1. Purpose and scope
2. Sub-processors
3. Data categories transferred per sub-processor
4. Retention per sub-processor
5. Technical and organisational measures (TOM)
6. Cross-border transfer mechanisms
7. Data subject rights and enforcement
8. Incident response
9. Audit trail and geographic notes

---

## 1. Purpose and scope

### 1.1 Controller

**MINT Finance SA** (CH), acting as data controller under nLPD art. 5(j) and
GDPR art. 4(7). Contact: `privacy@mint.finance` (placeholder).

### 1.2 Subject of the processing

The MINT application ("**MINT**") is a Swiss-law educational financial-literacy
service. Per `visions/vision_compliance.md` §2, MINT is expressly **read-only**
and never recommends named products, never moves money, never offers advice
within the meaning of LSFin art. 3.

### 1.3 Data categories processed

| Class            | Examples                                                                 |
|------------------|--------------------------------------------------------------------------|
| Identifying      | First name, canton, birth year (coarsened), user_id (UUIDv4).            |
| Financial        | Pillar 3a balance, LPP avoir, salary bracket, housing situation.         |
| Documents        | Uploaded LPP certificates, payslips, tax declarations, insurance policies.|
| Conversational   | Chat history with the coach, premier_eclairage insights, tension cards.  |
| Consent          | ConsentReceipt records (ISO/IEC 29184:2020-compliant).                   |

### 1.4 Purposes

Five purposes, each consent-gated (`ConsentPurpose` enum in phase 29-02):

1. `essential_service` — core coach chat and extraction.
2. `document_upload` — processing of uploaded documents.
3. `persistence_365d` — retention of extracted facts beyond session.
4. `ai_context_sharing` — sending to Anthropic/Bedrock for inference.
5. `third_party_attestation` — opposable third-party declarations (Phase 29-05).

---

## 2. Sub-processors

As of 2026-04-14. Notification of any change: **30 calendar days** minimum,
with right to object.

| # | Sub-processor        | Role                               | Location                      | Transfer mechanism            |
|---|----------------------|------------------------------------|-------------------------------|-------------------------------|
| 1 | Anthropic PBC        | LLM inference (Claude Sonnet / Haiku) — direct API, **fallback only post-Bedrock flip** | US                            | Swiss-US DPF + SCC module 2   |
| 2 | AWS EMEA SARL        | LLM inference via **Bedrock eu-central-1** (Frankfurt) + application hosting | EU (DE)                       | Intra-EU; no third-country transfer |
| 3 | Railway Corp         | Application hosting                | EU data region (to confirm)   | SCC module 2                  |
| 4 | Sentry (Functional Software Inc.) | Error monitoring      | US (EU isolation tier offered) | Swiss-US DPF                  |
| 5 | Microsoft Presidio   | PII detection (self-hosted in Railway EU) | EU                          | Intra-EU                      |
| 6 | Google Cloud (MLKit) | On-device OCR (no cloud hop in default flow) | CH device                    | Not applicable                |

### 2.1 Bedrock EU primacy

From v2.7 Phase 29-06, all LLM inference for EU users routes preferentially
through AWS Bedrock `eu-central-1` (Frankfurt). Anthropic direct remains in
the critical path only as a fallback when Bedrock is unavailable, gated by
`BEDROCK_EU_PRIMARY_ENABLED`. A two-week **shadow mode** precedes primary
flip (dual-fire, metrics-only comparison — no production traffic exposed).

### 2.2 No AWS CH region

As of 2026-04, no AWS region exists in Switzerland. `eu-central-1` (Frankfurt)
is the closest adequate jurisdiction. This is a **documented TOM limitation**;
MINT commits to migrating to an AWS CH region if and when one is offered.

---

## 3. Data categories transferred per sub-processor

| Sub-processor | Essential service | Document upload | Persistence 365d | AI context sharing | Third-party |
|---------------|-------------------|-----------------|------------------|--------------------|-------------|
| Anthropic (fallback)     | Chat turn + system prompt (scrubbed) | Vision: document image | Fact snapshots (scrubbed) | Coach narrative generation | n/a |
| AWS Bedrock eu-central-1 | Same as above — primary | Same as above — primary | Same as above — primary | Same as above — primary | n/a |
| Railway (app host)       | All user data (encrypted at rest) | Encrypted blobs | Encrypted blobs | n/a | Consent receipts |
| Sentry                   | Exception stack traces (PII-scrubbed) | Upload errors (no bodies) | n/a | n/a | n/a |
| Presidio (self-hosted)   | Chat text (PII detection only, not retained) | Document text (detection only) | n/a | n/a | n/a |
| Google MLKit             | n/a — on-device only | OCR text (on-device) | n/a | n/a | n/a |

**Key:** content is always **PII-scrubbed** (phase 29-03) before crossing the
app-to-sub-processor boundary, except raw document bytes which are additionally
**pre-masked** (phase 29-06 `mask_pii_regions`) when `MASK_PII_BEFORE_VISION`
is active.

---

## 4. Retention per sub-processor

| Data class                       | Retention                                               | Mechanism                                                                        |
|----------------------------------|---------------------------------------------------------|----------------------------------------------------------------------------------|
| Consent receipts                 | 10 years                                                | LSFin art. 74 audit trail. Encrypted + merkle-chained (phase 29-02).             |
| Evidence text (extracted facts)  | 365 days (rolling)                                      | Envelope AES-256-GCM encryption + DEK crypto-shred on revoke (phase 29-01).      |
| Chat logs (sanitised)            | 30 days plain; 365 days FPE-tokenised; purge at day 366 | Two-tier log rotation (phase 29-03 fact_key allowlist).                          |
| Error events                     | 90 days                                                 | Sentry retention policy.                                                         |
| Sub-processor inference traces   | **Not retained** by Anthropic (ZDR) / AWS Bedrock       | Anthropic ZDR clause; AWS Bedrock inference inputs not logged by default.        |
| OAuth tokens / bank credentials  | Not applicable                                          | MINT does **not** connect to bank accounts. Read-only data entry only.           |

---

## 5. Technical and organisational measures (TOM)

| # | Measure                                          | Implementation                                                                               | Phase |
|---|--------------------------------------------------|----------------------------------------------------------------------------------------------|-------|
| 1 | Encryption in transit                            | TLS 1.3 ubiquitous; AWS SigV4 for Bedrock.                                                   | —     |
| 2 | Encryption at rest                               | AES-256-GCM envelope on evidence_text; Fernet fallback in dev; optional AWS KMS data keys.   | 29-01 |
| 3 | Crypto-shredding on revoke                       | DEK destruction on `persistence_365d` revoke — mathematical non-recoverability.              | 29-01 |
| 4 | PII scrubbing (defense-in-depth)                 | Presidio NER + regex belt on all logs and LLM inputs.                                        | 29-03 |
| 5 | FPE tokenisation for analytics                   | Format-preserving encryption (pyffx) — downstream consumers still parse structurally.        | 29-03 |
| 6 | Granular consent with ISO 29184 receipts         | 5 purposes, per-user signed receipts, merkle-chained, HMAC-integrity.                        | 29-02 |
| 7 | Compliance judge on Vision output                | Haiku-4.5 LLM-as-judge; fail-closed on error; deterministic numeric sanity bounds.           | 29-04 |
| 8 | Third-party declarations (opposable consent)     | Per-doc_hash attestation, HTTP 428 gate, subject-name + IP-hash signed receipts.             | 29-05 |
| 9 | Bedrock EU routing (data stays in EU)            | Primary inference path through `eu-central-1` Frankfurt; Anthropic direct = fallback only.   | 29-06 |
| 10 | Two-stage image pre-masking                     | Tesseract OCR + PII-span detector → filled black rectangles before Vision call.              | 29-06 |
| 11 | Shadow-mode validation                          | Dual-fire + metrics-only diff log (`llm_shadow_diff`) — no content bodies logged.            | 29-06 |
| 12 | Router gate (no direct LLM calls)               | CI-enforced: zero `client.messages.create` outside `services/llm/` router package.           | 29-06 |
| 13 | Rate limiting & token budgets                   | Per-user Redis sliding window; Anthropic→Haiku degradation on SLO breach.                    | 27    |
| 14 | Observability with PII-safe logs                | Structured JSON logs; automatic PII filter applied before sink.                              | 29-03 |

### 5.1 Known limitations

- **Frankfurt ≠ Switzerland** (see §2.2). AWS CH region not yet offered.
- **Two-stage masking is default-OFF** at v2.7 ship. Activation gated by
  `MASK_PII_BEFORE_VISION` flag after Bedrock-primary stability is validated
  (prevents compounding two risky rollouts).
- **Anthropic fallback path** remains in use until Bedrock-primary shadow
  validates quality parity (~2-week minimum shadow window).

---

## 6. Cross-border transfer mechanisms

| Flow                                    | Mechanism                             | Basis                                                              |
|-----------------------------------------|---------------------------------------|--------------------------------------------------------------------|
| CH app user → Bedrock eu-central-1      | Adequate jurisdiction (EU → CH)        | FDPIC/PFPDT 2024 list: EU declared adequate.                       |
| CH app user → Anthropic US (fallback)   | Swiss-US DPF + SCC module 2            | DPF certification **must be verified** on dataprivacyframework.gov. |
| CH app user → Railway EU region         | Intra-EU                               | GDPR chapter V not triggered.                                       |
| CH app user → Sentry US (EU tier)       | Swiss-US DPF + minimisation            | Only exception stack traces (PII-scrubbed).                         |

A **Transfer Impact Assessment (TIA)** is on file for the Anthropic US fallback
path, per PFPDT guidance. TIA conclusion: transfer is permissible given
(i) content PII-scrubbing upstream, (ii) Swiss-US DPF adequacy, and (iii) the
short-term transitional nature of the fallback as Bedrock primary rolls out.

---

## 7. Data subject rights and enforcement

Under nLPD arts. 25–31 and GDPR arts. 15–22, MINT implements the following:

| Right                | Implementation                                                                                   |
|----------------------|--------------------------------------------------------------------------------------------------|
| Right to access      | User dashboard export (JSON) — all fact_key records + consent history.                           |
| Right to rectification | In-app editing of all extracted fields; Vision review gate (`FieldStatus.needs_review`).      |
| Right to erasure     | Crypto-shredding via DEK destruction; cascade to `persistence_365d` revoke (phase 29-01/02).     |
| Right to portability | **Deferred** to future "Dossier Federation" milestone. Interim: JSON export on request.          |
| Right to object      | Per-purpose consent revoke (`ConsentPurpose`); inference opt-out via `ai_context_sharing` toggle.|
| Right to restriction | Purpose revocation without account deletion.                                                     |
| Right to lodge a complaint | Controller contact + PFPDT link prominent in privacy policy.                              |

---

## 8. Incident response

1. **Detection** via Sentry + backend structured logs + Redis-level SLO monitor.
2. **Triage** within 24 hours: classify severity (P0 personal-data breach → 72h
   PFPDT notification window per nLPD art. 24).
3. **Containment**: feature-flag kill-switch (`BEDROCK_EU_PRIMARY_ENABLED=false`,
   `DOCUMENTS_V2_ENABLED=false`, etc.) available to ops without deploy.
4. **Notification**: user + PFPDT notifications issued per nLPD art. 24 if the
   breach is likely to cause risk. Template in `legal/INCIDENT_RESPONSE.md`.
5. **Post-mortem** logged in `decisions/` as an ADR; CI test added to prevent
   recurrence.

---

## 9. Audit trail and geographic notes

### 9.1 Merkle-chained consent receipts

Per phase 29-02 implementation, each ConsentReceipt is HMAC-signed and chained
to the prior receipt for the same user via `previousReceiptHash`. Tampering is
detectable without decrypting user data.

### 9.2 Router audit

Every LLM invocation emits a structured log line with `purpose`, `route_mode`
(`off` / `shadow` / `primary_bedrock`), and the user-scoped flag snapshot.
Enables regulator to reconstruct which jurisdiction handled inference on any
given request.

### 9.3 Geographic summary

| Data class              | Cantonal (CH)      | EU (Bedrock / Railway) | US (Anthropic / Sentry) |
|-------------------------|--------------------|------------------------|-------------------------|
| Evidence (encrypted)    | via Railway EU     | Railway EU             | Never                   |
| Chat (scrubbed)         | n/a                | Bedrock primary        | Anthropic fallback      |
| Consents                | n/a                | Railway EU             | Never                   |
| Error telemetry         | n/a                | n/a                    | Sentry US (scrubbed)    |

---

*End of DPA Technical Annex v1 — DRAFT, pending Walder Wyss / MLL Legal review.*
