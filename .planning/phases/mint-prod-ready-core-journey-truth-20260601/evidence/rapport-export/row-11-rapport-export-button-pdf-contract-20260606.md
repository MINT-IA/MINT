# Row 11 - Rapport export button to PDF contract

Date: 2026-06-06

Status: local widget contract proof. Row 11 remains `PARTIAL`.

## Problem

Before this proof, Row 11 had:

- service-level proof that `PdfService.generateFinancialReportPdf()` can create
  a concrete PDF artifact;
- screen-level accessibility proof that `/rapport` exposes an export button
  labeled `Exporter le bilan en PDF`;
- no deterministic proof that tapping the visible `/rapport` export action
  actually calls the PDF export path and hands concrete bytes to `Printing`.

## Proof Added

`apps/mobile/test/screens/advisor_banking_smoke_test.dart` now includes:

```text
FinancialReportScreenV2 export action shares a concrete PDF document
```

The test installs a fake `PrintingPlatform`, renders
`FinancialReportScreenV2`, taps the semantic export action, waits for the async
PDF generation path, and asserts:

- `sharePdf` is called once;
- filename is `mint_report_v2.pdf`;
- bytes are present and larger than `1024`;
- bytes start with `%PDF-`.

This proves the local chain:

```text
/rapport export action -> FinancialReportScreenV2.exportReportPdf()
-> PdfService.generateFinancialReportPdf() -> Printing.sharePdf(...)
```

## Commands

```bash
cd apps/mobile
flutter test test/screens/advisor_banking_smoke_test.dart --plain-name "export action shares a concrete PDF document"
flutter test test/screens/advisor_banking_smoke_test.dart
flutter analyze test/screens/advisor_banking_smoke_test.dart
```

Results:

- focused export test: passed
- full advisor/open-banking smoke file: `43` tests passed
- targeted analyze: no issues

Additional local checks:

```bash
git diff --check
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/mint_quality_os_check.py
```

Results:

- diff check: clean
- CJT context guard: clean
- Quality OS check: clean

## Scope Limit

This does not close Row 11 because it is not a live simulator proof. Still open:

- iOS runtime tap on the actual app;
- share sheet or generated file evidence;
- rendered PDF screenshot/text extraction from a runtime-generated artifact;
- VoiceOver/focus order for the export/share flow;
- per-archetype report content scoring.
