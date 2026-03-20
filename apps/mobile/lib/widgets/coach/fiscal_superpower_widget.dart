import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P9-C  Le Super-pouvoir fiscal enfant
//  Charte : L6 (Chiffre-choc) + L1 (CHF/mois)
//  Source : LIFD art. 213 (déduction 6'700/enfant)
//           OPP3 art. 1 (3a lié à l'enfant)
// ────────────────────────────────────────────────────────────

class FiscalSuperpower {
  const FiscalSuperpower({
    required this.label,
    required this.emoji,
    required this.annualDeduction,
    required this.taxSaving,
    required this.legalRef,
    this.note,
  });

  final String label;
  final String emoji;
  final double annualDeduction;
  final double taxSaving;
  final String legalRef;
  final String? note;
}

class FiscalSuperpowerWidget extends StatefulWidget {
  const FiscalSuperpowerWidget({
    super.key,
    required this.superpowers,
    this.taxRate = 0.25,
  });

  final List<FiscalSuperpower> superpowers;
  final double taxRate;

  @override
  State<FiscalSuperpowerWidget> createState() => _FiscalSuperpowerWidgetState();
}

class _FiscalSuperpowerWidgetState extends State<FiscalSuperpowerWidget> {
  int _children = 1;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  double get _totalSaving =>
      widget.superpowers.fold<double>(0, (s, p) => s + p.taxSaving) * _children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Super-pouvoir fiscal enfant déduction LIFD',
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
                  _buildChildrenSlider(),
                  const SizedBox(height: 16),
                  _buildSuperpowerList(),
                  const SizedBox(height: 16),
                  _buildTotalCallout(),
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
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🦸', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le super-pouvoir fiscal',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "L'État te rend de l'argent pour avoir un enfant.",
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nombre d\'enfants',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_children enfant${_children > 1 ? 's' : ''}',
                style: MintTextStyles.bodyMedium(color: MintColors.info).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        Slider(
          value: _children.toDouble(),
          min: 1,
          max: 4,
          divisions: 3,
          activeColor: MintColors.info,
          onChanged: (v) => setState(() => _children = v.round()),
        ),
      ],
    );
  }

  Widget _buildSuperpowerList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tes avantages fiscaux',
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...widget.superpowers.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Text(p.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.label,
                        style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Déduction : CHF ${_fmt(p.annualDeduction * _children)}/an · ${p.legalRef}',
                        style: MintTextStyles.micro(color: MintColors.textSecondary),
                      ),
                      if (p.note != null)
                        Text(
                          p.note!,
                          style: MintTextStyles.micro(color: MintColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '− CHF',
                      style: MintTextStyles.micro(color: MintColors.textSecondary),
                    ),
                    Text(
                      _fmt(p.taxSaving * _children),
                      style: MintTextStyles.titleMedium(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'd\'impôts/an',
                      style: MintTextStyles.micro(color: MintColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildTotalCallout() {
    final monthly = _totalSaving / 12;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.scoreExcellent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreExcellent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Économie totale avec $_children enfant${_children > 1 ? 's' : ''}',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'CHF ${_fmt(_totalSaving)}/an',
                  style: MintTextStyles.headlineMedium(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'soit CHF ${_fmt(monthly)}/mois remis dans ta poche',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
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
      'Outil éducatif · ne constitue pas un conseil fiscal au sens de la LSFin. '
      'Source : LIFD art. 213 (déductions enfants), OPP3 art. 1. '
      'Taux simulé à ${(widget.taxRate * 100).round()}% — varie selon commune et revenu.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
