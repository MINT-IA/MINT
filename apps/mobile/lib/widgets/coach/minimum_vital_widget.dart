import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P10-C  LP art. 93 — Insaisissable : ton bouclier légal
//  Charte : L6 (Chiffre-choc) + L5 (1 action)
//  Source : LP art. 93 (minimum vital), LP art. 92 (biens insaisissables)
// ────────────────────────────────────────────────────────────

class MinimumVitalItem {
  const MinimumVitalItem({
    required this.label,
    required this.emoji,
    required this.amount,
    required this.legalRef,
    this.note,
  });

  final String label;
  final String emoji;
  final double amount;
  final String legalRef;
  final String? note;
}

class MinimumVitalWidget extends StatelessWidget {
  const MinimumVitalWidget({
    super.key,
    required this.items,
    required this.grossMonthly,
    required this.totalDebts,
    this.hasChildren = false,
    this.childrenCount = 0,
  });

  final List<MinimumVitalItem> items;
  final double grossMonthly;
  final double totalDebts;
  final bool hasChildren;
  final int childrenCount;

  double get _totalProtected =>
      items.fold<double>(0, (s, i) => s + i.amount);

  double get _seizable => (grossMonthly - _totalProtected).clamp(0, grossMonthly);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Minimum vital LP art 93 bouclier légal insaisissable',
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
                  _buildShield(),
                  const SizedBox(height: 16),
                  _buildItemList(),
                  const SizedBox(height: 16),
                  _buildSeizableBar(),
                  const SizedBox(height: 16),
                  _buildAction(),
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
      decoration: const BoxDecoration(
        color: MintColors.successBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('🛡️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ton bouclier légal',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'LP art. 93 — Ce que tes créanciers ne peuvent PAS toucher',
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShield() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.scoreExcellent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreExcellent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minimum vital protégé',
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
                ),
                Text(
                  '${formatChfWithPrefix(_totalProtected)}/mois',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: MintColors.scoreExcellent,
                  ),
                ),
                Text(
                  'Légalement insaisissable · LP art. 93',
                  style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Saisissable',
                style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary),
              ),
              Text(
                formatChfWithPrefix(_seizable),
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _seizable > 0 ? MintColors.scoreAttention : MintColors.scoreExcellent,
                ),
              ),
              Text(
                '/mois max',
                style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Composantes du minimum vital',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MintColors.scoreExcellent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(item.emoji, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: GoogleFonts.inter(fontSize: 13, color: MintColors.textPrimary),
                    ),
                    Text(
                      '${item.legalRef}${item.note != null ? ' · ${item.note}' : ''}',
                      style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                formatChfWithPrefix(item.amount),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.scoreExcellent,
                ),
              ),
            ],
          ),
        )),
        if (hasChildren && childrenCount > 0) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MintColors.scoreExcellent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('👶', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enfants ($childrenCount)',
                        style: GoogleFonts.inter(fontSize: 13, color: MintColors.textPrimary),
                      ),
                      Text(
                        'LP art. 93 al. 1 lit. a — besoins enfants',
                        style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Inclus',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.scoreExcellent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSeizableBar() {
    final fraction = grossMonthly > 0 ? _seizable / grossMonthly : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Salaire brut : ${formatChfWithPrefix(grossMonthly)}/mois',
              style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
            ),
            Text(
              '${(fraction * 100).round()}% saisissable',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fraction > 0.4 ? MintColors.scoreCritique : MintColors.scoreAttention,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              LinearProgressIndicator(
                value: 1.0,
                minHeight: 14,
                backgroundColor: MintColors.scoreExcellent.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  MintColors.scoreExcellent.withValues(alpha: 0.3),
                ),
              ),
              LinearProgressIndicator(
                value: fraction,
                minHeight: 14,
                backgroundColor: MintColors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(MintColors.scoreAttention),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '🟢 Protégé : ${formatChfWithPrefix(_totalProtected)}',
              style: GoogleFonts.inter(fontSize: 10, color: MintColors.scoreExcellent),
            ),
            Text(
              '🟠 Saisissable : ${formatChfWithPrefix(_seizable)}',
              style: GoogleFonts.inter(fontSize: 10, color: MintColors.scoreAttention),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAction() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Si un créancier saisit plus que la limite',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.info,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contacte un·e avocat·e ou le service des poursuites de ta commune. '
                  'La LP art. 93 est impérative — aucun contrat ne peut y déroger.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
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
      'Outil éducatif · ne constitue pas un conseil juridique au sens de la LSFin. '
      'Source : LP art. 92 (biens insaisissables), LP art. 93 (minimum vital). '
      'Les montants varient selon le canton et la situation familiale.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
