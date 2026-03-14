// Outil éducatif — ne constitue pas un conseil financier (LSFin).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Carte "3e pilier (3a)" pour l'aperçu financier.
///
/// Affiche: capital actuel, plafond annuel, économie fiscale estimée,
/// projection à la retraite, et CTA vers le simulateur 3a.
class Apercu3aCard extends StatelessWidget {
  final CoachProfile profile;

  const Apercu3aCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final prev = profile.prevoyance;
    final gross = profile.revenuBrutAnnuel;
    final canton = profile.canton.isNotEmpty ? profile.canton : 'ZH';
    final ageRetraite = profile.effectiveRetirementAge;
    final anneesRestantes = ageRetraite - profile.age;

    // Plafond applicable
    final isIndepSansLpp = profile.archetype == FinancialArchetype.independentNoLpp;
    final plafond =
        isIndepSansLpp ? pilier3aPlafondSansLpp : pilier3aPlafondAvecLpp;

    // Économie fiscale estimée (versement max)
    final economieFiscale = gross > 0
        ? RetirementTaxCalculator.estimateTaxSaving(
            income: gross,
            deduction: plafond,
            canton: canton,
          )
        : 0.0;

    // Projection simple: capital actuel + versements futurs (sans rendement)
    final capitalActuel = prev.totalEpargne3a;
    final projectionSansRendement =
        capitalActuel + (plafond * anneesRestantes.clamp(0, 40));

    // Projection avec rendement ~2% net (conservateur, après frais)
    final tauxNet = 0.02;
    double projectionAvecRendement = capitalActuel;
    for (int i = 0; i < anneesRestantes.clamp(0, 40); i++) {
      projectionAvecRendement =
          (projectionAvecRendement + plafond) * (1 + tauxNet);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MintColors.pillar3a.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.savings_outlined,
                  color: MintColors.pillar3a,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.financialSummary3a3ePilier,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${prev.nombre3a} ${prev.nombre3a <= 1 ? "compte" : "comptes"}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Hero: capital actuel
              Text(
                formatChfWithPrefix(capitalActuel),
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3 KPI row
          Row(
            children: [
              Expanded(
                child: _KpiTile(
                  label: s.apercu3aPlafondLabel,
                  value: formatChfWithPrefix(plafond),
                  sublabel: '/an',
                  color: MintColors.pillar3a,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiTile(
                  label: s.apercu3aEconomieFiscaleLabel,
                  value: economieFiscale > 0
                      ? '~${formatChfWithPrefix(economieFiscale)}'
                      : '\u2014',
                  sublabel: '/an',
                  color: MintColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiTile(
                  label: s.apercu3aProjectionLabel,
                  value: formatChfCompact(projectionAvecRendement),
                  sublabel:
                      anneesRestantes > 0 ? 'dans $anneesRestantes ans' : '',
                  color: MintColors.info,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progression bar: capital actuel vs projection
          if (projectionSansRendement > 0) ...[
            _ProgressionBar(
              current: capitalActuel,
              target: projectionAvecRendement,
              label: s.apercu3aProgressionLabel,
            ),
            const SizedBox(height: 16),
          ],

          // Comptes detail (if multiple)
          if (prev.comptes3a.isNotEmpty) ...[
            ...prev.comptes3a.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_outlined,
                        size: 14, color: MintColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.provider,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      formatChfWithPrefix(c.solde),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // CTA: Simuler mon 3a
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/simulator/3a'),
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: Text(
                s.apercu3aSimulerCta,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: MintColors.pillar3a,
                side: BorderSide(
                    color: MintColors.pillar3a.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Disclaimer
          const SizedBox(height: 8),
          Text(
            s.apercu3aDisclaimer,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final Color color;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: MintColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          if (sublabel.isNotEmpty)
            Text(
              sublabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressionBar extends StatelessWidget {
  final double current;
  final double target;
  final String label;

  const _ProgressionBar({
    required this.current,
    required this.target,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textSecondary,
              ),
            ),
            Text(
              '$pct%',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.pillar3a,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: MintColors.pillar3a.withValues(alpha: 0.12),
            valueColor:
                AlwaysStoppedAnimation<Color>(MintColors.pillar3a),
          ),
        ),
      ],
    );
  }
}
