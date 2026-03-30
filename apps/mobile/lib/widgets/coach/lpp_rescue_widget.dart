import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P7-D  Opération sauvetage 2e pilier — 30 jours chrono
//  Charte : L5 (1 action) + L6 (Chiffre-choc)
//  Source : LFLP art. 3-4, OPP2 art. 10
// ────────────────────────────────────────────────────────────

class LppTransferOption {
  const LppTransferOption({
    required this.label,
    required this.emoji,
    required this.description,
    required this.fiveYearGain,
    this.recommended = false,
    this.legalRef,
  });

  final String label;
  final String emoji;
  final String description;
  final double fiveYearGain;
  final bool recommended;
  final String? legalRef;
}

class LppRescueWidget extends StatelessWidget {
  const LppRescueWidget({
    super.key,
    required this.lppBalance,
    required this.options,
    this.daysElapsed = 0,
  });

  final double lppBalance;
  final List<LppTransferOption> options;
  final int daysElapsed;

  // Délai pédagogique d'action recommandé (urgence). Le délai légal LFLP art. 4
  // est de 6 mois avant transfert automatique à l'institution supplétive.
  static const int _actionDays = 30;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = (_actionDays - daysElapsed).clamp(0, _actionDays);
    final urgencyColor = daysLeft > 14
        ? MintColors.scoreExcellent
        : daysLeft > 7
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    return Semantics(
      label: 'Sauvetage LPP 2e pilier libre passage',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(daysLeft, urgencyColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceChip(),
                  const SizedBox(height: 20),
                  ...options.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildOptionCard(e.value, e.key),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildChiffreChoc(),
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

  Widget _buildHeader(int daysLeft, Color urgencyColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: urgencyColor.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚑', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Opération sauvetage 2e pilier',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: urgencyColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, color: urgencyColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Il te reste $daysLeft jours pour agir',
                  style: MintTextStyles.bodySmall(color: urgencyColor).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined, color: MintColors.info, size: 18),
          const SizedBox(width: 10),
          Text(
            'Ton avoir LPP : CHF ${_fmt(lppBalance)}',
            style: MintTextStyles.bodyMedium(color: MintColors.info).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(LppTransferOption option, int index) {
    // isWorst: seule la première option avec le gain minimum est marquée "pire".
    // Garde : options.length > 1 pour éviter de marquer l'unique option comme pire.
    final worstOption = options.length > 1
        ? options.reduce((a, b) => a.fiveYearGain <= b.fiveYearGain ? a : b)
        : null;
    final isWorst = worstOption != null &&
        identical(option, worstOption) &&
        !option.recommended;

    Color borderColor = MintColors.lightBorder;
    Color? bgColor;
    if (option.recommended) {
      borderColor = MintColors.scoreExcellent;
      bgColor = MintColors.scoreExcellent.withValues(alpha: 0.05);
    } else if (isWorst) {
      borderColor = MintColors.scoreCritique.withValues(alpha: 0.4);
      bgColor = MintColors.scoreCritique.withValues(alpha: 0.03);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: option.recommended ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Option ${index + 1} : ${option.label}',
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (option.recommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: MintColors.scoreExcellent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Recommandé',
                    style: MintTextStyles.micro(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            option.description,
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.5),
          ),
          if (option.fiveYearGain != 0) ...[
            const SizedBox(height: 8),
            Text(
              option.fiveYearGain > 0
                  ? '+CHF ${_fmt(option.fiveYearGain)} sur 5 ans'
                  : '-CHF ${_fmt(option.fiveYearGain.abs())} sur 5 ans',
              style: MintTextStyles.bodySmall(color: option.fiveYearGain > 0 ? MintColors.scoreExcellent : MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (option.legalRef != null) ...[
            const SizedBox(height: 4),
            Text(
              option.legalRef!,
              style: MintTextStyles.micro(color: MintColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChiffreChoc() {
    // Estimation pédagogique : surcoût institutionnel ~1.5 % du solde sur 5 ans
    // (taux technique bas + frais de gestion suppl.). Source : CHS PP rapports.
    final estimatedLoss = (lppBalance * 0.015).clamp(500.0, 15000.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💸', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ne rien faire = institution supplétive',
                  style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Le taux technique est bas et les frais élevés. '
                  'Un avoir de CHF ${_fmt(lppBalance)} peut perdre jusqu\'à '
                  'CHF ${_fmt(estimatedLoss)} sur 5 ans vs un compte libre passage optimisé.',
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LFLP art. 3-4, OPP2 art. 10. Délai légal de transfert : 6 mois (LFLP art. 4). '
      'Avoirs oubliés : sfbvg.ch.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
