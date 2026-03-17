import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

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
    required this.legalRefKey,
  });

  final int number;
  final String emoji;
  final String Function(S) titleKey;
  final String Function(S) subtitleKey;
  final String Function(S) actionKey;
  final String Function(S) legalRefKey;
}

List<MortgageStep> _buildSteps() => [
  MortgageStep(
    number: 1,
    emoji: '🧮',
    titleKey: (s) => s.coachMortgageStep1Title,
    subtitleKey: (s) => s.coachMortgageStep1Subtitle,
    actionKey: (s) => s.coachMortgageStep1Action,
    legalRefKey: (s) => s.coachMortgageStep1Ref,
  ),
  MortgageStep(
    number: 2,
    emoji: '💰',
    titleKey: (s) => s.coachMortgageStep2Title,
    subtitleKey: (s) => s.coachMortgageStep2Subtitle,
    actionKey: (s) => s.coachMortgageStep2Action,
    legalRefKey: (s) => s.coachMortgageStep2Ref,
  ),
  MortgageStep(
    number: 3,
    emoji: '📊',
    titleKey: (s) => s.coachMortgageStep3Title,
    subtitleKey: (s) => s.coachMortgageStep3Subtitle,
    actionKey: (s) => s.coachMortgageStep3Action,
    legalRefKey: (s) => s.coachMortgageStep3Ref,
  ),
  MortgageStep(
    number: 4,
    emoji: '📉',
    titleKey: (s) => s.coachMortgageStep4Title,
    subtitleKey: (s) => s.coachMortgageStep4Subtitle,
    actionKey: (s) => s.coachMortgageStep4Action,
    legalRefKey: (s) => s.coachMortgageStep4Ref,
  ),
  MortgageStep(
    number: 5,
    emoji: '🏠',
    titleKey: (s) => s.coachMortgageStep5Title,
    subtitleKey: (s) => s.coachMortgageStep5Subtitle,
    actionKey: (s) => s.coachMortgageStep5Action,
    legalRefKey: (s) => s.coachMortgageStep5Ref,
  ),
  MortgageStep(
    number: 6,
    emoji: '⚖️',
    titleKey: (s) => s.coachMortgageStep6Title,
    subtitleKey: (s) => s.coachMortgageStep6Subtitle,
    actionKey: (s) => s.coachMortgageStep6Action,
    legalRefKey: (s) => s.coachMortgageStep6Ref,
  ),
  MortgageStep(
    number: 7,
    emoji: '📋',
    titleKey: (s) => s.coachMortgageStep7Title,
    subtitleKey: (s) => s.coachMortgageStep7Subtitle,
    actionKey: (s) => s.coachMortgageStep7Action,
    legalRefKey: (s) => s.coachMortgageStep7Ref,
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

  @override
  void initState() {
    super.initState();
    _activeStep = widget.currentStep.clamp(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final steps = _buildSteps();

    return Semantics(
      label: s.coachMortgageSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s, steps),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepper(steps),
                  const SizedBox(height: 20),
                  _buildActiveStepDetail(s, steps),
                  const SizedBox(height: 16),
                  _buildNavigation(s, steps),
                  const SizedBox(height: 16),
                  _buildDisclaimer(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s, List<MortgageStep> steps) {
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
                  s.coachMortgageTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
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
                  s.coachMortgageStepCounter(_activeStep + 1, steps.length),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: MintColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.coachMortgageSubtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(List<MortgageStep> steps) {
    return Row(
      children: List.generate(steps.length, (i) {
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
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isActive
                                  ? MintColors.primary
                                  : MintColors.textSecondary,
                            ),
                          ),
                  ),
                ),
              ),
              if (i < steps.length - 1)
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

  Widget _buildActiveStepDetail(S s, List<MortgageStep> steps) {
    final step = steps[_activeStep];

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
                    s.coachMortgageStepLabel(step.number, step.titleKey(s)),
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.subtitleKey(s),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textPrimary,
                height: 1.5,
              ),
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
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MintColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '📖 ${step.legalRefKey(s)}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(S s, List<MortgageStep> steps) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_activeStep > 0)
          TextButton.icon(
            onPressed: () => setState(() => _activeStep--),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(s.coachMortgagePrevious),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.textSecondary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          )
        else
          const SizedBox.shrink(),
        if (_activeStep < steps.length - 1)
          ElevatedButton.icon(
            onPressed: () => setState(() => _activeStep++),
            icon: Text(s.coachMortgageNextStep),
            label: const Icon(Icons.arrow_forward_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
              '✅ ${s.coachMortgageComplete}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: MintColors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(
      s.coachMortgageDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
