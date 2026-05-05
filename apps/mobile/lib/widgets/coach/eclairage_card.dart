/// EclairageCard — anonymous-chat "Premier Éclairage" surface.
///
/// Phase 80 (v2.11): the deterministic card rendered in the anonymous chat
/// stream when the backend (Phase 81) emits an `eclairage` payload at
/// coach turn 2, OR when the `MINT_E2E_FORCE_ECLAIRAGE_KIND` dart-define
/// pins a kind for the walker / widget tests (ECLW-01..05).
///
/// LSFin compliance:
///   - Always shows a CHF range (low–high), never a single absolute number.
///   - Always renders the disclaimer line beneath the body.
///   - Uses `MintColors` tokens — no hardcoded colours.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/services/coach/eclairage_models.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Renders an [EclairageCardData] inline inside the anonymous chat stream.
class EclairageCard extends StatelessWidget {
  final EclairageCardData data;

  const EclairageCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final low = _formatChf(data.chfRangeLow);
    final high = _formatChf(data.chfRangeHigh);
    final periodLabel = _periodLabel(data.chfRangePeriod);

    return Semantics(
      container: true,
      label: 'Premier éclairage : ${data.headline}. '
          'Fourchette $low à $high $periodLabel.',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MintColors.lightBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eyebrow — uppercase tracked label, deterministic per kind so
            // walker visual diffs catch regressions.
            Text(
              _eyebrowFor(data.kind),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.warningAaa,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            // Headline
            Text(
              data.headline,
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: MintColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            // CHF range — Handoff 2 §6 « UN SEUL chiffre » respected by
            // showing one fourchette (low–high) on a single line, not two
            // competing hero numbers.
            RichText(
              text: TextSpan(
                style: GoogleFonts.fraunces(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: MintColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.0,
                ),
                children: [
                  TextSpan(text: low),
                  TextSpan(
                    text: ' – ',
                    style: GoogleFonts.fraunces(
                      fontSize: 24,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  TextSpan(text: high),
                  TextSpan(
                    text: '  $periodLabel',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Body
            Text(
              data.body,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.inkPrimary,
                height: 1.45,
              ),
            ),
            if (data.softAccountHint != null) ...[
              const SizedBox(height: 12),
              Text(
                data.softAccountHint!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // LSFin disclaimer — REQUIRED, always visible.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MintColors.warningAaa.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data.lsfinDisclaimer,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MintColors.textMuted,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Eyebrow copy keyed by kind. Deterministic so walker SSIM goldens stay
  /// stable across runs.
  static String _eyebrowFor(EclairageKind kind) {
    switch (kind) {
      case EclairageKind.fiscalMargin3a:
        return 'PREMIER ÉCLAIRAGE · 3E PILIER';
      case EclairageKind.lppRachatWindow:
        return 'PREMIER ÉCLAIRAGE · LPP';
      case EclairageKind.liquidityRunway:
        return 'PREMIER ÉCLAIRAGE · LIQUIDITÉ';
      case EclairageKind.compoundGrowthEdge:
        return 'PREMIER ÉCLAIRAGE · CAPITALISATION';
    }
  }

  static String _periodLabel(String period) {
    switch (period.toLowerCase()) {
      case 'year':
        return 'CHF/an';
      case 'month':
        return 'CHF/mois';
      case 'months':
        return 'mois';
      case 'lifetime':
        return 'CHF à 65 ans';
      default:
        return 'CHF';
    }
  }

  /// Format an integer-like CHF amount with French thousands separators
  /// (« 3 187 » not « 3,187 »). For sub-1000 values (e.g. liquidity months)
  /// we keep the raw number unformatted.
  static String _formatChf(double v) {
    if (v.abs() < 1000) {
      // Keep one decimal for liquidity-months style ranges; strip if integer.
      return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    }
    final str = v.round().abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}
