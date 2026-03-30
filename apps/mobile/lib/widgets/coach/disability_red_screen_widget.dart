import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P4-C  L'Écran rouge de l'indépendant — filet vs vide
//  Charte : L6 (Chiffre-choc) + L4 (Raconte ne montre pas)
//  Source : LAMal art. 67-77, CO art. 324a, LAVS, LPP art. 23
// ────────────────────────────────────────────────────────────

class DisabilityRedScreenWidget extends StatefulWidget {
  const DisabilityRedScreenWidget({
    super.key,
    required this.monthlyExpenses,
    this.hasPerteDegain = false,
  });

  final double monthlyExpenses;
  final bool hasPerteDegain;

  @override
  State<DisabilityRedScreenWidget> createState() => _DisabilityRedScreenWidgetState();
}

class _DisabilityRedScreenWidgetState extends State<DisabilityRedScreenWidget> {
  int? _answer; // 0=oui, 1=non, 2=ne sais pas

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // Valeur illustrative : APG 80% + rente AI sur salaire médian CH (SFSO 2024 ~6'500/mois).
  // Varie selon salaire. Affiché avec ≈ pour indiquer l'ordre de grandeur.
  static const double _salarieMonthly = 4320;
  // Wired to social_insurance.dart (LAVS art. 34)
  static const double _aiRenteMax = aiRenteEntiere;
  // Wired to social_insurance.dart (LAI art. 28 + LPGA art. 19)
  static const int _aiDelayMonths = aiDecisionDelayMonths;

  @override
  Widget build(BuildContext context) {
    final emergencyNeeded = widget.monthlyExpenses * _aiDelayMonths;

    return Semantics(
      label: 'Écran rouge indépendant invalidité filet inexistant',
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
                  _buildComparisonTable(),
                  const SizedBox(height: 20),
                  _buildChiffreChoc(emergencyNeeded),
                  const SizedBox(height: 20),
                  _buildQuestion(),
                  if (_answer != null) _buildAnswerFeedback(),
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
        gradient: LinearGradient(
          colors: [
            MintColors.scoreCritique,
            MintColors.scoreCritique.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚨', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Indépendant·e : ton filet n\'existe pas',
                  style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Si tu ne peux plus travailler demain :',
            style: MintTextStyles.bodySmall(color: MintColors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Row(
      children: [
        Expanded(
          child: _buildColumn(
            title: 'Salarié·e',
            emoji: '👔',
            color: MintColors.scoreExcellent,
            items: const [
              'APG 80%',
              'LPP invalidité',
              'AI rente',
            ],
            totalMonthly: _salarieMonthly,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildColumn(
            title: 'Toi',
            emoji: '🧑‍💼',
            color: MintColors.scoreCritique,
            items: const [
              'RIEN',
              'pendant',
              '~14 mois',
            ],
            totalMonthly: 0,
            isVoid: true,
          ),
        ),
      ],
    );
  }

  Widget _buildColumn({
    required String title,
    required String emoji,
    required Color color,
    required List<String> items,
    required double totalMonthly,
    bool isVoid = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                title,
                style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isVoid ? MintColors.scoreCritique.withValues(alpha: 0.08) : MintColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    item,
                    style: MintTextStyles.labelSmall(color: isVoid ? MintColors.scoreCritique : MintColors.textPrimary).copyWith(fontSize: isVoid ? 16 : 12, fontWeight: isVoid ? FontWeight.w800 : FontWeight.w400),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isVoid ? '= 0 CHF/mois' : '\u2248 CHF ${_fmt(totalMonthly)}/mois',
            style: MintTextStyles.titleMedium(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc(double emergencyNeeded) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💰 Chiffre-choc : $_aiDelayMonths mois à 0 CHF.',
            style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Il te faudrait CHF ${_fmt(emergencyNeeded)} d\'épargne de sécurité '
            'pour tenir jusqu\'à la décision AI.',
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Après décision AI : CHF ${_fmt(_aiRenteMax)}/mois (AI seule)',
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'As-tu une assurance perte de gain ?',
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAnswerButton(0, 'Oui'),
              const SizedBox(width: 8),
              _buildAnswerButton(1, 'Non'),
              const SizedBox(width: 8),
              _buildAnswerButton(2, 'Je ne sais pas'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(int value, String label) {
    final isSelected = _answer == value;
    return GestureDetector(
      onTap: () => setState(() => _answer = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MintColors.primary : MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: MintTextStyles.bodySmall(color: isSelected ? MintColors.white : MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAnswerFeedback() {
    final (msg, color) = switch (_answer) {
      0 => ('Bien ! Vérifie que le délai de carence est inférieur à 30 jours.', MintColors.scoreExcellent),
      1 => ('Action prioritaire : compare 3 assurances perte de gain. Dès CHF 45/mois.', MintColors.scoreCritique),
      _ => ('Retrouve ton contrat ou contacte ta caisse de compensation.', MintColors.scoreAttention),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          msg,
          style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LAMal art. 67-77, CO art. 324a.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
