# Phase 72 — `_EclairageCard` widget render — Panel Verdict

> **Date :** 2026-05-05
> **Panel :** 3-pers (UX Cleo-school + a11y/VoiceOver + adversarial)
> **Verdict :** APPROVE-WITH-CHANGES — locked for implementation.

## 1. Card layout (top-to-bottom)

- **Container :** width = full chat row (`MediaQuery.size.width - 32`, NOT bubble-constrained 78%) — l'éclairage casse le rythme bubble pour signaler l'inflexion.
- **BG :** `MintColors.craieHandoff` (même surface coach, pas de contraste agressif)
- **Border :** 1px `MintColors.borderSubtle`, `BorderRadius.circular(16)`, **NO shadow** (Cleo-grade = no gloss)
- **Padding :** intérieur 20h / 18v
- **Margin :** top 8 / bottom 16 (sépare visuellement de la coach bubble qui l'a triggered)
- **Left accent :** 3px `MintColors.mintForest` vertical bar, full height, inset 0 — « special-but-not-shouting » signal
- **Internal sections :** 12dp vertical spacing, NO divider lines

**Sections in order :**
1. **Eyebrow** « Premier éclairage » — Inter 11pt w600 uppercase letterSpacing 1.2, `MintColors.mintForest`, marginBottom 6
2. **Headline** — `GoogleFonts.fraunces(fontSize: 18, fontWeight: w500, height: 1.3, color: inkPrimary)`, **italic OFF**
3. **CHF range visual** (see §2)
4. **Body** — Inter 14pt w400 height 1.5, `MintColors.inkPrimary`
5. **softAccountHint link** (see §3)
6. ~~disclaimer~~ — SKIP (already above input per Phase 71a §1.4)

## 2. CHF range visual

Inline mid-card, own row above body :

`[CHF badge] 1'500 – 2'500 / an`

- « CHF » : `MintColors.mintForest` Inter 12pt w600, 4px right padding (small badge)
- Numbers : `GoogleFonts.montserrat(fontSize: 28, fontWeight: w700, color: inkPrimary, letterSpacing: -0.3)` (matches `MintTextStyles.displaySmall`)
- En-dash `–` (U+2013), 6dp horizontal padding
- « / an » suffix : Inter 13pt w500 `textSecondaryAaa`
- **Format Suisse :** apostrophe thousand separator (`1'500`, not `1,500` / `1 500`)

**Null fallbacks (LOCKED) :**
- `low==null && high!=null` → `« jusqu'à CHF 2'500 / an »` (montserrat 28 for number, « jusqu'à » prefix Inter 13 textSecondaryAaa)
- `high==null && low!=null` → `« dès CHF 1'500 / an »`
- `low==null && high==null` → **omit range row entirely**, body + headline still render
- `period != "year"` → defensive : render « / an » regardless

**Symbol :** « CHF » (not « francs ») — matches DESIGN_SYSTEM + i18n-safe.

## 3. softAccountHint behavior

- Full-width tap row, marginTop 14, **min-height 44dp** (a11y)
- Padding 12v / 0h
- Visual : `MintColors.mintForest` text Inter 14 w600 + trailing `Icons.arrow_forward_rounded` 16dp same color, gap 6dp
- **NOT underlined**, **NOT button-styled** — Cleo « inline pull », not CTA primary
- Tap : `context.push('/auth/register?redirect=/anonymous/chat')` — `push` not `go` (preserve return path with conversation intact)
- `HapticFeedback.selectionClick()` on tap
- Wrapped in `InkWell` with `BorderRadius.circular(8)` for ripple feedback
- Empty/null hint → **omit row entirely**

## 4. a11y semantics order

```dart
Semantics(
  container: true,
  label: '$eyebrow. $headline. $rangeReadable. $body.',
  button: false,
  child: ...
)
```

Then **separate** :
```dart
Semantics(
  button: true,
  label: softAccountHint,
  hint: 'Crée un compte',
  child: InkWell(...)
)
```

`rangeReadable` formats as « entre 1500 et 2500 francs par an » (VoiceOver reads numbers cleanly ; apostrophe thousand-sep = read as garbage).

Disclaimer **NOT** in card semantics (read separately by VoiceOver above input).

## 5. Adversarial mitigations

| # | Pattern | Mitigation |
|---|---|---|
| 1 | Body 240 chars on iPhone SE 375px | NO truncation, NO scroll. Card grows vertically, parent ListView scrolls. NO maxLines, NO ellipsis. |
| 2 | chfRangeLow / chfRangeHigh null | Graceful fallbacks per §2. Never crash. |
| 3 | headline empty OR body empty | `if (headline.trim().isEmpty \|\| body.trim().isEmpty) return SizedBox.shrink();` |
| 4 | Duplicate disclaimer | SKIPPED in card (Phase 71a §1.4 above-input is single source). |
| 5 | Card rendered twice if backend re-emits | `_eclairageDelivered` guard already in `_AnonymousChatScreenState` Phase 71a line 243. |

## 6. Tests required (5)

1. **Golden** `eclairage_card_full.png` — full payload (fr_CH, headline+range+body+hint), iPhone 13 width
2. **Golden** `eclairage_card_no_range.png` — `chfRangeLow=null, chfRangeHigh=null` → range row absent
3. **Widget** tapping softAccountHint pushes `/auth/register?redirect=/anonymous/chat`
4. **Widget** body 240-char doesn't overflow (no `RenderFlex overflow` exception)
5. **Widget** empty headline OR empty body → `SizedBox.shrink()`

## 7. Decisions LOCKED

1. Headline = Fraunces 18pt w500 **NON-italic**
2. CHF range = montserrat 28pt w700 own row, apostrophe thousand-sep, en-dash separator
3. 3px `mintForest` left-stroke ribbon (no shadow, no BG tint, single line of forest green)
4. softAccountHint = inline pull row + arrow icon, NOT button-styled, NOT underlined, `context.push` (preserves return path)
5. Disclaimer NOT duplicated in card
6. Card width = full chat row (breaks 78% bubble constraint intentionally)
7. Card never renders if `headline.trim().isEmpty || body.trim().isEmpty`

---

**Panel verdict :** ship.
