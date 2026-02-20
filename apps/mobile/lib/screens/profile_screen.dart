import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final authProvider = context.watch<AuthProvider>();
    final double precision = profile?.factfindCompletionIndex ?? 0.3;

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
                  _buildPrecisionCard(context, precision),
                  const SizedBox(height: 32),
                  Text(
                      S.of(context)?.profileFactFindTitle ?? 'Détails FactFind',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildFactFindSection(
                    title: S.of(context)?.profileSectionIdentity ??
                        'Identité & Foyer',
                    status: S.of(context)?.profileStatusComplete ?? 'Complet',
                    isComplete: true,
                    icon: Icons.person_outline,
                    onTap: () => context.push('/advisor/wizard'),
                  ),
                  _buildFactFindSection(
                    title: S.of(context)?.profileSectionIncome ??
                        'Revenus & Épargne',
                    status:
                        S.of(context)?.profileStatusPartial ?? 'Partial (Net)',
                    isComplete: false,
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => context.push('/advisor/wizard'),
                  ),
                  _buildFactFindSection(
                    title: S.of(context)?.profileSectionPension ??
                        'Prévoyance (LPP)',
                    status: S.of(context)?.profileStatusMissing ?? 'Manquant',
                    isComplete: false,
                    icon: Icons.security_outlined,
                    reward:
                        S.of(context)?.profileReward15 ?? '+15% de précision',
                    onTap: () => context.push('/advisor/wizard'),
                  ),
                  _buildFactFindSection(
                    title: S.of(context)?.profileSectionProperty ??
                        'Immobilier & Dettes',
                    status: S.of(context)?.profileStatusMissing ?? 'Manquant',
                    isComplete: false,
                    icon: Icons.home_outlined,
                    reward:
                        S.of(context)?.profileReward10 ?? '+10% de précision',
                    onTap: () => context.push('/advisor/wizard'),
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
    final s = S.of(context);
    return SliverAppBar(
      backgroundColor: MintColors.background,
      title: Text(s?.profileTitle ?? 'MON PROFIL MENTOR',
          style: GoogleFonts.montserrat(
              fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildPrecisionCard(BuildContext context, double precision) {
    final s = S.of(context);
    final coachProfile = context.watch<CoachProfileProvider>();
    final hasFullWizard = coachProfile.hasFullProfile;
    final hasMini = coachProfile.isPartialProfile;

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
                      color: Colors.white70, fontWeight: FontWeight.bold)),
              Text('${(precision * 100).toInt()}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: precision,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
            onTap: hasFullWizard ? null : () => context.push('/advisor/wizard'),
          ),
          _buildPrecisionRow(
            icon: Icons.home_outlined,
            label: s?.profileSectionProperty ?? 'Immobilier & Dettes',
            isComplete: hasFullWizard,
            reward: hasFullWizard ? null : '+10%',
            onTap: hasFullWizard ? null : () => context.push('/advisor/wizard'),
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
            Icon(icon, size: 16,
                color: isComplete ? Colors.white : Colors.white38),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: isComplete ? Colors.white : Colors.white54,
                    fontSize: 13,
                    decoration: isComplete ? TextDecoration.none : null,
                  )),
            ),
            if (isComplete)
              const Icon(Icons.check_circle, size: 16, color: Colors.white)
            else if (reward != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(reward,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
            else
              const Icon(Icons.radio_button_unchecked,
                  size: 16, color: Colors.white38),
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
            color: Colors.white,
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
    return _buildFactFindSection(
      title: s?.profileAiByok ?? 'Ask MINT (BYOK)',
      status: byok.isConfigured
          ? '${byok.providerLabel} \u2014 ${s?.profileAiConfigured ?? 'Configur\u00e9'}'
          : (s?.profileAiNotConfigured ?? 'Non configur\u00e9'),
      isComplete: byok.isConfigured,
      icon: Icons.auto_awesome,
      onTap: () => context.push('/profile/byok'),
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
        color: Colors.white,
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
            label: const Text('Admin observability'),
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
            label: const Text('Supprimer mon compte cloud'),
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
        title: const Text('Supprimer le compte ?'),
        content: const Text(
          'Cette action supprime ton compte cloud et les données associées. '
          'Tes données locales restent sur cet appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: MintColors.error),
            child: const Text('Supprimer'),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        const Text('Langue / Sprache / Language',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              color: Colors.white,
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

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  s?.profileResetSuccess ??
                      'Historique financier local réinitialisé.',
                ),
              ),
            );
            context.go('/');
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
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
