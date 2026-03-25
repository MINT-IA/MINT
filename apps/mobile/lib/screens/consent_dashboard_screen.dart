import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/privacy_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
    final l10n = S.of(context)!;
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
          l10n.consentExportTitle,
          style: MintTextStyles.titleMedium(),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Format: ${summary['format']}',
                  style: MintTextStyles.bodyMedium()),
              const SizedBox(height: MintSpacing.sm),
              Text('Categories: $categories',
                  style: MintTextStyles.bodyMedium()),
              const SizedBox(height: MintSpacing.sm),
              Text(
                summary['retentionPolicy'] as String,
                style: MintTextStyles.labelSmall(),
              ),
              const SizedBox(height: MintSpacing.sm + 4),
              Text(
                summary['disclaimer'] as String,
                style: MintTextStyles.micro(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(l10n.consentClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    if (_loading) {
      return Scaffold(
        backgroundColor: MintColors.white,
        appBar: AppBar(
          backgroundColor: MintColors.white,
          surfaceTintColor: MintColors.white,
          elevation: 0,
          title: Text(
            l10n.consentControlCenter,
            style: MintTextStyles.headlineMedium(),
          ),
        ),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: const Center(child: CircularProgressIndicator()))),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: MintColors.white,
        appBar: AppBar(
          backgroundColor: MintColors.white,
          surfaceTintColor: MintColors.white,
          elevation: 0,
          title: Text(
            l10n.consentControlCenter,
            style: MintTextStyles.headlineMedium(),
          ),
        ),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Center(
          child: Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            margin: const EdgeInsets.all(MintSpacing.lg),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MintColors.error.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: MintColors.error, size: 20),
                const SizedBox(width: MintSpacing.sm + 4),
                Expanded(child: Text(
                  l10n.consentErrorMessage,
                  style: MintTextStyles.bodySmall(color: MintColors.error),
                )),
              ],
            ),
          ),
        ))),
      );
    }

    final consentStatus = PrivacyService.getConsentStatus(
      currentConsents: _consents,
    );

    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          l10n.consentControlCenter,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SingleChildScrollView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MintEntrance(child: _buildSecurityHeader(l10n)),
            const SizedBox(height: MintSpacing.lg),
            MintEntrance(delay: const Duration(milliseconds: 100), child: _buildExportButton(l10n)),
            const SizedBox(height: MintSpacing.xl),
            MintEntrance(delay: const Duration(milliseconds: 200), child: Text(
              l10n.consentRequiredTitle,
              style: MintTextStyles.titleMedium(),
            )),
            const SizedBox(height: MintSpacing.sm + 4),
            ...consentStatus
                .where((c) => c['required'] == true)
                .map((c) => _buildCategoryCard(c, l10n)),
            const SizedBox(height: MintSpacing.lg),
            MintEntrance(delay: const Duration(milliseconds: 300), child: Text(
              l10n.consentOptionalTitle,
              style: MintTextStyles.titleMedium(),
            )),
            const SizedBox(height: MintSpacing.sm + 4),
            ...consentStatus
                .where((c) => c['required'] == false)
                .map((c) => _buildCategoryCard(c, l10n)),
            const SizedBox(height: MintSpacing.xl),
            MintEntrance(delay: const Duration(milliseconds: 400), child: _buildRevokeAllButton(l10n)),
            const SizedBox(height: MintSpacing.lg),
            _buildDisclaimer(),
            const SizedBox(height: MintSpacing.md),
            _buildSources(l10n),
          ],
        ),
      ))),
    );
  }

  Widget _buildSecurityHeader(S l10n) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg - 4),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.success.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_person_outlined, color: MintColors.success),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Text(
              l10n.consentSecurityMessage,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(S l10n) {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        label: l10n.consentExportData,
        button: true,
        child: OutlinedButton.icon(
          onPressed: _exportData,
          icon: const Icon(Icons.download_outlined),
          label: Text(l10n.consentExportData),
          style: OutlinedButton.styleFrom(
            foregroundColor: MintColors.primary,
            side: const BorderSide(color: MintColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, S l10n) {
    final id = category['id'] as String;
    final label = category['label'] as String;
    final description = category['description'] as String;
    final legalBasis = category['legalBasis'] as String;
    final isRequired = category['required'] as bool;
    final isConsented = category['consented'] as bool;
    final retentionDays = category['retentionDays'] as int;

    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.lg - 4),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
                  ),
                ),
                if (isRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.sm,
                      vertical: MintSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: MintColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.consentRequired,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.primary,
                      ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Semantics(
                    label: '$label toggle',
                    toggled: isConsented,
                    child: Switch.adaptive(
                      value: isConsented,
                      onChanged: (v) => _toggleConsent(id, v),
                      activeTrackColor: MintColors.success,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            Wrap(
              spacing: MintSpacing.sm,
              runSpacing: 6,
              children: [
                _buildTag(legalBasis),
                _buildTag(l10n.consentRetentionDays(retentionDays)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: MintSpacing.xs),
      radius: 8,
      child: Text(
        text,
        style: MintTextStyles.labelSmall().copyWith(fontSize: 10),
      ),
    );
  }

  Widget _buildRevokeAllButton(S l10n) {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        label: l10n.consentRevokeAll,
        button: true,
        child: OutlinedButton(
          onPressed: _revokeAll,
          style: OutlinedButton.styleFrom(
            foregroundColor: MintColors.error,
            side: const BorderSide(color: MintColors.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(l10n.consentRevokeAll),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Text(
        PrivacyService.disclaimer,
        style: MintTextStyles.micro(),
      ),
    );
  }

  Widget _buildSources(S l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.consentLegalSources,
          style: MintTextStyles.labelSmall(
            color: MintColors.textSecondary,
          ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: MintSpacing.sm),
        ...PrivacyService.sources.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.xs),
            child: Text(
              '\u2022 $s',
              style: MintTextStyles.labelSmall().copyWith(fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}
