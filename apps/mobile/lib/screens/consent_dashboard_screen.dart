import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/privacy_service.dart';
import 'package:mint_mobile/theme/colors.dart';

class ConsentDashboardScreen extends StatefulWidget {
  const ConsentDashboardScreen({super.key});

  @override
  State<ConsentDashboardScreen> createState() => _ConsentDashboardScreenState();
}

class _ConsentDashboardScreenState extends State<ConsentDashboardScreen> {
  late Map<String, bool> _consents;

  @override
  void initState() {
    super.initState();
    _consents = {
      for (final cat in PrivacyService.dataCategories)
        cat['id'] as String: cat['required'] as bool,
    };
  }

  void _toggleConsent(String categoryId, bool value) {
    final cat = PrivacyService.getCategoryById(categoryId);
    if (cat == null) return;
    if (cat['required'] == true) return; // Cannot revoke required
    setState(() => _consents[categoryId] = value);
  }

  void _revokeAll() {
    setState(() {
      for (final cat in PrivacyService.optionalCategories) {
        _consents[cat['id'] as String] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tous les consentements optionnels ont ete revoques.'),
      ),
    );
  }

  void _exportData() {
    final summary = PrivacyService.generateExportSummary(
      profileId: 'local',
      profileData: {
        'birthYear': 1990,
        'canton': 'VD',
        'income': 80000,
        'analyticsEnabled': _consents['analytics'],
        'coachingEnabled': _consents['coaching_notifications'],
        'openBankingConnected': _consents['open_banking'],
        'documentsUploaded': _consents['document_upload'],
        'ragQueriesUsed': _consents['rag_queries'],
      },
    );

    final categories =
        (summary['dataCategories'] as List).join(', ');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Export de tes donnees',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Format: ${summary['format']}'),
              const SizedBox(height: 8),
              Text('Categories: $categories'),
              const SizedBox(height: 8),
              Text(
                summary['retentionPolicy'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                summary['disclaimer'] as String,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consentStatus = PrivacyService.getConsentStatus(
      currentConsents: _consents,
    );

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(
          'CENTRE DE CONTROLE DATA',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecurityHeader(),
            const SizedBox(height: 24),
            _buildExportButton(),
            const SizedBox(height: 32),
            Text(
              'Consentements requis',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...consentStatus
                .where((c) => c['required'] == true)
                .map((c) => _buildCategoryCard(c)),
            const SizedBox(height: 24),
            Text(
              'Consentements optionnels',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...consentStatus
                .where((c) => c['required'] == false)
                .map((c) => _buildCategoryCard(c)),
            const SizedBox(height: 32),
            _buildRevokeAllButton(),
            const SizedBox(height: 24),
            _buildDisclaimer(),
            const SizedBox(height: 16),
            _buildSources(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.success.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_person_outlined, color: MintColors.success),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Tes donnees restent sur ton appareil. Tu gardes le controle '
              'total sur les acces tiers.',
              style: TextStyle(fontSize: 13, color: MintColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _exportData,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Exporter mes donnees (nLPD art. 28)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.primary,
          side: const BorderSide(color: MintColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final id = category['id'] as String;
    final label = category['label'] as String;
    final description = category['description'] as String;
    final legalBasis = category['legalBasis'] as String;
    final isRequired = category['required'] as bool;
    final isConsented = category['consented'] as bool;
    final retentionDays = category['retentionDays'] as int;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MintColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Requis',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: MintColors.primary,
                      ),
                    ),
                  )
                else
                  Switch.adaptive(
                    value: isConsented,
                    onChanged: (v) => _toggleConsent(id, v),
                    activeColor: MintColors.success,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildTag(legalBasis),
                _buildTag('Conservation: $retentionDays jours'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MintColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: MintColors.textMuted),
      ),
    );
  }

  Widget _buildRevokeAllButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _revokeAll,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('REVOQUER TOUS LES CONSENTEMENTS OPTIONNELS'),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withOpacity(0.2)),
      ),
      child: const Text(
        PrivacyService.disclaimer,
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildSources() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sources legales',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...PrivacyService.sources.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $s',
              style: const TextStyle(
                fontSize: 10,
                color: MintColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
