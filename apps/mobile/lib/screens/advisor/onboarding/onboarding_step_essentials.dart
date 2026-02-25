import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/data/cantonal_data.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/onboarding/onboarding_widgets.dart';

class OnboardingStepEssentials extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController birthYearController;
  final VoidCallback onContinue;

  const OnboardingStepEssentials({
    super.key,
    required this.firstNameController,
    required this.birthYearController,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final provider = context.watch<OnboardingProvider>();
    final canton = provider.canton;

    // Compute birth year error from provider state
    final birthYearError = _computeBirthYearError(provider, l10n);

    final sortedCantons = CantonalDataService.cantons.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));
    final canContinue = birthYearError == null &&
        birthYearController.text.length == 4 &&
        canton != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingStepHeader(
            title: l10n?.advisorMiniStep2Title ?? 'Ton profil',
            subtitle: l10n?.advisorMiniStep2Subtitle ??
                'Age et canton changent tout en Suisse',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: firstNameController,
            textCapitalization: TextCapitalization.words,
            onChanged: provider.setFirstNameDraft,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              labelText: l10n?.advisorMiniFirstNameLabel ?? 'Prénom (optionnel)',
              hintText: l10n?.advisorMiniFirstNameHint ?? 'Prénom',
              filled: true,
              fillColor: MintColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: birthYearController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onChanged: (value) => provider.setBirthYearDraft(value),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              labelText:
                  l10n?.advisorMiniBirthYearLabel ?? 'Année de naissance',
              hintText: '1990',
              filled: true,
              fillColor: MintColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: MintColors.primary, width: 1.8),
              ),
            ),
          ),
          if (birthYearError != null) ...[
            const SizedBox(height: 6),
            Text(
              birthYearError,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: canton,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n?.advisorMiniCantonLabel ?? 'Canton de résidence',
              filled: true,
              fillColor: MintColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: MintColors.primary, width: 1.8),
              ),
            ),
            items: sortedCantons
                .map(
                  (entry) => DropdownMenuItem<String>(
                    initialValue: entry.key,
                    child: Text('${entry.value.name} (${entry.key})'),
                  ),
                )
                .toList(),
            onChanged: (value) => provider.setCanton(value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: provider.residencePermit,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Permis de séjour',
              filled: true,
              fillColor: MintColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: MintColors.primary, width: 1.8),
              ),
            ),
            items: const [
              DropdownMenuItem(initialValue: 'swiss', child: Text('Nationalité suisse')),
              DropdownMenuItem(initialValue: 'permit_c', child: Text('Permis C (établissement)')),
              DropdownMenuItem(initialValue: 'permit_b', child: Text('Permis B (séjour)')),
              DropdownMenuItem(initialValue: 'permit_g', child: Text('Permis G (frontalier)')),
            ],
            onChanged: (value) => provider.setResidencePermit(value),
          ),
          const SizedBox(height: 24),
          OnboardingContinueButton(
            enabled: canContinue,
            label: l10n?.onboardingContinue ?? 'Suivant',
            onPressed: onContinue,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String? _computeBirthYearError(OnboardingProvider provider, S? l10n) {
    final text = birthYearController.text;
    if (text.length != 4) return null;
    final year = int.tryParse(text);
    if (year == null) {
      return l10n?.advisorMiniBirthYearInvalid ?? 'Année invalide';
    }
    final maxYear = DateTime.now().year - 16;
    if (year < 1940 || year > maxYear) {
      return l10n?.advisorMiniBirthYearRange('$maxYear') ??
          'Entre 1940 et $maxYear';
    }
    return null;
  }
}
