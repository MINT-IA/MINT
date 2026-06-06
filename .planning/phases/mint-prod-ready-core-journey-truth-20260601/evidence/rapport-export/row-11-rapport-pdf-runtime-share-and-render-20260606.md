# Row 11 Rapport PDF Runtime Share And Render — 2026-06-06

## Scope

CJT-057 adds runtime iOS proof for the `/rapport` PDF export path after CJT-054, CJT-055, and CJT-056.

This proof covers:

- the visible `/rapport` export action on iPhone 17 Pro simulator;
- native iOS share-sheet presentation for `mint_report_v2.pdf`;
- generated PDF bytes copied from the simulator app container;
- extracted PDF text;
- a rendered QuickLook thumbnail of page 1.

Row 11 remains `PARTIAL`: VoiceOver/focus traversal, full content scoring, and per-archetype PDF quality review are still open.

## Runtime

- Branch: `qa/runtime-navigation-spine-20260602`
- Commit under test: `e97072311 Handle rapport PDF export failures`
- Simulator: iPhone 17 Pro `B03E429D-0422-4357-B754-536637D979F9`
- Automation note: this was not a Maestro flow; the native iOS share sheet is an OS surface that `snapshot_ui` did not expose as tappable AX targets, so the proof uses `xcrun simctl`, `xcodebuildmcp` tap/snapshot, screenshots, logs, and extracted artifacts.
- Build:

```bash
cd apps/mobile
flutter build ios --simulator --debug --dart-define=MINT_DISABLE_BETA_MODAL=true
xcrun simctl install B03E429D-0422-4357-B754-536637D979F9 build/ios/iphonesimulator/Runner.app
xcrun simctl launch B03E429D-0422-4357-B754-536637D979F9 ch.mint.app
xcrun simctl openurl B03E429D-0422-4357-B754-536637D979F9 mintapp:///rapport
```

## Evidence Folder

`evidence/maestro-ci/row-11-rapport-pdf-share-runtime-20260606T144622/`

Artifacts:

- `before-export.png` — `/rapport` before tapping export.
- `after-export-tap.png` — iOS share sheet visible after tapping export.
- `mint_report_v2.pdf` — copied from the simulator app container.
- `mint_report_v2.txt` — extracted with `pdftotext`.
- `mint_report_v2.pdf.png` — page 1 rendered with `qlmanage`.
- `share-sheet-log-excerpt.txt` — filtered iOS share-sheet logs.

## Runtime UI Proof

`xcodebuildmcp.snapshot_ui` exposed the target:

```text
button|Exporter le bilan en PDF
```

After tapping that target, the simulator screenshot shows the iOS share sheet with:

```text
mint_report_v2
PDF Document · 37 KB
Preview
More
Copier
Annoter
Imprimer
Save to Files
```

The filtered iOS logs also show the native share sheet lifecycle:

```text
UIActivityViewController: initialized with activityItems (.../tmp/mint_report_v2.pdf)
Share sheet is being presented
Add activities: Copier, AirDrop, Annoter, Imprimer
UIAVC: ready to interact
UIAVC: view did appear
```

## PDF Text Proof

`pdftotext` extracted the generated report. Key excerpts:

```text
Ton Bilan Flash - Export financier
Bilan personnalisé pour toi - ZH
Score de santé financière : 42/100 - À améliorer

PISTES À EXAMINER

1. Constitue ton fonds d'urgence
Contexte : Vise 3 mois de charges sur un compte épargne séparé.

2. Évaluer l’intérêt d’un 3a
Contexte : Marge déductible et impact fiscal estimés selon ton revenu, ton canton et ton statut LPP.

CADRE ÉDUCATIF ET LIMITES
Outil éducatif - MINT - ne constitue pas un conseil financier au sens de la LSFin
```

## Rendered PDF Proof

`qlmanage -t -s 1200` generated `mint_report_v2.pdf.png`.

The page 1 thumbnail is readable and shows:

- title `Ton Bilan Flash - Export financier`;
- key indicators;
- guidance-language section `PISTES À EXAMINER`;
- action titles framed as guidance/evaluation, not advice;
- fiscal simulation block;
- footer disclaimer.

Visual note: page 1 shows a pale blue rectangle under `CADRE ÉDUCATIF ET LIMITES`; keep this as a Row 23/PDF visual-quality follow-up rather than closing PDF design quality completely.

## Open Limits

Keep Row 11 `PARTIAL`.

Still open:

- VoiceOver/focus traversal for the export action and share-sheet interaction.
- Full PDF page-by-page visual QA.
- Per-archetype PDF content scoring and Swiss-financial-guidance rubric.
- Decide whether to harden the upstream `printing` iOS `keyWindow` presentation path or accept the current runtime proof as sufficient regression evidence.
- As in CJT-056, `sharePdf == false` is not treated as an export error because it may represent user cancellation.
