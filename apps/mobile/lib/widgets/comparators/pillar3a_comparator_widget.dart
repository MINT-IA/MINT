import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:mint_mobile/services/affiliate_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/widgets/educational_explanation_widget.dart';
import 'package:mint_mobile/data/financial_explanations.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

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
    final maxAnnual = hasPensionFund ? pilier3aPlafondAvecLpp : pilier3aPlafondSansLpp;
    final currencyFormat =
        NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

    // Projections à 65 ans (rendements historiques moyens)
    final capitalBank =
        _futureValue(maxAnnual, 0.015, yearsUntilRetirement); // 1.5%
    final capitalViac =
        _futureValue(maxAnnual, 0.045, yearsUntilRetirement); // 4.5%
    final capitalFinpension =
        _futureValue(maxAnnual, 0.055, yearsUntilRetirement); // 5.5%
    final capitalInsurance =
        _futureValue(maxAnnual, 0.010, yearsUntilRetirement); // 1.0%

    final gainVsBank = capitalViac - capitalBank;
    final gainVsInsurance = capitalViac - capitalInsurance;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary.withOpacity(0.05),
            MintColors.accentPastel.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: MintColors.primary.withOpacity(0.2), width: 2),
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
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comparateur 3a',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Projection sur $yearsUntilRetirement ans',
                      style: const TextStyle(
                          fontSize: 12, color: MintColors.textMuted),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scénario : Versement max annuel',
                  style: GoogleFonts.montserrat(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Versement/an :',
                        style: TextStyle(fontSize: 12)),
                    Text(
                      currencyFormat.format(maxAnnual),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Durée :', style: TextStyle(fontSize: 12)),
                    Text(
                      '$yearsUntilRetirement ans (jusqu\'à 65 ans)',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tableau comparatif
          _buildProviderRow(
            name: '🏦 Banque Classique',
            subtitle: 'UBS, CS, Raiffeisen',
            fees: '1.0-1.5%/an',
            returnRate: '1.5%/an',
            capital: capitalBank,
            isReference: true,
            currencyFormat: currencyFormat,
          ),

          const SizedBox(height: 12),

          _buildProviderRow(
            name: '🚀 VIAC',
            subtitle: 'Leader Suisse, 60% actions',
            fees: '0.52%/an',
            returnRate: '4.5%/an',
            capital: capitalViac,
            gain: gainVsBank,
            isRecommended: true,
            currencyFormat: currencyFormat,
          ),

          const SizedBox(height: 12),

          _buildProviderRow(
            name: '💎 Finpension',
            subtitle: 'Le - cher, 80% actions',
            fees: '0.39%/an',
            returnRate: '5.5%/an',
            capital: capitalFinpension,
            gain: capitalFinpension - capitalBank,
            currencyFormat: currencyFormat,
          ),

          const SizedBox(height: 12),

          _buildProviderRow(
            name: '⚠️ Assurance',
            subtitle: 'AXA, Zurich, Swiss Life',
            fees: '1.5-3%/an',
            returnRate: '1.0%/an',
            capital: capitalInsurance,
            gain: capitalInsurance - capitalBank, // Négatif
            isWarning: true,
            currencyFormat: currencyFormat,
          ),

          const SizedBox(height: 24),

          // Highlight gain VIAC — gated when debt active
          SafeModeGate(
            hasDebt: hasDebt,
            lockedTitle: 'Priorite au desendettement',
            lockedMessage:
                'Les recommandations de placement 3a sont desactivees en mode protection. '
                'Rembourser tes dettes offre un rendement plus eleve que tout placement.',
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up,
                          color: Colors.green.shade700, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avec VIAC au lieu d\'une banque :',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${currencyFormat.format(gainVsBank)}',
                              style: GoogleFonts.montserrat(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              'de plus a la retraite !',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.green.shade700),
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
                        // TODO: Ouvrir modal "Comment ouvrir VIAC"
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Ouvrir mon compte VIAC'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
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
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hypothèses pédagogiques basées sur rendements historiques moyens. Rendements passés ne garantissent pas rendements futurs.',
                    style:
                        TextStyle(fontSize: 11, color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // NOUVEAU : Tableau intérêts composés
          _buildCompoundInterestTable(maxAnnual, yearsUntilRetirement),

          const SizedBox(height: 16),

          // NOUVEAU : Widget explicatif pédagogique
          EducationalExplanationWidget(
            title: 'Pourquoi le 3a VIAC est imbattable',
            shortExplanation:
                'Le 3a te donne un double rendement : investissement + économie fiscale. Voici comment ça marche.',
            sections: FinancialExplanations.pillar3aRealReturnExplanation(
              maxAnnual,
              maxAnnual * 0.35, // Économie fiscale estimée (35% taux marginal)
              0.045, // Rendement VIAC
              yearsUntilRetirement,
            ),
            accentColor: Colors.green.shade700,
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

  /// Tableau montrant l'évolution du capital année par année (VIAC vs Banque)
  Widget _buildCompoundInterestTable(double annualContribution, int years) {
    // Sélectionner quelques années clés pour ne pas surcharger
    final keyYears = _selectKeyYears(years);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Évolution de ton capital 3a',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text(
                  'Année',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'Banque 1.5%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'VIAC 4.5%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const Divider(),
          // Lignes
          ...keyYears.map((year) {
            final bankCapital = _futureValue(annualContribution, 0.015, year);
            final viacCapital = _futureValue(annualContribution, 0.045, year);
            final currencyFormat =
                NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Année $year',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      currencyFormat.format(bankCapital),
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      currencyFormat.format(viacCapital),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '💡 Les dernières années font +50% du gain total grâce aux intérêts composés !',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade700,
                fontStyle: FontStyle.italic,
              ),
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
    required String name,
    required String subtitle,
    required String fees,
    required String returnRate,
    required double capital,
    double? gain,
    bool isReference = false,
    bool isRecommended = false,
    bool isWarning = false,
    required NumberFormat currencyFormat,
  }) {
    Color bgColor = Colors.white;
    Color borderColor = MintColors.border;

    if (isRecommended) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
    } else if (isWarning) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isRecommended ? 2 : 1),
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
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: MintColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (isRecommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'RECOMMANDÉ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
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
                  const Text('Frais',
                      style:
                          TextStyle(fontSize: 10, color: MintColors.textMuted)),
                  Text(fees,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rendement',
                      style:
                          TextStyle(fontSize: 10, color: MintColors.textMuted)),
                  Text(returnRate,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('À 65 ans',
                      style:
                          TextStyle(fontSize: 10, color: MintColors.textMuted)),
                  Text(
                    currencyFormat.format(capital),
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isRecommended
                          ? Colors.green.shade700
                          : MintColors.textPrimary,
                    ),
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
                color: gain > 0 ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${gain > 0 ? '+' : ''}${currencyFormat.format(gain)} vs Banque',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: gain > 0 ? Colors.green.shade700 : Colors.red.shade700,
                ),
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
}
