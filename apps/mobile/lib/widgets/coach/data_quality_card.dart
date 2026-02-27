import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  DATA QUALITY CARD — LOT 4 / Retirement Dashboard
// ────────────────────────────────────────────────────────────
//
//  Affiche les champs connus (coches vertes) et manquants (points ?).
//  CTA "Enrichir" avec estimation d'impact sur la precision.
//
//  Exemples :
//    knownFields  : ["AVS estimee : ~2'100/mois", "Canton : VD"]
//    missingFields: ["LPP : donnee manquante", "3a : donnee manquante"]
//    enrichImpact : "+15% precision"
//
//  Widget pur — aucune dependance Provider.
// ────────────────────────────────────────────────────────────

class DataQualityCard extends StatelessWidget {
  /// Champs renseignes (affichage avec icone validation).
  final List<String> knownFields;

  /// Champs manquants (affichage avec icone interrogation).
  final List<String> missingFields;

  /// Callback du bouton "Enrichir". Si null, navigue vers /onboarding/smart.
  final VoidCallback? onEnrich;

  /// Texte d'impact potentiel (ex. "+15% pr\u00e9cision"). Optionnel.
  final String? enrichImpact;

  const DataQualityCard({
    super.key,
    required this.knownFields,
    required this.missingFields,
    this.onEnrich,
    this.enrichImpact,
  });

  @override
  Widget build(BuildContext context) {
    // Ne rien afficher si tout est renseigne et aucun CTA utile
    if (knownFields.isEmpty && missingFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (knownFields.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSection(
              title: 'Donn\u00e9es connues',
              items: knownFields,
              isKnown: true,
            ),
          ],
          if (missingFields.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSection(
              title: 'Donn\u00e9es manquantes',
              items: missingFields,
              isKnown: false,
            ),
          ],
          if (missingFields.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildEnrichButton(context),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  HEADER
  // ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final hasGaps = missingFields.isNotEmpty;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: hasGaps
                ? MintColors.scoreAttention.withValues(alpha: 0.12)
                : MintColors.scoreExcellent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            hasGaps
                ? Icons.manage_search_outlined
                : Icons.check_circle_outline,
            color: hasGaps
                ? MintColors.scoreAttention
                : MintColors.scoreExcellent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qualit\u00e9 des donn\u00e9es',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                hasGaps
                    ? '${missingFields.length} information(s) \u00e0 ajouter'
                    : 'Profil complet',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (enrichImpact != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MintColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              enrichImpact!,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MintColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  SECTION
  // ────────────────────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required List<String> items,
    required bool isKnown,
  }) {
    final color =
        isKnown ? MintColors.scoreExcellent : MintColors.scoreAttention;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: MintColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isKnown
                ? MintColors.scoreExcellent.withValues(alpha: 0.04)
                : MintColors.scoreAttention.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: items
                .map((item) => _buildItem(
                      text: item,
                      isKnown: isKnown,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildItem({required String text, required bool isKnown}) {
    final color =
        isKnown ? MintColors.scoreExcellent : MintColors.scoreAttention;
    final icon = isKnown ? Icons.check_circle_outline : Icons.help_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isKnown
                    ? MintColors.textPrimary
                    : MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  ENRICH BUTTON
  // ────────────────────────────────────────────────────────────

  Widget _buildEnrichButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onEnrich ?? () => context.push('/onboarding/smart'),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(
          enrichImpact != null
              ? 'Enrichir mon profil ($enrichImpact)'
              : 'Enrichir mon profil',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.primary,
          side: const BorderSide(color: MintColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        ),
      ),
    );
  }
}
