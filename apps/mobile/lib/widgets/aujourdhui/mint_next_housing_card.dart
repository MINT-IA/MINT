import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class MintNextHousingCard extends StatelessWidget {
  const MintNextHousingCard({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: FeatureFlags.mintNextHousingListenable,
        builder: (context, enabled, _) {
          if (!enabled) return const SizedBox.shrink();
          final l10n = S.of(context)!;
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              MintSpacing.md,
              0,
              MintSpacing.md,
              MintSpacing.md,
            ),
            child: Semantics(
              identifier: 'action:today.open_mint_next_housing',
              button: true,
              child: Material(
                color: MintColors.craie,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/mint-next/housing'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 72),
                    child: Padding(
                      padding: const EdgeInsets.all(MintSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.home_outlined,
                              color: MintColors.success),
                          const SizedBox(width: MintSpacing.md),
                          Expanded(
                            child: Text(
                              l10n.housingExplore,
                              style: MintTextStyles.titleMedium(
                                  color: MintColors.textPrimary),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
