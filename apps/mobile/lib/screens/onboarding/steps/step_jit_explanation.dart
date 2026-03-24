import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/analytics_events.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';

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
    final explanation = _explanationForType(widget.chiffreChoc?.type);

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
              Text(
                'Comprendre en 30 secondes',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // ── SI...ALORS CARD ────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: MintColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MintColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SI...
                        _ConditionRow(
                          label: 'SI',
                          color: MintColors.warning,
                          text: explanation.condition,
                        ),
                        const SizedBox(height: 20),

                        // ALORS...
                        _ConditionRow(
                          label: 'ALORS',
                          color: MintColors.success,
                          text: explanation.consequence,
                        ),
                        const SizedBox(height: 24),

                        // WHY IT MATTERS
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: MintColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
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
              ),

              const SizedBox(height: 16),

              // ── NAVIGATION ──────────────────────────────────────────
              SizedBox(
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
                    'Que puis-je faire ?',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: widget.onBack,
                  child: Text(
                    'Retour',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── DISCLAIMER ──────────────────────────────────────────
              Text(
                'Outil éducatif simplifié. Ne constitue pas un conseil '
                'financier (LSFin).',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  _JitExplanation _explanationForType(ChiffreChocType? type) {
    return switch (type) {
      ChiffreChocType.liquidityAlert => const _JitExplanation(
          condition:
              'ton épargne de sécurité couvre moins de 2 mois de charges',
          consequence:
              'un imprévu (perte d\'emploi, réparation urgente) peut '
              'te mettre en difficulté financière rapidement.',
          insight:
              'Les experts recommandent 3 à 6 mois de charges fixes en '
              'réserve. Même 100 CHF/mois sur un compte épargne fait une '
              'différence significative sur 12 mois.',
          source: 'Recommandation Budget-conseil Suisse',
        ),
      ChiffreChocType.retirementGap => const _JitExplanation(
          condition:
              'ton taux de remplacement à la retraite est inférieur à 60%',
          consequence:
              'ton niveau de vie pourrait baisser significativement '
              'le jour où tu arrêtes de travailler.',
          insight:
              'En Suisse, l\'AVS et la LPP couvrent en moyenne 60% du '
              'dernier salaire. Le 3e pilier et l\'épargne libre comblent '
              'le reste. Plus tu commences tôt, moins l\'effort mensuel '
              'est important.',
          source: 'LAVS art. 34 / LPP art. 14',
        ),
      ChiffreChocType.taxSaving3a => const _JitExplanation(
          condition:
              'tu ne verses pas le maximum dans ton 3e pilier chaque année',
          consequence:
              'tu passes à côté d\'une économie fiscale et d\'un capital '
              'retraite supplémentaire.',
          insight:
              'Chaque franc versé en 3a est déductible du revenu imposable. '
              'Sur 20 ans, la différence entre verser 0 et le plafond '
              '(7\'258 CHF) peut représenter plus de 200\'000 CHF.',
          source: 'OPP3 art. 7 / LIFD art. 33',
        ),
      ChiffreChocType.retirementIncome => const _JitExplanation(
          condition:
              'ta projection de revenu à la retraite est estimée',
          consequence:
              'connaître ce montant te permet de planifier '
              'et d\'ajuster ta stratégie de prévoyance dès maintenant.',
          insight:
              'Le système suisse à 3 piliers (AVS + LPP + 3a) couvre en '
              'moyenne 60% du dernier salaire. Chaque pilier a ses règles '
              'et ses leviers d\'optimisation spécifiques.',
          source: 'LAVS art. 34 / LPP art. 14 / OPP3 art. 7',
        ),
      _ => const _JitExplanation(
          condition: 'tu n\'as pas encore un plan financier structuré',
          consequence:
              'tu risques de passer à côté d\'opportunités d\'optimisation '
              'fiscale et de prévoyance.',
          insight:
              'Un bilan financier annuel permet d\'identifier les leviers '
              'les plus impactants : 3a, rachat LPP, franchise LAMal, '
              'amortissement indirect.',
          source: 'Recommandation éducative MINT',
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
