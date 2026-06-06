# Row 11 Rapport PDF Export Failure Feedback — 2026-06-06

## Scope

CJT-056 adds local proof for two adjacent Row 11 risks found after CJT-055:

- `/rapport` export errors thrown by PDF generation/sharing now surface user-visible feedback instead of failing silently.
- repeated PDF exports in the same process no longer reuse a cached PDF theme object; a failing export followed by a successful export is now covered by widget proof.

This does not close Row 11. Runtime iOS share-sheet presentation remains a separate proof item.

## Changes

- `FinancialReportScreenV2.exportReportPdf()` now awaits `PdfService.generateFinancialReportPdf(...)` and shows localized `reportPdfExportError` in a `SnackBar` when the export throws.
- `PdfService` no longer caches `pw.ThemeData`; each export builds a fresh theme to avoid repeated-export state issues in PDF/font objects.
- Six-locale `reportPdfExportError` copy added and generated.

## Claude CLI Review

Claude CLI returned `IMPORTANT`, not `OK`, because the original runtime symptom can be a `printing` iOS no-op: the plugin may return success even if presentation does not happen. The review was accepted.

Adjustments made after review:

- The test was renamed to avoid claiming coverage of the iOS no-op.
- German copy was aligned back to informal voice.
- The initially proposed `sharePdf == false` error path was removed after final Claude review because it can represent a normal user cancellation.

## Proof

Commands run after the review adjustments:

```bash
cd apps/mobile
flutter test test/screens/advisor_banking_smoke_test.dart
flutter analyze lib/services/pdf_service.dart lib/screens/advisor/financial_report_screen_v2.dart test/screens/advisor_banking_smoke_test.dart
```

Results:

- `flutter test test/screens/advisor_banking_smoke_test.dart`: `44` tests passed.
- Targeted `flutter analyze`: `No issues found`.

Repository-level checks:

```bash
python3 tools/checks/arb_parity.py
python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb
python3 tools/checks/accent_lint_fr.py --file apps/mobile/test/screens/advisor_banking_smoke_test.dart
git diff --check
```

Results:

- ARB parity: `6` locales, `6875` keys each.
- French accent lint: no findings.
- `git diff --check`: no whitespace errors.
- MCP ComplianceGuard check on the new FR copy: clean.

## Open Limits

Keep Row 11 `PARTIAL`.

Still open:

- iOS runtime proof that tapping `/rapport` export presents a usable share sheet.
- If the `printing` plugin returns `true` while presentation is a no-op, this local catch cannot detect it.
- If the platform returns `false` for a normal user cancellation, MINT does not show the error SnackBar.
- Rendered PDF screenshot/text extraction and per-archetype content scoring remain open.
- VoiceOver/focus order for the export path remains open.
