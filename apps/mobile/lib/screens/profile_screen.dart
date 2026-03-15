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
    final recommendedSection = coachProvider.recommendedWizardSection;
    final onboardingQuality =
        (coachProvider.onboardingQualityScore * 100).round();

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
                  // Identity summary card (Moi tab hero)
                  if (coachProfile != null)
                    _buildIdentityCard(context, coachProfile),
                  if (coachProfile != null) const SizedBox(height: 16),
                  _buildPrecisionCard(context, precision),
                  const SizedBox(height: 12),
                  _buildBilanLink(context, coachProfile != null),
                  const SizedBox(height: 12),
                  if (precision >= 1.0) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: MintColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: MintColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: MintColors.success, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              S.of(context)?.profileCompleteBanner ??
                                  'Profil complet ! Ton coach dispose de toutes les données pour des conseils fiables.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: MintColors.success,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_shouldShowAnnualRefresh(coachProvider)) ...[
                    const SizedBox(height: 12),
                    _buildAnnualRefreshCard(context),
                  ],
                  _buildProfileGuidanceCard(
                    context,
                    recommendedSection: recommendedSection,
                    onboardingQuality: onboardingQuality,
                  ),
                  const SizedBox(height: 32),
                  Text(
                      S.of(context)?.profileFactFindTitle ?? 'Détails FactFind',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildFactFindSection(
                    title: S.of(context)?.profileSectionIdentity ??
                        'Identité & Foyer',
                    status: identityComplete
                        ? (S.of(context)?.profileStatusComplete ?? 'Complet')
                        : (S.of(context)?.profileStatusPartial ??
                            'A completer'),
                    isComplete: identityComplete,
                    icon: Icons.person_outline,
                    onTap: () =>
                        context.push('/advisor/wizard?section=identity'),
                  ),
                  _buildFactFindSection(
                    title: S.of(context)?.profileSectionIncome ??
                        'Revenus & Épargne',
                    status: incomeComplete
                        ? (S.of(context)?.profileStatusComplete ?? 'Complet')
                        : (S.of(context)?.profileStatusPartial ??
                            'A completer'),
                    isComplete: incomeComplete,
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () =>
                        context.push('/advisor/wizard?section=income'),
                  ),
                  _buildFactFindSection(
                    title: S.of(context)?.profileSectionPension ??
                        'Prévoyance (LPP)',
                    status: pensionComplete
                        ? (S.of(context)?.profileStatusComplete ?? 'Complet')
                        : (S.of(context)?.profileStatusMissing ?? 'Manquant'),
                    isComplete: pensionComplete,
                    icon: Icons.security_outlined,
                    reward: pensionComplete
                        ? null
                        : (S.of(context)?.profileReward15 ??
                            '+15% de précision'),
                    onTap: () =>
                        context.push('/advisor/wizard?section=pension'),
                  ),
                  _buildFactFindSection(
                    title: S.of(context)?.profileSectionProperty ??
                        'Immobilier & Dettes',
                    status: propertyComplete
                        ? (S.of(context)?.profileStatusComplete ?? 'Complet')
                        : (S.of(context)?.profileStatusMissing ?? 'Manquant'),
                    isComplete: propertyComplete,
                    icon: Icons.home_outlined,
                    reward: propertyComplete
                        ? null
                        : (S.of(context)?.profileReward10 ??
                            '+10% de précision'),
                    onTap: () =>
                        context.push('/advisor/wizard?section=property'),
                  ),
                  const SizedBox(height: 32),
                  _buildLanguageSection(context),
                  const SizedBox(height: 32),
                  Text(S.of(context)?.profileSecurityTitle ?? 'Sécurité & Data',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildFactFindSection(
                    title: S.of(context)?.profileConsentControl ??
                        'Contrôle des Partages',
                    status: S.of(context)?.profileConsentManage ??
                        'Gérer mes accès bLink',
                    isComplete: true,
                    icon: Icons.lock_outline,
                    onTap: () => context.push('/profile/consent'),
                  ),
                  const SizedBox(height: 32),
                  Text(
                      S.of(context)?.profileAiTitle ??
                          'Intelligence Artificielle',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildAiSection(context),
                  const SizedBox(height: 32),
                  Text(S.of(context)!.profileFamilySection,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildFactFindSection(
                    title: 'Notre menage',
                    status: 'Couple+',
                    isComplete: false,
                    icon: Icons.people_outline,
                    onTap: () => context.push('/household'),
                  ),
                  const SizedBox(height: 32),
                  Text(S.of(context)?.profileDocuments ?? 'Mes documents',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildDocumentsSection(context),
                  const SizedBox(height: 32),
                  // Auth section (if logged in)
                  if (authProvider.isLoggedIn) ...[
                    Text(S.of(context)?.profileAccountTitle ?? 'Compte',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildAuthSection(context, authProvider),
                    const SizedBox(height: 32),
                  ],
                  _buildDangerZone(context),
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
      title: Text('Moi',
          style: GoogleFonts.montserrat(
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: MintColors.textPrimary)),
    );
  }

  Widget _buildIdentityCard(BuildContext context, dynamic profile) {
    final name = profile.firstName ?? 'Utilisateur';
    final age = profile.age;
    final canton = profile.canton as String;
    final status = profile.employmentStatus as String;

    final statusLabel = {
      'salarie': 'Salarié',
      'independant': 'Indépendant',
      'chomage': 'En recherche',
      'retraite': 'Retraité',
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
                      age != null ? '$name, $age ans' : name,
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
                tooltip: 'Modifier',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBilanLink(BuildContext context, bool hasProfile) {
    return InkWell(
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
                    'Mon aperçu financier',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasProfile
                        ? 'Revenus, prévoyance, patrimoine, dettes'
                        : 'Complète ton profil pour voir tes chiffres',
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
    );
  }

  Widget _buildPrecisionCard(BuildContext context, double precision) {
    final s = S.of(context);
    final coachProfile = context.watch<CoachProfileProvider>();
    final hasFullWizard = coachProfile.hasFullProfile;
    final hasMini = coachProfile.hasProfile && !hasFullWizard;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: MintColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s?.profilePrecisionIndex ?? 'Precision Index',
                  style: const TextStyle(
                      color: MintColors.white70, fontWeight: FontWeight.bold)),
              Text('${(precision * 100).toInt()}%',
                  style: const TextStyle(
                      color: MintColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: precision,
            backgroundColor: MintColors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(MintColors.white),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 16),
          // Drill-down: show what's complete and what's missing
          _buildPrecisionRow(
            icon: Icons.person_outline,
            label: s?.profileSectionIdentity ?? 'Identite & Foyer',
            isComplete: hasMini || hasFullWizard,
          ),
          _buildPrecisionRow(
            icon: Icons.account_balance_wallet_outlined,
            label: s?.profileSectionIncome ?? 'Revenus & Epargne',
            isComplete: hasMini || hasFullWizard,
          ),
          _buildPrecisionRow(
            icon: Icons.security_outlined,
            label: s?.profileSectionPension ?? 'Prevoyance (LPP)',
            isComplete: hasFullWizard,
            reward: hasFullWizard ? null : '+15%',
            onTap: hasFullWizard
                ? null
                : () => context.push('/advisor/wizard?section=pension'),
          ),
          _buildPrecisionRow(
            icon: Icons.home_outlined,
            label: s?.profileSectionProperty ?? 'Immobilier & Dettes',
            isComplete: hasFullWizard,
            reward: hasFullWizard ? null : '+10%',
            onTap: hasFullWizard
                ? null
                : () => context.push('/advisor/wizard?section=property'),
          ),
        ],
      ),
    );
  }

  bool _shouldShowAnnualRefresh(CoachProfileProvider provider) {
    final profile = provider.profile;
    if (profile == null) return false;
    final lastUpdate = profile.checkIns.isNotEmpty
        ? profile.checkIns.last.month
        : DateTime(profile.birthYear);
    return DateTime.now().difference(lastUpdate).inDays >= 300;
  }

  Widget _buildAnnualRefreshCard(BuildContext context) {
    final s = S.of(context);
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
                s?.profileAnnualRefreshTitle ?? 'Mise à jour annuelle',
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
            s?.profileAnnualRefreshBody ??
                'Tes données datent de plus de 10 mois. Un check-up rapide (2 min) fiabilise ton plan.',
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
                s?.profileAnnualRefreshCta ?? 'Lancer le check-up',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _wizardSectionLabel(BuildContext context, String section) {
    final s = S.of(context);
    switch (section) {
      case 'identity':
        return s?.profileSectionIdentity ?? 'Identité & Foyer';
      case 'income':
        return s?.profileSectionIncome ?? 'Revenus & Épargne';
      case 'pension':
        return s?.profileSectionPension ?? 'Prévoyance (LPP)';
      case 'property':
        return s?.profileSectionProperty ?? 'Immobilier & Dettes';
      default:
        return s?.advisorMiniFullDiagnostic ?? 'Diagnostic complet';
    }
  }

  Widget _buildProfileGuidanceCard(
    BuildContext context, {
    required String recommendedSection,
    required int onboardingQuality,
  }) {
    final s = S.of(context);
    final sectionLabel = _wizardSectionLabel(context, recommendedSection);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, size: 16, color: MintColors.info),
              const SizedBox(width: 8),
              Text(
                s?.profileGuidanceTitle ?? 'Section recommandée',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$onboardingQuality%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s?.profileGuidanceBody(sectionLabel) ??
                'Complète maintenant $sectionLabel pour fiabiliser ton plan.',
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
              onPressed: () => context.push(
                '/advisor/wizard',
                extra: {'section': recommendedSection},
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                s?.profileGuidanceCta(sectionLabel) ??
                    'Compléter $sectionLabel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecisionRow({
    required IconData icon,
    required String label,
    required bool isComplete,
    String? reward,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon,
                size: 16, color: isComplete ? MintColors.white : MintColors.white38),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: isComplete ? MintColors.white : MintColors.white54,
                    fontSize: 13,
                    decoration: isComplete ? TextDecoration.none : null,
                  )),
            ),
            if (isComplete)
              const Icon(Icons.check_circle, size: 16, color: MintColors.white)
            else if (reward != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: MintColors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(reward,
                    style: const TextStyle(
                        color: MintColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
            else
              const Icon(Icons.radio_button_unchecked,
                  size: 16, color: MintColors.white38),
          ],
        ),
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
    return Container(
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
    );
  }

  Widget _buildAiSection(BuildContext context) {
    final byok = context.watch<ByokProvider>();
    final s = S.of(context);
    return Column(
      children: [
        _buildFactFindSection(
          title: s?.profileAiByok ?? 'Ask MINT (BYOK)',
          status: byok.isConfigured
              ? '${byok.providerLabel} \u2014 ${s?.profileAiConfigured ?? 'Configur\u00e9'}'
              : (s?.profileAiNotConfigured ?? 'Non configur\u00e9'),
          isComplete: byok.isConfigured,
          icon: Icons.auto_awesome,
          onTap: () => context.push('/profile/byok'),
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final slm = context.watch<SlmProvider>();
          return _buildFactFindSection(
            title: 'IA on-device (SLM)',
            status: slm.isEngineAvailable
                ? 'Mod\u00e8le pr\u00eat'
                : 'Mod\u00e8le non install\u00e9',
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
    final s = S.of(context);
    final count = docProvider.documentCount;
    final statusText = count > 0
        ? '$count document(s)'
        : (s?.documentsEmpty ?? 'Aucun document');
    return _buildFactFindSection(
      title: s?.profileDocuments ?? 'Mes documents',
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
                          (S.of(context)?.profileUser ?? 'Utilisateur'),
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
            label: Text(S.of(context)?.authLogout ?? 'Se déconnecter'),
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

    final message = success
        ? 'Compte supprimé avec succès.'
        : (authProvider.error ??
            'Suppression impossible pour le moment. Réessaie plus tard.');
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
        InkWell(
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
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Text(
          s?.profileDangerZoneTitle ?? 'Zone sensible',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          s?.profileDangerZoneSubtitle ??
              'Réinitialise ton historique financier local sans supprimer ton compte.',
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
              SnackBar(
                content: Text(
                  s?.profileResetSuccess ??
                      'Historique financier local réinitialisé.',
                ),
              ),
            );
            if (!context.mounted) return;
            if (kIsWeb) {
              // On web, navigate to onboarding so the user sees a clean slate.
              // loadFromWizard() above already confirmed _profile = null.
              context.go('/onboarding/quick');
            } else {
              context.go('/');
            }
          },
          style: TextButton.styleFrom(foregroundColor: MintColors.error),
          child: Text(
            s?.profileDeleteData ?? 'Supprimer mes données locales',
          ),
        ),
        Text(
          s?.profileResetScopeNote ??
              'Conserve la connexion et la clé BYOK. Les documents backend ne sont pas supprimés.',
          style: const TextStyle(fontSize: 11, color: MintColors.textMuted),
        ),
      ],
    );
  }

  Future<bool?> _showStrongResetDialog(BuildContext context) async {
    final s = S.of(context);
    final controller = TextEditingController();
    bool valid = false;
    const expected = 'RESET';

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(
                s?.profileResetDialogTitle ?? 'Réinitialiser ma situation ?',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s?.profileResetDialogBody ??
                        'Cette action supprime ton diagnostic, tes check-ins, ton score et ton budget local.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s?.profileResetDialogConfirmLabel ??
                        'Tape RESET pour confirmer :',
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
                          : s?.profileResetDialogInvalid ?? 'Mot-clé invalide.',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s?.commonCancel ?? 'Annuler'),
                ),
                TextButton(
                  onPressed: valid ? () => Navigator.pop(ctx, true) : null,
                  style: TextButton.styleFrom(foregroundColor: MintColors.error),
                  child: Text(s?.profileResetDialogAction ?? 'Réinitialiser'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
