import 'package:flutter/material.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Modèle de progression de clarté (pas gamification)
/// Respecte les invariants : rapport central, neutralité, simplicité

enum ActionStatus {
  ready, // ✅ Action prête à exécuter
  pending, // ⏳ Info manquante
  blocked, // 🚫 Bloquée (ex: Safe Mode)
}

class ClarityAction {
  final String id;
  final String label;
  final String description;
  final ActionStatus status;
  final String? blockingReason;
  final double impactOnPrecision; // 0-20%

  const ClarityAction({
    required this.id,
    required this.label,
    required this.description,
    required this.status,
    this.blockingReason,
    required this.impactOnPrecision,
  });
}

/// Badge comportemental (débloqué uniquement sur actions réalisées)
enum BehavioralBadge {
  protected, // 🛡️ Fonds d'urgence constitué
  regular, // 📅 Ordre permanent 3a activé
  transparent, // 📄 Certificat LPP uploadé
  prudent, // 🧠 Bénéficiaires vérifiés
}

class Badge {
  final BehavioralBadge type;
  final String emoji;
  final String label;
  final String description;
  final bool Function(Map<String, dynamic> actions) condition;

  const Badge({
    required this.type,
    required this.emoji,
    required this.label,
    required this.description,
    required this.condition,
  });

  static final List<Badge> all = [
    Badge(
      type: BehavioralBadge.protected,
      emoji: '🛡️',
      label: 'Protégé',
      description: 'Fonds d\'urgence constitué',
      condition: (actions) => actions['emergency_fund_proof_uploaded'] == true,
    ),
    Badge(
      type: BehavioralBadge.regular,
      emoji: '📅',
      label: 'Régulier',
      description: 'Ordre permanent 3a activé',
      condition: (actions) => actions['3a_standing_order_activated'] == true,
    ),
    Badge(
      type: BehavioralBadge.transparent,
      emoji: '📄',
      label: 'Transparent',
      description: 'Certificat LPP uploadé',
      condition: (actions) => actions['lpp_certificate_uploaded'] == true,
    ),
    Badge(
      type: BehavioralBadge.prudent,
      emoji: '🧠',
      label: 'Prudent',
      description: 'Bénéficiaires vérifiés',
      condition: (actions) => actions['beneficiaries_verified'] == true,
    ),
  ];

  static List<Badge> getUnlocked(Map<String, dynamic> actions) {
    return all.where((badge) => badge.condition(actions)).toList();
  }
}

/// État de progression de clarté
class ClarityState {
  final double precisionIndex; // 0-100%
  final List<ClarityAction> actions;
  final List<Badge> unlockedBadges;
  final String? nextMostValuableInfo;
  final bool safeMode;

  const ClarityState({
    required this.precisionIndex,
    required this.actions,
    required this.unlockedBadges,
    this.nextMostValuableInfo,
    required this.safeMode,
  });

  String get precisionLabel {
    if (precisionIndex < 40) return 'Basique';
    if (precisionIndex < 70) return 'Bon';
    if (precisionIndex < 90) return 'Excellent';
    return 'Complet';
  }

  Color get precisionColor {
    if (precisionIndex < 40) return MintColors.warning;
    if (precisionIndex < 70) {
      return MintColors.centralScenarioLight; // Vert clair
    }
    if (precisionIndex < 90) return MintColors.centralScenario; // Vert
    return MintColors.stressScenario; // Vert foncé
  }

  int get actionsReady =>
      actions.where((a) => a.status == ActionStatus.ready).length;
  int get totalActions => actions.length;

  static ClarityState calculate(
    Map<String, dynamic> answers,
    Map<String, dynamic> completedActions,
  ) {
    double precision = 0;

    // Profil minimal (20%)
    // V1: q_canton, q_birth_year
    if (answers['q_canton'] != null && answers['q_birth_year'] != null) {
      precision += 20;
    }

    // Cashflow (20%)
    // V1: q_net_income_monthly, q_savings_monthly (absent V1)
    // V2: q_net_income_period_chf
    bool hasIncome = answers['q_net_income_monthly'] != null ||
        answers['q_net_income_period_chf'] != null;
    bool hasSavings = answers['q_savings_monthly'] != null;

    if (hasIncome && hasSavings) {
      precision += 20;
    } else if (hasIncome) {
      precision += 10;
    }

    // Dettes (20%)
    // V1: q_has_leasing, q_has_consumer_credit
    // V2: q_has_consumer_debt, q_debt_payments_period_chf
    bool checkedDebt = answers['q_has_leasing'] != null ||
        answers['q_has_consumer_credit'] != null ||
        answers['q_has_consumer_debt'] != null;

    if (checkedDebt) {
      precision += 20;
    }

    // Prévoyance (20%)
    if (answers['q_has_3a'] != null || answers['q_3a_accounts_count'] != null) {
      precision += 10;
    }
    // V1/V2: q_has_lpp_certificate? In V2: q_lpp_buyback_available implies we checked certificate
    if (answers['q_has_lpp_certificate'] != null ||
        answers['q_lpp_buyback_available'] != null) {
      precision += 10;
    }

    // Objectif (20%)
    if (answers['q_goal_template'] != null || answers['q_main_goal'] != null) {
      precision += 20;
    }

    // Safe Mode : triggers stricts selon YAML
    // V1 keys and logic
    final bool hasDebtStress = answers['q_late_payments_6m'] == 'yes' ||
        answers['q_creditcard_minimum_or_overdraft'] == 'often' ||
        answers['q_has_consumer_credit'] == 'yes' ||
        answers['q_has_consumer_debt'] == 'yes'; // V2

    final double debtRatio = _calculateDebtRatio(answers);

    // V1: q_emergency_fund_exists, V2: q_emergency_fund
    // V2 values: yes_6months, yes_3months, no
    String? efV2 = answers['q_emergency_fund'];
    bool efV2Ok = efV2 == 'yes_6months' || efV2 == 'yes_3months';
    final bool hasEmergencyFund = answers['q_emergency_fund_exists'] == 'yes' ||
        answers['hasEmergencyFund'] == true ||
        efV2Ok;

    // Le Safe Mode est actif si stress financier OU ratio dette > 30% OU pas de fonds d'urgence
    final bool safeMode = hasDebtStress || debtRatio > 0.3 || !hasEmergencyFund;

    // Actions disponibles
    final actions = _generateActions(answers, safeMode);

    // Prochaine info la plus rentable
    final nextInfo = _getNextMostValuableInfo(answers, precision);

    // Badges débloqués
    final unlockedBadges = Badge.getUnlocked(completedActions);

    return ClarityState(
      precisionIndex: precision,
      actions: actions,
      unlockedBadges: unlockedBadges,
      nextMostValuableInfo: nextInfo,
      safeMode: safeMode,
    );
  }

  static double _calculateDebtRatio(Map<String, dynamic> answers) {
    // Support V1 and V2 income keys
    double income = _parseDouble(answers['income_net_monthly']) ??
        _parseDouble(answers['q_net_income_monthly']) ??
        0;

    if (income == 0) {
      // Try V2 period income
      final periodIncome = _parseDouble(answers['q_net_income_period_chf']);
      if (periodIncome != null) {
        final freq =
            (answers['q_pay_frequency'] as String?)?.trim().toLowerCase() ??
                'monthly';
        income = switch (freq) {
          'weekly' => periodIncome * 4.333,
          'biweekly' => periodIncome * 2.166,
          'yearly' || 'annual' || 'annuel' => periodIncome / 12,
          _ => periodIncome,
        };
      }
    }

    if (income == 0) return 0;

    double totalDebt = 0;
    if (answers['has_leasing'] == true || answers['q_has_leasing'] == 'yes') {
      totalDebt += _parseDouble(answers['leasing_monthly']) ??
          _parseDouble(answers['q_leasing_monthly']) ??
          0;
    }
    if (answers['has_consumer_credit'] == true ||
        answers['q_has_consumer_credit'] == 'yes') {
      totalDebt += _parseDouble(answers['consumer_credit_monthly']) ??
          _parseDouble(answers['q_credit_monthly']) ??
          0;
    }

    // V2 debt
    if (answers['q_debt_payments_period_chf'] != null) {
      totalDebt += _parseDouble(answers['q_debt_payments_period_chf']) ?? 0;
    }

    return totalDebt / income;
  }

  static double? _parseDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(
          raw.trim().replaceAll("'", '').replaceAll(',', '.'));
    }
    return null;
  }

  static List<ClarityAction> _generateActions(
      Map<String, dynamic> answers, bool safeMode) {
    final actions = <ClarityAction>[];

    // Action 1 : Fonds d'urgence (priorité absolue)
    String? efV2 = answers['q_emergency_fund'];
    bool efOk = answers['hasEmergencyFund'] == true ||
        answers['q_emergency_fund_exists'] == 'yes' ||
        efV2 == 'yes_6months' ||
        efV2 == 'yes_3months';

    if (!efOk) {
      actions.add(const ClarityAction(
        id: 'emergency_fund',
        label: 'Fonds d\'urgence',
        description: 'Constituer 3-6 mois de charges',
        status: ActionStatus.pending,
        impactOnPrecision: 15,
      ));
    } else {
      actions.add(const ClarityAction(
        id: 'emergency_fund',
        label: 'Fonds d\'urgence',
        description: 'Objectif atteint',
        status: ActionStatus.ready,
        impactOnPrecision: 0,
      ));
    }

    // Action 2 : 3a (si pas en Safe Mode)
    bool has3a = answers['has_3a'] == true ||
        answers['q_has_3a'] == true ||
        (answers['q_3a_accounts_count'] != null &&
            answers['q_3a_accounts_count'] != '0'); // V2

    if (safeMode) {
      actions.add(const ClarityAction(
        id: '3a',
        label: '3a',
        description: 'Bloqué : priorité au fonds d\'urgence',
        status: ActionStatus.blocked,
        blockingReason: 'Constitue d\'abord ton fonds d\'urgence',
        impactOnPrecision: 0,
      ));
    } else if (!has3a) {
      actions.add(const ClarityAction(
        id: '3a',
        label: '3a',
        description: 'Comparer les comptes 3a', // lint-ignore: no_hardcoded_fr (dette i18n préexistante, LOT 3)
        status: ActionStatus.pending,
        impactOnPrecision: 10,
      ));
    } else {
      actions.add(const ClarityAction(
        id: '3a',
        label: '3a',
        description: 'Optimiser versement annuel',
        status: ActionStatus.ready,
        impactOnPrecision: 5,
      ));
    }

    // Action 3 : Rachat LPP (si 35+ ans et pas en Safe Mode)
    final age = CoachProfile.fromWizardAnswers(answers).ageOrNull;
    // V2: q_lpp_buyback_available logic handled in questions?
    // Here logic for action card.

    if (safeMode) {
      actions.add(const ClarityAction(
        id: 'lpp_buyback',
        label: 'Rachat LPP',
        description: 'Bloqué : priorité au fonds d\'urgence',
        status: ActionStatus.blocked,
        blockingReason: 'Constitue d\'abord ton fonds d\'urgence',
        impactOnPrecision: 0,
      ));
    } else if (age == null) {
      actions.add(const ClarityAction(
        id: 'lpp_buyback',
        label: 'Rachat LPP',
        description: 'À évaluer après date de naissance',
        status: ActionStatus.pending,
        blockingReason: 'Ajoute ta date de naissance pour situer le rachat LPP',
        impactOnPrecision: 5,
      ));
    } else if (age < 35) {
      actions.add(const ClarityAction(
        id: 'lpp_buyback',
        label: 'Rachat LPP',
        description: 'Pas encore pertinent (< 35 ans)',
        status: ActionStatus.blocked,
        blockingReason: 'Généralement pertinent après 35 ans',
        impactOnPrecision: 0,
      ));
    } else if (answers['hasLppBuybackPotential'] != true &&
        answers['q_lpp_buyback_available'] == null) {
      actions.add(const ClarityAction(
        id: 'lpp_buyback',
        label: 'Rachat LPP',
        description: 'Vérifier potentiel sur certificat',
        status: ActionStatus.pending,
        impactOnPrecision: 10,
      ));
    } else {
      actions.add(const ClarityAction(
        id: 'lpp_buyback',
        label: 'Rachat LPP',
        description: 'Planifier rachat',
        status: ActionStatus.ready,
        impactOnPrecision: 5,
      ));
    }

    return actions;
  }

  static String? _getNextMostValuableInfo(
      Map<String, dynamic> answers, double currentPrecision) {
    // V2 Priority
    if (answers['q_canton'] == null && answers['canton'] == null) {
      return 'Canton de résidence';
    }
    if (answers['q_birth_year'] == null && answers['birthYear'] == null) {
      return 'Année de naissance';
    }
    if (answers['q_civil_status'] == null &&
        answers['household'] == null &&
        answers['q_household_type'] == null) {
      return 'Situation familiale';
    }

    // Cashflow
    if (answers['q_net_income_period_chf'] == null &&
        answers['q_net_income_monthly'] == null &&
        answers['income_net_monthly'] == null) {
      return 'Revenu net mensuel/périodique';
    }
    if (answers['q_savings_monthly'] == null &&
        answers['savings_monthly'] == null) {
      return 'Épargne mensuelle';
    }

    // Dettes
    // If debt exists, we want details
    // If unknown, we want to know if it exists
    if (answers['q_has_consumer_debt'] == null &&
        answers['has_leasing'] == null) {
      return 'Dettes';
    }

    // Prévoyance
    if (answers['q_has_3a'] == null &&
        answers['has_3a'] == null &&
        answers['q_3a_accounts_count'] == null) {
      return 'Compte 3a';
    }

    // Objectif
    if (answers['q_main_goal'] == null && answers['primary_goal'] == null) {
      return 'Objectif principal';
    }

    return null;
  }
}

/// Widget pour afficher la progression de clarté
class ClarityProgressHeader extends StatelessWidget {
  final ClarityState state;

  const ClarityProgressHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: MintColors.white,
        border: Border(
          bottom: BorderSide(color: MintColors.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Précision : ${state.precisionIndex.toStringAsFixed(0)}%',
                    style: MintTextStyles.titleLarge(
                      color: state.precisionColor,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    state.precisionLabel,
                    style:
                        MintTextStyles.bodyMedium(color: state.precisionColor),
                  ),
                ],
              ),
              if (state.safeMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: MintColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MintColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield,
                          size: 16, color: MintColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        'Mode Protection',
                        style: MintTextStyles.labelMedium(
                                color: MintColors.warning)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: state.precisionIndex / 100,
              minHeight: 8,
              backgroundColor: MintColors.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(state.precisionColor),
            ),
          ),
          if (state.nextMostValuableInfo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.greenBgLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: MintColors.stressScenario.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 16, color: MintColors.stressScenario),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prochaine info la plus rentable : ${state.nextMostValuableInfo}',
                      style: MintTextStyles.labelMedium(
                              color: MintColors.stressScenario)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Actions prêtes : ${state.actionsReady}/${state.totalActions}',
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
