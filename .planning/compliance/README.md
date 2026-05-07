# `.planning/compliance/` — internal compliance working files

This directory holds the **internal working drafts** that back the public compliance artefacts in `docs/compliance/`.

## Filing convention

| File | Purpose | Public-facing twin |
|---|---|---|
| `counsel-brief-2026-05.md` | Working draft of the 1-h counsel review brief (carries firm names, fee placeholders, frank framing). | [`docs/compliance/COUNSEL_BRIEF.md`](../../docs/compliance/COUNSEL_BRIEF.md) (public-safe variant). |
| `counsel-shortlist-2026-05.md` | 3-firm shortlist (Pestalozzi / Lenz & Staehelin / Vischer) with fee + availability placeholders, decision criteria, Julien-action D12 selection slot. | — (internal only). |
| `counsel-signoff-2026-05.pdf` | **Reserved path** for the signed counsel attestation on letterhead. Filed post-call (D14-D15). Tracked by `docs/EVIDENCE.md` row 2. | — (the PDF itself is the artefact; binary, no public twin). |
| `nda-template-2026-05.md` | Mutual NDA template for the 5-tester cohort. (Drafted by Plan 97-02.) | — (internal only). |

## Status board

- **Counsel brief drafted:** YES (2026-05-07) — `counsel-brief-2026-05.md` + public twin `docs/compliance/COUNSEL_BRIEF.md`.
- **Counsel shortlist drafted:** YES (2026-05-07) — `counsel-shortlist-2026-05.md`.
- **Counsel firm selected:** PENDING — Julien-action D12.
- **Counsel slot booked:** PENDING — Julien-action D12.
- **Counsel sign-off PDF filed:** PENDING — Julien-action D14-D15. Reserved path: `counsel-signoff-2026-05.pdf`.
- **`docs/EVIDENCE.md` row 2 status:** PENDING (will move to GREEN once the PDF lands).

## Public-repo discipline

This directory lives inside the public `MINT-IA/MINT` repository. Per the project's public-repo discipline:

- No forensic legal-admission language in any committed file.
- Decisions are marked **Proposed** until founder sign-off.
- Tester names are anonymised to initials; no full names committed.
- The signed PDF, when filed, is a counsel-authored artefact and carries counsel's own framing.

## Lints

- `tools/checks/no_legal_admission_in_public_docs.py` — runs over `.planning/`, `decisions/`, `docs/`. Hits in this directory must be addressed before push.
- `tools/checks/accent_lint_fr.py` — runs over `.dart`, `.py`, `.arb`, `.md`. FR copy in this directory must carry full diacritics.
- `tools/checks/banned_terms_arb.py` / `compliance_guard.BANNED_TERMS` — applies to user-facing surfaces; brief copy is reviewed for the same vocabulary.

## How this directory grows

After D14-D15, the signed PDF is committed binary at the reserved path. After v2.15, this directory will likely accumulate one `counsel-brief-YYYY-MM.md` per material compliance refresh (target cadence: every 6 months, or whenever a new article enters the control matrix).
