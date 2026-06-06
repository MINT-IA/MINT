# Row 11/23 Rapport PDF Legal Frame Page Break — 2026-06-06

## Scope

CJT-058 fixes the visual PDF issue surfaced by CJT-057: page 1 showed a pale-blue empty rectangle under `CADRE ÉDUCATIF ET LIMITES` because the legal/compliance frame could split across the page boundary.

This is a PDF visual-quality fix only. Rows 11 and 23 remain `PARTIAL`.

## Change

- `apps/mobile/lib/services/pdf_service.dart`
  - Starts the financial report `Cadre éducatif et limites` section with `pw.NewPage()`.
  - Keeps the legal/compliance frame with its content instead of allowing a blank colored container fragment at the bottom of page 1.
- `apps/mobile/test/services/pdf_service_test.dart`
  - Adds a red/green guard proving the financial report educational frame starts after a `pw.NewPage()`.

## Red/Green Proof

Red proof before the fix:

```text
flutter test test/services/pdf_service_test.dart --name "financial report educational frame starts on a fresh page"
Expected: a value greater than or equal to <0>
Actual: <-1>
```

Green proof after the fix:

```text
flutter test test/services/pdf_service_test.dart --name "financial report educational frame starts on a fresh page"
00:00 +1: All tests passed!
```

Full PDF service proof:

```text
flutter test test/services/pdf_service_test.dart
00:00 +18: All tests passed!
```

## Runtime Visual Proof

Evidence folder:

`evidence/maestro-ci/row-11-pdf-legal-frame-pagebreak-20260606T150214/`

Artifacts:

- `before-export.png` — `/rapport` before export.
- `after-export-tap.png` — native iOS share sheet after tapping export.
- `mint_report_v2.pdf` — regenerated runtime PDF.
- `mint_report_v2.txt` — extracted PDF text.
- `mint_report_v2.pdf.png` — QuickLook page 1 render.
- `mint_report_v2-page-2.png` — `pdftoppm` page 2 render.

Runtime commands:

```bash
cd apps/mobile
flutter build ios --simulator --debug --no-codesign --dart-define=MINT_DISABLE_BETA_MODAL=true
xcrun simctl install B03E429D-0422-4357-B754-536637D979F9 build/ios/iphonesimulator/Runner.app
xcrun simctl launch B03E429D-0422-4357-B754-536637D979F9 ch.mint.app
xcrun simctl openurl B03E429D-0422-4357-B754-536637D979F9 mintapp:///rapport
```

`xcodebuildmcp.snapshot_ui` exposed the export target:

```text
button|Exporter le bilan en PDF
```

After tapping export, the regenerated PDF was copied from the simulator container, extracted with `pdftotext`, and rendered with `qlmanage` / `pdftoppm`.

Visual result:

- Page 1 now ends cleanly after `SIMULATION FISCALE` and the footer. It no longer shows `CADRE ÉDUCATIF ET LIMITES` or a blank pale-blue rectangle.
- Page 2 starts with `CADRE ÉDUCATIF ET LIMITES`, and the pale-blue frame contains the legal/compliance content.

`pdftotext` also confirms the page split:

```text
Page 1 sur 2

MINT - MENTORAT FINANCIER
RAPPORT FINANCIER - CONFIDENTIEL

CADRE ÉDUCATIF ET LIMITES

Nature du service : Éducation financière (non-régulée)
```

## Build Note

The normal simulator build hit the local macOS/Xcode metadata issue already present in this workspace:

```text
resource fork, Finder information, or similar detritus not allowed
```

For this runtime visual proof, the app was built with `--no-codesign`. That produced `build/ios/iphonesimulator/Runner.app`, which installed and launched on the iPhone 17 Pro simulator. No Xcode project change was made in this lot.

## Open Limits

Keep Row 11 `PARTIAL`.

Still open:

- VoiceOver/focus traversal for the export action and share-sheet interaction.
- Full per-page PDF visual QA across more data states.
- Per-archetype PDF content scoring and Swiss-financial-guidance rubric.
