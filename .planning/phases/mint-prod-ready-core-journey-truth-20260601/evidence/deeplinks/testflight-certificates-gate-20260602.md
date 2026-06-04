---
id: CJT-015
date: 2026-06-02
status: open
area: release-testflight
release_blocker: true
---

# CJT-015 — TestFlight certificates gate

## Context

After commit `60207f0e95486b6ba877c66d9ae453e9c77b7696`
(`fix: keep coach route hints phase-specific`) was pushed to `staging`,
the functional CI and Railway staging deploy passed, but the TestFlight
workflow failed before iOS build/upload.

## Run

- Workflow: `TestFlight`
- Run: `26834962687`
- URL: `https://github.com/MINT-IA/MINT/actions/runs/26834962687`
- Job: `Build iOS + Upload TestFlight`
- Failed step: `Configure git credentials for certificates repo`

## Failure

The step failed while cloning the certificates repository:

```text
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/Julienbatt/mint-certificates.git/'
::error::Certificates repo clone failed. Rotate MATCH_GIT_BASIC_AUTHORIZATION with read access to Julienbatt/mint-certificates.
```

## Classification

This is a release credentials/certificates gate, not a CJT-009 product
navigation regression:

- CI run `26834960895` for the same commit passed.
- Design lints, semantic copy lints, and sync branches passed.
- Railway staging deploy `aa9af1ff-a553-45c7-8e84-fdf9b21acdfd` succeeded.
- Staging health returned `{"status":"ok"}`.

## Required Closure Proof

- Rotate or restore `MATCH_GIT_BASIC_AUTHORIZATION` with read access to
  `Julienbatt/mint-certificates`.
- Rerun TestFlight workflow successfully.
- Continue the existing CJT-015 release proof chain: signed archive, direct
  `mint-ai.ch` AASA, associated domains entitlement, and real-device Universal
  Link evidence or explicit release deferral.
