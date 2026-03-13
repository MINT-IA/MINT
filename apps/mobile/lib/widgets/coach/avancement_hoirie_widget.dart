import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P8-E  L'Avancement d'hoirie — Film 2 actes donation
//  Charte : L2 (Avant/Après) + L4 (Raconte ne montre pas)
//  Source : CC art. 626 (rapport à la masse), CC art. 471
// ────────────────────────────────────────────────────────────

class HoirieChild {
  const HoirieChild({required this.name, required this.emoji});
  final String name;
  final String emoji;
}

class AvancementHoirieWidget extends StatelessWidget {
  const AvancementHoirieWidget({
    super.key,
    required this.totalPatrimoine,
    required this.donationAmount,
    required this.children,
    required this.donationRecipientIndex,
  });

  final double totalPatrimoine;
  final double donationAmount;
  final List<HoirieChild> children;
  final int donationRecipientIndex;

  @override
  Widget build(BuildContext context) {
    final n = children.length;
    // CC art. 626 : la donation est "rapportée" à la masse au décès.
    // totalPatrimoine est le patrimoine AVANT donation (ce que l'on possède aujourd'hui).
    // Masse de calcul = (totalPatrimoine - donationAmount) + donationAmount rapporté = totalPatrimoine.
    // Pas d'addition de donationAmount : ce serait un double-compte.
    final masseTotale = totalPatrimoine;
    final sharePerChild = masseTotale / n;
    final recipientAuDeces = sharePerChild - donationAmount;

    return Semantics(
      label: 'Avancement hoirie donation rapport succession',
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
                  _buildAct1(),
                  _buildArrow(),
                  _buildAct2(sharePerChild, recipientAuDeces),
                  const SizedBox(height: 16),
                  _buildNarrative(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎬', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'L\'avancement d\'hoirie',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ce que tu donnes aujourd\'hui sera déduit de la part à ton décès · CC art. 626',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAct1() {
    final recipient = children[donationRecipientIndex.clamp(0, children.length - 1)];
    return _buildActCard(
      actLabel: 'ACTE 1 · Aujourd\'hui',
      color: MintColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patrimoine total : ${formatChfWithPrefix(totalPatrimoine)}',
            style: GoogleFonts.inter(fontSize: 13, color: MintColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${recipient.emoji} ${recipient.name}', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'reçoit donation : ${formatChfWithPrefix(donationAmount)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Patrimoine restant : ${formatChfWithPrefix(totalPatrimoine - donationAmount)}',
            style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAct2(double sharePerChild, double recipientAuDeces) {
    return _buildActCard(
      actLabel: 'ACTE 2 · Au décès — rapport à la masse (CC art. 626)',
      color: MintColors.scoreAttention,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masse de calcul : ${formatChfWithPrefix(totalPatrimoine - donationAmount)} + ${formatChfWithPrefix(donationAmount)} (rapporté)',
            style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            '= ${formatChfWithPrefix(totalPatrimoine)} partagé en ${children.length}',
            style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ...children.asMap().entries.map((e) {
            final isRecipient = e.key == donationRecipientIndex.clamp(0, children.length - 1);
            final share = isRecipient ? (recipientAuDeces < 0 ? 0.0 : recipientAuDeces) : sharePerChild;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('${e.value.emoji} ${e.value.name}', style: const TextStyle(fontSize: 14)),
                  if (isRecipient) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.scoreAttention.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '(déjà reçu ${formatChfWithPrefix(donationAmount)})',
                        style: GoogleFonts.inter(fontSize: 10, color: MintColors.scoreAttention, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    formatChfWithPrefix(share),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isRecipient ? MintColors.scoreAttention : MintColors.scoreExcellent,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActCard({required String actLabel, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            actLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Icon(Icons.keyboard_arrow_down, color: MintColors.textSecondary, size: 28),
      ),
    );
  }

  Widget _buildNarrative() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ce que tu donnes sera déduit de sa part. '
              'L\'égalité entre héritiers est préservée — sauf clause d\'exonération de rapport.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : CC art. 626 (rapport), CC art. 471 (réserves).',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
