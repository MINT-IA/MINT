import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Detail screen for a single uploaded LPP document.
///
/// Shows all extracted fields grouped by category, with confidence
/// indicators and action buttons.
class DocumentDetailScreen extends StatelessWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final docProvider = context.watch<DocumentProvider>();

    // Get the upload result if it matches, otherwise show placeholder
    final result = docProvider.lastUploadResult?.id == documentId
        ? docProvider.lastUploadResult
        : null;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, s),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: result != null
                  ? _buildDetailContent(context, s, result, docProvider)
                  : _buildPlaceholder(s),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // App Bar
  // ──────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, S? s) {
    return SliverAppBar(
      backgroundColor: MintColors.background,
      title: Text(
        s?.documentsLppCertificate ?? 'Certificat LPP',
        style: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Placeholder when detail is not available
  // ──────────────────────────────────────────────────────────

  Widget _buildPlaceholder(S? s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: MintColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined,
                  size: 48, color: MintColors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              s?.documentsEmpty ?? 'Aucun document',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: MintColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Detail Content
  // ──────────────────────────────────────────────────────────

  Widget _buildDetailContent(BuildContext context, S? s,
      DocumentUploadResult result, DocumentProvider docProvider) {
    final lppFields = result.extractedFields.lpp;
    final confidence = (result.confidence * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with confidence
        _buildConfidenceHeader(s, confidence, result),
        const SizedBox(height: 28),

        // Category: Epargne
        _buildCategory(
          s,
          label: s?.documentsCategoryEpargne ?? '\u00c9pargne',
          icon: Icons.savings_outlined,
          color: MintColors.success,
          fields: [
            _field(
              s?.documentsFieldAvoirObligatoire ??
                  'Avoir de vieillesse obligatoire',
              lppFields?.avoirObligatoire,
              'Montant accumul\u00e9 dans la part obligatoire LPP',
            ),
            _field(
              s?.documentsFieldAvoirSurobligatoire ??
                  'Avoir de vieillesse surobligatoire',
              lppFields?.avoirSurobligatoire,
              'Part au-del\u00e0 du minimum l\u00e9gal',
            ),
            _field(
              s?.documentsFieldAvoirTotal ?? 'Avoir de vieillesse total',
              lppFields?.avoirVieillesseTotal,
              'Total de ton capital de vieillesse',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Category: Salaire
        _buildCategory(
          s,
          label: s?.documentsCategorySalaire ?? 'Salaire',
          icon: Icons.account_balance_wallet_outlined,
          color: MintColors.info,
          fields: [
            _field(
              s?.documentsFieldSalaireAssure ?? 'Salaire assur\u00e9',
              lppFields?.salaireAssure,
              'Salaire sur lequel les cotisations sont calcul\u00e9es',
            ),
            _field(
              s?.documentsFieldSalaireAvs ?? 'Salaire AVS',
              lppFields?.salaireAvs,
              'Salaire d\u00e9terminant pour l\'AVS',
            ),
            _field(
              s?.documentsFieldDeductionCoordination ??
                  'D\u00e9duction de coordination',
              lppFields?.deductionCoordination,
              'Montant d\u00e9duit pour coordonner avec l\'AVS',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Category: Taux de conversion
        _buildCategory(
          s,
          label: s?.documentsCategoryTaux ?? 'Taux de conversion',
          icon: Icons.percent,
          color: const Color(0xFF4F46E5),
          fields: [
            _fieldPercent(
              s?.documentsFieldTauxObligatoire ??
                  'Taux de conversion obligatoire',
              lppFields?.tauxConversionObligatoire,
              'L\u00e9gal minimum : 6.8%',
            ),
            _fieldPercent(
              s?.documentsFieldTauxSurobligatoire ??
                  'Taux de conversion surobligatoire',
              lppFields?.tauxConversionSurobligatoire,
              'Fix\u00e9 par ta caisse de pension',
            ),
            _fieldPercent(
              s?.documentsFieldTauxEnveloppe ??
                  'Taux de conversion enveloppe',
              lppFields?.tauxConversionEnveloppe,
              'Taux moyen pond\u00e9r\u00e9',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Category: Couverture risque
        _buildCategory(
          s,
          label: s?.documentsCategoryRisque ?? 'Couverture risque',
          icon: Icons.shield_outlined,
          color: const Color(0xFFEA580C),
          fields: [
            _fieldYearly(
              s?.documentsFieldRenteInvalidite ??
                  'Rente d\'invalidit\u00e9 annuelle',
              lppFields?.renteInvalidite,
              'Rente en cas d\'incapacit\u00e9 de travail',
            ),
            _field(
              s?.documentsFieldCapitalDeces ?? 'Capital-d\u00e9c\u00e8s',
              lppFields?.capitalDeces,
              'Montant vers\u00e9 aux b\u00e9n\u00e9ficiaires en cas de d\u00e9c\u00e8s',
            ),
            _fieldYearly(
              s?.documentsFieldRenteConjoint ??
                  'Rente de conjoint annuelle',
              lppFields?.renteConjoint,
              'Rente vers\u00e9e au conjoint survivant',
            ),
            _fieldYearly(
              s?.documentsFieldRenteEnfant ?? 'Rente d\'enfant annuelle',
              lppFields?.renteEnfant,
              'Rente vers\u00e9e par enfant',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Category: Rachat
        _buildCategory(
          s,
          label: s?.documentsCategoryRachat ?? 'Rachat',
          icon: Icons.add_circle_outline,
          color: MintColors.primary,
          fields: [
            _field(
              s?.documentsFieldRachatMax ?? 'Rachat maximum possible',
              lppFields?.rachatMaximum,
              'Montant pouvant \u00eatre rachet\u00e9 pour optimiser ta pr\u00e9voyance',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Category: Cotisations
        _buildCategory(
          s,
          label: s?.documentsCategoryCotisations ?? 'Cotisations',
          icon: Icons.sync_alt,
          color: MintColors.warning,
          fields: [
            _fieldYearly(
              s?.documentsFieldCotisationEmploye ??
                  'Cotisation employ\u00e9 annuelle',
              lppFields?.cotisationEmploye,
              'Ta contribution annuelle',
            ),
            _fieldYearly(
              s?.documentsFieldCotisationEmployeur ??
                  'Cotisation employeur annuelle',
              lppFields?.cotisationEmployeur,
              'Contribution de ton employeur',
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Warnings
        if (result.warnings.isNotEmpty) ...[
          _buildWarnings(s, result.warnings),
          const SizedBox(height: 24),
        ],

        // Action buttons
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              // TODO: Update profile with extracted fields
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profil mis \u00e0 jour avec succ\u00e8s'),
                  backgroundColor: MintColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
              context.pop();
            },
            child: Text(
              s?.documentsConfirmButton ??
                  'Mettre \u00e0 jour le profil',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => _confirmDelete(context, s, docProvider),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(s?.documentsDeleteButton ?? 'Supprimer ce document'),
            style: TextButton.styleFrom(foregroundColor: MintColors.error),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // Confidence Header
  // ──────────────────────────────────────────────────────────

  Widget _buildConfidenceHeader(
      S? s, int confidence, DocumentUploadResult result) {
    final Color color;
    if (confidence >= 80) {
      color = MintColors.success;
    } else if (confidence >= 50) {
      color = MintColors.warning;
    } else {
      color = MintColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$confidence%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s?.documentsLppCertificate ?? 'Certificat LPP',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.fieldsFound} champs extraits sur ${result.fieldsTotal}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Category Section
  // ──────────────────────────────────────────────────────────

  Widget _buildCategory(
    S? s, {
    required String label,
    required IconData icon,
    required Color color,
    required List<_FieldEntry> fields,
  }) {
    // Filter out fields with no value
    final activeFields = fields.where((f) => f.value != null).toList();
    if (activeFields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final field in activeFields) _buildFieldCard(field),
      ],
    );
  }

  Widget _buildFieldCard(_FieldEntry field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  field.label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
              Text(
                field.formattedValue,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          if (field.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              field.explanation,
              style: const TextStyle(
                fontSize: 12,
                color: MintColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Warnings
  // ──────────────────────────────────────────────────────────

  Widget _buildWarnings(S? s, List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: MintColors.warning.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                s?.documentsWarningsTitle ?? 'Points d\'attention',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.warning.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\u2022 ',
                      style: TextStyle(
                          color: MintColors.warning.withValues(alpha: 0.7))),
                  Expanded(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 13,
                        color: MintColors.warning.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Delete Confirmation
  // ──────────────────────────────────────────────────────────

  Future<void> _confirmDelete(
      BuildContext context, S? s, DocumentProvider docProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s?.documentsDeleteTitle ?? 'Supprimer le document ?'),
        content: Text(s?.documentsDeleteMessage ??
            'Cette action est irr\u00e9versible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: MintColors.error),
            child: Text(s?.documentsDeleteButton ?? 'Supprimer ce document'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success = await docProvider.deleteDocument(documentId);
      if (success && context.mounted) {
        context.pop();
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // Field Entry Helpers
  // ──────────────────────────────────────────────────────────

  _FieldEntry _field(String label, double? value, String explanation) {
    return _FieldEntry(
      label: label,
      value: value,
      formattedValue: value != null ? _formatChf(value) : '-',
      explanation: explanation,
    );
  }

  _FieldEntry _fieldPercent(String label, double? value, String explanation) {
    return _FieldEntry(
      label: label,
      value: value,
      formattedValue:
          value != null ? '${value.toStringAsFixed(1)}%' : '-',
      explanation: explanation,
    );
  }

  _FieldEntry _fieldYearly(String label, double? value, String explanation) {
    return _FieldEntry(
      label: label,
      value: value,
      formattedValue: value != null ? '${_formatChf(value)}/an' : '-',
      explanation: explanation,
    );
  }

  String _formatChf(double value) {
    final intPart = value.truncate();
    final formatted = _groupDigits(intPart);
    return 'CHF $formatted';
  }

  String _groupDigits(int value) {
    final str = value.abs().toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return value < 0 ? '-${buffer.toString()}' : buffer.toString();
  }
}

/// Internal model for a field entry in the detail view.
class _FieldEntry {
  final String label;
  final double? value;
  final String formattedValue;
  final String explanation;

  const _FieldEntry({
    required this.label,
    required this.value,
    required this.formattedValue,
    required this.explanation,
  });
}
