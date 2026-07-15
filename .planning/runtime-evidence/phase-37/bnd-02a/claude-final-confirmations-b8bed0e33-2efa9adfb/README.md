# G1 PROV-02 / BND-02A — wrapper-only Opus final confirmations

This lightweight archive retains the four final exact-SHA Claude confirmations
for the backend and mobile closure slices. The copied `stdout`, empty `stderr`,
metadata and source checksum manifests are byte-identical to the final wrapper
outputs. No worktree location, temporary staging path, private certificate,
PII, credential, token, or large runtime bundle is retained.

## Audit gate result

- Final confirmations: **4/4 PASS** (`code` + `product-domain` for backend and
  mobile).
- P0: **0**. P1: **0**.
- P2 observations: **8**, all informational, accepted, resolved, or positive
  validation; none is an unresolved audit-gate blocker. Exact dispositions are
  machine-readable in `audit-manifest.json`.
- External-audit rubric subscore for these exact slices: **1.0/1.0**.

This archive is the external-audit sub-gate consumed by the later exact-SHA
runtime acceptance. **G1-BND-02 and G1-BND-02A are now technical GREEN at
`1d022c508`, while activation and G1 remain NO-GO.** The audit PASS results do
not prove the eight missing publishable external controller/vendor/legal facts.
The companion `runtime-1d022c508` archive supplies the completed Patrol/Maestro
proof; neither archive authorizes G2/G3 work.

## Exact audit chain

Backend head `b8bed0e33f9a4c6199bc7e3e91339f1ddd9a2fa3`, base
`eba7361ce35234f3d531f4355a8ce0e9304ff826`:

```bash
CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1 \
  tools/checks/claude_external_audit.sh code eba7361ce35234f3d531f4355a8ce0e9304ff826
CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1 \
  tools/checks/claude_external_audit.sh product-domain eba7361ce35234f3d531f4355a8ce0e9304ff826
```

Mobile head `2efa9adfb51ae594f75ca2b8d86c7c4d1018c26f`, base
`b8bed0e33f9a4c6199bc7e3e91339f1ddd9a2fa3`:

```bash
CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1 \
  tools/checks/claude_external_audit.sh code b8bed0e33f9a4c6199bc7e3e91339f1ddd9a2fa3
CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1 \
  tools/checks/claude_external_audit.sh product-domain b8bed0e33f9a4c6199bc7e3e91339f1ddd9a2fa3
```

Every run used the checked-in wrapper, an exact detached head, Opus/high,
`rerun=1`, the explicitly authorized non-Sonnet final-confirmation override,
no large-diff override and exit code 0. There was one final confirmation per
lens: no audit carousel.

## Verification

From this directory:

```bash
(cd backend && shasum -a 256 -c SHA256SUMS)
(cd mobile && shasum -a 256 -c SHA256SUMS)
shasum -a 256 -c SHA256SUMS
python3 -m json.tool audit-manifest.json >/dev/null
```

The root `SHA256SUMS` covers the note, manifest and every retained source file,
including the two nested source checksum manifests.
