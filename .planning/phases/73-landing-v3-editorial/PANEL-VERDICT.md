# Phase 73 — Landing v3 éditorial — Panel Verdict

> **Date :** 2026-05-05
> **Panel :** 2-pers (Brand strategist Apple/Linear + Swiss editorial Le Temps/NZZ)
> **Verdict :** APPROVE-WITH-NEW-LINE-D — locked for implementation.

## 1. Brand line LOCKED = option D (new)

**« Voir clair, décider seul. »**

A, B, C rejetées :
- A « L'argent, en clair. » + « Ta Suisse financière, traduite. » → « traduite » technocratic, sub-title duplique sans amplifier
- B « Ce que ta caisse de pension ne t'expliquera jamais. » → adversarial, journalist-bait, viole pivot 2026-04-12 retraite-frame
- C « La finance suisse, sans les angles morts. » → métaphore visuelle absente du produit, pan-locale fragile (« tote Winkel » DE = jargon routier)

D justifié : two verbs, two beats, hero-shaped. Voice = Linear/Stripe (verb-led pas feature-led). Pas de promesse de résultat, juste de capacité (LSFin-safe). Sobriété romande, traduit clean DE/IT/EN/ES/PT, autorité calme, zéro retraite-frame, 18-99 universel, tient sous scrutiny journaliste.

## 2. Hero strings × 6 locales (LOCKED)

| locale | hero |
|---|---|
| FR | Voir clair, décider seul. |
| EN | See clearly. Decide for yourself. |
| DE | Klar sehen. Selbst entscheiden. |
| IT | Vedere chiaro, decidere da sé. |
| ES | Ver claro, decidir por ti. |
| PT | Ver claro, decidir sozinho. |

ARB key = `landingV3Hero`. **Pas de sub-title** — la ligne porte tout.

## 3. Layout (top-to-bottom code-ready)

```
Scaffold BG = MintColors.warmWhite (#FAF8F5)
SafeArea + Center + ConstrainedBox(maxWidth: 480)  ← descendu de 560
Padding global : EdgeInsets.symmetric(horizontal: 28, vertical: 24)

Column children :
  1. Wordmark MINT — Align(centerLeft), MintTextStyles.brandLogo()
     override letterSpacing: 2 (pas 4), inkPrimary. Long-press → /auth/login
  2. Spacer(flex: 3)
  3. Hero phrase — l10n.landingV3Hero
     GoogleFonts.fraunces(fontSize: 40, fontStyle: italic, fontWeight: w400,
                          height: 1.2, letterSpacing: -0.4, color: inkPrimary)
     textAlign: center
  4. Spacer(flex: 4)
  5. CTA primaire — FilledButton
     backgroundColor: inkPrimary, foregroundColor: porcelaineHero
     minimumSize: Size.fromHeight(54)
     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
     ← PAS StadiumBorder (fix du mockup)
     textStyle: MintTextStyles.titleMedium(color: porcelaineHero)
  6. SizedBox(height: 16)
  7. Login link — l10n.landingV2LoginLink
     MintTextStyles.bodySmall(color: textSecondaryAaa), no underline
     tap → /auth/login. Semantics(button: true)
  8. Spacer(flex: 1)
  9. Legal footer — landingV2Legal
     MintTextStyles.labelSmall(color: textMutedAaa), center
  10. SizedBox(height: 8)
```

Animations existantes (line1 / paragraph / cta / legal opacity) conservées, re-câbler `_paragraphOpacity` sur le hero.

## 4. Decisions LOCKED

1. Brand line = D « Voir clair, décider seul. » (ne pas re-débattre)
2. **Pas de sub-title** — single line porte tout
3. Hero typo = **Fraunces italic 40pt w400**, `inkPrimary`. Italic ON.
4. CTA = `RoundedRectangleBorder(14)`, **PAS StadiumBorder**
5. BG = `MintColors.warmWhite` (landing-specific token, pas porcelaineHero)
6. Wordmark `letterSpacing: 2` (pas 4), `centerLeft`, `inkPrimary`. Long-press to `/auth/login` conservé.
7. maxWidth card = 480 (descendu de 560), padding horizontal = 28
8. Login link sans underline, `textSecondaryAaa`, 16px gap sous CTA
9. Deprecation plan : `landingV2PromiseSober` reste 1 release rollback-safety, retiré v2.11. `landingV2Paragraph` déjà mort, à purger.
10. Pre-push : `flutter gen-l10n` après ajout `landingV3Hero` × 6 ; `validate_arb_parity()` MCP ; `check_banned_terms("Voir clair, décider seul.")` (clean) ; golden tests Julien+Lauren regen.

---

**Panel verdict :** ship.
