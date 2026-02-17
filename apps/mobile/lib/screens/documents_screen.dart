import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/theme/colors.dart';

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
    final s = S.of(context);
    final docProvider = context.watch<DocumentProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final totalDocs = docProvider.documentCount;

    return Scaffold(
      backgroundColor: MintColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUploadTypeSheet(s),
        backgroundColor: MintColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(s, sub),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header card
                  _buildHeaderCard(s, totalDocs),
                  const SizedBox(height: 24),

                  // 2. Category grid
                  _buildCategoryGrid(s, docProvider),
                  const SizedBox(height: 28),

                  // 3. Legal guidance section
                  _buildGuidanceSection(s),
                  const SizedBox(height: 28),

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

                  // 4. Documents list
                  _buildDocumentsList(s, docProvider, sub),
                  const SizedBox(height: 24),

                  // Bank import card (kept as fallback)
                  _buildBankImportCard(s),
                  const SizedBox(height: 24),

                  // Privacy footer
                  _buildPrivacyFooter(s),
                  const SizedBox(height: 16),

                  // Disclaimer (compliance — mandatory)
                  _buildDisclaimer(s),
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
  // 1. App Bar — SliverAppBar with gradient
  // ──────────────────────────────────────────────────────────

  Widget _buildAppBar(S? s, SubscriptionProvider sub) {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'COFFRE-FORT',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      actions: [
        if (sub.isCoach)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Premium',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        IconButton(
          icon: const Icon(Icons.info_outline, size: 22, color: Colors.white),
          onPressed: () => _showInfoDialog(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // 2. Header Card — glassmorphism-style
  // ──────────────────────────────────────────────────────────

  Widget _buildHeaderCard(S? s, int totalDocs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.glassBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_outline,
                    color: MintColors.accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s?.vaultHeaderTitle ?? 'Ton coffre-fort financier',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s?.vaultHeaderSubtitle ??
                          'Centralise, comprends et agis sur tes documents',
                      style: const TextStyle(
                        fontSize: 15,
                        color: MintColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_outlined,
                    color: MintColors.info, size: 18),
                const SizedBox(width: 8),
                Text(
                  s?.vaultDocCount(totalDocs.toString()) ??
                      '$totalDocs documents',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.info,
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
  // 3. Category Grid — 2-column grid of tappable category cards
  // ──────────────────────────────────────────────────────────

  Widget _buildCategoryGrid(S? s, DocumentProvider docProvider) {
    final categories = _getCategoryDefinitions(s);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final count = _countDocumentsOfType(docProvider, cat.type);
        return _buildCategoryCard(s, cat.type, cat.icon, cat.color, count, cat.label);
      },
    );
  }

  Widget _buildCategoryCard(
    S? s,
    VaultDocumentType type,
    IconData icon,
    Color color,
    int count,
    String label,
  ) {
    return InkWell(
      onTap: () => _pickAndUpload(type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: MintColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              count > 0
                  ? (s?.vaultCategoryCount(count.toString()) ??
                      '$count')
                  : (s?.vaultCategoryNone ?? 'Aucun'),
              style: TextStyle(
                fontSize: 13,
                color: count > 0 ? color : MintColors.textMuted,
                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 4. Legal Guidance Section
  // ──────────────────────────────────────────────────────────

  Widget _buildGuidanceSection(S? s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s?.vaultGuidanceTitle.toUpperCase() ?? 'GUIDANCE JURIDIQUE',
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),

        // a) Bail — Tes droits de locataire
        _buildGuidanceCard(
          s,
          icon: Icons.home_outlined,
          title: s?.vaultGuidanceLeaseTitle ??
              'Bail \u2014 Tes droits de locataire',
          body: s?.vaultGuidanceLeaseBody ??
              'En Suisse, le loyer peut \u00eatre contest\u00e9 s\u2019il d\u00e9passe '
                  'le rendement admissible (CO art. 269). Le pr\u00e9avis l\u00e9gal est '
                  'de 3 mois pour un appartement, sauf clause contraire dans le bail. '
                  'L\u2019ASLOCA offre des consultations gratuites dans la plupart des cantons.',
          source: s?.vaultGuidanceLeaseSource ??
              'CO art. 269-270, OBLF art. 12-13',
        ),
        const SizedBox(height: 12),

        // b) Assurances — Audit de couverture
        _buildGuidanceCard(
          s,
          icon: Icons.health_and_safety_outlined,
          title: s?.vaultGuidanceInsuranceTitle ??
              'Assurances \u2014 Audit de couverture',
          body: s?.vaultGuidanceInsuranceBody ??
              'La RC priv\u00e9e et l\u2019assurance m\u00e9nage ne sont pas obligatoires '
                  'en Suisse, mais fortement recommand\u00e9es. V\u00e9rifie que ta somme '
                  'assur\u00e9e m\u00e9nage couvre la valeur r\u00e9elle de tes biens. '
                  'La sous-assurance peut r\u00e9duire l\u2019indemnisation proportionnellement '
                  '(LCA art. 69).',
          source: s?.vaultGuidanceInsuranceSource ??
              'LCA art. 69, CGA assureurs',
        ),
        const SizedBox(height: 12),

        // c) LAMal — Optimisation franchise
        _buildGuidanceCard(
          s,
          icon: Icons.local_hospital_outlined,
          title: s?.vaultGuidanceLamalTitle ??
              'LAMal \u2014 Optimisation franchise',
          body: s?.vaultGuidanceLamalBody ??
              'Tu peux changer de franchise LAMal chaque ann\u00e9e au 30 novembre '
                  '(franchise plus haute) ou au 31 d\u00e9cembre (franchise plus basse). '
                  'Un\u00b7e adulte en bonne sant\u00e9 peut \u00e9conomiser jusqu\u2019\u00e0 '
                  '1\u2019500 CHF/an avec une franchise de 2\u2019500 CHF vs 300 CHF.',
          source: s?.vaultGuidanceLamalSource ??
              'LAMal art. 62, OAMal art. 93-94',
        ),
        const SizedBox(height: 12),

        // d) Salaire — Vérification du certificat
        _buildGuidanceCard(
          s,
          icon: Icons.payments_outlined,
          title: s?.vaultGuidanceSalaryTitle ??
              'Salaire \u2014 V\u00e9rification du certificat',
          body: s?.vaultGuidanceSalaryBody ??
              'Ton certificat de salaire (Lohnausweis) est le document cl\u00e9 pour ta '
                  'd\u00e9claration fiscale. V\u00e9rifie que les cotisations LPP, AVS et '
                  'allocations familiales correspondent \u00e0 tes fiches de paie. '
                  'Toute erreur peut impacter tes imp\u00f4ts et ta pr\u00e9voyance.',
          source: s?.vaultGuidanceSalarySource ??
              'LIFD art. 127, OFS formulaire 11',
        ),
      ],
    );
  }

  Widget _buildGuidanceCard(
    S? s, {
    required IconData icon,
    required String title,
    required String body,
    required String source,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MintColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: MintColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.school_outlined,
                  color: MintColors.accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            source,
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 5. Documents List
  // ──────────────────────────────────────────────────────────

  Widget _buildDocumentsList(
      S? s, DocumentProvider docProvider, SubscriptionProvider sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s?.vaultDocListTitle.toUpperCase() ?? 'MES DOCUMENTS',
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),

        if (docProvider.documents.isEmpty)
          _buildEmptyState(s)
        else ...[
          // Group documents by type, show limited for free users
          ..._buildGroupedDocuments(s, docProvider, sub),

          // Premium upsell if free user has reached limit
          if (!sub.isCoach && docProvider.documents.length >= _freeDocLimit) ...[
            const SizedBox(height: 16),
            _buildPremiumUpsellCard(s),
          ],
        ],
      ],
    );
  }

  List<Widget> _buildGroupedDocuments(
      S? s, DocumentProvider docProvider, SubscriptionProvider sub) {
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
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: Row(
            children: [
              Icon(typeIcon, size: 16, color: typeColor),
              const SizedBox(width: 8),
              Text(
                typeLabel,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
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
      S? s, DocumentSummary doc, DocumentProvider docProvider) {
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
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: MintColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: MintColors.error),
      ),
      child: Container(
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MintColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _confidenceColor(confidence)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              s?.vaultConfidence(
                                          confidence.toString()) ??
                                  'Confiance : $confidence%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildEmptyState(S? s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_outlined,
              size: 48, color: MintColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            s?.vaultEmptyTitle ?? 'Aucun document',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s?.vaultEmptySubtitle ??
                'Ajoute ton premier document pour alimenter tes simulations avec des donn\u00e9es r\u00e9elles',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _showUploadTypeSheet(s),
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              s?.vaultUploadButton ?? 'Choisir un fichier PDF',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumUpsellCard(S? s) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_open_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  s?.vaultPremiumTitle ?? 'Coffre-fort Premium',
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
            s?.vaultPremiumBody ??
                'Passe \u00e0 MINT Premium pour stocker un nombre illimit\u00e9 de documents '
                    'et d\u00e9bloquer l\u2019audit de couverture automatique',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // Navigate to premium/subscription page
                context.push('/subscription');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MintColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                s?.vaultPremiumCta ?? 'D\u00e9couvrir Premium',
                style: const TextStyle(fontWeight: FontWeight.w600),
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
            s?.vaultAnalyzing ?? 'Analyse en cours...',
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
  // Error Card (kept)
  // ──────────────────────────────────────────────────────────

  Widget _buildErrorCard(DocumentProvider docProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
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
  // Upload Result Section (kept, handles new types gracefully)
  // ──────────────────────────────────────────────────────────

  Widget _buildResultSection(S? s, DocumentUploadResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfidenceCard(s, result),
        const SizedBox(height: 16),
        if (result.extractedFields.lpp != null)
          _buildExtractedFieldsPreview(s, result.extractedFields.lpp!),
        const SizedBox(height: 16),
        if (result.warnings.isNotEmpty) ...[
          _buildWarningsCard(s, result.warnings),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
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
    final Color color = _confidenceColor(confidence);

    return Container(
      padding: const EdgeInsets.all(20),
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
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedFieldsPreview(S? s, LppExtractedFields fields) {
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
          for (final warning in warnings)
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
                      warning,
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
  // Bank Import Card (kept as fallback)
  // ──────────────────────────────────────────────────────────

  Widget _buildBankImportCard(S? s) {
    return InkWell(
      onTap: () => context.push('/bank-import'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
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
                    s?.bankImportTitle ?? 'Importer un relev\u00e9 bancaire',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s?.bankImportSubtitle ??
                        'Analyse automatique de tes transactions',
                    style: const TextStyle(
                      fontSize: 13,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: MintColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Privacy Footer (kept)
  // ──────────────────────────────────────────────────────────

  Widget _buildPrivacyFooter(S? s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MintColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline,
                color: MintColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              s?.vaultPrivacy ??
                  'Tes documents sont analys\u00e9s localement et ne sont '
                      'jamais partag\u00e9s avec des tiers. Tu peux les supprimer '
                      '\u00e0 tout moment.',
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
  // Disclaimer (compliance — MANDATORY)
  // ──────────────────────────────────────────────────────────

  Widget _buildDisclaimer(S? s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_outlined,
              color: MintColors.textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              s?.vaultDisclaimer ??
                  'MINT est un outil \u00e9ducatif. Les informations juridiques '
                      'pr\u00e9sent\u00e9es sont \u00e0 titre informatif et ne constituent '
                      'pas un conseil juridique personnalis\u00e9 (LSFin, nLPD). '
                      'Pour toute question sp\u00e9cifique, consulte un\u00b7e '
                      'sp\u00e9cialiste qualifi\u00e9\u00b7e.',
              style: const TextStyle(
                fontSize: 12,
                color: MintColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Upload Bottom Sheet
  // ──────────────────────────────────────────────────────────

  void _showUploadTypeSheet(S? s) {
    final sub = context.read<SubscriptionProvider>();
    final docProvider = context.read<DocumentProvider>();

    // Check free-tier limit
    if (!sub.isCoach && docProvider.documentCount >= _freeDocLimit) {
      // Show premium upsell instead
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              _buildPremiumUpsellCard(s),
              const SizedBox(height: 24),
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

  Widget _buildUploadTypeSheet(BuildContext ctx, S? s) {
    final categories = _getCategoryDefinitions(s);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MintColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s?.vaultUploadTitle ?? 'Quel type de document ?',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final cat in categories) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 22),
                ),
                title: Text(
                  cat.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MintColors.textMuted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined,
                    color: MintColors.textMuted, size: 22),
              ),
              title: Text(
                s?.vaultCategoryOther ?? 'Autre',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: MintColors.textMuted, size: 22),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(VaultDocumentType.other);
              },
            ),
            const SizedBox(height: 8),
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
      // Upload with type hint (the provider will pass it to the service)
      // For now, the provider's uploadDocument accepts a path string;
      // once Agent 1 adds the type parameter, this will pass it through.
      await context
          .read<DocumentProvider>()
          .uploadDocument(result.files.single.path!);
    }
  }

  Future<void> _confirmDelete(
      S? s, String docId, DocumentProvider docProvider) async {
    final confirm = await _confirmDeleteDialog(s, docId, docProvider);
    if (confirm == true) {
      await docProvider.deleteDocument(docId);
    }
  }

  Future<bool?> _confirmDeleteDialog(
      S? s, String docId, DocumentProvider docProvider) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s?.vaultDeleteTitle ?? 'Supprimer le document ?'),
        content: Text(
            s?.vaultDeleteMessage ?? 'Cette action est irr\u00e9versible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: MintColors.error),
            child: Text(s?.vaultDeleteButton ?? 'Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    final s = S.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          s?.vaultTitle ?? 'Coffre-fort',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          s?.vaultPrivacy ??
              'Tes documents sont analys\u00e9s localement et ne sont '
                  'jamais partag\u00e9s avec des tiers. Tu peux les supprimer '
                  '\u00e0 tout moment.',
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
  // Helpers — Category definitions
  // ──────────────────────────────────────────────────────────

  /// Category definitions (excluding "other" which is handled separately).
  List<_CategoryDef> _getCategoryDefinitions(S? s) {
    return [
      _CategoryDef(
        type: VaultDocumentType.lppCertificate,
        icon: Icons.shield_outlined,
        color: MintColors.info,
        label: s?.vaultCategoryLpp ?? 'Pr\u00e9voyance LPP',
      ),
      _CategoryDef(
        type: VaultDocumentType.salaryCertificate,
        icon: Icons.payments_outlined,
        color: MintColors.success,
        label: s?.vaultCategorySalary ?? 'Certificat de salaire',
      ),
      _CategoryDef(
        type: VaultDocumentType.pillar3aAttestation,
        icon: Icons.savings_outlined,
        color: MintColors.purple,
        label: s?.vaultCategory3a ?? '3e pilier',
      ),
      _CategoryDef(
        type: VaultDocumentType.insurancePolicy,
        icon: Icons.health_and_safety_outlined,
        color: MintColors.warning,
        label: s?.vaultCategoryInsurance ?? 'Assurances',
      ),
      _CategoryDef(
        type: VaultDocumentType.lease,
        icon: Icons.home_outlined,
        color: MintColors.cyan,
        label: s?.vaultCategoryLease ?? 'Bail',
      ),
      _CategoryDef(
        type: VaultDocumentType.lamalStatement,
        icon: Icons.local_hospital_outlined,
        color: MintColors.error,
        label: s?.vaultCategoryLamal ?? 'Sant\u00e9 (LAMal)',
      ),
    ];
  }

  /// Count documents of a given type from the provider.
  int _countDocumentsOfType(
      DocumentProvider docProvider, VaultDocumentType type) {
    return docProvider.documents
        .where((d) => d.documentType == type)
        .length;
  }

  /// Get the display label for a document type.
  String _labelForType(S? s, VaultDocumentType type) {
    switch (type) {
      case VaultDocumentType.lppCertificate:
        return s?.vaultCategoryLpp ?? 'Pr\u00e9voyance LPP';
      case VaultDocumentType.salaryCertificate:
        return s?.vaultCategorySalary ?? 'Certificat de salaire';
      case VaultDocumentType.pillar3aAttestation:
        return s?.vaultCategory3a ?? '3e pilier';
      case VaultDocumentType.insurancePolicy:
        return s?.vaultCategoryInsurance ?? 'Assurances';
      case VaultDocumentType.lease:
        return s?.vaultCategoryLease ?? 'Bail';
      case VaultDocumentType.lamalStatement:
        return s?.vaultCategoryLamal ?? 'Sant\u00e9 (LAMal)';
      case VaultDocumentType.other:
        return s?.vaultCategoryOther ?? 'Autre';
    }
  }

  /// Get the icon for a document type.
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

  /// Get the color for a document type.
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

  /// Confidence color based on percentage.
  Color _confidenceColor(int confidence) {
    if (confidence >= 80) return MintColors.success;
    if (confidence >= 50) return MintColors.warning;
    return MintColors.error;
  }

  // ──────────────────────────────────────────────────────────
  // Helpers — Field entries (LPP-specific, kept for backward compat)
  // ──────────────────────────────────────────────────────────

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
