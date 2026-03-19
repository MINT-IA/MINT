import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/widgets/language_selector_widget.dart';
import 'package:mint_mobile/l10n/locale_helper.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/providers/slm_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final coachProvider = context.watch<CoachProfileProvider>();
    final coachProfile = coachProvider.profile;
    final double precision = coachProvider.profileCompleteness;
    // recommendedSection and onboardingQuality moved to inline progress

    // Compute real completion for each FactFind section
    // Identity: complete if birthYear + canton present (mini-onboarding or full wizard)
    final identityComplete =
        coachProfile != null && coachProfile.canton.isNotEmpty;

    // Income: complete if salaireBrutMensuel > 0
    final incomeComplete =
        coachProfile != null && coachProfile.salaireBrutMensuel > 0;

    // Pension: complete if LPP data is present (avoirLppTotal > 0)
    final pensionComplete = coachProfile != null &&
        (coachProfile.prevoyance.avoirLppTotal ?? 0) > 0;

    // Property: complete if patrimoine data is present or full wizard done
    final propertyComplete = coachProfile != null &&
        (coachProfile.patrimoine.totalPatrimoine > 0 ||
            coachProvider.hasFullProfile);

    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Identity card (compact) ───────────────
                  if (coachProfile != null)
                    _buildIdentityCard(context, coachProfile),
                  if (coachProfile != null) const SizedBox(height: 20),

                  // ══════════════════════════════════════════
                  //  SECTION: Mon dossier
                  // ══════════════════════════════════════════
                  _buildSectionHeader(l.profileSectionMyFile),
                  const SizedBox(height: 12),

                  // Inline progress bar (replaces imposing black card)
                  _buildInlineProgress(
                    context,
                    precision: precision,
                    identityComplete: identityComplete,
                    incomeComplete: incomeComplete,
                    pensionComplete: pensionComplete,
                    propertyComplete: propertyComplete,
                  ),
                  const SizedBox(height: 12),

                  // Annual refresh nudge (if stale data)
                  if (_shouldShowAnnualRefresh(coachProvider)) ...[
                    _buildAnnualRefreshCard(context),
                    const SizedBox(height: 12),
                  ],

                  // Mon aperçu financier
                  _buildBilanLink(context, coachProfile != null),
                  const SizedBox(height: 12),

                  // Documents
                  _buildDocumentsSection(context),
                  const SizedBox(height: 12),

                  // Couple / Family
                  _buildFactFindSection(
                    title: l.profileFamilySection,
                    status: 'Couple+',
                    isComplete: false,
                    icon: Icons.people_outline,
                    onTap: () => context.push('/couple'),
                  ),

                  // ══════════════════════════════════════════
                  //  SECTION: Réglages
                  // ══════════════════════════════════════════
                  const SizedBox(height: 24),
                  _buildSectionHeader(l.profileSectionSettings),
                  const SizedBox(height: 12),

                  // Language
                  _buildLanguageSection(context),
                  const SizedBox(height: 12),

                  // AI (BYOK + SLM)
                  _buildAiSection(context),
                  const SizedBox(height: 12),

                  // Security & Data
                  _buildFactFindSection(
                    title: l.profileConsentControl,
                    status: l.profileConsentManage,
                    isComplete: true,
                    icon: Icons.lock_outline,
                    onTap: () => context.push('/profile/consent'),
                  ),

                  // Account (if logged in)
                  if (authProvider.isLoggedIn) ...[
                    const SizedBox(height: 12),
                    _buildAuthSection(context, authProvider),
                  ],

                  // Danger zone
                  const SizedBox(height: 16),
                  _buildDangerZone(context),
                  const SizedBox(height: 80), // FAB clearance
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height <= 760;
    return SliverAppBar(
      pinned: true,
      toolbarHeight: isCompact ? 44 : 52,
      backgroundColor: MintColors.background,
      title: Text(S.of(context)!.tabMoi,
          style: GoogleFonts.montserrat(
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: MintColors.textPrimary)),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SECTION HEADER (clean divider with title)
  // ══════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: MintColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INLINE PROGRESS (replaces the imposing black Precision Card)
  // ══════════════════════════════════════════════════════════════

  Widget _buildInlineProgress(
    BuildContext context, {
    required double precision,
    required bool identityComplete,
    required bool incomeComplete,
    required bool pensionComplete,
    required bool propertyComplete,
  }) {
    final pct = (precision * 100).toInt();
    final l = S.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          // Progress header
          Row(
            children: [
              Expanded(
                child: Text(
                  l.profileCompletionLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$pct\u00a0%',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: pct >= 80 ? MintColors.success : MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: precision,
              backgroundColor: MintColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 80 ? MintColors.success : MintColors.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          // 4 completion rows (inline, compact)
          _buildCompletionRow(
            icon: Icons.person_outline,
            label: l.profileSectionIdentity,
            isComplete: identityComplete,
            onTap: () => context.push('/advisor/wizard?section=identity'),
          ),
          _buildCompletionRow(
            icon: Icons.account_balance_wallet_outlined,
            label: l.profileSectionIncome,
            isComplete: incomeComplete,
            onTap: () => context.push('/advisor/wizard?section=income'),
          ),
          _buildCompletionRow(
            icon: Icons.security_outlined,
            label: l.profileSectionPension,
            isComplete: pensionComplete,
            reward: pensionComplete ? null : '+15\u00a0%',
            onTap: () => context.push('/advisor/wizard?section=pension'),
          ),
          _buildCompletionRow(
            icon: Icons.home_outlined,
            label: l.profileSectionProperty,
            isComplete: propertyComplete,
            reward: propertyComplete ? null : '+10\u00a0%',
            onTap: () => context.push('/advisor/wizard?section=property'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionRow({
    required IconData icon,
    required String label,
    required bool isComplete,
    String? reward,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: isComplete
                      ? MintColors.success
                      : MintColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isComplete
                        ? MintColors.textPrimary
                        : MintColors.textSecondary,
                  ),
                ),
              ),
              if (isComplete)
                const Icon(Icons.check_circle,
                    size: 16, color: MintColors.success)
              else if (reward != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MintColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    reward,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: MintColors.primary,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right,
                    size: 16, color: MintColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  IDENTITY CARD
  // ══════════════════════════════════════════════════════════════

  Widget _buildIdentityCard(BuildContext context, dynamic profile) {
    final l = S.of(context)!;
    final name = profile.firstName ?? l.profileDefaultName;
    final age = profile.age;
    final canton = profile.canton as String;
    final status = profile.employmentStatus as String;

    final statusLabel = {
      'salarie': l.identityStatusSalarie,
      'independant': l.identityStatusIndependant,
      'chomage': l.identityStatusChomage,
      'retraite': l.identityStatusRetraite,
    }[status] ?? status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: MintColors.primary.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      age != null ? l.profileNameAge(name, age) : name,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canton.isNotEmpty
                          ? '$canton · $statusLabel'
                          : statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: MintColors.textMuted),
                onPressed: () =>
                    context.push('/onboarding/quick?section=identity'),
                tooltip: l.commonEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBilanLink(BuildContext context, bool hasProfile) {
    return Semantics(
      label: S.of(context)!.profileBilanTitle,
      button: true,
      child: InkWell(
        onTap: () => context.push('/profile/bilan'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MintColors.primary, MintColors.darkSurface],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: MintColors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.profileBilanTitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasProfile
                        ? S.of(context)!.profileBilanSubtitleComplete
                        : S.of(context)!.profileBilanSubtitleIncomplete,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: MintColors.white54, size: 20),
          ],
        ),
      ),
    ),
    );
  }

  // _buildPrecisionCard removed — replaced by _buildInlineProgress

  bool _shouldShowAnnualRefresh(CoachProfileProvider provider) {
    final profile = provider.profile;
    if (profile == null) return false;
    final lastUpdate = profile.checkIns.isNotEmpty
        ? profile.checkIns.last.month
        : DateTime(profile.birthYear);
    return DateTime.now().difference(lastUpdate).inDays >= 300;
  }

  Widget _buildAnnualRefreshCard(BuildContext context) {
    final l = S.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.update_outlined,
                  size: 16, color: MintColors.warning),
              const SizedBox(width: 8),
              Text(
                l.profileAnnualRefreshTitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.profileAnnualRefreshBody,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/coach/refresh'),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                l.profileAnnualRefreshCta,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactFindSection({
    required String title,
    required String status,
    required bool isComplete,
    required IconData icon,
    String? reward,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.border),
            ),
            child: Row(
              children: [
                Icon(icon,
                    color:
                        isComplete ? MintColors.success : MintColors.textMuted),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(status,
                          style: TextStyle(
                              fontSize: 12,
                              color: isComplete
                                  ? MintColors.success
                                  : MintColors.textMuted)),
                    ],
                  ),
                ),
                if (reward != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: MintColors.appleSurface,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(reward,
                        style: const TextStyle(
                            color: MintColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                const Icon(Icons.chevron_right,
                    size: 18, color: MintColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiSection(BuildContext context) {
    final byok = context.watch<ByokProvider>();
    final l = S.of(context)!;
    return Column(
      children: [
        _buildFactFindSection(
          title: l.profileAiByok,
          status: byok.isConfigured
              ? '${byok.providerLabel} \u2014 ${l.profileAiConfigured}'
              : l.profileAiNotConfigured,
          isComplete: byok.isConfigured,
          icon: Icons.auto_awesome,
          onTap: () => context.push('/profile/byok'),
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final slm = context.watch<SlmProvider>();
          return _buildFactFindSection(
            title: l.profileSlmTitle,
            status: slm.isEngineAvailable
                ? l.profileSlmReady
                : l.profileSlmNotInstalled,
            isComplete: slm.isEngineAvailable,
            icon: Icons.smartphone,
            onTap: () => context.push('/profile/slm'),
          );
        }),
      ],
    );
  }

  Widget _buildDocumentsSection(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();
    final l = S.of(context)!;
    final count = docProvider.documentCount;
    final statusText = count > 0
        ? l.profileDocCount(count)
        : l.documentsEmpty;
    return _buildFactFindSection(
      title: l.profileDocuments,
      status: statusText,
      isComplete: count > 0,
      icon: Icons.description_outlined,
      onTap: () => context.push('/documents'),
    );
  }

  Widget _buildAuthSection(BuildContext context, AuthProvider authProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: MintColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.displayName ??
                          authProvider.email ??
                          S.of(context)!.profileUser,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (authProvider.displayName != null)
                      Text(
                        authProvider.email ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: MintColors.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                context.go('/');
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: Text(S.of(context)!.authLogout),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.error,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/profile/admin-observability'),
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: Text(S.of(context)!.profileAdminObservability),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/profile/admin-analytics'),
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: Text(S.of(context)!.profileAnalyticsBeta),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          TextButton.icon(
            onPressed: authProvider.isLoading
                ? null
                : () => _confirmDeleteAccount(context, authProvider),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text(S.of(context)!.profileDeleteCloudAccount),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.error,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context)!.profileDeleteAccountTitle),
        content: Text(
          S.of(context)!.profileDeleteAccountContent,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.of(context)!.profileDeleteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: MintColors.error),
            child: Text(S.of(context)!.profileDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await authProvider.deleteAccount();
    if (!context.mounted) return;

    final l = S.of(context)!;
    final message = success
        ? l.profileDeleteAccountSuccess
        : (authProvider.error ?? l.profileDeleteAccountError);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    if (success) {
      context.go('/');
    }
  }

  Widget _buildLanguageSection(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final code = localeProvider.locale.languageCode;
    final flag = MintLocales.flagOf(code);
    final name = MintLocales.nameOf(code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.of(context)!.profileLanguageTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Semantics(
          label: '${S.of(context)!.profileChangeLanguage}: $name',
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final selected =
                  await showLanguageSelector(context, localeProvider.locale);
              if (selected != null && context.mounted) {
                context.read<LocaleProvider>().setLocale(selected);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MintColors.border),
              ),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: MintColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final l = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Text(
          l.profileDangerZoneTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l.profileDangerZoneSubtitle,
          style: const TextStyle(fontSize: 12, color: MintColors.textMuted),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            final confirmed = await _showStrongResetDialog(context);
            if (confirmed != true || !context.mounted) return;

            await ReportPersistenceService.clear();
            if (!context.mounted) return;

            context.read<CoachProfileProvider>().clear();
            context.read<ProfileProvider>().clear();
            context.read<DocumentProvider>().clearLocalState();
            await context.read<BudgetProvider>().clear();
            await AnalyticsService().clearLocalQueue();

            // Force re-read from SharedPreferences (now empty) to confirm
            // _profile = null in memory. Without this, _isLoaded = false
            // can cause stale data to reappear on re-render.
            if (!context.mounted) return;
            await context.read<CoachProfileProvider>().loadFromWizard();

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.profileResetSuccess)),
            );
            if (!context.mounted) return;
            if (kIsWeb) {
              context.go('/onboarding/quick');
            } else {
              context.go('/');
            }
          },
          style: TextButton.styleFrom(foregroundColor: MintColors.error),
          child: Text(l.profileDeleteData),
        ),
        Text(
          l.profileResetScopeNote,
          style: const TextStyle(fontSize: 11, color: MintColors.textMuted),
        ),
      ],
    );
  }

  Future<bool?> _showStrongResetDialog(BuildContext context) async {
    final l = S.of(context)!;
    final controller = TextEditingController();
    bool valid = false;
    const expected = 'RESET';

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(l.profileResetDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.profileResetDialogBody),
                  const SizedBox(height: 12),
                  Text(
                    l.profileResetDialogConfirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    onChanged: (value) {
                      setState(() {
                        valid = value.trim().toUpperCase() == expected;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: expected,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: controller.text.isEmpty || valid
                          ? null
                          : l.profileResetDialogInvalid,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.commonCancel),
                ),
                TextButton(
                  onPressed: valid ? () => Navigator.pop(ctx, true) : null,
                  style: TextButton.styleFrom(foregroundColor: MintColors.error),
                  child: Text(l.profileResetDialogAction),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
