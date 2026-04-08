import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class MintEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const MintEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: MintColors.greyApple),
            const SizedBox(height: 16),
            Text(title,
                style: MintTextStyles.headlineMedium(),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary),
                textAlign: TextAlign.center),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: ctaLabel,
                child: FilledButton.icon(
                  onPressed: onCta,
                  icon: const Icon(Icons.add),
                  label: Text(ctaLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
