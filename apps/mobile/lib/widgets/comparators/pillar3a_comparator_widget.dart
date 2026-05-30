import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'dart:math' as math;
import 'package:mint_mobile/widgets/educational_explanation_widget.dart';
import 'package:mint_mobile/data/financial_explanations.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Widget comparatif des fournisseurs 3a avec projection
class Pillar3aComparatorWidget extends StatelessWidget {
  final double monthlyIncome;
  final int yearsUntilRetirement;
  final bool hasPensionFund;

  const Pillar3aComparatorWidget({
    super.key,
    required this.monthlyIncome,
    required this.yearsUntilRetirement,
    this.hasPensionFund = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasDebt = context.watch<ProfileProvider>().profile?.hasDebt ?? false;
    final maxAnnual =
        hasPensionFund ? pilier3aPlafondAvecLpp : pilier3aPlafondSansLpp;
    final estimatedTaxSavings =
        maxAnnual * _estimated3aMarginalTaxRate(monthlyIncome);
    // Projections à 65 ans (rendements historiques moyens)
    final capitalBank =
        _futureValue(maxAnnual, 0.015, yearsUntilRetirement); // 1.5%
    final capitalSecurities60 =
        _futureValue(maxAnnual, 0.045, yearsUntilRetirement); // 4.5%
    final capitalSecurities80 =
        _futureValue(maxAnnual, 0.055, yearsUntilRetirement); // 5.5%
    final capitalInsurance =
        _futureValue(maxAnnual, 0.010, yearsUntilRetirement); // 1.0%

    final gainVsBank = capitalSecurities60 - capitalBank;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary.withValues(alpha: 0.05),
            MintColors.accentPastel.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: MintColors.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.compare_arrows,
                    color: MintColors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.pillar3aComparator,
                      style: MintTextStyles.titleLarge(
                          color: MintColors.textPrimary),
                    ),
                    Text(
                      S.of(context)!.pillar3aProjection(yearsUntilRetirement),
                      style: MintTextStyles.labelMedium(
                          color: MintColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Scénario
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.pillar3aScenarioTitle,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.of(context)!.pillar3aPaymentPerYear,
                        style: MintTextStyles.labelMedium()),
                    Text(
                      formatChfWithPrefix(maxAnnual),
                      style: MintTextStyles.labelMedium(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.of(context)!.pillar3aDuration,
                        style: MintTextStyles.labelMedium()),
                    Text(
                      S
                          .of(context)!
                          .pillar3aDurationYears(yearsUntilRetirement),
                      style: MintTextStyles.labelMedium(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tableau comparatif
          _buildProviderRow(
            context: context,
            name: '🏦 Banque Classique',
            subtitle: 'UBS, CS, Raiffeisen',
            fees: '1.0-1.5%/an',
            returnRate: '1.5%/an',
            capital: capitalBank,
            isReference: true,
          ),

          const SizedBox(height: 12),

          _buildProviderRow(
            context: context,
            name: '📈 3a titres 60%',
            subtitle: 'Scénario indiciel diversifié',
            fees: '0.52%/an',
            returnRate: '4.5%/an',
            capital: capitalSecurities60,
            gain: gainVsBank,
          ),

          const SizedBox(height: 12),

          _buildProviderRow(
            context: context,
            name: '📊 3a titres 80%',
            subtitle: 'Scénario actions élevé',
            fees: '0.39%/an',
            returnRate: '5.5%/an',
            capital: capitalSecurities80,
            gain: capitalSecurities80 - capitalBank,
          ),

          const SizedBox(height: 12),

          _buildProviderRow(
            context: context,
            name: '⚠️ Assurance',
            subtitle: 'AXA, Zurich, Swiss Life',
            fees: '1.5-3%/an',
            returnRate: '1.0%/an',
            capital: capitalInsurance,
            gain: capitalInsurance - capitalBank, // Négatif
            isWarning: true,
          ),

          const SizedBox(height: 24),

          // Highlight titres scenario gain — gated when debt active
          SafeModeGate(
            hasDebt: hasDebt,
            lockedTitle: 'Priorité au désendettement',
            lockedMessage:
                'Les recommandations de placement 3a sont désactivées en mode protection. '
                'Rembourser tes dettes offre un rendement plus élevé que tout placement.',
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MintColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: MintColors.success.withValues(alpha: 0.3), width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up,
                          color: MintColors.success, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scénario titres 60% au lieu d’une banque :',
                              style: MintTextStyles.bodySmall(
                                      color: MintColors.success)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${formatChfWithPrefix(gainVsBank)}',
                              style: MintTextStyles.displaySmall(
                                  color: MintColors.success),
                            ),
                            Text(
                              'd’écart estimé à la retraite',
                              style: MintTextStyles.labelMedium(
                                  color: MintColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        // TODO: Ouvrir modal de comparaison des hypothèses 3a
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Comparer les hypothèses 3a'),
                      style: FilledButton.styleFrom(
                        backgroundColor: MintColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: MintColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.pillar3aDisclaimer,
                    style: MintTextStyles.labelSmall(color: MintColors.warning),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // NOUVEAU : Tableau intérêts composés
          _buildCompoundInterestTable(context, maxAnnual, yearsUntilRetirement),

          const SizedBox(height: 16),

          // NOUVEAU : Widget explicatif pédagogique
          EducationalExplanationWidget(
            title: 'Pourquoi le 3a titres peut être efficace',
            shortExplanation:
                'Le 3a combine placement et impact fiscal estimé. Voici comment lire cette hypothèse.',
            sections: FinancialExplanations.pillar3aRealReturnExplanation(
              maxAnnual,
              estimatedTaxSavings,
              0.045, // Scénario titres 60%
              yearsUntilRetirement,
            ),
            accentColor: MintColors.success,
          ),

          const SizedBox(height: 16),

          // Widget explicatif intérêts composés
          EducationalExplanationWidget(
            title: 'La magie des intérêts composés',
            shortExplanation:
                'Tes gains génèrent eux-mêmes des gains. Plus le temps passe, plus l\'effet est puissant !',
            sections: FinancialExplanations.compoundInterestExplanation(),
            accentColor: MintColors.primary,
          ),
        ],
      ),
    );
  }

  /// Tableau montrant l'évolution du capital année par année.
  Widget _buildCompoundInterestTable(
      BuildContext context, double annualContribution, int years) {
    // Sélectionner quelques années clés pour ne pas surcharger
    final keyYears = _selectKeyYears(years);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 ${S.of(context)!.pillar3aCapitalEvolution}',
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: 12),
          // Header
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  S.of(context)!.pillar3aYearLabel,
                  style:
                      MintTextStyles.labelMedium(color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  S.of(context)!.pillar3aBank15,
                  style:
                      MintTextStyles.labelMedium(color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Titres 4.5 %',
                  style:
                      MintTextStyles.labelMedium(color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const Divider(),
          // Lignes
          ...keyYears.map((year) {
            final bankCapital = _futureValue(annualContribution, 0.015, year);
            final securitiesCapital =
                _futureValue(annualContribution, 0.045, year);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      S.of(context)!.pillar3aYearN(year),
                      style: MintTextStyles.labelSmall(),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      formatChfWithPrefix(bankCapital),
                      style: MintTextStyles.labelSmall(),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      formatChfWithPrefix(securitiesCapital),
                      style:
                          MintTextStyles.labelSmall(color: MintColors.success)
                              .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '💡 ${S.of(context)!.pillar3aCompoundTip}',
              style: MintTextStyles.labelSmall(color: MintColors.info)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  /// Sélectionne des années clés pour le tableau (ne pas tout afficher)
  List<int> _selectKeyYears(int totalYears) {
    if (totalYears <= 5) {
      return List.generate(totalYears, (i) => i + 1);
    } else if (totalYears <= 10) {
      return [1, 3, 5, totalYears];
    } else if (totalYears <= 20) {
      return [1, 5, 10, 15, totalYears];
    } else {
      return [1, 5, 10, 15, 20, totalYears];
    }
  }

  Widget _buildProviderRow({
    required BuildContext context,
    required String name,
    required String subtitle,
    required String fees,
    required String returnRate,
    required double capital,
    double? gain,
    bool isReference = false,
    bool isWarning = false,
  }) {
    Color bgColor = MintColors.white;
    Color borderColor = MintColors.border;

    if (isWarning) {
      bgColor = MintColors.error.withValues(alpha: 0.05);
      borderColor = MintColors.error.withValues(alpha: 0.3);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary)
                          .copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.of(context)!.pillar3aFees,
                      style: MintTextStyles.micro(color: MintColors.textMuted)),
                  Text(fees,
                      style: MintTextStyles.labelSmall(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.of(context)!.pillar3aReturn,
                      style: MintTextStyles.micro(color: MintColors.textMuted)),
                  Text(returnRate,
                      style: MintTextStyles.labelSmall(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(S.of(context)!.pillar3aAt65,
                      style: MintTextStyles.micro(color: MintColors.textMuted)),
                  Text(
                    formatChfWithPrefix(capital),
                    style: MintTextStyles.labelLarge(
                        color: MintColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          if (gain != null && !isReference) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: gain > 0
                    ? MintColors.success.withValues(alpha: 0.15)
                    : MintColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                S.of(context)!.pillar3aVsBank(
                    '${gain > 0 ? '+' : ''}${formatChfWithPrefix(gain)}'),
                style: MintTextStyles.labelSmall(
                  color: gain > 0 ? MintColors.success : MintColors.error,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _futureValue(double annualPayment, double rate, int years) {
    if (rate == 0 || years == 0) return annualPayment * years;
    return annualPayment * ((math.pow(1 + rate, years) - 1) / rate);
  }

  double _estimated3aMarginalTaxRate(double monthlyNetIncome) {
    final annualNet = monthlyNetIncome * 12;
    if (annualNet <= 0) return 0.20;
    if (annualNet < 60000) return 0.18;
    if (annualNet < 90000) return 0.24;
    if (annualNet < 140000) return 0.30;
    return 0.34;
  }
}
