import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/data/educational_themes.dart';
import 'package:mint_mobile/theme/colors.dart';

class ComprendreHubScreen extends StatelessWidget {
  const ComprendreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(
          S.of(context)!.eduHubTitle,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: MintColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: MintColors.background,
        elevation: 0,
        leading: const BackButton(color: MintColors.textPrimary),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: EducationData.themes.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                S.of(context)!.eduHubSubtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: MintColors.textMuted,
                  height: 1.5,
                ),
              ),
            );
          }
          final theme = EducationData.themes[index - 1].localized(S.of(context));
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: MintColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            S.of(context)!.eduHubReadQuiz,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MintColors.textMuted,
                            ),
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
