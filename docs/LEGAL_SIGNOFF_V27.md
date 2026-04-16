# Legal Sign-Off v2.7 — Template

**Fills:** prerequisite to flipping prod feature flags (`DOCUMENTS_V2_ENABLED`, `PRIVACY_V2_ENABLED`).
**Created:** 2026-04-15
**Status:** BLANK — Julien fills after outside-counsel session.
**Reference docs for the reviewer:**
- `docs/DPA_TECHNICAL_ANNEX.md` (produced in 29-06)
- `docs/LEGAL_REVIEW_CHECKLIST_29.md` (produced in 29-06)
- Privacy policy v2.3 draft (29-02)
- Consent receipts spec (29-02, ISO 29184 + merkle chain)
- Data retention policy (29-06, 6 months post-deletion)
- Bedrock EU sub-processor disclosure (29-06)

---

## Review subject

The following artefacts are submitted for outside-counsel review before v2.7 ships to prod:

1. **DPA Technical Annex** (29-06) — sub-processors, transfers (SCC + DPF), security, crypto-shred.
2. **Privacy Policy v2.3 draft** (29-02) — 4 purposes, Anthropic / Bedrock EU disclosure,
   retention (6 months post-account-deletion), user rights (access, rectification, erasure,
   portability).
3. **Consent receipts spec** (29-02) — ISO 29184 conformance, HMAC signature + sha256 merkle
   chain per user, 4-purpose granular consent.
4. **Data retention policy** (29-06) — `profile_facts` kept = account lifetime + 6 months;
   raw documents never stored (stream-only); `evidence_text` encrypted at rest with per-user DEK.
5. **Third-party document disclosure** (29-05) — opposable declaration + session-scoped routing +
   invite stub.
6. **LSFin + FINMA compatibility** — educational tool, not decisional ; no auto-confirm at any
   confidence; ComplianceGuard on Vision output (29-04).

---

## Firm consulted

- [ ] **Walder Wyss** (Zurich / Geneva)
- [ ] **MLL Legal** (Zurich / Geneva)
- [ ] **Other:** ________________________________________

## Session details

- **Session date:** ________________
- **Reviewer (avocat name):** ________________________________________
- **Bar number / registration:** ________________
- **Attendees from MINT side:** Julien Battaglia (founder)

---

## Decisions table

| # | Item | Reviewer decision | Action required | Due date |
|---|------|-------------------|-----------------|----------|
| 1 | DPA annex signing (Anthropic + Bedrock EU) | Approve / Amend / Reject | | |
| 2 | Privacy policy v2.3 wording (4 purposes, sub-processors) | Approve / Amend / Reject | | |
| 3 | Anthropic sub-processor disclosure (US + EU via Bedrock) | Approve / Amend / Reject | | |
| 4 | Bedrock EU migration timeline (shadow → primary) | Approve / Amend / Reject | | |
| 5 | Consent receipt wording (4 purposes, granular) | Approve / Amend / Reject | | |
| 6 | Retention: profile_facts = account + 6 months post-deletion | Approve / Amend / Reject | | |
| 7 | Third-party document disclosure wording (session-scoped) | Approve / Amend / Reject | | |
| 8 | Image masking pre-Vision policy (29-06 two-stage masker) | Approve / Amend / Reject | | |
| 9 | LSFin "éducatif pas décisionnel" wording | Approve / Amend / Reject | | |
| 10 | FINMA circular compatibility (no investment recommendation) | Approve / Amend / Reject | | |

---

## Blockers for prod rollout

List any item marked "Amend" or "Reject" above with specific wording/action required.
Resolve every blocker before flipping `DOCUMENTS_V2_ENABLED=true` in production.

| # | Blocker | Origin | Fix owner | Target date | Resolution commit |
|---|---------|--------|-----------|-------------|-------------------|
|   |         |        |           |             |                   |

---

## Final sign-off

Once all blockers above are resolved:

- **Julien's signature:** ________________________________________
- **Sign-off date:** ________________
- **Signed commit:**
  ```bash
  git commit --allow-empty -s -m "legal-signoff(v2.7): avocat review complete, no blockers"
  ```

After this commit, the device-gate executor may proceed to close v2.7.

---

## Notes

- This document is **not** a substitute for the DPA / privacy policy legal review sessions —
  it records only the decisions made, not privileged client-attorney discussions.
- No privileged material is stored in this file (per T-30-11 threat disposition).
- If reviewer requires fundamental structural change (new sub-processor, new retention scheme),
  open a dedicated phase (e.g., 31-legal-amendments) rather than patching inline.

*Template v1.0 — fills GATE-01/02 legal pre-requisite.*
