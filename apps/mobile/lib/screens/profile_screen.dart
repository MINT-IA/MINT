import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final coachProvider = context.watch<CoachProfileProvider>();
    final coachProfile = coachProvider.profile;
    final double precision = coachProvider.profileCompleteness;

    // Compute real completion for each FactFind section
    final identityComplete =
        coachProfile != null && coachProfile.canton.isNotEmpty;

    final incomeComplete =
        coachProfile != null && coachProfile.salaireBrutMensuel > 0;

    final pensionComplete = coachProfile != null &&
        (coachProfile.prevoyance.avoirLppTotal ?? 0) > 0;

    final propertyComplete = coachProfile != null &&
        (coachProfile.patrimoine.totalPatrimoine > 0 ||
            coachProvider.hasFullProfile);

    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(MintSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Identity card (compact) ───────────────
                  if (coachProfile != null)
                    MintEntrance(child: _buildIdentityCard(context, coachProfile)),
                  if (coachProfile != null)
                    const SizedBox(height: MintSpacing.md + MintSpacing.xs),

                  // ══════════════════════════════════════════
                  //  SECTION: Mon dossier
                  // ══════════════════════════════════════════
                  _buildSectionHeader(l.profileSectionMyFile),
                  const SizedBox(height: MintSpacing.sm + MintSpacing.xs),

                  // Inline progress bar
                  _buildInlineProgress(
                    context,
                    precision: precision,
                    identityComplete: identityComplete,
                    incomeComplete: incomeComplete,
                    pensionComplete: pensionComplete,
                    propertyComplete: propertyComplete,
                  ),
                  const SizedBox(height: MintSpacing.sm + MintSpacing.xs),

                  // Annual refresh nudge (if stale data)
                  if (_shouldShowAnnualRefresh(coachProvider)) ...[
                    _buildAnnualRefreshCard(context, coachProvider),
                    const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
                  ],

                  // Mon aperçu financier
                  _buildBilanLink(context, coachProfile != null),
                  const SizedBox(height: MintSpacing.sm + MintSpacing.xs),

                  // Documents
                  _buildDocumentsSection(context),
                  const SizedBox(height: MintSpacing.sm + MintSpacing.xs),

                  // Couple / Family
                  _buildFactFindSection(
                    title: l.profileFamilySection,
                    status: (coachProfile?.isCouple ?? false) ? l.profileFamilyCouple : l.profileFamilySingle,
                    isComplete: false,
                    icon: Icons.people_outline,
                    onTap: () => context.push('/couple'),
                  ),

                  // ══════════════════════════════════════════
                  //  SECTION: Compte
                  // ══════════════════════════════════════════
                  // Settings (Langue, BYOK, SLM, Consent) are accessible
                  // as rows in the Réglages section of the Dossier tab.

                  // Account (if logged in)
                  if (authProvider.isLoggedIn) ...[
                    const SizedBox(height: MintSpacing.lg),
                    _buildAuthSection(context, authProvider),
                  ],

                  // Danger zone
                  const SizedBox(height: MintSpacing.md),
                  _buildDangerZone(context),
                  const SizedBox(height: 80), // FAB clearance
                ],
              ),
            ),
          ),
        ],
      ))),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height <= 760;
    return SliverAppBar(
      pinned: true,
      toolbarHeight: isCompact ? 44 : 52,
      backgroundColor: MintColors.porcelaine,
      surfaceTintColor: MintColors.porcelaine,
      elevation: 0,
      title: Text(
        S.of(context)!.tabMoi,
        style: MintTextStyles.titleMedium(
          color: MintColors.textPrimary,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SECTION HEADER (sentence case, no uppercase, no letter-spacing)
  // ══════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: MintSpacing.xs),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: MintTextStyles.bodySmall(
            color: MintColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INLINE PROGRESS (with missing-section hint per Voice System)
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

    // Build missing sections hint (Voice System §5: "72% — il manque ton LPP et tes charges")
    final missing = <String>[];
    if (!identityComplete) missing.add(l.profileMissingIdentity);
    if (!incomeComplete) missing.add(l.profileMissingIncome);
    if (!pensionComplete) missing.add(l.profileMissingLpp);
    if (!propertyComplete) missing.add(l.profileMissingProperty);

    final String progressLabel;
    if (missing.isEmpty) {
      progressLabel = '$pct\u00a0%';
    } else {
      final missingText = missing.join(l.profileMissingAnd);
      progressLabel = l.profileCompletionHint(pct, missingText);
    }

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        children: [
          // Progress header
          Row(
            children: [
              Expanded(
                child: Text(
                  l.profileCompletionLabel,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          // Missing hint or percentage
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              progressLabel,
              style: MintTextStyles.bodySmall(
                color: pct >= 80 ? MintColors.success : MintColors.primary,
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(MintSpacing.xs),
            child: LinearProgressIndicator(
              value: precision,
              backgroundColor: MintColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 80 ? MintColors.success : MintColors.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
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
              const SizedBox(width: MintSpacing.sm + 2),
              Expanded(
                child: Text(
                  label,
                  style: MintTextStyles.bodySmall(
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
                    style: MintTextStyles.micro(
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
    final rawName = profile.firstName as String?;
    // If firstName is null, empty, or the generic default, skip it.
    // Use a non-null local for the real name to enable type promotion.
    final String? realName = (rawName != null &&
            rawName.isNotEmpty &&
            rawName != l.profileDefaultName)
        ? rawName
        : null;
    final age = profile.age;
    final canton = profile.canton as String;
    final status = profile.employmentStatus as String;

    final statusLabel = {
      'salarie': l.identityStatusSalarie,
      'independant': l.identityStatusIndependant,
      'chomage': l.identityStatusChomage,
      'retraite': l.identityStatusRetraite,
    }[status] ?? status;

    // Build the title line: "Julien, 49 ans" or just "49 ans" if no real name.
    final String titleLine;
    if (realName != null && age != null) {
      titleLine = l.profileNameAge(realName, age);
    } else if (realName != null) {
      titleLine = realName;
    } else if (age != null) {
      titleLine = '$age\u00a0ans';
    } else {
      titleLine = '';
    }

    // Avatar initial: first letter of name, or age digit, or "?"
    final avatarText = realName != null
        ? realName[0].toUpperCase()
        : (age != null ? '${age ~/ 10}' : '?');

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: MintColors.primary.withValues(alpha: 0.08),
            child: Text(
              avatarText,
              style: MintTextStyles.titleMedium(
                color: MintColors.primary,
              ),
            ),
          ),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titleLine.isNotEmpty)
                  Text(
                    titleLine,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  canton.isNotEmpty
                      ? '$canton \u00b7 $statusLabel'
                      : statusLabel,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: l.commonEdit,
            button: true,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: MintColors.textMuted),
              onPressed: () =>
                  context.push('/onboarding/quick?section=identity'),
              tooltip: l.commonEdit,
            ),
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MintColors.primary, MintColors.ardoise],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: MintColors.white, size: 22),
              const SizedBox(width: MintSpacing.sm + 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.profileBilanTitle,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasProfile
                          ? S.of(context)!.profileBilanSubtitleComplete
                          : S.of(context)!.profileBilanSubtitleIncomplete,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: MintColors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowAnnualRefresh(CoachProfileProvider provider) {
    final profile = provider.profile;
    if (profile == null) return false;
    // Use last check-in date, or profile createdAt as fallback.
    // Never fall back to DateTime(birthYear) — that caused the "16515 days" bug.
    final lastUpdate = profile.checkIns.isNotEmpty
        ? profile.checkIns.last.month
        : profile.createdAt;
    final days = DateTime.now().difference(lastUpdate).inDays;
    // Sanity guard: if days > 3650 (10y), data is corrupted — don't show.
    if (days > 3650) return false;
    return days >= 300;
  }

  int _staleDays(CoachProfileProvider provider) {
    final profile = provider.profile;
    if (profile == null) return 0;
    final lastUpdate = profile.checkIns.isNotEmpty
        ? profile.checkIns.last.month
        : profile.createdAt;
    return DateTime.now().difference(lastUpdate).inDays;
  }

  Widget _buildAnnualRefreshCard(
      BuildContext context, CoachProfileProvider provider) {
    final l = S.of(context)!;
    final days = _staleDays(provider);
    return MintSurface(
      tone: MintSurfaceTone.peche,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.update_outlined,
                  size: 16, color: MintColors.warning),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.profileAnnualRefreshTitle,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs + 2),
          Text(
            l.profileAnnualRefreshDays(days),
            style: MintTextStyles.labelSmall(
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: MintSpacing.xs + 2),
          Text(
            l.profileAnnualRefreshBody,
            style: MintTextStyles.labelSmall(
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/coach/refresh'),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                l.profileAnnualRefreshCta,
                style: MintTextStyles.bodySmall(),
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
      child: Padding(
        padding: const EdgeInsets.only(bottom: MintSpacing.sm + MintSpacing.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: MintSurface(
            tone: MintSurfaceTone.blanc,
            padding: const EdgeInsets.all(MintSpacing.md),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: isComplete
                        ? MintColors.success
                        : MintColors.textSecondary),
                const SizedBox(width: MintSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textPrimary,
                          )),
                      const SizedBox(height: 2),
                      Text(status,
                          style: MintTextStyles.labelSmall(
                            color: isComplete
                                ? MintColors.success
                                : MintColors.textMuted,
                          )),
                    ],
                  ),
                ),
                if (reward != null)
                  MintSurface(
                    tone: MintSurfaceTone.porcelaine,
                    padding: const EdgeInsets.symmetric(
                        horizontal: MintSpacing.sm, vertical: MintSpacing.xs),
                    radius: 8,
                    child: Text(reward,
                        style: MintTextStyles.micro(
                          color: MintColors.primary,
                        )),
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

  // AI (BYOK + SLM) section removed — now in SettingsSheet.

  Widget _buildDocumentsSection(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();
    final l = S.of(context)!;
    final count = docProvider.documentCount;
    final statusText = count > 0 ? l.profileDocCount(count) : l.documentsEmpty;
    return _buildFactFindSection(
      title: l.profileDocuments,
      status: statusText,
      isComplete: count > 0,
      icon: Icons.description_outlined,
      onTap: () => context.push('/documents'),
    );
  }

  Widget _buildAuthSection(BuildContext context, AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + MintSpacing.xs),
      child: MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + MintSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: MintColors.primary),
              const SizedBox(width: MintSpacing.sm + MintSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.displayName ??
                          authProvider.email ??
                          S.of(context)!.profileUser,
                      style: MintTextStyles.titleMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    if (authProvider.displayName != null)
                      Text(
                        authProvider.email ?? '',
                        style: MintTextStyles.labelSmall(
                          color: MintColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),
          TextButton.icon(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                context.go('/');
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: Text(S.of(context)!.authLogout,
                style: MintTextStyles.bodySmall()),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.error,
              padding:
                  const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/profile/admin-observability'),
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: Text(S.of(context)!.profileAdminObservability,
                style: MintTextStyles.bodySmall()),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.primary,
              padding:
                  const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/profile/admin-analytics'),
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: Text(S.of(context)!.profileAnalyticsBeta,
                style: MintTextStyles.bodySmall()),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.primary,
              padding:
                  const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
            ),
          ),
          TextButton.icon(
            onPressed: authProvider.isLoading
                ? null
                : () => _confirmDeleteAccount(context, authProvider),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text(S.of(context)!.profileDeleteCloudAccount,
                style: MintTextStyles.bodySmall()),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.error,
              padding:
                  const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
            ),
          ),
        ],
      ),
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
            onPressed: () => ctx.pop(false),
            child: Text(S.of(context)!.profileDeleteCancel),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            style: FilledButton.styleFrom(backgroundColor: MintColors.error),
            child: Text(S.of(context)!.profileDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await authProvider.deleteAccount();
    if (!context.mounted) return;

    // V5-2 audit fix: purge ALL local data artifacts on account deletion.
    // This ensures conversation history, coach insights, cached data, and
    // SharedPreferences are wiped — not just the server-side session.
    if (success) {
      final store = ConversationStore();
      // Delete all conversations from local storage
      final conversations = await store.listConversations();
      for (final conv in conversations) {
        await store.deleteConversation(conv.id);
      }
      await CoachMemoryService.clear();
      await CapMemoryStore.clear();
      final prefs = await SharedPreferences.getInstance();
      await PrecomputedInsightsService.clear(prefs);
      await prefs.clear(); // Nuclear option — clears all SharedPreferences
    }

    if (!context.mounted) return;

    final l = S.of(context)!;
    final message = success
        ? l.profileDeleteAccountSuccess
        : (authProvider.error != null
            ? localizeAuthError(authProvider.error!, l)
            : l.profileDeleteAccountError);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    if (success) {
      context.go('/');
    }
  }

  // Language section removed — now in SettingsSheet.

  Widget _buildDangerZone(BuildContext context) {
    final l = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: MintSpacing.lg),
        Text(
          l.profileDangerZoneTitle,
          style: MintTextStyles.bodySmall(
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: MintSpacing.sm),
        Text(
          l.profileDangerZoneSubtitle,
          style: MintTextStyles.labelSmall(
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
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
            // _profile = null in memory.
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
          child: Text(l.profileDeleteData, style: MintTextStyles.bodySmall()),
        ),
        Text(
          l.profileResetScopeNote,
          style: MintTextStyles.labelSmall(
            color: MintColors.textMuted,
          ),
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
                  const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
                  Text(
                    l.profileResetDialogConfirmLabel,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: MintSpacing.sm),
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
                  style:
                      TextButton.styleFrom(foregroundColor: MintColors.error),
                  child: Text(l.profileResetDialogAction),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() => controller.dispose());
  }
}
