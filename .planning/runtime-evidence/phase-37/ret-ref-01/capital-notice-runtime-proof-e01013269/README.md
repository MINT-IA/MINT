# G1 RET-REF-01 — LPP capital-notice exact-SHA runtime proof

## Scope

This package is the minimized, sanitized runtime proof for the technical
`lppCapitalNoticeDeadline` atom only. It does not activate the feature, close
RET-REF, or close G1.

- Exact source commit: `e010132690bf22fe953f1bddbbecf5fee8bda723`
- Mint OS Doctor: full Doctor passed before the runtime run.
- Patrol tooling: the checked-in Patrol tooling guard passed.
- Data classification: synthetic only.
- Private fixture used: false.
- Production capital-notice acquisition seam used: false.

## Proven runtime chain

1. The Patrol writer passed **1/1**. It used a real synthetic numeric self-LPP
   scan, followed by the bounded test-only provider accept and exact-BND record.
2. The app process underwent a **real terminate** (`simctl terminate`, exit 0).
3. The cold Patrol reader passed **1/1**. It loaded the persisted ledger,
   hydrated the exact BND reference, showed the **Dashboard** capital-notice
   surface, then proved **invalidation** after a new self-LPP review created a
   replacement snapshot.
4. An exact-commit physical source export was used for a **production
   rebuild/install**; export, extraction, build, code-sign, xattr cleanup, and
   installation all exited 0.
5. The production-default, feature-flag-off **Maestro run passed 1/1**, proving
   the capital-notice acquisition/banner path was absent from the normal app.
6. The normal-build core **before hashes equal the after hashes** byte for byte.
   Both manifests have SHA-256
   `923ef6b0146ab4d564d0b2515a711901cffe0224184cd13dbd92e2e26a191193`.

## Privacy and evidence minimization

Only these sanitized summaries, integrity manifests, and verdict documents are
tracked. No raw logs, raw simulator identifier, screenshots, result bundles,
private financial document, or local filesystem path is included. Simulator
identifiers in result summaries are redacted.

## Verdict

The exact-SHA technical runtime atom is **GREEN**. Feature activation is
**NO-GO** because the production acquisition seam is false and this proof is
synthetic-only. RET-REF and G1 remain open; G2/G3 remain forbidden.
