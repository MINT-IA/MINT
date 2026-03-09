/// Shared widgets for educational coach screens (65+).
///
/// Used by: OptimisationDecaissementScreen, SuccessionPatrimoineScreen.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ── Disclaimer palette (amber/brown — intentionally distinct from MintColors) ──
const _kDisclaimerBg = Color(0xFFFFF8E1);
const _kDisclaimerBorder = Color(0xFFFFE082);
const _kDisclaimerIcon = Color(0xFFF57F17);
const _kDisclaimerText = Color(0xFF5D4037);

/// Section title — Montserrat 15 bold.
class EduSectionTitle extends StatelessWidget {
  final String text;
  const EduSectionTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: MintColors.textPrimary,
      ),
    );
  }
}

/// LSFin disclaimer banner (amber background, info icon).
class EduDisclaimer extends StatelessWidget {
  final String text;
  const EduDisclaimer({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kDisclaimerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kDisclaimerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: _kDisclaimerIcon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _kDisclaimerText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Legal sources block — parameterized content, shared visual style.
///
/// [sources] : multi-line string, one `• …` bullet per line.
class EduLegalSources extends StatelessWidget {
  final String sources;
  const EduLegalSources({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sources légales',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sources,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Specialist CTA card — parameterized icon, color, title, body.
class EduSpecialistCta extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const EduSpecialistCta({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
