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
    required this.title,
    required this.subtitle,
    required this.action,
    required this.legalRef,
  });

  final int number;
  final String emoji;
  final String title;
  final String subtitle;
  final String action;
  final String legalRef;
}

List<MortgageStep> _buildSteps(S l) => [
  MortgageStep(
    number: 1,
    emoji: '🧮',
    title: l.mortgageJourneyStep1Title,
    subtitle: l.mortgageJourneyStep1Subtitle,
    action: l.mortgageJourneyStep1Action,
    legalRef: l.mortgageJourneyStep1Legal,
  ),
  MortgageStep(
    number: 2,
    emoji: '💰',
    title: l.mortgageJourneyStep2Title,
    subtitle: l.mortgageJourneyStep2Subtitle,
    action: l.mortgageJourneyStep2Action,
    legalRef: l.mortgageJourneyStep2Legal,
  ),
  MortgageStep(
    number: 3,
    emoji: '📊',
    title: l.mortgageJourneyStep3Title,
    subtitle: l.mortgageJourneyStep3Subtitle,
    action: l.mortgageJourneyStep3Action,
    legalRef: l.mortgageJourneyStep3Legal,
  ),
  MortgageStep(
    number: 4,
    emoji: '📉',
    title: l.mortgageJourneyStep4Title,
    subtitle: l.mortgageJourneyStep4Subtitle,
    action: l.mortgageJourneyStep4Action,
    legalRef: l.mortgageJourneyStep4Legal,
  ),
  MortgageStep(
    number: 5,
    emoji: '🏠',
    title: l.mortgageJourneyStep5Title,
    subtitle: l.mortgageJourneyStep5Subtitle,
    action: l.mortgageJourneyStep5Action,
    legalRef: l.mortgageJourneyStep5Legal,
  ),
  MortgageStep(
    number: 6,
    emoji: '⚖️',
    title: l.mortgageJourneyStep6Title,
    subtitle: l.mortgageJourneyStep6Subtitle,
    action: l.mortgageJourneyStep6Action,
    legalRef: l.mortgageJourneyStep6Legal,
  ),
  MortgageStep(
    number: 7,
    emoji: '📋',
    title: l.mortgageJourneyStep7Title,
    subtitle: l.mortgageJourneyStep7Subtitle,
    action: l.mortgageJourneyStep7Action,
    legalRef: l.mortgageJourneyStep7Legal,
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
    _activeStep = widget.currentStep.clamp(0, 6);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _steps = _buildSteps(S.of(context)!);
    _activeStep = _activeStep.clamp(0, _steps.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: S.of(context)!.mortgageJourneySemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepper(),
                  const SizedBox(height: 20),
                  _buildActiveStepDetail(),
                  const SizedBox(height: 16),
                  _buildNavigation(),
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

  Widget _buildHeader() {
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
                  S.of(context)!.mortgageJourneyTitle,
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
                  S.of(context)!.mortgageJourneyStepCounter(_activeStep + 1, _steps.length),
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
            S.of(context)!.mortgageJourneySubtitle,
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
                    S.of(context)!.mortgageJourneyStepLabel(step.number, step.title),
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
              step.subtitle,
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
                      step.action,
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
              '📖 ${step.legalRef}',
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

  Widget _buildNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_activeStep > 0)
          TextButton.icon(
            onPressed: () => setState(() => _activeStep--),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(S.of(context)!.mortgageJourneyPrevious),
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
            icon: Text(S.of(context)!.mortgageJourneyNextStep),
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
              '✅ ${S.of(context)!.mortgageJourneyComplete}',
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

  Widget _buildDisclaimer() {
    return Text(
      S.of(context)!.mortgageJourneyDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
