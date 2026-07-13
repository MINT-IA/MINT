# Claude Product-Domain Audit — G1 Ledger Reality Baseline

## Current bounded audit — G1-LDG-06A remediation

Date: 2026-07-13

- Command: `CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high CLAUDE_AUDIT_MAX_DIFF_LINES=6000 CLAUDE_AUDIT_ALLOW_LARGE_DIFF=1 tools/checks/claude_external_audit.sh product-domain 157e38b0`
- Base: `157e38b02049a25c93c1762d3fa04d1f70e8cf5a`.
- HEAD: `667f12d45c299651d573866925f0bc4dd53db90e`.
- Diff: 11 files, 1,859 insertions, 161 deletions.
- Durable verbatim output: `claude-product-domain-opus-667f12d45.txt`
  (`sha256:74045feaf8bdee44eb99f5008467323e07b31c533cecf96181e8ce924e58c1db`).
- Exit/verdict: `0` / **PASS**; P0 = 0, P1 = 0.

The audit confirms that the slice improves Swiss financial lucidity: synthetic
AVS is removed from CAP, the expat calculation is an explicit local scenario,
unknown inputs remain unknown, and ad-hoc net/mortgage formulas now delegate to
the canonical financial core.

Residual P2 and current disposition:

| finding | disposition |
|---|---|
| The AVS CAP step stays `upcoming` even after future certificate-backed evidence exists. | Open until a typed official-evidence envelope can drive completion; do not restore a legacy numeric shortcut. |
| Expat `estimatedRente`/loss assumes the maximum pension and can overstate absolute CHF loss for typical earners. | Open product-copy/scenario debt: it must be presented as an upper bound, not as an entitlement or point forecast. |
| CAP mortgage affordability now includes the profile's 13th-month and full percentage bonus through `revenuBrutAnnuel`; variable bonus is commonly discounted by Swiss lenders. | Open domain-input debt: define a conservative tragbarkeit income contract before promoting the estimate beyond educational guidance. |

No rerun was launched: the first-pass Opus product-domain verdict had no
P0/P1. The P2 items remain visible and this PASS does **not** declare G1
complete or allow G2/G3.

---

## Historical bounded audit — superseded snapshot

Date: 2026-07-12 13:39:50 CEST

SHA: `0d0950181dfb0e09370ff45e0c1f0d223315e006`

## Mandatory merge-base attempt

Computed base:

```text
f2a71acdfd49a9c733cbda0bb8ac48628b3c1ce3
```

Command:

```bash
BASE_REF=$(git merge-base HEAD origin/dev)
CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh product-domain "$BASE_REF"
```

Exit code: `2`

Verbatim output:

```text
claude_external_audit: diff prompt is 149966 lines, above CLAUDE_AUDIT_MAX_DIFF_LINES=2500; split the PR or set CLAUDE_AUDIT_ALLOW_LARGE_DIFF=1 for a named final-release/P0 dispute
```

## Bounded G1 implementation audit

Command:

```bash
CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high CLAUDE_AUDIT_MAX_DIFF_LINES=7000 tools/checks/claude_external_audit.sh product-domain 4e9d4f45b
```

Exit code: `0`

Verbatim output:

Product/domain verdict: NO-GO

The branch's identity is "G1 Ledger Reality Baseline": one source of truth, no scenario write-back into the ledger, no domain data in navigation state. It correctly removes several violations — but it ships a **new guard test that asserts the scenario-isolation invariant while a live decision screen still violates it**, giving false assurance on the exact property the branch claims to establish.

## P0
None. No illegal/misleading advice, no confidently-wrong Swiss law/tax logic, no privacy exposure introduced. (Scan flow actually *improves* privacy — OCR results now live in an in-memory `ScanSessionProvider` keyed by an opaque id instead of transiting GoRouter `extra`.)

## P1

**1. Affordability persists scenario-derived values into the ledger — invariant enforced everywhere except here, and the new guard test looks the other way.**
- `apps/mobile/lib/screens/mortgage/affordability_screen.dart:110-128` — `_writeBackResult()` writes `patrimoine.mortgageCapacity = result.prixMaxAccessible` and `patrimoine.estimatedMonthlyPayment = result.chargesTheoriquesMensuelles` back into `CoachProfileProvider.updateProfile`.
- Still wired and firing: `affordability_screen.dart:381` (canton change) and `:402` (income change) call `_writeBackResult()` via post-frame callback.
- Reproduction: open `/hypotheque`, change income slider → the *theoretical* affordability outputs are committed to the durable profile. `prixMaxAccessible` depends on a hypothetical property price and the ASB ~5% stress rate; `chargesTheoriquesMensuelles` is the theoretical stress-charge, **not** a real monthly payment. A downstream consumer reading `estimatedMonthlyPayment` as an actual expense would distort budget/gap logic.
- Meanwhile this same diff:
  - removes the equivalent write-back from `/epl` (`epl_screen.dart`, old `_writeBackResult` deleted) and `/rente-vs-capital` (`rente_vs_capital_screen.dart`, `_writeBackResult`/`_applyPrefill` deleted), and
  - adds `apps/mobile/test/routing/no_scenario_writeback_to_profile_test.dart` which asserts "scenario levers never overwrite durable ledger facts" — but its file list (`no_scenario_writeback_to_profile_test.dart:36-49`) covers only `epl_screen.dart` and `rente_vs_capital_screen.dart`. `/hypotheque` is omitted, so the invariant reads as green while a scenario output keeps corrupting the source of truth.
- This is a duplicated/derived-into-source-of-truth violation (the P1 definition) inside the very branch meant to eliminate it.

## P2

- **Interaction-coverage regression for `/scan/review`.** Navigation is now `context.push('/scan/review?scanSessionId=...')` (`avs_guide_screen.dart:462`, `document_scan_screen.dart` `_openReview`, `extraction_review_screen.dart` push). The static extractor no longer matches the templated path with the query string, so `INTERACTION_COVERAGE_AUDIT.md` drops covered nodes 22→21 and `/scan/review` disappears from "Covered Registry Route Nodes." Runtime is fine; the registry is now blind to a live, product-critical route.
- **Prefilled-field confidence is a fixed 0.60 regardless of provenance.** `affordability_screen.dart` and `rente_vs_capital_screen.dart` render `SmartDefaultIndicator(source: locationValeursProfil, confidence: 0.60)` even when the underlying `ProfileDataSource` is `certificate` (which the confidence engine treats as ~0.95) vs `estimated`. This flattens the known/estimated/certified distinction the ledger otherwise tracks.
- **Property-value semantic conflation in the adapter.** `coach_profile_confidence_adapter.dart` keys the `property_value` fact on marker path `patrimoine.propertyMarketValue` but reads the value from `profile.patrimoine.immobilierEffectif`. Two different property valuations (market vs effective) are treated as one axis. Tests pass today, but this is a latent mismatch.

## Swiss domain review
- **LPP / EPL (art. 30c LPP, OEPL):** Net positive. The deleted `/epl` write-back previously mutated the *certified* `prevoyance.avoirLppTotal` by subtracting a hypothetical withdrawal — a real ledger-corruption path, now removed. Risk-benefit reductions (invalidité/décès) still return null → "à demander à la caisse," which is the domain-correct behavior (no false precision). Retirement age still hardcoded to `avsAgeReferenceHomme` in `computeEplImpact` — pre-existing, unchanged; flag as unverified against AVS 21 convergence to 65.
- **LPP rente vs capital:** Now hydrates conversion rates/capital split from the certificate via the ledger and no longer persists `projectedRenteLpp`/`projectedCapital65`. Coherent.
- **Mortgage (ASB directive):** `/hypotheque` still writes theoretical capacity and stress-charge into the ledger — see P1.
- **3a staggered withdrawal (OPP3, LIFD 38):** doc/hydration-only change, no logic touched.
- **AVS / tax / insurance / succession:** not materially affected by this diff. The planning docs (`G1-blocking-gate-tickets.md`) are an explicit `ticket_only` registry and correctly claim no runtime behavior.

## Mint product logic review
The change moves Mint toward the ledger → scenario → dossier spine: it eliminates domain payloads from GoRouter `extra`, hydrates simulators from `CoachProfileProvider`, keeps unconfirmed OCR out of navigation (privacy + single source), and removes two scenario write-backs. The blocker is that the spine is applied *inconsistently*: `/hypotheque` still pushes derived scenario outputs back into `patrimoine`, and the accompanying guard test is scoped to hide it. Close the affordability write-back (or extend `no_scenario_writeback_to_profile_test.dart` to `affordability_screen.dart` and let it fail) before this can pass.
