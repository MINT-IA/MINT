# Quality gate scorecard — G1 LPP regulation mobile authority

**Implementation SHA:** `01b3bd8acad2a98fce0c0f2778340c5ddef7a7a7`

**Bounded authority score:** **9.0/10**

**Authority code:** **GREEN**

**Acquisition / consumer / runtime / activation / G1:** **NO-GO**

This score applies only to the typed model, ledger writer, raw-free document
authority bridge, cold resolver and session-safe coexistence contracts. It is
not an end-to-end product, RET-REF or G1 completion score.

| Dimension | Score | Evidence |
|---|---:|---|
| Data contract | 2.0 / 2.0 | Strict self-only metadata, exact UUID/date/year allowlists, nested single ledger root, receipt matcher, raw-free BND tuple and cold snapshot join. |
| Swiss correctness | 1.5 / 1.5 | A fund regulation is document authority only; no plan value, conversion rate, benefit, return or Swiss threshold becomes a personal fact. |
| UX lucidity | 1.0 / 1.5 | Known/missing/stale mechanics fail closed in the authority layer; no live screen or specialist consumer exists, so activation loses 0.5. |
| Runtime proof | 1.0 / 1.5 | 112 Flutter model/provider/session tests pass, including cold hydration and account epoch; no Maestro/Patrol or production acquisition proof, so activation loses 0.5. |
| Automated tests | 1.0 / 1.0 | Targeted suite 112/112; eight touched files analyze with zero issues; Doctor and diff checks pass. |
| External audit | 1.0 / 1.0 | Six bounded Opus outputs PASS; authority scope P0=0/P1=0. Two delivered-product P1 wiring findings are retained as NO-GO boundaries. |
| Integration/privacy hygiene | 1.0 / 1.0 | Raw-free, self-only, default-off, synthetic tests; no private document, PII, OCR, bytes, filename or local path retained. |
| Diff discipline | 0.5 / 0.5 | Atomic RED→GREEN slices, canonical kind fix, exact-SHA minimized evidence. |
| **Total** | **9.0 / 10.0** | Authority code accepted; no product activation or G1 promotion. |

## Gate qualification

A full-project `flutter analyze --no-pub` exits 1 on two `prefer_const` infos in
the untouched `lpp_capital_notice_deadline_provider_test.dart`. The eight files
changed by this authority slice each pass targeted `dart analyze` with zero
issues. The global analyzer baseline remains transparently non-green; no
out-of-scope file was rewritten.
