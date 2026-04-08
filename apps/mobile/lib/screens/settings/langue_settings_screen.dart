import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/locale_helper.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Language selection screen — lets the user switch the app locale.
///
/// Lists the 6 supported languages from [MintLocales.supportedLocales].
/// The current locale is highlighted with a check icon.
/// Tapping a language calls [LocaleProvider.setLocale] and shows a SnackBar.
class LangueSettingsScreen extends StatelessWidget {
  const LangueSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final currentLocale = context.watch<LocaleProvider>().locale;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          s.langueScreenTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(MintSpacing.lg),
        itemCount: MintLocales.supportedLocales.length,
        separatorBuilder: (_, __) => const SizedBox(height: MintSpacing.sm),
        itemBuilder: (context, index) {
          final locale = MintLocales.supportedLocales[index];
          final code = locale.languageCode;
          final isSelected = code == currentLocale.languageCode;

          return MintSurface(
            tone: MintSurfaceTone.blanc,
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _onTapLocale(context, locale, s),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.md,
                  vertical: MintSpacing.md,
                ),
                child: Row(
                  children: [
                    Text(
                      MintLocales.flagOf(code),
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: MintSpacing.md),
                    Expanded(
                      child: Text(
                        MintLocales.nameOf(code),
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: MintColors.primary,
                        size: 22,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onTapLocale(BuildContext context, Locale locale, S s) {
    final code = locale.languageCode;
    context.read<LocaleProvider>().setLocale(locale);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.langueScreenChanged(MintLocales.nameOf(code))),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
