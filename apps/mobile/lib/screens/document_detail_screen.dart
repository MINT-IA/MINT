import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Detail screen for a single uploaded LPP document.
///
/// Shows all extracted fields grouped by category, with confidence
/// indicators and action buttons.
class DocumentDetailScreen extends StatelessWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final docProvider = context.watch<DocumentProvider>();

    // Get the upload result if it matches, otherwise show placeholder
    final result = docProvider.lastUploadResult?.id == documentId
        ? docProvider.lastUploadResult
        : null;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(context, s),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(MintSpacing.lg),
              child: result != null
                  ? _buildDetailContent(context, s, result, docProvider)
                  : _buildPlaceholder(s),
            ),
          ),
        ],
      ))),
    );
  }

  // ──────────────────────────────────────────────────────────
  // App Bar
  // ──────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, S s) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      title: Text(
        s.documentsLppCertificate,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Placeholder when detail is not available
  // ──────────────────────────────────────────────────────────

  Widget _buildPlaceholder(S s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(MintSpacing.lg),
              decoration: const BoxDecoration(
                color: MintColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined,
                  size: 48, color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.md + 4),
            Text(
              s.documentsEmpty,
              style: MintTextStyles.headlineMedium(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Detail Content
  // ──────────────────────────────────────────────────────────

  Widget _buildDetailContent(BuildContext context, S s,
      DocumentUploadResult result, DocumentProvider docProvider) {
    final lppFields = result.extractedFields.lpp;
    final confidence = (result.confidence * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with confidence
        MintEntrance(child: _buildConfidenceHeader(s, confidence, result)),
        const SizedBox(height: MintSpacing.lg + 4),

        // Category: Epargne
        MintEntrance(delay: const Duration(milliseconds: 100), child: _buildCategory(
          s,
          label: s.documentsCategoryEpargne,
          icon: Icons.savings_outlined,
          color: MintColors.success,
          fields: [
            _field(
              s.documentsFieldAvoirObligatoire,
              lppFields?.avoirObligatoire,
              s.documentDetailExplanationObligatoire,
            ),
            _field(
              s.documentsFieldAvoirSurobligatoire,
              lppFields?.avoirSurobligatoire,
              s.documentDetailExplanationSurobligatoire,
            ),
            _field(
              s.documentsFieldAvoirTotal,
              lppFields?.avoirVieillesseTotal,
              s.documentDetailExplanationTotal,
            ),
          ],
        )),
        const SizedBox(height: MintSpacing.lg),

        // Category: Salaire
        MintEntrance(delay: const Duration(milliseconds: 200), child: _buildCategory(
          s,
          label: s.documentsCategorySalaire,
          icon: Icons.account_balance_wallet_outlined,
          color: MintColors.info,
          fields: [
            _field(
              s.documentsFieldSalaireAssure,
              lppFields?.salaireAssure,
              s.documentDetailExplanationSalaireAssure,
            ),
            _field(
              s.documentsFieldSalaireAvs,
              lppFields?.salaireAvs,
              s.documentDetailExplanationSalaireAvs,
            ),
            _field(
              s.documentsFieldDeductionCoordination,
              lppFields?.deductionCoordination,
              s.documentDetailExplanationDeduction,
            ),
          ],
        )),
        const SizedBox(height: MintSpacing.lg),

        // Category: Taux de conversion
        MintEntrance(delay: const Duration(milliseconds: 300), child: _buildCategory(
          s,
          label: s.documentsCategoryTaux,
          icon: Icons.percent,
          color: MintColors.indigo,
          fields: [
            _fieldPercent(
              s.documentsFieldTauxObligatoire,
              lppFields?.tauxConversionObligatoire,
              s.documentDetailExplanationTauxOblig,
            ),
            _fieldPercent(
              s.documentsFieldTauxSurobligatoire,
              lppFields?.tauxConversionSurobligatoire,
              s.documentDetailExplanationTauxSurob,
            ),
            _fieldPercent(
              s.documentsFieldTauxEnveloppe,
              lppFields?.tauxConversionEnveloppe,
              s.documentDetailExplanationTauxEnv,
            ),
          ],
        )),
        const SizedBox(height: MintSpacing.lg),

        // Category: Couverture risque
        MintEntrance(delay: const Duration(milliseconds: 400), child: _buildCategory(
          s,
          label: s.documentsCategoryRisque,
          icon: Icons.shield_outlined,
          color: MintColors.deepOrange,
          fields: [
            _fieldYearly(
              s.documentsFieldRenteInvalidite,
              lppFields?.renteInvalidite,
              s.documentDetailExplanationInvalidite,
            ),
            _field(
              s.documentsFieldCapitalDeces,
              lppFields?.capitalDeces,
              s.documentDetailExplanationDeces,
            ),
            _fieldYearly(
              s.documentsFieldRenteConjoint,
              lppFields?.renteConjoint,
              s.documentDetailExplanationConjoint,
            ),
            _fieldYearly(
              s.documentsFieldRenteEnfant,
              lppFields?.renteEnfant,
              s.documentDetailExplanationEnfant,
            ),
          ],
        )),
        const SizedBox(height: MintSpacing.lg),

        // Category: Rachat
        _buildCategory(
          s,
          label: s.documentsCategoryRachat,
          icon: Icons.add_circle_outline,
          color: MintColors.primary,
          fields: [
            _field(
              s.documentsFieldRachatMax,
              lppFields?.rachatMaximum,
              s.documentDetailExplanationRachat,
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.lg),

        // Category: Cotisations
        _buildCategory(
          s,
          label: s.documentsCategoryCotisations,
          icon: Icons.sync_alt,
          color: MintColors.warning,
          fields: [
            _fieldYearly(
              s.documentsFieldCotisationEmploye,
              lppFields?.cotisationEmploye,
              s.documentDetailExplanationEmploye,
            ),
            _fieldYearly(
              s.documentsFieldCotisationEmployeur,
              lppFields?.cotisationEmployeur,
              s.documentDetailExplanationEmployeur,
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.xl),

        // Warnings
        if (result.warnings.isNotEmpty) ...[
          _buildWarnings(s, result.warnings),
          const SizedBox(height: MintSpacing.lg),
        ],

        // Action buttons
        Semantics(
          button: true,
          label: s.documentsConfirmButton,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(s.documentDetailProfileUpdated),
                  backgroundColor: MintColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
              safePop(context);
            },
            child: Text(
              s.documentsConfirmButton,
            ),
          ),
        ),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        Center(
          child: TextButton.icon(
            onPressed: () => _confirmDelete(context, s, docProvider),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(s.documentsDeleteButton),
            style: TextButton.styleFrom(foregroundColor: MintColors.error),
          ),
        ),
        const SizedBox(height: MintSpacing.xxl),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // Confidence Header
  // ──────────────────────────────────────────────────────────

  Widget _buildConfidenceHeader(
      S s, int confidence, DocumentUploadResult result) {
    final Color color;
    if (confidence >= 80) {
      color = MintColors.success;
    } else if (confidence >= 50) {
      color = MintColors.warning;
    } else {
      color = MintColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
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
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.documentsLppCertificate,
                  style: MintTextStyles.titleMedium(),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  s.documentDetailFieldsExtracted(result.fieldsFound, result.fieldsTotal),
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
    S s, {
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
              padding: const EdgeInsets.all(MintSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        for (final field in activeFields) _buildFieldCard(field),
      ],
    );
  }

  Widget _buildFieldCard(_FieldEntry field) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  field.label,
                  style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
                ),
              ),
              Text(
                field.formattedValue,
                style: MintTextStyles.titleMedium(),
              ),
            ],
          ),
          if (field.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              field.explanation,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Warnings
  // ──────────────────────────────────────────────────────────

  Widget _buildWarnings(S s, List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
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
              const SizedBox(width: MintSpacing.sm),
              Text(
                s.documentsWarningsTitle,
                style: MintTextStyles.bodySmall(color: MintColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\u2022 ',
                      style: TextStyle(
                          color: MintColors.warning.withValues(alpha: 0.7))),
                  Expanded(
                    child: Text(
                      w,
                      style: MintTextStyles.bodySmall(color: MintColors.warning),
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
      BuildContext context, S s, DocumentProvider docProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.documentsDeleteTitle),
        content: Text(s.documentsDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.documentDetailCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: MintColors.error),
            child: Text(s.documentsDeleteButton),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success = await docProvider.deleteDocument(documentId);
      if (success && context.mounted) {
        safePop(context);
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
