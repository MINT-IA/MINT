import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/coach_paywall_sheet.dart';

/// "Coffre-fort" (Document Vault) screen.
///
/// Centralises all financial documents: LPP certificates, salary certificates,
/// 3a attestations, insurance policies, leases, LAMal statements.
/// Includes legal guidance cards and premium gating.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  /// Maximum documents for free-tier users.
  static const int _freeDocLimit = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final docProvider = context.watch<DocumentProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final totalDocs = docProvider.documentCount;

    return Scaffold(
      backgroundColor: MintColors.background,
      floatingActionButton: Semantics(
        label: s.vaultUploadButton,
        button: true,
        child: FloatingActionButton(
          onPressed: () => _showUploadTypeSheet(s),
          backgroundColor: MintColors.primary,
          child: const Icon(Icons.add_rounded, color: MintColors.white, size: 28),
        ),
      ),
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.vaultTitle,
          style: MintTextStyles.headlineMedium(),
        ),
        actions: [
          if (sub.isCoach)
            Container(
              margin: const EdgeInsets.only(right: MintSpacing.md),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: MintColors.primary, size: 16),
                  const SizedBox(width: MintSpacing.xs),
                  Text(
                    s.vaultPremiumBadge,
                    style: MintTextStyles.labelSmall(color: MintColors.primary),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 22, color: MintColors.textMuted),
            onPressed: () => _showInfoDialog(),
          ),
          const SizedBox(width: MintSpacing.sm),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header card
            _buildHeaderCard(s, totalDocs),
            const SizedBox(height: MintSpacing.lg),

            // 2. Category grid
            _buildCategoryGrid(s, docProvider),
            const SizedBox(height: MintSpacing.xl),

            // 3. Legal guidance section
            _buildGuidanceSection(s),
            const SizedBox(height: MintSpacing.xl),

            // Uploading indicator
            if (docProvider.isUploading) ...[
              _buildUploadingIndicator(s),
              const SizedBox(height: MintSpacing.lg),
            ],

            // Error display
            if (docProvider.error != null) ...[
              _buildErrorCard(docProvider),
              const SizedBox(height: MintSpacing.lg),
            ],

            // Last upload result
            if (docProvider.lastUploadResult != null &&
                !docProvider.isUploading) ...[
              _buildResultSection(s, docProvider.lastUploadResult!),
              const SizedBox(height: MintSpacing.lg),
            ],

            // 4. Documents list
            _buildDocumentsList(s, docProvider, sub),
            const SizedBox(height: MintSpacing.lg),

            // Bank import card (kept as fallback)
            _buildBankImportCard(s),
            const SizedBox(height: MintSpacing.lg),

            // Privacy footer
            _buildPrivacyFooter(s),
            const SizedBox(height: MintSpacing.md),

            // Disclaimer (compliance — mandatory)
            _buildDisclaimer(s),
            const SizedBox(height: MintSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 2. Header Card — standard card (no glassmorphism)
  // ──────────────────────────────────────────────────────────

  Widget _buildHeaderCard(S s, int totalDocs) {
    // Compute confidence choc: rough heuristic
    final confidencePct = totalDocs >= 6 ? 95 : (totalDocs * 15).clamp(0, 90);

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_outline,
                    color: MintColors.primary, size: 28),
              ),
              const SizedBox(width: MintSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.vaultHeaderTitle,
                      style: MintTextStyles.headlineLarge().copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      s.vaultHeaderSubtitle,
                      style: MintTextStyles.bodyMedium(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          // Chiffre-choc: X documents = Y% confiance
          Semantics(
            label: s.documentsConfidenceChoc(totalDocs.toString(), confidencePct.toString()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: MintSpacing.sm),
              decoration: BoxDecoration(
                color: MintColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_outlined,
                      color: MintColors.info, size: 18),
                  const SizedBox(width: MintSpacing.sm),
                  Text(
                    s.documentsConfidenceChoc(totalDocs.toString(), confidencePct.toString()),
                    style: MintTextStyles.bodySmall(color: MintColors.info),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 3. Category Grid — 2-column grid of tappable category cards
  // ──────────────────────────────────────────────────────────

  Widget _buildCategoryGrid(S s, DocumentProvider docProvider) {
    final categories = _getCategoryDefinitions(s);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MintSpacing.sm,
        mainAxisSpacing: MintSpacing.sm,
        childAspectRatio: 1.4,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final count = _countDocumentsOfType(docProvider, cat.type);
        return _buildCategoryCard(
            s, cat.type, cat.icon, cat.color, count, cat.label);
      },
    );
  }

  Widget _buildCategoryCard(
    S s,
    VaultDocumentType type,
    IconData icon,
    Color color,
    int count,
    String label,
  ) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: () => _pickAndUpload(type),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MintColors.border),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              count > 0
                  ? s.vaultCategoryCount(count.toString())
                  : s.vaultCategoryNone,
              style: MintTextStyles.labelSmall(
                color: count > 0 ? color : MintColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 4. Legal Guidance Section
  // ──────────────────────────────────────────────────────────

  Widget _buildGuidanceSection(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.vaultGuidanceTitle,
          style: MintTextStyles.labelSmall(),
        ),
        const SizedBox(height: MintSpacing.md),

        // a) Bail
        _buildGuidanceCard(
          s,
          icon: Icons.home_outlined,
          title: s.vaultGuidanceLeaseTitle,
          body: s.vaultGuidanceLeaseBody,
          source: s.vaultGuidanceLeaseSource,
        ),
        const SizedBox(height: MintSpacing.sm),

        // b) Assurances
        _buildGuidanceCard(
          s,
          icon: Icons.health_and_safety_outlined,
          title: s.vaultGuidanceInsuranceTitle,
          body: s.vaultGuidanceInsuranceBody,
          source: s.vaultGuidanceInsuranceSource,
        ),
        const SizedBox(height: MintSpacing.sm),

        // c) LAMal
        _buildGuidanceCard(
          s,
          icon: Icons.local_hospital_outlined,
          title: s.vaultGuidanceLamalTitle,
          body: s.vaultGuidanceLamalBody,
          source: s.vaultGuidanceLamalSource,
        ),
        const SizedBox(height: MintSpacing.sm),

        // d) Salaire
        _buildGuidanceCard(
          s,
          icon: Icons.payments_outlined,
          title: s.vaultGuidanceSalaryTitle,
          body: s.vaultGuidanceSalaryBody,
          source: s.vaultGuidanceSalarySource,
        ),
      ],
    );
  }

  Widget _buildGuidanceCard(
    S s, {
    required IconData icon,
    required String title,
    required String body,
    required String source,
  }) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(MintSpacing.sm),
                decoration: BoxDecoration(
                  color: MintColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: MintColors.info, size: 20),
              ),
              const SizedBox(width: MintSpacing.sm),
              const Icon(Icons.school_outlined,
                  color: MintColors.info, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            body,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            source,
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 5. Documents List
  // ──────────────────────────────────────────────────────────

  Widget _buildDocumentsList(
      S s, DocumentProvider docProvider, SubscriptionProvider sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.vaultDocListTitle,
          style: MintTextStyles.labelSmall(),
        ),
        const SizedBox(height: MintSpacing.sm),
        if (docProvider.documents.isEmpty)
          _buildEmptyState(s)
        else ...[
          // Group documents by type, show limited for free users
          ..._buildGroupedDocuments(s, docProvider, sub),

          // Premium upsell if free user has reached limit
          if (!sub.isCoach &&
              docProvider.documents.length >= _freeDocLimit) ...[
            const SizedBox(height: MintSpacing.md),
            _buildPremiumUpsellCard(s),
          ],
        ],
      ],
    );
  }

  List<Widget> _buildGroupedDocuments(
      S s, DocumentProvider docProvider, SubscriptionProvider sub) {
    final docs = sub.isCoach
        ? docProvider.documents
        : docProvider.documents.take(_freeDocLimit).toList();

    // Group by document type
    final grouped = <VaultDocumentType, List<DocumentSummary>>{};
    for (final doc in docs) {
      grouped.putIfAbsent(doc.documentType, () => []).add(doc);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      // Group header
      final typeLabel = _labelForType(s, entry.key);
      final typeIcon = _iconForType(entry.key);
      final typeColor = _colorForType(entry.key);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: MintSpacing.sm, top: MintSpacing.sm),
          child: Row(
            children: [
              Icon(typeIcon, size: 16, color: typeColor),
              const SizedBox(width: MintSpacing.sm),
              Text(
                typeLabel,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
            ],
          ),
        ),
      );

      for (final doc in entry.value) {
        widgets.add(_buildDocumentListItem(s, doc, docProvider));
      }
    }

    return widgets;
  }

  Widget _buildDocumentListItem(
      S s, DocumentSummary doc, DocumentProvider docProvider) {
    final typeLabel = _labelForType(s, doc.documentType);
    final typeIcon = _iconForType(doc.documentType);
    final typeColor = _colorForType(doc.documentType);
    final confidence = (doc.confidence * 100).round();
    final dateStr =
        '${doc.uploadDate.day}.${doc.uploadDate.month.toString().padLeft(2, '0')}.${doc.uploadDate.year}';

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteDialog(s, doc.id, docProvider),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: MintSpacing.lg),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: MintColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: MintColors.error),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          label: typeLabel,
          button: true,
          child: InkWell(
            onTap: () => context.push('/documents/${doc.id}'),
            borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: MintTextStyles.labelSmall(),
                          ),
                          const SizedBox(width: MintSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: MintSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: _confidenceColor(confidence)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              s.vaultConfidence(confidence.toString()),
                              style: MintTextStyles.labelSmall(
                                color: _confidenceColor(confidence),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmDelete(s, doc.id, docProvider),
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: MintColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(S s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MintSpacing.xl),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_outlined,
              size: 48, color: MintColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: MintSpacing.md),
          Text(
            s.vaultEmptyTitle,
            style: MintTextStyles.headlineMedium().copyWith(fontSize: 18),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            s.documentsEmptyVoice,
            textAlign: TextAlign.center,
            style: MintTextStyles.bodyMedium(),
          ),
          const SizedBox(height: MintSpacing.lg),
          FilledButton.icon(
            onPressed: () => _showUploadTypeSheet(s),
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              s.vaultUploadButton,
              style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumUpsellCard(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MintColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_open_rounded,
                    color: MintColors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  s.vaultPremiumTitle,
                  style: MintTextStyles.headlineMedium(color: MintColors.white).copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            s.vaultPremiumBody,
            style: MintTextStyles.bodyMedium(color: MintColors.white),
          ),
          const SizedBox(height: MintSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context.pop();
                CoachPaywallSheet.show(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.white,
                foregroundColor: MintColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                s.vaultPremiumCta,
                style: MintTextStyles.titleMedium(color: MintColors.primary).copyWith(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Uploading Indicator (kept)
  // ──────────────────────────────────────────────────────────

  Widget _buildUploadingIndicator(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(MintColors.primary),
            ),
          ),
          const SizedBox(width: MintSpacing.md),
          Text(
            s.vaultAnalyzing,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Error Card (kept)
  // ──────────────────────────────────────────────────────────

  Widget _buildErrorCard(DocumentProvider docProvider) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MintColors.error, size: 20),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              docProvider.error!,
              style: MintTextStyles.bodyMedium(color: MintColors.error),
            ),
          ),
          IconButton(
            onPressed: () => docProvider.clearError(),
            icon: const Icon(Icons.close, size: 18, color: MintColors.error),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Upload Result Section (kept)
  // ──────────────────────────────────────────────────────────

  Widget _buildResultSection(S s, DocumentUploadResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfidenceCard(s, result),
        const SizedBox(height: MintSpacing.md),
        if (result.extractedFields.lpp != null)
          _buildExtractedFieldsPreview(s, result.extractedFields.lpp!),
        const SizedBox(height: MintSpacing.md),
        if (result.warnings.isNotEmpty) ...[
          _buildWarningsCard(s, result.warnings),
          const SizedBox(height: MintSpacing.md),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              context.push('/documents/${result.id}');
            },
            child: Text(
              s.documentsConfirmButton,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceCard(S s, DocumentUploadResult result) {
    final confidence = (result.confidence * 100).round();
    final Color color = _confidenceColor(confidence);

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                confidence >= 80
                    ? Icons.check_circle
                    : confidence >= 50
                        ? Icons.warning_amber_rounded
                        : Icons.error_outline,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                _formatConfidence(s, confidence),
                style: MintTextStyles.titleMedium(color: color),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            _formatFieldsFound(s, result.fieldsFound, result.fieldsTotal),
            style: MintTextStyles.bodyMedium(),
          ),
          const SizedBox(height: MintSpacing.sm),
          LinearProgressIndicator(
            value: result.fieldsTotal > 0
                ? result.fieldsFound / result.fieldsTotal
                : 0,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedFieldsPreview(S s, LppExtractedFields fields) {
    final entries = _buildFieldEntries(s, fields);
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.vaultExtractedFields,
          style: MintTextStyles.labelSmall(),
        ),
        const SizedBox(height: MintSpacing.sm),
        ...entries.map((entry) => _buildFieldRow(entry.$1, entry.$2)),
      ],
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: MintSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: 14),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: MintTextStyles.bodyMedium(),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Text(
            value,
            style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningsCard(S s, List<String> warnings) {
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
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\u2022 ',
                      style: MintTextStyles.bodySmall(color: MintColors.warning)),
                  Expanded(
                    child: Text(
                      warning,
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
  // Bank Import Card (kept as fallback)
  // ──────────────────────────────────────────────────────────

  Widget _buildBankImportCard(S s) {
    return Semantics(
      label: s.bankImportTitle,
      button: true,
      child: InkWell(
        onTap: () => context.push('/bank-import'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MintColors.info.withValues(alpha: 0.3)),
          ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.account_balance_outlined,
                  color: MintColors.info, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.bankImportTitle,
                    style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    s.bankImportSubtitle,
                    style: MintTextStyles.bodySmall(color: MintColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: MintColors.textMuted, size: 22),
          ],
        ),
      ),
    ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Privacy Footer (kept)
  // ──────────────────────────────────────────────────────────

  Widget _buildPrivacyFooter(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline,
                color: MintColors.info, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              s.vaultPrivacy,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Disclaimer (compliance — MANDATORY)
  // ──────────────────────────────────────────────────────────

  Widget _buildDisclaimer(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_outlined,
              color: MintColors.textMuted, size: 18),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              s.vaultDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Upload Bottom Sheet
  // ──────────────────────────────────────────────────────────

  void _showUploadTypeSheet(S s) {
    final sub = context.read<SubscriptionProvider>();
    final docProvider = context.read<DocumentProvider>();

    // Check free-tier limit
    if (!sub.isCoach && docProvider.documentCount >= _freeDocLimit) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: MintSpacing.lg),
              _buildPremiumUpsellCard(s),
              const SizedBox(height: MintSpacing.lg),
            ],
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _buildUploadTypeSheet(ctx, s),
    );
  }

  Widget _buildUploadTypeSheet(BuildContext ctx, S s) {
    final categories = _getCategoryDefinitions(s);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MintSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MintColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: MintSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.vaultUploadTitle,
                  style: MintTextStyles.headlineMedium().copyWith(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            for (final cat in categories) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(MintSpacing.sm),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 22),
                ),
                title: Text(
                  cat.label,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: MintColors.textMuted, size: 22),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(cat.type);
                },
              ),
            ],
            // "Other" type
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(MintSpacing.sm),
                decoration: BoxDecoration(
                  color: MintColors.textMuted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined,
                    color: MintColors.textMuted, size: 22),
              ),
              title: Text(
                s.vaultCategoryOther,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: MintColors.textMuted, size: 22),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(VaultDocumentType.other);
              },
            ),
            const SizedBox(height: MintSpacing.sm),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(VaultDocumentType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      if (!mounted) return;
      await context
          .read<DocumentProvider>()
          .uploadDocument(result.files.single.path!);
    }
  }

  Future<void> _confirmDelete(
      S s, String docId, DocumentProvider docProvider) async {
    final confirm = await _confirmDeleteDialog(s, docId, docProvider);
    if (confirm == true) {
      await docProvider.deleteDocument(docId);
    }
  }

  Future<bool?> _confirmDeleteDialog(
      S s, String docId, DocumentProvider docProvider) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.vaultDeleteTitle),
        content: Text(s.vaultDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.vaultCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: MintColors.error),
            child: Text(s.vaultDeleteButton),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    final s = S.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          s.vaultTitle,
          style: MintTextStyles.headlineMedium().copyWith(fontSize: 20),
        ),
        content: Text(
          s.vaultPrivacy,
          style: MintTextStyles.bodyMedium(),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.vaultOkButton),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Helpers — Category definitions
  // ──────────────────────────────────────────────────────────

  List<_CategoryDef> _getCategoryDefinitions(S s) {
    return [
      _CategoryDef(
        type: VaultDocumentType.lppCertificate,
        icon: Icons.shield_outlined,
        color: MintColors.info,
        label: s.vaultCategoryLpp,
      ),
      _CategoryDef(
        type: VaultDocumentType.salaryCertificate,
        icon: Icons.payments_outlined,
        color: MintColors.success,
        label: s.vaultCategorySalary,
      ),
      _CategoryDef(
        type: VaultDocumentType.pillar3aAttestation,
        icon: Icons.savings_outlined,
        color: MintColors.purple,
        label: s.vaultCategory3a,
      ),
      _CategoryDef(
        type: VaultDocumentType.insurancePolicy,
        icon: Icons.health_and_safety_outlined,
        color: MintColors.warning,
        label: s.vaultCategoryInsurance,
      ),
      _CategoryDef(
        type: VaultDocumentType.lease,
        icon: Icons.home_outlined,
        color: MintColors.cyan,
        label: s.vaultCategoryLease,
      ),
      _CategoryDef(
        type: VaultDocumentType.lamalStatement,
        icon: Icons.local_hospital_outlined,
        color: MintColors.error,
        label: s.vaultCategoryLamal,
      ),
    ];
  }

  int _countDocumentsOfType(
      DocumentProvider docProvider, VaultDocumentType type) {
    return docProvider.documents.where((d) => d.documentType == type).length;
  }

  String _labelForType(S s, VaultDocumentType type) {
    switch (type) {
      case VaultDocumentType.lppCertificate:
        return s.vaultCategoryLpp;
      case VaultDocumentType.salaryCertificate:
        return s.vaultCategorySalary;
      case VaultDocumentType.pillar3aAttestation:
        return s.vaultCategory3a;
      case VaultDocumentType.insurancePolicy:
        return s.vaultCategoryInsurance;
      case VaultDocumentType.lease:
        return s.vaultCategoryLease;
      case VaultDocumentType.lamalStatement:
        return s.vaultCategoryLamal;
      case VaultDocumentType.other:
        return s.vaultCategoryOther;
    }
  }

  IconData _iconForType(VaultDocumentType type) {
    switch (type) {
      case VaultDocumentType.lppCertificate:
        return Icons.shield_outlined;
      case VaultDocumentType.salaryCertificate:
        return Icons.payments_outlined;
      case VaultDocumentType.pillar3aAttestation:
        return Icons.savings_outlined;
      case VaultDocumentType.insurancePolicy:
        return Icons.health_and_safety_outlined;
      case VaultDocumentType.lease:
        return Icons.home_outlined;
      case VaultDocumentType.lamalStatement:
        return Icons.local_hospital_outlined;
      case VaultDocumentType.other:
        return Icons.description_outlined;
    }
  }

  Color _colorForType(VaultDocumentType type) {
    switch (type) {
      case VaultDocumentType.lppCertificate:
        return MintColors.info;
      case VaultDocumentType.salaryCertificate:
        return MintColors.success;
      case VaultDocumentType.pillar3aAttestation:
        return MintColors.purple;
      case VaultDocumentType.insurancePolicy:
        return MintColors.warning;
      case VaultDocumentType.lease:
        return MintColors.cyan;
      case VaultDocumentType.lamalStatement:
        return MintColors.error;
      case VaultDocumentType.other:
        return MintColors.textMuted;
    }
  }

  Color _confidenceColor(int confidence) {
    if (confidence >= 80) return MintColors.success;
    if (confidence >= 50) return MintColors.warning;
    return MintColors.error;
  }

  // ──────────────────────────────────────────────────────────
  // Helpers — Field entries (LPP-specific)
  // ──────────────────────────────────────────────────────────

  List<(String, String)> _buildFieldEntries(S s, LppExtractedFields fields) {
    final entries = <(String, String)>[];

    if (fields.avoirVieillesseTotal != null) {
      entries.add((
        s.documentsFieldAvoirTotal,
        _formatChf(fields.avoirVieillesseTotal!),
      ));
    }
    if (fields.salaireAssure != null) {
      entries.add((
        s.documentsFieldSalaireAssure,
        _formatChf(fields.salaireAssure!),
      ));
    }
    if (fields.tauxConversionObligatoire != null) {
      entries.add((
        s.documentsFieldTauxObligatoire,
        '${fields.tauxConversionObligatoire!.toStringAsFixed(1)}%',
      ));
    }
    if (fields.rachatMaximum != null) {
      entries.add((
        s.documentsFieldRachatMax,
        _formatChf(fields.rachatMaximum!),
      ));
    }
    if (fields.renteInvalidite != null) {
      entries.add((
        s.documentsFieldRenteInvalidite,
        '${_formatChf(fields.renteInvalidite!)}/an',
      ));
    }
    if (fields.capitalDeces != null) {
      entries.add((
        s.documentsFieldCapitalDeces,
        _formatChf(fields.capitalDeces!),
      ));
    }
    if (fields.cotisationEmploye != null) {
      entries.add((
        s.documentsFieldCotisationEmploye,
        _formatChf(fields.cotisationEmploye!),
      ));
    }
    if (fields.cotisationEmployeur != null) {
      entries.add((
        s.documentsFieldCotisationEmployeur,
        _formatChf(fields.cotisationEmployeur!),
      ));
    }

    return entries;
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

  String _formatConfidence(S s, int confidence) {
    return s.documentsConfidence(confidence.toString());
  }

  String _formatFieldsFound(S s, int found, int total) {
    return s.documentsFieldsFound(found.toString(), total.toString());
  }
}

// ──────────────────────────────────────────────────────────
// Internal category definition model
// ──────────────────────────────────────────────────────────

class _CategoryDef {
  final VaultDocumentType type;
  final IconData icon;
  final Color color;
  final String label;

  const _CategoryDef({
    required this.type,
    required this.icon,
    required this.color,
    required this.label,
  });
}
