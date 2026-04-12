/// Shared widgets for educational coach screens (65+).
///
/// Used by: OptimisationDecaissementScreen, SuccessionPatrimoineScreen.
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ── Disclaimer palette (amber/brown — intentionally distinct from MintColors) ──
const _kDisclaimerBg = MintColors.disclaimerBg;
const _kDisclaimerBorder = MintColors.yellowGold;
const _kDisclaimerIcon = MintColors.warningText;
const _kDisclaimerText = MintColors.brownWarm;

/// Section title — Montserrat 15 bold.
class EduSectionTitle extends StatelessWidget {
  final String text;
  const EduSectionTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MintTextStyles.labelLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
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
              style: MintTextStyles.labelSmall(color: _kDisclaimerText).copyWith(height: 1.5),
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
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            sources,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.5),
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
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
