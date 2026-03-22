import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/locale_helper.dart';
import 'package:mint_mobile/theme/colors.dart';

/// A modal bottom-sheet that lets the user pick one of the supported languages.
///
/// Usage:
/// ```dart
/// final locale = await showLanguageSelector(context, currentLocale);
/// if (locale != null) { /* apply locale */ }
/// ```
Future<Locale?> showLanguageSelector(
  BuildContext context,
  Locale currentLocale,
) {
  return showModalBottomSheet<Locale>(
    context: context,
    backgroundColor: MintColors.transparent,
    isScrollControlled: true,
    builder: (_) => LanguageSelectorSheet(currentLocale: currentLocale),
  );
}

/// Internal bottom-sheet widget.
class LanguageSelectorSheet extends StatelessWidget {
  const LanguageSelectorSheet({super.key, required this.currentLocale});

  final Locale currentLocale;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MintColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 22, color: MintColors.textPrimary),
                  const SizedBox(width: 10),
                  Text(
                    'Langue / Sprache / Language',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Language list
            ...MintLocales.supportedLocales.map((locale) {
              final code = locale.languageCode;
              final isSelected = code == currentLocale.languageCode;
              return _LanguageTile(
                flag: MintLocales.flagOf(code),
                name: MintLocales.nameOf(code),
                isSelected: isSelected,
                onTap: () => context.pop(locale),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'interactive element',
      button: true,
      child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected ? MintColors.selectionBg : MintColors.transparent,
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: MintColors.textPrimary,
                    ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: MintColors.primary, size: 22),
          ],
        ),
      ),
    ),);
  }
}
