import 'package:flutter/material.dart';
import 'package:mint_mobile/widgets/educational/educational_widgets.dart';

/// Service de mapping entre les questions wizard et les inserts didactiques
/// Implémente le pattern "just-in-time information" (OECD/INFE)
class EducationalInsertService {
  /// Questions qui ont un insert didactique associé
  static const Set<String> questionsWithInserts = {
    'q_has_pension_fund',
    'q_has_3a',
    'q_3a_annual_amount',
    'q_mortgage_type',
    'q_has_consumer_credit',
    'q_has_leasing',
    'q_emergency_fund',
  };

  /// Vérifie si une question a un insert didactique
  static bool hasInsert(String questionId) {
    return questionsWithInserts.contains(questionId);
  }

  /// Retourne le widget d'insert pour une question donnée
  /// Returns null si aucun insert n'est disponible
  static Widget? getInsertWidget({
    required String questionId,
    required Map<String, dynamic> answers,
    VoidCallback? onLearnMore,
    Function(dynamic)? onAnswer,
  }) {
    switch (questionId) {
      case 'q_has_pension_fund':
        return LppPivotInsertWidget(
          hasPensionFund: answers['q_has_pension_fund'] == 'yes',
          onLearnMore: onLearnMore,
          onChanged: (val) => onAnswer?.call(val ? 'yes' : 'no'),
        );

      case 'q_has_3a':
      case 'q_3a_annual_amount':
        // 1. Income Resolution
        double monthlyIncome = 6000;

        final periodIncome = _parseDouble(answers['q_net_income_period_chf']);
        final monthlyDirect =
            _parseDouble(answers['q_income_net_monthly']); // Fallback key

        if (periodIncome != null) {
          final payFreq = answers['q_pay_frequency'] as String?;
          if (payFreq == 'weekly') {
            monthlyIncome = periodIncome * 4.33;
          } else if (payFreq == 'biweekly') {
            monthlyIncome = periodIncome * 2.17;
          } else {
            monthlyIncome = periodIncome;
          }
        } else if (monthlyDirect != null) {
          monthlyIncome = monthlyDirect;
        }

        // 2. Pension Fund Logic (Crucial Fix for Salaried employees)
        // If employee -> Default to Yes (Small 3a limit)
        // If self employed -> Default to No (Large 3a limit), unless explicit Yes
        final status = answers['q_employment_status'] as String?;
        final explicitLpp = answers['q_has_pension_fund'] == 'yes';

        bool hasPensionFund = explicitLpp;
        if (status == 'employee') {
          hasPensionFund =
              true; // Salaried employees almost always have LPP implies 7k limit
        }

        return TaxSavingsInsertWidget(
          initialIncome: monthlyIncome,
          hasPensionFund: hasPensionFund,
          onLearnMore: onLearnMore,
        );

      case 'q_mortgage_type':
        return MortgageComparisonInsertWidget(
          currentType: answers['q_mortgage_type'] as String?,
          onLearnMore: onLearnMore,
        );

      case 'q_has_consumer_credit':
        return CreditCostInsertWidget(
          creditAmount: _parseDouble(answers['q_credit_amount']),
          interestRate: _parseDouble(answers['q_credit_rate']),
          durationMonths: _parseInt(answers['q_credit_duration']),
          onLearnMore: onLearnMore,
        );

      case 'q_has_leasing':
        return LeasingCostInsertWidget(
          monthlyPayment: _parseDouble(answers['q_leasing_monthly']),
          remainingMonths: _parseInt(answers['q_leasing_remaining_months']),
          onLearnMore: onLearnMore,
        );

      case 'q_emergency_fund':
        return EmergencyFundInsertWidget(
          monthlyExpenses: _parseDouble(answers['q_expenses_fixed_monthly']),
          currentSavings: _parseDouble(answers['q_cash_total']),
          onLearnMore: onLearnMore,
        );

      default:
        return null;
    }
  }

  /// Retourne le titre du modal "En savoir plus"
  static String? getLearnMoreTitle(String questionId) {
    switch (questionId) {
      case 'q_has_pension_fund':
        return 'Comprendre le 2e pilier (LPP)';
      case 'q_has_3a':
      case 'q_3a_annual_amount':
        return 'Le 3e pilier en détail';
      case 'q_mortgage_type':
        return 'Types d\'hypothèques en Suisse';
      case 'q_has_consumer_credit':
        return 'Le crédit à la consommation';
      case 'q_has_leasing':
        return 'Leasing vs achat';
      case 'q_emergency_fund':
        return 'Pourquoi un fonds d\'urgence ?';
      default:
        return null;
    }
  }

  /// Parse helper pour double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parse helper pour int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
