import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/analytics_events.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Step 3 of the Smart Onboarding flow — JIT (Just-In-Time) Explanation.
///
/// Shows a mini-explanation in SI...ALORS format, contextual to the
/// chiffre choc type displayed on the previous step.
///
/// Design: Material 3, Montserrat headings, Inter body, MintColors.
/// Compliance: educational tone, no banned terms, French informal "tu".
class StepJitExplanation extends StatefulWidget {
  final ChiffreChoc? chiffreChoc;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepJitExplanation({
    super.key,
    required this.chiffreChoc,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepJitExplanation> createState() => _StepJitExplanationState();
}

class _StepJitExplanationState extends State<StepJitExplanation> {
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _trackView();
  }

  void _trackView() {
    if (_tracked) return;
    _tracked = true;
    AnalyticsService().trackEvent(
      kEventJitExplanationViewed,
      category: 'engagement',
      screenName: 'smart_onboarding_jit',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final explanation = _explanationForType(widget.chiffreChoc?.type, l);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // ── HEADER ─────────────────────────────────────────────
              MintEntrance(child: Text(
                l.stepJitTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              )),
              const SizedBox(height: 24),

              // ── SI...ALORS CARD ────────────────────────────────────
              Expanded(
                child: MintEntrance(delay: const Duration(milliseconds: 100), child: SingleChildScrollView(
                  child: MintSurface(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SI...
                        _ConditionRow(
                          label: l.stepJitSi,
                          color: MintColors.warning,
                          text: explanation.condition,
                        ),
                        const SizedBox(height: 20),

                        // ALORS...
                        _ConditionRow(
                          label: l.stepJitAlors,
                          color: MintColors.success,
                          text: explanation.consequence,
                        ),
                        const SizedBox(height: 24),

                        // WHY IT MATTERS
                        MintSurface(
                          tone: MintSurfaceTone.porcelaine,
                          padding: const EdgeInsets.all(16),
                          radius: 12,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 20,
                                color: MintColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  explanation.insight,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: MintColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // SOURCE
                        Text(
                          explanation.source,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: MintColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),

              const SizedBox(height: 16),

              // ── NAVIGATION ──────────────────────────────────────────
              MintEntrance(delay: const Duration(milliseconds: 200), child: Semantics(
                button: true,
                label: l.stepJitAction,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l.stepJitAction,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              )),
              const SizedBox(height: 8),
              MintEntrance(delay: const Duration(milliseconds: 300), child: Center(
                child: TextButton(
                  onPressed: widget.onBack,
                  child: Text(
                    l.stepJitBack,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 16),

              // ── DISCLAIMER ──────────────────────────────────────────
              MintEntrance(delay: const Duration(milliseconds: 400), child: Text(
                l.stepJitDisclaimer,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  _JitExplanation _explanationForType(ChiffreChocType? type, S l) {
    return switch (type) {
      ChiffreChocType.liquidityAlert => _JitExplanation(
          condition: l.stepJitLiquidityCond,
          consequence: l.stepJitLiquidityCons,
          insight: l.stepJitLiquidityInsight,
          source: l.stepJitLiquiditySource,
        ),
      ChiffreChocType.retirementGap => _JitExplanation(
          condition: l.stepJitRetirementCond,
          consequence: l.stepJitRetirementCons,
          insight: l.stepJitRetirementInsight,
          source: l.stepJitRetirementSource,
        ),
      ChiffreChocType.taxSaving3a => _JitExplanation(
          condition: l.stepJitTax3aCond,
          consequence: l.stepJitTax3aCons,
          insight: l.stepJitTax3aInsight,
          source: l.stepJitTax3aSource,
        ),
      ChiffreChocType.retirementIncome => _JitExplanation(
          condition: l.stepJitIncomeCond,
          consequence: l.stepJitIncomeCons,
          insight: l.stepJitIncomeInsight,
          source: l.stepJitIncomeSource,
        ),
      _ => _JitExplanation(
          condition: l.stepJitDefaultCond,
          consequence: l.stepJitDefaultCons,
          insight: l.stepJitDefaultInsight,
          source: l.stepJitDefaultSource,
        ),
    };
  }
}

class _ConditionRow extends StatelessWidget {
  final String label;
  final Color color;
  final String text;

  const _ConditionRow({
    required this.label,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: MintColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JitExplanation {
  final String condition;
  final String consequence;
  final String insight;
  final String source;

  const _JitExplanation({
    required this.condition,
    required this.consequence,
    required this.insight,
    required this.source,
  });
}
