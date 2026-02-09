import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// "Mes Documents" screen - Upload and manage LPP certificates.
///
/// Users can upload a PDF, see extracted fields with confidence scores,
/// and manage their previously uploaded documents.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  @override
  void initState() {
    super.initState();
    // Load documents list on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final docProvider = context.watch<DocumentProvider>();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(s),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    s?.documentsTitle ?? 'Mes documents',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s?.documentsSubtitle ??
                        'Upload et analyse de tes documents financiers',
                    style: const TextStyle(
                      fontSize: 15,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload card
                  _buildUploadCard(s, docProvider),
                  const SizedBox(height: 24),

                  // Uploading indicator
                  if (docProvider.isUploading) ...[
                    _buildUploadingIndicator(s),
                    const SizedBox(height: 24),
                  ],

                  // Error display
                  if (docProvider.error != null) ...[
                    _buildErrorCard(docProvider),
                    const SizedBox(height: 24),
                  ],

                  // Last upload result
                  if (docProvider.lastUploadResult != null &&
                      !docProvider.isUploading) ...[
                    _buildResultSection(s, docProvider.lastUploadResult!),
                    const SizedBox(height: 24),
                  ],

                  // Previous documents list
                  if (docProvider.documents.isNotEmpty) ...[
                    _buildDocumentsListSection(s, docProvider),
                    const SizedBox(height: 24),
                  ],

                  // Privacy footer
                  _buildPrivacyFooter(s),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // App Bar
  // ──────────────────────────────────────────────────────────

  Widget _buildAppBar(S? s) {
    return SliverAppBar(
      backgroundColor: MintColors.background,
      title: Text(
        s?.documentsTitle ?? 'Mes documents',
        style: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, size: 22),
          onPressed: () => _showInfoDialog(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // Upload Card
  // ──────────────────────────────────────────────────────────

  Widget _buildUploadCard(S? s, DocumentProvider docProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.primary,
            MintColors.primary.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  s?.documentsUploadTitle ?? 'Upload ton certificat LPP',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s?.documentsUploadBody ??
                'MINT extrait automatiquement tes donn\u00e9es de pr\u00e9voyance professionnelle',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: docProvider.isUploading ? null : () => _pickAndUpload(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MintColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.attach_file_rounded, size: 20),
              label: Text(
                s?.documentsUploadButton ?? 'Choisir un fichier PDF',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Uploading Indicator
  // ──────────────────────────────────────────────────────────

  Widget _buildUploadingIndicator(S? s) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          const SizedBox(width: 16),
          Text(
            s?.documentsAnalyzing ?? 'Analyse en cours...',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Error Card
  // ──────────────────────────────────────────────────────────

  Widget _buildErrorCard(DocumentProvider docProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MintColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              docProvider.error!,
              style: const TextStyle(
                fontSize: 14,
                color: MintColors.error,
                height: 1.4,
              ),
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
  // Upload Result Section
  // ──────────────────────────────────────────────────────────

  Widget _buildResultSection(S? s, DocumentUploadResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Confidence indicator
        _buildConfidenceCard(s, result),
        const SizedBox(height: 16),

        // Extracted fields preview
        _buildExtractedFieldsPreview(s, result.extractedFields),
        const SizedBox(height: 16),

        // Warnings
        if (result.warnings.isNotEmpty) ...[
          _buildWarningsCard(s, result.warnings),
          const SizedBox(height: 16),
        ],

        // Confirm button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              // Navigate to detail for full review
              context.push('/documents/${result.id}');
            },
            child: Text(
              s?.documentsConfirmButton ??
                  'Confirmer et mettre \u00e0 jour mon profil',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceCard(S? s, DocumentUploadResult result) {
    final confidence = (result.confidence * 100).round();
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatFieldsFound(s, result.fieldsFound, result.fieldsTotal),
            style: const TextStyle(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: result.fieldsTotal > 0
                ? result.fieldsFound / result.fieldsTotal
                : 0,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedFieldsPreview(
      S? s, LppExtractedFields fields) {
    final entries = _buildFieldEntries(s, fields);
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHAMPS EXTRAITS',
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...entries.map((entry) => _buildFieldRow(entry.$1, entry.$2)),
      ],
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningsCard(S? s, List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warning.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: MintColors.warning.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                s?.documentsWarningsTitle ?? 'Points d\'attention',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.warning.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\u2022 ',
                      style: TextStyle(
                          color: MintColors.warning.withOpacity(0.7))),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 13,
                        color: MintColors.warning.withOpacity(0.8),
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
  // Documents List
  // ──────────────────────────────────────────────────────────

  Widget _buildDocumentsListSection(S? s, DocumentProvider docProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DOCUMENTS',
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        for (final doc in docProvider.documents)
          _buildDocumentListItem(s, doc, docProvider),
      ],
    );
  }

  Widget _buildDocumentListItem(
      S? s, DocumentSummary doc, DocumentProvider docProvider) {
    final typeLabel = doc.documentType == 'lpp_certificate'
        ? (s?.documentsLppCertificate ?? 'Certificat LPP')
        : (s?.documentsUnknown ?? 'Document inconnu');
    final confidence = (doc.confidence * 100).round();
    final dateStr =
        '${doc.uploadDate.day}.${doc.uploadDate.month.toString().padLeft(2, '0')}.${doc.uploadDate.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/documents/${doc.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_outlined,
                    color: MintColors.textMuted, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr  \u2022  $confidence% confiance',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MintColors.textMuted,
                      ),
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
    );
  }

  // ──────────────────────────────────────────────────────────
  // Privacy Footer
  // ──────────────────────────────────────────────────────────

  Widget _buildPrivacyFooter(S? s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MintColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline,
                color: MintColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              s?.documentsPrivacy ??
                  'Tes documents sont analys\u00e9s localement et ne sont jamais partag\u00e9s avec des tiers.',
              style: const TextStyle(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
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
      S? s, String docId, DocumentProvider docProvider) async {
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

    if (confirm == true) {
      await docProvider.deleteDocument(docId);
    }
  }

  void _showInfoDialog() {
    final s = S.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          s?.documentsTitle ?? 'Mes documents',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          s?.documentsPrivacy ??
              'Tes documents sont analys\u00e9s localement et ne sont jamais partag\u00e9s avec des tiers. Tu peux les supprimer \u00e0 tout moment.',
          style: const TextStyle(
            fontSize: 14,
            color: MintColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────

  /// Build (label, formatted value) pairs from extracted fields.
  List<(String, String)> _buildFieldEntries(
      S? s, LppExtractedFields fields) {
    final entries = <(String, String)>[];

    if (fields.avoirVieillesseTotal != null) {
      entries.add((
        s?.documentsFieldAvoirTotal ?? 'Avoir de vieillesse total',
        _formatChf(fields.avoirVieillesseTotal!),
      ));
    }
    if (fields.salaireAssure != null) {
      entries.add((
        s?.documentsFieldSalaireAssure ?? 'Salaire assur\u00e9',
        _formatChf(fields.salaireAssure!),
      ));
    }
    if (fields.tauxConversionObligatoire != null) {
      entries.add((
        s?.documentsFieldTauxObligatoire ?? 'Taux de conversion obligatoire',
        '${fields.tauxConversionObligatoire!.toStringAsFixed(1)}%',
      ));
    }
    if (fields.rachatMaximum != null) {
      entries.add((
        s?.documentsFieldRachatMax ?? 'Rachat maximum possible',
        _formatChf(fields.rachatMaximum!),
      ));
    }
    if (fields.renteInvalidite != null) {
      entries.add((
        s?.documentsFieldRenteInvalidite ?? 'Rente d\'invalidit\u00e9 annuelle',
        '${_formatChf(fields.renteInvalidite!)}/an',
      ));
    }
    if (fields.capitalDeces != null) {
      entries.add((
        s?.documentsFieldCapitalDeces ?? 'Capital-d\u00e9c\u00e8s',
        _formatChf(fields.capitalDeces!),
      ));
    }
    if (fields.cotisationEmploye != null) {
      entries.add((
        s?.documentsFieldCotisationEmploye ?? 'Cotisation employ\u00e9 annuelle',
        _formatChf(fields.cotisationEmploye!),
      ));
    }
    if (fields.cotisationEmployeur != null) {
      entries.add((
        s?.documentsFieldCotisationEmployeur ??
            'Cotisation employeur annuelle',
        _formatChf(fields.cotisationEmployeur!),
      ));
    }

    return entries;
  }

  /// Format a number as CHF with Swiss apostrophe grouping.
  String _formatChf(double value) {
    final intPart = value.truncate();
    final formatted = _groupDigits(intPart);
    return 'CHF $formatted';
  }

  /// Group digits with apostrophe (Swiss format): 245678 -> 245'678
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

  String _formatConfidence(S? s, int confidence) {
    return s?.documentsConfidence(confidence.toString()) ??
        'Confiance : $confidence%';
  }

  String _formatFieldsFound(S? s, int found, int total) {
    return s?.documentsFieldsFound(found.toString(), total.toString()) ??
        '$found champs extraits sur $total';
  }
}
