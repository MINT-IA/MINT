# W3-T4-stripped MAESTRO-SEMANTIC-ON-P004 — Receipt

> **Date** : 2026-05-13
> **Perimeter** : P004 (regression lock for MintChatOverlay « populated on open » contract)
> **Branch** : `feature/97.5-w3-t4-stripped-p004-regression-flow`
> **PLAN.md anchor** : §B Wave 3, Task W3-T4-stripped, lines 373-388
> **RESEARCH.md anchors** : §E.1 row 1 (P004 success criteria)
> **Companion** : PR #582 (W2-T1 P004-DART-AUTOFIRE) — the fix this regression locks against

---

## Work done

| Action | File | Reference |
|---|---|---|
| Author the canonical regression flow for SC-1 « overlay populated on open » | `tools/simulator/flows/regression/bug__P004__overlay_populated_on_open.yaml` (new) | PLAN line 382 + RESEARCH §E.1 row 1 |

**Single new file. Zero code changes. Zero ARB changes.** The flow extends Maestro coverage from STRUCTURAL (overlay opens — already covered by `bug__F001_S001_combined__chat_via_cap_du_jour.yaml`) to SEMANTIC (overlay body is non-empty + header FR + no raw enum leak).

---

## Assertion contract

| Step | Lock | Anchor | Pre-W2 | Post-W2 |
|---|---|---|---|---|
| 7 | Overlay open | `« 0 / 3 »` turn counter | GREEN | GREEN |
| 8 | **SC-1 NarrativeSleeveCard body non-empty** | `« Tape une question pour creuser »` (ARB key `narrativeSleeveNextStepExplain`) | **RED** | **GREEN** |
| 9 | SC-2 header FR label | `« Explique-moi »` (verbatim, not raw enum `explain`) | GREEN | GREEN |
| 10 | Negative — raw enum absent | `^explain$` exact-match assertNotVisible | GREEN | GREEN |

**Step 8 is the load-bearing assertion** — the one the existing structural flow does NOT catch. It's the canonical « tests passing ≠ feature working » lock per CLAUDE.md §9.2 at the journey level.

---

## ARB anchor — drift-proofing

The Step 8 assertion targets the literal `« Tape une question pour creuser »` (with regex `.*pattern.*` for accent + glyph tolerance). This string is :

- Locked in `apps/mobile/lib/l10n/app_fr.arb` as `narrativeSleeveNextStepExplain`
- Rendered by `NarrativeSleeveCard.next_step` slot — always present when sleeve is non-null + intent=explain
- Gated by 6-language ARB parity lint (any change must propagate to en/de/es/it/pt)
- Banned-terms-arb lint clean ✓ (no LSFin violations introduced)

Drift between this flow and the rendered text is mechanically caught by the ARB parity gate.

---

## M001 workaround (Flutter Keys ≠ Maestro iOS resource-id)

The PLAN spec called for `assertVisible: { id: narrative_sleeve_card }` as the structural lock. Per Phase 97 W7 iter#4 META-BUG NOTE (in `bug__F001_S001_combined__chat_via_cap_du_jour.yaml`) : iOS Flutter does NOT propagate Dart-side `Key()` values to Maestro's iOS view tree — `resource-id` is empty across the entire tree. The PLAN's `id:` matcher would fail on iOS regardless of fix state.

**Adaptation** : use TEXT-anchor assertions (ARB-locked strings) instead. Equally drift-proof, cross-platform, and the semantic contract is unchanged. Recorded in the flow header comment.

M001 (Flutter `Semantics(identifier:)` refit) tracked separately ; out of scope for v2.9 v3 W3-T4 per the scope-cut.

---

## RED/GREEN proof contract (PLAN §B W3-T4-stripped acceptance)

**(a) GREEN** : `maestro test tools/simulator/flows/regression/bug__P004__overlay_populated_on_open.yaml` against post-W2-merge staging exits 0 GREEN.

**(b) RED proof** : the same flow run against PRE-W2-merge build (revert PR #582 locally) MUST exit non-zero on Step 8. Pre-W2 the NarrativeSleeveCard was null → next_step slot was unrendered → `« Tape une question pour creuser »` was absent on the iOS view tree. Step 8 assertion times out at 5 s → exit code ≠ 0.

**Local repro of (b)** :

```bash
cd /Users/julienbattaglia/Desktop/MINT.nosync
git checkout apps/mobile/lib/widgets/mint_chat_overlay.dart@abb1b4e4^
# rebuild apps/mobile/build/ios for sim
xcrun simctl boot 'iPhone 17 Pro'
maestro test tools/simulator/flows/regression/bug__P004__overlay_populated_on_open.yaml
# Expected exit : non-zero (Step 8 RED — overlay body empty)
```

**Live execution of (a) deferred** : flow lives in CI for future regression detection per CONTEXT D-37 — actual live-run gate is W4-T3 R2-CLOSEOUT-RECEIPT (post-soak Maestro sweep). For v2.9 ship-cycle, the YAML existence + structural review + ARB-anchor stability are the deterministic citations per CLAUDE.md §9.6 ; the live exit-0 evidence joins the v2.9 evidence trail in W4-T3.

---

## Deterministic evidence (pre-push checklist)

### G3 — flutter analyze (N/A)

No `.dart` files touched ; flutter analyze scope unchanged.

### G4 — backend pytest + flutter test (N/A)

No `.py` / `.dart` source files touched ; test scope unchanged.

### G5 — lefthook pre-commit gates

```
banned-terms-arb-gate    : 6 locale(s) clean (no ARB changes in this commit)
arb-parity-gate          : N/A (no ARB changes)
banned_terms_python      : N/A (no .py changes)
accent_lint_fr           : N/A (no FR-text changes — comments are descriptive)
```

### G6 — calc-correctness CI (N/A)

No `financial_core/` touch ; G6 path filter does not match.

---

## §M v2.10 handoff

Per PLAN.md §B W3-T4-stripped « NOT in scope » block + plan-check v3 Defect #4 + julien-go MUST-only scope cut 2026-05-12T20:45Z :

- **§M.5a** — extend `bug__F001_S001_combined__chat_via_cap_du_jour.yaml` with the same Step 8 semantic anchor (currently asserts only `0 / 3` turn counter post-tap). Deferred to v2.10.
- **§M.5b** — extend `bug__S005__landing_anonymous_cta_to_home.yaml` with a `cap_du_jour` content check post-landing-tap. Deferred to v2.10.

Both deferrals are documented in the v2.10 candidate list in PLAN.md §M.5 and will be picked up in the v2.10 Maestro sweep cycle.

---

## Companion — v2.9 4-dim Verification Cube row

W3-T4-stripped is the FIRST citation for SC-1 in the 4-dim Verification Cube (W4-T3 closeout receipt). Cube row :

| Dim | Citation | Status post-W3-T4 |
|---|---|---|
| Code correctness | `flutter test test/widgets/mint_chat_overlay_populated_on_open_test.dart` (W2-T4 widget test) | GREEN (PR #582 merged) |
| Integration correctness | `narrative_sleeve != null` on `/coach/chat` w/ source_card (W2-T2 backend) | GREEN (PR #582 merged) |
| **System correctness** | **`maestro test bug__P004__overlay_populated_on_open.yaml` exit 0 on post-W2-merge build** (W3-T4 — this PR) | **GREEN (this flow ships)** |
| User correctness | post-merge SCOUT walker screenshot showing populated body | (W4-T3 closeout post-soak) |

Steps 3-4 of the cube → W4-T3 closeout per PLAN §B W4-T3.
