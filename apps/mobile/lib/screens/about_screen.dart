import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// About screen — displays app identity, version, legal links, and compliance
/// disclaimer.
///
/// All legal URLs are static public pages. Tapping opens them in the external
/// browser via [launchUrl].
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.0.0';

  static const _legalLinks = [
    _LegalLink(
      icon: Icons.description_outlined,
      labelKey: 'cgu',
      url: 'https://mint.swiss/cgu',
    ),
    _LegalLink(
      icon: Icons.lock_outline,
      labelKey: 'privacy',
      url: 'https://mint.swiss/privacy',
    ),
    _LegalLink(
      icon: Icons.info_outline,
      labelKey: 'disclaimer',
      url: 'https://mint.swiss/disclaimer',
    ),
    _LegalLink(
      icon: Icons.gavel_outlined,
      labelKey: 'mentionsLegales',
      url: 'https://mint.swiss/mentions-legales',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          s.aboutScreenTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // MINT identity area
            const SizedBox(height: MintSpacing.xl),
            Text(
              'MINT',
              textAlign: TextAlign.center,
              style: MintTextStyles.headlineLarge(
                color: MintColors.primary,
              ).copyWith(fontSize: 48, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              s.aboutScreenTagline,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodyMedium(
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              s.aboutScreenVersion(_version),
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.xl),

            // Legal links section
            MintSurface(
              tone: MintSurfaceTone.blanc,
              padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
              child: Column(
                children: [
                  for (int i = 0; i < _legalLinks.length; i++) ...[
                    _buildLegalTile(context, s, _legalLinks[i]),
                    if (i < _legalLinks.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.lg,
                        ),
                        child: Divider(
                          height: 1,
                          color: MintColors.textPrimary.withValues(alpha: 0.05),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MintSpacing.lg),

            // Compliance disclaimer
            Text(
              s.aboutScreenDisclaimerText,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalTile(BuildContext context, S s, _LegalLink link) {
    final label = switch (link.labelKey) {
      'cgu' => s.aboutScreenCgu,
      'privacy' => s.aboutScreenPrivacy,
      'disclaimer' => s.aboutScreenDisclaimer,
      'mentionsLegales' => s.aboutScreenMentionsLegales,
      _ => link.labelKey,
    };

    return InkWell(
      onTap: () => _launchUrl(link.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md,
          vertical: MintSpacing.md,
        ),
        child: Row(
          children: [
            Icon(link.icon, color: MintColors.textSecondary, size: 20),
            const SizedBox(width: MintSpacing.md),
            Expanded(
              child: Text(
                label,
                style: MintTextStyles.titleMedium(
                  color: MintColors.textPrimary,
                ).copyWith(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: MintColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _LegalLink {
  final IconData icon;
  final String labelKey;
  final String url;

  const _LegalLink({
    required this.icon,
    required this.labelKey,
    required this.url,
  });
}
