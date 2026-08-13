// PrivacyCenterScreen — lists active + historical consent receipts, allows
// revocation from a single hub. Reachable at `/profile/privacy`.
//
// v2.7 Phase 29 / PRIV-01.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/local_preview_reset_service.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/future_builder_safe.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  final ConsentService _service = ConsentService();
  late Future<List<ConsentReceipt>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.list(force: true);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.list(force: true);
    });
  }

  Future<void> _confirmRevoke(ConsentReceipt receipt) async {
    final l = S.of(context)!;
    final isCascade = receipt.purpose == ConsentPurpose.persistence365d;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.consentRevokeConfirmTitle),
        content: Text(
          isCascade
              ? l.consentRevokeCascadeWarning
              : l.consentRevokeConfirmBody,
        ),
        actions: [
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.consentCancel),
          ),
          FilledButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.consentRevoke),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.revoke(receipt.receiptId);
      if (!mounted) return;
      await _refresh();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final l = S.of(context)!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.profileDeleteAccountTitle),
        content: Text(l.profileDeleteAccountContent),
        actions: [
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.profileDeleteCancel),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l.profileDeleteConfirm,
              style: const TextStyle(color: MintColors.error),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final deleted = await context.read<AuthProvider>().deleteAccount();
    if (!mounted) return;

    if (deleted) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.profileDeleteAccountError)),
      );
    }
  }

  String _labelForPurpose(S l, ConsentPurpose p) {
    switch (p) {
      case ConsentPurpose.visionExtraction:
        return l.consentPurposeVisionExtraction;
      case ConsentPurpose.persistence365d:
        return l.consentPurposePersistence365d;
      case ConsentPurpose.transferUsAnthropic:
        return l.consentPurposeTransferUsAnthropic;
      case ConsentPurpose.coupleProjection:
        return l.consentPurposeCoupleProjection;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    // B3a — l'autorité est l'état lifecycle CANONIQUE, jamais un booléen
    // isLoggedIn potentiellement périmé face aux jetons réels : la
    // suppression de compte n'existe qu'avec un compte confirmé
    // (accessMode account + userId ; sessionExpired a un userId null).
    final lifecycle = context.watch<AuthProvider>().authLifecycle;
    final hasCanonicalAccount =
        lifecycle.accessMode == AuthAccessMode.account &&
            lifecycle.userId != null;
    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        elevation: 0,
        title: Text(
          l.privacyCenterTitle,
          style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: MintColors.textPrimary),
      ),
      // La section Préversion (reset LOCAL) rend INDÉPENDAMMENT du fetch
      // serveur des consentements : une action purement locale ne dépend
      // jamais du réseau — en anonyme le fetch échoue et masquerait le
      // reset (trouvé au harnais runtime, run 1).
      body: Column(
        children: [
          if (PreviewShellPolicy.instance.isPreviewShell)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: l.previewResetSection),
                  Semantics(
                    identifier: 'action:preview_reset.open',
                    button: true,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.previewResetTitle,
                          style: MintTextStyles.bodyLarge(
                              color: MintColors.textPrimary)),
                      subtitle: Text(l.previewResetBody,
                          style: MintTextStyles.bodySmall(
                              color: MintColors.textSecondary)),
                      trailing: const Icon(Icons.restart_alt,
                          color: MintColors.error),
                      onTap: _confirmPreviewReset,
                    ),
                  ),
                  const Divider(color: MintColors.lightBorder),
                ],
              ),
            ),
          Expanded(child: _buildConsentsBody(l)),
          // B3a — la section compte est une vérité LOCALE (lifecycle
          // canonique) : elle rend indépendamment du fetch consents, comme
          // la section Préversion (même principe, même leçon runtime).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(color: MintColors.lightBorder),
                if (hasCanonicalAccount)
                  _DeleteAccountRow(onTap: _confirmDeleteAccount)
                else ...[
                  // État anonyme HONNÊTE : pas de compte, pas d'action de
                  // suppression, jamais une promesse serveur.
                  _SectionHeader(title: l.accountDeleteNoAccountTitle),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      PreviewShellPolicy.instance.isPreviewShell
                          ? l.accountDeleteNoAccountBodyPreview
                          : l.accountDeleteNoAccountBody,
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentsBody(S l) {
    return FutureBuilderSafe<List<ConsentReceipt>>(
        future: _future,
        onRetry: _refresh,
        builder: (ctx, consents) {
          final active = consents.where((c) => c.isActive).toList();
          final history = consents.where((c) => !c.isActive).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(title: l.privacyCenterSectionActive),
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l.privacyCenterEmpty,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  )
                else
                  for (final r in active)
                    _ConsentRow(
                      label: _labelForPurpose(l, r.purpose),
                      grantedAt: r.consentTimestamp,
                      onRevoke: () => _confirmRevoke(r),
                    ),
                const SizedBox(height: 24),
                _SectionHeader(title: l.privacyCenterSectionHistory),
                for (final r in history)
                  _ConsentRow(
                    label: _labelForPurpose(l, r.purpose),
                    grantedAt: r.consentTimestamp,
                    revokedAt: r.revokedAt,
                  ),
              ],
            ),
          );
        });
  }
}

extension _PreviewResetFlow on _PrivacyCenterScreenState {
  /// Comparaison de la confirmation forte, insensible aux diacritiques :
  /// taper la phrase entière reste exigé, mais « REPARTIR A ZERO » vaut
  /// « REPARTIR À ZÉRO » — les majuscules accentuées sont pénibles sur
  /// clavier iOS et le driver de saisie E2E les perd aussi.
  static String _normalizedConfirmation(String raw) {
    const diacritics = 'ÀÂÄÁÃÉÈÊËÍÎÏÓÔÖÕÚÙÛÜÇ'; // lint-ignore — table de normalisation, jamais rendue
    const plain = 'AAAAAEEEEIIIOOOOUUUUC';
    final upper = raw.trim().toUpperCase();
    final out = StringBuffer();
    for (final rune in upper.runes) {
      final ch = String.fromCharCode(rune);
      final idx = diacritics.indexOf(ch);
      out.write(idx >= 0 ? plain[idx] : ch);
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _confirmPreviewReset() async {
    final l = S.of(context)!;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.previewResetTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.previewResetBody),
            const SizedBox(height: 12),
            TextField(
              key: const Key('preview_reset_confirm_field'),
              controller: controller,
              autocorrect: false,
              enableSuggestions: false,
              decoration:
                  InputDecoration(hintText: l.previewResetConfirmHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(dialogContext).pop(
                _normalizedConfirmation(controller.text) ==
                    _normalizedConfirmation(l.previewResetConfirmWord)),
            child: Text(
              l.previewResetCta,
              style: const TextStyle(color: MintColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final userId = await AuthService.getUserId();
      await LocalPreviewResetService.reset(signedInUserId: userId);
      if (!mounted) return;
      // Rechargement honnête : storage purgé ⇒ profil mémoire remis à null,
      // rien ne survit en RAM jusqu'à la prochaine relance.
      await context.read<CoachProfileProvider>().loadFromWizard();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.previewResetDone)));
      context.go('/home');
    } catch (_) {
      // StateError (résidu/échec scellé) comme toute autre exception des
      // couches de purge : reset_pending est posé, le retry au boot le
      // reprendra — le rouge honnête couvre TOUS les échecs partiels.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.previewResetFailed)));
    }
  }
}

class _DeleteAccountRow extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteAccountRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.delete_outline,
        color: MintColors.error,
        size: 22,
      ),
      title: Text(
        l.profileDeleteCloudAccount,
        style: MintTextStyles.bodyMedium(color: MintColors.error),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: MintColors.error,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style:
            MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final String label;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final VoidCallback? onRevoke;

  const _ConsentRow({
    required this.label,
    required this.grantedAt,
    this.revokedAt,
    this.onRevoke,
  });

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintTextStyles.labelLarge(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  revokedAt == null
                      ? '${l.privacyCenterGrantedOn} ${_fmt(grantedAt)}'
                      : '${l.privacyCenterRevokedOn} ${_fmt(revokedAt!)}',
                  style: const TextStyle(
                    color: MintColors.textSecondary,
                  ).merge(MintTextStyles.labelMedium()),
                ),
              ],
            ),
          ),
          if (onRevoke != null)
            TextButton(
              // lint-ignore: prefer_mint_cta
              onPressed: onRevoke,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(l.consentRevoke),
            ),
        ],
      ),
    );
  }
}
