import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/privacy_service.dart';
import 'package:mint_mobile/theme/colors.dart';

class ConsentDashboardScreen extends StatefulWidget {
  const ConsentDashboardScreen({super.key});

  @override
  State<ConsentDashboardScreen> createState() => _ConsentDashboardScreenState();
}

class _ConsentDashboardScreenState extends State<ConsentDashboardScreen> {
  late Map<String, bool> _consents;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadConsents();
  }

  Future<void> _loadConsents() async {
    try {
      _consents = {
        for (final cat in PrivacyService.dataCategories)
          cat['id'] as String: cat['required'] as bool,
      };
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    }
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
      SnackBar(
        content: Text(S.of(context)!.consentAllRevoked),
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
          S.of(context)!.consentExportTitle,
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
            child: Text(S.of(context)!.consentClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: MintColors.background,
        appBar: AppBar(
          title: Text(
            S.of(context)!.consentControlCenter,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: MintColors.background,
        appBar: AppBar(
          title: Text(
            S.of(context)!.consentControlCenter,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: MintColors.error, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  'Une erreur est survenue. Réessaie plus tard.',
                  style: GoogleFonts.inter(fontSize: 13, color: MintColors.error),
                )),
              ],
            ),
          ),
        ),
      );
    }

    final consentStatus = PrivacyService.getConsentStatus(
      currentConsents: _consents,
    );

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(
          S.of(context)!.consentControlCenter,
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
              S.of(context)!.consentRequiredTitle,
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
              S.of(context)!.consentOptionalTitle,
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
        color: MintColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_person_outlined, color: MintColors.success),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              S.of(context)!.consentSecurityMessage,
              style: const TextStyle(fontSize: 13, color: MintColors.textPrimary),
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
        label: Text(S.of(context)!.consentExportData),
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
          color: MintColors.white,
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
                      color: MintColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      S.of(context)!.consentRequired,
                      style: const TextStyle(
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
                    activeTrackColor: MintColors.success,
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
                _buildTag(S.of(context)!.consentRetentionDays(retentionDays)),
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
          foregroundColor: MintColors.error,
          side: const BorderSide(color: MintColors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(S.of(context)!.consentRevokeAll),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
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
        Text(
          S.of(context)!.consentLegalSources,
          style: const TextStyle(
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
