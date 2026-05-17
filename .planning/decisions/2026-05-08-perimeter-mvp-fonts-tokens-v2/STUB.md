---
name: MVP-FONTS-TOKENS-V2 — perimeter STUB
description: Foundation perimeter pour MINT v2 design system — install Supreme + Gambarino fonts, ajout MintColors.mentheVive token, Gambarino italic display style, dark palette tokens. Pré-requis bloquant pour MVP-ONBOARDING-V2-AUTH-FIRST + MVP-COACH-V2-ARTEFACTS + tous autres v2 perimeters. Effort 0.6j.
type: decision
date: 2026-05-08
status: STUB (à ouvrir post PR #529 merge)
related:
  - .planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md
sources:
  - MINT Design System.pdf (Julien shared 2026-05-08, identité verrouillée v2)
  - https://www.fontshare.com/ (Supreme + Gambarino, license Open Source commercial)
  - apps/mobile/lib/theme/{colors,mint_text_styles,mint_spacing}.dart (existing baseline)
---

# MVP-FONTS-TOKENS-V2 — STUB

## Goal

Installer la foundation visuelle MINT v2 dans le mobile codebase :
- Supreme (UI) — 400, 500, 600 weights
- Gambarino (display, italic) — 400 weight
- `MintColors.mentheVive` token (vert-cyan vif, ~`#7DD3B5` à pixel-sample du PDF)
- `MintTextStyles.displayGambarinoItalic` (variantes hero/headline/title)
- Palette dark mode (`MintColors.dark*`) — règle grammar #8

Bloque tous les autres v2 perimeters jusqu'à ce que ce STUB soit livré.

## 5 gates mécaniques

| Gate | Description | Évidence |
|---|---|---|
| G1 | sim screenshot landing avec Gambarino italic + Supreme rendered correctly | `xcrun simctl io booted screenshot /tmp/font_test.png` |
| G2 | device par Julien — Apple device font rendering OK (no fallback to Times) | TestFlight |
| G3 | dev CI green — flutter analyze + build iOS + size budget |
| G4 | regression tests — golden test landing + onboarding intact post-font-swap |
| G5 | LSFin/accent/ARB lint inchangé + Fontshare license file committed |

## Tâches (atomic commits recommendées)

| # | Action | Effort | Dépendance |
|---|---|---|---|
| F1.1 | Download Supreme `.otf` (400, 500, 600) depuis fontshare.com manuellement (Julien ou via WebFetch CDN) | 0.1j | None |
| F1.2 | Download Gambarino `.otf` (400 italic) | 0.05j | None |
| F1.3 | Add `apps/mobile/assets/fonts/Supreme-Regular.otf` + `Supreme-Medium.otf` + `Supreme-Semibold.otf` + `Gambarino-Regular.otf` (italic baked-in) | 0.05j | F1.1+F1.2 |
| F1.4 | Edit `apps/mobile/pubspec.yaml` `fonts:` block | 0.05j | F1.3 |
| F1.5 | Add Fontshare license texts to `apps/mobile/assets/fonts/LICENSE-SUPREME.txt` + `LICENSE-GAMBARINO.txt` | 0.05j | F1.1+F1.2 |
| F2.1 | Pixel-sample Menthe-vive hex sur PDF/canvas v2 (Julien fournit ou screenshot annoté) | 0.05j | None |
| F2.2 | Add `MintColors.mentheVive = Color(0xFF...)` + `mentheVive12 = Color(0x1F...)` (12% opacity surface) à `apps/mobile/lib/theme/colors.dart` | 0.05j | F2.1 |
| F3.1 | Add `MintTextStyles.displayGambarinoItalic56` (Landing hero — 56-72px italic) | 0.05j | F1.4 |
| F3.2 | Add `MintTextStyles.displayGambarinoItalic40` (Onboarding hero — 40-48px italic) | 0.05j | F1.4 |
| F3.3 | Add `MintTextStyles.titleSupreme18Semibold` + `bodySupreme15Regular` + `labelSupreme12Uppercase025LS` | 0.05j | F1.4 |
| F4.1 | Add dark palette : `MintColors.darkBg`, `darkInk`, `darkInkSoft`, `darkBorderSubtle`, `darkMentheVive` (saturé pour contrast) | 0.1j | None |
| F4.2 | `ThemeData.dark` factory in `app.dart` qui mappe les dark tokens | 0.1j | F4.1 |
| F5 | Sample landing screen using new Gambarino italic — visual proof gate | 0.1j | F1+F2+F3 |
| F6 | Update `colors_and_type.css` (handoff 2) pour matcher (mark MINT v2 superseding) | 0.05j | F1+F2 |
| F7 | Test goldens (existing) re-baseline post-font-swap (expected diff) | 0.1j | F5 |

**Total estimé** : 0.6 j (sans le pixel-sample manual + license verify si Julien doit faire ces 2 étapes — sinon 0.4j).

## Références

- MINT Design System.pdf (5 pages reçues 2026-05-08)
- Existing `apps/mobile/lib/theme/colors.dart` (baseline `MintColors`)
- Existing `apps/mobile/lib/theme/mint_text_styles.dart` (baseline `MintTextStyles`)
- Hand Off 2 `colors_and_type.css` (semi-superseded — voir SYNTHESIS addendum)

## Counter-arguments and data gaps

- **Risk 1** : Supreme + Gambarino license — bien que Fontshare dit « Open Source », vérifier le ToS exact pour app commerciale + republication. Julien doit valider si MINT publie sur App Store / Play Store sans risk juridique.
- **Risk 2** : Bundle size impact — 4 .otf files ≈ 200-400 KB cumulés. App size mobile +300 KB. Acceptable pour iOS (no limit) + Android (généralement OK), mais à benchmarker.
- **Risk 3** : Font rendering différence iOS vs Android — Supreme vendor metrics peuvent shift baseline 1-2px. À tester sur les 2 plateformes avant golden re-baseline.
- **Risk 4** : Goldens existants vont casser massivement post-font-swap. Re-baseline = 50-100 golden updates. Effort additionnel à budgétiser hors STUB initial.
- **Risk 5** : Pixel-sample manual du Menthe-vive est subjectif. Sans un Figma/Sketch token export, on devine. Mitigation : Julien valide le hex final post-implementation par comparaison visuelle.
- **Data gap** : Pas de mesure de bundle size baseline pre/post fonts. Mesurer avant push.

## Approval gate

À ouvrir comme PR séparée post-PR #529 merge. **Pas un sub-task de la hotfix bundle B1-B6.**
