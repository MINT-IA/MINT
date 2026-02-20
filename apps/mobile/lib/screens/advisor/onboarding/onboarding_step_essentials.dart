import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mint_mobile/data/cantonal_data.dart';
import 'package:mint_mobile/widgets/onboarding/onboarding_widgets.dart';

class OnboardingStepEssentials extends StatelessWidget {
  final TextEditingController birthYearController;
  final String? canton;
  final String? birthYearError;
  final ValueChanged<String> onBirthYearChanged;
  final ValueChanged<String?> onCantonChanged;
  final VoidCallback onContinue;

  const OnboardingStepEssentials({
    super.key,
    required this.birthYearController,
    required this.canton,
    required this.birthYearError,
    required this.onBirthYearChanged,
    required this.onCantonChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
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
            title: l10n?.advisorMiniStep2Title ?? 'L\'essentiel',
            subtitle: l10n?.advisorMiniStep2Subtitle ??
                'Age et canton changent tout en Suisse',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: birthYearController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onChanged: onBirthYearChanged,
            decoration: InputDecoration(
              labelText:
                  l10n?.advisorMiniBirthYearLabel ?? 'Annee de naissance',
              hintText: '1990',
            ),
          ),
          if (birthYearError != null) ...[
            const SizedBox(height: 6),
            Text(
              birthYearError!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: canton,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n?.advisorMiniCantonLabel ?? 'Canton',
            ),
            items: sortedCantons
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text('${entry.value.name} (${entry.key})'),
                  ),
                )
                .toList(),
            onChanged: onCantonChanged,
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
}
