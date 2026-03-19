import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/data/educational_themes.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class ComprendreHubScreen extends StatelessWidget {
  const ComprendreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(
          S.of(context)!.eduHubTitle,
          style: MintTextStyles.titleMedium(),
        ),
        centerTitle: false,
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: MintColors.textPrimary),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(MintSpacing.lg),
        itemCount: EducationData.themes.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.lg),
              child: Text(
                S.of(context)!.eduHubSubtitle,
                style: MintTextStyles.bodyLarge(color: MintColors.textMuted),
              ),
            );
          }
          final theme = EducationData.themes[index - 1].localized(S.of(context));
          return Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.md),
            child: _ThemeCard(theme: theme),
          );
        },
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final EducationalTheme theme;

  const _ThemeCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: theme.title,
      button: true,
      child: InkWell(
      onTap: () => context.push('/education/theme/${theme.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: MintColors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Color bar
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: theme.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(theme.icon, color: theme.color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            theme.title,
                            style: MintTextStyles.titleMedium(),
                          ),
                          const SizedBox(height: MintSpacing.xs),
                          Text(
                            S.of(context)!.eduHubReadQuiz,
                            style: MintTextStyles.labelSmall(),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: MintColors.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
