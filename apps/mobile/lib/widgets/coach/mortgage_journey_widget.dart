import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P3-E  Parcours fléché immobilier — 7 étapes narratives
//  Charte : L3 (3 niveaux) + L5 (1 action par étape)
//  Source : FINMA/ASB (5% tragbarkeit), LPP art. 30c (EPL)
//          CC art. 652 (propriété), LIFD art. 21 (valeur locative)
// ────────────────────────────────────────────────────────────

/// Represents one step of the mortgage journey.
class MortgageStep {
  const MortgageStep({
    required this.number,
    required this.emoji,
    required this.titleKey,
    required this.subtitleKey,
    required this.actionKey,
    required this.legalRef,
  });

  final int number;
  final String emoji;
  final String Function(S) titleKey;
  final String Function(S) subtitleKey;
  final String Function(S) actionKey;
  final String legalRef;
}

List<MortgageStep> _buildSteps() => [
  MortgageStep(
    number: 1,
    emoji: '\u{1F9EE}',
    titleKey: (s) => s.mortgageStep1Title,
    subtitleKey: (s) => s.mortgageStep1Subtitle,
    actionKey: (s) => s.mortgageStep1Action,
    legalRef: 'FINMA/ASB — taux th\u00e9orique 5%',
  ),
  MortgageStep(
    number: 2,
    emoji: '\u{1F4B0}',
    titleKey: (s) => s.mortgageStep2Title,
    subtitleKey: (s) => s.mortgageStep2Subtitle,
    actionKey: (s) => s.mortgageStep2Action,
    legalRef: 'LPP art. 30c (EPL) — OPP2 art. 5 (min CHF 20\'000)',
  ),
  MortgageStep(
    number: 3,
    emoji: '\u{1F4CA}',
    titleKey: (s) => s.mortgageStep3Title,
    subtitleKey: (s) => s.mortgageStep3Subtitle,
    actionKey: (s) => s.mortgageStep3Action,
    legalRef: 'FINMA — Circular 2008/10 (standards hypoth\u00e9caires)',
  ),
  MortgageStep(
    number: 4,
    emoji: '\u{1F4C9}',
    titleKey: (s) => s.mortgageStep4Title,
    subtitleKey: (s) => s.mortgageStep4Subtitle,
    actionKey: (s) => s.mortgageStep4Action,
    legalRef: 'LIFD art. 33 al. 1 let. a (d\u00e9duction int\u00e9r\u00eats)',
  ),
  MortgageStep(
    number: 5,
    emoji: '\u{1F3E0}',
    titleKey: (s) => s.mortgageStep5Title,
    subtitleKey: (s) => s.mortgageStep5Subtitle,
    actionKey: (s) => s.mortgageStep5Action,
    legalRef: 'LIFD art. 21 al. 1 let. b (valeur locative)',
  ),
  MortgageStep(
    number: 6,
    emoji: '\u2696\uFE0F',
    titleKey: (s) => s.mortgageStep6Title,
    subtitleKey: (s) => s.mortgageStep6Subtitle,
    actionKey: (s) => s.mortgageStep6Action,
    legalRef: 'CO art. 261ss (bail \u00e0 loyer)',
  ),
  MortgageStep(
    number: 7,
    emoji: '\u{1F4CB}',
    titleKey: (s) => s.mortgageStep7Title,
    subtitleKey: (s) => s.mortgageStep7Subtitle,
    actionKey: (s) => s.mortgageStep7Action,
    legalRef: 'CC art. 652 (propri\u00e9t\u00e9 par \u00e9tages)',
  ),
];

class MortgageJourneyWidget extends StatefulWidget {
  const MortgageJourneyWidget({
    super.key,
    this.currentStep = 0,
  });

  /// 0-indexed step the user is currently at (0-6).
  final int currentStep;

  @override
  State<MortgageJourneyWidget> createState() => _MortgageJourneyWidgetState();
}

class _MortgageJourneyWidgetState extends State<MortgageJourneyWidget> {
  late int _activeStep;
  late List<MortgageStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps();
    _activeStep = widget.currentStep.clamp(0, _steps.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Semantics(
      label: 'Parcours fléché achat immobilier 7 étapes hypothèque fonds propres FINMA LPP',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepper(),
                  const SizedBox(height: 20),
                  _buildActiveStepDetail(),
                  const SizedBox(height: 16),
                  _buildNavigation(s),
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.mortgageJourneyTitle,
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_activeStep + 1} / ${_steps.length}',
                  style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.mortgageJourneySubtitle,
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: List.generate(_steps.length, (i) {
        final isDone = i < _activeStep;
        final isActive = i == _activeStep;

        return Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _activeStep = i),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? MintColors.primary
                        : isActive
                            ? MintColors.white
                            : MintColors.lightBorder.withValues(alpha: 0.4),
                    border: isActive
                        ? Border.all(color: MintColors.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: MintColors.white)
                        : Text(
                            '${i + 1}',
                            style: MintTextStyles.labelSmall(color: isActive ? MintColors.primary : MintColors.textSecondary).copyWith(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ),
              if (i < _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < _activeStep
                        ? MintColors.primary
                        : MintColors.lightBorder.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActiveStepDetail() {
    final step = _steps[_activeStep];
    final s = S.of(context)!;
    final title = step.titleKey(s);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(_activeStep),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: MintColors.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(step.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.mortgageJourneyStepLabel(step.number, title),
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.subtitleKey(s),
              style: MintTextStyles.labelMedium(color: MintColors.textPrimary).copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: MintColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      step.actionKey(s),
                      style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\u{1F4D6} ${step.legalRef}',
              style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(S s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_activeStep > 0)
          TextButton.icon(
            onPressed: () => setState(() => _activeStep--),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(s.mortgageJourneyPrevious),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.textSecondary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          )
        else
          const SizedBox.shrink(),
        if (_activeStep < _steps.length - 1)
          ElevatedButton.icon(
            onPressed: () => setState(() => _activeStep++),
            icon: Text(s.mortgageJourneyNextStep),
            label: const Icon(Icons.arrow_forward_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: MintTextStyles.labelMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.scoreExcellent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              s.mortgageJourneyComplete,
              style: MintTextStyles.labelMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      S.of(context)!.mortgageJourneyDisclaimer,
      style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
    );
  }
}
